extends "res://scenes/levels/Level2.gd"

const ROGUE_AI_SCENE := preload("res://scenes/enemy/RogueAI.tscn")

var _welcome_banner: CanvasLayer
var _final_key_spawned := false
var _rooms_list: Array[Rect2i] = []
var _spawn_room: Rect2i
var _erosion_timer := 0.0
var _hallucination_timer := 0.0

func _ready() -> void:
	# LevelBoss is floor 6
	_floor_index = 6
	level_title_text = "FINAL SECTOR // CORE COLLAPSE"
	
	super._ready()
	_show_welcome_message()

func _process(delta: float) -> void:
	if not _final_key_spawned and PlayerState.current_health < 20:
		_spawn_random_final_key()
	
	# System Erosion: Slowly drain health to force the key trigger eventually
	_erosion_timer += delta
	if _erosion_timer >= 4.0: # Every 4 seconds
		_erosion_timer = 0.0
		PlayerState.current_health = max(1, PlayerState.current_health - 1)
		if randf() > 0.7:
			EventBus.log("!! SYSTEM EROSION DETECTED // INTEGRITY REDUCED !!", "error")
			ScreenFX.flash_screen(Color(1, 0, 0, 0.1), 0.1)

	# Hallucinations: Spawn fake keys to confuse the player
	_hallucination_timer += delta
	if _hallucination_timer >= 12.0:
		_hallucination_timer = 0.0
		_spawn_hallucination()

func _spawn_hallucination() -> void:
	if _rooms_list.is_empty(): return
	var room = _rooms_list[randi() % _rooms_list.size()]
	if room == _spawn_room: return
	
	var fake_key = Node2D.new()
	fake_key.position = _cell_to_world(_room_center(room))
	add_child(fake_key)
	
	var visual = ColorRect.new()
	visual.size = Vector2(14, 14); visual.position = Vector2(-7, -7)
	visual.color = Color(1, 0.9, 0)
	fake_key.add_child(visual)
	
	var label = Label.new()
	label.text = "[E] ACCESS CORE KEY"
	label.offset_top = -30; label.offset_left = -50
	label.add_theme_font_size_override("font_size", 10)
	fake_key.add_child(label)
	
	# After 8 seconds, it glitches away
	var t = create_tween()
	t.tween_interval(8.0)
	t.tween_property(fake_key, "modulate", Color(1, 0, 0, 0), 0.5)
	t.tween_callback(fake_key.queue_free)

func _build_wall_material() -> ShaderMaterial:
	var mat = super._build_wall_material()
	# Standard level material but we tweak parameters for boss
	mat.set_shader_parameter("code_color", Color(1.0, 0.2, 0.2)) # Red walls
	mat.set_shader_parameter("fall_speed", 4.5) # Fast movement
	return mat

