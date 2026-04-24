## HUD.gd
## Real-time system inspector UI. Shows:
## - Active rules (live, updates on rule change)
## - Integrity bar
## - Player tags (for debugging exploits)
extends CanvasLayer

@onready var integrity_bar:    ProgressBar        = $HealthBar
@onready var integrity_label:  Label              = $Panel/VBox/IntegrityLabel
@onready var health_percentage_label: Label       = %HealthPercentageLabel
@onready var rules_container:  VBoxContainer      = $Panel/VBox/RulesScroll/RulesContainer
@onready var tags_label:       Label              = $Panel/VBox/TagsLabel
@onready var pause_btn:        Button             = $PauseBtn
@onready var hack_panel:       PanelContainer     = $HackPanel
@onready var minimap_panel:    PanelContainer     = $MinimapPanel
@onready var minimap_texture:  TextureRect        = $MinimapPanel/MinimapTexture
@onready var minimap_dot:      ColorRect          = $MinimapPanel/MinimapTexture/PlayerDot
@onready var super_speed_toggle: CheckBox         = $HackPanel/HackVBox/SuperSpeedToggle
@onready var fast_bullets_toggle: CheckBox        = $HackPanel/HackVBox/FastBulletsToggle
@onready var super_vision_toggle: CheckBox        = $HackPanel/HackVBox/SuperVisionToggle
@onready var slow_time_toggle: CheckBox           = $HackPanel/HackVBox/SlowTimeToggle
@onready var noclip_toggle: CheckBox              = $HackPanel/HackVBox/NoclipToggle
@onready var unlimited_bullets_toggle: CheckBox   = $HackPanel/HackVBox/UnlimitedBulletsToggle
@onready var hack_status:      Label              = $HackPanel/HackVBox/HackStatus
@onready var boss_bar_root:    Control            = $BossBar
@onready var boss_name_label:  Label              = $BossBar/BossName
@onready var boss_health_bar:  ProgressBar         = $BossBar/BossHealthBar
@onready var boss_health_label: Label              = $BossBar/BossHealthBar/BossHealthLabel

var _syncing_hack_ui := false
var _minimap_world_size := Vector2.ZERO
var _max_integrity := 1.0
var _boss_ref: Node2D = null
var _timed_hacks: Dictionary = {}  # hack_name -> remaining_time
var _hack_key_map := {
	"1": "super_speed",
	"2": "faster_bullets",
	"3": "super_vision",
	"4": "slow_time",
	"5": "noclip",
	"6": "unlimited_bullets"
}

const HACK_PANEL_TIME_SCALE := 0.2
const HACK_SLOW_TIME_SCALE := 0.45
const TIMED_HACK_DURATION := 10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_max_integrity = RuleManager.get_max_integrity() if RuleManager.has_method("get_max_integrity") else 1.0
	integrity_bar.max_value = _max_integrity * 100.0
	EventBus.rule_registered.connect(_on_rule_changed.bind(true))
	EventBus.rule_removed.connect(func(_id): _refresh_rules())
	EventBus.integrity_changed.connect(_on_integrity_changed)
	EventBus.entity_tag_changed.connect(_on_tag_changed)
	_style_static_labels()
	_style_pause_button()
	_style_hack_panel()
	pause_btn.pressed.connect(_on_pause_pressed)
	super_speed_toggle.toggled.connect(_on_hack_toggled)
	fast_bullets_toggle.toggled.connect(_on_hack_toggled)
	super_vision_toggle.toggled.connect(_on_hack_toggled)
	slow_time_toggle.toggled.connect(_on_hack_toggled)
	noclip_toggle.toggled.connect(_on_hack_toggled)
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.toggled.connect(_on_hack_toggled)
	_refresh_rules()
	_refresh_tags()
	_on_integrity_changed(RuleManager.get_integrity(), 0.0)
	_timed_hacks.clear()
	call_deferred("_sync_hacks_from_player")
	call_deferred("_sync_minimap")
	hack_panel.visible = true
	_apply_hack_time_scale()
	_set_hack_labels()

