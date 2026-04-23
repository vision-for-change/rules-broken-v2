extends Node

var selected_gun_id: String = "pistol"
var current_health: int = 300
var max_health: int = 300

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
