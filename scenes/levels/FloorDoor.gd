extends StaticBody2D

signal door_used

var _used := false

func get_interact_hint() -> String:
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("_get_enemy_kill_status"):
		var status = hud.call("_get_enemy_kill_status")
		if not status["met"]:
			return "Eliminate %d more targets" % status["remaining"]
	return "Enter next floor"

func on_player_interact(_result: Dictionary) -> void:
	if _used:
		return
	
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("_get_enemy_kill_status"):
		var status = hud.call("_get_enemy_kill_status")
		if not status["met"]:
			return
	
	_used = true
	emit_signal("door_used")
