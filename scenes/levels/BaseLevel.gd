## BaseLevel.gd
## Manages level lifecycle: loads rule set, connects events, handles transitions.
## Each level script extends this and declares its own rules/entities.
extends Node2D

@export var initial_rules: Array[String] = []
@export var level_number: int = 1
@export var level_title_text: String = "SECTOR 01"

@onready var hud: CanvasLayer = $HUD
@onready var title_label: Label = $TitleLabel

var _complete := false
var _paused := false
var _pause_layer: CanvasLayer
var _pause_label: Label
var _forced_modes: Dictionary = {}
const TRANSITION_IN_TIME := 0.35
const TRANSITION_OUT_TIME := 0.45

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Allow GUI input so Tab and Esc work, we will handle button focus separately
	get_viewport().gui_disable_input = false
	RuleManager.clear_rules()
	EntityRegistry.clear_all()

	for rule_id in initial_rules:
		var rule = RuleDefinitions.get_rule(rule_id)
		if not rule.is_empty():
			RuleManager.register_rule(rule)

	EventBus.level_complete.connect(_on_level_complete, CONNECT_ONE_SHOT)
	EventBus.player_caught.connect(_on_player_caught, CONNECT_ONE_SHOT)
	EventBus.integrity_changed.connect(_on_integrity_changed)
	_setup_pause_overlay()

	_show_title()
	_play_enter_transition()
	_trigger_player_spawn_animation()
	EventBus.log("// SECTOR %d INITIALISED //" % level_number, "info")
	EventBus.log("Active rules: %d" % initial_rules.size(), "info")

func _show_title() -> void:
	# Create a large centered banner
	var banner = CanvasLayer.new()
	banner.layer = 100
	add_child(banner)
	
	var label = Label.new()
	label.text = level_title_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	label.add_theme_color_override("outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	banner.add_child(label)
	
	label.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.0)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(func():
		# Move label to persistent top center display
		banner.remove_child(label)
		add_child(label)
		label.layout_mode = 1
		label.anchor_left = 0.5
		label.anchor_top = 0.0
		label.anchor_right = 0.5
		label.anchor_bottom = 0.0
		label.offset_left = -200.0
		label.offset_top = 12.0
		label.offset_right = 200.0
		label.offset_bottom = 40.0
		label.add_theme_font_size_override("font_size", 20)
		label.modulate.a = 1.0
		banner.queue_free()
	)
	
	# Also update the small top-left/top-center label if it exists
	if is_instance_valid(title_label):
		title_label.text = level_title_text
		title_label.modulate.a = 0.0 # Keep it hidden or secondary

func _trigger_player_spawn_animation() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	if player.has_method("play_spawn_animation"):
		player.play_spawn_animation()

func _on_level_complete() -> void:
	if _complete:
		return
	_complete = true
	AudioManager.play_sfx("level_complete")
	ScreenFX.flash_screen(Color(0.1, 1.0, 0.4, 0.5), 0.5)
	EventBus.log("// SECTOR %d CLEARED //" % level_number, "exploit")
	await get_tree().create_timer(1.1).timeout
	await _play_exit_transition()
	get_tree().paused = false
	_set_player_pause_override(false)
	_set_enemy_pause_override(false)
	_set_non_player_pause_override(false)
	var next = "res://scenes/levels/Level%d.tscn" % (level_number + 1)
	if ResourceLoader.exists(next):
		ScreenFX.transition_to_scene(next)
	else:
		ScreenFX.transition_to_scene("res://scenes/ui/WinScreen.tscn")

func _on_player_caught(_catcher_id: String) -> void:
	pass

func _on_integrity_changed(new_val: float, _delta: float) -> void:
	if new_val <= 0.0:
		EventBus.log("!! SYSTEM FAILURE — PLAYER CAUGHT !!", "error")
		return
	var max_integrity := RuleManager.get_max_integrity() if RuleManager.has_method("get_max_integrity") else 1.0
	var lockdown_threshold := max_integrity * 0.15
	if new_val <= lockdown_threshold and not RuleManager.is_rule_active("integrity_lockdown"):
		var rule = RuleDefinitions.get_rule("integrity_lockdown")
		if not rule.is_empty():
			RuleManager.register_rule(rule)
			EventBus.log("!! INTEGRITY LOCKDOWN TRIGGERED !!", "error")
			ScreenFX.screen_shake(8.0, 0.4)
			AudioManager.play_sfx("lockdown")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if _paused and event.is_action_pressed("pause_main_menu"):
		_toggle_pause()
		ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")

func _setup_pause_overlay() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 300
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(dim)

	_pause_label = Label.new()
	_pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_label.text = "PAUSED\n[ESC] RESUME\n[M] MAIN MENU"
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	_pause_label.add_theme_font_size_override("font_size", 18)
	_pause_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	_pause_label.add_theme_color_override("outline_color", Color.BLACK)
	_pause_label.add_theme_constant_override("outline_size", 2)
	_pause_layer.add_child(_pause_label)

	_pause_layer.visible = false

func _toggle_pause() -> void:
	if _complete:
		return
	_paused = not _paused
	get_tree().paused = _paused
	_set_player_pause_override(_paused)
	_set_enemy_pause_override(_paused)
	_set_non_player_pause_override(_paused)
	if is_instance_valid(_pause_layer):
		_pause_layer.visible = _paused

func request_pause_toggle() -> void:
	_toggle_pause()

func _set_player_pause_override(paused_state: bool) -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node:
			p.process_mode = Node.PROCESS_MODE_PAUSABLE if paused_state else Node.PROCESS_MODE_INHERIT

func _set_enemy_pause_override(paused_state: bool) -> void:
	for group_name in ["enemy", "enemy_projectile"]:
		var enemies = get_tree().get_nodes_in_group(group_name)
		for enemy in enemies:
			if enemy is Node:
				enemy.process_mode = Node.PROCESS_MODE_PAUSABLE if paused_state else Node.PROCESS_MODE_INHERIT

func _set_non_player_pause_override(paused_state: bool) -> void:
	var always_nodes: Array = [
		EventBus, RuleManager, ActionBus, EntityRegistry,
		AudioManager, ScreenFX, InputSetup, RuleDefinitions
	]
	if paused_state:
		_forced_modes.clear()
		for n in always_nodes:
			if n is Node and is_instance_valid(n):
				_forced_modes[n] = n.process_mode
				n.process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		for n in _forced_modes.keys():
			if n is Node and is_instance_valid(n):
				n.process_mode = _forced_modes[n]
		_forced_modes.clear()

func _play_enter_transition() -> void:
	var overlay = _create_transition_overlay()
	overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	var t = create_tween()
	t.tween_property(overlay, "color:a", 0.0, TRANSITION_IN_TIME)
	t.tween_callback(func(): overlay.get_parent().queue_free())

func _play_exit_transition() -> void:
	var overlay = _create_transition_overlay()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	var t = create_tween()
	t.tween_property(overlay, "color:a", 1.0, TRANSITION_OUT_TIME)
	await t.finished

func _create_transition_overlay() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	return overlay
