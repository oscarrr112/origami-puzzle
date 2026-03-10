extends Control

signal level_selected(level_data: Dictionary)

const BG_COLOR := Color("#F5F0E8")
const TEXT_COLOR := Color("#5C4033")
const ACCENT_COLOR := Color("#E8785A")

var levels_data: Array = []


func setup(levels: Array) -> void:
	levels_data = levels
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "折纸谜题"
	title.position = Vector2(0, 80)
	title.size = Vector2(720, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Origami Puzzle"
	subtitle.position = Vector2(0, 145)
	subtitle.size = Vector2(720, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(subtitle)

	# Level buttons grid
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(100, 280)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	add_child(grid)

	for level in levels_data:
		var btn := Button.new()
		btn.text = "%d\n%s" % [int(level["id"]), level["name"]]
		btn.custom_minimum_size = Vector2(110, 110)

		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		style.border_width_bottom = 3
		style.border_color = ACCENT_COLOR
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate()
		hover_style.bg_color = Color("#FFF5F0")
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.add_theme_color_override("font_color", TEXT_COLOR)
		btn.add_theme_font_size_override("font_size", 18)

		var data = level
		btn.pressed.connect(func(): level_selected.emit(data))
		grid.add_child(btn)
