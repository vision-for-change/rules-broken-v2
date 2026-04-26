## HUD.gd
## Real-time system inspector UI. Shows:
## - Active rules (live, updates on rule change)
## - Integrity bar
## - Player tags (for debugging exploits)
extends CanvasLayer

const MINECRAFT_FONT := preload("res://Minecraft.ttf")

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
var _active_hacks_queue: Array[String] = []  # Tracks order of active hacks (max 2)
var _enemies_defeated := 0
var _total_enemies := 0
var _enemy_counter_label: Label = null
var _boss_loadout_root: PanelContainer = null
var _boss_loadout_slots: Array = []
var _is_boss_encounter := false
var _telephone_alert_played := false
var _hack_key_map := {
	"1": "super_speed",
	"2": "faster_bullets",
	"3": "super_vision",
	"4": "unlimited_bullets",
	"5": "slow_time"
}
var _hack_unlock_by_stage := {
	"super_speed": 1,
	"faster_bullets": 2,
	"super_vision": 3,
	"unlimited_bullets": 5,
	"slow_time": 4
}

const HACK_PANEL_TIME_SCALE := 0.2
const HACK_SLOW_TIME_SCALE := 0.45
const TIMED_HACK_DURATION := 10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_max_integrity = RuleManager.get_max_integrity() if RuleManager.has_method("get_max_integrity") else 1.0
	integrity_bar.max_value = 100.0
	EventBus.rule_registered.connect(_on_rule_changed.bind(true))
	EventBus.rule_removed.connect(func(_id): _refresh_rules())
	EventBus.integrity_changed.connect(_on_integrity_changed)
	EventBus.entity_tag_changed.connect(_on_tag_changed)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	_style_static_labels()
	_style_pause_button()
	_ensure_special_hud_controls()
	_style_hack_panel()
	pause_btn.pressed.connect(_on_pause_pressed)
	super_speed_toggle.toggled.connect(func(enabled): _on_hack_toggled("super_speed", enabled))
	fast_bullets_toggle.toggled.connect(func(enabled): _on_hack_toggled("faster_bullets", enabled))
	super_vision_toggle.toggled.connect(func(enabled): _on_hack_toggled("super_vision", enabled))
	slow_time_toggle.toggled.connect(func(enabled): _on_hack_toggled("slow_time", enabled))
	noclip_toggle.toggled.connect(func(enabled): _on_hack_toggled("noclip", enabled))
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.toggled.connect(func(enabled): _on_hack_toggled("unlimited_bullets", enabled))
	_refresh_rules()
	_refresh_tags()
	_on_integrity_changed(RuleManager.get_integrity(), 0.0)
	call_deferred("_sync_hacks_from_player")
	call_deferred("_sync_minimap")
	call_deferred("_count_and_create_enemy_counter")
	hack_panel.visible = true
	_refresh_hack_availability()
	_apply_hack_time_scale()
	_set_hack_labels()

func _process(_delta: float) -> void:
	_sync_minimap()
	_update_minimap_player_dot()
	_update_boss_bar()
	_refresh_hack_availability()
	_update_boss_loadout_bar()
	_update_hack_display()

func _exit_tree() -> void:
	ScreenFX.clear_time_scale_override()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key_text = OS.get_keycode_string(event.keycode)
		if key_text in _hack_key_map:
			var hack_name = _hack_key_map[key_text]
			if not _is_hack_unlocked(hack_name):
				return
			_toggle_hack_by_name(hack_name)
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

