extends Node

var selected_gun_id: String = "pistol"
var current_health: int = 100
var max_health: int = 100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
