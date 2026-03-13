# Diagonal Fold Mechanic Design

## Overview

Add diagonal fold lines to the origami puzzle game, enabling cells to be split into triangular regions. Each level presets which fold lines (V, H, diagonal) are available.

## Cell Model: 4-Quadrant

Both diagonals (`\` and `/`) divide each cell into 4 kite-shaped quadrants:

```
    +----------+
    |\   T   / |
    |  \   /   |
    | L  X  R  |
    |  /   \   |
    |/   B   \ |
    +----------+
```

**Representation:**
- `int 0` → empty cell `[0,0,0,0]`
- `int 1-3` → full color `[c,c,c,c]`
- `[T, R, B, L]` → 4 quadrant colors (each 0-3)

**Canonical forms:**
- `\` split (upper-right=a, lower-left=b): `[a, a, b, b]`
- `/` split (upper-left=a, lower-right=b): `[a, b, b, a]`
- Full cell: `[c, c, c, c]` → normalize to `c` (int)
- All empty: `[0, 0, 0, 0]` → normalize to `0` (int)

**Normalization policy:** The grid model stores cells as either `int` (full/empty) or `Array` (quadrants). Normalization (`[c,c,c,c]` → `int c`, `[0,0,0,0]` → `int 0`) is applied at the end of each fold operation, after all transfers and merges are complete. This keeps internal representation clean and simplifies win-check comparisons. During a fold's transfer phase, all cells are temporarily treated as 4-quadrant arrays.

## Fold Types

### V and H folds (existing)

Same mechanics as before. When moving a quadrant cell, apply index permutation:
- **V fold** (horizontal flip): `[T,R,B,L]` → `[T,L,B,R]` (L↔R)
- **H fold** (vertical flip): `[T,R,B,L]` → `[B,R,T,L]` (T↔B)

### Diagonal folds (new)

Parametrized by direction (`\` or `/`) and offset:
- `d_bs` (`\` direction): offset = col - row. Offset 0 = main diagonal.
- `d_fs` (`/` direction): offset = col + row. Offset size-1 = main anti-diagonal.

**Source/target determination** (fixed direction — source always folds toward the diagonal line):
- `d_bs` offset=k: source = cells where `col - row > k` (upper-right region), target = `col - row < k` (lower-left region). Upper-right always folds onto lower-left.
- `d_fs` offset=k: source = cells where `col + row < k` (upper-left region), target = `col + row > k` (lower-right region). Upper-left always folds onto lower-right.

**Valid offset ranges:**
- `d_bs`: `k` in `[-(size-2), size-2]`. `k=0` is the main diagonal. Positive k shifts toward upper-right, negative toward lower-left.
- `d_fs`: `k` in `[1, 2*(size-1)-1]`. `k=size-1` is the main anti-diagonal.
- Offsets at the extremes (`-(size-1)` or `size-1` for `d_bs`, `0` or `2*(size-1)` for `d_fs`) produce zero source cells and are invalid fold lines.

**Cell transforms when moved by diagonal fold:**
- **`\` fold**: `[T,R,B,L]` → `[L,B,R,T]` (T↔L, R↔B)
- **`/` fold**: `[T,R,B,L]` → `[R,T,L,B]` (T↔R, B↔L)

**Position mapping:**
- `\` fold at offset k: source `(r, c)` → target `(c - k, r + k)` (reflection across `\` line)
- `/` fold at offset k: source `(r, c)` → target `(k - c, k - r)` (reflection across `/` line)

**Bounds check:** After computing the target position, discard any mapping where `tr < 0 || tr >= size || tc < 0 || tc >= size`. This naturally occurs for off-center diagonal folds where the source region extends beyond the grid's reflection.

**Cells on the fold line** get split:
- For `\` fold at offset k: cells where `col - row == k`
  - Source quadrants: T, R (upper-right half)
  - Target quadrants: B, L (lower-left half)
  - Source quadrants transfer and are cleared; target quadrants stay
- For `/` fold at offset k: cells where `col + row == k`
  - Source quadrants: T, L (upper-left half)
  - Target quadrants: B, R (lower-right half)

## Transfer Rules

Same as existing V/H but generalized:

For each source cell `(sr, sc)` mapping to target `(tr, tc)`:
1. Transform `front[sr][sc]` by fold type → merge onto `back[tr][tc]`
2. Transform `back[sr][sc]` by fold type → merge onto `front[tr][tc]`
3. Clear `front[sr][sc]` and `back[sr][sc]`

For cells on the fold line, this applies per-quadrant (source quadrants transfer, target quadrants stay).

**Merge rule:** per-quadrant, incoming non-zero overwrites existing. This is intentional — when a fold-line cell's source quadrants transfer onto an existing target cell, the incoming color takes priority. Level designers should account for this overwrite behavior.

## Rendering

Each cell rendered as 4 `Polygon2D` triangles sharing the center point `(CELL/2, CELL/2)`:
- T: `(0,0), (CELL,0), (CELL/2, CELL/2)`
- R: `(CELL,0), (CELL,CELL), (CELL/2, CELL/2)`
- B: `(CELL,CELL), (0,CELL), (CELL/2, CELL/2)`
- L: `(0,0), (0,CELL), (CELL/2, CELL/2)`

When all 4 quadrants share the same color, visually identical to a solid rectangle.

Preview grids (target, back) use the same approach at smaller scale.

## UI: Fold Line Buttons

Each level's `available_folds` determines which fold lines and buttons appear:
- **V/H**: existing line + button rendering, unchanged
- **Diagonal**: dashed line along the diagonal path, clickable button at each end

## Animation

- **V/H folds**: keep existing two-phase flip animation
- **Diagonal folds**: simplified fade animation (source fades out → result fades in). Can be upgraded to triangular flip later.

## Level JSON Format

```json
{
  "id": 25,
  "name": "example",
  "size": 4,
  "max_folds": 1,
  "front": [[0,0,0,1],[0,0,0,1],[0,0,0,0],[0,0,0,0]],
  "back":  [[0,0,2,0],[0,0,2,0],[0,0,0,0],[0,0,0,0]],
  "target": [[0,0,[2,2,1,1],0],[0,0,[2,2,1,1],0],[0,0,0,0],[0,0,0,0]],
  "folds": [
    {"type": "v", "pos": 2},
    {"type": "h", "pos": 1},
    {"type": "d_bs", "offset": 0},
    {"type": "d_fs", "offset": 3}
  ]
}
```

- `front`/`back`: pure int grids (initial state is always full cells)
- `target`: int or `[T,R,B,L]` arrays
- `folds`: available fold operations. Omitted = all V + H lines (backward compatible).

## Win Check

Compare front grid to target. Each cell comparison:
- Both int: direct `==`
- One int, one array: expand int to `[c,c,c,c]`, compare per-quadrant
- Both array: compare per-quadrant

## Files Changed

- `scripts/grid_model.gd` — complete rewrite: 4-quadrant cell model, diagonal fold logic, updated V/H fold logic, cell helpers
- `scripts/game.gd` — rendering (Polygon2D triangles), fold line UI from level config, diagonal animation, updated preview grids
- `data/levels.json` — add `folds` field to levels that need diagonals; existing levels keep working (no `folds` = all V+H)
