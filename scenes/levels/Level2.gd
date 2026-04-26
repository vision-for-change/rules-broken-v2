extends "res://scenes/levels/BaseLevel.gd"

const GRID_W := 360
const GRID_H := 336
const TILE_SIZE := 8.0
const TARGET_ROOM_COUNT := 34
const ROOM_ATTEMPTS := 520
const EXTRA_HALLWAYS := 28
const HALLWAY_WIDTH := 12
const BUG_SCENE := preload("res://scenes/enemy/bugs.tscn")
const SNAKE_SCENE := preload("res://scenes/enemy/Snake.tscn")
const TROJAN_SCENE := preload("res://scenes/enemy/TrojanHorse.tscn")
const CHATGPT_BOSS_SCENE := preload("res://scenes/enemy/chatgpt.tscn")
const FLOOR_DOOR_SCRIPT := preload("res://scenes/levels/FloorDoor.gd")
const MIN_BUGS_PER_ROOM := 2
const MAX_BUGS_PER_ROOM := 4
const MIN_OBSTACLES_PER_ROOM := 2
const MAX_OBSTACLES_PER_ROOM := 5
const OUTER_WALL_THICKNESS_TILES := 100
const OUTER_WALL_COLLISION_LAYER := 8
const EXIT_KILL_REQUIREMENTS := {
	1: 10,
	2: 15,
	3: 20,
	4: 25
}
const ENDLESS_BASE_KILL_REQUIREMENT := 30
const ENDLESS_KILL_INCREMENT := 5

var _rng := RandomNumberGenerator.new()
var _wall_material: ShaderMaterial
var _minimap_texture: Texture2D
var _transitioning := false
var _bug_spawn_index := 0
var _floor_five_cutscene_played := false
var _floor_five_boss: Node2D
var _camera_at_player: Camera2D
var _player_for_death_cam: Node2D
var _door_room: Rect2i
var _interactable_root_ref: Node2D
var _exit_spawned := false
var _current_kill_requirement := 0

static var _floor_index := 1
static var _advance_requested := false
static var _queued_start_floor := 1

static func queue_start_floor(floor_number: int) -> void:
	_queued_start_floor = maxi(1, floor_number)
	_advance_requested = false
	_floor_index = _queued_start_floor

static func reset_start_floor() -> void:
	_queued_start_floor = 1
	_advance_requested = false
	_floor_index = 1

func get_stage_number() -> int:
	return _floor_index

func get_enemy_kill_requirement() -> int:
	if _floor_index >= 6:
		return ENDLESS_BASE_KILL_REQUIREMENT + ((_floor_index - 6) * ENDLESS_KILL_INCREMENT)
	return _current_kill_requirement

func _ready() -> void:
	if not EventBus.enemy_defeated.is_connected(_on_enemy_defeated_for_exit):
		EventBus.enemy_defeated.connect(_on_enemy_defeated_for_exit)
	if _advance_requested:
		_floor_index += 1
	else:
		_floor_index = _queued_start_floor
	_queued_start_floor = 1
	_advance_requested = false
	level_number = _floor_index
	PlayerState.record_level_reached(_floor_index)
	level_title_text = "FLOOR %d" % _floor_index
	_transitioning = false
	_bug_spawn_index = 0
	_rng.randomize()
	_wall_material = _build_wall_material()
	_generate_dungeon()
	super._ready()
	_play_level_intro()
	_setup_level_music()

