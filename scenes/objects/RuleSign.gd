## RuleSign.gd
## Represents a posted rule. Destroying it removes the rule from RuleManager.
## Signs can also GRANT new rules (permission escalation exploit).
extends StaticBody2D

@export var rule_id         := "no_running"
@export var display_text    := "NO RUNNING"
@export var sign_color      := Color(0.85, 0.15, 0.15)
@export var grants_rule_id  := ""  # if set, destroying this ADDS a new rule (inversion exploit)

var entity_id := ""
var is_broken := false

@onready var sign_rect: ColorRect  = $SignRect
@onready var label: Label          = $Label
@onready var particles: CPUParticles2D = $Particles
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	entity_id = "sign_" + rule_id
	label.text = display_text
	sign_rect.color = sign_color

	EntityRegistry.register(entity_id, "sign", self,
		["sign", "interactable", "rule_source"],
		{"rule_id": rule_id, "grants": grants_rule_id}
	)

func on_player_interact(action_result: Dictionary) -> void:
	if is_broken: return
	_break(action_result)

func get_interact_hint() -> String:
	return "REMOVE: %s" % display_text

func _break(action_result: Dictionary) -> void:
	is_broken = true

	RuleManager.remove_rule(rule_id)
	EventBus.log("SIGN DESTROYED: rule [%s] removed" % rule_id, "warn")

	# Inversion exploit: removing this sign ADDS a conflicting rule
	if grants_rule_id != "":
		var granted = RuleDefinitions.get_rule(grants_rule_id)
		if not granted.is_empty():
			RuleManager.register_rule(granted)
			EventBus.log("RULE INVERSION: [%s] now active" % grants_rule_id, "exploit")

	ScreenFX.glitch_flash(0.25)
	ScreenFX.screen_shake(5.0, 0.2)
	AudioManager.play_sfx("sign_break")

	collision_layer = 0
	collision_mask  = 0
	EntityRegistry.unregister(entity_id)

	particles.emitting = true
	var t = create_tween()
	t.tween_property(sign_rect, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): visible = false)
