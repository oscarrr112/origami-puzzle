# Drag-to-Fold Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add drag-based folding so users can drag from any grid cell to another to execute a fold, coexisting with the current two-click interaction.

**Architecture:** Restructure `_input()` in `game.gd` to handle mouse down/motion/up events. Track drag state with 3 new variables. On release, match the drag vector against available folds using existing `get_mirror_pos()`/`get_fold_side()`.

**Tech Stack:** GDScript (Godot 4.6)

---

## Chunk 1: Implementation

### Task 1: Add drag state variables

**Files:**
- Modify: `scripts/game.gd:37-40` (after existing state variables)

- [ ] **Step 1: Add the three new variables after `_highlight_nodes`**

Insert after line 40 (`var _tutorial: TutorialOverlay = null`):

```gdscript
var _drag_start_cell: Vector2i = Vector2i(-1, -1)
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
const DRAG_THRESHOLD := 20.0
```

- [ ] **Step 2: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: add drag state variables for drag-to-fold"
```

---

### Task 2: Add `_try_drag_fold()` function

**Files:**
- Modify: `scripts/game.gd` (insert after `_compute_targets` function, around line 627)

- [ ] **Step 1: Add the new function after `_compute_targets()`**

Insert after the `_compute_targets` function (after line 626):

```gdscript
## Attempt to fold by matching drag start→end against available folds.
func _try_drag_fold(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	for fold_def in model.available_folds:
		var side := GridModel.get_fold_side(fold_def, from_cell.y, from_cell.x, model.size)
		if side == -1:
			continue
		var mirror := GridModel.get_mirror_pos(fold_def, from_cell.y, from_cell.x, model.size)
		if mirror == to_cell:
			var entry := fold_def.duplicate()
			entry["_force_side"] = side
			_on_fold_with_side(entry)
			return true
	return false
```

- [ ] **Step 2: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: add _try_drag_fold() matching function"
```

---

### Task 3: Restructure `_input()` into down/motion/up handlers

**Files:**
- Modify: `scripts/game.gd:550-577` (replace existing `_input` function)

- [ ] **Step 1: Replace `_input()` with the restructured version**

Replace the existing `_input` function (lines 550–577) with:

```gdscript
func _input(event: InputEvent) -> void:
	if _state == InteractionState.FOLDING:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_on_mouse_down(mb.position)
		else:
			_on_mouse_up(mb.position)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)


func _on_mouse_down(pos: Vector2) -> void:
	if is_animating or not model.can_fold():
		return
	var cell := _pos_to_cell(pos)
	if cell.x >= 0:
		_drag_start_cell = cell
		_drag_start_pos = pos
		_is_dragging = false


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _drag_start_cell == Vector2i(-1, -1) or _is_dragging:
		return
	if event.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
		_is_dragging = true
		if _state == InteractionState.SELECTED:
			_cancel_selection()


func _on_mouse_up(pos: Vector2) -> void:
	if _is_dragging and _drag_start_cell != Vector2i(-1, -1):
		var end_cell := _pos_to_cell(pos)
		if end_cell.x >= 0 and end_cell != _drag_start_cell:
			_try_drag_fold(_drag_start_cell, end_cell)
		_drag_start_cell = Vector2i(-1, -1)
		_is_dragging = false
		get_viewport().set_input_as_handled()
		return

	# Not a drag — run existing click logic
	_drag_start_cell = Vector2i(-1, -1)
	_is_dragging = false

	if is_animating or not model.can_fold():
		return
	var cell := _pos_to_cell(pos)

	match _state:
		InteractionState.IDLE:
			if cell.x >= 0 and _is_clickable_cell(cell.y, cell.x):
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

- [ ] **Step 2: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: restructure _input() to support drag-to-fold interaction"
```

---

### Task 4: Manual testing

- [ ] **Step 1: Run the game in Godot editor**

Open the project in Godot, run the game, and test:

1. **Drag fold works**: On any level, drag from a cell to its mirror position across a fold line → fold executes with animation
2. **Click still works**: Click a corner → gold highlights appear → click target → fold executes
3. **Invalid drag ignored**: Drag between cells with no valid fold → nothing happens
4. **Drag outside grid**: Start drag inside grid, release outside → nothing happens
5. **Short drag = click**: Click (no drag motion) on a corner → still triggers corner selection
6. **Drag during SELECTED state**: Select a corner, then drag → selection cancels, drag proceeds
7. **No folds remaining**: Use all folds, then try to drag → nothing happens
8. **Undo after drag fold**: Perform a drag fold, then click undo → fold reverts correctly

- [ ] **Step 2: Final commit if any fixes needed**
