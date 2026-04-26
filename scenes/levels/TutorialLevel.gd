## TutorialLevel.gd
## Interactive tutorial for movement, combat, hacks, and system rules.
extends "res://scenes/levels/BaseLevel.gd"

const TERMINAL_SCENE = preload("res://scenes/objects/Terminal.tscn")
const SIGN_SCENE = preload("res://scenes/objects/RuleSign.tscn")
const BUG_SCENE = preload("res://scenes/enemy/bugs.tscn")
const SNAKE_SCENE = preload("res://scenes/enemy/Snake.tscn")
const WORM_SCENE = preload("res://scenes/enemy/worm.tscn")
const EXIT_SCENE = preload("res://scenes/objects/Exit.tscn")
const MEDKIT_SCENE = preload("res://scenes/objects/HealthPickup.tscn")

enum Stage { MOVEMENT, BUG_COMBAT, SNAKE_COMBAT, HACK_MENU, DONE }
var _current_stage = Stage.MOVEMENT
var _stage_nodes = []
var _tutorial_canvas: CanvasLayer
var _instr_label: Label
var _enemies_killed_in_practice := 0
var _completion_popup: PanelContainer = null

func _ready() -> void:
	level_number = 5 # Force high level so hacks are visible in HUD
	level_title_text = "INITIALIZATION // TUTORIAL"
	super._ready()
	
	# Make player invincible for tutorial
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		players[0].call("set_hacked_client_modes", false, false, false, false, false, false, false, true)
		# Give player full loadout for practice
		var inv = players[0].get_node_or_null("Inventory")
		if inv:
			inv.call("set_max_slots", 4)
			var gun_ids: Array[String] = ["pistol", "ump", "ak47", "lightsaber"]
			inv.call("set_loadout", gun_ids, "pistol")
	
	_setup_tutorial_ui()
	_start_stage(Stage.MOVEMENT)
	
	# Listen for events
	EventBus.action_approved.connect(_on_action_approved)
	EventBus.enemy_defeated.connect(_on_enemy_defeated_tutorial)
	# Connect to a way to detect hack toggle (HUD might not emit one, but we can check Player state)

func get_stage_number() -> int:
	return 5 # Unlock all hacks for trial

func _setup_tutorial_ui() -> void:
	_tutorial_canvas = CanvasLayer.new()
	_tutorial_canvas.layer = 50
	add_child(_tutorial_canvas)
	
	_instr_label = Label.new()
	_instr_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_instr_label.offset_top = -140
	_instr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instr_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instr_label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	_instr_label.add_theme_font_size_override("font_size", 22)
	_instr_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	_instr_label.add_theme_color_override("outline_color", Color.BLACK)
	_instr_label.add_theme_constant_override("outline_size", 2)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top = -160
	bg.color = Color(0, 0, 0, 0.75)
	_tutorial_canvas.add_child(bg)
	_tutorial_canvas.add_child(_instr_label)
	
	var esc_hint = Label.new()
	esc_hint.text = "[ESC] TO EXIT TO MAIN MENU"
	esc_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	esc_hint.offset_left = -250
	esc_hint.offset_top = 20
	esc_hint.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	esc_hint.add_theme_font_size_override("font_size", 14)
	esc_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	_tutorial_canvas.add_child(esc_hint)

func _start_stage(stage: Stage) -> void:
	_current_stage = stage
	_clear_stage_nodes()
	
	match stage:
		Stage.MOVEMENT:
			_instr_label.text = "WELCOME, AGENT.\nUSE [WASD] TO MOVE. [SHIFT] TO DASH."
			EventBus.log("SYSTEM: Awaiting movement signature...", "info")
			
		Stage.BUG_COMBAT:
			_instr_label.text = "THREAT DETECTED: BUG.\nAIM WITH [MOUSE] AND [CLICK] TO ELIMINATE."
			var bug = BUG_SCENE.instantiate()
			bug.position = $Player.position + Vector2(250, 0)
			bug.set("entity_id", "tutorial_bug")
			add_child(bug)
			_stage_nodes.append(bug)

		Stage.SNAKE_COMBAT:
			_instr_label.text = "THREAT DETECTED: SNAKE (BULLET IMMUNE).\nUSE [SHIFT-DASH] AT HIGH SPEED TO DESTROY IT."
			var snake = SNAKE_SCENE.instantiate()
			snake.position = $Player.position + Vector2(250, 50)
			snake.set("entity_id", "tutorial_snake")
			add_child(snake)
			_stage_nodes.append(snake)

		Stage.HACK_MENU:
			_instr_label.text = "SYSTEM ACCESS GRANTED.\nPRESS [TAB] TO OPEN HACKS. TRY ENABLING ONE."
			EventBus.log("HACKING INTERFACE ONLINE", "exploit")
			# Start a loop to check if player toggled any hack
			_check_for_hack_trial()

		Stage.DONE:
			_instr_label.text = "CERTIFICATION COMPLETE."
			_show_advanced_completion_ui()

