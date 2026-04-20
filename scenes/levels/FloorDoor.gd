extends StaticBody2D

signal door_used

var _used := false

func get_interact_hint() -> String:
	return "Enter next floor"

func on_player_interact(_result: Dictionary) -> void:
	if _used:
		return
	_used = true
	emit_signal("door_used")
