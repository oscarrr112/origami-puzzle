# Drag-to-Fold Design Spec

## Overview

Add drag-based folding interaction to the origami puzzle game. Users can drag from any grid cell to another; if a valid fold maps the start cell to the end cell, the fold executes. Coexists with the current two-click interaction.

## Requirements

- **Coexistence**: Drag and two-click (corner select → target click) both work simultaneously
- **Any cell as start**: Drag start is not limited to corners — any grid cell is valid
- **Minimal feedback**: No drag line, no real-time target highlighting. Valid fold executes on release; invalid drag is silently ignored.
- **Single match guaranteed**: For any pair of distinct cells, at most one fold definition can map source to target. V/H vs V/H, V/H vs diagonal, and same-type diagonals all yield contradictions or non-integer solutions when equating mirror formulas. Cross-type diagonals (d_bs + d_fs) produce solutions only on both fold lines simultaneously, which are excluded by the `side == -1` skip. Therefore no disambiguation is needed.

## Scope

- **Modified file**: `scripts/game.gd` only
- **No changes to**: `grid_model.gd`, `level_select.gd`, `tutorial_overlay.gd`, `main.gd`

## Design

### New State Variables

```gdscript
var _drag_start_cell: Vector2i = Vector2i(-1, -1)  # Grid coords of drag start
var _drag_start_pos: Vector2                         # Screen position of mouse down
var _is_dragging: bool = false                       # Whether drag threshold exceeded
```

### Drag Threshold

20 pixels. Below this, the gesture is treated as a click (existing logic). Above, it becomes a drag.

### _input() Restructuring

The existing `_input()` only handles `InputEventMouseButton` with `pressed == true` and early-returns on other event types. The restructured version must handle three event types: mouse button down, mouse motion, and mouse button up.

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
```

**_on_mouse_down(pos)**:
1. Guard: `if is_animating or not model.can_fold(): return`
2. Convert position to grid cell via `_pos_to_cell()`
3. If valid cell: store `_drag_start_cell`, `_drag_start_pos`, set `_is_dragging = false`

**_on_mouse_motion(event)**:
1. If `_drag_start_cell` is valid and `!_is_dragging`:
2. Check distance from `_drag_start_pos`
3. If > 20px: set `_is_dragging = true`, cancel any existing corner selection via `_cancel_selection()`

**_on_mouse_up(pos)**:
1. If `_is_dragging` and `_drag_start_cell` is valid:
   - Compute end cell from release position
   - If end cell is valid and different from start: call `_try_drag_fold(start, end)`
   - Reset drag state (`_drag_start_cell = Vector2i(-1, -1)`)
2. If not dragging:
   - Execute existing click logic (corner select / target select)
   - Reset drag state

### _try_drag_fold(from_cell, to_cell) -> bool

New function. Iterates `model.available_folds`:

```gdscript
func _try_drag_fold(from_cell: Vector2i, to_cell: Vector2i) -> bool:
    for fold_def in model.available_folds:
        var side := GridModel.get_fold_side(fold_def, from_cell.y, from_cell.x, model.size)
        if side == -1:  # On fold line — cell maps to itself, blocked by same-cell check
            continue
        var mirror := GridModel.get_mirror_pos(fold_def, from_cell.y, from_cell.x, model.size)
        if mirror == to_cell:
            var entry := fold_def.duplicate()
            entry["_force_side"] = side
            _on_fold_with_side(entry)
            return true
    return false
```

### Reused Functions (no modifications)

- `GridModel.get_mirror_pos()` — compute where a cell lands after a fold
- `GridModel.get_fold_side()` — determine which side of fold line a cell is on
- `_on_fold_with_side()` — execute fold with animation
- `_pos_to_cell()` — screen coords to grid coords
- `_cancel_selection()` — clear corner selection state

### Edge Cases

- **Drag starts outside grid**: `_drag_start_cell` stays (-1,-1), drag is ignored
- **Drag ends outside grid**: No valid end cell, fold not attempted
- **Drag to same cell**: `end_cell != start_cell` check prevents no-op
- **Start cell on fold line**: `side == -1` is skipped in `_try_drag_fold`. This is safe because diagonal fold-line cells map to themselves, and the same-cell check already prevents that
- **No folds remaining**: `can_fold()` guard in `_on_mouse_down` prevents starting a drag when folds are exhausted
- **State is FOLDING**: Early return at top of `_input()` prevents interaction during animation
- **Tutorial active**: Tutorial overlay consumes input events before they reach `_input()`