func _generate_dungeon() -> void:
	if _floor_index == 5:
		_generate_floor_five_dungeon()
		return

	var grid := _make_filled_grid()
	var rooms: Array[Rect2i] = []

	var main_w := _rng.randi_range(78, 108)
	var main_h := _rng.randi_range(66, 96)
	var main_x := int((GRID_W - main_w) / 2)
	var main_y := int((GRID_H - main_h) / 2)
	var main_room := Rect2i(main_x, main_y, main_w, main_h)

	_carve_room(grid, main_room)
	rooms.append(main_room)

	var attempts := 0
	while rooms.size() < TARGET_ROOM_COUNT and attempts < ROOM_ATTEMPTS:
		attempts += 1
		var anchor := rooms[_rng.randi_range(0, rooms.size() - 1)]
		var candidate := _make_candidate_room(anchor)
		if candidate.size == Vector2i.ZERO:
			continue
		if not _room_inside_bounds(candidate):
			continue
		if _room_overlaps(candidate, rooms):
			continue

		_carve_corridor(grid, _room_center(anchor), _room_center(candidate))
		_carve_room(grid, candidate)
		rooms.append(candidate)

	_add_extra_corridors(grid, rooms)
	_build_minimap_texture(grid)
	_build_walls(grid)
	_resize_background()
	_populate_floor(main_room, rooms)

func _generate_floor_five_dungeon() -> void:
	_floor_five_cutscene_played = false
	_floor_five_boss = null
	var grid := _make_filled_grid()
	var spawn_room := Rect2i(40, int((GRID_H - 36) / 2), 42, 36)
	var spawn_center := _room_center(spawn_room)
	var big_room := Rect2i(spawn_room.end.x + 68, spawn_center.y - 52, 132, 104)

	_carve_room(grid, spawn_room)
	_carve_room(grid, big_room)
	_carve_line_horizontal(grid, spawn_room.end.x - 1, big_room.position.x, spawn_center.y, HALLWAY_WIDTH)

	var rooms: Array[Rect2i] = [spawn_room, big_room]
	_build_minimap_texture(grid)
	_build_walls(grid)
	_resize_background()
	_populate_floor(spawn_room, rooms)

func _make_filled_grid() -> Array:
	var grid: Array = []
	for y in range(GRID_H):
		var row: Array = []
		row.resize(GRID_W)
		row.fill(true) # true = wall, false = floor
		grid.append(row)
	return grid

func _make_candidate_room(anchor: Rect2i) -> Rect2i:
	var room_w := _rng.randi_range(54, 102)
	var room_h := _rng.randi_range(48, 90)
	var corridor := _rng.randi_range(24, 78)
	var center := _room_center(anchor)
	var nx := center.x - int(room_w / 2)
	var ny := center.y - int(room_h / 2)

	match _rng.randi_range(0, 3):
		0: # Right
			nx = anchor.position.x + anchor.size.x + corridor
		1: # Left
			nx = anchor.position.x - corridor - room_w
		2: # Down
			ny = anchor.position.y + anchor.size.y + corridor
		3: # Up
			ny = anchor.position.y - corridor - room_h

	return Rect2i(nx, ny, room_w, room_h)

func _room_inside_bounds(room: Rect2i) -> bool:
	return room.position.x >= 1 \
		and room.position.y >= 1 \
		and room.end.x <= GRID_W - 1 \
		and room.end.y <= GRID_H - 1

func _room_overlaps(room: Rect2i, rooms: Array[Rect2i]) -> bool:
	var padded := Rect2i(room.position - Vector2i.ONE, room.size + Vector2i.ONE * 2)
	for existing in rooms:
		if padded.intersects(existing):
			return true
	return false

func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + int(room.size.x / 2), room.position.y + int(room.size.y / 2))

