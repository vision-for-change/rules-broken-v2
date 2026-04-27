extends CharacterBody2D

@export var move_speed := 120.0
@export var entity_id := "snake_01"
@export var max_health := 30
@export var hit_flash_duration := 0.1
@export var hit_flash_color := Color(1.0, 0.3, 0.3, 1.0)
@export var segment_count := 6
@export var segment_spacing := 12.0
@export var explosion_delay := 0.1

const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.2)
const SHARD_COUNT := 8
const SHATTER_DURATION := 0.22
const EXPLOSION_DAMAGE_PER_SEGMENT := 0.4

var _player_ref: CharacterBody2D = null
var _defeated := false
var _health := 0
var _hit_flash_tween: Tween = null
var _pos_history: Array[Vector2] = []
var _segments: Array[Sprite2D] = []
var _contact_area: Area2D = null

@onready var health_bar: ProgressBar = $HealthBar
@onready var head_sprite: Sprite2D = $Head

func _ready() -> void:
	add_to_group("enemy")
	_health = maxi(1, max_health)
	_update_health_bar()
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	EntityRegistry.register(
		entity_id,
		"snake",
		self,
		["enforcer", "snake", "mobile"],
		{"integrity_contribution": -0.04}
	)
	
	_setup_contact_area()
	_setup_segments()

func _setup_segments() -> void:
	var tex = load("res://assets/sprites/snake_segment.webp")
	for i in range(segment_count):
		var s = Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * (1.0 - (float(i) / segment_count) * 0.4)
		s.z_index = z_index + 1
		add_child(s)
		_segments.append(s)
		# Initialize history
		for j in range(int(segment_spacing)):
			_pos_history.append(global_position)

func _setup_contact_area() -> void:
	_contact_area = Area2D.new()
	_contact_area.body_entered.connect(_on_contact_body_entered)
	add_child(_contact_area)
	
	var shape = CircleShape2D.new()
	shape.radius = 18.0
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	_contact_area.add_child(collision_shape)
	
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = 1

func take_damage(amount: int) -> bool:
	# Snake is immune to standard bullets/damage
	return false

func check_dash_collision(player_node: Node) -> bool:
	if _defeated or player_node == null:
		return false
	
	var is_dashing = player_node.is_dashing() if player_node.has_method("is_dashing") else false
	var modes = player_node.get_hacked_client_modes() if player_node.has_method("get_hacked_client_modes") else {}
	var has_super_speed = modes.get("super_speed", false)

	# The snake can only be killed if the player is dashing AND has super speed
	if is_dashing and has_super_speed:
		_health = 0
		ScreenFX.slow_motion_pulse(0.2, 1.0)
		shatter()
		return true
	
	return false

func _update_health_bar() -> void:
	# Hide the health bar as the snake is special and doesn't take normal damage
	if is_instance_valid(health_bar):
		health_bar.visible = false

func _play_hit_flash() -> void:
	if is_instance_valid(_hit_flash_tween): _hit_flash_tween.kill()
	modulate = hit_flash_color
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(self, "modulate", Color.WHITE, hit_flash_duration)

func _physics_process(delta: float) -> void:
	if _defeated: return
	
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		return

	# Slither movement
	var to_player = (_player_ref.global_position - global_position).normalized()
	
	# Add a sine wave to the movement for slithering effect
	var slither_offset = to_player.rotated(PI/2) * sin(Time.get_ticks_msec() * 0.01) * 0.5
	var move_dir = (to_player + slither_offset).normalized()
	
	velocity = move_dir * move_speed
	move_and_slide()
	
	if velocity.length() > 0:
		rotation = lerp_angle(rotation, velocity.angle(), 10.0 * delta)
	
	# Update segments
	_pos_history.push_front(global_position)
	if _pos_history.size() > segment_count * segment_spacing + 1:
		_pos_history.pop_back()
	
	for i in range(segment_count):
		var idx = int((i + 1) * segment_spacing)
		if idx < _pos_history.size():
			_segments[i].global_position = _pos_history[idx]
			# Rotate segment to follow the path
			var prev_idx = maxi(0, idx - 2)
			_segments[i].rotation = (_pos_history[prev_idx] - _pos_history[idx]).angle()

	# Health bar stays above head
	if is_instance_valid(health_bar):
		health_bar.rotation = -rotation
		health_bar.position = Vector2(0, -25).rotated(-rotation) + Vector2(-15, 0).rotated(-rotation)

	# Slow drain while in contact
	if _contact_area != null:
		for body in _contact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				var is_dashing = body.is_dashing() if body.has_method("is_dashing") else false
				var modes = body.get_hacked_client_modes() if body.has_method("get_hacked_client_modes") else {}
				var has_super_speed = modes.get("super_speed", false)
				
				if is_dashing or has_super_speed:
					_health = 0
					shatter()
					break
				else:
					if RuleManager.has_method("apply_integrity_damage"):
						# Drains integrity slowly over time
						RuleManager.apply_integrity_damage(3.5 * delta)

