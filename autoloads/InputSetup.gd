extends Node
func _ready() -> void:
	_add("run",      [KEY_SHIFT])
	_add("interact", [KEY_E, KEY_F])
	_add("inspect",  [KEY_TAB])
	_add("log_toggle", [KEY_QUOTELEFT])
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
