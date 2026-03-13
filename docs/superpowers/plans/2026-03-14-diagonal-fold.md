# Diagonal Fold Mechanic Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add diagonal fold lines (`\` and `/`) with a 4-quadrant cell model that splits cells into triangular regions, while keeping all existing V/H fold levels working.

**Architecture:** Rewrite `grid_model.gd` to use a unified 4-quadrant cell representation (`[T,R,B,L]`) internally, with fold operations generalized across V, H, `\`, and `/` types. Update `game.gd` to render cells as 4 `Polygon2D` triangles instead of `ColorRect`, add diagonal fold line UI, and implement diagonal fold animation. Level JSON gains an optional `folds` array to specify available fold lines per level.

**Tech Stack:** Godot 4.6, GDScript, Polygon2D for triangle rendering

**Spec:** `docs/superpowers/specs/2026-03-14-diagonal-fold-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `scripts/grid_model.gd` | Rewrite | 4-quadrant cell model, all fold logic (V/H/diagonal), merge, normalize, win check |
| `scripts/game.gd` | Major modify | Polygon2D cell rendering, fold line UI from level config, diagonal animation, updated previews |
| `data/levels.json` | Minor modify | Add `folds` array to existing levels (backward compat: omit = all V+H) |
| `tools/level_generator.py` | Modify | Update fold simulator for 4-quadrant cells and diagonal folds |

---

## Chunk 1: Grid Model Rewrite

### Task 1: Rewrite grid_model.gd — Cell Helpers

Rewrite `scripts/grid_model.gd` with the new 4-quadrant cell model. Start with cell helper functions.

**Files:**
- Rewrite: `scripts/grid_model.gd`

- [ ] **Step 1: Write cell helper functions**

Replace the entire `scripts/grid_model.gd` with the new cell model foundation. Cells are stored internally as either `int` (full/empty) or `Array[int]` of 4 quadrants `[T, R, B, L]`.

```gdscript
class_name GridModel
extends RefCounted

const EMPTY := 0

# Quadrant indices
const Q_T := 0  # Top
const Q_R := 1  # Right
const Q_B := 2  # Bottom
const Q_L := 3  # Left

var size: int
var front: Array   # [row][col] of int or Array[int]
var back: Array
var target: Array
var max_folds: int
var folds_used: int = 0
var available_folds: Array = []  # Array of fold definitions from level JSON
var _history: Array = []


# ── Cell Helpers ──────────────────────────────────────────────────────

static func cell_to_quads(cell) -> Array:
	"""Expand any cell to [T, R, B, L] array."""
	if cell is Array:
		return cell.duplicate()
	var c := int(cell)
	return [c, c, c, c]


static func normalize_cell(quads: Array):
	"""If all 4 quadrants are the same, collapse to int. Otherwise return array."""
	if quads[0] == quads[1] and quads[1] == quads[2] and quads[2] == quads[3]:
		return quads[0]
	return quads


static func merge_quads(existing: Array, incoming: Array) -> Array:
	"""Per-quadrant merge: incoming non-zero overwrites existing."""
	var result := existing.duplicate()
	for i in range(4):
		if incoming[i] != EMPTY:
			result[i] = incoming[i]
	return result


static func is_empty_cell(cell) -> bool:
	if cell is Array:
		return cell[0] == EMPTY and cell[1] == EMPTY and cell[2] == EMPTY and cell[3] == EMPTY
	return int(cell) == EMPTY


static func get_cell_color(cell, quad_index: int) -> int:
	"""Get color of a specific quadrant."""
	if cell is Array:
		return int(cell[quad_index])
	return int(cell)
```

- [ ] **Step 2: Verify the file parses without errors**

Run: Open the project in Godot editor or run headless — confirm no parse errors in Output panel.

- [ ] **Step 3: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "refactor: rewrite grid_model.gd with 4-quadrant cell helpers"
```

---

### Task 2: Grid Model — Fold Transform Permutations

Add fold transform functions that permute quadrant indices for each fold type.

**Files:**
- Modify: `scripts/grid_model.gd`

- [ ] **Step 1: Add fold transform functions**

Append after the cell helpers section:

```gdscript
# ── Fold Transforms ──────────────────────────────────────────────────

static func transform_cell(cell, fold_type: String) -> Array:
	"""Apply quadrant permutation for a fold type. Returns [T,R,B,L]."""
	var q := cell_to_quads(cell)
	match fold_type:
		"v":
			return [q[Q_T], q[Q_L], q[Q_B], q[Q_R]]  # L↔R
		"h":
			return [q[Q_B], q[Q_R], q[Q_T], q[Q_L]]  # T↔B
		"d_bs":
			return [q[Q_L], q[Q_B], q[Q_R], q[Q_T]]  # T↔L, R↔B
		"d_fs":
			return [q[Q_R], q[Q_T], q[Q_L], q[Q_B]]  # T↔R, B↔L
		_:
			return q
```

- [ ] **Step 2: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "feat: add fold transform permutations for V/H/diagonal"
```

---

### Task 3: Grid Model — Setup and Grid I/O

Add setup, deep copy, grid parsing, and history (undo/reset) logic.

**Files:**
- Modify: `scripts/grid_model.gd`

- [ ] **Step 1: Add setup and grid management functions**

Append after fold transforms:

```gdscript
# ── Grid Setup & I/O ────────────────────────────────────────────────

func setup(p_size: int, p_front: Array, p_back: Array, p_target: Array,
		   p_max_folds: int, p_folds: Array = []) -> void:
	size = p_size
	front = _parse_grid(p_front)
	back = _parse_grid(p_back)
	target = _parse_grid(p_target)
	max_folds = p_max_folds
	folds_used = 0
	_history.clear()

	if p_folds.is_empty():
		# Backward compat: all V + H lines
		available_folds = []
		for i in range(1, size):
			available_folds.append({"type": "v", "pos": i})
			available_folds.append({"type": "h", "pos": i})
	else:
		available_folds = p_folds.duplicate(true)


func _parse_grid(data: Array) -> Array:
	"""Parse JSON grid: int stays int, array stays array."""
	var grid := []
	for row_data in data:
		var row := []
		for cell in row_data:
			if cell is Array:
				var quads := []
				for v in cell:
					quads.append(int(v))
				row.append(quads)
			else:
				row.append(int(cell))
		grid.append(row)
	return grid


func _deep_copy(grid: Array) -> Array:
	var copy := []
	for row_data in grid:
		var row := []
		for cell in row_data:
			if cell is Array:
				row.append(cell.duplicate())
			else:
				row.append(cell)
		copy.append(row)
	return copy


func _normalize_grid(grid: Array) -> void:
	"""Normalize all cells in-place: [c,c,c,c] → c."""
	for row in range(size):
		for col in range(size):
			var cell = grid[row][col]
			if cell is Array:
				grid[row][col] = normalize_cell(cell)


func can_fold() -> bool:
	return folds_used < max_folds


func undo() -> void:
	if _history.is_empty():
		return
	var state: Dictionary = _history.pop_back()
	front = state.front
	back = state.back
	folds_used = state.folds


func reset() -> void:
	if _history.is_empty():
		return
	var state: Dictionary = _history[0]
	front = _deep_copy(state.front)
	back = _deep_copy(state.back)
	folds_used = 0
	_history.clear()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "feat: add grid setup, parsing, deep copy, undo/reset"
```

