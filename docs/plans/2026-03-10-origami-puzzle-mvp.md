# Origami Puzzle MVP 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现一个可玩的折纸益智游戏 Demo，包含 8 个关卡、折叠动画、撤销/重置功能。

**Architecture:** 单场景架构，main.gd 管理两个屏幕（选关/游戏）。grid_model.gd 处理纯数据逻辑（折叠、撤销、胜负判定），game.gd 处理渲染和交互。关卡数据存 JSON。

**Tech Stack:** Godot 4.6, GDScript, 纯 2D

---

### Task 1: 项目配置

**Files:**
- Modify: `project.godot`

**Step 1: 更新 project.godot**

修改窗口大小为 720×1280（竖屏手机比例），设置主场景，启用拉伸模式。

在 `project.godot` 中添加/修改：

```ini
[application]
config/name="OrigamiPuzzle"
config/features=PackedStringArray("4.6", "Forward Plus")
config/icon="res://icon.svg"
run/main_scene="res://scenes/main.tscn"

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="keep_width"
window/handheld/orientation=1
```

**Step 2: 验证**

Run: 在 Godot 编辑器中打开项目，确认窗口尺寸设置正确。

---

### Task 2: 数据模型 (GridModel)

**Files:**
- Create: `scripts/grid_model.gd`

**Step 1: 创建 grid_model.gd**

```gdscript
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
	front = _deep_copy(p_front)
	back = _deep_copy(p_back)
	target = _deep_copy(p_target)
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
		"sources": [] as Array[Vector2i],
		"targets": [] as Array[Vector2i],
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


func _deep_copy(arr: Array) -> Array:
	var copy := []
	for row_data in arr:
		if row_data is Array:
			copy.append(row_data.duplicate())
		else:
			copy.append(row_data)
	return copy
```

**Step 2: 验证**

在 Godot 编辑器中确认无语法错误（脚本面板打开该文件）。

**Step 3: 提交**

```bash
git add scripts/grid_model.gd
git commit -m "feat: add GridModel with fold/undo/reset logic"
```

---

### Task 3: 关卡数据

**Files:**
- Create: `data/levels.json`

**Step 1: 创建 levels.json**

