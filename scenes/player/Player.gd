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
const GHOST_INTERVAL := 0.045
const DASH_GHOST_INTERVAL := 0.015
const GHOST_LIFETIME := 0.16
const DASH_GHOST_LIFETIME := 0.22
const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.32)
const DASH_GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.5)
const SHATTER_ROWS := 4
const SHATTER_COLS := 4
const SHATTER_DURATION := 2.2
const SHATTER_FORCE := 120.0
const SHOOT_SHAKE_INTENSITY := 1.2
const SHOOT_SHAKE_DURATION := 0.06
const DASH_SHAKE_INTENSITY := 3.2
const DASH_SHAKE_DURATION := 0.1
const FOOTSTEP_INT = 0.38
const DEATH_SHAKE_INTENSITY := 22.0
const DEATH_SHAKE_DURATION := 0.45
const DEATH_TRANSITION_DELAY := 7.0
const DEATH_DIGIT_COUNT := 460
const DEATH_EXPLOSION_COUNT := 220
const DEATH_DIGIT_EFFECT_TIME := 1.35
const DEATH_BURST_FLASH_TIME := 0.55
const DEATH_SHAKE_PULSE_INTERVAL := 0.18
const DEATH_ZOOM_IN_MULT := 1.75
const DEATH_ZOOM_OUT_MULT := 0.75
const DEATH_ZOOM_OUT_TIME := 1.35

var is_alive := true
var _death_anim_active := false
var _interact_target: Node = null
var _footstep_t := 0.0
var _hack_super_speed := false
var _hack_faster_bullets := false
var _hack_super_vision := false
var _hack_slow_time := false
var _hack_noclip := false
var _hack_unlimited_bullets := false
var _ghost_timer := 0.0
var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_direction := Vector2.ZERO
var _death_zoom_tween: Tween
var _default_collision_layer := 1
var _default_collision_mask := 3
var damage := 10
var max_ammo := 12
var fire_rate := 0.3


@onready var body_rect: ColorRect  = $BodyRect
@onready var interact_area: Area2D = $InteractArea
@onready var camera: Camera2D      = $Camera2D
@onready var hint_label: Label     = $HintLabel
@onready var inventory: Node = $Inventory
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
	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask
	_apply_noclip_mode()
	AudioManager.play_music("stable")
	_apply_camera_modes()

func _physics_process(delta: float) -> void:
	if not is_alive:
		if _death_anim_active:
			_update_facing_to_mouse()
			if Input.is_action_pressed("shoot"):
				_shoot()
		return
	_update_facing_to_mouse()
	_dash_cd = max(0.0, _dash_cd - delta)
	_dash_timer = max(0.0, _dash_timer - delta)

	# Try move_* first (physical), then fallback to ui_*
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length_squared() < 0.01:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and dir.length() > 0.05:
		_dash_direction = dir.normalized()
		_dash_timer = DASH_DURATION
		_dash_cd = DASH_COOLDOWN
		ScreenFX.screen_shake(DASH_SHAKE_INTENSITY, DASH_SHAKE_DURATION)
		AudioManager.play_sfx("whoosh")
	elif _dash_timer <= 0.0:
		_dash_direction = Vector2.ZERO

	var move_dir: Vector2 = dir
	if _dash_timer > 0.0 and _dash_direction.length() > 0.05:
		move_dir = _dash_direction

	var target_velocity: Vector2 = Vector2.ZERO
	if move_dir.length() > 0.05:
		var ctx = {"actor_id": ENTITY_ID, "direction": move_dir}
		var result: Dictionary = ActionBus.submit(ActionBus.MOVE, EntityRegistry.get_tags(ENTITY_ID), ctx)
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
	
	if _hack_noclip:
		_clamp_position_to_bounds()
	
	if _dash_timer > 0.0 and _hack_super_speed:
		print("DEBUG: _physics_process calling _check_dash_collision: dash_timer=%.2f, super_speed=%s" % [_dash_timer, _hack_super_speed])
		_check_dash_collision()

	if velocity.length_squared() > 16.0:
		_ghost_step(delta)
	if Input.is_action_just_pressed("interact") and _interact_target != null:
		_do_interact()
	var current_gun: Dictionary = {}
	if inventory != null and inventory.has_method("get_current_gun"):
		current_gun = inventory.get_current_gun()
	var wants_to_shoot: bool = false
	if not current_gun.is_empty():
		wants_to_shoot = Input.is_action_pressed("shoot") if current_gun.get("auto_fire", false) else Input.is_action_just_pressed("shoot")
	if wants_to_shoot:
		_shoot()

