extends Area2D

@export var speed := 300.0
@export var lifetime := 1.2

var _direction := Vector2.RIGHT
var _owner_body: PhysicsBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(owner_body: PhysicsBody2D, direction: Vector2, speed_mult: float = 1.0) -> void:
	_owner_body = owner_body
	_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	speed *= maxf(speed_mult, 0.1)
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == _owner_body:
		return
	if body != null and body.is_in_group("enemy"):
		body.queue_free()
	queue_free()