---

### Task 4: Grid Model — V/H Fold Logic (updated for quadrant cells)

Rewrite V and H fold operations to work with the quadrant cell model.

**Files:**
- Modify: `scripts/grid_model.gd`

- [ ] **Step 1: Add the unified fold entry point and V/H fold functions**

```gdscript
# ── Fold Operations ──────────────────────────────────────────────────

func fold(fold_def: Dictionary) -> Dictionary:
	"""Execute a fold. fold_def has 'type' and 'pos' or 'offset'.
	   Returns animation data: {type, sources, targets, fold_line_cells, ...}."""
	if folds_used >= max_folds:
		return {}

	_history.append({
		"front": _deep_copy(front),
		"back": _deep_copy(back),
		"folds": folds_used
	})

	var result: Dictionary
	var fold_type: String = fold_def["type"]
	match fold_type:
		"v":
			result = _fold_vh(fold_type, int(fold_def["pos"]))
		"h":
			result = _fold_vh(fold_type, int(fold_def["pos"]))
		"d_bs":
			result = _fold_diagonal(fold_type, int(fold_def["offset"]))
		"d_fs":
			result = _fold_diagonal(fold_type, int(fold_def["offset"]))
		_:
			return {}

	_normalize_grid(front)
	_normalize_grid(back)
	folds_used += 1
	return result


func _fold_vh(fold_type: String, fold_pos: int) -> Dictionary:
	"""V or H fold. Returns {type, fold_pos, sources:[], targets:[]}."""
	var is_vert := (fold_type == "v")
	var result := {
		"type": fold_type,
		"fold_pos": fold_pos,
		"sources": [] as Array[Vector2i],
		"targets": [] as Array[Vector2i],
	}

	# Determine source range (smaller or equal side folds)
	var src_indices: Array[int] = []
	if is_vert:
		var left := fold_pos
		var right := size - fold_pos
		if left <= right:
			for i in range(fold_pos): src_indices.append(i)
		else:
			for i in range(fold_pos, size): src_indices.append(i)
	else:
		var top := fold_pos
		var bottom := size - fold_pos
		if top <= bottom:
			for i in range(fold_pos): src_indices.append(i)
		else:
			for i in range(fold_pos, size): src_indices.append(i)

	# Save original front/back for correct two-way transfer
	var orig_front := _deep_copy(front)
	var orig_back := _deep_copy(back)

	for idx in src_indices:
		var mirror := 2 * fold_pos - 1 - idx
		if mirror < 0 or mirror >= size:
			continue
		for other in range(size):
			var sr: int
			var sc: int
			var tr: int
			var tc: int
			if is_vert:
				sr = other; sc = idx; tr = other; tc = mirror
			else:
				sr = idx; sc = other; tr = mirror; tc = other

			result.sources.append(Vector2i(sc, sr))
			result.targets.append(Vector2i(tc, tr))

			# Transform source cell by fold type, then merge
			var src_front_xf := transform_cell(orig_front[sr][sc], fold_type)
			var src_back_xf := transform_cell(orig_back[sr][sc], fold_type)

			# front[source] → back[target]
			var tgt_back := cell_to_quads(back[tr][tc])
			back[tr][tc] = merge_quads(tgt_back, src_front_xf)
			# back[source] → front[target]
			var tgt_front := cell_to_quads(front[tr][tc])
			front[tr][tc] = merge_quads(tgt_front, src_back_xf)

			# Clear source
			front[sr][sc] = EMPTY
			back[sr][sc] = EMPTY

	return result
```

- [ ] **Step 2: Verify existing V/H levels still work**

Manually test levels 1-3 in the Godot editor (after game.gd is updated). Or test via the Python verifier after updating it.

- [ ] **Step 3: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "feat: unified fold entry point with updated V/H fold logic"
```

---

### Task 5: Grid Model — Diagonal Fold Logic

Add the diagonal fold implementation.

**Files:**
- Modify: `scripts/grid_model.gd`

- [ ] **Step 1: Add diagonal fold function**

```gdscript
func _fold_diagonal(fold_type: String, offset: int) -> Dictionary:
	"""Diagonal fold (d_bs or d_fs). Returns animation data."""
	var is_bs := (fold_type == "d_bs")
	var result := {
		"type": fold_type,
		"offset": offset,
		"sources": [] as Array[Vector2i],
		"targets": [] as Array[Vector2i],
		"fold_line_cells": [] as Array[Vector2i],  # cells on the diagonal
	}

	var orig_front := _deep_copy(front)
	var orig_back := _deep_copy(back)

	for row in range(size):
		for col in range(size):
			var val: int
			if is_bs:
				val = col - row
			else:
				val = col + row

			if is_bs and val > offset:
				# Source cell (upper-right region)
				_transfer_whole_cell(row, col, fold_type, offset, is_bs, orig_front, orig_back, result)
			elif is_bs and val < offset:
				pass  # Target region, untouched
			elif not is_bs and val < offset:
				# Source cell (upper-left region)
				_transfer_whole_cell(row, col, fold_type, offset, is_bs, orig_front, orig_back, result)
			elif not is_bs and val > offset:
				pass  # Target region, untouched
			else:
				# On the fold line (val == offset)
				_transfer_fold_line_cell(row, col, fold_type, offset, is_bs, orig_front, orig_back, result)

	return result


func _transfer_whole_cell(sr: int, sc: int, fold_type: String, offset: int,
						  is_bs: bool, orig_front: Array, orig_back: Array,
						  result: Dictionary) -> void:
	"""Transfer an entire source cell to its target position."""
	var tr: int
	var tc: int
	if is_bs:
		tr = sc - offset
		tc = sr + offset
	else:
		tr = offset - sc
		tc = offset - sr

	# Bounds check
	if tr < 0 or tr >= size or tc < 0 or tc >= size:
		# Source has no valid target — just clear it
		front[sr][sc] = EMPTY
		back[sr][sc] = EMPTY
		return

	result.sources.append(Vector2i(sc, sr))
	result.targets.append(Vector2i(tc, tr))

	var src_front_xf := transform_cell(orig_front[sr][sc], fold_type)
	var src_back_xf := transform_cell(orig_back[sr][sc], fold_type)

	var tgt_back := cell_to_quads(back[tr][tc])
	back[tr][tc] = merge_quads(tgt_back, src_front_xf)
	var tgt_front := cell_to_quads(front[tr][tc])
	front[tr][tc] = merge_quads(tgt_front, src_back_xf)

	front[sr][sc] = EMPTY
	back[sr][sc] = EMPTY


