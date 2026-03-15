extends Node2D

signal level_completed(level_id: int)
signal back_pressed

const CELL_SIZE := 120
const CELL_GAP := 3
const TARGET_CELL_SIZE := 35
const TARGET_GAP := 2
const GRID_ORIGIN := Vector2(60, 350)
const TARGET_ORIGIN := Vector2(60, 80)
const BACK_ORIGIN := Vector2(420, 80)
const HUD_Y_OFFSET := 60
const FOLD_BTN_THICKNESS := 44
const ANIM_DURATION := 0.3

const COLOR_MAP := {
	0: Color("#F5F0E8"),
	1: Color("#E8785A"),
	2: Color("#6ABEAB"),
	3: Color("#E8B84A"),
}

const BG_COLOR := Color("#F5F0E8")
const TEXT_COLOR := Color("#5C4033")
const FOLD_LINE_COLOR := Color("#5C4033", 0.25)
const FOLD_LINE_HOVER := Color("#E8785A", 0.6)

var model: GridModel
var level_data: Dictionary
var is_animating := false

var cell_rects: Array = []
var target_rects: Array = []
var back_rects: Array = []
var fold_buttons: Array = []
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


func _build_all() -> void:
	for child in get_children():
		child.queue_free()
	cell_rects.clear()
	target_rects.clear()
	back_rects.clear()
	fold_buttons.clear()
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


func _build_diagonal_fold_line(fold_type: String, offset: int, total: float) -> void:
	var is_bs := (fold_type == "d_bs")
	var s := model.size
	var step := CELL_SIZE + CELL_GAP

	var points: Array[Vector2] = []
	for i in range(s + 1):
		var r_f: float
		var c_f: float
		if is_bs:
			r_f = float(i)
			c_f = float(i) + float(offset)
		else:
			r_f = float(i)
			c_f = float(offset) - float(i)

		if c_f < 0.0 or c_f > float(s) or r_f < 0.0 or r_f > float(s):
			continue

		var px := GRID_ORIGIN.x + c_f * step
		var py := GRID_ORIGIN.y + r_f * step
		points.append(Vector2(px, py))

	if points.size() < 2:
		return

	var line := Line2D.new()
	for pt in points:
		line.add_point(pt)
	line.width = 2.0
	line.default_color = FOLD_LINE_COLOR
	add_child(line)
	fold_lines.append(line)

	var def := {"type": fold_type, "offset": offset}
	var line_ref := line

	# Place a clickable button at each segment along the diagonal line
	for i in range(points.size() - 1):
		var p1 := points[i]
		var p2 := points[i + 1]
		var mid := (p1 + p2) / 2.0
		var btn := Button.new()
		btn.flat = true
		btn.position = Vector2(min(p1.x, p2.x) - 15, min(p1.y, p2.y) - 15)
		btn.size = Vector2(abs(p2.x - p1.x) + 30, abs(p2.y - p1.y) + 30)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(func(): _on_fold(def))
		btn.mouse_entered.connect(func(): line_ref.default_color = FOLD_LINE_HOVER; line_ref.width = 4.0)
		btn.mouse_exited.connect(func(): line_ref.default_color = FOLD_LINE_COLOR; line_ref.width = 2.0)
		add_child(btn)
		fold_buttons.append(btn)

	# Visible indicator circles at endpoints
	for pt in [points[0], points[points.size() - 1]]:
		var indicator := Polygon2D.new()
		var circle_pts := PackedVector2Array()
		var radius := 8.0
		for j in range(12):
			var angle := j * TAU / 12.0
			circle_pts.append(pt + Vector2(cos(angle), sin(angle)) * radius)
		indicator.polygon = circle_pts
		indicator.color = FOLD_LINE_COLOR
		add_child(indicator)


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


func _on_fold(fold_def: Dictionary) -> void:
	if is_animating or not model.can_fold():
		return
	var result := model.fold(fold_def)
	if result.is_empty():
		return
	_animate_fold(result)


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


func _set_fold_buttons_enabled(enabled: bool) -> void:
	for btn in fold_buttons:
		btn.disabled = not enabled


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
	model.undo()
	_refresh_grid()
	_update_fold_label()


func _on_reset() -> void:
	if is_animating:
		return
	model.reset()
	_refresh_grid()
	_update_fold_label()


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
