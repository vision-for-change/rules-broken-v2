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

enum Stage { MOVEMENT, BUG_COMBAT, SNAKE_COMBAT, HACK_MENU, TERMINAL, FINAL }
var _current_stage = Stage.MOVEMENT
var _stage_nodes = []
var _tutorial_canvas: CanvasLayer
var _instr_label: Label
var _enemies_killed_in_practice := 0

func _ready() -> void:
	level_number = 0
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
	
	# Listen for events to advance tutorial
	EventBus.action_approved.connect(_on_action_approved)
	EventBus.rule_removed.connect(_on_rule_removed_tutorial)
	EventBus.enemy_defeated.connect(_on_enemy_defeated_tutorial)

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
	_instr_label.add_theme_font_size_override("font_size", 20)
	_instr_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	_instr_label.add_theme_color_override("outline_color", Color.BLACK)
	_instr_label.add_theme_constant_override("outline_size", 2)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top = -160
	bg.color = Color(0, 0, 0, 0.65)
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
			_instr_label.text = "WELCOME, AGENT.\nUSE [WASD] OR [ARROWS] TO MOVE.\nPRESS [SHIFT] TO DASH."
			EventBus.log("SYSTEM: Awaiting movement signature...", "info")
			
		Stage.BUG_COMBAT:
			_instr_label.text = "THIS IS A BUG. YOU WILL SEE THESE OFTEN.\nAIM WITH [MOUSE] AND [LEFT-CLICK] TO SHOOT.\nELIMINATE THE TARGET."
			var bug = BUG_SCENE.instantiate()
			bug.position = $Player.position + Vector2(250, 0)
			bug.set("entity_id", "tutorial_bug")
			add_child(bug)
			_stage_nodes.append(bug)
			EventBus.log("THREAT DETECTED: BUG_01", "error")

		Stage.SNAKE_COMBAT:
			_instr_label.text = "THIS IS A SNAKE. IT IS IMMUNE TO BULLETS.\nUSE FAST SPEED [SHIFT-DASH] TO MAKE IT DIE."
			var snake = SNAKE_SCENE.instantiate()
			snake.position = $Player.position + Vector2(250, 50)
			snake.set("entity_id", "tutorial_snake")
			add_child(snake)
			_stage_nodes.append(snake)
			EventBus.log("THREAT DETECTED: SNAKE_PROCESS", "error")

		Stage.HACK_MENU:
			_instr_label.text = "YOU ARE AN AGENT. YOU CAN HACK THE SYSTEM.\nPRESS [TAB] TO OPEN THE HACK MENU.\nTRY ENABLING A MODE LIKE 'NOCLIP' OR 'SUPER SPEED'."
			EventBus.log("HACKING INTERFACE AVAILABLE", "exploit")
			# Wait a bit for them to explore the menu
			get_tree().create_timer(6.0).timeout.connect(func():
				if _current_stage == Stage.HACK_MENU: _start_stage(Stage.TERMINAL)
			)

		Stage.TERMINAL:
			_instr_label.text = "THE SYSTEM HAS RULES THAT BLOCK YOU.\nAPPROACH THE BLUE TERMINAL AND PRESS [E] TO PURGE RULES.\nPRESS [1-4] TO SWITCH GUNS IF NEEDED."
			
			var sign_obj = SIGN_SCENE.instantiate()
			sign_obj.rule_id = "integrity_lockdown"
			sign_obj.display_text = "SYSTEM LOCKDOWN"
			sign_obj.position = $Player.position + Vector2(300, 0)
			add_child(sign_obj)
			_stage_nodes.append(sign_obj)
			
			var term = TERMINAL_SCENE.instantiate()
			term.terminal_id = "tutorial_term"
			term.position = $Player.position + Vector2(150, -120)
			add_child(term)
			_stage_nodes.append(term)
			
			RuleManager.register_rule(RuleDefinitions.get_rule("integrity_lockdown"))
			EventBus.log("HACKING VULNERABILITY DETECTED", "exploit")

		Stage.FINAL:
			_instr_label.text = "TUTORIAL COMPLETE.\nSYSTEM INTEGRITY IS LOW. COLLECT THE MEDKIT.\nTHEN ENTER THE EXIT PORTAL TO FINISH."
			
			var medkit = MEDKIT_SCENE.instantiate()
			medkit.position = $Player.position + Vector2(100, -50)
			add_child(medkit)
			_stage_nodes.append(medkit)
			
			var exit = EXIT_SCENE.instantiate()
			exit.position = $Player.position + Vector2(250, 0)
			add_child(exit)
			_stage_nodes.append(exit)
			
			# Force integrity low for demonstration
			RuleManager.apply_integrity_damage(5.0)

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

func _on_rule_removed_tutorial(_rule_id: String) -> void:
	if _current_stage == Stage.TERMINAL:
		_start_stage(Stage.FINAL)

func _on_level_complete() -> void:
	EventBus.log("TUTORIAL COMPLETE // AGENT CERTIFIED", "exploit")
	_instr_label.text = "CERTIFICATION COMPLETE. RETURNING TO HUB..."
	await get_tree().create_timer(2.5).timeout
	ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")

func _clear_stage_nodes() -> void:
	for n in _stage_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_stage_nodes.clear()
