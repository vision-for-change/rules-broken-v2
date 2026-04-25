extends Control

var _matrix_bg: Control
var _matrix_columns: Array = []

const LEVEL2_SCRIPT := preload("res://scenes/levels/Level2.gd")
const MATRIX_COL_SPACING := 26.0
const MATRIX_ROW_SPACING := 21.0
const MATRIX_FONT_SIZE := 16
const MATRIX_COLOR := Color(0.42, 1.0, 0.76, 0.62)
const MINECRAFT_FONT := preload("res://Minecraft.ttf")

func _ready() -> void:
	AudioManager.play_music("stable")
	ScreenFX.flash_screen(Color(0.7, 1.0, 0.75, 0.28), 0.9)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	randomize()

	_create_matrix_background()
	move_child(_matrix_bg, 0)
	_style_panel()
	_style_labels()
	_style_button($Panel/Margin/VBox/Buttons/ContinueBtn, 18, Color(0.95, 0.9, 0.35))
	_style_button($Panel/Margin/VBox/Buttons/ReplayBtn, 18, Color(0.2, 1.0, 0.6))
	_style_button($Panel/Margin/VBox/Buttons/QuitBtn, 18, Color(1.0, 0.45, 0.35))

	$Panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.15)
	tween.tween_property($Panel, "modulate:a", 1.0, 0.45)

func _create_matrix_background() -> void:
	if is_instance_valid(_matrix_bg):
		_matrix_bg.queue_free()
	_matrix_columns.clear()

	_matrix_bg = Control.new()
	_matrix_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_matrix_bg)

	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.01, 0.03, 0.02, 0.22)
	_matrix_bg.add_child(tint)

	var viewport_size = get_viewport_rect().size
	var cols = int(ceil(viewport_size.x / MATRIX_COL_SPACING)) + 2
	var rows = int(ceil(viewport_size.y / MATRIX_ROW_SPACING)) + 3

	for col in range(cols):
		var x_pos = col * MATRIX_COL_SPACING + 8.0
		var direction = -1.0 if (col % 2 == 0) else 1.0
		var speed = randf_range(26.0, 62.0)
		var labels: Array = []

		for row in range(rows):
			var lbl = Label.new()
			lbl.text = str(randi() % 2)
			lbl.add_theme_font_size_override("font_size", MATRIX_FONT_SIZE)
			lbl.add_theme_color_override("font_color", MATRIX_COLOR)
			lbl.position = Vector2(x_pos, row * MATRIX_ROW_SPACING + randf_range(-6.0, 6.0))
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
			elif randi() % 80 == 0:
				lbl.text = str(randi() % 2)
			lbl.position.y = y

func _style_panel() -> void:
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.03, 0.07, 0.06, 0.76)
	panel_box.border_color = Color(0.32, 1.0, 0.74, 0.8)
	panel_box.border_width_left = 2
	panel_box.border_width_right = 2
	panel_box.border_width_top = 2
	panel_box.border_width_bottom = 2
	panel_box.set_corner_radius_all(10)
	panel_box.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	panel_box.shadow_size = 12
	$Panel.add_theme_stylebox_override("panel", panel_box)

func _style_labels() -> void:
	$Panel/Margin/VBox/Eyebrow.add_theme_font_override("font", MINECRAFT_FONT)
	$Panel/Margin/VBox/Eyebrow.add_theme_font_size_override("font_size", 13)
	$Panel/Margin/VBox/Eyebrow.add_theme_color_override("font_color", Color(0.55, 1.0, 0.86))
	$Panel/Margin/VBox/Eyebrow.add_theme_color_override("font_outline_color", Color.BLACK)
	$Panel/Margin/VBox/Eyebrow.add_theme_constant_override("outline_size", 1)

	$Panel/Margin/VBox/TitleLabel.add_theme_font_override("font", MINECRAFT_FONT)
	$Panel/Margin/VBox/TitleLabel.add_theme_font_size_override("font_size", 32)
	$Panel/Margin/VBox/TitleLabel.add_theme_color_override("font_color", Color(0.92, 1.0, 0.95))
	$Panel/Margin/VBox/TitleLabel.add_theme_color_override("font_outline_color", Color.BLACK)
	$Panel/Margin/VBox/TitleLabel.add_theme_constant_override("outline_size", 2)

	$Panel/Margin/VBox/Sub.add_theme_font_override("font", MINECRAFT_FONT)
	$Panel/Margin/VBox/Sub.add_theme_font_size_override("font_size", 16)
	$Panel/Margin/VBox/Sub.add_theme_color_override("font_color", Color(0.74, 0.9, 0.82))
	if PlayerState.endless_unlocked:
		$Panel/Margin/VBox/Sub.text = "Boss defeated.\nEndless sectors unlocked.\nPush deeper into the network."

	$Panel/Margin/VBox/Hint.add_theme_font_override("font", MINECRAFT_FONT)
	$Panel/Margin/VBox/Hint.add_theme_font_size_override("font_size", 12)
	$Panel/Margin/VBox/Hint.add_theme_color_override("font_color", Color(0.46, 0.72, 0.63))

func _style_button(btn: Button, size: int, color: Color) -> void:
	btn.add_theme_font_override("font", MINECRAFT_FONT)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 1)

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.02, 0.08, 0.06, 0.88)
	stylebox.border_color = color
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.set_corner_radius_all(6)
	stylebox.content_margin_left = 14
	stylebox.content_margin_right = 14
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", stylebox)

	var hover_box = stylebox.duplicate()
	hover_box.bg_color = Color(0.06, 0.15, 0.12, 0.95)
	btn.add_theme_stylebox_override("hover", hover_box)

	var pressed_box = stylebox.duplicate()
	pressed_box.bg_color = Color(0.03, 0.06, 0.05, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_box)

	btn.mouse_entered.connect(func(): AudioManager.play_sfx_with_options("hover", -20.0, 0.7, 1.3))
	btn.pressed.connect(func(): AudioManager.play_sfx_with_options("click", -15.0, 0.7, 1.3))

func _on_continue_pressed() -> void:
	PlayerState.current_health = PlayerState.max_health
	LEVEL2_SCRIPT.queue_start_floor(6)
	ScreenFX.transition_to_scene_with_black_fade("res://scenes/levels/Level2.tscn", 0.6, 1.0, 0.6)

func _on_replay_pressed() -> void:
	PlayerState.reset_run_progression()
	PlayerState.current_health = PlayerState.max_health
	LEVEL2_SCRIPT.reset_start_floor()
	ScreenFX.transition_to_scene_with_black_fade("res://scenes/levels/Level2.tscn", 0.6, 1.0, 0.6)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_on_continue_pressed()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_replay_pressed()
		elif event.keycode == KEY_ESCAPE:
			_on_quit_pressed()
