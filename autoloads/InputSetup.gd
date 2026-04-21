extends Control

var _selected_id := "pistol"
var _cards := {}

func _ready() -> void:
	# Load previously selected gun
	_selected_id = PlayerState.selected_gun_id

	# Background (must be a ColorRect)
	if $Background is ColorRect:
		$Background.color = Color(0.04, 0.05, 0.09)

	$Background.set_anchors_preset(Control.PRESET_FULL_RECT)

	# UI styling
	$TitleLabel.add_theme_font_size_override("font_size", 18)
	$TitleLabel.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))

	$DeployBtn.add_theme_font_size_override("font_size", 14)
	$BackBtn.add_theme_font_size_override("font_size", 12)

	# Button signals
	$DeployBtn.pressed.connect(_on_deploy)
	$BackBtn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)

	_build_cards()


func _build_cards() -> void:
	for gid in GunDatabase.get_all_ids():
		var gun = GunDatabase.guns[gid]
		var card = _make_card(gid, gun)
		$GunGrid.add_child(card)
		_cards[gid] = card

	_refresh()


func _make_card(gid: String, gun: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 140)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# Gun image
	var tex = TextureRect.new()
	tex.custom_minimum_size = Vector2(90, 65)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var path = gun.get("sprite", "")
	if ResourceLoader.exists(path):
		tex.texture = load(path)

	vbox.add_child(tex)

	# Gun name
	var name_lbl = Label.new()
	name_lbl.text = gun["display_name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", gun.get("color", Color.WHITE))
	vbox.add_child(name_lbl)

	# Stats
	var stats = Label.new()
	stats.text = "DMG:%d  AMO:%d" % [gun["damage"], gun["max_ammo"]]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 9)
	vbox.add_child(stats)

	# Illegal tag
	if gun.get("illegal", false):
		var tag = Label.new()
		tag.text = "!! ILLEGAL !!"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		vbox.add_child(tag)

	# Select button
	var btn = Button.new()
	btn.text = "SELECT"
	btn.pressed.connect(func():
		_selected_id = gid
		PlayerState.selected_gun_id = gid
		_refresh()
	)
	vbox.add_child(btn)

	return card


func _refresh() -> void:
	for gid in _cards:
		var gun = GunDatabase.guns[gid]
		var panel = _cards[gid]

		# Highlight selected gun
		if gid == _selected_id:
			panel.self_modulate = gun.get("color", Color.WHITE)
		else:
			panel.self_modulate = Color(0.5, 0.5, 0.5)


func _on_deploy() -> void:
	PlayerState.selected_gun_id = _selected_id
	get_tree().change_scene_to_file("res://scenes/levels/Level1.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_accept"):
		_on_deploy()

	if event.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
