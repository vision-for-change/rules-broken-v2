extends Node

func _ready() -> void:
	_ensure_action("ui_left", [_key(KEY_LEFT), _key(KEY_A)])
	_ensure_action("ui_right", [_key(KEY_RIGHT), _key(KEY_D)])
	_ensure_action("ui_up", [_key(KEY_UP), _key(KEY_W)])
	_ensure_action("ui_down", [_key(KEY_DOWN), _key(KEY_S)])
	_ensure_action("ui_accept", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE)])
	_ensure_action("ui_cancel", [_key(KEY_ESCAPE)])

	_ensure_action("dash", [_key(KEY_SPACE)])
	_ensure_action("interact", [_key(KEY_E), _key(KEY_F)])
	_ensure_action("shoot", [_mouse(MOUSE_BUTTON_LEFT)])
	_ensure_action("inspect", [_key(KEY_TAB)])
	_ensure_action("pause_main_menu", [_key(KEY_M)])

	_ensure_action("reload", [_key(KEY_R)])
	_ensure_action("next_weapon", [_key(KEY_Q)])
	_ensure_action("slot_1", [_key(KEY_1)])
	_ensure_action("slot_2", [_key(KEY_2)])
	_ensure_action("slot_3", [_key(KEY_3)])

func _ensure_action(action_name: String, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in events:
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	return event

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
