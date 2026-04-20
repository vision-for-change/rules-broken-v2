extends Node
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_add("interact", [KEY_E, KEY_F])
	_add_mouse("shoot", [MOUSE_BUTTON_LEFT])
	_add("dash", [KEY_SPACE])
	_add("inspect",  [KEY_TAB])
	_add("pause_main_menu", [KEY_M])
	_add_to_existing("ui_left", [KEY_A])
	_add_to_existing("ui_right", [KEY_D])
	_add_to_existing("ui_up", [KEY_W])
	_add_to_existing("ui_down", [KEY_S])

func _add(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev = InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)

func _add_to_existing(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev = InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)

func _add_mouse(action: String, buttons: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for b in buttons:
		var ev = InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