func _transfer_fold_line_cell(row: int, col: int, fold_type: String,
							  offset: int, is_bs: bool,
							  orig_front: Array, orig_back: Array,
							  result: Dictionary) -> void:
	"""Handle a cell sitting on the diagonal fold line — split by quadrant."""
	result.fold_line_cells.append(Vector2i(col, row))

	# Determine which quadrants are source vs target
	var src_quads: Array[int]  # quadrant indices that transfer
	var tgt_quads: Array[int]  # quadrant indices that stay
	if is_bs:
		src_quads = [Q_T, Q_R]  # upper-right half
		tgt_quads = [Q_B, Q_L]  # lower-left half
	else:
		src_quads = [Q_T, Q_L]  # upper-left half
		tgt_quads = [Q_B, Q_R]  # lower-right half

	var of := cell_to_quads(orig_front[row][col])
	var ob := cell_to_quads(orig_back[row][col])

	# Build incoming quads (only source quadrant values, rest zero)
	var incoming_front := [EMPTY, EMPTY, EMPTY, EMPTY]
	var incoming_back := [EMPTY, EMPTY, EMPTY, EMPTY]
	for qi in src_quads:
		incoming_front[qi] = of[qi]
		incoming_back[qi] = ob[qi]

	# Transform the incoming (src quads only) by fold type
	var xf_front := transform_cell(incoming_front, fold_type)
	var xf_back := transform_cell(incoming_back, fold_type)

	# The fold-line cell maps to itself, so merge onto self
	# front[source_quads] → back[self], back[source_quads] → front[self]
	var cur_back := cell_to_quads(back[row][col])
	back[row][col] = merge_quads(cur_back, xf_front)
	var cur_front := cell_to_quads(front[row][col])
	front[row][col] = merge_quads(cur_front, xf_back)

	# Clear source quadrants
	var f := cell_to_quads(front[row][col])
	var b := cell_to_quads(back[row][col])
	for qi in src_quads:
		f[qi] = EMPTY
		b[qi] = EMPTY
	front[row][col] = f
	back[row][col] = b
```

- [ ] **Step 2: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "feat: add diagonal fold logic with fold-line cell splitting"
```

---

### Task 6: Grid Model — Win Check (quadrant-aware)

Update the win check to compare cells that may be int or array.

**Files:**
- Modify: `scripts/grid_model.gd`

- [ ] **Step 1: Add quadrant-aware win check**

```gdscript
func check_win() -> bool:
	for row in range(size):
		for col in range(size):
			if not _cells_equal(front[row][col], target[row][col]):
				return false
	return true


static func _cells_equal(a, b) -> bool:
	"""Compare two cells (int or array) for equality."""
	var qa := cell_to_quads(a)
	var qb := cell_to_quads(b)
	return qa[0] == qb[0] and qa[1] == qb[1] and qa[2] == qb[2] and qa[3] == qb[3]
```

- [ ] **Step 2: Commit**

```bash
git add scripts/grid_model.gd
git commit -m "feat: quadrant-aware win check comparison"
```

---

## Chunk 2: Game Rendering & UI Updates

### Task 7: Game.gd — Polygon2D Cell Rendering

Replace `ColorRect` cells with 4 `Polygon2D` triangles per cell. When all quadrants share the same color, it looks identical to the old solid rectangle.

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Replace _build_main_grid with Polygon2D approach**

Each cell becomes a `Node2D` container with 4 `Polygon2D` children (T, R, B, L triangles). Update `cell_rects` to store these containers.

In `game.gd`, replace the `_build_main_grid` function and add triangle creation helpers:

```gdscript
# cell_rects stores Node2D containers; each has 4 Polygon2D children named "T","R","B","L"

func _build_main_grid() -> void:
	var s := model.size
	for row in range(s):
		var row_arr := []
		for col in range(s):
			var cell_node := _create_cell_node(
				_cell_pos(col, row), CELL_SIZE
			)
			add_child(cell_node)
			row_arr.append(cell_node)
		cell_rects.append(row_arr)


func _create_cell_node(pos: Vector2, cell_size: float) -> Node2D:
	"""Create a Node2D with 4 Polygon2D triangle children."""
	var node := Node2D.new()
	node.position = pos
	var half := cell_size / 2.0
	var cx := half
	var cy := half

	# T: top-left, top-right, center
	var t := Polygon2D.new()
	t.polygon = PackedVector2Array([Vector2(0, 0), Vector2(cell_size, 0), Vector2(cx, cy)])
	t.color = COLOR_MAP[0]
	t.name = "T"
	node.add_child(t)

	# R: top-right, bottom-right, center
	var r := Polygon2D.new()
	r.polygon = PackedVector2Array([Vector2(cell_size, 0), Vector2(cell_size, cell_size), Vector2(cx, cy)])
	r.color = COLOR_MAP[0]
	r.name = "R"
	node.add_child(r)

	# B: bottom-right, bottom-left, center
	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(cell_size, cell_size), Vector2(0, cell_size), Vector2(cx, cy)])
	b.color = COLOR_MAP[0]
	b.name = "B"
	node.add_child(b)

	# L: top-left, bottom-left, center
	var l := Polygon2D.new()
	l.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, cell_size), Vector2(cx, cy)])
	l.color = COLOR_MAP[0]
	l.name = "L"
	node.add_child(l)

	return node
```

- [ ] **Step 2: Update _refresh_grid to set per-quadrant colors**

```gdscript
func _refresh_grid() -> void:
	var s := model.size
	for row in range(s):
		for col in range(s):
			var cell_node: Node2D = cell_rects[row][col]
			_set_cell_colors(cell_node, model.front[row][col])
			# Refresh back preview
			if back_rects.size() > row and back_rects[row].size() > col:
				_set_preview_colors(back_rects[row][col], model.back[row][col])


func _set_cell_colors(cell_node: Node2D, cell) -> void:
	"""Set the 4 triangle colors from a cell value (int or array)."""
	var quads := GridModel.cell_to_quads(cell)
	cell_node.get_node("T").color = COLOR_MAP[quads[0]]
	cell_node.get_node("R").color = COLOR_MAP[quads[1]]
	cell_node.get_node("B").color = COLOR_MAP[quads[2]]
	cell_node.get_node("L").color = COLOR_MAP[quads[3]]
```

