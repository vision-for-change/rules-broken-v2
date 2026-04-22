## HUD.gd
## Real-time system inspector UI. Shows:
## - Active rules (live, updates on rule change)
## - Integrity bar
## - Player tags (for debugging exploits)
extends CanvasLayer

@onready var integrity_bar:    ProgressBar        = $HealthBar
@onready var integrity_label:  Label              = $Panel/VBox/IntegrityLabel
@onready var rules_container:  VBoxContainer      = $Panel/VBox/RulesScroll/RulesContainer
@onready var tags_label:       Label              = $Panel/VBox/TagsLabel
@onready var pause_btn:        Button             = $PauseBtn
@onready var hack_panel:       PanelContainer     = $HackPanel
@onready var minimap_panel:    PanelContainer     = $MinimapPanel
@onready var minimap_texture:  TextureRect        = $MinimapPanel/MinimapTexture
@onready var minimap_dot:      ColorRect          = $MinimapPanel/MinimapTexture/PlayerDot
@onready var super_speed_toggle: CheckBox         = $HackPanel/HackVBox/SuperSpeedToggle
@onready var invincible_toggle: CheckBox          = $HackPanel/HackVBox/InvincibleToggle
@onready var fast_bullets_toggle: CheckBox        = $HackPanel/HackVBox/FastBulletsToggle
@onready var ultimate_bullets_toggle: CheckBox    = $HackPanel/HackVBox/UltimateBulletsToggle
@onready var super_vision_toggle: CheckBox        = $HackPanel/HackVBox/SuperVisionToggle
@onready var hack_status:      Label              = $HackPanel/HackVBox/HackStatus

var _syncing_hack_ui := false
var _minimap_world_size := Vector2.ZERO
var _max_integrity := 1.0

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
	invincible_toggle.toggled.connect(_on_hack_toggled)
	fast_bullets_toggle.toggled.connect(_on_hack_toggled)
	ultimate_bullets_toggle.toggled.connect(_on_hack_toggled)
	super_vision_toggle.toggled.connect(_on_hack_toggled)
	_refresh_rules()
	_refresh_tags()
	_on_integrity_changed(RuleManager.get_integrity(), 0.0)
	call_deferred("_sync_hacks_from_player")
	call_deferred("_sync_minimap")

func _process(_delta: float) -> void:
	_sync_minimap()
	_update_minimap_player_dot()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.is_action_pressed("inspect"):
		hack_panel.visible = not hack_panel.visible
		
func _style_static_labels() -> void:
	for lbl in [$Panel/VBox/SysLabel, $Panel/VBox/IntegrityLabel,
				$Panel/VBox/TagsLabel, $Panel/VBox/HintLabel]:
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
		lbl.add_theme_color_override("outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 1)
	$Panel/VBox/SysLabel.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))

func _style_pause_button() -> void:
	pause_btn.add_theme_font_size_override("font_size", 14)
	pause_btn.add_theme_color_override("font_color", Color(0.15, 1.0, 0.45))
	pause_btn.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.6))
	pause_btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.9, 0.35))
	pause_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	pause_btn.add_theme_constant_override("outline_size", 1)

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
	for toggle in [super_speed_toggle, invincible_toggle, fast_bullets_toggle, ultimate_bullets_toggle, super_vision_toggle]:
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
		toggle.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 1.0))

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
	invincible_toggle.button_pressed = modes.get("invincible", false)
	fast_bullets_toggle.button_pressed = modes.get("faster_bullets", false)
	ultimate_bullets_toggle.button_pressed = modes.get("ultimate_bullets", false)
	super_vision_toggle.button_pressed = modes.get("super_vision", false)
	_syncing_hack_ui = false
	_update_hack_status()

func _on_hack_toggled(_enabled: bool) -> void:
	if _syncing_hack_ui:
		return
	var player = _get_player()
	if player != null and player.has_method("set_hacked_client_modes"):
		player.set_hacked_client_modes(
			super_speed_toggle.button_pressed,
			invincible_toggle.button_pressed,
			fast_bullets_toggle.button_pressed,
			ultimate_bullets_toggle.button_pressed,
			super_vision_toggle.button_pressed
		)
	_update_hack_status()

func _update_hack_status() -> void:
	var states: Array[String] = []
	if super_speed_toggle.button_pressed:
		states.append("SUPER SPEED")
	if invincible_toggle.button_pressed:
		states.append("INVINCIBLE")
	if fast_bullets_toggle.button_pressed:
		states.append("FASTER BULLETS")
	if ultimate_bullets_toggle.button_pressed:
		states.append("ULTIMATE BULLETS")
	if super_vision_toggle.button_pressed:
		states.append("SUPER VISION")
	hack_status.text = "// ACTIVE: " + (", ".join(states) if not states.is_empty() else "NONE")

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


func _apply_fonts() -> void:
	for node in get_tree().get_nodes_in_group("hud_label"):
		node.add_theme_font_size_override("font_size", 7)
		node.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
