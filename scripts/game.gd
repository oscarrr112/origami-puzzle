extends Node2D

signal level_completed(level_id: int)
signal back_pressed

const CELL_SIZE := 120
const CELL_GAP := 3
const TARGET_CELL_SIZE := 35
const TARGET_GAP := 2
const GRID_ORIGIN := Vector2(60, 350)
const TARGET_ORIGIN := Vector2(60, 100)
const BACK_ORIGIN := Vector2(420, 100)
const HUD_Y_OFFSET := 60
const ANIM_DURATION := 0.3

const COLOR_MAP := {
	0: Color("#F5F0E8"),
	1: Color("#E8785A"),
	2: Color("#6ABEAB"),
	3: Color("#E8B84A"),
	4: Color("#7B6CB7"),
	5: Color("#5BA4CF"),
}

const BG_COLOR := Color("#F5F0E8")
const TEXT_COLOR := Color("#5C4033")
const FOLD_LINE_COLOR := Color("#5C4033", 0.25)
const CORNER_HINT_COLOR := Color("#4CAF50", 0.45)  # Green hint for clickable corners
const TARGET_GLOW_COLOR := Color("#FFD700")

var model: GridModel
var level_data: Dictionary
var is_animating := false

enum InteractionState { IDLE, SELECTED, FOLDING }
var _state: InteractionState = InteractionState.IDLE
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _target_map: Dictionary = {}  # {Vector2i -> Array[Dictionary]} -- target cell -> [fold_defs]
var _highlight_nodes: Array = []  # Nodes created for glow effects
var _tutorial: TutorialOverlay = null

var _drag_start_cell: Vector2i = Vector2i(-1, -1)
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
const DRAG_THRESHOLD := 20.0

var cell_rects: Array = []
var target_rects: Array = []
var back_rects: Array = []
var fold_lines: Array = []
var fold_label: Label
var win_overlay: ColorRect
var win_panel: PanelContainer


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
	_draw_corner_hints()
	if int(data["id"]) == 0:
		_start_tutorial()


func _build_all() -> void:
	for child in get_children():
		child.queue_free()
	cell_rects.clear()
	target_rects.clear()
	back_rects.clear()
	fold_lines.clear()

	_build_background()
	_build_level_title()
	_build_target_label()
	_build_target_grid()
	_build_back_grid()
	_build_grid_border()
	_build_main_grid()
	_build_fold_lines()
	_build_hud()
	_build_win_popup()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(720, 1280)
	bg.z_index = -10
	add_child(bg)


func _build_level_title() -> void:
	var lbl := Label.new()
	lbl.text = "第 %d 关 · %s" % [int(level_data["id"]), level_data["name"]]
	lbl.position = Vector2(60, 25)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(lbl)


func _build_target_label() -> void:
	var lbl := Label.new()
	lbl.text = "目标"
	lbl.position = Vector2(TARGET_ORIGIN.x, TARGET_ORIGIN.y - 28)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(lbl)


func _build_target_grid() -> void:
	var s := model.size
	var container := Node2D.new()
	container.position = TARGET_ORIGIN
	add_child(container)
	_add_preview_border(container, s)
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


func _build_back_grid() -> void:
	# 背面标签
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
	_add_preview_border(container, s)

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


func _add_preview_border(container: Node2D, s: int) -> void:
	var total := s * TARGET_CELL_SIZE + (s - 1) * TARGET_GAP
	var border := ReferenceRect.new()
	border.position = Vector2(-1, -1)
	border.size = Vector2(total + 2, total + 2)
	border.border_color = Color("#5C4033", 0.15)
	border.border_width = 1.0
	border.editor_only = false
	container.add_child(border)
	# Inner grid lines
	var grid_color := Color("#5C4033", 0.08)
	for i in range(1, s):
		var offset := i * (TARGET_CELL_SIZE + TARGET_GAP) - TARGET_GAP / 2.0
		var vline := Line2D.new()
		vline.add_point(Vector2(offset, 0))
		vline.add_point(Vector2(offset, total))
		vline.width = 1.0
		vline.default_color = grid_color
		vline.z_index = -1
		container.add_child(vline)
		var hline := Line2D.new()
		hline.add_point(Vector2(0, offset))
		hline.add_point(Vector2(total, offset))
		hline.width = 1.0
		hline.default_color = grid_color
		hline.z_index = -1
		container.add_child(hline)


