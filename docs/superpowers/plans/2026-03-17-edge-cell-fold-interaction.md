# Edge Cell Fold Interaction Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fold-line-click interaction with edge-cell two-click interaction (click edge cell → see targets → click target to fold).

**Architecture:** Add interaction state machine (IDLE/SELECTED/FOLDING) to game.gd. Add public helper methods to grid_model.gd for mirror position calculation and side determination. Replace fold line Buttons and diagonal hit-testing with cell-click detection in `_input()`. Draw fold lines as dashed decorative lines.

**Tech Stack:** Godot 4.6, GDScript

**Spec:** `docs/superpowers/specs/2026-03-17-edge-cell-fold-interaction-design.md`

---

## Chunk 1: grid_model.gd — Public helpers and force_side

### Task 1: Add public helper methods to grid_model.gd

These methods allow game.gd to compute target positions and determine foldable sides without duplicating fold logic.

**Files:**
- Modify: `scripts/grid_model.gd`

- [ ] **Step 1: Add `get_mirror_pos()` static method**

Add after the `_cells_equal` method at the end of grid_model.gd:

```gdscript
# ── Public Helpers for Interaction ──────────────────────────────────

static func get_mirror_pos(fold_def: Dictionary, row: int, col: int, grid_size: int) -> Vector2i:
	## Calculate the mirror position for a cell across a fold line.
	## Returns Vector2i(-1,-1) if out of bounds.
	var fold_type: String = fold_def["type"]
	var target_r: int
	var target_c: int
	match fold_type:
		"v":
			var pos: int = int(fold_def["pos"])
			target_r = row
			target_c = 2 * pos - 1 - col
		"h":
			var pos: int = int(fold_def["pos"])
			target_r = 2 * pos - 1 - row
			target_c = col
		"d_bs":
			var offset: int = int(fold_def["offset"])
			target_r = col - offset
			target_c = row + offset
		"d_fs":
			var offset: int = int(fold_def["offset"])
			target_r = offset - col
			target_c = offset - row
		_:
			return Vector2i(-1, -1)
	if target_r < 0 or target_r >= grid_size or target_c < 0 or target_c >= grid_size:
		return Vector2i(-1, -1)
	return Vector2i(target_c, target_r)
```

- [ ] **Step 2: Add `get_fold_side()` static method**

Add right after `get_mirror_pos`:

```gdscript
static func get_fold_side(fold_def: Dictionary, row: int, col: int, grid_size: int) -> int:
	## Determine which side of a fold line a cell is on.
	## Returns: 0 = side A, 1 = side B, -1 = on the fold line (diagonal only).
	var fold_type: String = fold_def["type"]
	match fold_type:
		"v":
			var pos: int = int(fold_def["pos"])
			if col < pos:
				return 0  # left
			else:
				return 1  # right
		"h":
			var pos: int = int(fold_def["pos"])
			if row < pos:
				return 0  # top
			else:
				return 1  # bottom
		"d_bs":
			var offset: int = int(fold_def["offset"])
			var val: int = col - row
			if val > offset:
				return 0  # side A (upper-right)
			elif val < offset:
				return 1  # side B (lower-left)
			else:
				return -1  # on fold line
		"d_fs":
			var offset: int = int(fold_def["offset"])
			var val: int = col + row
			if val < offset:
				return 0  # side A (upper-left)
			elif val > offset:
				return 1  # side B (lower-right)
			else:
				return -1  # on fold line
	return -1


static func is_foldable_side(fold_def: Dictionary, row: int, col: int, grid_size: int) -> bool:
	## Check if a cell is on a foldable side (smaller or equal side) of a fold line.
	var side := get_fold_side(fold_def, row, col, grid_size)
	if side == -1:
		return false  # on the fold line itself

	var fold_type: String = fold_def["type"]
	var count_a := 0
	var count_b := 0

	match fold_type:
		"v":
			var pos: int = int(fold_def["pos"])
			count_a = pos
			count_b = grid_size - pos
		"h":
			var pos: int = int(fold_def["pos"])
			count_a = pos
			count_b = grid_size - pos
		"d_bs", "d_fs":
			var is_bs := (fold_type == "d_bs")
			var offset: int = int(fold_def["offset"])
			for r in range(grid_size):
				for c in range(grid_size):
					var val: int = (c - r) if is_bs else (c + r)
					if val > offset:
						if is_bs: count_a += 1
						else: count_b += 1
					elif val < offset:
						if is_bs: count_b += 1
						else: count_a += 1

	# Side A (0) is foldable if count_a <= count_b
	# Side B (1) is foldable if count_b <= count_a
	if side == 0:
		return count_a <= count_b
	else:
		return count_b <= count_a
```