```json
{
  "levels": [
    {
      "id": 1,
      "name": "初折",
      "size": 4,
      "max_folds": 1,
      "front": [
        [0, 0, 0, 1],
        [0, 0, 0, 1],
        [0, 0, 0, 1],
        [0, 0, 0, 1]
      ],
      "back": [
        [0, 1, 0, 0],
        [0, 1, 0, 0],
        [0, 1, 0, 0],
        [0, 1, 0, 0]
      ],
      "target": [
        [0, 0, 1, 1],
        [0, 0, 1, 1],
        [0, 0, 1, 1],
        [0, 0, 1, 1]
      ]
    },
    {
      "id": 2,
      "name": "倒影",
      "size": 4,
      "max_folds": 1,
      "front": [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [0, 0, 0, 0]
      ],
      "back": [
        [1, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
      ],
      "target": [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [1, 1, 1, 1]
      ]
    },
    {
      "id": 3,
      "name": "箭头",
      "size": 4,
      "max_folds": 1,
      "front": [
        [0, 0, 0, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 1]
      ],
      "back": [
        [0, 0, 0, 0],
        [1, 1, 0, 0],
        [1, 1, 0, 0],
        [0, 0, 0, 0]
      ],
      "target": [
        [0, 0, 0, 1],
        [0, 0, 1, 1],
        [0, 0, 1, 1],
        [0, 0, 0, 1]
      ]
    },
    {
      "id": 4,
      "name": "钻石",
      "size": 4,
      "max_folds": 1,
      "front": [
        [1, 0, 0, 1],
        [0, 1, 1, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
      ],
      "back": [
        [1, 1, 1, 1],
        [0, 1, 1, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
      ],
      "target": [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 1, 1, 0],
        [1, 1, 1, 1]
      ]
    },
    {
      "id": 5,
      "name": "窄边",
      "size": 4,
      "max_folds": 1,
      "front": [
        [0, 0, 0, 2],
        [0, 0, 0, 2],
        [0, 0, 0, 2],
        [0, 0, 0, 2]
      ],
      "back": [
        [0, 0, 0, 1],
        [0, 0, 0, 1],
        [0, 0, 0, 1],
        [0, 0, 0, 1]
      ],
      "target": [
        [0, 0, 1, 0],
        [0, 0, 1, 0],
        [0, 0, 1, 0],
        [0, 0, 1, 0]
      ]
    },
    {
      "id": 6,
      "name": "棋盘",
      "size": 4,
      "max_folds": 1,
      "front": [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
      ],
      "back": [
        [2, 1, 0, 0],
        [1, 2, 0, 0],
        [2, 1, 0, 0],
        [1, 2, 0, 0]
      ],
      "target": [
        [0, 0, 1, 2],
        [0, 0, 2, 1],
        [0, 0, 1, 2],
        [0, 0, 2, 1]
      ]
    },
    {
      "id": 7,
      "name": "点睛",
      "size": 4,
      "max_folds": 1,
      "front": [
        [3, 3, 3, 3],
        [0, 0, 0, 0],
        [2, 2, 2, 2],
        [1, 1, 1, 1]
      ],
      "back": [
        [1, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0]
      ],
      "target": [
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [2, 2, 2, 2],
        [1, 1, 1, 1]
      ]
    },
    {
      "id": 8,
      "name": "拼合",
      "size": 4,
      "max_folds": 1,
      "front": [
        [1, 0, 1, 2],
        [1, 0, 1, 2],
        [1, 0, 1, 2],
        [1, 0, 1, 2]
      ],
      "back": [
        [2, 0, 0, 0],
        [2, 0, 0, 0],
        [2, 0, 0, 0],
        [2, 0, 0, 0]
      ],
      "target": [
        [0, 2, 1, 2],
        [0, 2, 1, 2],
        [0, 2, 1, 2],
        [0, 2, 1, 2]
      ]
    }
  ]
}
```

**Step 2: 提交**

```bash
git add data/levels.json
git commit -m "feat: add 8 verified puzzle levels"
```

---

### Task 4: 游戏场景 (核心渲染与交互)

**Files:**
- Create: `scripts/game.gd`

**Step 1: 创建 game.gd**

这是游戏核心场景脚本，负责网格渲染、折叠线交互、折叠动画、HUD、胜负判定。

