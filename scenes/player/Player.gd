extends CharacterBody2D

const SPEED_MOVE = 360.0
const HACK_SPEED_MULT = 2.4
const DASH_SPEED_MULT = 2.2
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.5
const HACK_BULLET_SPEED_MULT = 2.2
const DEFAULT_CAMERA_ZOOM := Vector2(1.5, 1.5)
const SUPER_VISION_CAMERA_ZOOM := Vector2(1.0, 1.0)
const ENTITY_ID = "player"
const BULLET_SCENE = preload("res://scenes/player/Bullet.tscn")
const SHOOT_COOLDOWN := 0.2
const GHOST_INTERVAL := 0.045
const DASH_GHOST_INTERVAL := 0.015
const GHOST_LIFETIME := 0.16
const DASH_GHOST_LIFETIME := 0.22
const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.32)
const DASH_GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.5)
const SHATTER_ROWS := 4
const SHATTER_COLS := 4
const SHATTER_DURATION := 0.75
const SHATTER_FORCE := 120.0
const SHOOT_SHAKE_INTENSITY := 1.2
const SHOOT_SHAKE_DURATION := 0.06
const DASH_SHAKE_INTENSITY := 3.2
const DASH_SHAKE_DURATION := 0.1
const FOOTSTEP_INT = 0.38

var is_alive := true
var _interact_target: Node = null
var _footstep_t := 0.0
var _hack_super_speed := false
var _hack_invincible := false
var _hack_faster_bullets := false
var _hack_ultimate_bullets := false
var _hack_super_vision := false
var _shoot_cd := 0.0
var _ghost_timer := 0.0
var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_direction := Vector2.ZERO
var damage := 10
var max_ammo := 12
var fire_rate := 0.3


@onready var body_rect: ColorRect  = $BodyRect
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D      = $Camera2D
@onready var hint_label: Label     = $HintLabel
@onready var gun_sprite: Sprite2D  = $Sprite2D   # GUN NODE
@onready var player_sprite: Sprite2D = $PlayerSprite

func _ready() -> void:
	add_to_group("player")
	_load_selected_gun()   # ⭐ NEW — load gun sprite + stats

	ScreenFX.register_camera(camera)
	EntityRegistry.register(ENTITY_ID, "player", self,
		["player", "agent", "mobile"],
		{"integrity_contribution": 0.0}
	)
	EventBus.player_caught.connect(_on_caught)
	EventBus.action_denied.connect(_on_action_denied)
	interact_area.body_entered.connect(_on_interact_enter)
	interact_area.body_exited.connect(_on_interact_exit)
	AudioManager.play_music("stable")
	_apply_camera_modes()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_update_facing_to_mouse()
	_shoot_cd = max(0.0, _shoot_cd - delta)
	_dash_cd = max(0.0, _dash_cd - delta)
	_dash_timer = max(0.0, _dash_timer - delta)

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and dir.length() > 0.05:
		_dash_direction = dir.normalized()
		_dash_timer = DASH_DURATION
		_dash_cd = DASH_COOLDOWN
		ScreenFX.screen_shake(DASH_SHAKE_INTENSITY, DASH_SHAKE_DURATION)
	elif _dash_timer <= 0.0:
		_dash_direction = Vector2.ZERO

	var move_dir := dir
	if _dash_timer > 0.0 and _dash_direction.length() > 0.05:
		move_dir = _dash_direction

	var target_velocity := Vector2.ZERO
	if move_dir.length() > 0.05:
		var ctx = {"actor_id": ENTITY_ID, "direction": move_dir}
		var result = ActionBus.submit(ActionBus.MOVE, EntityRegistry.get_tags(ENTITY_ID), ctx)
		if result["allowed"]:
			target_velocity = move_dir * SPEED_MOVE
		else:
			target_velocity = move_dir * (SPEED_MOVE * 0.4)
		if _hack_super_speed:
			target_velocity *= HACK_SPEED_MULT
		if _dash_timer > 0.0:
			target_velocity *= DASH_SPEED_MULT
		_footstep_t += delta
		if _footstep_t >= FOOTSTEP_INT:
			_footstep_t = 0.0
			AudioManager.play_sfx("footstep")

	velocity = target_velocity
	move_and_slide()

	if velocity.length_squared() > 16.0:
		_ghost_step(delta)
	if Input.is_action_just_pressed("interact") and _interact_target != null:
		_do_interact()
	if Input.is_action_pressed("shoot"):
		_shoot()