- [ ] **Step 3: Update _show_back to use quadrant colors**

```gdscript
func _show_back() -> void:
	var s := model.size
	for row in range(s):
		for col in range(s):
			var cell_node: Node2D = cell_rects[row][col]
			var front_cell = model.front[row][col]
			var back_cell = model.back[row][col]
			var bq := GridModel.cell_to_quads(back_cell)
			var fq := GridModel.cell_to_quads(front_cell)
			for qi in range(4):
				var quad_name: String = ["T", "R", "B", "L"][qi]
				var poly: Polygon2D = cell_node.get_node(quad_name)
				if bq[qi] != 0:
					poly.color = COLOR_MAP[bq[qi]].lerp(Color.WHITE, 0.3)
				elif fq[qi] == 0:
					poly.color = COLOR_MAP[0]
				else:
					poly.color = COLOR_MAP[fq[qi]].lerp(Color.WHITE, 0.5)
```

- [ ] **Step 4: Verify main grid renders correctly for existing levels**

Open Godot editor, run the game, check that levels 1-3 display correctly as solid-color rectangles (4 same-color triangles = visually identical to ColorRect).

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: replace ColorRect cells with Polygon2D triangles"
```

---

### Task 8: Game.gd — Preview Grids with Quadrant Support

Update target and back preview grids to render quadrant cells as 4 triangles.

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Rewrite preview cell creation and update**

Replace `_create_preview_cell` and `_set_preview_cell_color` with triangle-based versions:

```gdscript
func _create_preview_cell(cell, pos: Vector2) -> Node2D:
	"""Create a preview cell node (4 triangles at TARGET_CELL_SIZE scale)."""
	var node := _create_cell_node(pos, float(TARGET_CELL_SIZE))
	_set_preview_colors(node, cell)
	return node


func _set_preview_colors(cell_node: Node2D, cell) -> void:
	"""Set preview cell colors from a cell value."""
	var quads := GridModel.cell_to_quads(cell)
	cell_node.get_node("T").color = COLOR_MAP[quads[0]]
	cell_node.get_node("R").color = COLOR_MAP[quads[1]]
	cell_node.get_node("B").color = COLOR_MAP[quads[2]]
	cell_node.get_node("L").color = COLOR_MAP[quads[3]]
```

- [ ] **Step 2: Update _build_target_grid to pass cell value (not int)**

```gdscript
func _build_target_grid() -> void:
	var s := model.size
	var container := Node2D.new()
	container.position = TARGET_ORIGIN
	add_child(container)
	for row in range(s):
		var row_arr := []
		for col in range(s):
			var cell := _create_preview_cell(
				model.target[row][col],
				Vector2(col * (TARGET_CELL_SIZE + TARGET_GAP), row * (TARGET_CELL_SIZE + TARGET_GAP))
			)
			container.add_child(cell)
			row_arr.append(cell)
		target_rects.append(row_arr)
```

- [ ] **Step 3: Update _build_back_grid similarly**

```gdscript
func _build_back_grid() -> void:
	var lbl := Label.new()
	lbl.text = "背面"
	lbl.position = Vector2(BACK_ORIGIN.x, BACK_ORIGIN.y - 28)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(lbl)
	var s := model.size
	var container := Node2D.new()
	container.position = BACK_ORIGIN
	add_child(container)
	for row in range(s):
		var row_arr := []
		for col in range(s):
			var cell := _create_preview_cell(
				model.back[row][col],
				Vector2(col * (TARGET_CELL_SIZE + TARGET_GAP), row * (TARGET_CELL_SIZE + TARGET_GAP))
			)
			container.add_child(cell)
			row_arr.append(cell)
		back_rects.append(row_arr)
```

- [ ] **Step 4: Remove old Panel-based `_create_preview_cell(color_id, pos)` and `_set_preview_cell_color(panel, color_id)`**

Delete the two old functions that used `Panel` and `StyleBoxFlat`.

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: update preview grids with Polygon2D triangles"
```

---

### Task 9: Game.gd — Fold Line UI from Level Config

Replace hardcoded V/H fold lines with level-config-driven fold lines, including diagonal lines.

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Update start_level to pass folds to model**

```gdscript
func start_level(data: Dictionary) -> void:
	level_data = data
	model = GridModel.new()
	var folds_arr: Array = data.get("folds", [])
	model.setup(
		int(data["size"]),
		data["front"],
		data["back"],
		data["target"],
		int(data["max_folds"]),
		folds_arr
	)
	_build_all()
	_refresh_grid()
```

- [ ] **Step 2: Rewrite _build_fold_lines to iterate model.available_folds**

```gdscript
func _build_fold_lines() -> void:
	var s := model.size
	var total := float(s * CELL_SIZE + (s - 1) * CELL_GAP)

	for fold_def in model.available_folds:
		var ft: String = fold_def["type"]
		match ft:
			"v":
				_build_v_fold_line(int(fold_def["pos"]), total)
			"h":
				_build_h_fold_line(int(fold_def["pos"]), total)
			"d_bs":
				_build_diagonal_fold_line(ft, int(fold_def["offset"]), total)
			"d_fs":
				_build_diagonal_fold_line(ft, int(fold_def["offset"]), total)


func _build_v_fold_line(fold_pos: int, total: float) -> void:
	var x := GRID_ORIGIN.x + fold_pos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var line := Line2D.new()
	line.add_point(Vector2(x, GRID_ORIGIN.y))
	line.add_point(Vector2(x, GRID_ORIGIN.y + total))
	line.width = 2.0
	line.default_color = FOLD_LINE_COLOR
	add_child(line)
	fold_lines.append(line)

	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(x - FOLD_BTN_THICKNESS / 2.0, GRID_ORIGIN.y - 10)
	btn.size = Vector2(FOLD_BTN_THICKNESS, total + 20)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var def := {"type": "v", "pos": fold_pos}
	var line_ref := line
	btn.pressed.connect(func(): _on_fold(def))
	btn.mouse_entered.connect(func(): line_ref.default_color = FOLD_LINE_HOVER; line_ref.width = 4.0)
	btn.mouse_exited.connect(func(): line_ref.default_color = FOLD_LINE_COLOR; line_ref.width = 2.0)
	add_child(btn)
	fold_buttons.append(btn)


func _build_h_fold_line(fold_pos: int, total: float) -> void:
	var y := GRID_ORIGIN.y + fold_pos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var line := Line2D.new()
	line.add_point(Vector2(GRID_ORIGIN.x, y))
	line.add_point(Vector2(GRID_ORIGIN.x + total, y))
	line.width = 2.0
	line.default_color = FOLD_LINE_COLOR
	add_child(line)
	fold_lines.append(line)

	var btn := Button.new()
	btn.flat = true
	btn.position = Vector2(GRID_ORIGIN.x - 10, y - FOLD_BTN_THICKNESS / 2.0)
	btn.size = Vector2(total + 20, FOLD_BTN_THICKNESS)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var def := {"type": "h", "pos": fold_pos}
	var line_ref := line
	btn.pressed.connect(func(): _on_fold(def))
	btn.mouse_entered.connect(func(): line_ref.default_color = FOLD_LINE_HOVER; line_ref.width = 4.0)
	btn.mouse_exited.connect(func(): line_ref.default_color = FOLD_LINE_COLOR; line_ref.width = 2.0)
	add_child(btn)
	fold_buttons.append(btn)
```

