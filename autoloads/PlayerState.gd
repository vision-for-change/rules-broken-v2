extends Node

var selected_gun_id: String = "pistol"
var current_health: int = 300
var max_health: int = 300
var boss_defeated_this_run := false
var endless_unlocked := false
var max_level_achieved := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset_run_progression() -> void:
	boss_defeated_this_run = false
	endless_unlocked = false
	max_level_achieved = 1

func record_level_reached(level_number: int) -> void:
	max_level_achieved = maxi(max_level_achieved, level_number)
