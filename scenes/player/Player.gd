## Player.gd
## Player submits ALL actions through ActionBus. Movement, interaction,
## bypass — nothing happens without passing the rule pipeline.
extends CharacterBody2D

const SPEED_MOVE = 100.0
const ACCELERATION = 700.0
const DECELERATION = 900.0
const HACK_SPEED_MULT = 2.4
const ENTITY_ID  = "player"

var is_alive   := true
var _interact_target: Node = null
var _footstep_t := 0.0
var _hack_super_speed := false
var _hack_invincible := false
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

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
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
	var smoothing := ACCELERATION if target_velocity != Vector2.ZERO else DECELERATION
	velocity = velocity.move_toward(target_velocity, smoothing * delta)

	var move_speed := velocity.length()
	move_and_slide()
	_push_colliders(dir, move_speed)

	if dir.x != 0:
		body_rect.scale.x = sign(dir.x)

	# Interact input
	if Input.is_action_just_pressed("interact") and _interact_target != null:
		_do_interact()

func _push_colliders(dir: Vector2, move_speed: float) -> void:
	if dir.length_squared() == 0.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var collider := collision.get_collider()
		if collider != null and collider.has_method("receive_push"):
			collider.receive_push(dir, move_speed)

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

func set_hacked_client_modes(super_speed_enabled: bool, invincible_enabled: bool) -> void:
	_hack_super_speed = super_speed_enabled
	_hack_invincible = invincible_enabled

func get_hacked_client_modes() -> Dictionary:
	return {
		"super_speed": _hack_super_speed,
		"invincible": _hack_invincible
	}
