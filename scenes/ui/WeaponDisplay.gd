extends Control

var _inventory: Node = null

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	_inventory = players[0].get_node_or_null("Inventory")
	if _inventory == null: return
	_inventory.gun_changed.connect(_on_gun_changed)
	_inventory.ammo_changed.connect(_on_ammo_changed)
	# Show starting gun
	var gun = _inventory.get_current_gun()
	if not gun.is_empty():
		_on_gun_changed(gun)

func _on_gun_changed(gun: Dictionary) -> void:
	var path = gun.get("sprite", "")
	if ResourceLoader.exists(path):
		$GunImage.texture = load(path)
	$AmmoLabel.text = "%d / %d" % [gun["ammo"], gun["max_ammo"]]
	$AmmoLabel.add_theme_color_override("font_color", gun.get("color", Color.WHITE))

func _on_ammo_changed(_id: String, current: int, maximum: int) -> void:
	$AmmoLabel.text = "%d / %d" % [current, maximum]
	# Turn red when low
	if current <= 3:
		$AmmoLabel.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	elif float(current) / maximum < 0.4:
		$AmmoLabel.add_theme_color_override("font_color", Color(1, 0.7, 0.1))
