extends Node
func _ready() -> void:
	_add("run",      [KEY_SHIFT])
	_add("interact", [KEY_E, KEY_F])
	_add("inspect",  [KEY_TAB])
	_add("log_toggle", [KEY_QUOTELEFT])

func _add(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev = InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)
