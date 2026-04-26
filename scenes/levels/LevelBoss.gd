extends "res://scenes/levels/Level2.gd"

const ROGUE_AI_SCENE := preload("res://scenes/enemy/RogueAI.tscn")
const BOSS_INTERACTABLE_SCRIPT := preload("res://scenes/levels/BossInteractable.gd")
const OVERRIDE_KEYS_PER_PHASE := 2
const SHIELD_DOWN_TIME := 9.0
const BOSS_LOADOUT_BASE: Array[String] = ["pistol", "ump", "ak47", "lightsaber"]
const INTRO_REVEAL_ZOOM := Vector2(0.6, 0.6)
const INTRO_REVEAL_DURATION := 1.0
const INTRO_RETURN_DURATION := 0.8
const INTRO_HOLD_TIME := 0.45

var _welcome_banner: CanvasLayer
var _boss: Node2D
var _rooms_list: Array[Rect2i] = []
var _spawn_room: Rect2i
var _boss_room: Rect2i
var _active_override_keys: Array[Node2D] = []
var _keys_remaining := 0
var _key_cycle_active := false
var _boss_intro_started := false
var _boss_intro_finished := false

func _ready() -> void:
	# Note: _floor_index is static from Level2.gd
	level_number = _floor_index
	PlayerState.record_level_reached(_floor_index)
	level_title_text = "FLOOR %d // CORE ANOMALY" % _floor_index
	
	super._ready()
	_show_welcome_message()

func get_stage_number() -> int:
	return _floor_index

func get_boss_objective_status() -> Dictionary:
	var shielded := true
	if is_instance_valid(_boss) and _boss.has_method("is_shielded"):
		shielded = bool(_boss.call("is_shielded"))
	return {
		"remaining": _keys_remaining,
		"total": OVERRIDE_KEYS_PER_PHASE,
		"shielded": shielded
	}

func _build_wall_material() -> ShaderMaterial:
	var mat = super._build_wall_material()
	mat.set_shader_parameter("code_color", Color(1.0, 0.2, 0.2))
	mat.set_shader_parameter("fall_speed", 4.5 + (float(_floor_index) * 0.5))
	return mat