- [ ] **Step 3: Add `force_side` parameter to `fold()`**

Modify the `fold()` method signature and pass it through to `_fold_vh` and `_fold_diagonal`:

In `fold()`, change:
```gdscript
func fold(fold_def: Dictionary) -> Dictionary:
```
to:
```gdscript
func fold(fold_def: Dictionary, force_side: int = -1) -> Dictionary:
```

And pass `force_side` to the internal methods. Change lines 179-185:
```gdscript
	match fold_type:
		"v":
			result = _fold_vh(fold_type, int(fold_def["pos"]), force_side)
		"h":
			result = _fold_vh(fold_type, int(fold_def["pos"]), force_side)
		"d_bs":
			result = _fold_diagonal(fold_type, int(fold_def["offset"]), force_side)
		"d_fs":
			result = _fold_diagonal(fold_type, int(fold_def["offset"]), force_side)
```

- [ ] **Step 4: Update `_fold_vh` to accept `force_side`**

Change signature:
```gdscript
func _fold_vh(fold_type: String, fold_pos: int, force_side: int = -1) -> Dictionary:
```

Replace the source index selection logic (lines 204-218):
```gdscript
	var src_indices: Array[int] = []
	var left := fold_pos
	var right := size - fold_pos
	var fold_left: bool
	if force_side == 0:
		fold_left = true
	elif force_side == 1:
		fold_left = false
	else:
		fold_left = (left <= right)  # original auto behavior

	if is_vert:
		if fold_left:
			for i in range(fold_pos): src_indices.append(i)
		else:
			for i in range(fold_pos, size): src_indices.append(i)
	else:
		var top := fold_pos
		var bottom := size - fold_pos
		var fold_top: bool
		if force_side == 0:
			fold_top = true
		elif force_side == 1:
			fold_top = false
		else:
			fold_top = (top <= bottom)
		if fold_top:
			for i in range(fold_pos): src_indices.append(i)
		else:
			for i in range(fold_pos, size): src_indices.append(i)
```

- [ ] **Step 5: Update `_fold_diagonal` to accept `force_side`**

Change signature:
```gdscript
func _fold_diagonal(fold_type: String, offset: int, force_side: int = -1) -> Dictionary:
```

Replace the `fold_side_a` determination (line 279):
```gdscript
	var fold_side_a: bool
	if force_side == 0:
		fold_side_a = true
	elif force_side == 1:
		fold_side_a = false
	else:
		fold_side_a = (count_a <= count_b)  # original auto behavior
```

- [ ] **Step 6: Verify compilation**

Run: `cd /Volumes/Mac/GameDev/origami-puzzle && /Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20`

Expected: No GDScript errors related to grid_model.gd

