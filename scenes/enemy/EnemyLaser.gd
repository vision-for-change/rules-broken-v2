extends Area2D

@export var speed := 520.0
@export var lifetime := 1.6
@export var integrity_damage := 0.4
const GHOST_INTERVAL := 0.015
const GHOST_LIFETIME := 0.4
const GHOST_COLOR := Color(1.0, 0.0, 0.0, 0.95)
const DASH_DODGE_RADIUS := 28.0
const DASH_DODGE_PASS_MARGIN := 8.0

var _direction := Vector2.RIGHT
var _owner_body: Node2D = null
var _ghost_timer := 0.0
var _player_ref: Node2D = null
var _dash_dodge_armed := false
var _dash_dodge_triggered := false
var _player_damage := 15

@onready var beam: Sprite2D = $Beam

func _ready() -> void:
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D

func setup(owner_body: Node2D, direction: Vector2) -> void:
	_owner_body = owner_body
	_direction = direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	rotation = _direction.angle()
	_player_damage = _resolve_player_damage(owner_body)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_try_trigger_dash_dodge_slowmo()
	_ghost_step(delta)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == _owner_body:
		return
	if body == null:
		return
	
	if body.is_in_group("player"):
		# If player is already dead don't do anything
		if body.get("is_alive") == false:
			queue_free()
			return
		
		# Feedback for hitting player
		ScreenFX.flash_screen(Color(1.0, 0.1, 0.1, 0.4), 0.25)
		ScreenFX.screen_shake(3.0, 0.15)
		ScreenFX.spawn_hit_flash(global_position, Color(1.0, 0.4, 0.2, 1.0), 18.0, 0.18)
		
		# Deal damage to both systems
		if RuleManager.has_method("apply_integrity_damage"):
			RuleManager.apply_integrity_damage(1.0) # ~11% of integrity
		
		if body.has_method("take_damage"):
			body.take_damage(_player_damage)
			
		EventBus.log("SYSTEM INTEGRITY COMPROMISED", "error")
		queue_free()
	elif body.is_in_group("enemy"):
		# Let it pass through other enemies so it doesn't get blocked accidentally
		return
	else:
		# Hit a wall or static object
		queue_free()
	

func _ghost_step(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = GHOST_INTERVAL
	_spawn_ghost_from(beam)

func _spawn_ghost_from(source: CanvasItem) -> void:
	if not is_instance_valid(source):
		return
	if source is Sprite2D:
		var src_sprite := source as Sprite2D
		if src_sprite.texture == null:
			return
		var scene_root := get_tree().current_scene
		if scene_root == null:
			return
		var ghost_sprite := Sprite2D.new()
		ghost_sprite.texture = src_sprite.texture
		ghost_sprite.scale = src_sprite.scale * 1.35
		ghost_sprite.global_position = src_sprite.global_position
		ghost_sprite.global_rotation = src_sprite.global_rotation
		ghost_sprite.z_index = z_index - 1
		ghost_sprite.modulate = GHOST_COLOR
		scene_root.add_child(ghost_sprite)
		var sprite_tween := ghost_sprite.create_tween()
		sprite_tween.tween_property(ghost_sprite, "modulate:a", 0.0, GHOST_LIFETIME)
		sprite_tween.tween_callback(ghost_sprite.queue_free)
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
	ghost_item.z_index = z_index - 1
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

func _try_trigger_dash_dodge_slowmo() -> void:
	if _dash_dodge_triggered:
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
		if _player_ref == null:
			return
	if not _player_ref.has_method("is_dashing"):
		return

	var to_player := _player_ref.global_position - global_position
	var dash_dodge_radius_sq := DASH_DODGE_RADIUS * DASH_DODGE_RADIUS
	if bool(_player_ref.call("is_dashing")) and to_player.length_squared() <= dash_dodge_radius_sq:
		_dash_dodge_armed = true
	if not _dash_dodge_armed:
		return

	if to_player.dot(_direction) < -DASH_DODGE_PASS_MARGIN:
		_dash_dodge_triggered = true
		ScreenFX.flash_screen(Color(0.1, 1.0, 0.35, 0.28), 0.14)
		ScreenFX.slow_motion_pulse()

func _resolve_player_damage(owner_body: Node2D) -> int:
	if owner_body == null:
		return 15
	if owner_body.get_script() != null and str(owner_body.get_script().resource_path) == "res://scenes/enemy/bugs.gd":
		return 5
	return 15