```gdscript
extends Node2D

signal level_completed(level_id: int)
signal back_pressed

const CELL_SIZE := 120
const CELL_GAP := 3
const TARGET_CELL_SIZE := 35
const TARGET_GAP := 2
const GRID_ORIGIN := Vector2(60, 350)
const TARGET_ORIGIN := Vector2(250, 80)
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
const CELL_BORDER_COLOR := Color("#5C4033", 0.08)

var model: GridModel
var level_data: Dictionary
var is_animating := false

# Node references (created in code)
var cell_rects: Array = []      # [row][col] of ColorRect
var target_rects: Array = []
var fold_buttons: Array = []
var fold_lines: Array = []
var fold_label: Label
var win_overlay: ColorRect
var win_panel: PanelContainer


func start_level(data: Dictionary) -> void:
	level_data = data
	model = GridModel.new()
	model.setup(
		int(data.size),
		data.front,
		data.back,
		data.target,
		int(data.max_folds)
	)
	_build_all()
	_refresh_grid()


func _build_all() -> void:
	for child in get_children():
		child.queue_free()
	cell_rects.clear()
	target_rects.clear()
	fold_buttons.clear()
	fold_lines.clear()

	_build_background()
	_build_level_title()
	_build_target_label()
	_build_target_grid()
	_build_grid_border()
	_build_main_grid()
	_build_fold_lines()
	_build_hud()
	_build_win_popup()


# ── Background ──

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(720, 1280)
	bg.z_index = -10
	add_child(bg)


# ── Title ──

func _build_level_title() -> void:
	var lbl := Label.new()
	lbl.text = "第 %d 关 · %s" % [level_data.id, level_data.name]
	lbl.position = Vector2(60, 25)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(lbl)


# ── Target ──

func _build_target_label() -> void:
	var lbl := Label.new()
	lbl.text = "目标图案"
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
			var rect := ColorRect.new()
			rect.size = Vector2(TARGET_CELL_SIZE, TARGET_CELL_SIZE)
			rect.position = Vector2(
				col * (TARGET_CELL_SIZE + TARGET_GAP),
				row * (TARGET_CELL_SIZE + TARGET_GAP)
			)
			rect.color = COLOR_MAP[model.target[row][col]]
			container.add_child(rect)
			row_arr.append(rect)
		target_rects.append(row_arr)


# ── Main Grid ──

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


# ── Fold Lines ──

func _build_fold_lines() -> void:
	var s := model.size
	var total := s * CELL_SIZE + (s - 1) * CELL_GAP

	# Vertical fold lines (between columns)
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

	# Horizontal fold lines (between rows)
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


# ── HUD ──

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


# ── Win Popup ──

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
	next_btn.pressed.connect(func(): level_completed.emit(int(level_data.id)))
	vbox.add_child(next_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color("#5C4033", 0.5)
	back_style.corner_radius_top_left = 12
	back_style.corner_radius_top_right = 12
	back_style.corner_radius_bottom_left = 12
	back_style.corner_radius_bottom_right = 12
	back_style.content_margin_left = 20
	back_style.content_margin_right = 20
	back_style.content_margin_top = 12
	back_style.content_margin_bottom = 12

	var back_btn := Button.new()
	back_btn.text = "返回选关"
	back_btn.add_theme_stylebox_override("normal", back_style)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func():
		win_overlay.visible = false
		win_panel.visible = false
		back_pressed.emit()
	)
	vbox.add_child(back_btn)

	win_panel.add_child(vbox)
	add_child(win_panel)


# ── Fold Logic ──

func _on_fold(is_vertical: bool, fold_pos: int) -> void:
	if is_animating or not model.can_fold():
		return

	# Snapshot colors before model update for animation
	var old_front := model._deep_copy(model.front)
	var result := model.fold(is_vertical, fold_pos)
	if result.is_empty():
		return

	_animate_fold(result, old_front)


func _animate_fold(fold_data: Dictionary, old_front: Array) -> void:
	is_animating = true
	_set_fold_buttons_enabled(false)

	var sources: Array = fold_data.sources
	var tween := create_tween()
	tween.set_parallel(true)

	var is_vert: bool = fold_data.is_vertical
	var fpos: int = fold_data.fold_pos

	# Animate source cells shrinking toward fold line
	for i in range(sources.size()):
		var src: Vector2i = sources[i]
		var cell: ColorRect = cell_rects[src.y][src.x]

		if is_vert:
			var fold_x := GRID_ORIGIN.x + fpos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0
			if src.x < fpos:
				tween.tween_property(cell, "size:x", 0.0, ANIM_DURATION)
				tween.tween_property(cell, "position:x", fold_x, ANIM_DURATION)
			else:
				tween.tween_property(cell, "size:x", 0.0, ANIM_DURATION)
		else:
			var fold_y := GRID_ORIGIN.y + fpos * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0
			if src.y < fpos:
				tween.tween_property(cell, "size:y", 0.0, ANIM_DURATION)
				tween.tween_property(cell, "position:y", fold_y, ANIM_DURATION)
			else:
				tween.tween_property(cell, "size:y", 0.0, ANIM_DURATION)

	tween.chain()
	tween.tween_callback(func():
		_refresh_grid()
		is_animating = false
		_set_fold_buttons_enabled(true)
		_update_fold_label()
		if model.check_win():
			_show_win()
	)


func _set_fold_buttons_enabled(enabled: bool) -> void:
	for btn in fold_buttons:
		btn.disabled = not enabled


func _refresh_grid() -> void:
	var s := model.size
	for row in range(s):
		for col in range(s):
			var rect: ColorRect = cell_rects[row][col]
			rect.color = COLOR_MAP[model.front[row][col]]
			rect.size = Vector2(CELL_SIZE, CELL_SIZE)
			rect.position = _cell_pos(col, row)


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


func _show_win() -> void:
	win_overlay.visible = true
	win_panel.visible = true
```

