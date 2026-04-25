extends CharacterBody2D

signal shield_disabled(duration: float)
signal shield_restored
signal defeated

@export var move_speed := 280.0 # Significantly faster following
@export var duplication_rate := 4.0 
@export var fire_rate := 0.8
@export var max_health := 450
@export var vulnerable_duration := 7.0

const PROJECTILE_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")

var _player_ref: Node2D = null
var _fire_timer := 0.0
var _dup_timer := 0.0
var _pattern_angle := 0.0
var _is_clone := false
var _health := 0
var _shielded := true
var _vulnerable_timer := 0.0
var _defeated := false

@onready var sprite := $Sprite2D
@onready var ui := $UI
@onready var pressure_bar := $UI/PressureBar
@onready var status_label: Label = $UI/Label

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	_health = maxi(1, max_health)
	
	# Small like player
	scale = Vector2.ONE * 0.8
	
	if _is_clone:
		ui.hide()
		_shielded = false
	else:
		pressure_bar.max_value = 25
		_update_status_visuals()

func _physics_process(delta: float) -> void:
	if _defeated:
		velocity = Vector2.ZERO
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		return

	if not _is_clone and not _shielded:
		_vulnerable_timer = maxf(0.0, _vulnerable_timer - delta)
		if _vulnerable_timer <= 0.0:
			restore_shield()

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

func disable_shield(duration: float = vulnerable_duration) -> void:
	if _is_clone or _defeated:
		return
	_shielded = false
	_vulnerable_timer = maxf(0.1, duration)
	_update_status_visuals()
	shield_disabled.emit(_vulnerable_timer)

func restore_shield() -> void:
	if _is_clone or _defeated:
		return
	if _shielded:
		return
	_shielded = true
	_vulnerable_timer = 0.0
	_update_status_visuals()
	shield_restored.emit()

func take_damage(amount: int) -> bool:
	if _is_clone:
		queue_free()
		return true
	if _defeated:
		return false
	if _shielded:
		_flash_blocked_hit()
		return false
	_health = maxi(0, _health - maxi(1, amount))
	var tween := create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if _health > 0:
		return false
	_defeat()
	return true

func get_health() -> int:
	if _is_clone:
		return 0
	return _health

func get_max_health() -> int:
	if _is_clone:
		return 0
	return max_health

func is_shielded() -> bool:
	return _shielded

func _flash_blocked_hit() -> void:
	var tween := create_tween()
	sprite.modulate = Color(0.3, 1.0, 1.4)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func _update_status_visuals() -> void:
	if not is_instance_valid(status_label) or not is_instance_valid(pressure_bar):
		return
	if _shielded:
		status_label.text = "ROGUE AI // SHIELD ACTIVE"
		pressure_bar.modulate = Color(0.3, 0.9, 1.0, 1.0)
		sprite.modulate = Color(0.75, 0.95, 1.2, 1.0)
	else:
		status_label.text = "ROGUE AI // VULNERABLE"
		pressure_bar.modulate = Color(1.0, 0.4, 0.35, 1.0)
		sprite.modulate = Color(1.25, 0.8, 0.8, 1.0)

func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	velocity = Vector2.ZERO
	for clone in get_tree().get_nodes_in_group("boss_clone"):
		if is_instance_valid(clone):
			clone.queue_free()
	defeated.emit()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
