extends Node

var selected_gun_id: String = "pistol"

const GUNS := {
	"pistol": {
		"id": "pistol",
		"display_name": "Pistol",
		"description": "Reliable. Silent enough.",
		"damage": 15,
		"fire_rate": 0.35,
		"max_ammo": 12,
		"reload_time": 1.0,
		"bullet_speed": 300.0,
		"bullet_color": Color(1.0, 0.9, 0.3),
		"color": Color(0.9, 0.8, 0.2),
		"sprite": "res://assets/sprites/Pistol.png",
		"auto_fire": false,
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
		"bullet_speed": 400.0,
		"bullet_color": Color(1.0, 0.5, 0.1),
		"color": Color(0.6, 0.3, 0.1),
		"sprite": "res://assets/sprites/AK47.png",
		"auto_fire": true,
		"illegal": false,
	},
	"assault_rifle": {
		"id": "assault_rifle",
		"display_name": "Assault Rifle",
		"description": "Burst fire. Medium risk.",
		"damage": 22,
		"fire_rate": 0.09,
		"max_ammo": 25,
		"reload_time": 1.8,
		"bullet_speed": 420.0,
		"bullet_color": Color(0.4, 0.8, 1.0),
		"color": Color(0.2, 0.5, 0.8),
		"sprite": "res://assets/sprites/Assualt rifle.png",
		"auto_fire": true,
		"illegal": false,
	},
	"m4e": {
		"id": "m4e",
		"display_name": "M4E",
		"description": "Precise. Low noise signature.",
		"damage": 25,
		"fire_rate": 0.15,
		"max_ammo": 20,
		"reload_time": 1.5,
		"bullet_speed": 380.0,
		"bullet_color": Color(0.6, 1.0, 0.4),
		"color": Color(0.3, 0.7, 0.2),
		"sprite": "res://assets/sprites/M4E.jpg",
		"auto_fire": true,
		"illegal": false,
	},
	"usp": {
		"id": "usp",
		"display_name": "USP",
		"description": "Fully suppressed. Watchdogs won't hear it.",
		"damage": 18,
		"fire_rate": 0.4,
		"max_ammo": 15,
		"reload_time": 1.2,
		"bullet_speed": 280.0,
		"bullet_color": Color(0.8, 0.5, 1.0),
		"color": Color(0.5, 0.2, 0.8),
		"sprite": "res://assets/sprites/USP.jpg",
		"auto_fire": false,
		"illegal": false,
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
