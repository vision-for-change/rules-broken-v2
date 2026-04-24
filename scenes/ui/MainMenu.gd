extends Control

var _matrix_bg: Control
var _matrix_columns: Array = []
const LEVEL2_SCRIPT := preload("res://scenes/levels/Level2.gd")

const MATRIX_COL_SPACING := 34.0
const MATRIX_ROW_SPACING := 28.0
const MATRIX_FONT_SIZE := 16
const MATRIX_BASE_COLOR := Color(0.1, 0.8, 0.4, 0.5)

func _ready() -> void:
	AudioManager.play_music("stable")
	randomize()

	set_anchors_preset(Control.PRESET_FULL_RECT)

	if has_node("Background"):
		$Background.visible = false
	if has_node("ScanlineOverlay"):
		$ScanlineOverlay.visible = false

	_create_matrix_background()
	move_child(_matrix_bg, 0)

	$VBox.anchor_left = 0.5
	$VBox.anchor_top = 0.5
	$VBox.anchor_right = 0.5
	$VBox.anchor_bottom = 0.5
	$VBox.offset_left = -300
	$VBox.offset_top = 100
	$VBox.offset_right = 300
	$VBox.offset_bottom = 500
	$VBox.alignment = BoxContainer.ALIGNMENT_CENTER

	_style_label($VBox/SubLabel, 18, Color(0.4, 0.6, 0.5, 1))
	_style_label($VBox/PlayBtn, 20)
	_style_label($VBox/Floor5Btn, 18)
	_style_label($VBox/QuitBtn, 20)
	_style_label($VBox/InfoLabel, 13, Color(0.35, 0.35, 0.45, 1))

	if has_node("VBox/InstructionsBtn"):
		_style_label($VBox/InstructionsBtn, 18, Color(0.8, 0.8, 0.3))

	if has_node("InstructionsPanel"):
		_style_label($InstructionsPanel/VBox/Title, 24, Color(0.2, 1.0, 0.8))
		_style_label($InstructionsPanel/VBox/Content, 14, Color(0.9, 0.9, 0.9))
		_style_label($InstructionsPanel/VBox/CloseInstructionsBtn, 16)

	# ✅ YOUR CHANGE
	if has_node("VBox/SelectWeaponBtn"):
		$VBox/SelectWeaponBtn.add_theme_font_size_override("font_size", 9)
		$VBox/SelectWeaponBtn.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))

	move_child($VBox, get_child_count() - 1)

func _create_matrix_background() -> void:
	if is_instance_valid(_matrix_bg):
		_matrix_bg.queue_free()
	_matrix_columns.clear()

	_matrix_bg = Control.new()
	_matrix_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_matrix_bg)

	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color(0.03, 0.06, 0.05, 1.0)
	_matrix_bg.add_child(bg_rect)

	var viewport_size = get_viewport_rect().size
	var cols = int(ceil(viewport_size.x / MATRIX_COL_SPACING)) + 2
	var rows = int(ceil(viewport_size.y / MATRIX_ROW_SPACING)) + 3

	for col in range(cols):
		var x_pos = col * MATRIX_COL_SPACING + 8.0
		var direction = -1.0 if (col % 2 == 0) else 1.0
		var speed = randf_range(22.0, 58.0)
		var labels: Array = []

		for row in range(rows):
			var lbl = Label.new()
			lbl.text = str(randi() % 2)
			lbl.add_theme_font_size_override("font_size", MATRIX_FONT_SIZE)
			lbl.add_theme_color_override("font_color", MATRIX_BASE_COLOR)
			lbl.position = Vector2(x_pos, row * MATRIX_ROW_SPACING + randf_range(-8.0, 8.0))
			_matrix_bg.add_child(lbl)
			labels.append(lbl)

		_matrix_columns.append({
			"labels": labels,
			"speed": speed,
			"direction": direction
		})

func _process(delta: float) -> void:
	if _matrix_columns.is_empty():
		return

	var viewport_h = get_viewport_rect().size.y

	for column in _matrix_columns:
		var speed: float = column["speed"]
		var direction: float = column["direction"]
		var labels: Array = column["labels"]

		for lbl in labels:
			var y = lbl.position.y + (speed * direction * delta)

			if direction > 0.0 and y > viewport_h + MATRIX_ROW_SPACING:
				y = -MATRIX_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif direction < 0.0 and y < -MATRIX_ROW_SPACING:
				y = viewport_h + MATRIX_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif randi() % 90 == 0:
				lbl.text = str(randi() % 2)

			lbl.position.y = y

func _style_label(lbl: Control, size: int, color: Color = Color.WHITE) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE:
		lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	if lbl is Label:
		(lbl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(lbl as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _on_play_pressed() -> void:
	LEVEL2_SCRIPT.reset_start_floor()
	ScreenFX.transition_to_scene("res://scenes/levels/Level2.tscn")

func _on_floor_5_pressed() -> void:
	LEVEL2_SCRIPT.queue_start_floor(5)
	ScreenFX.transition_to_scene("res://scenes/levels/Level2.tscn")

func _on_select_weapon_pressed() -> void:
	ScreenFX.transition_to_scene("res://scenes/ui/GunSelectScreen.tscn")

func _on_instructions_pressed() -> void:
	if has_node("InstructionsPanel"):
		$InstructionsPanel.visible = true
		$VBox.visible = false

func _on_close_instructions_pressed() -> void:
	if has_node("InstructionsPanel"):
		$InstructionsPanel.visible = false
		$VBox.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_play_pressed()
