extends Node

signal gun_changed(gun_data: Dictionary)
signal ammo_changed(gun_id: String, current: int, max_ammo: int)
signal reload_state_changed(is_reloading: bool, current: int, max_ammo: int, reload_time: float)
signal inventory_full()

const MAX_SLOTS := 3

var slots: Array[Dictionary] = []
var current_slot: int = 0
var _reload_timer: float = 0.0
var _fire_timer: float = 0.0
var is_reloading: bool = false

func _ready() -> void:
	var gun_id: String = "pistol"
	if get_node_or_null("/root/GunDatabase") != null:
		gun_id = GunDatabase.selected_gun_id
	if get_node_or_null("/root/PlayerState") != null:
		gun_id = PlayerState.selected_gun_id
	var starting: Dictionary = GunDatabase.get_gun(gun_id)
	if not starting.is_empty():
		add_gun(starting)

func _process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = maxf(0.0, _fire_timer - delta)

	if not is_reloading:
		return

	_reload_timer -= delta
	if _reload_timer > 0.0:
		return

	is_reloading = false
	if slots.is_empty():
		return

	slots[current_slot]["ammo"] = slots[current_slot]["max_ammo"]
	ammo_changed.emit(
		slots[current_slot]["id"],
		slots[current_slot]["ammo"],
		slots[current_slot]["max_ammo"]
	)
	reload_state_changed.emit(
		false,
		slots[current_slot]["ammo"],
		slots[current_slot]["max_ammo"],
		0.0
	)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return

	if event.keycode == KEY_1:
		switch_to(0)
	elif event.keycode == KEY_2:
		switch_to(1)
	elif event.keycode == KEY_3:
		switch_to(2)
	elif event.keycode == KEY_Q:
		if not slots.is_empty():
			switch_to((current_slot + 1) % slots.size())
	elif event.keycode == KEY_R:
		start_reload()

func add_gun(gun_data: Dictionary) -> bool:
	for i in slots.size():
		if slots[i]["id"] == gun_data["id"]:
			slots[i]["ammo"] = mini(
				slots[i]["ammo"] + gun_data["max_ammo"] / 2,
				slots[i]["max_ammo"]
			)
			ammo_changed.emit(slots[i]["id"], slots[i]["ammo"], slots[i]["max_ammo"])
			return true

	if slots.size() >= MAX_SLOTS:
		inventory_full.emit()
		return false

	slots.append(gun_data.duplicate(true))

	if slots.size() == 1:
		switch_to(0)
	else:
		gun_changed.emit(slots[current_slot])
	return true

func switch_to(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	current_slot = index
	is_reloading = false
	_reload_timer = 0.0
	gun_changed.emit(slots[current_slot])
	reload_state_changed.emit(
		false,
		slots[current_slot]["ammo"],
		slots[current_slot]["max_ammo"],
		0.0
	)

func get_current_gun() -> Dictionary:
	if slots.is_empty():
		return {}
	return slots[current_slot]

func start_reload() -> void:
	if slots.is_empty() or is_reloading:
		return
	var gun: Dictionary = slots[current_slot]
	if gun["ammo"] >= gun["max_ammo"]:
		return
	is_reloading = true
	_reload_timer = float(gun.get("reload_time", 1.5))
	reload_state_changed.emit(true, gun["ammo"], gun["max_ammo"], _reload_timer)

func can_shoot() -> bool:
	if slots.is_empty() or is_reloading or _fire_timer > 0.0:
		return false
	return slots[current_slot]["ammo"] > 0

func request_shot() -> Dictionary:
	if not can_shoot():
		if not slots.is_empty() and slots[current_slot]["ammo"] <= 0:
			start_reload()
		return {}

	var gun: Dictionary = slots[current_slot]
	gun["ammo"] -= 1
	_fire_timer = float(gun["fire_rate"])
	ammo_changed.emit(gun["id"], gun["ammo"], gun["max_ammo"])
	if gun["ammo"] <= 0:
		reload_state_changed.emit(false, gun["ammo"], gun["max_ammo"], 0.0)
	return gun.duplicate(true)