- [ ] **Step 3: Add diagonal fold line builder**

```gdscript
func _build_diagonal_fold_line(fold_type: String, offset: int, total: float) -> void:
	"""Draw a dashed diagonal line and place a clickable button along it."""
	var is_bs := (fold_type == "d_bs")
	var s := model.size
	var step := CELL_SIZE + CELL_GAP

	# Compute the pixel start and end points of the diagonal line
	# For d_bs (\ direction): cells where col - row == offset
	# For d_fs (/ direction): cells where col + row == offset
	var points: Array[Vector2] = []
	for i in range(s + 1):
		var r_f: float
		var c_f: float
		if is_bs:
			# The \ line passes through corners where col = row + offset
			# Grid corner (i, i+offset) in cell coords
			r_f = float(i)
			c_f = float(i) + float(offset)
		else:
			# The / line passes through corners where col + row = offset
			r_f = float(i)
			c_f = float(offset) - float(i)

		if c_f < 0.0 or c_f > float(s) or r_f < 0.0 or r_f > float(s):
			continue

		var px := GRID_ORIGIN.x + c_f * step - (CELL_GAP * 0.5 if c_f > 0 and c_f < float(s) else 0.0)
		var py := GRID_ORIGIN.y + r_f * step - (CELL_GAP * 0.5 if r_f > 0 and r_f < float(s) else 0.0)
		# Simplified: use direct grid mapping
		px = GRID_ORIGIN.x + c_f * step
		py = GRID_ORIGIN.y + r_f * step
		points.append(Vector2(px, py))

	if points.size() < 2:
		return

	# Draw dashed line segments
	var line := Line2D.new()
	for pt in points:
		line.add_point(pt)
	line.width = 2.0
	line.default_color = FOLD_LINE_COLOR
	add_child(line)
	fold_lines.append(line)

	# Clickable buttons at each endpoint of the diagonal line (avoids overlapping V/H buttons)
	var def := {"type": fold_type, "offset": offset}
	var line_ref := line
	var btn_size := Vector2(FOLD_BTN_THICKNESS, FOLD_BTN_THICKNESS)
	for pt in [points[0], points[points.size() - 1]]:
		var btn := Button.new()
		btn.flat = true
		btn.position = pt - btn_size / 2.0
		btn.size = btn_size
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(func(): _on_fold(def))
		btn.mouse_entered.connect(func(): line_ref.default_color = FOLD_LINE_HOVER; line_ref.width = 4.0)
		btn.mouse_exited.connect(func(): line_ref.default_color = FOLD_LINE_COLOR; line_ref.width = 2.0)
		add_child(btn)
		fold_buttons.append(btn)
```

- [ ] **Step 4: Update _on_fold to accept fold_def dictionary**

```gdscript
func _on_fold(fold_def: Dictionary) -> void:
	if is_animating or not model.can_fold():
		return
	var result := model.fold(fold_def)
	if result.is_empty():
		return
	_animate_fold(result)
```

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: config-driven fold line UI with diagonal support"
```

---

### Task 10: Game.gd — Update Fold Animation

Update the fold animation to handle both V/H (existing flip animation) and diagonal (fade animation).

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Refactor _animate_fold to dispatch by fold type**

```gdscript
func _animate_fold(fold_data: Dictionary) -> void:
	is_animating = true
	_set_fold_buttons_enabled(false)

	var fold_type: String = fold_data["type"]
	match fold_type:
		"v", "h":
			await _animate_vh_fold(fold_data)
		"d_bs", "d_fs":
			await _animate_diagonal_fold(fold_data)

	_refresh_grid()
	_update_fold_label()
	_set_fold_buttons_enabled(true)
	is_animating = false

	if model.check_win():
		await get_tree().create_timer(0.5).timeout
		_show_win()