func _ensure_special_hud_controls() -> void:
	# REORDER: Put Level 4 hacks at the bottom
	if has_node("HackPanel/HackVBox"):
		var vbox = $HackPanel/HackVBox
		# Higher level hacks first, Level 4 at the very bottom
		# Actually, let's just move Level 4 ones to the end of the VBox
		vbox.move_child(slow_time_toggle, vbox.get_child_count() - 1)
		if is_instance_valid(hack_status):
			vbox.move_child(hack_status, vbox.get_child_count() - 1)

	if _boss_loadout_root != null:
		return
	_boss_loadout_root = PanelContainer.new()
	_boss_loadout_root.visible = false
	_boss_loadout_root.anchor_left = 0.5
	_boss_loadout_root.anchor_top = 1.0
	_boss_loadout_root.anchor_right = 0.5
	_boss_loadout_root.anchor_bottom = 1.0
	_boss_loadout_root.offset_left = -236.0
	_boss_loadout_root.offset_top = -124.0
	_boss_loadout_root.offset_right = 236.0
	_boss_loadout_root.offset_bottom = -48.0
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = Color(0.03, 0.08, 0.09, 0.8)
	root_style.border_color = Color(0.25, 0.8, 0.95, 0.8)
	root_style.border_width_left = 2
	root_style.border_width_right = 2
	root_style.border_width_top = 2
	root_style.border_width_bottom = 2
	root_style.set_corner_radius_all(8)
	_boss_loadout_root.add_theme_stylebox_override("panel", root_style)
	add_child(_boss_loadout_root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_boss_loadout_root.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(hbox)

	for i in range(4):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(106, 58)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.06, 0.11, 0.13, 0.95)
		slot_style.border_color = Color(0.15, 0.36, 0.45, 1.0)
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", slot_style)
		hbox.add_child(slot)

		var slot_margin := MarginContainer.new()
		slot_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_margin.add_theme_constant_override("margin_left", 6)
		slot_margin.add_theme_constant_override("margin_top", 5)
		slot_margin.add_theme_constant_override("margin_right", 6)
		slot_margin.add_theme_constant_override("margin_bottom", 5)
		slot.add_child(slot_margin)

		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)
		slot_margin.add_child(slot_vbox)

		var key_label := Label.new()
		key_label.text = "[%d]" % (i + 1)
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", Color(0.58, 0.96, 1.0))
		slot_vbox.add_child(key_label)

		var name_label := Label.new()
		name_label.text = "---"
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.96, 0.98))
		slot_vbox.add_child(name_label)

		var ammo_label := Label.new()
		ammo_label.text = "INF"
		ammo_label.add_theme_font_size_override("font_size", 10)
		ammo_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.78))
		slot_vbox.add_child(ammo_label)

		_boss_loadout_slots.append({
			"panel": slot,
			"name": name_label,
			"ammo": ammo_label
		})

func _get_current_stage() -> int:
	var level = get_tree().current_scene
	if level != null and level.has_method("get_stage_number"):
		return int(level.call("get_stage_number"))
	if level != null and level.get("level_number") != null:
		return int(level.get("level_number"))
	return 1

func _is_hack_unlocked(hack_name: String) -> bool:
	if hack_name == "noclip":
		return false
	var required_stage = _hack_unlock_by_stage.get(hack_name, 99)
	return _get_current_stage() >= required_stage

func _refresh_hack_availability() -> void:
	var unlock_labels := {
		"super_speed": "LV1",
		"faster_bullets": "LV2",
		"super_vision": "LV3",
		"slow_time": "LV4",
		"noclip": "LOCKED",
		"unlimited_bullets": "LV5"
	}
	var toggle_map := {
		"super_speed": super_speed_toggle,
		"faster_bullets": fast_bullets_toggle,
		"super_vision": super_vision_toggle,
		"slow_time": slow_time_toggle,
		"noclip": noclip_toggle,
		"unlimited_bullets": unlimited_bullets_toggle
	}
	for hack_name in toggle_map.keys():
		var toggle: CheckBox = toggle_map[hack_name]
		if toggle == null:
			continue
		var unlocked := _is_hack_unlocked(hack_name)
		toggle.visible = unlocked
		toggle.disabled = not unlocked
		if not unlocked and toggle.button_pressed:
			_syncing_hack_ui = true
			toggle.button_pressed = false
			_syncing_hack_ui = false
		var base_text := _format_hack_label(toggle.text, hack_name)
		if unlocked:
			toggle.text = base_text
		else:
			toggle.text = "%s [%s]" % [base_text, str(unlock_labels.get(hack_name, "LOCKED"))]
	_apply_allowed_hacks_to_player()

