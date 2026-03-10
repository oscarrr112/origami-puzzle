extends Node2D

var levels_data: Array = []
var level_select = null
var game_screen = null


func _ready() -> void:
	_load_levels()
	_show_level_select()


func _load_levels() -> void:
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	if not file:
		push_error("Failed to open levels.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse levels.json: " + json.get_error_message())
		return
	levels_data = json.data.levels


func _show_level_select() -> void:
	if game_screen:
		game_screen.queue_free()
		game_screen = null

	level_select = Control.new()
	level_select.set_script(load("res://scripts/level_select.gd"))
	add_child(level_select)
	level_select.setup(levels_data)
	level_select.level_selected.connect(_on_level_selected)


func _on_level_selected(data: Dictionary) -> void:
	if level_select:
		level_select.queue_free()
		level_select = null

	game_screen = Node2D.new()
	game_screen.set_script(load("res://scripts/game.gd"))
	add_child(game_screen)
	game_screen.start_level(data)
	game_screen.back_pressed.connect(_show_level_select)
	game_screen.level_completed.connect(_on_level_completed)


func _on_level_completed(level_id: int) -> void:
	var next_idx := -1
	for i in range(levels_data.size()):
		if int(levels_data[i]["id"]) == level_id:
			next_idx = i + 1
			break

	if next_idx >= 0 and next_idx < levels_data.size():
		_on_level_selected(levels_data[next_idx])
	else:
		_show_level_select()
