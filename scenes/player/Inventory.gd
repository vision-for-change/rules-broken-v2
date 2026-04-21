extends Node

signal gun_changed(gun_data: Dictionary)
signal ammo_changed(gun_id: String, current: int, max_ammo: int)

const MAX_SLOTS := 3
var slots: Array[Dictionary] = []
var current_slot: int = 0
var is_reloading: bool = false
var _reload_timer: float = 0.0
var _fire_timer: float = 0.0

# Reference to your existing Bullet scene
const BULLET_SCENE = preload("res://scenes/player/Bullet.tscn")

func _ready() -> void:
	# Load gun player picked on the select screen
	if GunDatabase == null:
		push_error("GunDatabase autoload is missing.")
		return
	var starting = GunDatabase.get_gun(PlayerState.selected_gun_id)
	if starting.is_empty():
		var all_ids: Array[String] = GunDatabase.get_all_ids()
		if not all_ids.is_empty():
			starting = GunDatabase.get_gun(all_ids[0])
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

	# Auto fire while holding left mouse
	var gun = get_current_gun()
	if not gun.is_empty() and gun.get("auto_fire", false):
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_try_shoot()

func _input(event: InputEvent) -> void:
	# Left click = shoot (semi auto)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_shoot()

	# Switch slots
	if event.is_action_pressed("slot_1"): switch_to(0)
	if event.is_action_pressed("slot_2"): switch_to(1)
	if event.is_action_pressed("slot_3"): switch_to(2)
	if event.is_action_pressed("next_weapon") and not slots.is_empty():
		switch_to((current_slot + 1) % slots.size())

	# Reload
	if event.is_action_pressed("reload"):
		start_reload()

func add_gun(gun_data: Dictionary) -> bool:
	gun_data = _normalize_gun_data(gun_data)

	# Already have it — top up ammo
	for i in slots.size():
		if slots[i]["id"] == gun_data["id"]:
			slots[i]["ammo"] = mini(
				slots[i]["ammo"] + gun_data["max_ammo"] / 2,
				slots[i]["max_ammo"]
			)
			ammo_changed.emit(slots[i]["id"], slots[i]["ammo"], slots[i]["max_ammo"])
			return true

	if slots.size() >= MAX_SLOTS:
		return false

	slots.append(gun_data)

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
	if int(gun.get("ammo", 0)) >= int(gun.get("max_ammo", 0)):
		return
	is_reloading = true
	_reload_timer = gun.get("reload_time", 1.5)

func can_shoot() -> bool:
	if slots.is_empty() or is_reloading or _fire_timer > 0.0:
		return false
	return int(slots[current_slot].get("ammo", 0)) > 0

func _try_shoot() -> void:
	if not can_shoot():
		if not slots.is_empty() and int(slots[current_slot].get("ammo", 0)) <= 0:
			start_reload()
		return

	var gun = slots[current_slot]
	gun["ammo"] -= 1
	_fire_timer = gun["fire_rate"]
	ammo_changed.emit(gun["id"], gun["ammo"], gun["max_ammo"])

	# Get direction toward mouse
	var player = get_parent()
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()

	# Spawn YOUR existing bullet
	var bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = player.global_position

	# Use your bullet's existing setup() function
	var speed_mult = gun.get("bullet_speed", 300.0) / 300.0
	bullet.setup(player, direction, speed_mult)

	# Apply damage override to match gun stats
	# Your bullet doesn't have a damage var yet — see Step 2 below
	if bullet.has_method("set_damage"):
		bullet.set_damage(gun["damage"])

	ScreenFX.screen_shake(1.5, 0.05)

func _normalize_gun_data(gun_data: Dictionary) -> Dictionary:
	var normalized := gun_data.duplicate(true)
	var max_ammo := int(normalized.get("max_ammo", 0))
	normalized["max_ammo"] = max_ammo
	normalized["ammo"] = int(normalized.get("ammo", max_ammo))
	normalized["fire_rate"] = float(normalized.get("fire_rate", 0.2))
	normalized["damage"] = int(normalized.get("damage", 1))
	normalized["bullet_speed"] = float(normalized.get("bullet_speed", 300.0))
	normalized["reload_time"] = float(normalized.get("reload_time", 1.5))
	normalized["auto_fire"] = bool(normalized.get("auto_fire", false))
	if not normalized.has("id"):
		normalized["id"] = "unknown"
	return normalized
