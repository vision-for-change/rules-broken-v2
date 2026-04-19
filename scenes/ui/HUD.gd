## HUD.gd
## Real-time system inspector UI. Shows:
## - Active rules (live, updates on rule change)
## - System log (scrolling event feed)
## - Integrity bar
## - Player tags (for debugging exploits)
extends CanvasLayer

const MAX_LOG_LINES   = 12
const SEVERITY_COLORS = {
	"info":    Color(0.7, 0.8, 0.7),
	"warn":    Color(1.0, 0.8, 0.2),
	"error":   Color(1.0, 0.3, 0.2),
	"exploit": Color(0.2, 1.0, 0.5),
}

var _log_lines: Array[String] = []

@onready var integrity_bar:    TextureProgressBar = $Panel/VBox/IntegrityBar
@onready var integrity_label:  Label              = $Panel/VBox/IntegrityLabel
@onready var rules_container:  VBoxContainer      = $Panel/VBox/RulesScroll/RulesContainer
@onready var tags_label:       Label              = $Panel/VBox/TagsLabel
@onready var log_container:    VBoxContainer      = $LogPanel/LogScroll/LogContainer
@onready var log_panel:        Panel              = $LogPanel

func _ready() -> void:
	EventBus.rule_registered.connect(_on_rule_changed.bind(true))
	EventBus.rule_removed.connect(func(_id): _refresh_rules())
	EventBus.integrity_changed.connect(_on_integrity_changed)
	EventBus.log_event.connect(_on_log_event)
	EventBus.entity_tag_changed.connect(_on_tag_changed)
	_refresh_rules()
	_refresh_tags()
	_on_integrity_changed(1.0, 0.0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("log_toggle"):
		log_panel.visible = not log_panel.visible


	# Style static labels
	for lbl in [$Panel/VBox/SysLabel, $Panel/VBox/IntegrityLabel,
				$Panel/VBox/TagsLabel, $Panel/VBox/HintLabel]:
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.6))
	$Panel/VBox/SysLabel.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

func _on_rule_changed(_rule: Dictionary, _added: bool) -> void:
	_refresh_rules()

func _refresh_rules() -> void:
	for c in rules_container.get_children():
		c.queue_free()

	var header := _make_label("// ACTIVE RULES", Color(0.4, 1.0, 0.6), 7)
	rules_container.add_child(header)

	var rules = RuleManager.get_all_rules()
	if rules.is_empty():
		rules_container.add_child(_make_label("  [NONE]", Color(0.4, 0.4, 0.5), 6))
	else:
		for rule in rules:
			var col = Color(1.0, 0.4, 0.3) if rule["severity"] == "hard" else \
					  Color(1.0, 0.7, 0.1) if rule["severity"] == "soft" else Color(1.0, 0.1, 0.1)
			var txt = "  [%s] p=%d" % [rule["id"], rule["priority"]]
			rules_container.add_child(_make_label(txt, col, 6))

func _refresh_tags() -> void:
	var tags = EntityRegistry.get_tags("player")
	tags_label.text = "// TAGS: " + (", ".join(tags) if not tags.is_empty() else "none")

func _on_integrity_changed(new_val: float, _delta: float) -> void:
	if not is_instance_valid(integrity_bar):
		return
	integrity_bar.value = new_val * 100.0
	var col: Color
	if new_val > 0.6:
		col = Color(0.2, 0.9, 0.4)
	elif new_val > 0.3:
		col = Color(1.0, 0.7, 0.1)
	else:
		col = Color(1.0, 0.2, 0.1)
	integrity_label.text = "SYS INTEGRITY: %d%%" % int(new_val * 100.0)
	integrity_label.add_theme_color_override("font_color", col)

func _on_log_event(message: String, severity: String) -> void:
	var col = SEVERITY_COLORS.get(severity, Color(0.7, 0.8, 0.7))
	var prefix = {"info": "> ", "warn": "! ", "error": "!! ", "exploit": ">> "}.get(severity, "> ")
	_log_lines.append(prefix + message)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_rebuild_log(col)

func _rebuild_log(latest_col: Color) -> void:
	for c in log_container.get_children():
		c.queue_free()
	for i in _log_lines.size():
		var is_latest = (i == _log_lines.size() - 1)
		var col = latest_col if is_latest else Color(0.5, 0.5, 0.5)
		log_container.add_child(_make_label(_log_lines[i], col, 6))

func _on_tag_changed(entity_id: String, _tag: String, _added: bool) -> void:
	if entity_id == "player":
		_refresh_tags()

func _make_label(text: String, color: Color, size: int = 7) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.clip_text = true
	return lbl


func _apply_fonts() -> void:
	for node in get_tree().get_nodes_in_group("hud_label"):
		node.add_theme_font_size_override("font_size", 7)
		node.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
