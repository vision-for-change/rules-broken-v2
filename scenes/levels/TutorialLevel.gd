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
	# Backup: Listen for hack usage to finish tutorial
	EventBus.action_exploited.connect(_on_hack_used_signal)

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


	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)

	var esc_hint = Label.new()
	esc_hint.text = "[ESC] TO EXIT"
	esc_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	esc_hint.offset_left = -150
	esc_hint.offset_top = 20
	esc_hint.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	esc_hint.add_theme_font_size_override("font_size", 14)
	esc_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_tutorial_canvas.add_child(esc_hint)


func _start_stage(stage: Stage) -> void:
	_current_stage = stage

	match stage:
		Stage.MOVEMENT:
			$CanvasLayer/Label.visible = true

		Stage.BUG_COMBAT:
			$CanvasLayer/Label2.visible = true
			$CanvasLayer/Label.visible = false
			var bug = BUG_SCENE.instantiate()
			bug.set("entity_id", "tutorial_bug")
			bug.position = $Player.position + Vector2(250, 0)
			add_child(bug)
			_stage_nodes.append(bug)

		Stage.SNAKE_COMBAT:
			$CanvasLayer/Label2.visible = false
			$CanvasLayer/Label3.visible = true
			var snake = SNAKE_SCENE.instantiate()
			snake.position = $Player.position + Vector2(200, 0)
			snake.set("entity_id", "tutorial_snake")
			snake.set("segment_count", 5)
			add_child(snake)
			_stage_nodes.append(snake)
			
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				var player = players[0]
				player.call("set_hacked_client_modes", false, false, false, false, false, false)

		Stage.HACK_MENU:
			$CanvasLayer/Label3.visible = false
			$CanvasLayer/Label4.visible = true
			EventBus.log("HACKING INTERFACE ONLINE", "exploit")
			# Reset hacks so they have to try one
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				players[0].call("set_hacked_client_modes", false, false, false, false, false, false)
			# Start robust polling
			_check_for_hack_activation()

		Stage.DONE:
			$CanvasLayer/Label4.visible = false
			$CanvasLayer/Label5.visible = true
			Music.tutorialFinished = true
			_show_advanced_completion_ui()

func _check_for_hack_activation() -> void:
	if _current_stage != Stage.HACK_MENU:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var modes = player.call("get_hacked_client_modes")
		var any_active = false
		for m in modes.values():
			if m == true:
				any_active = true
				break
		
		if any_active:
			_complete_hack_stage()
			return
			
	# Keep checking every 0.3s
	get_tree().create_timer(0.3).timeout.connect(_check_for_hack_activation)

func _on_hack_used_signal(_info, _desc) -> void:
	if _current_stage == Stage.HACK_MENU:
		_complete_hack_stage()

func _complete_hack_stage() -> void:
	if _current_stage != Stage.HACK_MENU: return
	
	# Mark as done so we don't trigger twice
	_current_stage = Stage.DONE
	EventBus.log("TUTORIAL: Hack trial successful!", "exploit")
	
	# Small delay for dramatic effect
	get_tree().create_timer(1.0).timeout.connect(func():
		_start_stage(Stage.DONE)
	)

func _on_action_approved(action: Dictionary) -> void:
	if _current_stage == Stage.MOVEMENT and action["type"] == ActionBus.MOVE:
		# Short delay after first move
		get_tree().create_timer(1.0).timeout.connect(func():
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
	# FIX: set_border_width_all instead of property border_width_all
	style.set_border_width_all(3)
	style.border_color = Color(0.2, 1.0, 0.5)
	style.set_corner_radius_all(10)
	_completion_popup.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
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
	desc.text = "You are the one. Ready to hack the Matrix?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	desc.add_theme_font_size_override("font_size", 18)
	vbox.add_child(desc)

	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(250, 50)
	menu_btn.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func(): ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn"))
	vbox.add_child(menu_btn)
	
	# Simple animation
	_completion_popup.scale = Vector2(0.8, 0.8)
	_completion_popup.pivot_offset = Vector2(250, 150)
	create_tween().tween_property(_completion_popup, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	
func _clear_stage_nodes() -> void:
	for n in _stage_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_stage_nodes.clear()