func _carve_room(grid: Array, room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			grid[y][x] = false

func _carve_corridor(grid: Array, from: Vector2i, to: Vector2i) -> void:
	if _rng.randi_range(0, 1) == 0:
		_carve_line_horizontal(grid, from.x, to.x, from.y, HALLWAY_WIDTH)
		_carve_line_vertical(grid, from.y, to.y, to.x, HALLWAY_WIDTH)
	else:
		_carve_line_vertical(grid, from.y, to.y, from.x, HALLWAY_WIDTH)
		_carve_line_horizontal(grid, from.x, to.x, to.y, HALLWAY_WIDTH)

func _carve_line_horizontal(grid: Array, x0: int, x1: int, y: int, width: int = 1) -> void:
	var start_x := mini(x0, x1)
	var end_x := maxi(x0, x1)
	var half_w := int(width / 2)
	for x in range(start_x, end_x + 1):
		for oy in range(-half_w, half_w + 1):
			var cy := y + oy
			if cy >= 0 and cy < GRID_H and x >= 0 and x < GRID_W:
				grid[cy][x] = false

func _carve_line_vertical(grid: Array, y0: int, y1: int, x: int, width: int = 1) -> void:
	var start_y := mini(y0, y1)
	var end_y := maxi(y0, y1)
	var half_w := int(width / 2)
	for y in range(start_y, end_y + 1):
		for ox in range(-half_w, half_w + 1):
			var cx := x + ox
			if y >= 0 and y < GRID_H and cx >= 0 and cx < GRID_W:
				grid[y][cx] = false

func _add_extra_corridors(grid: Array, rooms: Array[Rect2i]) -> void:
	if rooms.size() < 3:
		return
	for i in range(EXTRA_HALLWAYS):
		var a_idx := _rng.randi_range(0, rooms.size() - 1)
		var b_idx := _rng.randi_range(0, rooms.size() - 1)
		if a_idx == b_idx:
			continue
		_carve_corridor(grid, _room_center(rooms[a_idx]), _room_center(rooms[b_idx]))

func _build_walls(grid: Array) -> void:
	var walls := $Walls
	for c in walls.get_children():
		c.queue_free()

	for y in range(GRID_H):
		var run_start := -1
		for x in range(GRID_W):
			var is_wall := bool(grid[y][x])
			if is_wall and run_start == -1:
				run_start = x
			elif not is_wall and run_start != -1:
				_spawn_wall_span(walls, run_start, x - 1, y)
				run_start = -1
		if run_start != -1:
			_spawn_wall_span(walls, run_start, GRID_W - 1, y)
	_spawn_outer_boundary_walls(walls)

func _spawn_wall_span(parent: Node, start_x: int, end_x: int, cell_y: int) -> void:
	var tile_count := end_x - start_x + 1
	var span_w := float(tile_count) * TILE_SIZE
	var body := StaticBody2D.new()
	body.position = Vector2((float(start_x) + float(tile_count) * 0.5) * TILE_SIZE, (cell_y + 0.5) * TILE_SIZE)
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(span_w, TILE_SIZE)
	shape.shape = rect
	body.add_child(shape)

	var block := ColorRect.new()
	block.offset_left = -span_w * 0.5
	block.offset_top = -TILE_SIZE * 0.5
	block.offset_right = span_w * 0.5
	block.offset_bottom = TILE_SIZE * 0.5
	block.color = Color(1, 1, 1, 1)
	block.material = _wall_material
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(block)

func _spawn_vertical_wall_span(parent: Node, cell_x: int, start_y: int, end_y: int) -> void:
	var tile_count := end_y - start_y + 1
	var span_h := float(tile_count) * TILE_SIZE
	var body := StaticBody2D.new()
	body.position = Vector2((cell_x + 0.5) * TILE_SIZE, (float(start_y) + float(tile_count) * 0.5) * TILE_SIZE)
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, span_h)
	shape.shape = rect
	body.add_child(shape)

	var block := ColorRect.new()
	block.offset_left = -TILE_SIZE * 0.5
	block.offset_top = -span_h * 0.5
	block.offset_right = TILE_SIZE * 0.5
	block.offset_bottom = span_h * 0.5
	block.color = Color(1, 1, 1, 1)
	block.material = _wall_material
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(block)

func _spawn_outer_boundary_walls(parent: Node) -> void:
	# Add thick outer walls so camera space outside the dungeon still shows map walls.
	var t := OUTER_WALL_THICKNESS_TILES
	_spawn_outer_wall_band(parent, Rect2i(-t, -t, GRID_W + t * 2, t)) # top
	_spawn_outer_wall_band(parent, Rect2i(-t, GRID_H, GRID_W + t * 2, t)) # bottom
	_spawn_outer_wall_band(parent, Rect2i(-t, 0, t, GRID_H)) # left
	_spawn_outer_wall_band(parent, Rect2i(GRID_W, 0, t, GRID_H)) # right

