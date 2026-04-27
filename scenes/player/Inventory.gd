extends Node

signal gun_changed(gun_data: Dictionary)
signal ammo_changed(gun_id: String, current: int, max_ammo: int)
signal reload_state_changed(is_reloading: bool, current: int, max_ammo: int, reload_time: float)
signal inventory_full()

var slots: Array[Dictionary] = []
var current_slot: int = 0
var _reload_timer: float = 0.0
var _fire_timer: float = 0.0
var is_reloading: bool = false
var max_slots: int = 3

func _ready() -> void:
	var gun_id: String = "ump"
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
	elif event.keycode == KEY_4:
		switch_to(3)
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

	if slots.size() >= max_slots:
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

func set_max_slots(count: int) -> void:
	max_slots = maxi(1, count)
	if slots.size() > max_slots:
		slots.resize(max_slots)
		current_slot = clampi(current_slot, 0, max_slots - 1)
		if not slots.is_empty():
			gun_changed.emit(slots[current_slot])

func set_loadout(gun_ids: Array[String], equip_id: String = "") -> void:
	slots.clear()
	current_slot = 0
	is_reloading = false
	_reload_timer = 0.0
	for gun_id in gun_ids:
		var gun := GunDatabase.get_gun(gun_id)
		if gun.is_empty():
			continue
		if slots.size() >= max_slots:
			break
		slots.append(gun)
	if slots.is_empty():
		return
	var equip_index := 0
	if equip_id != "":
		for i in range(slots.size()):
			if slots[i]["id"] == equip_id:
				equip_index = i
				break
	switch_to(equip_index)

func start_reload() -> void:
	if slots.is_empty() or is_reloading:
		return
	var gun: Dictionary = slots[current_slot]
	if gun["ammo"] >= gun["max_ammo"]:
		return
	is_reloading = true
	_reload_timer = float(gun.get("reload_time", 1.5))
	reload_state_changed.emit(true, gun["ammo"], gun["max_ammo"], _reload_timer)
	Sounds.playsound("res://Sounds/dragon-studio-gun-reload-2-504027.mp3")

func can_shoot() -> bool:
	if slots.is_empty() or is_reloading or _fire_timer > 0.0:
		return false
	var gun = slots[current_slot]
	return gun["max_ammo"] == 0 or gun["ammo"] > 0

func request_shot() -> Dictionary:
	if not can_shoot():
		if not slots.is_empty() and slots[current_slot]["max_ammo"] > 0 and slots[current_slot]["ammo"] <= 0:
			start_reload()
		return {}

	var gun: Dictionary = slots[current_slot]
	
	var player = get_tree().get_nodes_in_group("player")
	var unlimited_bullets_enabled := false
	if not player.is_empty():
		var p = player[0]
		if p.has_method("get_hacked_client_modes"):
			unlimited_bullets_enabled = p.get_hacked_client_modes().get("unlimited_bullets", false)
	
	if not unlimited_bullets_enabled and gun["max_ammo"] > 0:
		gun["ammo"] -= 1
	
	_fire_timer = float(gun["fire_rate"])
	if gun["max_ammo"] > 0:
		ammo_changed.emit(gun["id"], gun["ammo"], gun["max_ammo"])
		if gun["ammo"] <= 0 and not unlimited_bullets_enabled:
			reload_state_changed.emit(false, gun["ammo"], gun["max_ammo"], 0.0)
	return gun.duplicate(true)