func _update_facing_to_mouse() -> void:
	var aim_dir := get_global_mouse_position() - global_position
	if aim_dir.length_squared() < 0.001:
		return
	rotation = aim_dir.angle()
	hint_label.rotation = -rotation

func _shoot() -> void:
	if _shoot_cd > 0.0:
		return
	var muzzle_pos := gun_sprite.global_position if is_instance_valid(gun_sprite) else global_position
	var shot_dir := get_global_mouse_position() - muzzle_pos
	if shot_dir.length_squared() == 0.0:
		shot_dir = Vector2.RIGHT
	var bullet = BULLET_SCENE.instantiate()
	if bullet == null:
		return
	if get_tree().current_scene == null:
		return
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle_pos
	var bullet_speed_mult := HACK_BULLET_SPEED_MULT if _hack_faster_bullets else 1.0
	if bullet.has_method("setup"):
		bullet.setup(self, shot_dir.normalized(), bullet_speed_mult)
	ScreenFX.screen_shake(SHOOT_SHAKE_INTENSITY, SHOOT_SHAKE_DURATION)
	_shoot_cd = 0.0 if _hack_ultimate_bullets else SHOOT_COOLDOWN

func _do_interact() -> void:
	if _interact_target == null or not is_instance_valid(_interact_target):
		return
	var target_id = _interact_target.get("entity_id") if _interact_target.get("entity_id") != null else "unknown"
	var ctx = {
		"actor_id": ENTITY_ID,
		"target_id": target_id,
		"target_node": _interact_target
	}
	var result = ActionBus.submit(ActionBus.INTERACT, EntityRegistry.get_tags(ENTITY_ID), ctx)
	if result["allowed"] or result["loophole"] != "":
		_interact_target.on_player_interact(result)

func _on_interact_enter(body: Node) -> void:
	if body.has_method("on_player_interact"):
		_interact_target = body
		hint_label.text = "[ E ] " + (body.get_interact_hint() if body.has_method("get_interact_hint") else "Interact")
		hint_label.visible = true

func _on_interact_exit(body: Node) -> void:
	if body == _interact_target:
		_interact_target = null
		hint_label.visible = false

func _on_action_denied(action: Dictionary, reason: String) -> void:
	if action["actor_id"] != ENTITY_ID:
		return
	ScreenFX.flash_screen(Color(1, 0.3, 0.1, 0.3), 0.15)

func _on_caught(_catcher_id: String) -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	ScreenFX.screen_shake(14.0, 0.6)
	ScreenFX.flash_screen(Color(1, 0.0, 0.1, 0.7), 0.5)
	AudioManager.play_sfx("caught")
	_play_shatter_effect()
	get_tree().create_timer(1.5, false).timeout.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn"),
		CONNECT_ONE_SHOT
	)

func _play_shatter_effect() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	if is_instance_valid(player_sprite):
		_spawn_shatter_from_sprite(player_sprite, SHATTER_ROWS, SHATTER_COLS, SHATTER_DURATION, SHATTER_FORCE)
		player_sprite.visible = false
	if is_instance_valid(gun_sprite):
		_spawn_shatter_from_sprite(gun_sprite, 3, 3, SHATTER_DURATION * 0.9, SHATTER_FORCE * 0.8)
		gun_sprite.visible = false