func _spawn_outer_wall_band(parent: Node, cells: Rect2i) -> void:
	var body := StaticBody2D.new()
	var w := float(cells.size.x) * TILE_SIZE
	var h := float(cells.size.y) * TILE_SIZE
	body.position = Vector2(
		(float(cells.position.x) + float(cells.size.x) * 0.5) * TILE_SIZE,
		(float(cells.position.y) + float(cells.size.y) * 0.5) * TILE_SIZE
	)
	body.collision_layer = 1 | OUTER_WALL_COLLISION_LAYER
	body.collision_mask = 0
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)

	var block := ColorRect.new()
	block.offset_left = -w * 0.5
	block.offset_top = -h * 0.5
	block.offset_right = w * 0.5
	block.offset_bottom = h * 0.5
	block.color = Color(1, 1, 1, 1)
	block.material = _wall_material
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(block)

func _resize_background() -> void:
	var bg := get_node_or_null("Background") as ColorRect
	if bg == null:
		return
	bg.offset_right = GRID_W * TILE_SIZE
	bg.offset_bottom = GRID_H * TILE_SIZE

func _populate_floor(main_room: Rect2i, rooms: Array[Rect2i]) -> void:
	var enemy_root := _get_or_create_container("Enemies")
	var obstacle_root := _get_or_create_container("Obstacles")
	var interactable_root := _get_or_create_container("Interactables")
	_clear_children(enemy_root)
	_clear_children(obstacle_root)
	_clear_children(interactable_root)

	var player := get_node_or_null("Player") as Node2D
	if player != null:
		player.global_position = _cell_to_world(_room_center(main_room))

	var is_floor_five := _floor_index == 5
	var door_room := Rect2i()
	if not is_floor_five:
		door_room = _pick_farthest_room(main_room, rooms)
		_door_room = door_room
		_interactable_root_ref = interactable_root
		_current_kill_requirement = int(get_enemy_kill_requirement())
		
		# ALWAYS SPAWN TELEPHONE AT START
		_spawn_floor_door(interactable_root, door_room)
		_exit_spawned = true
	else:
		_current_kill_requirement = 0
		_door_room = Rect2i()
		_interactable_root_ref = null
		_exit_spawned = false

	for room in rooms:
		# Keep both the spawn room and floor door room clear.
		if not is_floor_five and room != main_room and room != door_room:
			_spawn_room_obstacles(obstacle_root, room)
		if not is_floor_five and room != main_room:
			match _floor_index:
				1:
					# Level 1: Only bugs
					_spawn_room_bugs(enemy_root, room)
				2:
					# Level 2: Bugs + Snakes
					if _rng.randf() > 0.4:
						_spawn_room_bugs(enemy_root, room)
					else:
						_spawn_room_snakes(enemy_root, room)
				3:
					# Level 3: Bugs + Snakes + Trojans
					var r := _rng.randf()
					if r > 0.6:
						_spawn_room_bugs(enemy_root, room)
					elif r > 0.3:
						_spawn_room_snakes(enemy_root, room)
					else:
						_spawn_room_trojans(enemy_root, room)
				4:
					# Level 4: Level 3 + higher intensity
					var r := _rng.randf()
					if r > 0.6:
						_spawn_room_bugs(enemy_root, room, 2.5) # 2.5x more bugs
					elif r > 0.3:
						_spawn_room_snakes(enemy_root, room, 2.0) # 2x more snakes
					else:
						_spawn_room_trojans(enemy_root, room, 2.0) # 2x more trojans
				_:
					var endless_mult := _get_endless_enemy_multiplier()
					var r := _rng.randf()
					if r > 0.55:
						_spawn_room_bugs(enemy_root, room, 2.5 * endless_mult)
					elif r > 0.2:
						_spawn_room_snakes(enemy_root, room, 2.0 * endless_mult)
					else:
						_spawn_room_trojans(enemy_root, room, 2.0 * endless_mult)

	if is_floor_five:
		var big_room := rooms[1] if rooms.size() > 1 else main_room
		_spawn_floor_five_boss(enemy_root, big_room)
		_spawn_floor_five_cutscene_trigger(interactable_root, big_room)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)

