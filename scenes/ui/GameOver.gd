extends Control

func _ready() -> void:
	$VBox/TitleLabel.add_theme_font_size_override("font_size", 36)
	$VBox/TitleLabel.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	$VBox/Sub.add_theme_font_size_override("font_size", 14)
	$VBox/Sub.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	$VBox/RetryBtn.add_theme_font_size_override("font_size", 14)
	$VBox/MenuBtn.add_theme_font_size_override("font_size", 14)
	ScreenFX.flash_screen(Color(1, 0, 0.1, 0.6), 0.5)

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/Level2.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_retry_pressed()
		if event.keycode == KEY_ESCAPE:
			_on_menu_pressed()