func _spawn_shatter_from_sprite(source_sprite: Sprite2D, rows: int, cols: int, duration: float, force: float) -> void:
	if source_sprite == null:
		return
	if source_sprite.texture == null:
		return
	var texture_size := source_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var piece_size := texture_size / Vector2(float(cols), float(rows))
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
			var random_spread := Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
			var travel := (outward_dir + random_spread).normalized() * randf_range(force * 0.55, force)
			var target_pos := shard.global_position + travel
			var target_rot := shard.rotation + randf_range(-2.6, 2.6)
			get_tree().current_scene.add_child(shard)
			var tween := shard.create_tween()
			tween.set_parallel(true)
			tween.tween_property(shard, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "rotation", target_rot, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.set_parallel(false)
			tween.tween_callback(shard.queue_free)

func _load_selected_gun() -> void:
	var gid = PlayerState.selected_gun_id
	var gun = GunDatabase.GUNS.get(gid, null)
	if gun == null:
		return

	# Set gun sprite
	if gun.has("sprite") and ResourceLoader.exists(gun["sprite"]):
		gun_sprite.texture = load(gun["sprite"])

		# ⭐ AUTO-SCALE GUN TO A GOOD SIZE
		if gun_sprite.texture:
			var tex_size = gun_sprite.texture.get_size()
			var target_height := 20.0  # adjust this number if needed
			var scale_factor: float = target_height / tex_size.y
			gun_sprite.scale = Vector2(scale_factor, scale_factor)

	# Apply stats if they exist
	if gun.has("damage"):
		damage = gun["damage"]
	if gun.has("max_ammo"):
		max_ammo = gun["max_ammo"]
	if gun.has("fire_rate"):
		fire_rate = gun["fire_rate"]



func set_hacked_client_modes(
	super_speed_enabled: bool,
	invincible_enabled: bool,
	faster_bullets_enabled: bool = false,
	ultimate_bullets_enabled: bool = false,
	super_vision_enabled: bool = false
) -> void:
	_hack_super_speed = super_speed_enabled
	_hack_invincible = invincible_enabled
	_hack_faster_bullets = faster_bullets_enabled
	_hack_ultimate_bullets = ultimate_bullets_enabled
	if _hack_ultimate_bullets:
		_shoot_cd = 0.0
	_hack_super_vision = super_vision_enabled
	_apply_camera_modes()

func get_hacked_client_modes() -> Dictionary:
	return {
		"super_speed": _hack_super_speed,
		"invincible": _hack_invincible,
		"faster_bullets": _hack_faster_bullets,
		"ultimate_bullets": _hack_ultimate_bullets,
		"super_vision": _hack_super_vision
	}

func _apply_camera_modes() -> void:
	if camera == null:
		return
	camera.zoom = SUPER_VISION_CAMERA_ZOOM if _hack_super_vision else DEFAULT_CAMERA_ZOOM

func _ghost_step(delta: float) -> void:
	var dash_blur := is_dashing()
	var ghost_interval := DASH_GHOST_INTERVAL if dash_blur else GHOST_INTERVAL
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = ghost_interval
	_spawn_player_ghost(dash_blur)

func _spawn_player_ghost(dash_blur: bool = false) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ghost_root := Node2D.new()
	ghost_root.global_position = global_position
	ghost_root.global_rotation = global_rotation
	ghost_root.scale = scale
	ghost_root.z_index = z_index - 1
	ghost_root.modulate = DASH_GHOST_COLOR if dash_blur else GHOST_COLOR
	scene_root.add_child(ghost_root)
	if is_instance_valid(body_rect):
		var body_ghost := body_rect.duplicate()
		if body_ghost is Control:
			(body_ghost as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost_root.add_child(body_ghost)
	if is_instance_valid(gun_sprite):
		ghost_root.add_child(gun_sprite.duplicate())
	var tween := ghost_root.create_tween()
	var ghost_lifetime := DASH_GHOST_LIFETIME if dash_blur else GHOST_LIFETIME
	tween.tween_property(ghost_root, "modulate:a", 0.0, ghost_lifetime)
	tween.tween_callback(ghost_root.queue_free)

func is_dashing() -> bool:
	return _dash_timer > 0.0