func _apply_allowed_hacks_to_player() -> void:
	var player = _get_player()
	if player == null or not player.has_method("set_hacked_client_modes"):
		return
	player.set_hacked_client_modes(
		super_speed_toggle.button_pressed and _is_hack_unlocked("super_speed"),
		fast_bullets_toggle.button_pressed and _is_hack_unlocked("faster_bullets"),
		super_vision_toggle.button_pressed and _is_hack_unlocked("super_vision"),
		slow_time_toggle.button_pressed and _is_hack_unlocked("slow_time"),
		false,
		unlimited_bullets_toggle.button_pressed and _is_hack_unlocked("unlimited_bullets")
	)

func _apply_hack_time_scale() -> void:
	if slow_time_toggle.button_pressed:
		ScreenFX.set_time_scale_override(HACK_SLOW_TIME_SCALE)
		return
	ScreenFX.clear_time_scale_override()

func _update_timed_hacks(delta: float) -> void:
	pass
		
func _style_static_labels() -> void:
	for lbl in [$Panel/VBox/SysLabel, $Panel/VBox/IntegrityLabel,
				$Panel/VBox/TagsLabel, $Panel/VBox/HintLabel]:
		lbl.add_theme_font_override("font", MINECRAFT_FONT)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
		lbl.add_theme_color_override("outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 1)
	$Panel/VBox/SysLabel.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))

func _style_pause_button() -> void:
	var color = Color(0.15, 1.0, 0.45)
	pause_btn.add_theme_font_override("font", MINECRAFT_FONT)
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
		lbl.add_theme_font_override("font", MINECRAFT_FONT)
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
		toggle.add_theme_font_override("font", MINECRAFT_FONT)
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
		toggle.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 1.0))
		toggle.focus_mode = Control.FOCUS_NONE

func _set_hack_labels() -> void:
	super_speed_toggle.text = "[1] SUPER SPEED"
	fast_bullets_toggle.text = "[2] FASTER BULLETS"
	super_vision_toggle.text = "[3] SUPER VISION"
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.text = "[4] UNLIMITED AMMO"
	slow_time_toggle.text = "[5] SLOW TIME"
	noclip_toggle.text = "[X] NOCLIP"

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
	super_speed_toggle.button_pressed = modes.get("super_speed", false) and _is_hack_unlocked("super_speed")
	fast_bullets_toggle.button_pressed = modes.get("faster_bullets", false) and _is_hack_unlocked("faster_bullets")
	super_vision_toggle.button_pressed = modes.get("super_vision", false) and _is_hack_unlocked("super_vision")
	slow_time_toggle.button_pressed = modes.get("slow_time", false) and _is_hack_unlocked("slow_time")
	noclip_toggle.button_pressed = false
	unlimited_bullets_toggle.button_pressed = modes.get("unlimited_bullets", false) and _is_hack_unlocked("unlimited_bullets")
	_syncing_hack_ui = false
	_refresh_hack_availability()
	_update_hack_status()
	_apply_hack_time_scale()
	_apply_allowed_hacks_to_player()

func _on_hack_toggled(hack_name: String, enabled: bool) -> void:
	if _syncing_hack_ui:
		return
	if enabled and not _is_hack_unlocked(hack_name):
		_disable_hack(hack_name)
		return
	
	if enabled:
		# Add to queue
		if hack_name not in _active_hacks_queue:
			_active_hacks_queue.append(hack_name)
		
		# If we now have more than 2 hacks, disable the oldest one
		if _active_hacks_queue.size() > 2:
			var oldest = _active_hacks_queue.pop_front()
			_disable_hack(oldest)
	else:
		# Remove from queue
		if hack_name in _active_hacks_queue:
			_active_hacks_queue.erase(hack_name)
	
	_apply_allowed_hacks_to_player()
	_update_hack_status()
	_apply_hack_time_scale()

func _disable_hack(hack_name: String) -> void:
	_syncing_hack_ui = true
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
		"unlimited_bullets":
			if unlimited_bullets_toggle != null:
				unlimited_bullets_toggle.button_pressed = false
	_syncing_hack_ui = false

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
	hack_status.text = "// LV%d HACKS: " % _get_current_stage() + (", ".join(states) if not states.is_empty() else "NONE")

func _format_hack_status(hack_label: String, hack_name: String) -> String:
	return hack_label