func _show_welcome_message() -> void:
	_welcome_banner = CanvasLayer.new()
	_welcome_banner.layer = 100
	add_child(_welcome_banner)
	
	var label = Label.new()
	var tier = _floor_index / 5
	label.text = "BOSS TIER %d DETECTED\nSYSTEM INTEGRITY CRITICAL\nCOLLECT OVERRIDE KEYS TO DROP SHIELD" % tier
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	label.add_theme_color_override("outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_welcome_banner.add_child(label)
	
	await get_tree().create_timer(4.0).timeout
	var t = create_tween()
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(_welcome_banner.queue_free)

func _populate_floor(main_room: Rect2i, rooms: Array[Rect2i]) -> void:
	_rooms_list = rooms
	_spawn_room = main_room
	_boss_room = rooms[rooms.size() / 2] if rooms.size() > 1 else main_room
	_active_override_keys.clear()
	_keys_remaining = 0
	_key_cycle_active = false
	_boss_intro_started = false
	_boss_intro_finished = false

	var enemy_root := _get_or_create_container("Enemies")
	var obstacle_root := _get_or_create_container("Obstacles")
	var interactable_root := _get_or_create_container("Interactables")
	_clear_children(enemy_root)
	_clear_children(obstacle_root)
	_clear_children(interactable_root)

	var player := get_node_or_null("Player") as Node2D
	if player != null:
		player.global_position = _cell_to_world(_room_center(main_room))
		_configure_player_for_boss_fight(player)

	_spawn_boss(enemy_root)
	_spawn_boss_intro_trigger(interactable_root)

func _configure_player_for_boss_fight(player: Node2D) -> void:
	if player == null:
		return
	
	# Full health refill for boss
	if player.get("health") != null:
		player.set("health", 100)
		EventBus.player_health_changed.emit(100, 100)
	
	if player.has_node("Inventory"):
		var inventory = player.get_node("Inventory")
		if inventory != null:
			if inventory.has_method("set_max_slots"):
				inventory.call("set_max_slots", 4)
			# Give them AK47 and Lightsaber if they don't have it, or just use what they have
			var current_selected = PlayerState.selected_gun_id
			var loadout: Array[String] = [current_selected, "ump", "ak47", "lightsaber"]
			if inventory.has_method("set_loadout"):
				inventory.call("set_loadout", loadout, current_selected)
	
	var hud_node := get_node_or_null("HUD")
	if is_instance_valid(hud_node):
		if hud_node.has_method("set_boss_encounter_mode"):
			hud_node.call("set_boss_encounter_mode", true)
		
	EventBus.log("BOSS ENCOUNTER // NO HOTBAR // ANALYZING PATTERNS", "error")

func _spawn_boss(parent: Node2D) -> void:
	var boss = ROGUE_AI_SCENE.instantiate()
	if boss == null:
		return
	parent.add_child(boss)
	boss.global_position = _cell_to_world(_room_center(_boss_room))
	_boss = boss

	# Scaling based on level
	var tier_mult := float(_floor_index) / 5.0
	if boss.get("max_health") != null:
		var new_hp = int(420.0 * (1.0 + (tier_mult - 1.0) * 0.8))
		boss.set("max_health", new_hp)
	if boss.get("move_speed") != null:
		var new_speed = 215.0 * (1.0 + (tier_mult - 1.0) * 0.15)
		boss.set("move_speed", new_speed)
	if boss.has_method("set_combat_active"):
		boss.call("set_combat_active", false)

	if boss.has_signal("shield_disabled"):
		boss.connect("shield_disabled", Callable(self, "_on_boss_shield_disabled"))
	if boss.has_signal("shield_restored"):
		boss.connect("shield_restored", Callable(self, "_on_boss_shield_restored"))
	if boss.has_signal("defeated"):
		boss.connect("defeated", Callable(self, "_on_victory"), CONNECT_ONE_SHOT)

	var hud_node := get_node_or_null("HUD")
	if is_instance_valid(hud_node) and hud_node.has_method("bind_boss"):
		hud_node.call("bind_boss", boss, "ROGUE AI // TIER %d" % int(tier_mult))

func _spawn_boss_intro_trigger(parent: Node2D) -> void:
	var trigger := Area2D.new()
	trigger.name = "BossIntroTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.monitoring = true
	parent.add_child(trigger)
	trigger.global_position = _cell_to_world(_room_center(_boss_room))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(_boss_room.size.x) * TILE_SIZE, float(_boss_room.size.y) * TILE_SIZE)
	shape.shape = rect
	trigger.add_child(shape)

	trigger.body_entered.connect(func(body: Node) -> void:
		if _boss_intro_started:
			return
		if not body.is_in_group("player"):
			return
		_boss_intro_started = true
		trigger.monitoring = false
		_play_boss_intro_cutscene(body as Node2D)
	)

func _play_boss_intro_cutscene(player: Node2D) -> void:
	if player == null or not is_instance_valid(_boss):
		_begin_boss_fight()
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		_begin_boss_fight()
		return

	var original_smoothing := camera.position_smoothing_enabled
	var default_zoom := camera.zoom
	var can_restore_player_physics := player.has_method("set_physics_process")
	var focus := (player.global_position + _boss.global_position) * 0.5

	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	if can_restore_player_physics:
		player.set_physics_process(false)

	camera.position_smoothing_enabled = false
	camera.reparent(self, true)

	var reveal_tween := create_tween()
	reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_property(camera, "global_position", focus, INTRO_REVEAL_DURATION)
	reveal_tween.parallel().tween_property(camera, "zoom", INTRO_REVEAL_ZOOM, INTRO_REVEAL_DURATION)
	await reveal_tween.finished
	await get_tree().create_timer(INTRO_HOLD_TIME).timeout

	var return_tween := create_tween()
	return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(camera, "global_position", player.global_position, INTRO_RETURN_DURATION)
	return_tween.parallel().tween_property(camera, "zoom", default_zoom, INTRO_RETURN_DURATION)
	await return_tween.finished

	camera.reparent(player, true)
	camera.position = Vector2.ZERO
	camera.position_smoothing_enabled = original_smoothing
	if can_restore_player_physics:
		player.set_physics_process(true)

	_begin_boss_fight()

func _begin_boss_fight() -> void:
	if _boss_intro_finished:
		return
	_boss_intro_finished = true
	if is_instance_valid(_boss) and _boss.has_method("set_combat_active"):
		_boss.call("set_combat_active", true)
	_start_boss_music()
	var interactable_root := _get_or_create_container("Interactables")
	_start_override_key_phase(interactable_root)
	EventBus.log("ROGUE AI ONLINE // FIGHT BEGIN", "error")

