## Player.gd
## Player submits ALL actions through ActionBus. Movement, interaction,
## bypass — nothing happens without passing the rule pipeline.
extends CharacterBody2D

const SPEED_MOVE = 150.0
const HACK_SPEED_MULT = 2.4
const HACK_BULLET_SPEED_MULT = 2.2
const DEFAULT_CAMERA_ZOOM := Vector2(1.5, 1.5)
const SUPER_VISION_CAMERA_ZOOM := Vector2(1.0, 1.0)
const ENTITY_ID  = "player"
const BULLET_SCENE = preload("res://scenes/player/Bullet.tscn")
const SHOOT_COOLDOWN := 0.12

var is_alive   := true
var _interact_target: Node = null
var _footstep_t := 0.0
var _hack_super_speed := false
var _hack_invincible := false
var _hack_faster_bullets := false
var _hack_super_vision := false
var _shoot_cd := 0.0
const FOOTSTEP_INT = 0.38

@onready var body_rect: ColorRect      = $BodyRect
@onready var interact_area: Area2D     = $InteractArea
@onready var camera: Camera2D          = $Camera2D
@onready var hint_label: Label         = $HintLabel

func _ready() -> void:
	add_to_group("player")
	ScreenFX.register_camera(camera)

	EntityRegistry.register(ENTITY_ID, "player",  self,
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
	_shoot_cd = max(0.0, _shoot_cd - delta)

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var target_velocity := Vector2.ZERO

	# MOVE action goes through ActionBus
	if dir.length() > 0.05:
		var ctx = {
			"actor_id":  ENTITY_ID,
			"direction": dir
		}
		var result = ActionBus.submit(ActionBus.MOVE,
			EntityRegistry.get_tags(ENTITY_ID), ctx)

		if result["allowed"]:
			target_velocity = dir * SPEED_MOVE
		else:
			# Blocked: dampen to slow walk
			target_velocity = dir * (SPEED_MOVE * 0.4)
		if _hack_super_speed:
			target_velocity *= HACK_SPEED_MULT

		# Footstep audio
		_footstep_t += delta
		if _footstep_t >= FOOTSTEP_INT:
			_footstep_t = 0.0
			AudioManager.play_sfx("footstep")
	velocity = target_velocity

	move_and_slide()

	# Interact input
	if Input.is_action_just_pressed("interact") and _interact_target != null:
		_do_interact()
	if Input.is_action_just_pressed("shoot"):
		_shoot()

func _shoot() -> void:
	if _shoot_cd > 0.0:
		return
	var shot_dir := get_global_mouse_position() - global_position
	if shot_dir.length_squared() == 0.0:
		shot_dir = Vector2.RIGHT
	var bullet = BULLET_SCENE.instantiate()
	if bullet == null:
		return
	if get_tree().current_scene == null:
		return
	var spawn_pos := global_position + shot_dir.normalized() * 12.0
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos
	var bullet_speed_mult := HACK_BULLET_SPEED_MULT if _hack_faster_bullets else 1.0
	if bullet.has_method("setup"):
		bullet.setup(self, shot_dir.normalized(), bullet_speed_mult)
	_shoot_cd = SHOOT_COOLDOWN

func _do_interact() -> void:
	if _interact_target == null or not is_instance_valid(_interact_target):
		return
	var target_id = _interact_target.get("entity_id") if _interact_target.get("entity_id") != null else "unknown"
	var ctx = {
		"actor_id":  ENTITY_ID,
		"target_id": target_id,
		"target_node": _interact_target
	}
	var result = ActionBus.submit(ActionBus.INTERACT,
		EntityRegistry.get_tags(ENTITY_ID), ctx)
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
	if _hack_invincible:
		ScreenFX.flash_screen(Color(0.2, 1.0, 1.0, 0.25), 0.1)
		EventBus.log("HACK CLIENT: INVINCIBILITY prevented capture", "exploit")
		return
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	ScreenFX.screen_shake(14.0, 0.6)
	ScreenFX.flash_screen(Color(1, 0.0, 0.1, 0.7), 0.5)
	AudioManager.play_sfx("caught")
	var t = create_tween()
	t.tween_property(body_rect, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")

func set_hacked_client_modes(
	super_speed_enabled: bool,
	invincible_enabled: bool,
	faster_bullets_enabled: bool = false,
	super_vision_enabled: bool = false
) -> void:
	_hack_super_speed = super_speed_enabled
	_hack_invincible = invincible_enabled
	_hack_faster_bullets = faster_bullets_enabled
	_hack_super_vision = super_vision_enabled
	_apply_camera_modes()

func get_hacked_client_modes() -> Dictionary:
	return {
		"super_speed": _hack_super_speed,
		"invincible": _hack_invincible,
		"faster_bullets": _hack_faster_bullets,
		"super_vision": _hack_super_vision
	}

func _apply_camera_modes() -> void:
	if camera == null:
		return
	camera.zoom = SUPER_VISION_CAMERA_ZOOM if _hack_super_vision else DEFAULT_CAMERA_ZOOM