func _format_hack_label(base_label: String, hack_name: String) -> String:
	var base_map := {
		"super_speed": "[1] SUPER SPEED",
		"faster_bullets": "[2] FASTER BULLETS",
		"super_vision": "[3] SUPER VISION",
		"slow_time": "[5] SLOW TIME",
		"noclip": "[X] NOCLIP",
		"unlimited_bullets": "[4] UNLIMITED AMMO"
	}
	return str(base_map.get(hack_name, base_label))

func _update_hack_display() -> void:
	super_speed_toggle.text = "[1] SUPER SPEED"
	fast_bullets_toggle.text = "[2] FASTER BULLETS"
	super_vision_toggle.text = "[3] SUPER VISION"
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.text = "[4] UNLIMITED AMMO"
	slow_time_toggle.text = "[5] SLOW TIME"
	noclip_toggle.text = "[X] NOCLIP"

func _toggle_hack_by_name(hack_name: String) -> void:
	var toggle = _get_toggle_for_hack(hack_name)
	if toggle != null:
		toggle.button_pressed = not toggle.button_pressed

func _get_toggle_for_hack(hack_name: String) -> BaseButton:
	match hack_name:
		"super_speed":
			return super_speed_toggle
		"faster_bullets":
			return fast_bullets_toggle
		"super_vision":
			return super_vision_toggle
		"slow_time":
			return slow_time_toggle
		"noclip":
			return noclip_toggle
		"unlimited_bullets":
			return unlimited_bullets_toggle
	return null

func set_boss_encounter_mode(active: bool) -> void:
	_is_boss_encounter = active
	if _boss_loadout_root != null:
		_boss_loadout_root.visible = active and not _is_boss_encounter # Forces false if boss encounter

func _update_boss_loadout_bar() -> void:
	if _boss_loadout_root == null:
		return
	# NO HOTBAR: Always keep hidden during boss encounter
	var should_show := false 
	_boss_loadout_root.visible = should_show
	if not should_show:
		return
	var player = _get_player()
	if player == null or not player.has_node("Inventory"):
		return
	var inventory = player.get_node("Inventory")
	if inventory == null:
		return
	var slots: Array = inventory.get("slots")
	var current_slot: int = int(inventory.get("current_slot"))
	for i in range(_boss_loadout_slots.size()):
		var slot_ui: Dictionary = _boss_loadout_slots[i]
		var panel: PanelContainer = slot_ui["panel"]
		var name_label: Label = slot_ui["name"]
		var ammo_label: Label = slot_ui["ammo"]
		if i < slots.size():
			var gun: Dictionary = slots[i]
			name_label.text = str(gun.get("display_name", "---")).to_upper()
			var max_ammo := int(gun.get("max_ammo", 0))
			ammo_label.text = "INF" if max_ammo == 0 or unlimited_bullets_toggle.button_pressed else "%d" % int(gun.get("ammo", max_ammo))
			panel.self_modulate = Color(1, 1, 1, 1) if i == current_slot else Color(0.72, 0.82, 0.86, 0.88)
		else:
			name_label.text = "---"
			ammo_label.text = ""
			panel.self_modulate = Color(0.45, 0.45, 0.45, 0.6)

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
	integrity_bar.value = ratio * 100.0
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

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	if not is_instance_valid(integrity_bar):
		return
	var health_ratio := float(current_health) / float(max_health) if max_health > 0 else 0.0
	integrity_bar.value = health_ratio * 100.0
	var col: Color
	if health_ratio > 0.6:
		col = Color(0.2, 0.9, 0.4)
	elif health_ratio > 0.3:
		col = Color(1.0, 0.7, 0.1)
	else:
		col = Color(1.0, 0.2, 0.1)
	integrity_label.text = "SYSTEM HEALTH: %d/%d" % [current_health, max_health]
	integrity_label.add_theme_color_override("font_color", col)
	if is_instance_valid(health_percentage_label):
		health_percentage_label.text = "%d%%" % int(health_ratio * 100.0)

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
	var level = get_tree().current_scene
	if level != null and level.has_method("get_boss_objective_status") and _enemy_counter_label != null:
		var boss_status: Dictionary = level.call("get_boss_objective_status")
		if bool(boss_status.get("shielded", false)):
			_enemy_counter_label.text = "OVERRIDE KEYS: %d / %d" % [int(boss_status.get("remaining", 0)), int(boss_status.get("total", 0))]
			_enemy_counter_label.add_theme_color_override("font_color", Color(0.85, 1.0, 1.0))
		else:
			_enemy_counter_label.text = "SHIELD DOWN // FIRE NOW"
			_enemy_counter_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.65))


