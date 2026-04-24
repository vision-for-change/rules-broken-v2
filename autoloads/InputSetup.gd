extends Node

func _ready() -> void:
	_add("ui_left", [_key(KEY_LEFT), _key(KEY_A)])
	_add("ui_right", [_key(KEY_RIGHT), _key(KEY_D)])
	_add("ui_up", [_key(KEY_UP), _key(KEY_W)])
	_add("ui_down", [_key(KEY_DOWN), _key(KEY_S)])
	
	_add("move_left", [_key(KEY_LEFT), _key(KEY_A)])
	_add("move_right", [_key(KEY_RIGHT), _key(KEY_D)])
	_add("move_up", [_key(KEY_UP), _key(KEY_W)])
	_add("move_down", [_key(KEY_DOWN), _key(KEY_S)])

	_add("ui_accept", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE)])
	_add("ui_cancel", [_key(KEY_ESCAPE)])

	_add("dash", [_key(KEY_SPACE)])
	_add("interact", [_key(KEY_E), _key(KEY_F)])
	_add("shoot", [_mouse(MOUSE_BUTTON_LEFT)])
	_add("inspect", [_key(KEY_TAB)])
	_add("pause_main_menu", [_key(KEY_M)])

	# ✅ STEP 6 (added properly)
	_add("slot_1", [_key(KEY_1)])
	_add("slot_2", [_key(KEY_2)])
	_add("slot_3", [_key(KEY_3)])
	_add("next_weapon", [_key(KEY_Q)])
	_add("reload", [_key(KEY_R)])


func _add(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in events:
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
