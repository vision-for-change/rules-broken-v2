extends CharacterBody2D

signal shield_disabled(duration: float)
signal shield_restored
signal defeated

@export var move_speed := 215.0
@export var duplication_rate := 6.0
@export var fire_rate := 1.05
@export var max_health := 420
@export var vulnerable_duration := 8.5

const PROJECTILE_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")
const MAX_CLONES := 5
const SIGNAL_LOST_COLOR := Color(1.0, 0.92, 0.35, 1.0)
const VULNERABLE_COLOR := Color(1.25, 0.8, 0.8, 1.0)
const SHIELDED_COLOR := Color(0.75, 0.95, 1.2, 1.0)

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
	
	scale = Vector2.ONE * (0.62 if not _is_clone else 0.5)
	
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

	var player_hidden := _player_has_invisibility_hack()
	if player_hidden:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 3.0)
		move_and_slide()
		sprite.rotation = lerp_angle(sprite.rotation, sprite.rotation + 0.25, 2.0 * delta)
		if not _is_clone:
			ui.global_position = global_position
			if is_instance_valid(status_label):
				status_label.text = "ROGUE AI // SIGNAL LOST"
				status_label.add_theme_color_override("font_color", SIGNAL_LOST_COLOR)
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
		if _dup_timer >= duplication_rate and clones.size() < MAX_CLONES:
			_dup_timer = 0.0
			_duplicate_self()

	# Move towards player
	var offset := _player_ref.global_position - global_position
	var distance := offset.length()
	var dir_to_player := offset.normalized() if distance > 0.001 else Vector2.ZERO
	if not _is_clone and distance < 96.0:
		dir_to_player = -dir_to_player
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
	var num_bullets := 3 if _is_clone else 6
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
		status_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
		sprite.modulate = SHIELDED_COLOR
	else:
		status_label.text = "ROGUE AI // VULNERABLE"
		pressure_bar.modulate = Color(1.0, 0.4, 0.35, 1.0)
		status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.66, 1.0))
		sprite.modulate = VULNERABLE_COLOR

func _player_has_invisibility_hack() -> bool:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return false
	if not _player_ref.has_method("get_hacked_client_modes"):
		return false
	var modes: Dictionary = _player_ref.get_hacked_client_modes()
	return bool(modes.get("invisible", false))

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
