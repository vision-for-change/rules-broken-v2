## Watchdog.gd
## AI enforcer that obeys its own rule constraints.
## Critical design: Watchdog submits ALERT actions through ActionBus too.
## Player can create rule states that BLOCK the Watchdog from alerting.
extends CharacterBody2D

@export var patrol_points: Array[Vector2] = []
@export var patrol_speed  := 35.0
@export var chase_speed   := 75.0
@export var view_range    := 60.0
@export var view_angle    := 65.0
@export var entity_id     := "watchdog_01"

enum WatchdogState { PATROL, INVESTIGATE, ENFORCE, RETURN, STUNNED }

var _state          := WatchdogState.PATROL
var _patrol_idx     := 0
var _alert_timer    := 0.0
var _stun_timer     := 0.0
var _home_pos       : Vector2
var _player_ref     : Node = null
var _facing         := Vector2.RIGHT
var _last_seen_pos  := Vector2.ZERO
const ALERT_DUR     = 4.0

@onready var view_cone: Polygon2D  = $ViewCone
@onready var exclaim: Label        = $ExclaimLabel
@onready var body_rect: ColorRect  = $BodyRect

func _ready() -> void:
	_home_pos = global_position
	if patrol_points.is_empty():
		patrol_points = [global_position, global_position + Vector2(64, 0)]

	EntityRegistry.register(entity_id, "watchdog", self,
		["watchdog", "enforcer", "mobile"],
		{"state": "patrol"}
	)

	EventBus.entity_tag_changed.connect(_on_tag_changed)
	get_tree().process_frame.connect(_find_player, CONNECT_ONE_SHOT)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]

func _physics_process(delta: float) -> void:
	match _state:
		WatchdogState.PATROL:     _patrol(delta)
		WatchdogState.INVESTIGATE:_investigate(delta)
		WatchdogState.ENFORCE:    _enforce(delta)
		WatchdogState.RETURN:     _do_return(delta)
		WatchdogState.STUNNED:    _stunned(delta)

	_scan_for_player()
	_update_cone()
	if _facing.x != 0:
		body_rect.scale.x = sign(_facing.x)

func _patrol(_d: float) -> void:
	if patrol_points.is_empty(): return
	var target = patrol_points[_patrol_idx]
	var diff = target - global_position
	if diff.length() < 5.0:
		_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
		return
	_facing = diff.normalized()
	velocity = _facing * patrol_speed
	move_and_slide()

func _investigate(_d: float) -> void:
	var diff = _last_seen_pos - global_position
	if diff.length() < 8.0 or _alert_timer <= 0.0:
		_set_state(WatchdogState.RETURN)
		return
	_facing = diff.normalized()
	velocity = _facing * (patrol_speed * 1.3)
	move_and_slide()

func _enforce(_d: float) -> void:
	if not is_instance_valid(_player_ref):
		_set_state(WatchdogState.RETURN)
		return
	var diff = _player_ref.global_position - global_position
	_facing = diff.normalized()
	velocity = _facing * chase_speed
	move_and_slide()
	if diff.length() < 10.0:
		EventBus.player_caught.emit(entity_id)

func _do_return(_d: float) -> void:
	var diff = _home_pos - global_position
	if diff.length() < 6.0:
		_set_state(WatchdogState.PATROL)
		return
	_facing = diff.normalized()
	velocity = _facing * patrol_speed
	move_and_slide()

func _stunned(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
	move_and_slide()
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_set_state(WatchdogState.RETURN)

func _scan_for_player() -> void:
	if not is_instance_valid(_player_ref): return
	var player_data = _player_ref
	if not player_data.get("is_alive"): return

	var to_player = _player_ref.global_position - global_position
	var dist = to_player.length()

	# Lost track
	if dist > view_range and _state == WatchdogState.ENFORCE:
		_alert_timer = ALERT_DUR
		_last_seen_pos = _player_ref.global_position
		_set_state(WatchdogState.INVESTIGATE)
		return

	if dist > view_range: return

	var angle = rad_to_deg(_facing.angle_to(to_player.normalized()))
	if abs(angle) > view_angle: return

	# Line of sight
	var space = get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.create(global_position, _player_ref.global_position, 1)
	q.exclude = [self]
	var hit = space.intersect_ray(q)
	if hit and hit.collider != _player_ref: return

	# Player is visible — check for rule violations
	_check_violations()

func _check_violations() -> void:
	var player_tags = EntityRegistry.get_tags("player")
	var violation_type = ""

	if RuleManager.is_rule_active("no_running") and "running" in player_tags:
		violation_type = "running"
	if RuleManager.is_rule_active("no_move") and _player_ref.velocity.length() > 5.0:
		violation_type = "movement"

	if violation_type == "":
		return

	# Watchdog must submit its own ALERT action through ActionBus
	# This means rules can BLOCK the watchdog from alerting!
	var result = ActionBus.submit(ActionBus.ALERT,
		EntityRegistry.get_tags(entity_id),
		{
			"actor_id":  entity_id,
			"target_id": "player",
			"violation": violation_type
		}
	)

	if result["allowed"]:
		_trigger_enforce(violation_type)
	else:
		# Watchdog is rule-blocked from alerting — systemic exploit!
		EventBus.log("WATCHDOG [%s] blocked from alerting: %s" % [entity_id, result["reason"]], "exploit")
		ScreenFX.glitch_flash(0.1)

func _trigger_enforce(reason: String) -> void:
	if _state == WatchdogState.ENFORCE:
		return
	EventBus.watchdog_alert.emit(entity_id, "player", reason)
	EventBus.log("WATCHDOG ENFORCE: %s detected violation=%s" % [entity_id, reason], "error")
	ScreenFX.screen_shake(4.0, 0.2)
	exclaim.text = "!"
	exclaim.visible = true
	_set_state(WatchdogState.ENFORCE)

func stun(duration: float = 2.0) -> void:
	_stun_timer = duration
	exclaim.text = "?"
	exclaim.visible = true
	_set_state(WatchdogState.STUNNED)
	body_rect.color = Color(0.4, 0.4, 0.6)

func _set_state(new_state: WatchdogState) -> void:
	var old = WatchdogState.keys()[_state]
	var nw  = WatchdogState.keys()[new_state]
	_state = new_state
	EntityRegistry.set_state(entity_id, nw.to_lower())
	EntityRegistry.set_entity_meta(entity_id, "state", nw.to_lower())
	EventBus.watchdog_state_changed.emit(entity_id, old, nw)

	match new_state:
		WatchdogState.PATROL:
			exclaim.visible = false
			body_rect.color = Color(0.85, 0.3, 0.2)
		WatchdogState.ENFORCE:
			body_rect.color = Color(1.0, 0.1, 0.1)
		WatchdogState.RETURN:
			exclaim.visible = false
			body_rect.color = Color(0.85, 0.3, 0.2)

func _on_tag_changed(eid: String, tag: String, added: bool) -> void:
	# React to system-wide tag changes that might affect this watchdog
	if eid == entity_id and tag == "disabled" and added:
		_set_state(WatchdogState.STUNNED)
		_stun_timer = 999.0

func _update_cone() -> void:
	if not is_instance_valid(view_cone): return
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		var t = float(i) / 12.0
		var a = lerp(-deg_to_rad(view_angle), deg_to_rad(view_angle), t)
		pts.append(_facing.rotated(a) * view_range)
	view_cone.polygon = pts

func _process(delta: float) -> void:
	if _state == WatchdogState.INVESTIGATE:
		_alert_timer -= delta
