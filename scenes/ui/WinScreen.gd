extends Control

var _matrix_bg: Control
var _matrix_columns: Array = []

const MATRIX_COL_SPACING := 28.0
const MATRIX_ROW_SPACING := 22.0
const MATRIX_FONT_SIZE := 14
const WIN_COLOR := Color(1.0, 0.9, 0.2, 0.6) # Golden matrix for win

func _ready() -> void:
	AudioManager.play_music("stable")
	ScreenFX.flash_screen(Color(1.0, 0.9, 0.3, 0.4), 1.2)
	
	_create_matrix_background()
	
	$VBox/TitleLabel.text = "// SYSTEM TOTAL BREACH //"
	$VBox/TitleLabel.add_theme_font_size_override("font_size", 36)
	$VBox/TitleLabel.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	$VBox/TitleLabel.add_theme_color_override("outline_color", Color.BLACK)
	$VBox/TitleLabel.add_theme_constant_override("outline_size", 4)
	
	$VBox/Sub.text = "All security protocols dismantled.\nAccess to reality granted.\n\nThank you for playing."
	$VBox/Sub.add_theme_font_size_override("font_size", 16)
	$VBox/Sub.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	
	$VBox/Hint.text = "[ PRESS ANY KEY TO LOG OUT ]"
	$VBox/Hint.add_theme_font_size_override("font_size", 12)
	$VBox/Hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	
	# Animate the content
	$VBox.modulate.a = 0
	var t = create_tween()
	t.tween_interval(0.5)
	t.tween_property($VBox, "modulate:a", 1.0, 2.0)
	
	# Subtle glitch effect on title
	_glitch_title()

func _glitch_title() -> void:
	while true:
		await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
		var original_pos = $VBox/TitleLabel.position
		for i in range(10):
			$VBox/TitleLabel.position = original_pos + Vector2(randf_range(-4, 4), randf_range(-2, 2))
			$VBox/TitleLabel.modulate = Color(randf(), 1.0, randf())
			await get_tree().create_timer(0.05).timeout
		$VBox/TitleLabel.position = original_pos
		$VBox/TitleLabel.modulate = Color.WHITE

func _create_matrix_background() -> void:
	_matrix_bg = Control.new()
	_matrix_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_matrix_bg)
	move_child(_matrix_bg, 0)

	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color(0.05, 0.05, 0.02, 1.0)
	_matrix_bg.add_child(bg_rect)

	var viewport_size = get_viewport_rect().size
	var cols = int(ceil(viewport_size.x / MATRIX_COL_SPACING)) + 2
	var rows = int(ceil(viewport_size.y / MATRIX_ROW_SPACING)) + 3

	for col in range(cols):
		var x_pos = col * MATRIX_COL_SPACING
		var speed = randf_range(40.0, 100.0)
		var labels: Array = []
		for row in range(rows):
			var lbl = Label.new()
			lbl.text = char(randi_range(33, 126))
			lbl.add_theme_font_size_override("font_size", MATRIX_FONT_SIZE)
			lbl.add_theme_color_override("font_color", WIN_COLOR)
			lbl.position = Vector2(x_pos, row * MATRIX_ROW_SPACING)
			_matrix_bg.add_child(lbl)
			labels.append(lbl)
		_matrix_columns.append({"labels": labels, "speed": speed})

func _process(delta: float) -> void:
	var viewport_h = get_viewport_rect().size.y
	for column in _matrix_columns:
		var speed = column["speed"]
		for lbl in column["labels"]:
			lbl.position.y += speed * delta
			if lbl.position.y > viewport_h:
				lbl.position.y = -MATRIX_ROW_SPACING
				lbl.text = char(randi_range(33, 126))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")
