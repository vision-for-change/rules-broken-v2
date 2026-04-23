extends "res://scenes/levels/Level2.gd"

const ROGUE_AI_SCENE := preload("res://scenes/enemy/RogueAI.tscn")

var _welcome_banner: CanvasLayer
var _final_key_spawned := false

func _ready() -> void:
	# LevelBoss is floor 6 essentially
	_floor_index = 6
	level_title_text = "FINAL SECTOR // CORE ACCESS"
	
	# Standard generation but larger
	# We don't override _generate_dungeon, we let it run but we can tweak grid
	super._ready()
	_show_welcome_message()

func _show_welcome_message() -> void:
	_welcome_banner = CanvasLayer.new()
	_welcome_banner.layer = 100
	add_child(_welcome_banner)
	
	var label = Label.new()
	label.text = "WELCOME TO BOSS LEVEL\nFIND THE CORE KEY // SURVIVE THE SWARM"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.add_theme_color_override("outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	_welcome_banner.add_child(label)
	
	await get_tree().create_timer(2.0).timeout
	var t = create_tween()
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(_welcome_banner.queue_free)

# Override populate to handle boss level specifics
func _populate_floor(main_room: Rect2i, rooms: Array[Rect2i]) -> void:
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
	
	# 4. Spawn Final Key in the farthest room
	var far_room = _pick_farthest_room(main_room, rooms)
	_spawn_final_key_interactive(far_room, interactable_root)
	
	# 5. Spawn Weapon Pickup in a nearby room
	if rooms.size() > 2:
		_spawn_weapon_pickup(_room_center(rooms[1]), interactable_root)

func _spawn_weapon_pickup(cell: Vector2i, parent: Node2D) -> void:
	var pickup = Area2D.new()
	pickup.name = "WeaponPickup"
	pickup.add_to_group("boss_level_pickup")
	pickup.position = _cell_to_world(cell)
	pickup.collision_layer = 2 # Correct layer for interaction
	pickup.collision_mask = 0
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
	var key_area := Area2D.new()
	key_area.name = "FinalKey"
	key_area.add_to_group("boss_level_key")
	key_area.position = _cell_to_world(_room_center(room))
	key_area.collision_layer = 2 # Correct layer for interaction
	key_area.collision_mask = 0
	parent.add_child(key_area)
	
	var visual := ColorRect.new()
	visual.size = Vector2(14, 14); visual.position = Vector2(-7, -7)
	visual.color = Color(1, 0.9, 0)
	key_area.add_child(visual)
	
	var label := Label.new()
	label.text = "[E] ACCESS CORE KEY"
	label.offset_top = -30; label.offset_left = -50
	label.add_theme_font_size_override("font_size", 10)
	key_area.add_child(label)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	key_area.add_child(shape)

	# Using Area2D monitoring to check for player
	key_area.area_entered.connect(func(area): if area.get_parent().is_in_group("player"): key_area.set_meta("near", true))
	key_area.area_exited.connect(func(area): if area.get_parent().is_in_group("player"): key_area.set_meta("near", false))

func _input(event: InputEvent) -> void:
	super._input(event)
	
	if event.is_action_pressed("interact"): # Handles E
		for k in get_tree().get_nodes_in_group("boss_level_key"):
			if k.get_meta("near", false):
				_on_victory()
				return
				
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
