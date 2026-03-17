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


# ── Fold Operations ──────────────────────────────────────────────────

func fold(fold_def: Dictionary, force_side: int = -1) -> Dictionary:
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
			result = _fold_vh(fold_type, int(fold_def["pos"]), force_side)
		"h":
			result = _fold_vh(fold_type, int(fold_def["pos"]), force_side)
		"d_bs":
			result = _fold_diagonal(fold_type, int(fold_def["offset"]), force_side)
		"d_fs":
			result = _fold_diagonal(fold_type, int(fold_def["offset"]), force_side)
		_:
			return {}

	_normalize_grid(front)
	_normalize_grid(back)
	folds_used += 1
	return result


func _fold_vh(fold_type: String, fold_pos: int, force_side: int = -1) -> Dictionary:
	var is_vert := (fold_type == "v")
	var result := {
		"type": fold_type,
		"fold_pos": fold_pos,
		"sources": [] as Array[Vector2i],
		"targets": [] as Array[Vector2i],
	}

	var src_indices: Array[int] = []
	if is_vert:
		var left := fold_pos
		var right := size - fold_pos
		var fold_left: bool
		if force_side == 0:
			fold_left = true
		elif force_side == 1:
			fold_left = false
		else:
			fold_left = (left <= right)
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

	var orig_front := _deep_copy(front)
	var orig_back := _deep_copy(back)

	for idx in src_indices:
		var mirror := 2 * fold_pos - 1 - idx
		if mirror < 0 or mirror >= size:
			continue
		for other in range(size):
			var sr: int
			var sc: int
			var target_r: int
			var target_c: int
			if is_vert:
				sr = other; sc = idx; target_r = other; target_c = mirror
			else:
				sr = idx; sc = other; target_r = mirror; target_c = other

			result.sources.append(Vector2i(sc, sr))
			result.targets.append(Vector2i(target_c, target_r))

			var src_front_xf := transform_cell(orig_front[sr][sc], fold_type)
			var src_back_xf := transform_cell(orig_back[sr][sc], fold_type)

			var tgt_back := cell_to_quads(back[target_r][target_c])
			back[target_r][target_c] = merge_quads(tgt_back, src_front_xf)
			var tgt_front := cell_to_quads(front[target_r][target_c])
			front[target_r][target_c] = merge_quads(tgt_front, src_back_xf)

			front[sr][sc] = EMPTY
			back[sr][sc] = EMPTY

	return result


func _fold_diagonal(fold_type: String, offset: int, force_side: int = -1) -> Dictionary:
	var is_bs := (fold_type == "d_bs")
	var result := {
		"type": fold_type,
		"offset": offset,
		"sources": [] as Array[Vector2i],
		"targets": [] as Array[Vector2i],
		"fold_line_cells": [] as Array[Vector2i],
	}

	# Count cells on each side to fold the smaller side (like VH folds)
	# Side A: upper-right for d_bs (val > offset), upper-left for d_fs (val < offset)
	# Side B: lower-left for d_bs (val < offset), lower-right for d_fs (val > offset)
	var count_a := 0
	var count_b := 0
	for row in range(size):
		for col in range(size):
			var val: int = (col - row) if is_bs else (col + row)
			if val > offset:
				if is_bs: count_a += 1
				else: count_b += 1
			elif val < offset:
				if is_bs: count_b += 1
				else: count_a += 1

	var fold_side_a: bool
	if force_side == 0:
		fold_side_a = true
	elif force_side == 1:
		fold_side_a = false
	else:
		fold_side_a = (count_a <= count_b)

	# Determine source quadrants for fold-line cells
	var src_quads: Array[int] = []
	if is_bs:
		if fold_side_a:
			src_quads = [Q_T, Q_R]
		else:
			src_quads = [Q_B, Q_L]
	else:
		if fold_side_a:
			src_quads = [Q_T, Q_L]
		else:
			src_quads = [Q_B, Q_R]

	var src_quad_names: Array[String] = []
	for qi in src_quads:
		src_quad_names.append(["T", "R", "B", "L"][qi])
	result["src_quad_names"] = src_quad_names

	var orig_front := _deep_copy(front)
	var orig_back := _deep_copy(back)

	for row in range(size):
		for col in range(size):
			var val: int = (col - row) if is_bs else (col + row)

			if val == offset:
				_transfer_fold_line_cell(row, col, fold_type, offset, is_bs, orig_front, orig_back, result, src_quads)
			else:
				var is_side_a: bool = (val > offset) if is_bs else (val < offset)
				if (is_side_a and fold_side_a) or (not is_side_a and not fold_side_a):
					_transfer_whole_cell(row, col, fold_type, offset, is_bs, orig_front, orig_back, result)

	return result