func _build_wall_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 bg_color : source_color = vec4(0.02, 0.06, 0.04, 1.0);
uniform vec4 code_color : source_color = vec4(0.24, 1.0, 0.45, 1.0);
uniform float fall_speed = 1.8;
uniform float glyph_density = 48.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 glyph_uv = vec2(UV.x * glyph_density * 0.5, UV.y * glyph_density + TIME * fall_speed * 12.0);
	vec2 gid = floor(glyph_uv + floor(SCREEN_UV * 220.0));
	float glyph = step(0.82, hash(gid));
	float scan = 0.25 + 0.75 * pow(1.0 - UV.y, 1.4);
	float pulse = 0.06 * (sin((UV.y + TIME * 1.6) * 55.0) * 0.5 + 0.5);
	vec3 col = mix(bg_color.rgb, code_color.rgb, glyph * scan);
	col += code_color.rgb * pulse;
	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _build_minimap_texture(grid: Array) -> void:
	var img := Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	var wall_col := Color(0.02, 0.06, 0.08, 0.9)
	var floor_col := Color(0.3, 1.0, 0.5, 0.95)
	for y in range(GRID_H):
		for x in range(GRID_W):
			img.set_pixel(x, y, wall_col if bool(grid[y][x]) else floor_col)
	_minimap_texture = ImageTexture.create_from_image(img)

func get_minimap_texture() -> Texture2D:
	return _minimap_texture

func get_world_size() -> Vector2:
	return Vector2(GRID_W * TILE_SIZE, GRID_H * TILE_SIZE)

func _get_or_create_container(name: String) -> Node2D:
	var n := get_node_or_null(name) as Node2D
	if n != null:
		return n
	n = Node2D.new()
	n.name = name
	add_child(n)
	return n

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _pick_farthest_room(main_room: Rect2i, rooms: Array[Rect2i]) -> Rect2i:
	var main_center := _room_center(main_room)
	var farthest := main_room
	var far_dist := -1.0
	for room in rooms:
		if room == main_room:
			continue
		var d := main_center.distance_to(_room_center(room))
		if d > far_dist:
			far_dist = d
			farthest = room
	return farthest

func _spawn_floor_door(parent: Node2D, room: Rect2i) -> void:
	var door := StaticBody2D.new()
	door.name = "SystemTelephone"
	door.collision_layer = 2
	door.collision_mask = 0
	door.position = _cell_to_world(_room_center(room))
	door.set_script(FLOOR_DOOR_SCRIPT)
	parent.add_child(door)
	if door.has_signal("door_used"):
		door.connect("door_used", Callable(self, "_on_floor_door_used"))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, 32.0)
	shape.shape = rect
	door.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	door.add_child(sprite)
	
	# Initial check
	if door.has_method("_update_visuals"):
		door.call("_update_visuals")
	
	EventBus.log("SYSTEM TELEPHONE LOCATED // CLEAR TARGETS TO ANSWER", "info")

func _spawn_room_obstacles(parent: Node2D, room: Rect2i) -> void:
	var obstacle_count := _rng.randi_range(MIN_OBSTACLES_PER_ROOM, MAX_OBSTACLES_PER_ROOM)
	for i in range(obstacle_count):
		var max_w := maxi(4, int(room.size.x * 0.35))
		var max_h := maxi(4, int(room.size.y * 0.35))
		var obs_w_cells := _rng.randi_range(3, max_w)
		var obs_h_cells := _rng.randi_range(3, max_h)
		var margin := 3
		if room.size.x <= obs_w_cells + margin * 2 or room.size.y <= obs_h_cells + margin * 2:
			continue

		var ox := _rng.randi_range(room.position.x + margin, room.end.x - obs_w_cells - margin)
		var oy := _rng.randi_range(room.position.y + margin, room.end.y - obs_h_cells - margin)
		_spawn_obstacle(parent, Rect2i(ox, oy, obs_w_cells, obs_h_cells))