- [ ] **Step 7: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "feat: add public helpers and force_side param to grid_model"
```

---

## Chunk 2: game.gd — Remove old interaction, add state machine and cell click

### Task 2: Add interaction state and remove old fold button/diagonal code

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Add state enum and variables**

Add after line 33 (`var is_animating := false`):

```gdscript
enum InteractionState { IDLE, SELECTED, FOLDING }
var _state: InteractionState = InteractionState.IDLE
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _target_map: Dictionary = {}  # {Vector2i -> Array[Dictionary]} — target cell -> [fold_defs]
var _highlight_nodes: Array = []  # Nodes created for glow effects
```

- [ ] **Step 2: Remove old fold button and diagonal arrays**

Remove these variables (lines 38-40):
```gdscript
var fold_buttons: Array = []
var fold_lines: Array = []
var _diag_folds: Array = []  # [{def, line, p1, p2}, ...] for diagonal hit testing
```

Replace with:
```gdscript
var fold_lines: Array = []  # Decorative dashed Line2D nodes
```

- [ ] **Step 3: Remove `_build_v_fold_line` Button and hover code**

Replace the entire `_build_v_fold_line` function with:

```gdscript
func _build_v_fold_line(fold_pos: int, total: float) -> void:
	var x := GRID_ORIGIN.x + fold_pos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var extend := 12.0
	_draw_dashed_line(
		Vector2(x, GRID_ORIGIN.y - extend),
		Vector2(x, GRID_ORIGIN.y + total + extend),
		FOLD_LINE_COLOR, 2.0, 8.0, 6.0
	)
```

- [ ] **Step 4: Remove `_build_h_fold_line` Button and hover code**

Replace the entire `_build_h_fold_line` function with:

```gdscript
func _build_h_fold_line(fold_pos: int, total: float) -> void:
	var y := GRID_ORIGIN.y + fold_pos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var extend := 12.0
	_draw_dashed_line(
		Vector2(GRID_ORIGIN.x - extend, y),
		Vector2(GRID_ORIGIN.x + total + extend, y),
		FOLD_LINE_COLOR, 2.0, 8.0, 6.0
	)
```

- [ ] **Step 5: Replace `_build_diagonal_fold_line` — remove indicators**

Replace the entire `_build_diagonal_fold_line` function with:

```gdscript
func _build_diagonal_fold_line(fold_type: String, offset: int, _total: float) -> void:
	var is_bs := (fold_type == "d_bs")
	var s := model.size

	var first_cell := Vector2i(-1, -1)
	var last_cell := Vector2i(-1, -1)
	for row in range(s):
		for col in range(s):
			var val: int = (col - row) if is_bs else (col + row)
			if val != offset:
				continue
			if first_cell.x == -1:
				first_cell = Vector2i(col, row)
			last_cell = Vector2i(col, row)

	if first_cell.x == -1:
		return

	var p1: Vector2
	var p2: Vector2
	if is_bs:
		p1 = _cell_pos(first_cell.x, first_cell.y)
		p2 = _cell_pos(last_cell.x, last_cell.y) + Vector2(CELL_SIZE, CELL_SIZE)
	else:
		p1 = _cell_pos(first_cell.x, first_cell.y) + Vector2(CELL_SIZE, 0)
		p2 = _cell_pos(last_cell.x, last_cell.y) + Vector2(0, CELL_SIZE)

	# Extend beyond grid
	var dir := (p2 - p1).normalized()
	p1 -= dir * 12.0
	p2 += dir * 12.0

	_draw_dashed_line(p1, p2, FOLD_LINE_COLOR, 2.0, 8.0, 6.0)