func _update_facing_to_mouse() -> void:
	var aim_dir: Vector2 = get_global_mouse_position() - global_position
	if aim_dir.length_squared() < 0.001:
		return
	rotation = aim_dir.angle()
	hint_label.rotation = -rotation

func _shoot() -> void:
	if inventory == null or not inventory.has_method("request_shot"):
		return

	var gun: Dictionary = inventory.request_shot()
	if gun.is_empty():
		return

	var muzzle_pos: Vector2 = gun_sprite.global_position if is_instance_valid(gun_sprite) else global_position
	var shot_dir: Vector2 = get_global_mouse_position() - muzzle_pos
	if shot_dir.length_squared() == 0.0:
		shot_dir = Vector2.RIGHT
	var bullet: Node = BULLET_SCENE.instantiate()
	if bullet == null:
		return
	if get_tree().current_scene == null:
		return
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle_pos
	var bullet_speed_mult: float = float(gun.get("bullet_speed", 520.0)) / 520.0
	if _hack_faster_bullets:
		bullet_speed_mult *= HACK_BULLET_SPEED_MULT
	if bullet.has_method("setup"):
		bullet.setup(self, shot_dir.normalized(), bullet_speed_mult)
	AudioManager.play_sfx("universfield-gunshot")
	ScreenFX.screen_shake(SHOOT_SHAKE_INTENSITY, SHOOT_SHAKE_DURATION)

func _do_interact() -> void:
	if _interact_target == null or not is_instance_valid(_interact_target):
		return
	var target_id: String = str(_interact_target.get("entity_id")) if _interact_target.get("entity_id") != null else "unknown"
	var ctx = {
		"actor_id": ENTITY_ID,
		"target_id": target_id,
		"target_node": _interact_target
	}
	var result: Dictionary = ActionBus.submit(ActionBus.INTERACT, EntityRegistry.get_tags(ENTITY_ID), ctx)
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
	ScreenFX.clear_time_scale_override()
	is_alive = false
	_death_anim_active = true
	velocity = Vector2.ZERO
	ScreenFX.screen_shake(DEATH_SHAKE_INTENSITY, DEATH_SHAKE_DURATION)
	ScreenFX.flash_screen(Color(1, 0.0, 0.1, 0.8), 0.9)
	AudioManager.play_sfx("dragon-studio-cinematic-boom")
	_start_death_zoom_in()
	_shatter_visible_enemies()
	_spawn_death_binary_cataclysm()
	_pause_non_animation_elements()
	ScreenFX.flash_screen(Color(0.2, 1.0, 0.45, 0.55), DEATH_BURST_FLASH_TIME)
	var pulse_count: int = int(ceil(DEATH_TRANSITION_DELAY / DEATH_SHAKE_PULSE_INTERVAL))
	for i in range(pulse_count):
		var shake_delay: float = DEATH_SHAKE_PULSE_INTERVAL * float(i)
		var progress: float = float(i) / maxf(1.0, float(pulse_count - 1))
		var shake_strength: float = lerpf(DEATH_SHAKE_INTENSITY, DEATH_SHAKE_INTENSITY * 0.55, progress)
		var shake_timer: SceneTreeTimer = get_tree().create_timer(shake_delay, false)
		shake_timer.timeout.connect(func(): ScreenFX.screen_shake(shake_strength, DEATH_SHAKE_DURATION))
	var shatter_delay: float = maxf(0.05, DEATH_TRANSITION_DELAY - SHATTER_DURATION - 0.1)
	var shatter_timer: SceneTreeTimer = get_tree().create_timer(shatter_delay, false)
	shatter_timer.timeout.connect(_play_shatter_effect)
	var transition_timer: SceneTreeTimer = get_tree().create_timer(DEATH_TRANSITION_DELAY, false)
	transition_timer.timeout.connect(func(): ScreenFX.transition_to_scene("res://scenes/ui/GameOver.tscn"))

