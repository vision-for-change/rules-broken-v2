extends CharacterBody2D

@export var move_speed := 80.0
@export var entity_id := "worm_01"
@export var max_health := 1

const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.2)
const SHARD_COUNT := 8
const SHATTER_DURATION := 0.22

var _player_ref: CharacterBody2D = null
var _defeated := false
var _health := 0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemy")
	_health = maxi(1, max_health)
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	EntityRegistry.register(
		entity_id,
		"worm",
		self,
		["worm", "mobile"],
		{"integrity_contribution": -0.02}
	)

func take_damage(amount: int) -> bool:
	if _defeated:
		return false
	
	var player = get_tree().get_first_node_in_group("player")
	
	if amount >= 9999:
		if player != null and player.has_method("get_hacked_client_modes") and player.has_method("is_dashing"):
			var modes = player.get_hacked_client_modes()
			var is_dashing = player.is_dashing()
			if modes.get("super_speed", false) and is_dashing:
				_health = 0
				shatter()
				return true
		return false
	
	return false

func check_dash_collision(player_node: Node) -> bool:
	print("DEBUG: Worm check_dash_collision called")
	if _defeated or player_node == null:
		print("DEBUG: Worm defeated or player null")
		return false
	
	if not player_node.has_method("is_dashing") or not player_node.has_method("get_hacked_client_modes"):
		print("DEBUG: Player missing methods")
		return false
	
	var is_dashing = player_node.is_dashing()
	var modes = player_node.get_hacked_client_modes()
	var has_super_speed = modes.get("super_speed", false)
	
	print("DEBUG: is_dashing=%s, has_super_speed=%s" % [is_dashing, has_super_speed])
	
	if is_dashing and has_super_speed:
		print("DEBUG: Worm shattering!")
		_health = 0
		shatter()
		return true
	
	return false

func _physics_process(delta: float) -> void:
	if _defeated: return
	
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		return

	var to_player = (_player_ref.global_position - global_position).normalized()
	velocity = to_player * move_speed
	move_and_slide()
	
	if velocity.length() > 0:
		rotation = lerp_angle(rotation, velocity.angle(), 10.0 * delta)

func shatter() -> void:
	if _defeated: return
	_defeated = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
	AudioManager.play_sfx("freesound_community-glass-shatter")
	_spawn_shards()
	visible = false
	await get_tree().create_timer(SHATTER_DURATION).timeout
	queue_free()

func _spawn_shards() -> void:
	if is_instance_valid(sprite):
		_spawn_shards_from_sprite(sprite)

func _spawn_shards_from_sprite(source_sprite: Sprite2D) -> void:
	if not is_instance_valid(source_sprite) or source_sprite.texture == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	for i in SHARD_COUNT:
		var shard := Sprite2D.new()
		shard.texture = source_sprite.texture
		shard.global_position = source_sprite.global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		shard.global_rotation = randf_range(0.0, TAU)
		shard.scale = source_sprite.global_scale * randf_range(0.35, 0.65)
		shard.z_index = source_sprite.z_index + 1
		scene_root.add_child(shard)

		var drift := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(20.0, 60.0)
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", shard.global_position + drift, SHATTER_DURATION)
		tween.parallel().tween_property(shard, "global_rotation", shard.global_rotation + randf_range(-3.0, 3.0), SHATTER_DURATION)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, SHATTER_DURATION)
		tween.tween_callback(shard.queue_free)

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)
