extends CharacterBody2D

signal death_animation_finished
signal shatter_started

@export var entity_id := "chatgpt_boss"
@export var max_health := 1000

const DEATH_SHAKE_INTENSITY := 20.0
const DEATH_SHAKE_DURATION := 0.45
const DEATH_DIGIT_COUNT := 260
const DEATH_EXPLOSION_COUNT := 120
const DEATH_DIGIT_EFFECT_TIME := 1.8
const SHATTER_ROWS := 6
const SHATTER_COLS := 6
const SHATTER_DURATION := 2.2
const SHATTER_FORCE := 260.0

# Attack timing and circle/ring settings
const ATTACK_COOLDOWN := 6.0
const CIRCLE_COUNT := 3
const CIRCLE_SPAWN_DELAY := 2.0
const CIRCLE_GROW_DURATION := 1.5
const CIRCLE_MAX_RADIUS := 120.0
const CIRCLE_COLOR := Color(1.0, 0.2, 0.2, 0.6)
const PLAYER_DAMAGE_PERCENT := 0.3

# Spin barrage settings
const BARRAGE_PROJECTILE_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")
const BARRAGE_PROJECTILES := 64
const BARRAGE_DURATION := 2.0
const BARRAGE_SLOW_SCALE := 0.28
const BARRAGE_SPIN_SPEED := 12.0 # radians per second for visual spin
const BARRAGE_SPREAD_JITTER := 0.14

# Continuous barrage settings (always-on 360)
const BARRAGE_CONTINUOUS := true
const BARRAGE_INTERVAL := 0.06              # seconds between ticks
const BARRAGE_PROJECTILES_PER_TICK := 8     # projectiles spawned each tick forming a partial ring
const BARRAGE_ROTATION_SPEED := 1.2         # radians per second for phase rotation

var _health := 0
var _defeated := false
var _attack_cooldown := 0.0
var _barrage_phase := 0.0

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemy")
	_health = maxi(1, max_health)
	_start_attack_loop()
	# Start continuous barrage if enabled
	if BARRAGE_CONTINUOUS:
		_start_continuous_barrage()

func take_damage(amount: int) -> bool:
	if _defeated:
		return false
	var final_damage := maxi(1, amount)
	_health = maxi(0, _health - final_damage)
	if _health > 0:
		return false
	_defeated = true
	_play_death_animation()
	return true

func get_health() -> int:
	return _health

func get_max_health() -> int:
	return max_health

func _play_death_animation() -> void:
	EventBus.enemy_defeated.emit(entity_id)
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true

	ScreenFX.screen_shake(DEATH_SHAKE_INTENSITY, DEATH_SHAKE_DURATION)
	ScreenFX.flash_screen(Color(1.0, 0.08, 0.08, 0.72), 0.5)
	ScreenFX.flash_screen(Color(0.2, 1.0, 0.45, 0.45), 0.7)
	AudioManager.play_sfx("dragon-studio-cinematic-boom")
	_spawn_death_binary_cataclysm()
	_shatter_sprite()

func _shatter_sprite() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		_finish_death_sequence()
		return
	shatter_started.emit()
	_spawn_shatter_from_sprite(_sprite, SHATTER_ROWS, SHATTER_COLS, SHATTER_DURATION, SHATTER_FORCE)
	_sprite.visible = false
	var timer := get_tree().create_timer(SHATTER_DURATION + 0.12, false)
	timer.timeout.connect(_finish_death_sequence)

func _finish_death_sequence() -> void:
	death_animation_finished.emit()
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

func _start_attack_loop() -> void:
	while not _defeated:
		await get_tree().create_timer(ATTACK_COOLDOWN).timeout
		if not _defeated:
			if randi() % 2 == 0:
				_perform_circle_attack()
			else:
				_perform_spin_barrage()

