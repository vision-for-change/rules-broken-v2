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
var _dash_cooldown := 0.0
var _dash_timer := 0.0
var _dash_dir := Vector2.ZERO
var _attack_phase := 0

@onready var sprite := $Sprite2D
@onready var ui := $UI
@onready var pressure_bar := $UI/PressureBar
@onready var status_label: Label = $UI/Label

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	
	# FORCE COLLISION LAYER TO 2 (Same as Bugs/Snakes)
	# This ensures player bullets (mask 3) will hit the boss
	collision_layer = 2
	collision_mask = 3
	
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	
	# Scaling based on level (accessing static var from Level2)
	var floor_idx = 5
	var level_script = load("res://scenes/levels/Level2.gd")
	if level_script:
		floor_idx = level_script._floor_index
	
	var tier_mult := float(floor_idx) / 5.0
	max_health = int(420.0 * (1.0 + (tier_mult - 1.0) * 0.8))
	move_speed = 215.0 * (1.0 + (tier_mult - 1.0) * 0.15)
	
	_health = max_health
	
	scale = Vector2.ONE * (0.62 if not _is_clone else 0.5)

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

	# Movement logic
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * (move_speed * 4.0)
		_spawn_dash_ghost()
	else:
		var offset := _player_ref.global_position - global_position
		var distance := offset.length()
		var dir_to_player := offset.normalized() if distance > 0.001 else Vector2.ZERO
		
		# Boss tries to keep some distance but occasionally dashes in
		var target_speed = move_speed
		if not _is_clone:
			if distance < 120.0:
				dir_to_player = -dir_to_player
			elif distance > 300.0:
				target_speed *= 1.5
				
			if _dash_cooldown <= 0.0 and distance > 200.0 and _shielded:
				_start_dash(offset.normalized())
				
		velocity = dir_to_player * target_speed

	move_and_slide()

	# Rotation
	var aim_dir = (_player_ref.global_position - global_position).normalized()
	sprite.rotation = lerp_angle(sprite.rotation, aim_dir.angle(), 10.0 * delta)
	
	if not _is_clone:
		ui.global_position = global_position

	# Fire patterns
	_fire_timer += delta
	if _fire_timer >= fire_rate:
		_fire_timer = 0.0
		_execute_attack_pattern()

func _start_dash(dir: Vector2) -> void:
	_dash_dir = dir
	_dash_timer = 0.25
	_dash_cooldown = randf_range(3.0, 5.0)
	AudioManager.play_sfx("dragon-studio-simple-whoosh")

func _spawn_dash_ghost() -> void:
	var ghost = sprite.duplicate()
	get_parent().add_child(ghost)
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.modulate = Color(0.2, 0.8, 1.0, 0.4)
	var t = create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.3)
	t.tween_callback(ghost.queue_free)

func _execute_attack_pattern() -> void:
	if _is_clone:
		_fire_radial_pattern(3)
		return
		
	_attack_phase = (_attack_phase + 1) % 3
	match _attack_phase:
		0: _fire_radial_pattern(8)
		1: _fire_burst_pattern()
		2: _fire_spiral_pattern()

func _fire_radial_pattern(count: int) -> void:
	_pattern_angle += 0.4
	for i in range(count):
		var angle := _pattern_angle + (i * TAU / count)
		var dir := Vector2.RIGHT.rotated(angle)
		_spawn_projectile(dir)

func _fire_burst_pattern() -> void:
	var to_player = (_player_ref.global_position - global_position).normalized()
	for i in range(3):
		var dir = to_player.rotated(randf_range(-0.2, 0.2))
		_spawn_projectile(dir)
		await get_tree().create_timer(0.1).timeout

func _fire_spiral_pattern() -> void:
	for i in range(12):
		var angle = (float(i) / 12.0) * TAU * 2.0
		var dir = Vector2.RIGHT.rotated(angle)
		_spawn_projectile(dir)
		await get_tree().create_timer(0.05).timeout

func _duplicate_self() -> void:
	var clone_scene = load("res://scenes/enemy/RogueAI.tscn")
	if clone_scene == null: return
	var clone = clone_scene.instantiate()
	clone._is_clone = true
	clone.add_to_group("boss_clone")
	clone._player_ref = _player_ref
	get_parent().add_child(clone)
	clone.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	
	# Visual effect for duplication
	var t = create_tween()
	clone.modulate.a = 0
	t.tween_property(clone, "modulate:a", 1.0, 0.5)

func _spawn_projectile(dir: Vector2) -> void:
	if not is_instance_valid(get_tree().current_scene): return
	var laser := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(laser)
	laser.global_position = global_position + dir * 25.0
	if laser.has_method("setup"):
		laser.setup(self, dir)

func disable_shield(duration: float = vulnerable_duration) -> void:
	if _is_clone or _defeated:
		return
	_shielded = false
	_vulnerable_timer = maxf(0.1, duration)
	_update_status_visuals()
	shield_disabled.emit(_vulnerable_timer)
	# Slow motion pulse when shield drops
	ScreenFX.slow_motion_pulse(0.3, 1.5)

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
		_health = 0
		_defeat()
		return true
	if _defeated:
		return false
	if _shielded:
		_flash_blocked_hit()
		return false
	
	# Set damage to exactly 15 per hit as requested
	var damage_to_deal = 15
	_health = maxi(0, _health - damage_to_deal)
	
	# Hit effect
	var tween := create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", VULNERABLE_COLOR, 0.1)
	
	if _health > 0:
		return false
	_defeat()
	return true

func get_health() -> int:
	return _health

func get_max_health() -> int:
	return max_health

func is_shielded() -> bool:
	return _shielded

func _flash_blocked_hit() -> void:
	var tween := create_tween()
	sprite.modulate = Color(0.3, 1.0, 1.4)
	tween.tween_property(sprite, "modulate", SHIELDED_COLOR, 0.12)

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
	set_physics_process(false)
	
	if not _is_clone:
		for clone in get_tree().get_nodes_in_group("boss_clone"):
			if is_instance_valid(clone):
				clone.queue_free()
		defeated.emit()
		AudioManager.play_sfx("freesound_community-glass-shatter")
		ScreenFX.slow_motion_pulse(0.1, 2.0)
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
