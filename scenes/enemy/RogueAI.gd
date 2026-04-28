extends CharacterBody2D

signal shield_disabled(duration: float)
signal shield_restored
signal defeated

@export var move_speed := 50.0
@export var duplication_rate := 4.0
@export var fire_rate := 0.9
@export var max_health := 420
@export var vulnerable_duration := 8.5

const PROJECTILE_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")
const MAX_CLONES := 5
const SIGNAL_LOST_COLOR := Color(1.0, 0.92, 0.35, 1.0)
const VULNERABLE_COLOR := Color(1.25, 0.8, 0.8, 1.0)
const SHIELDED_COLOR := Color(0.75, 0.95, 1.2, 1.0)
const DEATH_SHAKE_INTENSITY := 20.0
const DEATH_SHAKE_DURATION := 0.45
const DEATH_DIGIT_COUNT := 260
const DEATH_EXPLOSION_COUNT := 120
const DEATH_DIGIT_EFFECT_TIME := 1.8
const SHATTER_ROWS := 6
const SHATTER_COLS := 6
const SHATTER_DURATION := 2.2
const SHATTER_FORCE := 260.0

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
var _combat_active := true

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
	if _is_clone:
		max_health = int(75.0 * tier_mult)
	else:
		max_health = int(1500.0 * tier_mult)
	move_speed = 50.0
	
	_health = max_health
	
	scale = Vector2.ONE * (0.62 if not _is_clone else 0.5)

func _physics_process(delta: float) -> void:
	if _defeated:
		velocity = Vector2.ZERO
		return
	if not _combat_active:
		velocity = Vector2.ZERO
		if not _is_clone:
			ui.global_position = global_position
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
				target_speed *= 1
				
			if _dash_cooldown <= 0.0 and distance > 200.0 and _shielded:
				_start_dash(offset.normalized())
				
		velocity = dir_to_player * target_speed

	move_and_slide()

	# Rotation
	var aim_dir = (_player_ref.global_position - global_position).normalized()
	sprite.rotation = lerp_angle(sprite.rotation, aim_dir.angle(), 10.0 * delta)
	$LightOccluder2D.rotation = lerp_angle(sprite.rotation, aim_dir.angle(), 10.0 * delta)
	
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
	if not _combat_active:
		return false
	if _defeated:
		return false
	if not _is_clone and _shielded:
		_flash_blocked_hit()
		return false
	
	_health = maxi(0, _health - amount)
	
	# Hit effect
	var tween := create_tween()
	sprite.modulate = Color.RED
	tween.tween_property(sprite, "modulate", VULNERABLE_COLOR if not _is_clone else Color(1.0, 0.6, 0.6, 1.0), 0.1)
	
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

func set_combat_active(active: bool) -> void:
	if _defeated:
		return
	_combat_active = active
	if not _combat_active:
		velocity = Vector2.ZERO

func is_combat_active() -> bool:
	return _combat_active

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

func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
	
	if not _is_clone:
		for clone in get_tree().get_nodes_in_group("boss_clone"):
			if is_instance_valid(clone):
				clone.queue_free()
	
	ScreenFX.screen_shake(20.0, 0.45)
	ScreenFX.flash_screen(Color(1.0, 0.08, 0.08, 0.72), 0.5)
	ScreenFX.flash_screen(Color(0.2, 1.0, 0.45, 0.45), 0.7)
	
	if _is_clone:
		# Play explosive glass shattering sound for duplicates
		AudioManager.play_sfx("explosive-glass-shatter")
	else:
		AudioManager.play_sfx("dragon-studio-cinematic-boom")
	
	_spawn_death_binary_cataclysm()
	_shatter_sprite()

func _shatter_sprite() -> void:
	if not is_instance_valid(sprite) or sprite.texture == null:
		_finish_death_sequence()
		return
	_spawn_shatter_from_sprite(sprite, SHATTER_ROWS, SHATTER_COLS, SHATTER_DURATION, SHATTER_FORCE)
	sprite.visible = false
	var timer := get_tree().create_timer(SHATTER_DURATION + 0.12, false)
	timer.timeout.connect(_finish_death_sequence)

func _finish_death_sequence() -> void:
	if not _is_clone:
		Music.stopsound()
		defeated.emit()
	queue_free()

