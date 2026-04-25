extends CharacterBody2D

@export var move_speed := 140.0
@export var shoot_range := 180.0
@export var shoot_cooldown := 0.4
@export var laser_spawn_distance := 12.0
@export var entity_id := "bug_01"
@export var max_health := 10
@export var hit_flash_duration := 0.1
@export var hit_flash_color := Color(1.0, 0.3, 0.3, 1.0)
const LASER_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")
const GHOST_INTERVAL := 0.045
const GHOST_LIFETIME := 0.16
const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.32)
const SHARD_COUNT := 8
const SHATTER_DURATION := 0.22

var _player_ref: CharacterBody2D = null
var _shoot_cd := 0.0
var _ghost_timer := 0.0
var _defeated := false
var _health := 0
var _hit_flash_tween: Tween = null

@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	add_to_group("enemy")
	_health = maxi(1, max_health)
	_update_health_bar()
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	EntityRegistry.register(
		entity_id,
		"bug",
		self,
		["enforcer", "watchdog", "bug", "mobile"],
		{"integrity_contribution": -0.03}
	)

func take_damage(amount: int) -> bool:
	if _defeated:
		return false
	var final_damage: int = maxi(1, amount)
	_health = maxi(0, _health - final_damage)
	_update_health_bar()
	_play_hit_flash()
	if _health > 0:
		return false
	AudioManager.play_sfx("freesound_community-glass-shatter")
	shatter()
	return true

func get_health() -> int:
	return _health

func get_max_health() -> int:
	return max_health

func _update_health_bar() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = _health
		health_bar.visible = _health > 0 # Show always if alive

func _play_hit_flash() -> void:
	if not is_instance_valid(body_sprite):
		return
	if is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	body_sprite.modulate = hit_flash_color
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(body_sprite, "modulate", Color.WHITE, hit_flash_duration)

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)

func _physics_process(delta: float) -> void:
	if _defeated:
		if is_instance_valid(health_bar):
			health_bar.visible = false
		return
	
	# Update health bar position/rotation (keep it upright and centered above the bug)
	if is_instance_valid(health_bar):
		# We want the bar to be at (0, -28) in GLOBAL space relative to our position
		# but it's a child, so we must counteract our own rotation
		health_bar.rotation = -rotation
		# Counter-rotate the offset so it stays "above" the bug in world space
		var offset := Vector2(0, -28).rotated(-rotation)
		health_bar.position = offset - (health_bar.size / 2.0).rotated(-rotation)
		# Actually simpler to just use top_level if it's easier, but this keeps it a child
		# Adjusting for local offset center:
		health_bar.position = Vector2(-15, -28).rotated(-rotation)
		# Wait, simplest way is to put the bar in a non-rotating Node2D marker. 
		# Let's just fix the position/rotation manually here.
		health_bar.rotation = -rotation
		health_bar.position = Vector2(0, -28).rotated(-rotation) + Vector2(-15, 0).rotated(-rotation)

	if is_instance_valid(visibility_notifier) and not visibility_notifier.is_on_screen():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player_ref == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	var to_player := _player_ref.global_position - global_position
	if to_player.length_squared() > 0.01:
		rotation = to_player.angle()
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if velocity.length_squared() > 16.0:
		_ghost_step(delta)

	var distance_to_player := global_position.distance_to(_player_ref.global_position)
	if distance_to_player <= shoot_range and _shoot_cd <= 0.0:
		_fire_laser(to_player)

func _fire_laser(to_player: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var laser := LASER_SCENE.instantiate()
	if laser == null:
		return
	var shot_dir := to_player.normalized() if to_player.length_squared() > 0.0 else Vector2.RIGHT
	scene_root.add_child(laser)
	laser.global_position = global_position + shot_dir * laser_spawn_distance
	if laser.has_method("setup"):
		laser.setup(self, shot_dir)
	_shoot_cd = shoot_cooldown

func _ghost_step(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = GHOST_INTERVAL
	_spawn_ghost_from(body_sprite)

func _spawn_ghost_from(source: CanvasItem) -> void:
	if not is_instance_valid(source):
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ghost := source.duplicate()
	if not (ghost is CanvasItem):
		return
	scene_root.add_child(ghost)
	var ghost_item := ghost as CanvasItem
	ghost_item.top_level = true
	ghost_item.z_index = source.z_index - 1
	ghost_item.modulate = GHOST_COLOR
	if source is Node2D and ghost_item is Node2D:
		var src_n2d := source as Node2D
		var ghost_n2d := ghost_item as Node2D
		ghost_n2d.global_position = src_n2d.global_position
		ghost_n2d.global_rotation = src_n2d.global_rotation
		ghost_n2d.scale = src_n2d.scale
	elif source is Control and ghost_item is Control:
		var src_ctrl := source as Control
		var ghost_ctrl := ghost_item as Control
		ghost_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost_ctrl.global_position = src_ctrl.global_position
		ghost_ctrl.rotation = src_ctrl.rotation
		ghost_ctrl.scale = src_ctrl.scale
	var tween := ghost_item.create_tween()
	tween.tween_property(ghost_item, "modulate:a", 0.0, GHOST_LIFETIME)
	tween.tween_callback(ghost_item.queue_free)

func shatter() -> void:
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
	_spawn_shards()
	visible = false
	await get_tree().create_timer(SHATTER_DURATION).timeout
	queue_free()

func _spawn_shards() -> void:
	if not is_instance_valid(body_sprite):
		return
	var frame_tex := body_sprite.sprite_frames.get_frame_texture(body_sprite.animation, body_sprite.frame)
	if frame_tex == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	for i in SHARD_COUNT:
		var shard := Sprite2D.new()
		shard.texture = frame_tex
		shard.global_position = global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		shard.global_rotation = randf_range(0.0, TAU)
		shard.scale = Vector2.ONE * randf_range(0.35, 0.65)
		shard.z_index = z_index + 1
		scene_root.add_child(shard)

		var drift := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(20.0, 60.0)
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", shard.global_position + drift, SHATTER_DURATION)
		tween.parallel().tween_property(shard, "global_rotation", shard.global_rotation + randf_range(-3.0, 3.0), SHATTER_DURATION)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, SHATTER_DURATION)
		tween.tween_callback(shard.queue_free)
