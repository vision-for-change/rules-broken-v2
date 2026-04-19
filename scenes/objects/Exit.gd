## Exit.gd
## Level exit. Uses ActionBus to validate ACCESS action.
## Can be locked by rules — player must bypass or remove blocking rules.
extends Area2D

@export var exit_id      := "exit_01"
@export var locked_by    := ""   # rule_id that locks this exit
@export var requires_tag := ""   # player tag required to pass

@onready var body_rect: ColorRect = $BodyRect
@onready var label: Label         = $Label

var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visual()
	EventBus.rule_removed.connect(_on_rule_removed)
	EventBus.entity_tag_changed.connect(_on_tag_changed)

func _update_visual() -> void:
	var is_locked = (locked_by != "" and RuleManager.is_rule_active(locked_by)) or (requires_tag != "" and not EntityRegistry.has_tag("player", requires_tag))
	if is_locked:
		body_rect.color = Color(0.6, 0.1, 0.1)
		label.text = "EXIT\nLOCKED"
	else:
		body_rect.color = Color(0.1, 0.9, 0.4)
		label.text = "EXIT"

func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"): return

	# Tag check
	if requires_tag != "" and not EntityRegistry.has_tag("player", requires_tag):
		EventBus.log("EXIT DENIED: requires tag [%s]" % requires_tag, "warn")
		AudioManager.play_sfx("denied")
		ScreenFX.flash_screen(Color(1, 0.2, 0.1, 0.3), 0.2)
		return

	var result = ActionBus.submit(ActionBus.ACCESS,
		EntityRegistry.get_tags("player"),
		{"actor_id": "player", "target_id": exit_id,
		 "context_locked_by": locked_by}
	)

	if result["allowed"] or result["loophole"] != "":
		_triggered = true
		EventBus.level_complete.emit()
		AudioManager.play_sfx("level_complete")
		ScreenFX.flash_screen(Color(0.1, 1.0, 0.4, 0.45), 0.6)
	else:
		EventBus.log("EXIT BLOCKED: %s" % result["reason"], "warn")
		AudioManager.play_sfx("denied")
		ScreenFX.flash_screen(Color(1, 0.2, 0.1, 0.3), 0.2)

func _on_rule_removed(rule_id: String) -> void:
	if rule_id == locked_by:
		_update_visual()

func _on_tag_changed(entity_id: String, _tag: String, _added: bool) -> void:
	if entity_id == "player":
		_update_visual()
