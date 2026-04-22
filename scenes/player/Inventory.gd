extends Node

signal gun_changed(gun_data: Dictionary)
signal ammo_changed(gun_id: String, current: int, max_ammo: int)
signal inventory_full()

const MAX_SLOTS := 3

var slots: Array[Dictionary] = []
var current_slot: int = 0
var _reload_timer: float = 0.0
var _fire_timer: float = 0.0
var is_reloading: bool = false

const BULLET_SCENE = preload("res://scenes/player/Bullet.tscn")

func _ready() -> void:
	# Load gun from select screen
	if Engine.has_singleton("PlayerState") or get_node_or_null("/root/PlayerState") != null:
		var starting = GunDatabase.get_gun(PlayerState.selected_gun_id)
		if not starting.is_empty():
			add_gun(starting)
	elif get_node_or_null("/root/GunDatabase") != null:
		var starting = GunDatabase.get_gun(GunDatabase.selected_gun_id)
		if not starting.is_empty():
			add_gun(starting)

func _process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta

	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			is_reloading = false
			if not slots.is_empty():
				slots[current_slot]["ammo"] = slots[current_slot]["max_ammo"]
				ammo_changed.emit(
					slots[current_slot]["id"],
					slots[current_slot]["ammo"],
					slots[current_slot]["max_ammo"]
				)

	# Auto fire — hold left mouse for automatic guns
	if not slots.is_empty():
		var gun = slots[current_slot]
		if gun.get("auto_fire", false) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_try_shoot()

func _input(event: InputEvent) -> void:
	# ── Mouse shooting ──────────────────────────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_shoot()
		return  # stop here, don't run keyboard checks on mouse events

	# ── Keyboard only below ──────────────────────────
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_1: switch_to(0)
	elif event.keycode == KEY_2: switch_to(1)
	elif event.keycode == KEY_3: switch_to(2)
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

func get_current_gun() -> Dictionary:
	if slots.is_empty():
		return {}
	return slots[current_slot]

func start_reload() -> void:
	if slots.is_empty() or is_reloading:
		return
	var gun = slots[current_slot]
	if gun["ammo"] >= gun["max_ammo"]:
		return
	is_reloading = true
	_reload_timer = gun.get("reload_time", 1.5)

func can_shoot() -> bool:
	if slots.is_empty() or is_reloading or _fire_timer > 0.0:
		return false
	return slots[current_slot]["ammo"] > 0

func _try_shoot() -> void:
	if not can_shoot():
		if not slots.is_empty() and slots[current_slot]["ammo"] <= 0:
			start_reload()
		return

	var gun = slots[current_slot]
	gun["ammo"] -= 1
	_fire_timer = gun["fire_rate"]
	ammo_changed.emit(gun["id"], gun["ammo"], gun["max_ammo"])

	var player = get_parent()
	var dir = (player.get_global_mouse_position() - player.global_position).normalized()

	# Spawn your existing Bullet.tscn
	var bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = player.global_position
	bullet.setup(player, dir, gun.get("bullet_speed", 520.0) / 520.0)

	ScreenFX.screen_shake(1.5, 0.05)