func _show_welcome_message() -> void:
	_welcome_banner = CanvasLayer.new()
	_welcome_banner.layer = 100
	add_child(_welcome_banner)
	
	var label = Label.new()
	label.text = "WELCOME TO BOSS LEVEL\n// WARNING: CORE INSTABILITY //\nNO HACKS // SURVIVE THE SWARM"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	label.add_theme_color_override("outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_welcome_banner.add_child(label)
	
	await get_tree().create_timer(3.0).timeout
	var t = create_tween()
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(_welcome_banner.queue_free)

# Override populate to handle boss level specifics
func _populate_floor(main_room: Rect2i, rooms: Array[Rect2i]) -> void:
	_rooms_list = rooms
	_spawn_room = main_room

	# 1. Clear standard enemies/objects
	var enemy_root := _get_or_create_container("Enemies")
	var obstacle_root := _get_or_create_container("Obstacles")
	var interactable_root := _get_or_create_container("Interactables")
	_clear_children(enemy_root)
	_clear_children(obstacle_root)
	_clear_children(interactable_root)

	# 2. Spawn Player in main room center
	var player := get_node_or_null("Player") as Node2D
	if player != null:
		player.global_position = _cell_to_world(_room_center(main_room))

	# 3. Spawn Master AI at the center of a different room
	var boss_room = rooms[rooms.size() / 2] if rooms.size() > 1 else main_room
	var boss = ROGUE_AI_SCENE.instantiate()
	enemy_root.add_child(boss)
	boss.global_position = _cell_to_world(_room_center(boss_room))
	
	# 4. Final Key is now spawned via _process when health < 20
	
	# 5. Spawn Weapon Pickup in a nearby room
	if rooms.size() > 2:
		_spawn_weapon_pickup(_room_center(rooms[1]), interactable_root)

func _spawn_random_final_key() -> void:
	if _rooms_list.is_empty(): return
	_final_key_spawned = true
	
	# Pick a random room that isn't the spawn room
	var possible_rooms = _rooms_list.duplicate()
	for i in range(possible_rooms.size() - 1, -1, -1):
		if possible_rooms[i] == _spawn_room:
			possible_rooms.remove_at(i)
	
	var target_room = _spawn_room
	if not possible_rooms.is_empty():
		target_room = possible_rooms[randi() % possible_rooms.size()]
	
	var interactable_root = _get_or_create_container("Interactables")
	_spawn_final_key_interactive(target_room, interactable_root)
	
	EventBus.log("!! EMERGENCY OVERRIDE // CORE KEY MANIFESTED !!", "error")
	ScreenFX.flash_screen(Color(1, 0.8, 0, 0.3), 0.5)
	AudioManager.play_sfx("lockdown")

func _spawn_weapon_pickup(cell: Vector2i, parent: Node2D) -> void:
	var pickup = Area2D.new()
	pickup.name = "WeaponPickup"
	pickup.add_to_group("boss_level_pickup")
	pickup.position = _cell_to_world(cell)
	pickup.collision_layer = 0
	pickup.collision_mask = 1 
	parent.add_child(pickup)
	
	var visual = ColorRect.new()
	visual.size = Vector2(16, 10); visual.position = Vector2(-8, -5)
	visual.color = Color(0.2, 0.8, 1.0)
	pickup.add_child(visual)
	
	var lbl = Label.new()
	lbl.text = "[G] EQUIP AK-47"
	lbl.offset_top = -25; lbl.offset_left = -40
	lbl.add_theme_font_size_override("font_size", 8)
	pickup.add_child(lbl)
	
	pickup.body_entered.connect(func(body): if body.is_in_group("player"): pickup.set_meta("player_near", true))
	pickup.body_exited.connect(func(body): if body.is_in_group("player"): pickup.set_meta("player_near", false))

func _spawn_final_key_interactive(room: Rect2i, parent: Node2D) -> void:
	var key_script = load("res://scenes/levels/BossInteractable.gd")
	var key_obj := StaticBody2D.new()
	key_obj.set_script(key_script)
	key_obj.name = "FinalKey"
	key_obj.position = _cell_to_world(_room_center(room))
	key_obj.collision_layer = 2 
	key_obj.collision_mask = 0
	key_obj.set("interact_hint", "Access Core Key")
	parent.add_child(key_obj)
	
	if key_obj.has_signal("interacted"):
		key_obj.connect("interacted", Callable(self, "_on_victory"))
	
	var visual := ColorRect.new()
	visual.size = Vector2(14, 14); visual.position = Vector2(-7, -7)
	visual.color = Color(1, 0.9, 0)
	key_obj.add_child(visual)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	key_obj.add_child(shape)

func _input(event: InputEvent) -> void:
	super._input(event)
	
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_G:
		for p in get_tree().get_nodes_in_group("boss_level_pickup"):
			if p.get_meta("player_near", false):
				_equip_weapon("ak47")
				p.queue_free()
				break

func _equip_weapon(id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_load_selected_gun"):
		PlayerState.selected_gun_id = id
		player.call("_load_selected_gun")
	AudioManager.play_sfx("universfield-gunshot")

func _on_victory() -> void:
	if _transitioning: return
	_transitioning = true
	AudioManager.play_sfx("level_complete")
	ScreenFX.transition_to_scene("res://scenes/ui/WinScreen.tscn")