```

- [ ] **Step 2: Extract existing V/H animation into _animate_vh_fold**

Move the existing `_animate_fold` body (source/target pairs, flap creation, tween logic) into `_animate_vh_fold(fold_data)`. Key changes:
- `fold_data.is_vertical` → `fold_data.type == "v"`
- `fold_data.fold_pos` → `int(fold_data["fold_pos"])`
- `old_front[src.y][src.x]` must use `GridModel.cell_to_quads()` to read colors
- Flap cells rendered as `_create_cell_node()` instead of `ColorRect`

```gdscript
func _animate_vh_fold(fold_data: Dictionary) -> void:
	var sources: Array = fold_data.sources
	var targets: Array = fold_data.targets
	var is_vert: bool = (fold_data.type == "v")
	var fpos: int = fold_data.fold_pos

	var history_state: Dictionary = model._history[model._history.size() - 1]
	var old_front: Array = history_state.front

	# Collect unique source→target pairs
	var fold_pairs := []
	var seen := {}
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		var tgt: Vector2i = targets[i]
		var key := src.y * 100 + src.x
		if seen.has(key):
			continue
		seen[key] = true
		fold_pairs.append({"src": src, "tgt": tgt})

	var fold_px := 0.0
	if is_vert:
		fold_px = GRID_ORIGIN.x + fpos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0
	else:
		fold_px = GRID_ORIGIN.y + fpos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0

	# Hide source cells
	for pair in fold_pairs:
		var src: Vector2i = pair.src
		cell_rects[src.y][src.x].visible = false

	# Front flap (shows pre-fold front colors)
	var flap_front := Node2D.new()
	flap_front.z_index = 10
	flap_front.position = Vector2(fold_px, 0) if is_vert else Vector2(0, fold_px)
	add_child(flap_front)

	for pair in fold_pairs:
		var src: Vector2i = pair.src
		var cell_node := _create_cell_node(Vector2.ZERO, float(CELL_SIZE))
		_set_cell_colors(cell_node, old_front[src.y][src.x])
		var abs_pos := _cell_pos(src.x, src.y)
		if is_vert:
			cell_node.position = Vector2(abs_pos.x - fold_px, abs_pos.y)
		else:
			cell_node.position = Vector2(abs_pos.x, abs_pos.y - fold_px)
		flap_front.add_child(cell_node)

	# Back flap (shows post-fold target colors)
	var flap_back := Node2D.new()
	flap_back.z_index = 10
	flap_back.position = Vector2(fold_px, 0) if is_vert else Vector2(0, fold_px)
	if is_vert:
		flap_back.scale.x = 0.0
	else:
		flap_back.scale.y = 0.0
	flap_back.skew = 0.1
	add_child(flap_back)

	for pair in fold_pairs:
		var tgt: Vector2i = pair.tgt
		var cell_node := _create_cell_node(Vector2.ZERO, float(CELL_SIZE))
		_set_cell_colors(cell_node, model.front[tgt.y][tgt.x])
		var abs_pos := _cell_pos(tgt.x, tgt.y)
		if is_vert:
			cell_node.position = Vector2(abs_pos.x - fold_px, abs_pos.y)
		else:
			cell_node.position = Vector2(abs_pos.x, abs_pos.y - fold_px)
		flap_back.add_child(cell_node)

	# Shadow
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.0)
	shadow.z_index = 3
	var grid_total := float(model.size * (CELL_SIZE + CELL_GAP) - CELL_GAP)
	if is_vert:
		shadow.position = Vector2(fold_px + 3, GRID_ORIGIN.y + 3)
		shadow.size = Vector2(grid_total / 2.0, grid_total)
	else:
		shadow.position = Vector2(GRID_ORIGIN.x + 3, fold_px + 3)
		shadow.size = Vector2(grid_total, grid_total / 2.0)
	add_child(shadow)

	# Two-phase tween
	var fold_duration := 0.5
	var half := fold_duration / 2.0

	var tween1 := create_tween()
	tween1.set_parallel(true)
	tween1.set_ease(Tween.EASE_IN)
	tween1.set_trans(Tween.TRANS_SINE)
	if is_vert:
		tween1.tween_property(flap_front, "scale:x", 0.0, half)
	else:
		tween1.tween_property(flap_front, "scale:y", 0.0, half)
	tween1.tween_property(flap_front, "skew", 0.1, half)
	tween1.tween_property(shadow, "color:a", 0.12, half)
	await tween1.finished

	flap_front.visible = false

	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.set_ease(Tween.EASE_OUT)
	tween2.set_trans(Tween.TRANS_SINE)
	if is_vert:
		tween2.tween_property(flap_back, "scale:x", 1.0, half)
	else:
		tween2.tween_property(flap_back, "scale:y", 1.0, half)
	tween2.tween_property(flap_back, "skew", 0.0, half)
	tween2.tween_property(shadow, "color:a", 0.0, half)
	await tween2.finished

	flap_front.queue_free()
	flap_back.queue_free()
	shadow.queue_free()
	for pair in fold_pairs:
		var src: Vector2i = pair.src
		cell_rects[src.y][src.x].visible = true
```

- [ ] **Step 3: Add diagonal fade animation**

```gdscript
func _animate_diagonal_fold(fold_data: Dictionary) -> void:
	"""Simplified fade animation for diagonal folds."""
	var sources: Array = fold_data.sources
	var targets: Array = fold_data.targets

	# Phase 1: Fade out source cells
	var tweens := []
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		var cell_node: Node2D = cell_rects[src.y][src.x]
		cell_node.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(cell_node, "modulate:a", 0.0, 0.25)
		tweens.append(tw)

	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished

	# Snap to final state
	_refresh_grid()

	# Phase 2: Fade in affected target cells
	var target_set := {}
	for i in range(targets.size()):
		var tgt: Vector2i = targets[i]
		var key := tgt.y * 100 + tgt.x
		if not target_set.has(key):
			target_set[key] = tgt

	tweens.clear()
	for key in target_set:
		var tgt: Vector2i = target_set[key]
		var cell_node: Node2D = cell_rects[tgt.y][tgt.x]
		cell_node.modulate.a = 0.3
		var tw := create_tween()
		tw.tween_property(cell_node, "modulate:a", 1.0, 0.25)
		tweens.append(tw)

	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished

	# Restore all cell opacity after animation completes
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		cell_rects[src.y][src.x].modulate.a = 1.0
	if fold_data.has("fold_line_cells"):
		for flc in fold_data.fold_line_cells:
			cell_rects[flc.y][flc.x].modulate.a = 1.0
```

- [ ] **Step 4: Verify animation plays correctly for existing V/H levels**

Run levels 1-3 in the Godot editor. Confirm the flip animation still works.

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: fold animation with diagonal fade support"
```

---

## Chunk 3: Integration & Test Levels

### Task 11: Add Test Diagonal Levels

Add 2-3 diagonal fold levels to `data/levels.json` for testing.

**Files:**
- Modify: `data/levels.json`

- [ ] **Step 1: Design test levels by hand**

