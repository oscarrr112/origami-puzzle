class_name TutorialOverlay
extends CanvasLayer

signal completed
signal click_in_highlight

const MASK_COLOR := Color(0, 0, 0, 0.6)
const PANEL_BG := Color(1, 1, 1, 0.95)
const TEXT_COLOR := Color("#5C4033")

var _steps: Array = []
var _current_step: int = -1
var _highlight_rect: Rect2 = Rect2()
var _waiting_for_action := false

var _mask_top: ColorRect
var _mask_bottom: ColorRect
var _mask_left: ColorRect
var _mask_right: ColorRect
var _text_panel: PanelContainer
var _text_label: RichTextLabel
var _tap_hint: Label

const SCREEN_W := 720.0
const SCREEN_H := 1280.0


func _ready() -> void:
	layer = 50
	_build_mask()
	_build_text_panel()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_mask() -> void:
	_mask_top = ColorRect.new()
	_mask_top.color = MASK_COLOR
	_mask_top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mask_top)

	_mask_bottom = ColorRect.new()
	_mask_bottom.color = MASK_COLOR
	_mask_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mask_bottom)

	_mask_left = ColorRect.new()
	_mask_left.color = MASK_COLOR
	_mask_left.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mask_left)

	_mask_right = ColorRect.new()
	_mask_right.color = MASK_COLOR
	_mask_right.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mask_right)


func _build_text_panel() -> void:
	_text_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_text_panel.add_theme_stylebox_override("panel", style)
	_text_panel.position = Vector2(40, SCREEN_H - 200)
	_text_panel.size = Vector2(SCREEN_W - 80, 160)
	add_child(_text_panel)

	var vbox := VBoxContainer.new()
	_text_panel.add_child(vbox)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	_text_label.add_theme_color_override("default_color", TEXT_COLOR)
	_text_label.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(_text_label)

	_tap_hint = Label.new()
	_tap_hint.text = "点击继续 ▶"
	_tap_hint.add_theme_font_size_override("font_size", 16)
	_tap_hint.add_theme_color_override("font_color", Color("#999999"))
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_tap_hint)


func start(steps: Array) -> void:
	_steps = steps
	_current_step = -1
	visible = true
	_advance()


func _advance() -> void:
	_current_step += 1
	if _current_step >= _steps.size():
		_finish()
		return
	_show_step(_steps[_current_step])


func _finish() -> void:
	visible = false
	completed.emit()


func _show_step(step: Dictionary) -> void:
	_text_label.text = step.get("text", "")
	_highlight_rect = step.get("highlight", Rect2(0, 0, SCREEN_W, SCREEN_H))
	_waiting_for_action = false

	var step_type: String = step.get("type", "INFO")
	match step_type:
		"INFO":
			_tap_hint.text = "点击继续 ▶"
			_tap_hint.visible = true
		"WAIT_CLICK":
			_tap_hint.text = ""
			_tap_hint.visible = false
		"WAIT_ACTION":
			_tap_hint.text = ""
			_tap_hint.visible = false
			_waiting_for_action = true

	_update_mask(_highlight_rect)


func _update_mask(cutout: Rect2) -> void:
	## Top: full width, from top to cutout top
	_mask_top.position = Vector2(0, 0)
	_mask_top.size = Vector2(SCREEN_W, maxf(cutout.position.y, 0))

	## Bottom: full width, from cutout bottom to screen bottom
	var cutout_bottom := cutout.position.y + cutout.size.y
	_mask_bottom.position = Vector2(0, cutout_bottom)
	_mask_bottom.size = Vector2(SCREEN_W, maxf(SCREEN_H - cutout_bottom, 0))

	## Left: cutout height, from left edge to cutout left
	_mask_left.position = Vector2(0, cutout.position.y)
	_mask_left.size = Vector2(maxf(cutout.position.x, 0), cutout.size.y)

	## Right: cutout height, from cutout right to screen right
	var cutout_right := cutout.position.x + cutout.size.x
	_mask_right.position = Vector2(cutout_right, cutout.position.y)
	_mask_right.size = Vector2(maxf(SCREEN_W - cutout_right, 0), cutout.size.y)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_for_action:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var step: Dictionary = _steps[_current_step]
			var step_type: String = step.get("type", "INFO")

			match step_type:
				"INFO":
					get_viewport().set_input_as_handled()
					_advance()
				"WAIT_CLICK":
					if _highlight_rect.has_point(mb.position):
						click_in_highlight.emit()
						_advance()
					else:
						get_viewport().set_input_as_handled()


## Called by game.gd when a WAIT_ACTION condition is met
func notify_action_completed() -> void:
	if _waiting_for_action:
		_waiting_for_action = false
		_advance()
