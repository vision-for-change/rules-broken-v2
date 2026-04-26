extends CharacterBody2D

@export var move_speed := 80.0
@export var entity_id := "worm_01"
@export var max_health := 1
@export var shoot_range := 250.0
@export var shoot_cooldown := 1.5

const LASER_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")
const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.2)
const SHARD_COUNT := 8
const SHATTER_DURATION := 0.22

var _player_ref: CharacterBody2D = null
var _defeated := false
var _health := 0
var _contact_area: Area2D = null
var _shoot_cd := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemy")
	_health = maxi(1, max_health)
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	_setup_contact_area()
	
	EntityRegistry.register(
		entity_id,
		"worm",
		self,
		["worm", "mobile"],
		{"integrity_contribution": -0.02}
	)

func _setup_contact_area() -> void:
	_contact_area = Area2D.new()
	_contact_area.body_entered.connect(_on_contact_body_entered)
	add_child(_contact_area)
	
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	_contact_area.add_child(collision_shape)
	
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = 1

func _on_contact_body_entered(body: Node2D) -> void:
	if _defeated:
		return
	
	if body.is_in_group("player") and body.has_method("take_damage"):
		var is_dashing = body.is_dashing() if body.has_method("is_dashing") else false
		var modes = body.get_hacked_client_modes() if body.has_method("get_hacked_client_modes") else {}
		var has_super_speed = modes.get("super_speed", false)
		
		# Don't damage if player is dashing with super speed (they should be killing us)
		if is_dashing and has_super_speed:
			return
			
		# Deal reduced damage on contact
		body.take_damage(5)
		if RuleManager.has_method("apply_integrity_damage"):
			RuleManager.apply_integrity_damage(0.2)
			
		# Flash particles at the contact point for visual feedback
		ScreenFX.spawn_hit_flash(global_position, Color(1.0, 0.6, 0.2, 1.0), 16.0, 0.14)
		shatter()

func take_damage(amount: int) -> bool:
	if _defeated:
		return false
	
	# Worm is weak to bullets
	if amount > 0:
		shatter()
		return true
	
	return false

func check_dash_collision(player_node: Node) -> bool:
	if _defeated or player_node == null:
		return false
	
	if not player_node.has_method("is_dashing") or not player_node.has_method("get_hacked_client_modes"):
		return false
	
	var is_dashing = player_node.is_dashing()
	var modes = player_node.get_hacked_client_modes()
	var has_super_speed = modes.get("super_speed", false)
	
	if is_dashing and has_super_speed:
		_health = 0
		ScreenFX.slow_motion_pulse(0.2, 1.0)
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
		
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	var distance_to_player := global_position.distance_to(_player_ref.global_position)
	if distance_to_player <= shoot_range and _shoot_cd <= 0.0:
		_fire_laser()

func _fire_laser() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var laser := LASER_SCENE.instantiate()
	if laser == null:
		return
	
	var to_player = (_player_ref.global_position - global_position).normalized()
	scene_root.add_child(laser)
	laser.global_position = global_position + to_player * 15.0
	if laser.has_method("setup"):
		laser.setup(self, to_player)
	
	# Set damage to 5 for worm bullets
	laser.set("_player_damage", 5)
	
	_shoot_cd = shoot_cooldown

func shatter() -> void:
	if _defeated: return
	_defeated = true
	EventBus.enemy_defeated.emit(entity_id)
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