func _shatter_visible_enemies() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if not _is_world_point_visible(enemy_node.global_position):
			continue
		if enemy_node.has_method("shatter"):
			enemy_node.call("shatter")
		elif enemy_node.has_method("take_damage"):
			enemy_node.call("take_damage", 9999)
		else:
			enemy_node.queue_free()

func _pause_non_animation_elements() -> void:
	var level_root: Node = get_tree().current_scene
	if level_root == null:
		return
	if level_root.has_node("HUD"):
		var hud_node: Node = level_root.get_node("HUD")
		if hud_node is Node:
			(hud_node as Node).process_mode = Node.PROCESS_MODE_DISABLED

	for group_name in ["enemy", "enemy_projectile"]:
		var members: Array = get_tree().get_nodes_in_group(group_name)
		for member in members:
			if not (member is Node):
				continue
			var n: Node = member as Node
			if n == self:
				continue
			n.process_mode = Node.PROCESS_MODE_DISABLED

	if RuleManager is Node and is_instance_valid(RuleManager):
		RuleManager.process_mode = Node.PROCESS_MODE_DISABLED

func _is_world_point_visible(world_point: Vector2) -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var visible_rect: Rect2 = viewport.get_visible_rect()
	var screen_point: Vector2 = viewport.get_canvas_transform() * world_point
	return visible_rect.has_point(screen_point)

func _spawn_death_binary_cataclysm() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 320
	scene_root.add_child(layer)
	var bounds: Vector2 = viewport.get_visible_rect().size

	for i in range(DEATH_DIGIT_COUNT):
		var digit: Label = Label.new()
		digit.text = "1" if randi() % 2 == 0 else "O"
		digit.position = Vector2(randf_range(0.0, bounds.x), randf_range(0.0, bounds.y))
		digit.rotation = randf_range(-0.4, 0.4)
		digit.modulate.a = 0.0
		digit.add_theme_font_size_override("font_size", randi_range(12, 30))
		digit.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 0.95))
		digit.add_theme_color_override("outline_color", Color(0.0, 0.18, 0.07, 0.95))
		digit.add_theme_constant_override("outline_size", 1)
		layer.add_child(digit)
		var digit_tween: Tween = digit.create_tween()
		digit_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var start_delay: float = randf_range(0.0, maxf(0.0, DEATH_TRANSITION_DELAY - (DEATH_DIGIT_EFFECT_TIME + 0.35)))
		var drift: Vector2 = Vector2(randf_range(-180.0, 180.0), randf_range(-220.0, 220.0))
		digit_tween.tween_interval(start_delay)
		digit_tween.tween_property(digit, "modulate:a", 1.0, 0.05)
		digit_tween.parallel().tween_property(digit, "position", digit.position + drift, DEATH_DIGIT_EFFECT_TIME)
		digit_tween.parallel().tween_property(digit, "rotation", digit.rotation + randf_range(-2.2, 2.2), DEATH_DIGIT_EFFECT_TIME)
		digit_tween.tween_property(digit, "modulate:a", 0.0, 0.35)
		digit_tween.tween_callback(digit.queue_free)

	for i in range(DEATH_EXPLOSION_COUNT):
		var blast: ColorRect = ColorRect.new()
		blast.color = Color(0.1, 1.0, 0.35, randf_range(0.25, 0.5))
		blast.size = Vector2.ONE * randf_range(10.0, 24.0)
		blast.position = Vector2(randf_range(0.0, bounds.x), randf_range(0.0, bounds.y)) - blast.size * 0.5
		blast.pivot_offset = blast.size * 0.5
		blast.modulate.a = 0.0
		layer.add_child(blast)
		var blast_tween: Tween = blast.create_tween()
		blast_tween.tween_interval(randf_range(0.0, maxf(0.0, DEATH_TRANSITION_DELAY - 0.45)))
		blast_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		blast_tween.tween_property(blast, "modulate:a", randf_range(0.35, 0.65), 0.08)
		blast_tween.tween_property(blast, "scale", Vector2(randf_range(4.0, 10.0), randf_range(4.0, 10.0)), 0.35)
		blast_tween.parallel().tween_property(blast, "modulate:a", 0.0, 0.35)
		blast_tween.tween_callback(blast.queue_free)

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(DEATH_TRANSITION_DELAY + 0.25, false)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)