func _process(_delta: float) -> void:
	_sync_minimap()
	_update_minimap_player_dot()
	_update_boss_bar()
	_update_timed_hacks(_delta)
	_update_hack_display()

func _exit_tree() -> void:
	ScreenFX.clear_time_scale_override()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key_text = OS.get_keycode_string(event.keycode)
		if key_text in _hack_key_map:
			var hack_name = _hack_key_map[key_text]
			if hack_name == "unlimited_bullets":
				if unlimited_bullets_toggle != null:
					unlimited_bullets_toggle.button_pressed = not unlimited_bullets_toggle.button_pressed
			else:
				_activate_timed_hack(hack_name)
			get_tree().root.set_input_as_handled()
			return
		return
	
	if event is InputEventKey and event.is_action_pressed("inspect"):
		return
	if not hack_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos := get_viewport().get_mouse_position()
		if not hack_panel.get_global_rect().has_point(mouse_pos):
			return

func _set_hack_panel_visible(visible: bool) -> void:
	hack_panel.visible = visible

func _apply_hack_time_scale() -> void:
	if slow_time_toggle.button_pressed:
		ScreenFX.set_time_scale_override(HACK_SLOW_TIME_SCALE)
		return
	ScreenFX.clear_time_scale_override()

func _activate_timed_hack(hack_name: String) -> void:
	_timed_hacks[hack_name] = TIMED_HACK_DURATION
	
	match hack_name:
		"super_speed":
			if not super_speed_toggle.button_pressed:
				super_speed_toggle.button_pressed = true
		"faster_bullets":
			if not fast_bullets_toggle.button_pressed:
				fast_bullets_toggle.button_pressed = true
		"super_vision":
			if not super_vision_toggle.button_pressed:
				super_vision_toggle.button_pressed = true
		"slow_time":
			if not slow_time_toggle.button_pressed:
				slow_time_toggle.button_pressed = true
		"noclip":
			if not noclip_toggle.button_pressed:
				noclip_toggle.button_pressed = true

func _update_timed_hacks(delta: float) -> void:
	var hacks_to_remove = []
	
	for hack_name in _timed_hacks.keys():
		_timed_hacks[hack_name] -= delta
		if _timed_hacks[hack_name] <= 0.0:
			hacks_to_remove.append(hack_name)
	
	for hack_name in hacks_to_remove:
		_timed_hacks.erase(hack_name)
		match hack_name:
			"super_speed":
				super_speed_toggle.button_pressed = false
			"faster_bullets":
				fast_bullets_toggle.button_pressed = false
			"super_vision":
				super_vision_toggle.button_pressed = false
			"slow_time":
				slow_time_toggle.button_pressed = false
			"noclip":
				noclip_toggle.button_pressed = false
	
	_update_hack_status()
		
func _style_static_labels() -> void:
	for lbl in [$Panel/VBox/SysLabel, $Panel/VBox/IntegrityLabel,
				$Panel/VBox/TagsLabel, $Panel/VBox/HintLabel]:
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
		lbl.add_theme_color_override("outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 1)
	$Panel/VBox/SysLabel.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))

func _style_pause_button() -> void:
	var color = Color(0.15, 1.0, 0.45)
	pause_btn.add_theme_font_size_override("font_size", 14)
	pause_btn.add_theme_color_override("font_color", color)
	pause_btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.7))
	pause_btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.8, 0.3))
	pause_btn.add_theme_color_override("font_focus_color", Color(0.3, 1.0, 0.6))
	pause_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	pause_btn.add_theme_constant_override("outline_size", 1)
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
	pause_btn.add_theme_stylebox_override("normal", stylebox)
	var hover_box = stylebox.duplicate()
	hover_box.bg_color = Color(0.05, 0.15, 0.08, 0.9)
	pause_btn.add_theme_stylebox_override("hover", hover_box)
	var pressed_box = stylebox.duplicate()
	pressed_box.bg_color = Color(0.02, 0.06, 0.03, 1.0)
	pause_btn.add_theme_stylebox_override("pressed", pressed_box)