func shatter() -> void:
	if _defeated: return
	_defeated = true
	EventBus.enemy_defeated.emit(entity_id)
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
	AudioManager.play_sfx("explosive-glass-shatter")
	_spawn_shards()
	visible = false
	await get_tree().create_timer(SHATTER_DURATION).timeout
	queue_free()

func _spawn_shards() -> void:
	_spawn_shards_from_sprite(head_sprite)
	for segment in _segments:
		_spawn_shards_from_sprite(segment)

func _spawn_shards_from_sprite(source_sprite: Sprite2D) -> void:
	if not is_instance_valid(source_sprite) or source_sprite.texture == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	for i in SHARD_COUNT:
		var shard := Sprite2D.new()
		shard.texture = source_sprite.texture
		shard.global_position = source_sprite.global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		shard.global_rotation = randf_range(0.0, TAU)
		shard.scale = source_sprite.global_scale * randf_range(0.35, 0.65)
		shard.z_index = source_sprite.z_index + 1
		scene_root.add_child(shard)

		var drift := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(20.0, 60.0)
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", shard.global_position + drift, SHATTER_DURATION)
		tween.parallel().tween_property(shard, "global_rotation", shard.global_rotation + randf_range(-3.0, 3.0), SHATTER_DURATION)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, SHATTER_DURATION)
		tween.tween_callback(shard.queue_free)

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)

func _on_contact_body_entered(body: Node2D) -> void:
	if _defeated:
		return
	
	if body != _player_ref:
		return
	
	var modes = _player_ref.get_hacked_client_modes() if _player_ref.has_method("get_hacked_client_modes") else {}
	var is_dashing = _player_ref.is_dashing() if _player_ref.has_method("is_dashing") else false
	var has_super_speed = modes.get("super_speed", false)
	
	if is_dashing and has_super_speed:
		return
	
	_explode_segments()

func _explode_segments() -> void:
	if _defeated:
		return
	_defeated = true
	EventBus.enemy_defeated.emit(entity_id)
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
	
	if is_instance_valid(health_bar):
		health_bar.visible = false
	
	var total_damage = int(max_health * 0.2)
	
	# Explode head first
	_spawn_shards_from_sprite(head_sprite)
	_spawn_explosion_at_position(head_sprite.global_position)
	head_sprite.visible = false
	if _player_ref != null and is_instance_valid(_player_ref) and _player_ref.has_method("take_damage"):
		_player_ref.call("take_damage", total_damage)
		ScreenFX.screen_shake(3.0, 0.15)
		AudioManager.play_sfx("explosive-glass-shatter")
	
	# Explode each segment in order
	for i in range(segment_count):
		await get_tree().create_timer(explosion_delay).timeout
		if is_instance_valid(_segments[i]):
			_spawn_shards_from_sprite(_segments[i])
			_spawn_explosion_at_position(_segments[i].global_position)
			_segments[i].visible = false
		if _player_ref != null and is_instance_valid(_player_ref) and _player_ref.has_method("take_damage"):
			_player_ref.call("take_damage", total_damage)
			ScreenFX.screen_shake(3.0, 0.15)
			AudioManager.play_sfx("explosive-glass-shatter")
	
	await get_tree().create_timer(SHATTER_DURATION).timeout
	queue_free()

func _spawn_explosion_at_position(pos: Vector2) -> void:
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return
	
	# Shatter effect - spray out pieces (bigger explosion)
	for i in range(24):
		var shard = Sprite2D.new()
		shard.texture = load("res://assets/sprites/snake_segment.webp")
		shard.global_position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		shard.global_rotation = randf_range(0.0, TAU)
		shard.scale = Vector2.ONE * randf_range(0.4, 0.8)
		shard.z_index = 10
		scene_root.add_child(shard)
		
		var drift = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(60.0, 140.0)
		var tween = shard.create_tween()
		tween.tween_property(shard, "global_position", shard.global_position + drift, SHATTER_DURATION)
		tween.parallel().tween_property(shard, "global_rotation", shard.global_rotation + randf_range(-5.0, 5.0), SHATTER_DURATION)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, SHATTER_DURATION)
		tween.tween_callback(shard.queue_free)
	
	# Digital matrix effect - 0's and 1's (bigger explosion)
	for i in range(32):
		var digit = Label.new()
		digit.text = "1" if randi() % 2 == 0 else "0"
		digit.position = pos + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
		digit.add_theme_font_size_override("font_size", randi_range(18, 32))
		digit.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 0.95))
		digit.z_index = 11
		scene_root.add_child(digit)
		
		var drift = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(50.0, 120.0)
		var digit_tween = digit.create_tween()
		digit_tween.tween_property(digit, "position", digit.position + drift, SHATTER_DURATION * 0.7)
		digit_tween.parallel().tween_property(digit, "modulate:a", 0.0, SHATTER_DURATION * 0.7)
		digit_tween.tween_callback(digit.queue_free)
