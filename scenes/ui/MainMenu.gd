extends Control

func _ready() -> void:
	AudioManager.play_music("stable")
	$VBox/TitleLabel.add_theme_font_size_override("font_size", 14)
	$VBox/TitleLabel.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 1))
	$VBox/SubLabel.add_theme_font_size_override("font_size", 7)
	$VBox/SubLabel.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5, 1))
	$VBox/PlayBtn.add_theme_font_size_override("font_size", 9)
	$VBox/QuitBtn.add_theme_font_size_override("font_size", 9)
	$VBox/InfoLabel.add_theme_font_size_override("font_size", 6)
	$VBox/InfoLabel.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45, 1))

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/Level1.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_play_pressed()
