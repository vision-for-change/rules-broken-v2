extends Control

var _selected_id := "pistol"
var _cards := {}

func _ready() -> void:
	_selected_id = GunDatabase.selected_gun_id

	$Background.color = Color(0.04, 0.05, 0.09)
	$Background.set_anchors_preset(Control.PRESET_FULL_RECT)

	$TitleLabel.add_theme_font_size_override("font_size", 22)
	$TitleLabel.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	$TitleLabel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	$TitleLabel.offset_top = 20.0
	$TitleLabel.offset_bottom = 50.0
	$TitleLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	$SubLabel.add_theme_font_size_override("font_size", 11)
	$SubLabel.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	$SubLabel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	$SubLabel.offset_top = 52.0
	$SubLabel.offset_bottom = 70.0
	$SubLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Position gun grid in center
	$GunGrid.set_anchors_preset(Control.PRESET_CENTER)
	$GunGrid.offset_left = -280.0
	$GunGrid.offset_top = -60.0
	$GunGrid.offset_right = 280.0
	$GunGrid.offset_bottom = 100.0
	$GunGrid.add_theme_constant_override("separation", 12)

	$DeployBtn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	$DeployBtn.offset_left = 100.0
	$DeployBtn.offset_right = -100.0
	$DeployBtn.offset_top = -50.0
	$DeployBtn.offset_bottom = -15.0
	$DeployBtn.add_theme_font_size_override("font_size", 16)
	$DeployBtn.pressed.connect(_on_deploy)

	$BackBtn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	$BackBtn.offset_left = 15.0
	$BackBtn.offset_right = 90.0
	$BackBtn.offset_top = -50.0
	$BackBtn.offset_bottom = -15.0
	$BackBtn.add_theme_font_size_override("font_size", 12)
	$BackBtn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)

	_build_cards()

func _build_cards() -> void:
	# Clear any existing cards
	for child in $GunGrid.get_children():
		child.queue_free()
	_cards.clear()

	for gid in GunDatabase.get_all_ids():
		var gun = GunDatabase.GUNS[gid]
		var card = _make_card(gid, gun)
		$GunGrid.add_child(card)
		_cards[gid] = card

	_refresh()

func _make_card(gid: String, gun: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 160)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Gun image — shows your actual sprite
	var tex = TextureRect.new()
	tex.custom_minimum_size = Vector2(100, 80)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var path = gun.get("sprite", "")
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	vbox.add_child(tex)

	# Gun name
	var name_lbl = Label.new()
	name_lbl.text = gun["display_name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", gun.get("color", Color.WHITE))
	vbox.add_child(name_lbl)

	# Stats
	var stats = Label.new()
	stats.text = "DMG:%d  AMMO:%d" % [gun["damage"], gun["max_ammo"]]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	vbox.add_child(stats)

	# Description
	var desc = Label.new()
	desc.text = gun.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color(0.45, 0.5, 0.45))
	vbox.add_child(desc)

	# Select button
	var btn = Button.new()
	btn.text = "SELECT"
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func():
		_selected_id = gid
		GunDatabase.selected_gun_id = gid
		PlayerState.selected_gun_id = gid
		_refresh()
	)
	vbox.add_child(btn)

	return card

func _refresh() -> void:
	for gid in _cards:
		var gun = GunDatabase.GUNS[gid]
		var panel: PanelContainer = _cards[gid]
		if gid == _selected_id:
			# Highlight selected card with gun's color
			panel.self_modulate = Color(1, 1, 1, 1)
			panel.add_theme_stylebox_override("panel", _make_highlight_style(gun["color"]))
		else:
			panel.self_modulate = Color(0.5, 0.5, 0.5, 1)
			panel.remove_theme_stylebox_override("panel")

func _make_highlight_style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15)
	s.border_color = color
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	return s

func _on_deploy() -> void:
	GunDatabase.selected_gun_id = _selected_id
	PlayerState.selected_gun_id = _selected_id
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/levels/Level2.tscn")
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_deploy()
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
