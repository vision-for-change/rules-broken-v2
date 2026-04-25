extends Control

const LEVEL2_SCRIPT := preload("res://scenes/levels/Level2.gd")
const MINECRAFT_FONT := preload("res://Minecraft.ttf")

func _ready() -> void:
	_style_summary()
	$VBox/RetryBtn.add_theme_font_size_override("font_size", 16)
	$VBox/MenuBtn.add_theme_font_size_override("font_size", 16)
	_style_button($VBox/RetryBtn, 16, Color(0.2, 1.0, 0.5))
	_style_button($VBox/MenuBtn, 16, Color(0.2, 1.0, 0.5))
	ScreenFX.flash_screen(Color(0.086, 0.642, 0.287, 0.6), 0.5)

func _style_summary() -> void:
	var lines: Array[String] = []
	if PlayerState.boss_defeated_this_run:
		lines.append("BOSS DEFEATED")
	lines.append("MAXIMUM LEVEL ACHIEVED: LEVEL %d" % PlayerState.max_level_achieved)
	$VBox/SummaryLabel.text = "\n".join(lines)
	$VBox/SummaryLabel.add_theme_font_override("font", MINECRAFT_FONT)
	$VBox/SummaryLabel.add_theme_font_size_override("font_size", 16)
	$VBox/SummaryLabel.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	$VBox/SummaryLabel.add_theme_color_override("font_outline_color", Color.BLACK)
	$VBox/SummaryLabel.add_theme_constant_override("outline_size", 2)

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
	btn.pressed.connect(func(): AudioManager.play_sfx_with_options("click", -15.0, 0.7, 1.3))

func _on_retry_pressed() -> void:
	PlayerState.reset_run_progression()
	LEVEL2_SCRIPT.reset_start_floor()
	ScreenFX.transition_to_scene("res://scenes/levels/Level2.tscn")
	
func _on_menu_pressed() -> void:
	PlayerState.reset_run_progression()
	ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_retry_pressed()
		if event.keycode == KEY_ESCAPE:
			_on_menu_pressed()