func _play_shatter_effect() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_start_death_zoom_out()
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
	var texture_size: Vector2 = source_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var piece_size: Vector2 = texture_size / Vector2(float(cols), float(rows))
	for y in rows:
		for x in cols:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = source_sprite.texture
			atlas.region = Rect2(Vector2(x, y) * piece_size, piece_size)
			var shard: Sprite2D = Sprite2D.new()
			shard.texture = atlas
			shard.centered = true
			shard.scale = source_sprite.global_scale
			shard.global_rotation = source_sprite.global_rotation
			shard.modulate = source_sprite.modulate
			var cell_center: Vector2 = (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) * piece_size
			var offset: Vector2 = cell_center - texture_size * 0.5
			var rotated_offset: Vector2 = (offset * source_sprite.global_scale).rotated(source_sprite.global_rotation)
			shard.global_position = source_sprite.global_position + rotated_offset
			var outward_dir: Vector2 = offset.normalized()
			if outward_dir.length_squared() < 0.001:
				outward_dir = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
			var random_spread: Vector2 = Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
			var travel: Vector2 = (outward_dir + random_spread).normalized() * randf_range(force * 0.55, force)
			var target_pos: Vector2 = shard.global_position + travel
			var target_rot: float = shard.rotation + randf_range(-2.6, 2.6)
			get_tree().current_scene.add_child(shard)
			var tween: Tween = shard.create_tween()
			tween.set_parallel(true)
			tween.tween_property(shard, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "rotation", target_rot, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(shard, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.set_parallel(false)
			tween.tween_callback(shard.queue_free)

func _start_death_zoom_in() -> void:
	if camera == null:
		return
	if is_instance_valid(_death_zoom_tween):
		_death_zoom_tween.kill()
	var target: Vector2 = camera.zoom * DEATH_ZOOM_IN_MULT
	target.x = minf(4.0, target.x)
	target.y = minf(4.0, target.y)
	var zoom_in_time: float = maxf(0.2, DEATH_TRANSITION_DELAY - SHATTER_DURATION - 0.1)
	_death_zoom_tween = create_tween()
	_death_zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_death_zoom_tween.tween_property(camera, "zoom", target, zoom_in_time)

func _start_death_zoom_out() -> void:
	if camera == null:
		return
	if is_instance_valid(_death_zoom_tween):
		_death_zoom_tween.kill()
	var target: Vector2 = DEFAULT_CAMERA_ZOOM * DEATH_ZOOM_OUT_MULT
	target.x = maxf(0.35, target.x)
	target.y = maxf(0.35, target.y)
	_death_zoom_tween = create_tween()
	_death_zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_death_zoom_tween.tween_property(camera, "zoom", target, DEATH_ZOOM_OUT_TIME)

func _load_selected_gun() -> void:
	var gid: String = PlayerState.selected_gun_id
	var gun: Dictionary = GunDatabase.GUNS.get(gid, {})
	if gun.is_empty():
		return

	# Set gun sprite
	if gun.has("sprite") and ResourceLoader.exists(gun["sprite"]):
		gun_sprite.texture = load(gun["sprite"])

		# ⭐ AUTO-SCALE GUN TO A GOOD SIZE
		if gun_sprite.texture:
			var tex_size: Vector2 = gun_sprite.texture.get_size()
			var target_height: float = 20.0
			var scale_factor: float = target_height / tex_size.y
			gun_sprite.scale = Vector2(scale_factor, scale_factor)

	# Apply stats if they exist
	if gun.has("damage"):
		damage = int(gun["damage"])
	if gun.has("max_ammo"):
		max_ammo = int(gun["max_ammo"])
	if gun.has("fire_rate"):
		fire_rate = float(gun["fire_rate"])



func set_hacked_client_modes(
	super_speed_enabled: bool,
	faster_bullets_enabled: bool = false,
	super_vision_enabled: bool = false,
	slow_time_enabled: bool = false,
	noclip_enabled: bool = false,
	unlimited_bullets_enabled: bool = false
) -> void:
	_hack_super_speed = super_speed_enabled
	_hack_faster_bullets = faster_bullets_enabled
	_hack_super_vision = super_vision_enabled
	_hack_slow_time = slow_time_enabled
	_hack_noclip = noclip_enabled
	_hack_unlimited_bullets = unlimited_bullets_enabled
	_apply_noclip_mode()
	_apply_camera_modes()

func get_hacked_client_modes() -> Dictionary:
	return {
		"super_speed": _hack_super_speed,
		"faster_bullets": _hack_faster_bullets,
		"super_vision": _hack_super_vision,
		"slow_time": _hack_slow_time,
		"noclip": _hack_noclip,
		"unlimited_bullets": _hack_unlimited_bullets
	}

func _apply_noclip_mode() -> void:
	if _hack_noclip:
		collision_layer = 0
		collision_mask = 0
		return
	collision_layer = _default_collision_layer
	collision_mask = _default_collision_mask

func _clamp_position_to_bounds() -> void:
	var level = get_tree().current_scene
	if level == null:
		return
	
	var bounds: Rect2 = Rect2()
	if level.has_method("get_world_size"):
		bounds = Rect2(Vector2.ZERO, level.get_world_size())
	else:
		return
	
	var player_size := 16.0
	global_position.x = clampf(global_position.x, bounds.position.x + player_size, bounds.position.x + bounds.size.x - player_size)
	global_position.y = clampf(global_position.y, bounds.position.y + player_size, bounds.position.y + bounds.size.y - player_size)

func _apply_camera_modes() -> void:
	if camera == null:
		return
	camera.zoom = SUPER_VISION_CAMERA_ZOOM if _hack_super_vision else DEFAULT_CAMERA_ZOOM

func _ghost_step(delta: float) -> void:
	var dash_blur: bool = is_dashing()
	var ghost_interval: float = DASH_GHOST_INTERVAL if dash_blur else GHOST_INTERVAL
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = ghost_interval
	_spawn_player_ghost(dash_blur)

func _spawn_player_ghost(dash_blur: bool = false) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var ghost_root: Node2D = Node2D.new()
	ghost_root.global_position = global_position
	ghost_root.global_rotation = global_rotation
	ghost_root.scale = scale
	ghost_root.z_index = z_index - 1
	ghost_root.modulate = DASH_GHOST_COLOR if dash_blur else GHOST_COLOR
	scene_root.add_child(ghost_root)
	if is_instance_valid(body_rect):
		var body_ghost: Node = body_rect.duplicate()
		if body_ghost is Control:
			(body_ghost as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost_root.add_child(body_ghost)
	if is_instance_valid(gun_sprite):
		ghost_root.add_child(gun_sprite.duplicate())
	var tween: Tween = ghost_root.create_tween()
	var ghost_lifetime: float = DASH_GHOST_LIFETIME if dash_blur else GHOST_LIFETIME
	tween.tween_property(ghost_root, "modulate:a", 0.0, ghost_lifetime)
	tween.tween_callback(ghost_root.queue_free)

func is_dashing() -> bool:
	return _dash_timer > 0.0

func _check_dash_collision() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	print("DEBUG: _check_dash_collision called, found %d enemies" % enemies.size())
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		print("DEBUG: Enemy found: %s" % enemy.name)
		if not enemy.has_method("check_dash_collision"):
			continue
		var distance = global_position.distance_to((enemy as Node2D).global_position)
		print("DEBUG: Enemy distance: %.2f" % distance)
		if distance < 50.0:
			print("DEBUG: Enemy in range! Calling check_dash_collision")
			enemy.call("check_dash_collision", self)
