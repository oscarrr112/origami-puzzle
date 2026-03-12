class_name GridModel
extends RefCounted

const EMPTY := 0

var size: int
var front: Array  # [row][col] of int
var back: Array
var target: Array
var max_folds: int
var folds_used: int = 0
var _history: Array = []


func setup(p_size: int, p_front: Array, p_back: Array, p_target: Array, p_max_folds: int) -> void:
	size = p_size
	front = _to_int_grid(p_front)
	back = _to_int_grid(p_back)
	target = _to_int_grid(p_target)
	max_folds = p_max_folds
	folds_used = 0
	_history.clear()


func fold(is_vertical: bool, fold_pos: int) -> Dictionary:
	if folds_used >= max_folds:
		return {}

	_history.append({
		"front": _deep_copy(front),
		"back": _deep_copy(back),
		"folds": folds_used
	})

	var result := {
		"sources": [],
		"targets": [],
		"is_vertical": is_vertical,
		"fold_pos": fold_pos
	}

	if is_vertical:
		_fold_vertical(fold_pos, result)
	else:
		_fold_horizontal(fold_pos, result)

	folds_used += 1
	return result


func _fold_vertical(fold_pos: int, result: Dictionary) -> void:
	var left := fold_pos
	var right := size - fold_pos
	var fold_left := left <= right

	if fold_left:
		for col in range(fold_pos):
			var mirror := 2 * fold_pos - 1 - col
			if mirror >= size:
				continue
			for row in range(size):
				result.sources.append(Vector2i(col, row))
				result.targets.append(Vector2i(mirror, row))
				if front[row][col] != EMPTY:
					back[row][mirror] = front[row][col]
				if back[row][col] != EMPTY:
					front[row][mirror] = back[row][col]
				front[row][col] = EMPTY
				back[row][col] = EMPTY
	else:
		for col in range(fold_pos, size):
			var mirror := 2 * fold_pos - 1 - col
			if mirror < 0:
				continue
			for row in range(size):
				result.sources.append(Vector2i(col, row))
				result.targets.append(Vector2i(mirror, row))
				if front[row][col] != EMPTY:
					back[row][mirror] = front[row][col]
				if back[row][col] != EMPTY:
					front[row][mirror] = back[row][col]
				front[row][col] = EMPTY
				back[row][col] = EMPTY


func _fold_horizontal(fold_pos: int, result: Dictionary) -> void:
	var top := fold_pos
	var bottom := size - fold_pos
	var fold_top := top <= bottom

	if fold_top:
		for row in range(fold_pos):
			var mirror := 2 * fold_pos - 1 - row
			if mirror >= size:
				continue
			for col in range(size):
				result.sources.append(Vector2i(col, row))
				result.targets.append(Vector2i(col, mirror))
				if front[row][col] != EMPTY:
					back[mirror][col] = front[row][col]
				if back[row][col] != EMPTY:
					front[mirror][col] = back[row][col]
				front[row][col] = EMPTY
				back[row][col] = EMPTY
	else:
		for row in range(fold_pos, size):
			var mirror := 2 * fold_pos - 1 - row
			if mirror < 0:
				continue
			for col in range(size):
				result.sources.append(Vector2i(col, row))
				result.targets.append(Vector2i(col, mirror))
				if front[row][col] != EMPTY:
					back[mirror][col] = front[row][col]
				if back[row][col] != EMPTY:
					front[mirror][col] = back[row][col]
				front[row][col] = EMPTY
				back[row][col] = EMPTY


func check_win() -> bool:
	for row in range(size):
		for col in range(size):
			if front[row][col] != target[row][col]:
				return false
	return true


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


func _to_int_grid(arr: Array) -> Array:
	var copy := []
	for row_data in arr:
		if row_data is Array:
			var int_row := []
			for val in row_data:
				int_row.append(int(val))
			copy.append(int_row)
		else:
			copy.append(int(row_data))
	return copy


func _deep_copy(arr: Array) -> Array:
	var copy := []
	for row_data in arr:
		if row_data is Array:
			copy.append(row_data.duplicate())
		else:
			copy.append(row_data)
	return copy
