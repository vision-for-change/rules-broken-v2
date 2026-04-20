extends CharacterBody2D

@export var friction := 900.0
@export var push_multiplier := 0.9

func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

func receive_push(direction: Vector2, move_speed: float) -> void:
	if direction.length_squared() == 0.0:
		return
	velocity = direction.normalized() * move_speed * push_multiplier
