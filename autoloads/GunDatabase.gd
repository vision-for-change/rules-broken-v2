extends Node

var guns := {
	"glitch_gun": {
		"id": "glitch_gun",
		"display_name": "GL1TCH",
		"description": "Breaks rules. Literally.",
		"damage": 999,
		"fire_rate": 0.05,
		"max_ammo": 7,
		"reload_time": 3.0,
		"bullet_speed": 600.0,
		"bullet_color": Color(0.0, 1.0, 0.5),
		"color": Color(0.0, 1.0, 0.4),
		"sprite": "res://assets/sprites/matrix_gun.webp",
		"auto_fire": true,
		"knockback": 200.0,
		"illegal": true,
		"rule_break": "removes_all_rules",
	},

	"emp_gun": {
		"id": "emp_gun",
		"display_name": "EMP",
		"description": "Disables watchdogs instantly.",
		"damage": 0,
		"fire_rate": 1.0,
		"max_ammo": 5,
		"reload_time": 2.5,
		"bullet_speed": 250.0,
		"bullet_color": Color(0.4, 0.6, 1.0),
		"color": Color(0.3, 0.5, 1.0),
		"sprite": "res://assets/sprites/bullet.webp",
		"auto_fire": false,
		"knockback": 0.0,
		"illegal": true,
		"rule_break": "disables_watchdogs",
	},
}

func get_gun(id: String) -> Dictionary:
	return guns.get(id, {})
