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

	# Initialize player hack modes for tutorial
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player = players[0]
		player.call("set_invincible", true)
		player.call("set_hacked_client_modes", false, false, false, false, false, false)
		# Give player full loadout for practice
		var inv = player.get_node_or_null("Inventory")
		if inv:
			inv.call("set_max_slots", 4)
			var gun_ids: Array[String] = ["pistol", "ump", "ak47", "lightsaber"]
			inv.call("set_loadout", gun_ids, "pistol")

	_setup_tutorial_ui()
	_start_stage(Stage.MOVEMENT)

	# Listen for events
	EventBus.action_approved.connect(_on_action_approved)
	EventBus.enemy_defeated.connect(_on_enemy_defeated_tutorial)
	# Listen for hack usage to finish tutorial
	EventBus.action_exploited.connect(_on_hack_used)

func get_stage_number() -> int:
	return 5 # Unlock all hacks for trial

func _setup_tutorial_ui() -> void:
	_tutorial_canvas = CanvasLayer.new()
	_tutorial_canvas.layer = 100 # High layer
	add_child(_tutorial_canvas)

	# Main instruction label (legacy, kept invisible but used for state)
	_instr_label = Label.new()
	_instr_label.visible = false
	_tutorial_canvas.add_child(_instr_label)

	# Background dim for the bottom area
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top = -180
	bg.color = Color(0, 0, 0, 0.5)
	_tutorial_canvas.add_child(bg)

	# Morpheus UI Container - Anchored to Bottom Right
	var morpheus_container := HBoxContainer.new()
	morpheus_container.name = "MorpheusContainer"
	morpheus_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	morpheus_container.offset_left = -800
	morpheus_container.offset_top = -170
	morpheus_container.offset_right = -20
	morpheus_container.offset_bottom = -20
	morpheus_container.alignment = BoxContainer.ALIGNMENT_END
	_tutorial_canvas.add_child(morpheus_container)

	# Portrait
	var morpheus_texrect := TextureRect.new()
	morpheus_texrect.name = "MorpheusSprite"
	var morpheus_tex := load("res://assets/addmorpheus.png")
	if morpheus_tex:
		morpheus_texrect.texture = morpheus_tex
	morpheus_texrect.custom_minimum_size = Vector2(140, 140)
	morpheus_texrect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	morpheus_texrect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	morpheus_container.add_child(morpheus_texrect)

	# Text Box with Enhanced Style
	var morpheus_box := PanelContainer.new()
	morpheus_box.name = "MorpheusTextBox"
	morpheus_box.custom_minimum_size = Vector2(600, 140)
	
	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0, 0.05, 0.02, 0.85)
	box_style.border_width_left = 4
	box_style.border_color = Color(0.1, 1.0, 0.4, 0.8)
	box_style.set_corner_radius_all(4)
	morpheus_box.add_theme_stylebox_override("panel", box_style)
	morpheus_container.add_child(morpheus_box)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	morpheus_box.add_child(margin)

	var morpheus_label := RichTextLabel.new()
	morpheus_label.name = "MorpheusLabel"
	morpheus_label.bbcode_enabled = true
	morpheus_label.add_theme_font_override("normal_font", preload("res://Minecraft.ttf"))
	morpheus_label.add_theme_font_size_override("normal_font_size", 24)
	morpheus_label.add_theme_color_override("default_color", Color(0.2, 1.0, 0.5))
	morpheus_label.text = ""
	margin.add_child(morpheus_label)

	var esc_hint = Label.new()
	esc_hint.text = "[ESC] TO EXIT"
	esc_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	esc_hint.offset_left = -150
	esc_hint.offset_top = 20
	esc_hint.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	esc_hint.add_theme_font_size_override("font_size", 14)
	esc_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_tutorial_canvas.add_child(esc_hint)

func _set_instruction(text: String) -> void:
	_instr_label.text = text
	var label = _tutorial_canvas.find_child("MorpheusLabel", true, false)
	if label:
		label.clear()
		label.append_text(text)