func _spawn_obstacle(parent: Node2D, obstacle_cells: Rect2i) -> void:
	var body := StaticBody2D.new()
	var w := float(obstacle_cells.size.x) * TILE_SIZE
	var h := float(obstacle_cells.size.y) * TILE_SIZE
	body.position = Vector2(
		(float(obstacle_cells.position.x) + float(obstacle_cells.size.x) * 0.5) * TILE_SIZE,
		(float(obstacle_cells.position.y) + float(obstacle_cells.size.y) * 0.5) * TILE_SIZE
	)
	body.collision_layer = 1
	body.collision_mask = 4
	body.add_to_group("obstacle")
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)

	var block := ColorRect.new()
	block.offset_left = -w * 0.5
	block.offset_top = -h * 0.5
	block.offset_right = w * 0.5
	block.offset_bottom = h * 0.5
	block.color = Color(0.07, 0.12, 0.1, 1.0)
	block.material = _wall_material
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(block)

func _spawn_room_bugs(parent: Node2D, room: Rect2i, count_mult: float = 1.0) -> void:
	var base_count := _rng.randi_range(MIN_BUGS_PER_ROOM, MAX_BUGS_PER_ROOM)
	var bug_count := int(base_count * count_mult)
	for i in range(bug_count):
		var bug := BUG_SCENE.instantiate()
		if bug == null:
			continue
		_bug_spawn_index += 1
		bug.set("entity_id", "bug_floor_%d_%d" % [_floor_index, _bug_spawn_index])
		bug.position = _cell_to_world(_random_cell_in_room(room, 3))
		# Higher floors increase speed.
		if _floor_index >= 4:
			var current_speed = bug.get("move_speed")
			if current_speed == null: current_speed = 140.0
			bug.set("move_speed", current_speed * _get_enemy_speed_multiplier())
		parent.add_child(bug)

func _spawn_room_snakes(parent: Node2D, room: Rect2i, count_mult: float = 1.0) -> void:
	var base_count := _rng.randi_range(1, 2)
	var count := int(base_count * count_mult) 
	for i in range(count):
		var snake := SNAKE_SCENE.instantiate()
		if snake == null:
			continue
		_bug_spawn_index += 1
		snake.set("entity_id", "snake_floor_%d_%d" % [_floor_index, _bug_spawn_index])
		snake.position = _cell_to_world(_random_cell_in_room(room, 3))
		if _floor_index >= 4:
			var current_speed = snake.get("move_speed")
			if current_speed == null: current_speed = 120.0
			snake.set("move_speed", current_speed * _get_enemy_speed_multiplier())
		parent.add_child(snake)

func _spawn_room_trojans(parent: Node2D, room: Rect2i, count_mult: float = 1.0) -> void:
	var base_count := _rng.randi_range(1, 2)
	var count := int(base_count * count_mult)
	for i in range(count):
		var trojan := TROJAN_SCENE.instantiate()
		if trojan == null:
			continue
		_bug_spawn_index += 1
		trojan.set("entity_id", "trojan_floor_%d_%d" % [_floor_index, _bug_spawn_index])
		trojan.position = _cell_to_world(_random_cell_in_room(room, 3))
		if _floor_index >= 4:
			var current_speed = trojan.get("move_speed")
			if current_speed == null: current_speed = 100.0
			trojan.set("move_speed", current_speed * _get_enemy_speed_multiplier())
		parent.add_child(trojan)