Level 25: Simple `\` main diagonal fold (size 4, 1 fold).
- Front: color 1 in upper-right triangle area `(0,1), (0,2), (0,3), (1,2), (1,3), (2,3)`
- Back: all empty
- Target: after `d_bs` offset=0 fold, upper-right folds to lower-left. Cells on diagonal get split.
- Available folds: `[{"type": "d_bs", "offset": 0}]`

Compute the target state:
- Source cells (col-row > 0): `(0,1), (0,2), (0,3), (1,2), (1,3), (2,3)`
  - `(r=0,c=1)` → target `(c-0, r+0)` = `(1, 0)` → front[1][0] stays empty, back[1][0] gets color 1
  - `(r=0,c=2)` → `(2, 0)` → back[2][0] = 1
  - `(r=0,c=3)` → `(3, 0)` → back[3][0] = 1
  - `(r=1,c=2)` → `(2, 1)` → back[2][1] = 1
  - `(r=1,c=3)` → `(3, 1)` → back[3][1] = 1
  - `(r=2,c=3)` → `(3, 2)` → back[3][2] = 1
- Wait, front→back transfer. So after fold:
  - `back[1][0] = 1`, `back[2][0] = 1`, etc.
  - `front` at those target positions gets `back[source]` which is 0, so stays 0.
  - Source cells cleared.
- Fold line cells (col-row == 0): `(0,0), (1,1), (2,2), (3,3)` — all empty, no change.
- Result: front = all empty. That won't work for a puzzle.

Let me design simpler test levels:

Level 25: "斜折" — d_bs fold with back colors
- Size: 4, max_folds: 1
- Front: all empty
- Back: color 1 at `(0,1), (0,2), (0,3), (1,2), (1,3), (2,3)` (upper-right triangle)
- After d_bs offset=0: back[source] → front[target]
  - `back(0,1)=1` → transform → front at `(1,0)` = 1
  - `back(0,2)=1` → front at `(2,0)` = 1
  - `back(0,3)=1` → front at `(3,0)` = 1
  - `back(1,2)=1` → front at `(2,1)` = 1
  - `back(1,3)=1` → front at `(3,1)` = 1
  - `back(2,3)=1` → front at `(3,2)` = 1
- Target: front = lower-left triangle filled with 1
  - `[[0,0,0,0],[1,0,0,0],[1,1,0,0],[1,1,1,0]]`
- Folds: `[{"type": "d_bs", "offset": 0}]`

Level 26: "反斜" — d_fs fold
- Size: 4, max_folds: 1
- Front: all empty
- Back: color 2 at `(0,0), (1,0), (1,1), (2,0), (2,1), (2,2)` (upper-left triangle, where col+row < 3)
- After d_fs offset=3: source is col+row < 3
  - `back(0,0)=2` → front at `(3-0, 3-0)` = `(3,3)` = 2
  - `back(1,0)=2` → front at `(3-0, 3-1)` = `(3,2)` = 2
  - `back(1,1)=2` → front at `(3-1, 3-1)` = `(2,2)` = 2
  - `back(2,0)=2` → front at `(3-0, 3-2)` = `(3,1)` = 2
  - `back(2,1)=2` → front at `(3-1, 3-2)` = `(2,1)` = 2
  - `back(2,2)=2` → front at `(3-2, 3-2)` = `(1,1)` = 2
- Target: lower-right triangle filled with 2
  - `[[0,0,0,0],[0,2,0,0],[0,2,2,0],[0,2,2,2]]`
  Wait, let me recheck. For d_fs: source (r,c) → target (offset-c, offset-r)
  - `(0,0)` → `(3, 3)` ✓
  - `(1,0)` → `(3, 2)` ✓
  - `(1,1)` → `(2, 2)` ✓
  - `(2,0)` → `(3, 1)` ✓
  - `(2,1)` → `(2, 1)` — this is itself! col+row = 3 = offset. It's on the fold line, not source!

  Let me recalculate. Source = col+row < 3.
  - `(2,0)`: col+row = 2 < 3 → source ✓, target = `(3, 1)`
  - `(2,1)`: col+row = 3 = offset → fold line, not source

  Fold line cells (col+row == 3): `(0,3), (1,2), (2,1), (3,0)`
  Source cells (col+row < 3): `(0,0), (0,1), (0,2), (1,0), (1,1), (2,0)`

  Back has color 2 at: `(0,0), (1,0), (1,1), (2,0)` (4 cells in source region)
  - `(0,0)` → `(3,3)`: front[3][3] = 2
  - `(1,0)` → `(3,2)`: front[3][2] = 2
  - `(1,1)` → `(2,2)`: front[2][2] = 2
  - `(2,0)` → `(3,1)`: front[3][1] = 2

  Target: `[[0,0,0,0],[0,0,0,0],[0,0,2,0],[0,2,2,2]]`
  Folds: `[{"type": "d_fs", "offset": 3}]`

Level 27: "切分" — diagonal fold that creates triangle cells
- Size: 4, max_folds: 1
- Front: color 1 at `(1,1)` (on the d_bs main diagonal, col-row=0)
- Back: all empty
- After d_bs offset=0: fold-line cell (1,1)
  - Source quadrants: T, R → front[1][1] quad T=1, R=1
  - Transform by d_bs: [1,1,0,0] → [0,0,1,1] (T→L, R→B, rest 0)
  - front→back transfer: back[1][1] merged with [0,0,1,1]
  - back→front transfer: back was empty, so nothing
  - Source quads cleared: front[1][1] has T=0, R=0, B stays 0, L stays 0 = all 0

  Hmm, the target would be front=all empty, back[1][1]=[0,0,1,1]. Not visible to player.

Let me make it more interesting with both front and back:
- Front: `(0,1)=1` (source, col-row=1>0), `(1,1)=1` (fold line)
- Back: `(1,1)=2` (fold line)
- d_bs offset=0:
  - Source `(0,1)`: target `(1,0)`. front[0][1]=1 → back[1][0]=1, back[0][1]=0 → front[1][0]=0. Clear source.
  - Fold line `(1,1)`:
    - Source quads T,R of front = [1,1,...] → incoming_front = [1,1,0,0]
    - Source quads T,R of back = [2,2,...] → incoming_back = [2,2,0,0]
    - Transform incoming_front by d_bs: [1,1,0,0] → [0,0,1,1]
    - Transform incoming_back by d_bs: [2,2,0,0] → [0,0,2,2]
    - front→back: merge back[1][1] with [0,0,1,1] → back[1][1]=[0,0,1,1] (was [2,2,2,2], but we're merging onto current)

    Wait, I need to be more careful. Let me just make simple levels for now.

```json
{
  "id": 25,
  "name": "斜折",
  "size": 4,
  "max_folds": 1,
  "front": [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]],
  "back": [[0,1,1,1],[0,0,1,1],[0,0,0,1],[0,0,0,0]],
  "target": [[0,0,0,0],[1,0,0,0],[1,1,0,0],[1,1,1,0]],
  "folds": [{"type": "d_bs", "offset": 0}]
},
{
  "id": 26,
  "name": "反斜",
  "size": 4,
  "max_folds": 1,
  "front": [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]],
  "back": [[2,0,0,0],[2,2,0,0],[2,0,0,0],[0,0,0,0]],
  "target": [[0,0,0,0],[0,0,0,0],[0,0,2,0],[0,2,2,2]],
  "folds": [{"type": "d_fs", "offset": 3}]
}
```

- [ ] **Step 2: Add the test levels to data/levels.json**

Append the two level objects to the `"levels"` array in `data/levels.json`.

- [ ] **Step 3: Run the game, test level 25 and 26**

Verify:
1. Diagonal fold lines render correctly
2. Clicking the diagonal line triggers the fold
3. The fade animation plays
4. The resulting grid matches the target
5. Win check triggers

- [ ] **Step 4: Commit**

```bash
git add data/levels.json
git commit -m "feat: add 2 diagonal fold test levels (25-26)"
```

---

### Task 12: Update Python Level Generator for Diagonal Folds

Update `tools/level_generator.py` to support the 4-quadrant model and diagonal fold simulation, enabling verification of diagonal levels.

**Files:**
- Modify: `tools/level_generator.py`

- [ ] **Step 1: Add quadrant cell helpers**

Add at the top of the file, after `EMPTY = 0`:

```python
# Quadrant indices: T=0, R=1, B=2, L=3
def cell_to_quads(cell):
    if isinstance(cell, list):
        return list(cell)
    return [cell, cell, cell, cell]