func _build_grid_border() -> void:
	var s := model.size
	var total := s * CELL_SIZE + (s - 1) * CELL_GAP
	var border := ReferenceRect.new()
	border.position = GRID_ORIGIN - Vector2(2, 2)
	border.size = Vector2(total + 4, total + 4)
	border.border_color = Color("#5C4033", 0.15)
	border.border_width = 2.0
	border.editor_only = false
	add_child(border)

	# Inner grid lines so cell structure is always visible
	var grid_color := Color("#5C4033", 0.08)
	for i in range(1, s):
		var x := GRID_ORIGIN.x + i * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
		var vline := Line2D.new()
		vline.add_point(Vector2(x, GRID_ORIGIN.y))
		vline.add_point(Vector2(x, GRID_ORIGIN.y + total))
		vline.width = 1.0
		vline.default_color = grid_color
		vline.z_index = -1
		add_child(vline)

		var y := GRID_ORIGIN.y + i * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
		var hline := Line2D.new()
		hline.add_point(Vector2(GRID_ORIGIN.x, y))
		hline.add_point(Vector2(GRID_ORIGIN.x + total, y))
		hline.width = 1.0
		hline.default_color = grid_color
		hline.z_index = -1
		add_child(hline)


func _build_main_grid() -> void:
	var s := model.size
	for row in range(s):
		var row_arr := []
		for col in range(s):
			var cell_node := _create_cell_node(
				_cell_pos(col, row), float(CELL_SIZE)
			)
			add_child(cell_node)
			row_arr.append(cell_node)
		cell_rects.append(row_arr)


func _cell_pos(col: int, row: int) -> Vector2:
	return GRID_ORIGIN + Vector2(
		col * (CELL_SIZE + CELL_GAP),
		row * (CELL_SIZE + CELL_GAP)
	)


func _create_cell_node(pos: Vector2, cell_size: float) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	var cx := cell_size / 2.0
	var cy := cell_size / 2.0

	var t := Polygon2D.new()
	t.polygon = PackedVector2Array([Vector2(0, 0), Vector2(cell_size, 0), Vector2(cx, cy)])
	t.color = COLOR_MAP[0]
	t.name = "T"
	node.add_child(t)

	var r := Polygon2D.new()
	r.polygon = PackedVector2Array([Vector2(cell_size, 0), Vector2(cell_size, cell_size), Vector2(cx, cy)])
	r.color = COLOR_MAP[0]
	r.name = "R"
	node.add_child(r)

	var b := Polygon2D.new()
	b.polygon = PackedVector2Array([Vector2(cell_size, cell_size), Vector2(0, cell_size), Vector2(cx, cy)])
	b.color = COLOR_MAP[0]
	b.name = "B"
	node.add_child(b)

	var l := Polygon2D.new()
	l.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, cell_size), Vector2(cx, cy)])
	l.color = COLOR_MAP[0]
	l.name = "L"
	node.add_child(l)

	return node


func _create_preview_cell(cell, pos: Vector2) -> Node2D:
	var node := _create_cell_node(pos, float(TARGET_CELL_SIZE))
	_set_preview_colors(node, cell)
	return node


func _set_cell_colors(cell_node: Node2D, cell) -> void:
	var quads := GridModel.cell_to_quads(cell)
	cell_node.get_node("T").color = COLOR_MAP[quads[0]]
	cell_node.get_node("R").color = COLOR_MAP[quads[1]]
	cell_node.get_node("B").color = COLOR_MAP[quads[2]]
	cell_node.get_node("L").color = COLOR_MAP[quads[3]]

func _set_preview_colors(cell_node: Node2D, cell) -> void:
	var quads := GridModel.cell_to_quads(cell)
	cell_node.get_node("T").color = COLOR_MAP[quads[0]]
	cell_node.get_node("R").color = COLOR_MAP[quads[1]]
	cell_node.get_node("B").color = COLOR_MAP[quads[2]]
	cell_node.get_node("L").color = COLOR_MAP[quads[3]]


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
	var extend := 12.0
	_draw_dashed_line(
		Vector2(x, GRID_ORIGIN.y - extend),
		Vector2(x, GRID_ORIGIN.y + total + extend),
		FOLD_LINE_COLOR, 2.0, 8.0, 6.0
	)