func _apply_fonts() -> void:
	for node in get_tree().get_nodes_in_group("hud_label"):
		node.add_theme_font_size_override("font_size", 7)
		node.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))

func _count_total_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	_total_enemies = enemies.size()
	# Wait a frame if count is still 0 and try again
	if _total_enemies == 0:
		await get_tree().process_frame
		enemies = get_tree().get_nodes_in_group("enemy")
		_total_enemies = enemies.size()

func _count_and_create_enemy_counter() -> void:
	_telephone_alert_played = false
	await _count_total_enemies()
	_create_enemy_counter_label()

func _create_enemy_counter_label() -> void:
	var status := _get_enemy_kill_status()
	_enemy_counter_label = Label.new()
	_enemy_counter_label.text = "TARGETS: 0/%d" % int(status.get("required", 0))
	_enemy_counter_label.add_theme_font_size_override("font_size", 18)
	_enemy_counter_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
	_enemy_counter_label.add_theme_color_override("outline_color", Color.BLACK)
	_enemy_counter_label.add_theme_constant_override("outline_size", 2)
	_enemy_counter_label.position = Vector2(12, 12)
	_enemy_counter_label.z_index = 100
	add_child(_enemy_counter_label)

func _on_enemy_defeated(_enemy_id: String) -> void:
	_enemies_defeated += 1
	_update_enemy_counter_display()
	# If we've met the target and haven't yet notified, play the phone ring
	var status := _get_enemy_kill_status()
	var current_scene = get_tree().current_scene
	var is_tutorial = current_scene != null and current_scene.name == "tutorial"
	# Only play the telephone ring in normal levels (skip tutorial)
	if bool(status.get("met", false)) and not _telephone_alert_played and not is_tutorial:
		_telephone_alert_played = true
		AudioManager.play_sfx("TelephoneRinging")

func _update_enemy_counter_display() -> void:
	if _enemy_counter_label != null:
		var level = get_tree().current_scene
		if level != null and level.has_method("get_boss_objective_status"):
			var boss_status: Dictionary = level.call("get_boss_objective_status")
			if bool(boss_status.get("shielded", false)):
				_enemy_counter_label.add_theme_color_override("font_color", Color(0.85, 1.0, 1.0))
				_enemy_counter_label.text = "OVERRIDE KEYS: %d / %d" % [int(boss_status.get("remaining", 0)), int(boss_status.get("total", 0))]
			else:
				_enemy_counter_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.65))
				_enemy_counter_label.text = "SHIELD DOWN // FIRE NOW"
			return
		var status := _get_enemy_kill_status()
		var requirement_met = bool(status.get("met", false))
		var required = int(status.get("required", 0))
		var color = Color(0.2, 1.0, 0.45) if requirement_met else Color(0.8, 1.0, 0.9)
		_enemy_counter_label.add_theme_color_override("font_color", color)
		_enemy_counter_label.text = "TARGETS: %d/%d" % [_enemies_defeated, required]

func _get_enemy_kill_status() -> Dictionary:
	var required := 0
	if _total_enemies > 0:
		required = ceili(_total_enemies / 2.0)
	else:
		var level = get_tree().current_scene
		if level != null and level.has_method("get_enemy_kill_requirement"):
			required = int(level.call("get_enemy_kill_requirement"))
	var requirement_met = required <= 0 or _enemies_defeated >= required
	var remaining = maxi(0, required - _enemies_defeated)
	return {
		"met": requirement_met,
		"defeated": _enemies_defeated,
		"total": _total_enemies,
		"required": required,
		"remaining": remaining
	}

func set_boss_mode_defaults() -> void:
	_syncing_hack_ui = true
	if unlimited_bullets_toggle != null:
		unlimited_bullets_toggle.button_pressed = true
	_syncing_hack_ui = false
	_apply_allowed_hacks_to_player()
	_update_hack_status()