func _start_boss_music() -> void:
	Music.playglobalsound("res://Sounds/Hive - Ultrasonic Sound (The Matrix).mp3")

func _start_override_key_phase(parent: Node2D) -> void:
	if not is_instance_valid(_boss):
		return
	if _boss.has_method("is_shielded") and not bool(_boss.call("is_shielded")):
		return
	_clear_override_keys()
	_key_cycle_active = true
	_keys_remaining = OVERRIDE_KEYS_PER_PHASE

	var candidate_rooms: Array[Rect2i] = []
	for room in _rooms_list:
		if room == _spawn_room:
			continue
		candidate_rooms.append(room)
	if candidate_rooms.is_empty():
		candidate_rooms.append(_boss_room)

	for i in range(OVERRIDE_KEYS_PER_PHASE):
		var room = candidate_rooms[randi() % candidate_rooms.size()]
		var cell = _random_cell_in_room(room, 4)
		var key = _spawn_override_key(cell, parent, i + 1)
		if key != null:
			_active_override_keys.append(key)

	_keys_remaining = _active_override_keys.size()
	EventBus.log("OVERRIDE KEYS SPAWNED // COLLECT %d" % _keys_remaining, "warn")

func _spawn_override_key(cell: Vector2i, parent: Node2D, index: int) -> Node2D:
	var key_obj := StaticBody2D.new()
	key_obj.set_script(BOSS_INTERACTABLE_SCRIPT)
	key_obj.name = "OverrideKey%d" % index
	key_obj.position = _cell_to_world(cell)
	key_obj.collision_layer = 2
	key_obj.collision_mask = 0
	key_obj.set("interact_hint", "Collect Override Key")
	parent.add_child(key_obj)

	var visual := ColorRect.new()
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	visual.color = Color(0.1, 0.95, 1.0)
	key_obj.add_child(visual)

	var core := ColorRect.new()
	core.size = Vector2(10, 10)
	core.position = Vector2(-5, -5)
	core.color = Color(1.0, 1.0, 1.0)
	key_obj.add_child(core)

	var label := Label.new()
	label.text = "[E] OVERRIDE"
	label.offset_top = -32
	label.offset_left = -44
	label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.75, 1.0, 1.0))
	key_obj.add_child(label)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 32.0
	shape.shape = circle
	key_obj.add_child(shape)

	if key_obj.has_signal("interacted"):
		key_obj.connect("interacted", Callable(self, "_on_override_key_collected").bind(key_obj), CONNECT_ONE_SHOT)

	return key_obj

func _on_override_key_collected(key_obj: Node2D) -> void:
	if not is_instance_valid(key_obj):
		return
	if _active_override_keys.has(key_obj):
		_active_override_keys.erase(key_obj)
	_keys_remaining = maxi(0, _active_override_keys.size())
	AudioManager.play_sfx("level_complete")
	EventBus.log("KEY CAPTURED // %d REMAINING" % _keys_remaining, "warn")
	key_obj.queue_free()

	if _keys_remaining > 0:
		return
	_key_cycle_active = false
	if is_instance_valid(_boss) and _boss.has_method("disable_shield"):
		_boss.call("disable_shield", SHIELD_DOWN_TIME)

func _on_boss_shield_disabled(duration: float) -> void:
	_clear_override_keys()
	EventBus.log("SHIELD DOWN // BOSS VULNERABLE", "error")
	ScreenFX.flash_screen(Color(1.0, 0.25, 0.25, 0.2), 0.25)

func _on_boss_shield_restored() -> void:
	if _transitioning:
		return
	if not _boss_intro_finished:
		return
	var interactable_root := _get_or_create_container("Interactables")
	EventBus.log("SHIELD RESTORED // SEARCH FOR KEYS", "warn")
	_start_override_key_phase(interactable_root)

func _clear_override_keys() -> void:
	for key in _active_override_keys:
		if is_instance_valid(key):
			key.queue_free()
	_active_override_keys.clear()
	_keys_remaining = 0

func _on_victory() -> void:
	_clear_override_keys()
	if _transitioning:
		return
	_transitioning = true
	PlayerState.boss_defeated_this_run = true
	PlayerState.endless_unlocked = true
	PlayerState.record_level_reached(_floor_index)
	AudioManager.play_sfx("level_complete")
	
	await _play_exit_transition()
	
	# After boss, go to Win Screen
	ScreenFX.transition_to_scene("res://scenes/ui/WinScreen.tscn")