func _build_h_fold_line(fold_pos: int, total: float) -> void:
	var y := GRID_ORIGIN.y + fold_pos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var extend := 12.0
	_draw_dashed_line(
		Vector2(GRID_ORIGIN.x - extend, y),
		Vector2(GRID_ORIGIN.x + total + extend, y),
		FOLD_LINE_COLOR, 2.0, 8.0, 6.0
	)


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


func _build_hud() -> void:
	var s := model.size
	var total := s * CELL_SIZE + (s - 1) * CELL_GAP
	var hud_y := GRID_ORIGIN.y + total + HUD_Y_OFFSET

	fold_label = Label.new()
	fold_label.position = Vector2(GRID_ORIGIN.x, hud_y)
	fold_label.add_theme_font_size_override("font_size", 24)
	fold_label.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(fold_label)
	_update_fold_label()

	var btn_y := hud_y + 50
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#E8785A")
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8

	var undo_btn := Button.new()
	undo_btn.text = "撤销"
	undo_btn.position = Vector2(GRID_ORIGIN.x, btn_y)
	undo_btn.custom_minimum_size = Vector2(130, 50)
	undo_btn.add_theme_stylebox_override("normal", btn_style)
	undo_btn.add_theme_color_override("font_color", Color.WHITE)
	undo_btn.add_theme_font_size_override("font_size", 20)
	undo_btn.pressed.connect(_on_undo)
	add_child(undo_btn)

	var reset_style := btn_style.duplicate()
	reset_style.bg_color = Color("#6ABEAB")
	var reset_btn := Button.new()
	reset_btn.text = "重置"
	reset_btn.position = Vector2(GRID_ORIGIN.x + 150, btn_y)
	reset_btn.custom_minimum_size = Vector2(130, 50)
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.add_theme_color_override("font_color", Color.WHITE)
	reset_btn.add_theme_font_size_override("font_size", 20)
	reset_btn.pressed.connect(_on_reset)
	add_child(reset_btn)

	var back_style := btn_style.duplicate()
	back_style.bg_color = Color("#5C4033", 0.6)
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(GRID_ORIGIN.x + 300, btn_y)
	back_btn.custom_minimum_size = Vector2(130, 50)
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func(): back_pressed.emit())
	add_child(back_btn)

	# 查看背面按钮
	var peek_style := btn_style.duplicate()
	peek_style.bg_color = Color("#E8B84A")
	var peek_btn := Button.new()
	peek_btn.text = "查看背面"
	peek_btn.position = Vector2(GRID_ORIGIN.x, btn_y + 70)
	peek_btn.custom_minimum_size = Vector2(280, 50)
	peek_btn.add_theme_stylebox_override("normal", peek_style)
	peek_btn.add_theme_color_override("font_color", Color.WHITE)
	peek_btn.add_theme_font_size_override("font_size", 20)
	peek_btn.button_down.connect(_show_back)
	peek_btn.button_up.connect(_hide_back)
	add_child(peek_btn)