func _transfer_whole_cell(sr: int, sc: int, fold_type: String, offset: int,
						  is_bs: bool, orig_front: Array, orig_back: Array,
						  result: Dictionary) -> void:
	var target_r: int
	var target_c: int
	if is_bs:
		target_r = sc - offset
		target_c = sr + offset
	else:
		target_r = offset - sc
		target_c = offset - sr

	if target_r < 0 or target_r >= size or target_c < 0 or target_c >= size:
		front[sr][sc] = EMPTY
		back[sr][sc] = EMPTY
		return

	result.sources.append(Vector2i(sc, sr))
	result.targets.append(Vector2i(target_c, target_r))

	var src_front_xf := transform_cell(orig_front[sr][sc], fold_type)
	var src_back_xf := transform_cell(orig_back[sr][sc], fold_type)

	var tgt_back := cell_to_quads(back[target_r][target_c])
	back[target_r][target_c] = merge_quads(tgt_back, src_front_xf)
	var tgt_front := cell_to_quads(front[target_r][target_c])
	front[target_r][target_c] = merge_quads(tgt_front, src_back_xf)

	front[sr][sc] = EMPTY
	back[sr][sc] = EMPTY


func _transfer_fold_line_cell(row: int, col: int, fold_type: String,
							  _offset: int, _is_bs: bool,
							  orig_front: Array, orig_back: Array,
							  result: Dictionary, src_quads: Array[int]) -> void:
	result.fold_line_cells.append(Vector2i(col, row))

	var of := cell_to_quads(orig_front[row][col])
	var ob := cell_to_quads(orig_back[row][col])

	var incoming_front := [EMPTY, EMPTY, EMPTY, EMPTY]
	var incoming_back := [EMPTY, EMPTY, EMPTY, EMPTY]
	for qi in src_quads:
		incoming_front[qi] = of[qi]
		incoming_back[qi] = ob[qi]

	var xf_front := transform_cell(incoming_front, fold_type)
	var xf_back := transform_cell(incoming_back, fold_type)

	var cur_back := cell_to_quads(back[row][col])
	back[row][col] = merge_quads(cur_back, xf_front)
	var cur_front := cell_to_quads(front[row][col])
	front[row][col] = merge_quads(cur_front, xf_back)

	var f := cell_to_quads(front[row][col])
	var b := cell_to_quads(back[row][col])
	for qi in src_quads:
		f[qi] = EMPTY
		b[qi] = EMPTY
	front[row][col] = f
	back[row][col] = b


# ── Win Check ────────────────────────────────────────────────────────

func check_win() -> bool:
	for row in range(size):
		for col in range(size):
			if not _cells_equal(front[row][col], target[row][col]):
				return false
	return true


static func _cells_equal(a, b) -> bool:
	var qa := cell_to_quads(a)
	var qb := cell_to_quads(b)
	return qa[0] == qb[0] and qa[1] == qb[1] and qa[2] == qb[2] and qa[3] == qb[3]


# ── Public Helpers for Interaction ──────────────────────────────────

## Calculate the mirror position for a cell across a fold line.
## Returns Vector2i(-1,-1) if out of bounds.
static func get_mirror_pos(fold_def: Dictionary, row: int, col: int, grid_size: int) -> Vector2i:
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


## Determine which side of a fold line a cell is on.
## Returns: 0 = side A, 1 = side B, -1 = on the fold line (diagonal only).
static func get_fold_side(fold_def: Dictionary, row: int, col: int, grid_size: int) -> int:
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


## Check if a cell is on a foldable side (smaller or equal side) of a fold line.
static func is_foldable_side(fold_def: Dictionary, row: int, col: int, grid_size: int) -> bool:
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
