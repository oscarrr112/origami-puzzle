# Drag-to-Fold Design Spec

## Overview

Add drag-based folding interaction to the origami puzzle game. Users can drag from any grid cell to another; if a valid fold maps the start cell to the end cell, the fold executes. Coexists with the current two-click interaction.

## Requirements

- **Coexistence**: Drag and two-click (corner select → target click) both work simultaneously
- **Any cell as start**: Drag start is not limited to corners — any grid cell is valid
- **Minimal feedback**: Only highlight the start cell on press; no drag line or real-time target highlighting
- **Single match guaranteed**: Mathematically proven that at most one fold definition can map a given source cell to a given target cell, so no disambiguation needed

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

### _input() Changes

The existing `_input()` handles `InputEventMouseButton` (pressed only). The redesigned version:

**Mouse button down (left)**:
1. Convert position to grid cell via `_pos_to_cell()`
2. If valid cell: store `_drag_start_cell`, `_drag_start_pos`, set `_is_dragging = false`
3. Apply subtle highlight to start cell

**Mouse motion**:
1. If `_drag_start_cell` is valid and `!_is_dragging`:
2. Check distance from `_drag_start_pos`
3. If > 20px: set `_is_dragging = true`, cancel any existing corner selection via `_cancel_selection()`

**Mouse button up (left)**:
1. If `_is_dragging` and `_drag_start_cell` is valid:
   - Compute end cell from release position
   - If end cell is valid and different from start: call `_try_drag_fold(start, end)`
   - Clear highlight, reset drag state
2. If not dragging:
   - Execute existing click logic (corner select / target select)
   - Reset drag state

### _try_drag_fold(from_cell, to_cell) -> bool

New function. Iterates `model.available_folds`:

```
for fold_def in model.available_folds:
    side = GridModel.get_fold_side(fold_def, from_cell.y, from_cell.x, model.size)
    if side == -1:  # On fold line
        continue
    mirror = GridModel.get_mirror_pos(fold_def, from_cell.y, from_cell.x, model.size)
    if mirror == to_cell:
        _on_fold_with_side(fold_def_with_side)  # Reuse existing fold execution
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
- **State is FOLDING**: Early return at top of `_input()` prevents interaction during animation
- **Tutorial active**: Tutorial overlay consumes input events before they reach `_input()`