```

- [ ] **Step 6: Add `_draw_dashed_line` helper**

Add this helper function (after `_build_diagonal_fold_line`):

```gdscript
func _draw_dashed_line(p1: Vector2, p2: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var dir := (p2 - p1).normalized()
	var total_len := p1.distance_to(p2)
	var pos := 0.0
	while pos < total_len:
		var dash_end := minf(pos + dash, total_len)
		var line := Line2D.new()
		line.add_point(p1 + dir * pos)
		line.add_point(p1 + dir * dash_end)
		line.width = width
		line.default_color = color
		line.z_index = 1
		add_child(line)
		fold_lines.append(line)
		pos += dash + gap
```

- [ ] **Step 7: Remove `_point_dist_to_segment` and old `_input`**

Delete the entire `_point_dist_to_segment` static function (lines 576-582).

Delete the entire old `_input` function (lines 585-607).

- [ ] **Step 8: Remove `_set_fold_buttons_enabled` and its calls**

Delete the `_set_fold_buttons_enabled` function (lines 806-808).

Remove the two calls to it in `_animate_fold` (lines 621 and 632). The function becomes:

```gdscript
func _animate_fold(fold_data: Dictionary) -> void:
	is_animating = true
	_state = InteractionState.FOLDING

	var fold_type: String = fold_data["type"]
	match fold_type:
		"v", "h":
			await _animate_vh_fold(fold_data)
		"d_bs", "d_fs":
			await _animate_diagonal_fold(fold_data)

	_refresh_grid()
	_update_fold_label()
	_state = InteractionState.IDLE
	is_animating = false

	if model.check_win():
		await get_tree().create_timer(0.5).timeout
		_show_win()
```

- [ ] **Step 9: Remove `fold_buttons` references in `_build_all`**

In `_build_all`, remove:
```gdscript
	fold_buttons.clear()
```
And remove:
```gdscript
	_diag_folds.clear()
```

- [ ] **Step 10: Remove dead constants and functions**

Delete `FOLD_LINE_HOVER` constant:
```gdscript
const FOLD_LINE_HOVER := Color("#4A90D9", 0.8)
```

Delete `FOLD_BTN_THICKNESS` constant:
```gdscript
const FOLD_BTN_THICKNESS := 44
```

Delete the old `_on_fold` function (no longer called by anything):
```gdscript
func _on_fold(fold_def: Dictionary) -> void:
	...
```

- [ ] **Step 11: Verify compilation**

Run: `cd /Volumes/Mac/GameDev/origami-puzzle && /Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20`

- [ ] **Step 12: Commit**

```bash
git add scripts/game.gd
git commit -m "refactor: remove old fold buttons/hover/diagonal hit-testing, add dashed lines"
```

---

### Task 3: Implement new cell-click interaction

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Add `_input` with cell-click detection**

```gdscript
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_animating or not model.can_fold():
		return

	var cell := _pos_to_cell(mb.position)

	match _state:
		InteractionState.IDLE:
			if cell.x >= 0 and _is_valid_edge_cell(cell.y, cell.x):
				_select_cell(cell)
				get_viewport().set_input_as_handled()
		InteractionState.SELECTED:
			if cell == _selected_cell:
				_cancel_selection()
				get_viewport().set_input_as_handled()
			elif _target_map.has(cell):
				var fold_defs: Array = _target_map[cell]
				_cancel_selection()
				_on_fold_with_side(fold_defs[0])
				get_viewport().set_input_as_handled()
			else:
				_cancel_selection()
				get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Add `_pos_to_cell` helper**

```gdscript
func _pos_to_cell(pos: Vector2) -> Vector2i:
	## Convert screen position to grid cell coordinates. Returns (-1,-1) if invalid.
	var local := pos - GRID_ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var step := float(CELL_SIZE + CELL_GAP)
	var col := int(local.x / step)
	var row := int(local.y / step)
	if col >= model.size or row >= model.size:
		return Vector2i(-1, -1)
	# Check click is within cell, not in gap
	var local_x := local.x - col * step
	var local_y := local.y - row * step
	if local_x > CELL_SIZE or local_y > CELL_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(col, row)
```

- [ ] **Step 3: Add `_is_valid_edge_cell` method**

```gdscript
func _is_valid_edge_cell(row: int, col: int) -> bool:
	## Check if cell is a non-empty edge cell that can be folded.
	if GridModel.is_empty_cell(model.front[row][col]):
		return false
	# Check if on visual edge (grid boundary or adjacent to empty)
	var on_edge := false
	if row == 0 or row == model.size - 1 or col == 0 or col == model.size - 1:
		on_edge = true
	else:
		# Check 4-directional neighbors for empty
		if GridModel.is_empty_cell(model.front[row - 1][col]):
			on_edge = true
		elif GridModel.is_empty_cell(model.front[row + 1][col]):
			on_edge = true
		elif GridModel.is_empty_cell(model.front[row][col - 1]):
			on_edge = true
		elif GridModel.is_empty_cell(model.front[row][col + 1]):
			on_edge = true
	if not on_edge:
		return false
	# Check if at least one fold line affects this cell
	for fold_def in model.available_folds:
		if GridModel.is_foldable_side(fold_def, row, col, model.size):
			return true
	return false
```

- [ ] **Step 4: Add `_compute_targets` method**

```gdscript
func _compute_targets(row: int, col: int) -> Dictionary:
	## Compute all reachable target positions for a cell. Returns {Vector2i -> Array[Dictionary]}.
	var targets := {}
	for fold_def in model.available_folds:
		if not GridModel.is_foldable_side(fold_def, row, col, model.size):
			continue
		var mirror := GridModel.get_mirror_pos(fold_def, row, col, model.size)
		if mirror == Vector2i(-1, -1):
			continue
		# Store fold_def with the side info
		var side := GridModel.get_fold_side(fold_def, row, col, model.size)
		var entry := fold_def.duplicate()
		entry["_force_side"] = side
		if not targets.has(mirror):
			targets[mirror] = []
		targets[mirror].append(entry)
	return targets
```

- [ ] **Step 5: Add `_select_cell` and `_cancel_selection`**

```gdscript
func _select_cell(cell: Vector2i) -> void:
	_selected_cell = cell
	_target_map = _compute_targets(cell.y, cell.x)
	_state = InteractionState.SELECTED
	_draw_highlights()


func _cancel_selection() -> void:
	_selected_cell = Vector2i(-1, -1)
	_target_map.clear()
	_state = InteractionState.IDLE
	_clear_highlights()
```

- [ ] **Step 6: Add `_on_fold_with_side`**

```gdscript
func _on_fold_with_side(fold_def_with_side: Dictionary) -> void:
	var force_side: int = fold_def_with_side.get("_force_side", -1)
	# Build clean fold_def without internal fields
	var fold_def := {}
	for key in fold_def_with_side:
		if not key.begins_with("_"):
			fold_def[key] = fold_def_with_side[key]

	if is_animating or not model.can_fold():
		return
	var result := model.fold(fold_def, force_side)
	if result.is_empty():
		return
	_animate_fold(result)
```

- [ ] **Step 7: Update `_on_undo` and `_on_reset` to cancel selection**

```gdscript
func _on_undo() -> void:
	if is_animating:
		return
	if _state == InteractionState.SELECTED:
		_cancel_selection()
	model.undo()
	_refresh_grid()
	_update_fold_label()


func _on_reset() -> void:
	if is_animating:
		return
	if _state == InteractionState.SELECTED:
		_cancel_selection()
	model.reset()
	_refresh_grid()
	_update_fold_label()
```

- [ ] **Step 8: Verify compilation**

Run: `cd /Volumes/Mac/GameDev/origami-puzzle && /Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20`

- [ ] **Step 9: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: implement edge-cell two-click fold interaction"
```

---

## Chunk 3: Glow effects and edge hints

### Task 4: Add highlight/glow visual effects

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Add highlight color constants**

Add near the other color constants:
```gdscript
const SELECTED_BORDER_COLOR := Color("#FFFFFF")
const TARGET_GLOW_COLOR := Color("#FFD700")
```

- [ ] **Step 2: Implement `_draw_highlights`**

```gdscript
func _draw_highlights() -> void:
	_clear_highlights()
	# Selected cell — white border
	var sel_pos := _cell_pos(_selected_cell.x, _selected_cell.y)
	var sel_border := ReferenceRect.new()
	sel_border.position = sel_pos - Vector2(2, 2)
	sel_border.size = Vector2(CELL_SIZE + 4, CELL_SIZE + 4)
	sel_border.border_color = SELECTED_BORDER_COLOR
	sel_border.border_width = 3.0
	sel_border.editor_only = false
	sel_border.z_index = 20
	add_child(sel_border)
	_highlight_nodes.append(sel_border)

	# Target cells — gold glow border with pulse
	for target_cell in _target_map.keys():
		var tgt_pos := _cell_pos(target_cell.x, target_cell.y)

		# Outer glow (wider, semi-transparent)
		var glow := ReferenceRect.new()
		glow.position = tgt_pos - Vector2(4, 4)
		glow.size = Vector2(CELL_SIZE + 8, CELL_SIZE + 8)
		glow.border_color = Color(TARGET_GLOW_COLOR, 0.4)
		glow.border_width = 5.0
		glow.editor_only = false
		glow.z_index = 19
		add_child(glow)
		_highlight_nodes.append(glow)

		# Inner border
		var border := ReferenceRect.new()
		border.position = tgt_pos - Vector2(2, 2)
		border.size = Vector2(CELL_SIZE + 4, CELL_SIZE + 4)
		border.border_color = TARGET_GLOW_COLOR
		border.border_width = 3.0
		border.editor_only = false
		border.z_index = 20
		add_child(border)
		_highlight_nodes.append(border)

		# Pulse animation — use node-owned tweens so they auto-stop on queue_free()
		var tween := border.create_tween()
		tween.set_loops()
		tween.tween_property(border, "border_color:a", 0.4, 0.75)
		tween.tween_property(border, "border_color:a", 1.0, 0.75)
		var tween2 := glow.create_tween()
		tween2.set_loops()
		tween2.tween_property(glow, "border_color:a", 0.15, 0.75)
		tween2.tween_property(glow, "border_color:a", 0.4, 0.75)
```

- [ ] **Step 3: Implement `_clear_highlights`**

```gdscript
func _clear_highlights() -> void:
	for node in _highlight_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_highlight_nodes.clear()
```

- [ ] **Step 4: Verify compilation**

Run: `cd /Volumes/Mac/GameDev/origami-puzzle && /Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20`

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: add gold glow pulse for target cells, white border for selected"
```

---

**Note:** IDLE-state edge cell visual hints (subtle border/glow to indicate clickability) are deferred per spec — "具体视觉效果在游戏中调试确定". Will be tuned during manual testing.

### Task 5: Manual integration test

- [ ] **Step 1: Launch game and test basic V/H fold**

Open the game in Godot editor. Start level 1 (a simple level).

Verify:
- Fold lines appear as dashed `- - -` lines extending beyond the grid
- No buttons or hover effects on fold lines
- Clicking an edge cell highlights it with white border
- Target positions show gold pulsing border
- Clicking a target executes the fold with correct animation
- Clicking empty area cancels selection

- [ ] **Step 2: Test equal-side fold (middle fold line)**

Find a level with a centered fold line (e.g., v2 on a 4x4 grid).

Verify:
- Edge cells on BOTH sides of the centered fold line are clickable
- Each side shows its correct target on the other side
- Folding from left to right works
- Folding from right to left also works

- [ ] **Step 3: Test diagonal fold**

Find a level with diagonal folds.

Verify:
- Diagonal fold lines appear as dashed lines extending beyond grid
- Edge cells affected by diagonal folds are clickable
- Target positions are correctly calculated
- Fold animation plays correctly

- [ ] **Step 4: Test undo/reset in SELECTED state**

Verify:
- While targets are glowing, pressing "撤销" cancels selection and undoes last fold
- While targets are glowing, pressing "重置" cancels selection and resets

- [ ] **Step 5: Test post-fold edge detection**

Verify:
- After folding column 0 away, cells in column 1 become clickable (new visual edge)

- [ ] **Step 6: Commit if all tests pass**

```bash
git add -A
git commit -m "feat: complete edge-cell fold interaction redesign"
```
