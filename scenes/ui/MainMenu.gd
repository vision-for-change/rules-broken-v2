extends Control

var _matrix_bg: Control
var _matrix_columns: Array = []
const LEVEL2_SCRIPT := preload("res://scenes/levels/Level2.gd")

const MATRIX_COL_SPACING := 34.0
const MATRIX_ROW_SPACING := 28.0
const MATRIX_FONT_SIZE := 16
const MATRIX_BASE_COLOR := Color(0.1, 0.8, 0.4, 0.5)
const MINECRAFT_FONT := preload("res://Minecraft.ttf")

func _ready() -> void:
	Music.playglobalsound("res://Sounds/freesound_community-matrix-redux-78819.mp3")
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
	$VBox.offset_top = -180
	$VBox.offset_right = 300
	$VBox.offset_bottom = 300
	$VBox.alignment = BoxContainer.ALIGNMENT_CENTER

	_style_label($VBox/SubLabel, 18, Color(0.4, 0.6, 0.5, 1))
	_style_button($VBox/PlayBtn, 20)
	
	# Create debug buttons (Tutorial and Boss only)
	_create_menu_buttons()
	
	if has_node("VBox/SelectWeaponBtn"):
		_style_button($VBox/SelectWeaponBtn, 20)

	_connect_button_hover_sounds()
	move_child($VBox, get_child_count() - 1)

func _create_menu_buttons() -> void:
	var vbox = $VBox

	# Tutorial Button
	var tutorial_btn: Button
	if has_node("VBox/TutorialBtn"):
		tutorial_btn = get_node("VBox/TutorialBtn")
	else:
		tutorial_btn = Button.new()
		tutorial_btn.name = "TutorialBtn"
		tutorial_btn.text = "PLAY TUTORIAL"
		vbox.add_child(tutorial_btn)
		vbox.move_child(tutorial_btn, 2)

	_style_button(tutorial_btn, 20, Color(0.4, 0.9, 1.0))
	if not tutorial_btn.pressed.is_connected(_on_tutorial_pressed):
		tutorial_btn.pressed.connect(_on_tutorial_pressed)

	# Boss Debug (Floor 5)
	var boss_btn: Button
	if has_node("VBox/Floor5Btn"):
		boss_btn = get_node("VBox/Floor5Btn")
	else:
		boss_btn = Button.new()
		boss_btn.name = "Floor5Btn"
		vbox.add_child(boss_btn)
		vbox.move_child(boss_btn, 3)

	boss_btn.text = "BOSS: ROGUE AI"
	_style_button(boss_btn, 18, Color(0.8, 0.2, 0.2))
	if not boss_btn.pressed.is_connected(_on_floor_5_pressed):
		boss_btn.pressed.connect(_on_floor_5_pressed)

	# Ensure Floor 1-4 buttons are removed if they were created via script previously
	for i in range(1, 5):
		var btn_name = "Floor%dBtn" % i
		if has_node("VBox/" + btn_name):
			get_node("VBox/" + btn_name).queue_free()
func _connect_button_hover_sounds() -> void:
	var buttons = []
	for child in $VBox.get_children():
		if child is Button:
			buttons.append(child)
	
	for btn in buttons:
		if is_instance_valid(btn) and btn is Button:
			btn.mouse_entered.connect(func(): AudioManager.play_sfx_with_options("hover", -20.0, 0.7, 1.3))

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
			lbl.add_theme_font_override("font", MINECRAFT_FONT)
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
	lbl.add_theme_font_override("font", MINECRAFT_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	if color != Color.WHITE:
		lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	if lbl is Label:
		(lbl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(lbl as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _style_button(btn: Button, size: int, color: Color = Color(0.2, 1.0, 0.5)) -> void:
	btn.add_theme_font_override("font", MINECRAFT_FONT)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.8, 0.3))
	btn.add_theme_color_override("font_focus_color", Color(0.3, 1.0, 0.6))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 1)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.02, 0.08, 0.05, 0.8)
	stylebox.border_color = color
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.set_corner_radius_all(4)
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 6
	stylebox.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", stylebox)
	var hover_box = stylebox.duplicate()
	hover_box.bg_color = Color(0.05, 0.15, 0.08, 0.9)
	btn.add_theme_stylebox_override("hover", hover_box)
	var pressed_box = stylebox.duplicate()
	pressed_box.bg_color = Color(0.02, 0.06, 0.03, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_box)
	# Check if already connected to avoid duplicate sounds
	var is_connected = false
	for connection in btn.pressed.get_connections():
		if connection.callable.get_object() == AudioManager:
			is_connected = true
			break
	if not is_connected:
		btn.pressed.connect(func(): AudioManager.play_sfx_with_options("click", -15.0, 0.7, 1.3))

func _on_play_pressed() -> void:
	Music.stopsound()
	PlayerState.reset_run_progression()
	LEVEL2_SCRIPT.reset_start_floor()
	ScreenFX.transition_to_scene_with_black_fade("res://scenes/levels/Level2.tscn", 0.6, 1.0, 0.6)

func _on_tutorial_pressed() -> void:
	Music.stopsound()
	PlayerState.reset_run_progression()
	ScreenFX.transition_to_scene_with_black_fade("res://tutorial.tscn", 0.6, 1.0, 0.6)

func _on_floor_5_pressed() -> void:
	Music.stopsound()
	PlayerState.reset_run_progression()
	LEVEL2_SCRIPT.queue_start_floor(5)
	ScreenFX.transition_to_scene_with_black_fade("res://scenes/levels/LevelBoss.tscn", 0.6, 1.0, 0.6)

func _on_select_weapon_pressed() -> void:
	ScreenFX.transition_to_scene("res://scenes/ui/GunSelectScreen.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_play_pressed()
