extends Area2D

@export var heal_amount := 3.0
@export var lifetime := 8.0

var _consumed := false
var _bob_time := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _start_bobbing() -> void:
	_bob_time = 0.0

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	
	_bob_time += delta
	var bob_offset = sin(_bob_time * PI / 0.8) * 3.0
	global_position.y += bob_offset - (sin((_bob_time - delta) * PI / 0.8) * 3.0 if _bob_time > delta else 0.0)

func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if body == null or not body.is_in_group("player"):
		return
	# Don't heal if player is already dead
	if body.get("is_alive") == false:
		return
	_consumed = true
	RuleManager.apply_integrity_heal(heal_amount)
	
	# Heal the player as well
	if body.has_method("heal"):
		body.call("heal", int(heal_amount * 30))
	
	EventBus.log("HEALTH POWER-UP +%d" % int(heal_amount * 100.0), "info")
	ScreenFX.flash_screen(Color(0.2, 1.0, 0.3, 0.2), 0.12)
	queue_free()
