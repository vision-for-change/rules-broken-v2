extends StaticBody2D

signal interacted

var interact_hint := "Interact"

func get_interact_hint() -> String:
	return interact_hint

func on_player_interact(_result: Dictionary) -> void:
	interacted.emit()
