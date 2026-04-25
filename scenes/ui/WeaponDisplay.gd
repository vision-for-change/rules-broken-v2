extends Control

const LOW_AMMO_COLOR := Color(1.0, 0.35, 0.25)
const MID_AMMO_COLOR := Color(1.0, 0.75, 0.2)
const READY_COLOR := Color(0.8, 0.92, 1.0)
const EMPTY_COLOR := Color(1.0, 0.45, 0.35)
const MINECRAFT_FONT := preload("res://Minecraft.ttf")

var _inventory: Node = null
var _gun_color: Color = READY_COLOR

@onready var gun_image: TextureRect = $Panel/Margin/HBox/GunFrame/GunImage
@onready var weapon_name_label: Label = $Panel/Margin/HBox/Info/WeaponNameLabel
@onready var ammo_label: Label = $Panel/Margin/HBox/Info/AmmoLabel
@onready var status_label: Label = $Panel/Margin/HBox/Info/StatusLabel

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	_inventory = players[0].get_node_or_null("Inventory")
	if _inventory == null:
		return
	_inventory.gun_changed.connect(_on_gun_changed)
	_inventory.ammo_changed.connect(_on_ammo_changed)
	_inventory.reload_state_changed.connect(_on_reload_state_changed)

	_style_labels()
	
	var gun: Dictionary = _inventory.get_current_gun()
	if not gun.is_empty():
		_on_gun_changed(gun)

func _style_labels() -> void:
	weapon_name_label.add_theme_font_override("font", MINECRAFT_FONT)
	ammo_label.add_theme_font_override("font", MINECRAFT_FONT)
	status_label.add_theme_font_override("font", MINECRAFT_FONT)

func _on_gun_changed(gun: Dictionary) -> void:
	var path: String = str(gun.get("sprite", ""))
	if ResourceLoader.exists(path):
		gun_image.texture = load(path)
	weapon_name_label.text = str(gun.get("display_name", "Weapon")).to_upper()
	_gun_color = gun.get("color", READY_COLOR) as Color
	_update_ammo_text(int(gun["ammo"]), int(gun["max_ammo"]))
	_set_status("Ready", READY_COLOR)

func _on_ammo_changed(_id: String, current: int, maximum: int) -> void:
	_update_ammo_text(current, maximum)
	if current <= 0:
		_set_status("Out of ammo  |  Press R to reload", EMPTY_COLOR)
	else:
		_set_status("Ready", READY_COLOR)

func _on_reload_state_changed(is_reloading: bool, current: int, maximum: int, _reload_time: float) -> void:
	_update_ammo_text(current, maximum)
	if is_reloading:
		_set_status("Reloading...", MID_AMMO_COLOR)
	elif current <= 0:
		_set_status("Out of ammo  |  Press R to reload", EMPTY_COLOR)
	else:
		_set_status("Ready", READY_COLOR)

func _update_ammo_text(current: int, maximum: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [current, maximum]
	ammo_label.add_theme_color_override("font_color", _get_ammo_color(current, maximum))

func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)

func _get_ammo_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return EMPTY_COLOR
	if current <= 0:
		return EMPTY_COLOR
	if current <= 3:
		return LOW_AMMO_COLOR
	if float(current) / float(maximum) < 0.4:
		return MID_AMMO_COLOR
	return _gun_color
