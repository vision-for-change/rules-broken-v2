extends Control

func _ready() -> void:
	$VBox/RetryBtn.add_theme_font_size_override("font_size", 14)
	$VBox/MenuBtn.add_theme_font_size_override("font_size", 14)
	ScreenFX.flash_screen(Color(0.086, 0.642, 0.287, 0.6), 0.5)

func _on_retry_pressed() -> void:
	ScreenFX.transition_to_scene("res://scenes/levels/Level2.tscn")
	
func _on_menu_pressed() -> void:
	ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_retry_pressed()
		if event.keycode == KEY_ESCAPE:
			_on_menu_pressed()
