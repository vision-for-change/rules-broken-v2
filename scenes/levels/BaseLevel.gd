## BaseLevel.gd
## Manages level lifecycle: loads rule set, connects events, handles transitions.
## Each level script extends this and declares its own rules/entities.
extends Node2D

## Override in subclasses to define which rules start active
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
	EventBus.log("// SECTOR %d INITIALISED //" % level_number, "info")
	EventBus.log("Active rules: %d" % initial_rules.size(), "info")

func _show_title() -> void:
	title_label.text = level_title_text
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	title_label.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(title_label, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.8)
	t.tween_property(title_label, "modulate:a", 0.0, 0.4)

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
	_set_non_player_pause_override(false)
	var next = "res://scenes/levels/Level%d.tscn" % (level_number + 1)
	if ResourceLoader.exists(next):
		get_tree().change_scene_to_file(next)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/WinScreen.tscn")

func _on_player_caught(_catcher_id: String) -> void:
	# Player.gd handles its own caught animation + scene change
	pass

func _on_integrity_changed(new_val: float, _delta: float) -> void:
	if new_val <= 0.0:
		EventBus.log("!! SYSTEM FAILURE — shutting down !!", "error")
		get_tree().quit()
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
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if _paused and event.is_action_pressed("pause_main_menu"):
		get_tree().paused = false
		_paused = false
		_set_player_pause_override(false)
		_set_non_player_pause_override(false)
		if is_instance_valid(_pause_layer):
			_pause_layer.visible = false
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

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