func _spawn_shatter_from_sprite(source_sprite: Sprite2D, rows: int, cols: int, duration: float, force: float) -> void:
	if source_sprite == null or source_sprite.texture == null:
		return
	var texture_size := source_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var piece_size := texture_size / Vector2(float(cols), float(rows))
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	for y in rows:
		for x in cols:
			var atlas := AtlasTexture.new()
			atlas.atlas = source_sprite.texture
			atlas.region = Rect2(Vector2(x, y) * piece_size, piece_size)
			var shard := Sprite2D.new()
			shard.texture = atlas
			shard.centered = true
			shard.scale = source_sprite.global_scale
			shard.global_rotation = source_sprite.global_rotation
			shard.modulate = source_sprite.modulate
			var cell_center := (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) * piece_size
			var offset := cell_center - texture_size * 0.5
			var rotated_offset := (offset * source_sprite.global_scale).rotated(source_sprite.global_rotation)
			shard.global_position = source_sprite.global_position + rotated_offset
			var outward_dir := offset.normalized()
			if outward_dir.length_squared() < 0.001:
				outward_dir = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
			var random_spread := Vector2(randf_range(-0.28, 0.28), randf_range(-0.28, 0.28))
			var travel := (outward_dir + random_spread).normalized() * randf_range(force * 0.6, force)
			var target_pos := shard.global_position + travel
			var target_rot := shard.rotation + randf_range(-3.1, 3.1)
			scene_root.add_child(shard)
			var tween := shard.create_tween()
			tween.set_parallel(true)
			tween.tween_property(shard, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "rotation", target_rot, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.set_parallel(false)
			tween.tween_callback(shard.queue_free)

func _spawn_death_binary_cataclysm() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 320
	scene_root.add_child(layer)
	var bounds := viewport.get_visible_rect().size

	for i in DEATH_DIGIT_COUNT:
		var digit := Label.new()
		digit.text = "1" if randi() % 2 == 0 else "O"
		digit.position = Vector2(randf_range(0.0, bounds.x), randf_range(0.0, bounds.y))
		digit.rotation = randf_range(-0.45, 0.45)
		digit.modulate.a = 0.0
		digit.add_theme_font_override("font", preload("res://Minecraft.ttf"))
		digit.add_theme_font_size_override("font_size", randi_range(11, 28))
		digit.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 0.95))
		digit.add_theme_color_override("outline_color", Color(0.0, 0.18, 0.07, 0.95))
		digit.add_theme_constant_override("outline_size", 1)
		layer.add_child(digit)
		var digit_tween := digit.create_tween()
		digit_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var start_delay := randf_range(0.0, maxf(0.0, SHATTER_DURATION - (DEATH_DIGIT_EFFECT_TIME + 0.2)))
		var drift := Vector2(randf_range(-200.0, 200.0), randf_range(-240.0, 240.0))
		digit_tween.tween_interval(start_delay)
		digit_tween.tween_property(digit, "modulate:a", 1.0, 0.05)
		digit_tween.parallel().tween_property(digit, "position", digit.position + drift, DEATH_DIGIT_EFFECT_TIME)
		digit_tween.parallel().tween_property(digit, "rotation", digit.rotation + randf_range(-2.3, 2.3), DEATH_DIGIT_EFFECT_TIME)
		digit_tween.tween_property(digit, "modulate:a", 0.0, 0.3)
		digit_tween.tween_callback(digit.queue_free)

	for i in DEATH_EXPLOSION_COUNT:
		var blast := ColorRect.new()
		blast.color = Color(0.1, 1.0, 0.35, randf_range(0.2, 0.46))
		blast.size = Vector2.ONE * randf_range(9.0, 24.0)
		blast.position = Vector2(randf_range(0.0, bounds.x), randf_range(0.0, bounds.y)) - blast.size * 0.5
		blast.pivot_offset = blast.size * 0.5
		blast.modulate.a = 0.0
		layer.add_child(blast)
		var blast_tween := blast.create_tween()
		blast_tween.tween_interval(randf_range(0.0, maxf(0.0, SHATTER_DURATION - 0.35)))
		blast_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		blast_tween.tween_property(blast, "modulate:a", randf_range(0.35, 0.62), 0.08)
		blast_tween.tween_property(blast, "scale", Vector2(randf_range(3.4, 9.2), randf_range(3.4, 9.2)), 0.3)
		blast_tween.parallel().tween_property(blast, "modulate:a", 0.0, 0.3)
		blast_tween.tween_callback(blast.queue_free)

	var cleanup_timer := get_tree().create_timer(SHATTER_DURATION + 0.3, false)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)
