extends CharacterBody2D

@export var move_speed := 70.0
@export var catch_distance := 14.0
@export var entity_id := "bug_01"

var _player_ref: CharacterBody2D = null
var _caught := false

func _ready() -> void:
	add_to_group("enemy")
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	EntityRegistry.register(
		entity_id,
		"bug",
		self,
		["enforcer", "watchdog", "bug", "mobile"],
		{"integrity_contribution": -0.03}
	)

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)

func _physics_process(_delta: float) -> void:
	if _caught:
		velocity = Vector2.ZERO
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player_ref == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	var to_player := _player_ref.global_position - global_position
	if to_player.length_squared() > 0.01:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if global_position.distance_to(_player_ref.global_position) <= catch_distance:
		_caught = true
		EventBus.player_caught.emit(entity_id)
