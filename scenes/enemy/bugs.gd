extends CharacterBody2D

@export var move_speed := 200.0
@export var shoot_range := 180.0
@export var shoot_cooldown := 0.4
@export var laser_spawn_distance := 12.0
@export var entity_id := "bug_01"
const LASER_SCENE := preload("res://scenes/enemy/EnemyLaser.tscn")
const GHOST_INTERVAL := 0.045
const GHOST_LIFETIME := 0.16
const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.32)

var _player_ref: CharacterBody2D = null
var _shoot_cd := 0.0
var _ghost_timer := 0.0

@onready var body_rect: ColorRect = $BodyRect

func _ready() -> void:
	add_to_group("enemy")
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	EntityRegistry.register(
		entity_id,
		"bug",
		self,
		["enforcer", "watchdog", "bug", "mobile"],
		{"integrity_contribution": -0.03}
	)

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)

func _physics_process(delta: float) -> void:
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player_ref == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	var to_player := _player_ref.global_position - global_position
	if to_player.length_squared() > 0.01:
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
	_spawn_ghost_from(body_rect)

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
