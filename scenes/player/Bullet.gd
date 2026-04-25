extends Area2D

@export var speed := 520.0
@export var lifetime := 1.2
const HEALTH_PICKUP_SCENE := preload("res://scenes/objects/HealthPickup.tscn")
const HEALTH_DROP_CHANCE_DENOM := 3
const ENEMY_HEALTH_PICKUP_HEAL_AMOUNT := 0.5
const GHOST_INTERVAL := 0.02
const GHOST_LIFETIME := 0.28

var _direction := Vector2.RIGHT
var _owner_body: PhysicsBody2D = null
var _ghost_timer := 0.0
var _is_lightsaber_bullet := false
var damage := 10

@onready var bullet_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(owner_body: PhysicsBody2D, direction: Vector2, speed_mult: float = 1.0) -> void:
	_owner_body = owner_body
	_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	speed *= maxf(speed_mult, 0.1)
	rotation = _direction.angle()

func setup_as_lightsaber(owner_body: PhysicsBody2D, direction: Vector2) -> void:
	setup(owner_body, direction, 1.2) # Faster
	_is_lightsaber_bullet = true
	if is_instance_valid(bullet_sprite):
		bullet_sprite.modulate = Color(0.2, 1.0, 0.8) # Cyan energy color
	lifetime = 0.5 # Shorter range

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_ghost_step(delta)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == null or body == _owner_body:
		return
	
	if body.is_in_group("enemy"):
		# Instant-kill for bug enemies: check entity type via EntityRegistry or group membership
		var is_bug := false
		# Try entity_id-based detection (used elsewhere)
		var entity_id = null
		if body.has_method("get"):
			entity_id = body.get("entity_id")
		if entity_id:
			var entity = EntityRegistry.get_entity(entity_id)
			is_bug = entity.get("type", "") == "bug"
		# Fallback: check 'bug' group
		if not is_bug and body.has_method("is_in_group"):
			is_bug = body.is_in_group("bug")
		if is_bug:
			# Immediate removal on hit
			body.queue_free()
			_try_spawn_health_pickup(body)
		else:
			if _is_lightsaber_bullet:
				_handle_lightsaber_hit(body)
			else:
				if body.has_method("take_damage"):
					var defeated := bool(body.call("take_damage", damage))
					if defeated:
						_try_spawn_health_pickup(body)
				else:
					body.queue_free()
					_try_spawn_health_pickup(body)
		queue_free()
	elif not body is PhysicsBody2D:
		# Static collision or wall
		queue_free()

func _handle_lightsaber_hit(enemy: Node) -> void:
	# Check if it's a snake - snakes are immune to lightsaber bullets
	var is_snake = false
	var entity_id = enemy.get("entity_id")
	if entity_id:
		var entity = EntityRegistry.get_entity(entity_id)
		is_snake = entity.get("type", "") == "snake"
	
	if not is_snake:
		# It's a bug or other non-snake enemy - health MUST go down
		if enemy.has_method("take_damage"):
			var defeated := bool(enemy.call("take_damage", damage))
			if defeated:
				_try_spawn_health_pickup(enemy)
		else:
			# Fallback: instant kill if it has no take_damage method
			enemy.queue_free()
			_try_spawn_health_pickup(enemy)

func _try_spawn_health_pickup(enemy: Node) -> void:
	if randi() % HEALTH_DROP_CHANCE_DENOM != 0:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var pickup = HEALTH_PICKUP_SCENE.instantiate()
	if pickup == null:
		return
	pickup.heal_amount = ENEMY_HEALTH_PICKUP_HEAL_AMOUNT
	scene_root.add_child(pickup)
	pickup.global_position = enemy.global_position if enemy is Node2D else global_position

func _ghost_step(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = GHOST_INTERVAL
	_spawn_ghost()

func _spawn_ghost() -> void:
	if not is_instance_valid(bullet_sprite) or bullet_sprite.texture == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = bullet_sprite.texture
	ghost.scale = bullet_sprite.scale * 1.2
	ghost.global_position = global_position
	ghost.global_rotation = rotation
	ghost.z_index = z_index - 1
	ghost.modulate = Color(0.45, 1.0, 0.65, 0.75)
	scene_root.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_LIFETIME)
	tween.tween_callback(ghost.queue_free)

func set_damage(amount: int) -> void:
	damage = amount
