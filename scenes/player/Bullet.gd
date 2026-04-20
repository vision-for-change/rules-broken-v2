extends Area2D

@export var speed := 520.0
@export var lifetime := 1.2
const HEALTH_PICKUP_SCENE := preload("res://scenes/objects/HealthPickup.tscn")
const HEALTH_DROP_CHANCE_DENOM := 3
const GHOST_INTERVAL := 0.02
const GHOST_LIFETIME := 0.28

var _direction := Vector2.RIGHT
var _owner_body: PhysicsBody2D = null
var _ghost_timer := 0.0

@onready var bullet_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(owner_body: PhysicsBody2D, direction: Vector2, speed_mult: float = 1.0) -> void:
	_owner_body = owner_body
	_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	speed *= maxf(speed_mult, 0.1)
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_ghost_step(delta)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == _owner_body:
		return
	if body != null and body.is_in_group("enemy"):
		_try_spawn_health_pickup(body)
		body.queue_free()
	queue_free()

func _try_spawn_health_pickup(enemy: Node) -> void:
	if randi() % HEALTH_DROP_CHANCE_DENOM != 0:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var pickup = HEALTH_PICKUP_SCENE.instantiate()
	if pickup == null:
		return
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
