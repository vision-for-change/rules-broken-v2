extends Node

var selected_gun_id: String = "ump"

const GUNS := {
	"pistol": {
		"id": "pistol",
		"display_name": "Pistol",
		"description": "Reliable. Silent enough.",
		"damage": 15,
		"fire_rate": 0.35,
		"max_ammo": 12,
		"reload_time": 1.0,
		"bullet_speed": 450.0,
		"bullet_color": Color(1.0, 0.9, 0.3),
		"color": Color(0.9, 0.8, 0.2),
		"sprite": "res://assets/sprites/Pistol.png",
		"preview_sprite": "res://assets/matrix_gun.webp",
		"auto_fire": true,
		"illegal": false,
	},
	"ak47": {
		"id": "ak47",
		"display_name": "AK-47",
		"description": "Loud. Breaks the no-noise rule.",
		"damage": 30,
		"fire_rate": 0.12,
		"max_ammo": 30,
		"reload_time": 2.2,
		"bullet_speed": 600.0,
		"bullet_color": Color(1.0, 0.5, 0.1),
		"color": Color(0.6, 0.3, 0.1),
		"sprite": "res://assets/matrix_ak.webp",
		"auto_fire": true,
		"illegal": false,
	},
	"ump": {
		"id": "ump",
		"display_name": "UMP",
		"description": "Fast SMG burst. Cleaner recoil than the AK.",
		"damage": 22,
		"fire_rate": 0.09,
		"max_ammo": 30,
		"reload_time": 1.8,
		"bullet_speed": 570.0,
		"bullet_color": Color(0.7, 0.9, 1.0),
		"color": Color(0.35, 0.75, 0.95),
		"sprite": "res://assets/UMP.webp",
		"preview_sprite": "res://assets/UMP.webp",
		"auto_fire": true,
		"illegal": false,
	},
	"lightsaber": {
		"id": "lightsaber",
		"display_name": "Lightsaber",
		"description": "Dynamic energy blade. Cuts through bugs like butter.",
		"damage": 30,
		"fire_rate": 0.12,
		"max_ammo": 0, # Infinite
		"reload_time": 0.0,
		"bullet_speed": 600.0,
		"bullet_color": Color(1.0, 1.0, 1.0),
		"color": Color(0.0, 1.0, 1.0),
		"sprite": "res://assets/lightsaber.webp",
		"preview_sprite": "res://assets/lightsaber.webp",
		"auto_fire": true,
		"illegal": true,
		"is_lightsaber": true
	},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_gun(gun_id: String) -> Dictionary:
	var base = GUNS.get(gun_id, {})
	if base.is_empty():
		return {}
	var copy = base.duplicate(true)
	copy["ammo"] = copy["max_ammo"]
	return copy

func get_all_ids() -> Array:
	return GUNS.keys()
