extends Control

var _selected_id := "pistol"
var _cards := {}
var _card_tweens := {}
var _matrix_bg: Control
var _matrix_columns: Array = []

const MATRIX_COL_SPACING := 34.0
const MATRIX_ROW_SPACING := 28.0
const MATRIX_FONT_SIZE := 16
const MATRIX_BASE_COLOR := Color(0.1, 0.8, 0.4, 0.5)
const MINECRAFT_FONT := preload("res://Minecraft.ttf")

func _ready() -> void:
	_selected_id = GunDatabase.selected_gun_id
	randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	$Background.color = Color(0.04, 0.05, 0.09)
	$Background.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Background.visible = false

	_create_matrix_background()
	move_child(_matrix_bg, 0)

	$TitleLabel.add_theme_font_override("font", MINECRAFT_FONT)
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
	$SubLabel.visible = false

	# Position gun grid in center
	$GunGrid.set_anchors_preset(Control.PRESET_CENTER)
	$GunGrid.offset_left = -280.0
	$GunGrid.offset_top = -90.0
	$GunGrid.offset_right = 280.0
	$GunGrid.offset_bottom = 70.0
	$GunGrid.alignment = BoxContainer.ALIGNMENT_CENTER
	$GunGrid.add_theme_constant_override("separation", 12)

	$DeployBtn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	$DeployBtn.offset_left = -140.0
	$DeployBtn.offset_right = 140.0
	$DeployBtn.offset_top = -60.0
	$DeployBtn.offset_bottom = -20.0
	_style_button($DeployBtn, 16)
	$DeployBtn.pressed.connect(_on_deploy)
	$DeployBtn.mouse_entered.connect(func(): AudioManager.play_sfx_with_options("hover", -20.0, 0.7, 1.3))

	$BackBtn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	$BackBtn.offset_left = -240.0
	$BackBtn.offset_right = -150.0
	$BackBtn.offset_top = -60.0
	$BackBtn.offset_bottom = -20.0
	_style_button($BackBtn, 12)
	$BackBtn.pressed.connect(func():
		ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")
	)
	$BackBtn.mouse_entered.connect(func(): AudioManager.play_sfx_with_options("hover", -20.0, 0.7, 1.3))

	_build_cards()

func _create_matrix_background() -> void:
	if is_instance_valid(_matrix_bg):
		_matrix_bg.queue_free()
	_matrix_columns.clear()

	_matrix_bg = Control.new()
	_matrix_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_matrix_bg)

	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color(0.03, 0.06, 0.05, 1.0)
	_matrix_bg.add_child(bg_rect)

	var viewport_size = get_viewport_rect().size
	var cols = int(ceil(viewport_size.x / MATRIX_COL_SPACING)) + 2
	var rows = int(ceil(viewport_size.y / MATRIX_ROW_SPACING)) + 3

	for col in range(cols):
		var x_pos = col * MATRIX_COL_SPACING + 8.0
		var direction = -1.0 if (col % 2 == 0) else 1.0
		var speed = randf_range(22.0, 58.0)
		var labels: Array = []

		for row in range(rows):
			var lbl = Label.new()
			lbl.text = str(randi() % 2)
			lbl.add_theme_font_override("font", MINECRAFT_FONT)
			lbl.add_theme_font_size_override("font_size", MATRIX_FONT_SIZE)
			lbl.add_theme_color_override("font_color", MATRIX_BASE_COLOR)
			lbl.position = Vector2(x_pos, row * MATRIX_ROW_SPACING + randf_range(-8.0, 8.0))
			_matrix_bg.add_child(lbl)
			labels.append(lbl)

		_matrix_columns.append({
			"labels": labels,
			"speed": speed,
			"direction": direction
		})

func _process(delta: float) -> void:
	if _matrix_columns.is_empty():
		return

	var viewport_h = get_viewport_rect().size.y

	for column in _matrix_columns:
		var speed: float = column["speed"]
		var direction: float = column["direction"]
		var labels: Array = column["labels"]

		for lbl in labels:
			var y = lbl.position.y + (speed * direction * delta)

			if direction > 0.0 and y > viewport_h + MATRIX_ROW_SPACING:
				y = -MATRIX_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif direction < 0.0 and y < -MATRIX_ROW_SPACING:
				y = viewport_h + MATRIX_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif randi() % 90 == 0:
				lbl.text = str(randi() % 2)

			lbl.position.y = y

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
	card.custom_minimum_size = Vector2(110, 140)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Gun image — shows your actual sprite
	var tex = TextureRect.new()
	tex.custom_minimum_size = Vector2(100, 80)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var path = gun.get("preview_sprite", gun.get("sprite", ""))
	if ResourceLoader.exists(path):
		tex.texture = load(path)
	vbox.add_child(tex)

	# Gun name
	var name_lbl = Label.new()
	name_lbl.text = gun["display_name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", MINECRAFT_FONT)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", gun.get("color", Color.WHITE))
	vbox.add_child(name_lbl)

	# Stats
	var stats = Label.new()
	stats.text = "DMG:%d  AMMO:%d" % [gun["damage"], gun["max_ammo"]]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_override("font", MINECRAFT_FONT)
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	vbox.add_child(stats)

	# Select button
	var btn = Button.new()
	btn.text = "SELECT"
	btn.add_theme_font_override("font", MINECRAFT_FONT)
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
		var target_modulate := Color(0.5, 0.5, 0.5, 1)
		var target_scale := Vector2(1.0, 1.0)
		if gid == _selected_id:
			# Highlight selected card with gun's color
			panel.add_theme_stylebox_override("panel", _make_highlight_style(gun["color"]))
			target_modulate = Color(1, 1, 1, 1)
			target_scale = Vector2(1.06, 1.06)
		else:
			panel.remove_theme_stylebox_override("panel")
		panel.pivot_offset = panel.size * 0.5
		if _card_tweens.has(panel):
			var existing: Tween = _card_tweens[panel]
			if is_instance_valid(existing):
				existing.kill()
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "self_modulate", target_modulate, 0.15)
		tween.parallel().tween_property(panel, "scale", target_scale, 0.15)
		_card_tweens[panel] = tween

func _make_highlight_style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15)
	s.border_color = color
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	return s

func _style_button(btn: Button, size: int, color: Color = Color(0.2, 1.0, 0.5)) -> void:
	btn.add_theme_font_override("font", MINECRAFT_FONT)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.7))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.8, 0.3))
	btn.add_theme_color_override("font_focus_color", Color(0.3, 1.0, 0.6))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 1)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.02, 0.08, 0.05, 0.8)
	stylebox.border_color = color
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.set_corner_radius_all(4)
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 6
	stylebox.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", stylebox)
	var hover_box = stylebox.duplicate()
	hover_box.bg_color = Color(0.05, 0.15, 0.08, 0.9)
	btn.add_theme_stylebox_override("hover", hover_box)
	var pressed_box = stylebox.duplicate()
	pressed_box.bg_color = Color(0.02, 0.06, 0.03, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_box)
	btn.pressed.connect(func(): AudioManager.play_sfx_with_options("click", -15.0, 0.7, 1.3))

func _on_deploy() -> void:
	GunDatabase.selected_gun_id = _selected_id
	PlayerState.selected_gun_id = _selected_id
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		ScreenFX.transition_to_scene("res://scenes/levels/Level2.tscn")
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_deploy()
		if event.keycode == KEY_ESCAPE:
			ScreenFX.transition_to_scene("res://scenes/ui/MainMenu.tscn")