func _style_hack_panel() -> void:
	for lbl in [$HackPanel/HackVBox/HackTitle, $HackPanel/HackVBox/HackHint, hack_status]:
		lbl.add_theme_color_override("outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 1)
	$HackPanel/HackVBox/HackTitle.add_theme_font_size_override("font_size", 14)
	$HackPanel/HackVBox/HackTitle.add_theme_color_override("font_color", Color(0.15, 1.0, 0.85))
	$HackPanel/HackVBox/HackHint.add_theme_font_size_override("font_size", 10)
	$HackPanel/HackVBox/HackHint.add_theme_color_override("font_color", Color(0.55, 0.95, 0.9))
	hack_status.add_theme_font_size_override("font_size", 10)
	hack_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
	for toggle in [super_speed_toggle, fast_bullets_toggle, super_vision_toggle, slow_time_toggle, noclip_toggle, unlimited_bullets_toggle]:
		if toggle == null:
			continue
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
		toggle.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 1.0))
		toggle.focus_mode = Control.FOCUS_NONE

func _set_hack_labels() -> void:
	super_speed_toggle.text = _format_hack_label("[1] SUPER SPEED", "super_speed")
	fast_bullets_toggle.text = _format_hack_label("[2] FASTER BULLETS", "faster_bullets")
	super_vision_toggle.text = _format_hack_label("[3] SUPER VISION", "super_vision")
	slow_time_toggle.text = _format_hack_label("[4] SLOW TIME", "slow_time")
	noclip_toggle.text = _format_hack_label("[5] NOCLIP", "noclip")
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.text = _format_hack_label("[6] UNLIMITED AMMO", "unlimited_bullets")

func _sync_minimap() -> void:
	var level = get_tree().current_scene
	if level == null or not level.has_method("get_minimap_texture"):
		minimap_panel.visible = false
		return

	var tex: Texture2D = level.get_minimap_texture()
	if tex == null:
		minimap_panel.visible = false
		return

	minimap_panel.visible = true
	if minimap_texture.texture != tex:
		minimap_texture.texture = tex

	if level.has_method("get_world_size"):
		_minimap_world_size = level.get_world_size()

func _update_minimap_player_dot() -> void:
	if not minimap_panel.visible:
		return
	if _minimap_world_size.x <= 0.0 or _minimap_world_size.y <= 0.0:
		return
	var player := _get_player() as Node2D
	if player == null:
		return
	var x_ratio := clampf(player.global_position.x / _minimap_world_size.x, 0.0, 1.0)
	var y_ratio := clampf(player.global_position.y / _minimap_world_size.y, 0.0, 1.0)
	var tex_size := minimap_texture.size
	var dot_size := minimap_dot.size
	minimap_dot.position = Vector2(x_ratio * tex_size.x, y_ratio * tex_size.y) - dot_size * 0.5

func _sync_hacks_from_player() -> void:
	var player = _get_player()
	if player == null or not player.has_method("get_hacked_client_modes"):
		_update_hack_status()
		return
	var modes: Dictionary = player.get_hacked_client_modes()
	_syncing_hack_ui = true
	super_speed_toggle.button_pressed = modes.get("super_speed", false)
	fast_bullets_toggle.button_pressed = modes.get("faster_bullets", false)
	super_vision_toggle.button_pressed = modes.get("super_vision", false)
	slow_time_toggle.button_pressed = modes.get("slow_time", false)
	noclip_toggle.button_pressed = modes.get("noclip", false)
	unlimited_bullets_toggle.button_pressed = modes.get("unlimited_bullets", false)
	_syncing_hack_ui = false
	_update_hack_status()
	_apply_hack_time_scale()
	if player.has_method("set_hacked_client_modes"):
		player.set_hacked_client_modes(
			super_speed_toggle.button_pressed,
			fast_bullets_toggle.button_pressed,
			super_vision_toggle.button_pressed,
			slow_time_toggle.button_pressed,
			noclip_toggle.button_pressed,
			unlimited_bullets_toggle.button_pressed
		)