func _check_for_hack_trial() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or _current_stage != Stage.HACK_MENU: return
	
	var modes = player.call("get_hacked_client_modes")
	var any_hack_active = false
	for val in modes.values():
		if val == true and val != modes.get("invincible", false): # Ignore invincibility
			any_hack_active = true
			break
			
	if any_hack_active:
		await get_tree().create_timer(2.0).timeout
		_start_stage(Stage.DONE)
	else:
		get_tree().create_timer(0.5).timeout.connect(_check_for_hack_trial)

func _on_action_approved(action: Dictionary) -> void:
	if _current_stage == Stage.MOVEMENT and action["type"] == ActionBus.MOVE:
		get_tree().create_timer(2.0).timeout.connect(func(): 
			if _current_stage == Stage.MOVEMENT: _start_stage(Stage.BUG_COMBAT)
		)

func _on_enemy_defeated_tutorial(_id: String) -> void:
	if _current_stage == Stage.BUG_COMBAT:
		_start_stage(Stage.SNAKE_COMBAT)
	elif _current_stage == Stage.SNAKE_COMBAT:
		_start_stage(Stage.HACK_MENU)

func _show_advanced_completion_ui() -> void:
	if _completion_popup: return
	
	# Advanced UI construction
	_completion_popup = PanelContainer.new()
	_completion_popup.set_anchors_preset(Control.PRESET_CENTER)
	_completion_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_completion_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_completion_popup.custom_minimum_size = Vector2(500, 300)
	_tutorial_canvas.add_child(_completion_popup)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.1, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 1.0, 0.5, 0.8)
	style.set_corner_radius_all(12)
	style.shadow_size = 20
	style.shadow_color = Color(0, 1, 0.2, 0.15)
	_completion_popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_completion_popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "TUTORIAL // COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "System initialized. Agent certified for field operations.\n\nWould you like to repeat the training\nor proceed to the mainframe?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	vbox.add_child(desc)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(hbox)
	
	var redo_btn = Button.new()
	redo_btn.text = " REDO TUTORIAL "
	_style_advanced_button(redo_btn, Color(0.4, 0.8, 1.0))
	redo_btn.pressed.connect(_on_redo_pressed)
	hbox.add_child(redo_btn)
	
	var menu_btn = Button.new()
	menu_btn.text = " MAIN MENU "
	_style_advanced_button(menu_btn, Color(0.2, 1.0, 0.5))
	menu_btn.pressed.connect(_on_menu_pressed)
	hbox.add_child(menu_btn)
	
	# Intro animation for popup
	_completion_popup.modulate.a = 0
	_completion_popup.scale = Vector2(0.9, 0.9)
	_completion_popup.pivot_offset = Vector2(250, 150)
	var t = create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_completion_popup, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(_completion_popup, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	AudioManager.play_sfx("dragon-studio-cinematic-boom")

func _style_advanced_button(btn: Button, color: Color) -> void:
	btn.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", color)
	
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0,0,0,0.4)
	sb_normal.border_width_left = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = color
	sb_normal.set_corner_radius_all(6)
	sb_normal.content_margin_left = 15
	sb_normal.content_margin_right = 15
	
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = color * Color(1,1,1,0.2)
	sb_hover.border_color = Color.WHITE
	
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_normal)
	btn.focus_mode = Control.FOCUS_NONE

func _on_redo_pressed() -> void:
	ScreenFX.transition_to_scene("res://tutorial.tscn")

func _on_menu_pressed() -> void:
	ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")

func _clear_stage_nodes() -> void:
	for n in _stage_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_stage_nodes.clear()

func _on_level_complete() -> void:
	# Standard completion (if exit portal used)
	_start_stage(Stage.DONE)