func _build_win_popup() -> void:
	win_overlay = ColorRect.new()
	win_overlay.color = Color(0, 0, 0, 0.4)
	win_overlay.position = Vector2.ZERO
	win_overlay.size = Vector2(720, 1280)
	win_overlay.visible = false
	win_overlay.z_index = 100
	add_child(win_overlay)

	win_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	win_panel.add_theme_stylebox_override("panel", panel_style)
	win_panel.position = Vector2(120, 450)
	win_panel.size = Vector2(480, 300)
	win_panel.visible = false
	win_panel.z_index = 101

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "通关！"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#E8785A"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var next_style := StyleBoxFlat.new()
	next_style.bg_color = Color("#E8785A")
	next_style.corner_radius_top_left = 12
	next_style.corner_radius_top_right = 12
	next_style.corner_radius_bottom_left = 12
	next_style.corner_radius_bottom_right = 12
	next_style.content_margin_left = 20
	next_style.content_margin_right = 20
	next_style.content_margin_top = 12
	next_style.content_margin_bottom = 12

	var next_btn := Button.new()
	next_btn.text = "下一关"
	next_btn.add_theme_stylebox_override("normal", next_style)
	next_btn.add_theme_color_override("font_color", Color.WHITE)
	next_btn.add_theme_font_size_override("font_size", 24)
	next_btn.pressed.connect(func(): level_completed.emit(int(level_data["id"])))
	vbox.add_child(next_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	var win_back_style := StyleBoxFlat.new()
	win_back_style.bg_color = Color("#5C4033", 0.5)
	win_back_style.corner_radius_top_left = 12
	win_back_style.corner_radius_top_right = 12
	win_back_style.corner_radius_bottom_left = 12
	win_back_style.corner_radius_bottom_right = 12
	win_back_style.content_margin_left = 20
	win_back_style.content_margin_right = 20
	win_back_style.content_margin_top = 12
	win_back_style.content_margin_bottom = 12

	var win_back_btn := Button.new()
	win_back_btn.text = "返回选关"
	win_back_btn.add_theme_stylebox_override("normal", win_back_style)
	win_back_btn.add_theme_color_override("font_color", Color.WHITE)
	win_back_btn.add_theme_font_size_override("font_size", 20)
	win_back_btn.pressed.connect(func():
		win_overlay.visible = false
		win_panel.visible = false
		back_pressed.emit()
	)
	vbox.add_child(win_back_btn)

	win_panel.add_child(vbox)
	add_child(win_panel)


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


## Convert screen position to grid cell coordinates. Returns (-1,-1) if invalid.
func _pos_to_cell(pos: Vector2) -> Vector2i:
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


## Check if cell is a corner cell that can trigger at least one fold.
## Corners are always clickable, even when empty (empty = transparent color).
func _is_clickable_cell(row: int, col: int) -> bool:
	var is_corner := (row == 0 or row == model.size - 1) and (col == 0 or col == model.size - 1)
	if not is_corner:
		return false
	# Check if at least one fold line affects this cell
	for fold_def in model.available_folds:
		if GridModel.is_foldable_side(fold_def, row, col, model.size):
			return true
	return false


## Compute all reachable target positions for a cell.
func _compute_targets(row: int, col: int) -> Dictionary:
	var targets := {}
	for fold_def in model.available_folds:
		if not GridModel.is_foldable_side(fold_def, row, col, model.size):
			continue
		var mirror := GridModel.get_mirror_pos(fold_def, row, col, model.size)
		if mirror == Vector2i(-1, -1):
			continue
		var side := GridModel.get_fold_side(fold_def, row, col, model.size)
		var entry: Dictionary = fold_def.duplicate()
		entry["_force_side"] = side
		if not targets.has(mirror):
			targets[mirror] = []
		targets[mirror].append(entry)
	return targets


func _select_cell(cell: Vector2i) -> void:
	_selected_cell = cell
	_target_map = _compute_targets(cell.y, cell.x)
	_state = InteractionState.SELECTED
	_draw_highlights()


func _cancel_selection() -> void:
	_selected_cell = Vector2i(-1, -1)
	_target_map.clear()
	_state = InteractionState.IDLE
	_draw_corner_hints()


func _on_fold_with_side(fold_def_with_side: Dictionary) -> void:
	var force_side: int = fold_def_with_side.get("_force_side", -1)
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
	_draw_corner_hints()
	if _tutorial:
		_tutorial.notify_action_completed()

	if model.check_win():
		if _tutorial:
			await _tutorial.completed
		await get_tree().create_timer(0.5).timeout
		_show_win()


func _animate_vh_fold(fold_data: Dictionary) -> void:
	var sources: Array = fold_data.sources
	var targets: Array = fold_data.targets
	var is_vert: bool = (fold_data.type == "v")
	var fpos: int = fold_data.fold_pos

	var history_state: Dictionary = model._history[model._history.size() - 1]
	var old_front: Array = history_state.front

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

	for pair in fold_pairs:
		var src: Vector2i = pair.src
		cell_rects[src.y][src.x].visible = false

	# Front flap (pre-fold colors)
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

	# Back flap (post-fold target colors)
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


func _animate_diagonal_fold(fold_data: Dictionary) -> void:
	var sources: Array = fold_data.sources
	var targets: Array = fold_data.targets
	var fold_line_cells: Array = fold_data.get("fold_line_cells", [])
	var fold_type: String = fold_data["type"]

	# Source quadrant names for fold-line cells (determined by model based on fold direction)
	var src_quad_names: Array = fold_data.get("src_quad_names", [])
	if src_quad_names.is_empty():
		if fold_type == "d_bs":
			src_quad_names = ["T", "R"]
		else:
			src_quad_names = ["T", "L"]

	# Phase 1: Fade out source cells (whole) + fold-line source quadrants only
	var tweens := []
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		var cell_node: Node2D = cell_rects[src.y][src.x]
		cell_node.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(cell_node, "modulate:a", 0.0, 0.25)
		tweens.append(tw)

	for flc in fold_line_cells:
		var cell_node: Node2D = cell_rects[flc.y][flc.x]
		for qname in src_quad_names:
			var quad: Polygon2D = cell_node.get_node(qname)
			quad.modulate.a = 1.0
			var tw := create_tween()
			tw.tween_property(quad, "modulate:a", 0.0, 0.25)
			tweens.append(tw)

	if tweens.size() > 0:
		await tweens[tweens.size() - 1].finished

	# Snap to final state and restore all opacity
	_refresh_grid()
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		cell_rects[src.y][src.x].modulate.a = 1.0
	for flc in fold_line_cells:
		var cell_node: Node2D = cell_rects[flc.y][flc.x]
		for qname in src_quad_names:
			cell_node.get_node(qname).modulate.a = 1.0


func _refresh_grid() -> void:
	var s := model.size
	for row in range(s):
		for col in range(s):
			var cell_node: Node2D = cell_rects[row][col]
			_set_cell_colors(cell_node, model.front[row][col])
			if back_rects.size() > row and back_rects[row].size() > col:
				_set_preview_colors(back_rects[row][col], model.back[row][col])


func _update_fold_label() -> void:
	fold_label.text = "折叠: %d / %d" % [model.folds_used, model.max_folds]


func _on_undo() -> void:
	if is_animating:
		return
	if _state == InteractionState.SELECTED:
		_cancel_selection()
	model.undo()
	_refresh_grid()
	_update_fold_label()
	_draw_corner_hints()


func _on_reset() -> void:
	if is_animating:
		return
	if _state == InteractionState.SELECTED:
		_cancel_selection()
	model.reset()
	_refresh_grid()
	_update_fold_label()
	_draw_corner_hints()


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


func _hide_back() -> void:
	_refresh_grid()


func _show_win() -> void:
	win_overlay.visible = true
	win_panel.visible = true


func _draw_corner_hints() -> void:
	_clear_highlights()
	var s := model.size
	var corners := [Vector2i(0, 0), Vector2i(s - 1, 0), Vector2i(0, s - 1), Vector2i(s - 1, s - 1)]
	for corner in corners:
		if not _is_clickable_cell(corner.y, corner.x):
			continue
		var pos := _cell_pos(corner.x, corner.y)
		var hint := ReferenceRect.new()
		hint.position = pos - Vector2(3, 3)
		hint.size = Vector2(CELL_SIZE + 6, CELL_SIZE + 6)
		hint.border_color = CORNER_HINT_COLOR
		hint.border_width = 4.0
		hint.editor_only = false
		hint.z_index = 20
		add_child(hint)
		_highlight_nodes.append(hint)
		var tw := hint.create_tween()
		tw.set_loops()
		tw.tween_property(hint, "border_color:a", 0.15, 1.0)
		tw.tween_property(hint, "border_color:a", 0.55, 1.0)


func _start_tutorial() -> void:
	var s := model.size
	var total := float(s * CELL_SIZE + (s - 1) * CELL_GAP)

	var target_total := float(s * TARGET_CELL_SIZE + (s - 1) * TARGET_GAP)
	var target_rect := Rect2(
		TARGET_ORIGIN - Vector2(8, 36),
		Vector2(target_total + 16, target_total + 44)
	)
	var back_total := target_total
	var back_rect := Rect2(
		BACK_ORIGIN - Vector2(8, 36),
		Vector2(back_total + 16, back_total + 44)
	)
	var grid_rect := Rect2(
		GRID_ORIGIN - Vector2(8, 8),
		Vector2(total + 16, total + 16)
	)
	var fold_label_rect := Rect2(
		fold_label.position - Vector2(4, 4),
		Vector2(250, 40)
	)
	var v2_x := GRID_ORIGIN.x + 2 * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var fold_line_rect := Rect2(
		Vector2(v2_x - 20, GRID_ORIGIN.y - 12),
		Vector2(40, total + 24)
	)
	var corner_rect := Rect2(
		_cell_pos(0, 0) - Vector2(4, 4),
		Vector2(CELL_SIZE + 8, CELL_SIZE + 8)
	)
	var target_cell_rect := Rect2(
		_cell_pos(3, 0) - Vector2(6, 6),
		Vector2(CELL_SIZE + 12, CELL_SIZE + 12)
	)

	var steps: Array = [
		{
			"type": "INFO",
			"text": "欢迎来到折纸游戏！这是目标图案，你需要通过折叠让纸变成这个样子。",
			"highlight": target_rect,
		},
		{
			"type": "INFO",
			"text": "这是当前纸的正面。红色色块在左上角。",
			"highlight": grid_rect,
		},
		{
			"type": "INFO",
			"text": "这是纸的背面。折叠时，正面的颜色会翻到背面。",
			"highlight": back_rect,
		},
		{
			"type": "INFO",
			"text": "你有有限的折叠次数。用完之前要完成目标！",
			"highlight": fold_label_rect,
		},
		{
			"type": "INFO",
			"text": "虚线表示可以折叠的位置。",
			"highlight": fold_line_rect,
		},
		{
			"type": "WAIT_CLICK",
			"text": "点击左上角绿色闪烁的位置来开始折叠。",
			"highlight": corner_rect,
		},
		{
			"type": "INFO",
			"text": "金色闪烁的格子是折叠后色块会到达的位置。",
			"highlight": target_cell_rect,
		},
		{
			"type": "WAIT_CLICK",
			"text": "点击金色格子来执行折叠！",
			"highlight": target_cell_rect,
		},
		{
			"type": "WAIT_ACTION",
			"text": "",
			"highlight": grid_rect,
		},
		{
			"type": "INFO",
			"text": "太棒了！你完成了第一次折叠！现在纸的正面已经和目标一样了。",
			"highlight": grid_rect,
		},
	]

	_tutorial = TutorialOverlay.new()
	add_child(_tutorial)
	_tutorial.completed.connect(_on_tutorial_completed)
	_tutorial.start(steps)


func _on_tutorial_completed() -> void:
	if _tutorial:
		_tutorial.queue_free()
		_tutorial = null


func _draw_highlights() -> void:
	_clear_highlights()
	# Target cells — gold glow with strong pulse
	for target_cell in _target_map.keys():
		var tgt_pos := _cell_pos(target_cell.x, target_cell.y)

		# Semi-transparent gold overlay for stronger visual
		var overlay := ColorRect.new()
		overlay.position = tgt_pos
		overlay.size = Vector2(CELL_SIZE, CELL_SIZE)
		overlay.color = Color(TARGET_GLOW_COLOR, 0.25)
		overlay.z_index = 18
		add_child(overlay)
		_highlight_nodes.append(overlay)

		# Outer glow (wider, semi-transparent)
		var glow := ReferenceRect.new()
		glow.position = tgt_pos - Vector2(5, 5)
		glow.size = Vector2(CELL_SIZE + 10, CELL_SIZE + 10)
		glow.border_color = Color(TARGET_GLOW_COLOR, 0.5)
		glow.border_width = 6.0
		glow.editor_only = false
		glow.z_index = 19
		add_child(glow)
		_highlight_nodes.append(glow)

		# Inner border
		var border := ReferenceRect.new()
		border.position = tgt_pos - Vector2(2, 2)
		border.size = Vector2(CELL_SIZE + 4, CELL_SIZE + 4)
		border.border_color = TARGET_GLOW_COLOR
		border.border_width = 4.0
		border.editor_only = false
		border.z_index = 20
		add_child(border)
		_highlight_nodes.append(border)

		# Pulse animation — stronger range, faster
		var tween := border.create_tween()
		tween.set_loops()
		tween.tween_property(border, "border_color:a", 0.2, 0.5)
		tween.tween_property(border, "border_color:a", 1.0, 0.5)
		var tween2 := glow.create_tween()
		tween2.set_loops()
		tween2.tween_property(glow, "border_color:a", 0.1, 0.5)
		tween2.tween_property(glow, "border_color:a", 0.5, 0.5)
		var tween3 := overlay.create_tween()
		tween3.set_loops()
		tween3.tween_property(overlay, "color:a", 0.1, 0.5)
		tween3.tween_property(overlay, "color:a", 0.3, 0.5)


func _clear_highlights() -> void:
	for node in _highlight_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_highlight_nodes.clear()
