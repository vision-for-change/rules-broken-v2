extends Area2D

@export var heal_amount := 3.0
@export var lifetime := 8.0

var _consumed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

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