func _get_enemy_speed_multiplier() -> float:
	if _floor_index <= 3:
		return 1.0
	if _floor_index == 4:
		return 1.3
	return 1.3 + (float(_floor_index - 4) * 0.08)

func _get_endless_enemy_multiplier() -> float:
	if _floor_index <= 5:
		return 1.0
	return 1.0 + (float(_floor_index - 5) * 0.2)

func _random_cell_in_room(room: Rect2i, margin: int = 1) -> Vector2i:
	var min_x := room.position.x + margin
	var max_x := room.end.x - margin - 1
	var min_y := room.position.y + margin
	var max_y := room.end.y - margin - 1
	if min_x > max_x:
		min_x = room.position.x
		max_x = room.end.x - 1
	if min_y > max_y:
		min_y = room.position.y
		max_y = room.end.y - 1
	return Vector2i(_rng.randi_range(min_x, max_x), _rng.randi_range(min_y, max_y))

func _spawn_floor_five_boss(parent: Node2D, big_room: Rect2i) -> void:
	var boss := CHATGPT_BOSS_SCENE.instantiate() as Node2D
	if boss == null:
		return
	parent.add_child(boss)
	boss.global_position = _cell_to_world(_room_center(big_room))
	boss.add_to_group("enemy")
	_floor_five_boss = boss
	var hud_node := get_node_or_null("HUD")
	if is_instance_valid(hud_node) and hud_node.has_method("bind_boss"):
		hud_node.call("bind_boss", boss, "CHATGPT")
	if boss.has_signal("death_animation_finished"):
		boss.death_animation_finished.connect(_on_chatgpt_death, CONNECT_ONE_SHOT)
	if boss.has_signal("shatter_started"):
		boss.shatter_started.connect(_on_chatgpt_shatter)

func _spawn_floor_five_cutscene_trigger(parent: Node2D, big_room: Rect2i) -> void:
	var trigger := Area2D.new()
	trigger.name = "FloorFiveBossCutsceneTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.monitoring = true
	parent.add_child(trigger)
	trigger.global_position = _cell_to_world(_room_center(big_room))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(big_room.size.x) * TILE_SIZE, float(big_room.size.y) * TILE_SIZE)
	shape.shape = rect
	trigger.add_child(shape)

	trigger.body_entered.connect(func(body: Node) -> void:
		if _floor_five_cutscene_played:
			return
		if not body.is_in_group("player"):
			return
		_floor_five_cutscene_played = true
		trigger.monitoring = false
		_play_floor_five_boss_cutscene(body as Node2D)
	)

func _play_floor_five_boss_cutscene(player: Node2D) -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var original_smoothing := camera.position_smoothing_enabled
	var default_zoom := camera.zoom
	var boss_focus := _floor_five_boss.global_position if is_instance_valid(_floor_five_boss) else player.global_position
	var can_restore_player_physics := player.has_method("set_physics_process")

	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	if can_restore_player_physics:
		player.set_physics_process(false)

	camera.position_smoothing_enabled = false
	camera.reparent(self, true)

	var reveal_tween := create_tween()
	reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_property(camera, "global_position", boss_focus, 3.0)
	reveal_tween.parallel().tween_property(camera, "zoom", Vector2(0.85, 0.85), 3.0)
	await reveal_tween.finished
	await get_tree().create_timer(0.75).timeout

	var return_tween := create_tween()
	return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(camera, "global_position", player.global_position, 1.2)
	return_tween.parallel().tween_property(camera, "zoom", default_zoom, 1.2)
	await return_tween.finished

	camera.reparent(player, true)
	camera.position = Vector2.ZERO
	camera.position_smoothing_enabled = original_smoothing
	if can_restore_player_physics:
		player.set_physics_process(true)
	
	_camera_at_player = camera
	_player_for_death_cam = player