def normalize_cell(quads):
    if quads[0] == quads[1] == quads[2] == quads[3]:
        return quads[0]
    return quads

def merge_quads(existing, incoming):
    return [incoming[i] if incoming[i] != EMPTY else existing[i] for i in range(4)]

TRANSFORMS = {
    "v": lambda q: [q[0], q[3], q[2], q[1]],       # L↔R
    "h": lambda q: [q[2], q[1], q[0], q[3]],       # T↔B
    "d_bs": lambda q: [q[3], q[2], q[1], q[0]],    # T↔L, R↔B
    "d_fs": lambda q: [q[1], q[0], q[3], q[2]],    # T↔R, B↔L
}

def transform_cell(cell, fold_type):
    return TRANSFORMS[fold_type](cell_to_quads(cell))
```

- [ ] **Step 2: Add diagonal fold function**

```python
def fold_diagonal(front, back, size, fold_type, offset):
    """Perform a diagonal fold, returning new (front, back)."""
    f = copy.deepcopy(front)
    b = copy.deepcopy(back)
    orig_f = copy.deepcopy(front)
    orig_b = copy.deepcopy(back)
    is_bs = (fold_type == "d_bs")

    for row in range(size):
        for col in range(size):
            val = col - row if is_bs else col + row
            if (is_bs and val > offset) or (not is_bs and val < offset):
                # Source cell
                if is_bs:
                    tr, tc = col - offset, row + offset
                else:
                    tr, tc = offset - col, offset - row
                if tr < 0 or tr >= size or tc < 0 or tc >= size:
                    f[row][col] = EMPTY
                    b[row][col] = EMPTY
                    continue
                src_f_xf = transform_cell(orig_f[row][col], fold_type)
                src_b_xf = transform_cell(orig_b[row][col], fold_type)
                tgt_b = cell_to_quads(b[tr][tc])
                b[tr][tc] = normalize_cell(merge_quads(tgt_b, src_f_xf))
                tgt_f = cell_to_quads(f[tr][tc])
                f[tr][tc] = normalize_cell(merge_quads(tgt_f, src_b_xf))
                f[row][col] = EMPTY
                b[row][col] = EMPTY
            elif val == offset:
                # Fold line cell
                src_quads = [0, 1] if is_bs else [0, 3]  # T,R or T,L
                of = cell_to_quads(orig_f[row][col])
                ob = cell_to_quads(orig_b[row][col])
                inc_f = [of[i] if i in src_quads else EMPTY for i in range(4)]
                inc_b = [ob[i] if i in src_quads else EMPTY for i in range(4)]
                xf_f = transform_cell(inc_f, fold_type)
                xf_b = transform_cell(inc_b, fold_type)
                cur_b = cell_to_quads(b[row][col])
                b[row][col] = normalize_cell(merge_quads(cur_b, xf_f))
                cur_f = cell_to_quads(f[row][col])
                f[row][col] = normalize_cell(merge_quads(cur_f, xf_b))
                ff = cell_to_quads(f[row][col])
                fb = cell_to_quads(b[row][col])
                for qi in src_quads:
                    ff[qi] = EMPTY
                    fb[qi] = EMPTY
                f[row][col] = normalize_cell(ff)
                b[row][col] = normalize_cell(fb)
    return f, b
```

- [ ] **Step 3: Update fold_grid and apply_folds to handle all fold types**

```python
def fold_grid_any(front, back, size, fold_def):
    """Perform any fold type from a fold definition dict."""
    ft = fold_def.get("type", "v" if fold_def.get(0, True) else "h")
    if ft in ("v", "h"):
        pos = fold_def.get("pos", fold_def.get(1, 1))
        return fold_grid(front, back, size, ft == "v", pos)
    else:
        return fold_diagonal(front, back, size, ft, fold_def["offset"])


def apply_folds_any(front, back, size, fold_sequence):
    """Apply a sequence of fold defs."""
    f, b = copy.deepcopy(front), copy.deepcopy(back)
    for fold_def in fold_sequence:
        f, b = fold_grid_any(f, b, size, fold_def)
    return f, b
```

- [ ] **Step 4: Update check_win for quadrant comparison**

```python
def check_win(front, target, size):
    for r in range(size):
        for c in range(size):
            fq = cell_to_quads(front[r][c])
            tq = cell_to_quads(target[r][c])
            if fq != tq:
                return False
    return True
```

- [ ] **Step 5: Update verify_level to handle levels with folds field**

```python
def verify_level(level_data):
    front = level_data["front"]
    back = level_data["back"]
    target = level_data["target"]
    size = level_data["size"]
    max_folds = level_data["max_folds"]
    folds = level_data.get("folds", None)

    if folds:
        # Try all permutations of available folds up to max_folds
        sols = []
        for length in range(1, max_folds + 1):
            for seq in itertools.product(folds, repeat=length):
                f, _ = apply_folds_any(front, back, size, list(seq))
                if check_win(f, target, size):
                    sols.append(list(seq))
        return len(sols) > 0, sols
    else:
        sols = find_solutions(front, back, target, size, max_folds)
        return len(sols) > 0, sols
```

- [ ] **Step 6: Run verification on all levels including the new diagonal ones**

Run: `python3 tools/level_generator.py verify data/levels.json`
Expected: All 26 levels pass (✓).

- [ ] **Step 7: Commit**

```bash
git add tools/level_generator.py
git commit -m "feat: update level generator with diagonal fold support"
```

---

### Task 13: End-to-End Testing & Polish

Final integration testing and cleanup.

**Files:**
- All modified files

- [ ] **Step 1: Test all existing levels (1-24) still work**

Run the game, click through levels 1, 5, 10, 15, 20, 24 to verify:
- Grid renders correctly (solid rectangles, no visual artifacts)
- V/H fold animation works
- Win detection works
- Undo/reset works

- [ ] **Step 2: Test diagonal levels (25-26)**

- Diagonal fold line visible on grid
- Clicking diagonal fold line triggers fold
- Fade animation plays smoothly
- Target grid shows correct result
- Win popup appears

- [ ] **Step 3: Test undo/reset with diagonal folds**

- After diagonal fold → undo → grid returns to pre-fold state
- After diagonal fold → reset → grid returns to initial state

- [ ] **Step 4: Fix any issues found**

Address bugs discovered during testing.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete diagonal fold mechanic implementation"
```
