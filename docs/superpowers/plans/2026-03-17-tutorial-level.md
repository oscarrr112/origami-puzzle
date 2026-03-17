# Tutorial Level Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a blocking step-by-step tutorial (level 0) that teaches the corner-click fold interaction.

**Architecture:** New `TutorialOverlay` CanvasLayer with mask + text panel. game.gd gains tutorial mode: emits signals on key actions, defers to overlay for input blocking. Tutorial steps defined as Array[Dictionary] in game.gd. Level 0 data added to levels.json.

**Tech Stack:** Godot 4.6, GDScript

**Spec:** `docs/superpowers/specs/2026-03-17-tutorial-level-design.md`

---

## Chunk 1: TutorialOverlay + game.gd integration + level data

### Task 1: Create tutorial_overlay.gd

**Files:**
- Create: `scripts/tutorial_overlay.gd`

- [ ] **Step 1: Create the TutorialOverlay script**

```gdscript
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
			_tap_hint.text = "请稍候..."
			_tap_hint.visible = true
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
		## Block all input during WAIT_ACTION
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var step: Dictionary = _steps[_current_step]
			var step_type: String = step.get("type", "INFO")

			match step_type:
				"INFO":
					## Any click advances
					get_viewport().set_input_as_handled()
					_advance()
				"WAIT_CLICK":
					if _highlight_rect.has_point(mb.position):
						## Click is in highlight area — let it through to game.gd
						## and advance to next step
						click_in_highlight.emit()
						_advance()
					else:
						## Block click outside highlight
						get_viewport().set_input_as_handled()


## Called by game.gd when a WAIT_ACTION condition is met
func notify_action_completed() -> void:
	if _waiting_for_action:
		_waiting_for_action = false
		_advance()
```

- [ ] **Step 2: Commit**

```bash
git add scripts/tutorial_overlay.gd
git commit -m "feat: add TutorialOverlay with mask, text panel, step system"
```

---

### Task 2: Add tutorial level data to levels.json

**Files:**
- Modify: `data/levels.json`

- [ ] **Step 1: Insert tutorial level at the beginning of the levels array**

Add this as the first element of the `"levels"` array in levels.json (before id:1):

```json
{
  "id": 0,
  "name": "教学",
  "size": 4,
  "max_folds": 1,
  "front": [
    [1, 1, 0, 0],
    [1, 1, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0]
  ],
  "back": [
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0]
  ],
  "target": [
    [0, 0, 1, 1],
    [0, 0, 1, 1],
    [0, 0, 0, 0],
    [0, 0, 0, 0]
  ],
  "folds": [
    {"type": "v", "pos": 2}
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add data/levels.json
git commit -m "feat: add tutorial level (id=0) to levels.json"
```

---

### Task 3: Integrate tutorial into game.gd

**Files:**
- Modify: `scripts/game.gd`

- [ ] **Step 1: Add tutorial signals and state variable**

After the existing signals at the top of game.gd, add:

```gdscript
var _tutorial: TutorialOverlay = null
```

- [ ] **Step 2: Add tutorial setup in `start_level`**

At the end of `start_level()`, after `_draw_corner_hints()`, add:

```gdscript
	if int(data["id"]) == 0:
		_start_tutorial()
```

- [ ] **Step 3: Add `_start_tutorial` method**

This method defines all tutorial steps with their highlight rects and types, then creates and starts the overlay. Add this after `_draw_corner_hints`:

```gdscript
func _start_tutorial() -> void:
	var s := model.size
	var total := float(s * CELL_SIZE + (s - 1) * CELL_GAP)

	## Calculate UI element rects for highlighting
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
	## V2 fold line area (narrow vertical band at center)
	var v2_x := GRID_ORIGIN.x + 2 * (CELL_SIZE + CELL_GAP) - CELL_GAP / 2.0 - 1
	var fold_line_rect := Rect2(
		Vector2(v2_x - 20, GRID_ORIGIN.y - 12),
		Vector2(40, total + 24)
	)
	## Corner (0,0) cell rect
	var corner_rect := Rect2(
		_cell_pos(0, 0) - Vector2(4, 4),
		Vector2(CELL_SIZE + 8, CELL_SIZE + 8)
	)
	## Target cell (0,3) rect — mirror of (0,0) across v2
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
			"id": "click_corner",
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
			"id": "click_target",
		},
		{
			"type": "WAIT_ACTION",
			"text": "",
			"highlight": grid_rect,
			"id": "wait_fold",
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
```

- [ ] **Step 4: Notify tutorial when fold animation completes**

In `_animate_fold`, after `is_animating = false` and before the `check_win()` block, add:

```gdscript
	if _tutorial:
		_tutorial.notify_action_completed()
```

- [ ] **Step 5: Suppress win popup during tutorial**

The tutorial's final INFO step should show before the win popup. Modify the win check in `_animate_fold` — wrap it so it waits for tutorial completion:

Replace the win check block:
```gdscript
	if model.check_win():
		await get_tree().create_timer(0.5).timeout
		_show_win()
```

With:
```gdscript
	if model.check_win():
		if _tutorial:
			## Tutorial will show its own completion message
			## Win popup shows after tutorial ends
			await _tutorial.completed
		await get_tree().create_timer(0.5).timeout
		_show_win()
```

- [ ] **Step 6: Commit**

```bash
git add scripts/game.gd
git commit -m "feat: integrate tutorial overlay into game.gd with 10-step flow"
```

---

### Task 4: Manual testing

- [ ] **Step 1: Open the game, select level 0 (教学)**

Verify:
- Dark overlay appears with text: "欢迎来到折纸游戏！..."
- Target grid area is highlighted (visible through mask cutout)
- Clicking anywhere advances to next step

- [ ] **Step 2: Walk through all INFO steps (1-5)**

Verify each step highlights the correct area:
- Step 1: Target grid
- Step 2: Main grid
- Step 3: Back preview
- Step 4: Fold counter label
- Step 5: Dashed fold line

- [ ] **Step 3: Test WAIT_CLICK on corner (step 6)**

Verify:
- Only the corner cell (0,0) is highlighted
- Clicking outside the highlight does nothing
- Clicking the corner selects it AND advances the tutorial

- [ ] **Step 4: Test INFO + WAIT_CLICK on target (steps 7-8)**

Verify:
- Step 7 shows gold target area, click anywhere to continue
- Step 8 requires clicking the gold target cell to execute fold

- [ ] **Step 5: Test fold + completion (steps 9-10)**

Verify:
- Fold animation plays
- Tutorial shows completion message
- Win popup appears after tutorial dismissal

- [ ] **Step 6: Commit if all tests pass**

```bash
git add -A
git commit -m "feat: complete tutorial level implementation"
```