func _on_hack_toggled(enabled: bool) -> void:
	if _syncing_hack_ui:
		return
	
	if enabled:
		_start_timer_for_toggled_hack()
	
	var player = _get_player()
	if player != null and player.has_method("set_hacked_client_modes"):
		player.set_hacked_client_modes(
			super_speed_toggle.button_pressed,
			fast_bullets_toggle.button_pressed,
			super_vision_toggle.button_pressed,
			slow_time_toggle.button_pressed,
			noclip_toggle.button_pressed,
			unlimited_bullets_toggle.button_pressed
		)
	_update_hack_status()
	_apply_hack_time_scale()

func _start_timer_for_toggled_hack() -> void:
	if super_speed_toggle.button_pressed and "super_speed" not in _timed_hacks:
		_timed_hacks["super_speed"] = TIMED_HACK_DURATION
	if fast_bullets_toggle.button_pressed and "faster_bullets" not in _timed_hacks:
		_timed_hacks["faster_bullets"] = TIMED_HACK_DURATION
	if super_vision_toggle.button_pressed and "super_vision" not in _timed_hacks:
		_timed_hacks["super_vision"] = TIMED_HACK_DURATION
	if slow_time_toggle.button_pressed and "slow_time" not in _timed_hacks:
		_timed_hacks["slow_time"] = TIMED_HACK_DURATION
	if noclip_toggle.button_pressed and "noclip" not in _timed_hacks:
		_timed_hacks["noclip"] = TIMED_HACK_DURATION
	if unlimited_bullets_toggle != null and unlimited_bullets_toggle.button_pressed and "unlimited_bullets" not in _timed_hacks:
		_timed_hacks["unlimited_bullets"] = TIMED_HACK_DURATION

func _update_hack_status() -> void:
	var states: Array[String] = []
	if super_speed_toggle.button_pressed:
		states.append("SUPER SPEED")
	if fast_bullets_toggle.button_pressed:
		states.append("FASTER BULLETS")
	if super_vision_toggle.button_pressed:
		states.append("SUPER VISION")
	if slow_time_toggle.button_pressed:
		states.append("SLOW TIME")
	if noclip_toggle.button_pressed:
		states.append("NOCLIP")
	if unlimited_bullets_toggle.button_pressed:
		states.append("UNLIMITED BULLETS")
	hack_status.text = "// ACTIVE: " + (", ".join(states) if not states.is_empty() else "NONE")

func _format_hack_status(hack_label: String, hack_name: String) -> String:
	if hack_name in _timed_hacks:
		var remaining = int(ceil(_timed_hacks[hack_name]))
		return "%s [%ds]" % [hack_label, remaining]
	return hack_label

func _format_hack_label(base_label: String, hack_name: String) -> String:
	if hack_name in _timed_hacks:
		var remaining = int(ceil(_timed_hacks[hack_name]))
		return "%s [%ds]" % [base_label, remaining]
	return base_label

func _update_hack_display() -> void:
	super_speed_toggle.text = _format_hack_label("[1] SUPER SPEED", "super_speed")
	fast_bullets_toggle.text = _format_hack_label("[2] FASTER BULLETS", "faster_bullets")
	super_vision_toggle.text = _format_hack_label("[3] SUPER VISION", "super_vision")
	slow_time_toggle.text = _format_hack_label("[4] SLOW TIME", "slow_time")
	noclip_toggle.text = _format_hack_label("[5] NOCLIP", "noclip")
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.text = _format_hack_label("[6] UNLIMITED AMMO", "unlimited_bullets")

