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
	model.setup(
		int(data["size"]),
		data["front"],
		data["back"],
		data["target"],
		int(data["max_folds"])
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
				int(model.target[row][col]),
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
				int(model.back[row][col]),
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


func _build_main_grid() -> void:
	var s := model.size
	for row in range(s):
		var row_arr := []
		for col in range(s):
			var rect := ColorRect.new()
			rect.size = Vector2(CELL_SIZE, CELL_SIZE)
			rect.position = _cell_pos(col, row)
			rect.color = COLOR_MAP[0]
			add_child(rect)
			row_arr.append(rect)
		cell_rects.append(row_arr)


func _cell_pos(col: int, row: int) -> Vector2:
	return GRID_ORIGIN + Vector2(
		col * (CELL_SIZE + CELL_GAP),
		row * (CELL_SIZE + CELL_GAP)
	)


func _create_preview_cell(color_id: int, pos: Vector2) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(TARGET_CELL_SIZE, TARGET_CELL_SIZE)
	panel.position = pos
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_MAP[color_id]
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color("#5C4033", 0.3)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _set_preview_cell_color(panel: Panel, color_id: int) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.bg_color = COLOR_MAP[color_id]


func _build_fold_lines() -> void:
	var s := model.size
	var total := s * CELL_SIZE + (s - 1) * CELL_GAP

	for i in range(1, s):
		var x := GRID_ORIGIN.x + i * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
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
		var fold_pos := i
		var line_ref := line
		btn.pressed.connect(func(): _on_fold(true, fold_pos))
		btn.mouse_entered.connect(func(): line_ref.default_color = FOLD_LINE_HOVER; line_ref.width = 4.0)
		btn.mouse_exited.connect(func(): line_ref.default_color = FOLD_LINE_COLOR; line_ref.width = 2.0)
		add_child(btn)
		fold_buttons.append(btn)

	for i in range(1, s):
		var y := GRID_ORIGIN.y + i * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
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
		var fold_pos := i
		var line_ref := line
		btn.pressed.connect(func(): _on_fold(false, fold_pos))
		btn.mouse_entered.connect(func(): line_ref.default_color = FOLD_LINE_HOVER; line_ref.width = 4.0)
		btn.mouse_exited.connect(func(): line_ref.default_color = FOLD_LINE_COLOR; line_ref.width = 2.0)
		add_child(btn)
		fold_buttons.append(btn)


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


func _on_fold(is_vertical: bool, fold_pos: int) -> void:
	if is_animating or not model.can_fold():
		return
	var result := model.fold(is_vertical, fold_pos)
	if result.is_empty():
		return
	_animate_fold(result)


func _animate_fold(fold_data: Dictionary) -> void:
	is_animating = true
	_set_fold_buttons_enabled(false)

	var sources: Array = fold_data.sources
	var targets: Array = fold_data.targets
	var is_vert: bool = fold_data.is_vertical
	var fpos: int = fold_data.fold_pos

	# 记录源格子的背面颜色（折叠前已保存在 history 里）
	var history_state: Dictionary = model._history[model._history.size() - 1]
	var old_back: Array = history_state.back

	# 收集不重复的 source→target 映射，以及源格子背面颜色
	var fold_pairs := []  # [{src, tgt, back_color}]
	var seen := {}
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		var tgt: Vector2i = targets[i]
		var key := src.y * 100 + src.x
		if seen.has(key):
			continue
		seen[key] = true
		var back_val := int(old_back[src.y][src.x])
		fold_pairs.append({"src": src, "tgt": tgt, "back_color": back_val})

	# 计算折线像素坐标
	var fold_px := 0.0
	if is_vert:
		fold_px = GRID_ORIGIN.x + fpos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0
	else:
		fold_px = GRID_ORIGIN.y + fpos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0

	# 创建临时"翻面"格子（从折线展开，显示背面颜色）
	var temp_cells := []
	for pair in fold_pairs:
		var tgt: Vector2i = pair.tgt
		var back_color: int = pair.back_color
		# 只有背面有颜色的才显示翻面效果
		var display_color: Color
		if back_color != 0:
			display_color = COLOR_MAP[back_color]
		else:
			display_color = COLOR_MAP[0]

		var temp := ColorRect.new()
		temp.color = display_color
		temp.z_index = 5
		var target_pos := _cell_pos(tgt.x, tgt.y)
		if is_vert:
			# 从折线位置开始，宽度为0
			temp.position = Vector2(fold_px, target_pos.y)
			temp.size = Vector2(0, CELL_SIZE)
		else:
			# 从折线位置开始，高度为0
			temp.position = Vector2(target_pos.x, fold_px)
			temp.size = Vector2(CELL_SIZE, 0)
		add_child(temp)
		temp_cells.append({"node": temp, "tgt": tgt, "target_pos": target_pos})

	# ---- 动画：源缩小 + 目标展开 同时进行 ----
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)

	var fold_duration := 0.4

	# 源格子向折线缩小
	for pair in fold_pairs:
		var src: Vector2i = pair.src
		var cell: ColorRect = cell_rects[src.y][src.x]
		if is_vert:
			if src.x < fpos:
				tween.tween_property(cell, "size:x", 0.0, fold_duration)
				tween.tween_property(cell, "position:x", fold_px, fold_duration)
			else:
				tween.tween_property(cell, "size:x", 0.0, fold_duration)
		else:
			if src.y < fpos:
				tween.tween_property(cell, "size:y", 0.0, fold_duration)
				tween.tween_property(cell, "position:y", fold_px, fold_duration)
			else:
				tween.tween_property(cell, "size:y", 0.0, fold_duration)

	# 目标位置的临时格子从折线展开
	for tc in temp_cells:
		var temp: ColorRect = tc.node
		var target_pos: Vector2 = tc.target_pos
		if is_vert:
			tween.tween_property(temp, "size:x", float(CELL_SIZE), fold_duration)
			tween.tween_property(temp, "position:x", target_pos.x, fold_duration)
		else:
			tween.tween_property(temp, "size:y", float(CELL_SIZE), fold_duration)
			tween.tween_property(temp, "position:y", target_pos.y, fold_duration)

	await tween.finished

	# 清理临时格子，刷新网格到最终状态
	for tc in temp_cells:
		tc.node.queue_free()
	_refresh_grid()
	_update_fold_label()

	# 通关检测（延迟显示）
	_set_fold_buttons_enabled(true)
	is_animating = false

	if model.check_win():
		await get_tree().create_timer(0.5).timeout
		_show_win()


func _set_fold_buttons_enabled(enabled: bool) -> void:
	for btn in fold_buttons:
		btn.disabled = not enabled


func _refresh_grid() -> void:
	var s := model.size
	for row in range(s):
		for col in range(s):
			var rect: ColorRect = cell_rects[row][col]
			rect.color = COLOR_MAP[int(model.front[row][col])]
			rect.size = Vector2(CELL_SIZE, CELL_SIZE)
			rect.position = _cell_pos(col, row)
			# 刷新背面小预览
			if back_rects.size() > row and back_rects[row].size() > col:
				_set_preview_cell_color(back_rects[row][col], int(model.back[row][col]))


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
			var rect: ColorRect = cell_rects[row][col]
			var back_val := int(model.back[row][col])
			if back_val != 0:
				rect.color = COLOR_MAP[back_val].lerp(Color.WHITE, 0.3)
			elif int(model.front[row][col]) == 0:
				rect.color = COLOR_MAP[0]
			else:
				rect.color = COLOR_MAP[int(model.front[row][col])].lerp(Color.WHITE, 0.5)


func _hide_back() -> void:
	_refresh_grid()


func _show_win() -> void:
	win_overlay.visible = true
	win_panel.visible = true
