extends CharacterBody2D

@export var move_speed := 120.0
@export var entity_id := "snake_01"
@export var max_health := 30
@export var hit_flash_duration := 0.1
@export var hit_flash_color := Color(1.0, 0.3, 0.3, 1.0)
@export var segment_count := 6
@export var segment_spacing := 12.0

const GHOST_COLOR := Color(0.45, 1.0, 0.65, 0.2)
const SHATTER_DURATION := 0.22

var _player_ref: CharacterBody2D = null
var _defeated := false
var _health := 0
var _hit_flash_tween: Tween = null
var _pos_history: Array[Vector2] = []
var _segments: Array[Sprite2D] = []

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
	
	_setup_segments()

func _setup_segments() -> void:
	var tex = load("res://assets/sprites/snake_segment.webp")
	for i in range(segment_count):
		var s = Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * (1.0 - (float(i) / segment_count) * 0.4)
		s.z_index = z_index - 1
		add_child(s)
		_segments.append(s)
		# Initialize history
		for j in range(int(segment_spacing)):
			_pos_history.append(global_position)

func take_damage(amount: int) -> bool:
	if _defeated:
		return false
	_health = maxi(0, _health - amount)
	_update_health_bar()
	_play_hit_flash()
	if _health > 0:
		return false
	shatter()
	return true

func _update_health_bar() -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_health
		health_bar.value = _health
		health_bar.visible = _health > 0

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

func shatter() -> void:
	if _defeated: return
	_defeated = true
	AudioManager.play_sfx("freesound_community-glass-shatter")
	# Simple fade out for segments
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, SHATTER_DURATION)
	for s in _segments:
		t.tween_property(s, "modulate:a", 0.0, SHATTER_DURATION)
	t.set_parallel(false)
	t.tween_callback(queue_free)

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)
