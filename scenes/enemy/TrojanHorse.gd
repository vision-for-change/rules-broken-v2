extends CharacterBody2D

@export var move_speed := 120.0
@export var entity_id := "trojan_01"

const BUG_SCENE := preload("res://scenes/enemy/bugs.tscn")
const GHOST_COLOR := Color(0.2, 0.8, 0.4, 0.4)
const SHARD_COUNT := 10
const SHATTER_DURATION := 0.25

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
	shatter()
	return false

func shatter() -> void:
	if _defeated: return
	_defeated = true
	
	# Disable logic
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	
	# Play glass shatter sound with a bit of a boom
	AudioManager.play_sfx("freesound_community-glass-shatter")
	AudioManager.play_sfx_with_volume("dragon-studio-cinematic-boom", -10.0)
	
	# Visual effects
	ScreenFX.flash_screen(Color(0.2, 1.0, 0.5, 0.3), 0.15)
	_spawn_shards()
	
	# Spawn the "Hidden" Bug
	var bug = BUG_SCENE.instantiate()
	get_parent().add_child(bug)
	bug.global_position = global_position
	bug.set("entity_id", "bug_from_trojan_" + str(Time.get_ticks_msec()))
	
	# Hide the horse
	visible = false
	
	await get_tree().create_timer(SHATTER_DURATION).timeout
	queue_free()

func _spawn_shards() -> void:
	if not is_instance_valid(sprite) or sprite.texture == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	for i in SHARD_COUNT:
		var shard := Sprite2D.new()
		shard.texture = sprite.texture
		shard.global_position = sprite.global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		shard.global_rotation = randf_range(0.0, TAU)
		shard.scale = sprite.global_scale * randf_range(0.4, 0.7)
		shard.z_index = sprite.z_index + 1
		scene_root.add_child(shard)

		var drift := Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(30.0, 80.0)
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", shard.global_position + drift, SHATTER_DURATION)
		tween.parallel().tween_property(shard, "global_rotation", shard.global_rotation + randf_range(-4.0, 4.0), SHATTER_DURATION)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, SHATTER_DURATION)
		tween.tween_callback(shard.queue_free)

func _physics_process(delta: float) -> void:
	if _defeated: return
	
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D
		return

	# ALWAYS STRAIGHT: No going right or left
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