**Step 2: 验证**

Godot 编辑器中打开脚本确认无语法错误。

**Step 3: 提交**

```bash
git add scripts/game.gd
git commit -m "feat: add game scene with grid rendering, fold animation, and HUD"
```

---

### Task 5: 选关界面

**Files:**
- Create: `scripts/level_select.gd`

**Step 1: 创建 level_select.gd**

```gdscript
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

	# Level buttons
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(100, 280)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	add_child(grid)

	for level in levels_data:
		var btn := Button.new()
		btn.text = "%d\n%s" % [level.id, level.name]
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

		var data := level
		btn.pressed.connect(func(): level_selected.emit(data))
		grid.add_child(btn)
```

**Step 2: 提交**

```bash
git add scripts/level_select.gd
git commit -m "feat: add level select screen"
```

---

### Task 6: 主场景（场景管理）

**Files:**
- Create: `scenes/main.tscn`
- Create: `scripts/main.gd`

**Step 1: 创建 main.gd**

```gdscript
extends Node2D

var levels_data: Array = []
var level_select: Control
var game_screen: Node2D


func _ready() -> void:
	_load_levels()
	_show_level_select()


func _load_levels() -> void:
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
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
	# Go to next level
	var next_idx := -1
	for i in range(levels_data.size()):
		if int(levels_data[i].id) == level_id:
			next_idx = i + 1
			break

	if next_idx >= 0 and next_idx < levels_data.size():
		_on_level_selected(levels_data[next_idx])
	else:
		_show_level_select()
```

**Step 2: 创建 main.tscn**

最小 .tscn 文件，只包含根节点和脚本引用：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

**Step 3: 验证**

在 Godot 编辑器中运行项目 (F5)，应看到：
1. 选关界面显示 8 个关卡按钮
2. 点击关卡进入游戏
3. 点击折叠线触发折叠动画
4. 正确折叠后显示通关弹窗
5. 撤销/重置/返回按钮正常工作

**Step 4: 提交**

```bash
git add scripts/main.gd scenes/main.tscn
git commit -m "feat: add main scene with level select and game integration"
```

---

### Task 7: 视觉微调与翻看背面提示

**Files:**
- Modify: `scripts/game.gd`

**Step 1: 添加背面预览功能**

在 game.gd 的 `_build_hud()` 末尾添加一个 "查看背面" 按钮，按住时显示背面颜色：

在 `_build_hud` 函数末尾追加：

```gdscript
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
```

添加两个函数：

```gdscript
func _show_back() -> void:
	var s := model.size
	for row in range(s):
		for col in range(s):
			var rect: ColorRect = cell_rects[row][col]
			var back_val: int = model.back[row][col]
			if back_val != 0:
				rect.color = COLOR_MAP[back_val].lerp(Color.WHITE, 0.3)
			elif model.front[row][col] == 0:
				rect.color = COLOR_MAP[0]
			else:
				rect.color = COLOR_MAP[model.front[row][col]].lerp(Color.WHITE, 0.5)


func _hide_back() -> void:
	_refresh_grid()
```

**Step 2: 提交**

```bash
git add scripts/game.gd
git commit -m "feat: add peek-at-back-side button for hints"
```

---

### Task 8: 最终集成测试

**Step 1: 完整游玩测试**

运行项目，依次测试：

1. 选关界面显示 8 个关卡
2. 关卡 1：点击第 2 条竖折线 → 折叠动画 → 通关
3. 关卡 2：点击第 2 条横折线 → 折叠动画 → 通关
4. 撤销功能：折叠后点撤销 → 恢复原状
5. 重置功能：折叠后点重置 → 恢复到关卡初始状态
6. 查看背面：按住按钮 → 看到背面颜色 → 松开恢复
7. 通关弹窗：点"下一关" → 进入下一关
8. 返回功能：点返回 → 回到选关界面
9. 最后一关通关后 → 自动回到选关界面

**Step 2: 全部通过后提交**

```bash
git add -A
git commit -m "feat: complete Origami Puzzle MVP with 8 levels"
```