func _start_stage(stage: Stage) -> void:
	_current_stage = stage
	_clear_stage_nodes()

	match stage:
		Stage.MOVEMENT:
			_set_instruction("Use WASD For movement.")
			EventBus.log("SYSTEM: Awaiting movement signature...", "info")

		Stage.BUG_COMBAT:
			_set_instruction("A Big Bug spotted, Use your mouse to aim and kill it with a mouse click.")   
			var bug = BUG_SCENE.instantiate()
			bug.position = $Player.position + Vector2(250, 0)
			bug.set("entity_id", "tutorial_bug")
			if bug.has_method("set_scale"): bug.call("set_scale", Vector2(2, 2))
			elif "scale" in bug: bug.scale = Vector2(2, 2)
			add_child(bug)
			_stage_nodes.append(bug)

		Stage.SNAKE_COMBAT:
			_set_instruction("A new enemy snake spotted. Use speed+dash to kill it.")
			var snake = SNAKE_SCENE.instantiate()
			snake.position = $Player.position + Vector2(200, 0)
			snake.set("entity_id", "tutorial_snake")
			snake.set("segment_count", 5)
			add_child(snake)
			_stage_nodes.append(snake)
			
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				var player = players[0]
				# Enable super speed automatically for this part so dash-kill works
				player.call("set_hacked_client_modes", true, false, false, false, false, false)

		Stage.HACK_MENU:
			_set_instruction("Use tabs for hack, try one of the hack and see how it is used.")
			EventBus.log("HACKING INTERFACE ONLINE", "exploit")
			# Reset hacks so they have to try one
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				players[0].call("set_hacked_client_modes", false, false, false, false, false, false)

		Stage.DONE:
			_set_instruction("CERTIFICATION COMPLETE.")
			_show_advanced_completion_ui()

func _on_hack_used(_action_info, _loophole_desc) -> void:
	if _current_stage == Stage.HACK_MENU:
		# Small delay for dramatic effect
		get_tree().create_timer(1.2).timeout.connect(func():
			if _current_stage == Stage.HACK_MENU:
				_start_stage(Stage.DONE)
		)

func _on_action_approved(action: Dictionary) -> void:
	if _current_stage == Stage.MOVEMENT and action["type"] == ActionBus.MOVE:
		# Short delay after first move
		get_tree().create_timer(1.5).timeout.connect(func():
			if _current_stage == Stage.MOVEMENT: _start_stage(Stage.BUG_COMBAT)
		)

func _on_enemy_defeated_tutorial(_id: String) -> void:
	if _current_stage == Stage.BUG_COMBAT:
		_start_stage(Stage.SNAKE_COMBAT)
	elif _current_stage == Stage.SNAKE_COMBAT:
		_start_stage(Stage.HACK_MENU)

func _show_advanced_completion_ui() -> void:
	if _completion_popup: return
	
	# Dim the rest of the screen
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	_tutorial_canvas.add_child(overlay)

	_completion_popup = PanelContainer.new()
	_completion_popup.set_anchors_preset(Control.PRESET_CENTER)
	_completion_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_completion_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_completion_popup.custom_minimum_size = Vector2(500, 300)
	_tutorial_canvas.add_child(_completion_popup)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0.1, 0.05, 0.95)
	style.border_width_all = 3
	style.border_color = Color(0.2, 1.0, 0.5)
	style.set_corner_radius_all(10)
	_completion_popup.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_all", 30)
	_completion_popup.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "TUTORIAL // COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "System initialized. Agent certified for field operations.\n\nReady to enter the Mainframe?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	desc.add_theme_font_size_override("font_size", 18)
	vbox.add_child(desc)

	var menu_btn = Button.new()
	menu_btn.text = " PROCEED TO MAIN MENU "
	menu_btn.custom_minimum_size = Vector2(250, 50)
	menu_btn.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func(): ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn"))
	vbox.add_child(menu_btn)
	
	# Simple animation
	_completion_popup.scale = Vector2(0.8, 0.8)
	_completion_popup.pivot_offset = Vector2(250, 150)
	create_tween().tween_property(_completion_popup, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	
	AudioManager.play_sfx("dragon-studio-cinematic-boom")

func _clear_stage_nodes() -> void:
	for n in _stage_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_stage_nodes.clear()
