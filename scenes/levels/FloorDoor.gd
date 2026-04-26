extends StaticBody2D

signal door_used

const TELEPHONE_DOWN = preload("res://assets/Telephonedown.webp")
const TELEPHONE_UP = preload("res://assets/TelephoneUp.webp")

var _used := false
var _ready_to_exit := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("exit_telephone")
	_update_visuals()

func _process(_delta: float) -> void:
	_check_status()

func _check_status() -> void:
	if _ready_to_exit:
		return
		
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("_get_enemy_kill_status"):
		var status = hud.call("_get_enemy_kill_status")
		if status["met"]:
			_ready_to_exit = true
			_update_visuals()
			EventBus.log("SYSTEM UNLOCKED // TELEPHONE UP", "exploit")
			AudioManager.play_sfx("universfield-magic-teleport-whoosh")

func _update_visuals() -> void:
	if sprite == null: return
	
	if _ready_to_exit:
		sprite.texture = TELEPHONE_UP
		sprite.modulate = Color(0.2, 1.0, 0.5) # Green glow when ready
	else:
		sprite.texture = TELEPHONE_DOWN
		sprite.modulate = Color(1.0, 0.3, 0.3) # Red tint when locked

func get_interact_hint() -> String:
	if _ready_to_exit:
		return "Answer System Call [E]"
		
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("_get_enemy_kill_status"):
		var status = hud.call("_get_enemy_kill_status")
		if not status["met"]:
			return "Targets remaining: %d" % status["remaining"]
	return "System Locked"

func on_player_interact(_result: Dictionary) -> void:
	if _used:
		return
	
	if not _ready_to_exit:
		AudioManager.play_sfx("click")
		ScreenFX.flash_screen(Color(1, 0, 0, 0.1), 0.1)
		return
	
	_used = true
	emit_signal("door_used")