func _get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _on_pause_pressed() -> void:
	var current = get_tree().current_scene
	if current != null and current.has_method("request_pause_toggle"):
		current.request_pause_toggle()

func _on_rule_changed(_rule: Dictionary, _added: bool) -> void:
	_refresh_rules()

func bind_boss(boss: Node2D, boss_name: String = "CHATGPT") -> void:
	_boss_ref = boss
	if is_instance_valid(boss_name_label):
		boss_name_label.text = boss_name
	_update_boss_bar()

func unbind_boss() -> void:
	_boss_ref = null
	if is_instance_valid(boss_bar_root):
		boss_bar_root.visible = false

func _refresh_rules() -> void:
	for c in rules_container.get_children():
		c.queue_free()

	var header := _make_label("// ACTIVE RULES", Color(0.4, 1.0, 0.6), 12)
	rules_container.add_child(header)

	var rules = RuleManager.get_all_rules()
	if rules.is_empty():
		rules_container.add_child(_make_label("  [NONE]", Color(0.4, 0.4, 0.5), 10))
	else:
		for rule in rules:
			var col = Color(1.0, 0.4, 0.3) if rule["severity"] == "hard" else \
					  Color(1.0, 0.7, 0.1) if rule["severity"] == "soft" else Color(1.0, 0.1, 0.1)
			var txt = "  [%s] p=%d" % [rule["id"], rule["priority"]]
			rules_container.add_child(_make_label(txt, col, 10))

func _refresh_tags() -> void:
	var tags = EntityRegistry.get_tags("player")
	tags_label.text = "// TAGS: " + (", ".join(tags) if not tags.is_empty() else "none")

func _on_integrity_changed(new_val: float, _delta: float) -> void:
	if not is_instance_valid(integrity_bar):
		return
	var ratio := new_val / _max_integrity if _max_integrity > 0.0 else 0.0
	integrity_bar.value = new_val * 100.0
	var col: Color
	if ratio > 0.6:
		col = Color(0.2, 0.9, 0.4)
	elif ratio > 0.3:
		col = Color(1.0, 0.7, 0.1)
	else:
		col = Color(1.0, 0.2, 0.1)
	integrity_label.text = "SYSTEM HEALTH: %d/%d" % [int(new_val * 100.0), int(_max_integrity * 100.0)]
	integrity_label.add_theme_color_override("font_color", col)
	if is_instance_valid(health_percentage_label):
		health_percentage_label.text = "%d%%" % int(ratio * 100.0)

func _on_tag_changed(entity_id: String, _tag: String, _added: bool) -> void:
	if entity_id == "player":
		_refresh_tags()

func _make_label(text: String, color: Color, size: int = 7) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.clip_text = true
	lbl.add_theme_color_override("outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return lbl

func _update_boss_bar() -> void:
	if not is_instance_valid(_boss_ref):
		if is_instance_valid(boss_bar_root):
			boss_bar_root.visible = false
		return
	if not _boss_ref.has_method("get_health") or not _boss_ref.has_method("get_max_health"):
		if is_instance_valid(boss_bar_root):
			boss_bar_root.visible = false
		return

	var current_health: int = _boss_ref.call("get_health")
	var max_health: int = _boss_ref.call("get_max_health")
	if max_health <= 0:
		if is_instance_valid(boss_bar_root):
			boss_bar_root.visible = false
		return

	if is_instance_valid(boss_bar_root):
		boss_bar_root.visible = true
	if is_instance_valid(boss_health_bar):
		boss_health_bar.max_value = max_health
		boss_health_bar.value = current_health
	if is_instance_valid(boss_health_label):
		boss_health_label.text = "%d / %d" % [current_health, max_health]


func _apply_fonts() -> void:
	for node in get_tree().get_nodes_in_group("hud_label"):
		node.add_theme_font_size_override("font_size", 7)
		node.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
