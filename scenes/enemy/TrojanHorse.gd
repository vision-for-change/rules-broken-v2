extends CharacterBody2D

@export var move_speed := 120.0
@export var entity_id := "trojan_01"

const BUG_SCENE := preload("res://scenes/enemy/bugs.tscn")
const GHOST_COLOR := Color(0.2, 0.8, 0.4, 0.4)

var _player_ref: CharacterBody2D = null
var _defeated := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemy")
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
	
	EntityRegistry.register(
		entity_id,
		"trojan",
		self,
		["trojan", "mobile"],
		{"integrity_contribution": -0.05}
	)
	
	# No rotation - keep it "straight" as per the sprite
	rotation = 0

func take_damage(_amount: int) -> bool:
	if _defeated:
		return false
	_defeated = true
	_transform_into_bug()
	return false

func _transform_into_bug() -> void:
	var bug = BUG_SCENE.instantiate()
	get_parent().add_child(bug)
	bug.global_position = global_position
	# Ensure the new bug has a unique ID
	bug.set("entity_id", "bug_from_trojan_" + str(Time.get_ticks_msec()))
	
	# Visual effect for transformation
	ScreenFX.flash_screen(Color(0.2, 1.0, 0.5, 0.3), 0.15)
	AudioManager.play_sfx("freesound_community-glass-shatter")
	
	queue_free()

func _physics_process(delta: float) -> void:
	if _defeated: return
	
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		return

	# ALWAYS STRAIGHT: No going right or left
	# Only tracks and moves on the Y axis (Vertical)
	var to_player_y = _player_ref.global_position.y - global_position.y
	
	if abs(to_player_y) > 5.0:
		velocity.y = sign(to_player_y) * move_speed
	else:
		velocity.y = 0
		
	# Force X velocity to zero
	velocity.x = 0
	
	move_and_slide()
	
	# Keep sprite orientation fixed (always straight)
	rotation = 0

func _exit_tree() -> void:
	EntityRegistry.unregister(entity_id)