func _perform_spin_barrage() -> void:
	# Slow time, spin sprite visually, and fire a dense radial projectile pattern with jitter to create gaps
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	# Visual spin only (no global time scaling for always-on barrage)
	# (Keeping this function as a burst visual effect without changing Engine.time_scale.)

	# Visual spin: rotate the sprite quickly for the duration
	var spin_tween := _sprite.create_tween()
	spin_tween.set_parallel(true)
	spin_tween.tween_property(_sprite, "rotation", _sprite.rotation + BARRAGE_SPIN_SPEED * BARRAGE_DURATION, BARRAGE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Fire projectiles over the duration; timers are scaled by Engine.time_scale
	var interval := BARRAGE_DURATION / float(BARRAGE_PROJECTILES)
	for i in range(BARRAGE_PROJECTILES):
		if _defeated:
			break
		var angle := TAU * float(i) / float(BARRAGE_PROJECTILES) + randf_range(-BARRAGE_SPREAD_JITTER, BARRAGE_SPREAD_JITTER)
		_spawn_barrage_projectile(angle)
		await get_tree().create_timer(interval).timeout

	# No time scale to restore when used as a visual burst

func _spawn_barrage_projectile(angle: float) -> void:
	var proj := BARRAGE_PROJECTILE_SCENE.instantiate()
	if proj == null:
		return
	var dir := Vector2.RIGHT.rotated(angle)
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)
	if proj.has_method("setup"):
		proj.call("setup", self, dir)

func _start_continuous_barrage() -> void:
	# Continuously spawn partial rings that rotate over time to create a constant 360° threat
	_barrage_phase = 0.0
	while not _defeated:
		for i in range(BARRAGE_PROJECTILES_PER_TICK):
			var angle := TAU * float(i) / float(BARRAGE_PROJECTILES_PER_TICK) + _barrage_phase + randf_range(-BARRAGE_SPREAD_JITTER, BARRAGE_SPREAD_JITTER)
			_spawn_barrage_projectile(angle)
		await get_tree().create_timer(BARRAGE_INTERVAL).timeout
		_barrage_phase += BARRAGE_ROTATION_SPEED * BARRAGE_INTERVAL

func _perform_circle_attack() -> void:
	for i in range(CIRCLE_COUNT):
		if _defeated:
			break
		_spawn_expanding_circle()
		if i < CIRCLE_COUNT - 1:
			await get_tree().create_timer(CIRCLE_SPAWN_DELAY).timeout

func _spawn_expanding_circle() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	
	var circle = Node2D.new()
	circle.global_position = global_position
	scene_root.add_child(circle)
	
	var visual = ColorRect.new()
	visual.anchor_left = 0.5
	visual.anchor_top = 0.5
	visual.anchor_right = 0.5
	visual.anchor_bottom = 0.5
	visual.color = CIRCLE_COLOR
	visual.modulate.a = 0.5
	circle.add_child(visual)
	
	var current_radius := 0.0
	var grow_tween := create_tween()
	grow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	grow_tween.tween_method(
		func(r: float) -> void:
			current_radius = r
			visual.size = Vector2.ONE * r * 2.0
			visual.position = Vector2(-r, -r),
		0.0,
		CIRCLE_MAX_RADIUS,
		CIRCLE_GROW_DURATION
	)
	
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		await grow_tween.finished
		
		# Check distance to player
		var dist := global_position.distance_to(player.global_position)
		if dist <= CIRCLE_MAX_RADIUS:
			var has_noclip = player.get("_hack_noclip") as bool
			if not has_noclip and player.is_alive:
				# Instead of instant death, deal percentage damage to system integrity
				var damage_amount := RuleManager.get_max_integrity() * PLAYER_DAMAGE_PERCENT
				RuleManager.apply_integrity_damage(damage_amount)
				
				# Feedback for getting hit
				EventBus.log("!! CORE PULSE DETECTED — SYSTEM INTEGRITY DAMAGED !!", "error")
				ScreenFX.flash_screen(Color(1.0, 0.1, 0.1, 0.5), 0.25)
				ScreenFX.screen_shake(10.0, 0.4)
				AudioManager.play_sfx("dragon-studio-cinematic-boom")
	
	circle.queue_free()