func _on_floor_door_used() -> void:
	if _transitioning:
		return
	_transitioning = true

	_advance_requested = true
	var next_floor = _floor_index + 1

	await _play_exit_transition()

	if next_floor % 5 == 0:
		# It's a boss floor
		ScreenFX.transition_to_scene("res://scenes/levels/LevelBoss.tscn")
	else:
		# Regular floor
		ScreenFX.transition_to_scene("res://scenes/levels/Level2.tscn")
func _on_enemy_defeated_for_exit(_enemy_id: String) -> void:
	if _floor_index >= 5:
		return
	# Redundant door spawning removed as SystemTelephone is now present from start.
	pass

func _on_chatgpt_death() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _play_exit_transition()
	ScreenFX.transition_to_scene("res://scenes/ui/WinScreen.tscn")

func _on_chatgpt_shatter() -> void:
	if _player_for_death_cam == null or _camera_at_player == null:
		return
	
	var camera := _camera_at_player
	var boss_focus := _floor_five_boss.global_position if is_instance_valid(_floor_five_boss) else _player_for_death_cam.global_position
	
	camera.position_smoothing_enabled = false
	camera.reparent(self, true)
	
	var zoom_in_tween := create_tween()
	zoom_in_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_in_tween.tween_property(camera, "global_position", boss_focus, 0.5)
	zoom_in_tween.parallel().tween_property(camera, "zoom", Vector2(0.6, 0.6), 0.5)
	await zoom_in_tween.finished
	
	await get_tree().create_timer(0.3).timeout
	
	var zoom_out_tween := create_tween()
	zoom_out_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom_out_tween.tween_property(camera, "zoom", Vector2(0.3, 0.3), 1.2)

func _play_level_intro() -> void:
	var intro_text := ""
	var intro_subtext := ""
	
	match _floor_index:
		1:
			intro_text = "NEW ENEMY: WORM"
			intro_subtext = "TACTICAL ADVICE: ELIMINATE WITH BULLETS"
		2:
			intro_text = "NEW ENEMY: SNAKE"
			intro_subtext = "TACTICAL ADVICE: USE SPEED // STRIKE THE TAIL"
		3:
			intro_text = "NEW ENEMY: TROJAN HORSE"
			intro_subtext = "TACTICAL ADVICE: FIND OUT YOURSELF"
		4:
			intro_text = "INTENSITY INCREASED"
			intro_subtext = "SYSTEM STABILITY: COMPROMISED"
		5:
			intro_text = "FINAL BOSS: ROGUE AI"
			intro_subtext = "THREAT LEVEL: OMEGA // SYSTEM CRITICAL"
		_:
			return

	# Create a temporary UI for intro
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	
	var vbox := VBoxContainer.new()
	center.add_child(vbox)
	
	var main_label := Label.new()
	main_label.text = intro_text
	main_label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	main_label.add_theme_font_size_override("font_size", 32)
	main_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main_label)
	
	var sub_label := Label.new()
	sub_label.text = intro_subtext
	sub_label.add_theme_font_override("font", preload("res://Minecraft.ttf"))
	sub_label.add_theme_font_size_override("font_size", 18)
	sub_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.6))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)
	
	# Animation
	main_label.modulate.a = 0.0
	sub_label.modulate.a = 0.0
	center.scale = Vector2(0.8, 0.8)
	center.pivot_offset = get_viewport_rect().size / 2.0
	
	var intro_tween := create_tween()
	intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Play even if paused
	intro_tween.tween_interval(2.5) # Wait for player teleport animation
	intro_tween.tween_property(main_label, "modulate:a", 1.0, 0.5)
	intro_tween.parallel().tween_property(center, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(sub_label, "modulate:a", 1.0, 0.5)
	intro_tween.tween_interval(2.0)
	intro_tween.tween_property(vbox, "modulate:a", 0.0, 0.8)
	intro_tween.tween_callback(layer.queue_free)
	
	AudioManager.play_sfx("dragon-studio-simple-whoosh")

func _setup_level_music() -> void:
	if _floor_index % 5 != 0:
		Music.playglobalsound("res://Sounds/Prime Audio Soup.mp3")
