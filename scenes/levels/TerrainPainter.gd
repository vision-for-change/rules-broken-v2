@tool
extends TileMapLayer

@export var map_size := Vector2i(32, 18)
@export var wall_thickness := 1

@export var terrain_set_id := 0
@export var floor_terrain_id := 0
@export var wall_terrain_id := 1

@export var generate_on_ready := true
@export var rebuild_now := false:
	set(value):
		rebuild_now = value
		if value:
			_build_room()
			rebuild_now = false

func _ready() -> void:
	if generate_on_ready:
		_build_room()

func _build_room() -> void:
	if tile_set == null:
		return

	clear()

	var floor_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []

	for y in range(map_size.y):
		for x in range(map_size.x):
			var cell := Vector2i(x, y)
			floor_cells.append(cell)

			var is_wall = (
				x < wall_thickness or
				y < wall_thickness or
				x >= map_size.x - wall_thickness or
				y >= map_size.y - wall_thickness
			)
			if is_wall:
				wall_cells.append(cell)

	set_cells_terrain_connect(floor_cells, terrain_set_id, floor_terrain_id, false)
	set_cells_terrain_connect(wall_cells, terrain_set_id, wall_terrain_id, false)
