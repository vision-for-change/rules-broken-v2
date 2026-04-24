extends CharacterBody2D

@export var move_speed := 280.0 # Significantly faster following
@export var duplication_rate := 4.0 
@export var fire_rate := 0.8

const PROJECTILE_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")

var _player_ref: Node2D = null
var _fire_timer := 0.0
var _dup_timer := 0.0
var _pattern_angle := 0.0
var _is_clone := false

@onready var sprite := $Sprite2D
@onready var ui := $UI
@onready var pressure_bar := $UI/PressureBar

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	# Small like player
	scale = Vector2.ONE * 0.8
	
	if _is_clone:
		ui.hide() 
	else:
		pressure_bar.max_value = 25 

func _physics_process(delta: float) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	# Handle duplication (only for the master AI)
	if not _is_clone:
		_dup_timer += delta
		var clones = get_tree().get_nodes_in_group("boss_clone")
		pressure_bar.value = clones.size()
		if _dup_timer >= duplication_rate:
			_dup_timer = 0.0
			_duplicate_self()

	# Move towards player
	var dir_to_player := (_player_ref.global_position - global_position).normalized()
	velocity = dir_to_player * move_speed
	move_and_slide()

	# Rotate to face the player instead of just spinning
	var target_angle = dir_to_player.angle()
	sprite.rotation = lerp_angle(sprite.rotation, target_angle, 4.0 * delta)
	
	if not _is_clone:
		ui.global_position = global_position

	# Fire patterns
	_fire_timer += delta
	if _fire_timer >= fire_rate:
		_fire_timer = 0.0
		_fire_radial_pattern()

func _duplicate_self() -> void:
	var clone = load("res://scenes/enemy/RogueAI.tscn").instantiate()
	clone._is_clone = true
	clone.add_to_group("boss_clone")
	# Ensure clone gets a reference to player immediately
	clone._player_ref = _player_ref
	get_parent().add_child(clone)
	clone.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func _fire_radial_pattern() -> void:
	var num_bullets := 4 if _is_clone else 8
	_pattern_angle += 0.3
	for i in range(num_bullets):
		var angle := _pattern_angle + (i * TAU / num_bullets)
		var dir := Vector2.RIGHT.rotated(angle)
		_spawn_projectile(dir)

func _spawn_projectile(dir: Vector2) -> void:
	var laser := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(laser)
	laser.global_position = global_position + dir * 20.0
	if laser.has_method("setup"):
		laser.setup(self, dir)

func take_damage(_amount: int) -> bool:
	# Rogue AI is immortal
	var tween := create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	return false
