extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const INTRO_MUSIC := "freesound_community-matrix-redux-78819"

const MATRIX_COL_SPACING := 34.0
const MATRIX_ROW_SPACING := 28.0
const MATRIX_FONT_SIZE := 16
const MATRIX_BASE_COLOR := Color(0.1, 0.85, 0.45, 0.42)

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const WORM_SCENE := preload("res://scenes/enemy/worm.tscn")
const ENEMY_LASER := preload("res://scenes/enemy/EnemyLaser.tscn")

var _matrix_bg: Control
var _matrix_columns: Array = []
var _transition_started := false
var _intro_tween: Tween

# Demo nodes
var _canvas_layer: CanvasLayer
var _demo_container: Node2D
var _player: Node = null
var _enemy: Node = null
var _hud_label: Label = null
var _demo_camera: Camera2D = null

@onready var _logo: TextureRect = $Center/VBox/Logo
@onready var _title: Label = $Center/VBox/Title
@onready var _subtitle: Label = $Center/VBox/Subtitle
@onready var _status: Label = $Center/VBox/Status
@onready var _scanline: ColorRect = $Scanline
@onready var _flash: ColorRect = $Flash

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_static_ui()
	_build_matrix_background()
	move_child(_matrix_bg, 1)

	# create a CanvasLayer so demo sprites render above the matrix background
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1
	add_child(_canvas_layer)

	_demo_container = Node2D.new()
	_canvas_layer.add_child(_demo_container)

	_setup_demo()

	AudioManager.play_music_by_file(INTRO_MUSIC)
	_play_intro_sequence()

func _process(delta: float) -> void:
	if _matrix_columns.is_empty():
		return

	var viewport_h = get_viewport_rect().size.y

	for column in _matrix_columns:
		var speed: float = column["speed"]
		var direction: float = column["direction"]
		var labels: Array = column["labels"]

		for lbl in labels:
			if not is_instance_valid(lbl):
				continue

			var y = lbl.position.y + (speed * direction * delta)
			if direction > 0.0 and y > viewport_h + MATRIX_ROW_SPACING:
				y = -MATRIX_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif direction < 0.0 and y < -MATRIX_ROW_SPACING:
				y = viewport_h + MATRIX_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif randi() % 75 == 0:
				lbl.text = str(randi() % 2)

			lbl.position.y = y

func _style_static_ui() -> void:
	if has_node("Background"):
		$Background.color = Color(0.03, 0.05, 0.08, 1.0)

	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(640, 200)
	_logo.modulate = Color(1, 1, 1, 0)
	_logo.scale = Vector2(0.84, 0.84)

	_style_label(_title, 30, Color(0.42, 1.0, 0.72))
	_title.modulate = Color(1, 1, 1, 0)

	_style_label(_subtitle, 16, Color(0.82, 0.96, 0.9))
	_subtitle.modulate = Color(1, 1, 1, 0)

	_style_label(_status, 14, Color(0.5, 0.7, 0.6))
	_status.modulate = Color(1, 1, 1, 0)

	_scanline.modulate = Color(0.2, 1.0, 0.5, 0.0)
	_flash.modulate = Color(0.9, 1.0, 0.95, 0.0)

func _style_label(lbl: Label, size: int, color: Color) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_matrix_background() -> void:
	if is_instance_valid(_matrix_bg):
		_matrix_bg.queue_free()
	_matrix_columns.clear()

	_matrix_bg = Control.new()
	_matrix_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_matrix_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_matrix_bg)

	var bg_rect := ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = Color(0.02, 0.06, 0.05, 1.0)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_matrix_bg.add_child(bg_rect)

	var viewport_size = get_viewport_rect().size
	var cols = int(ceil(viewport_size.x / MATRIX_COL_SPACING)) + 2
	var rows = int(ceil(viewport_size.y / MATRIX_ROW_SPACING)) + 3

	for col in range(cols):
		var x_pos = col * MATRIX_COL_SPACING + 8.0
		var direction = -1.0 if (col % 2 == 0) else 1.0
		var speed = randf_range(26.0, 62.0)
		var labels: Array = []

		for row in range(rows):
			var lbl := Label.new()
			lbl.text = str(randi() % 2)
			lbl.add_theme_font_size_override("font_size", MATRIX_FONT_SIZE)
			lbl.add_theme_color_override("font_color", MATRIX_BASE_COLOR)
			lbl.position = Vector2(x_pos, row * MATRIX_ROW_SPACING + randf_range(-8.0, 8.0))
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_matrix_bg.add_child(lbl)
			labels.append(lbl)

		_matrix_columns.append({
			"labels": labels,
			"speed": speed,
			"direction": direction
		})

func _setup_demo() -> void:
	# create a Camera2D for the demo and center it on screen
	_demo_camera = Camera2D.new()
	_demo_camera.current = true
	_demo_camera.position = get_viewport_rect().size * 0.5
	_demo_camera.zoom = Vector2(1.15, 1.15)
	_demo_camera.position_smoothing_enabled = true
	_demo_camera.position_smoothing_speed = 6.0
	_demo_container.add_child(_demo_camera)

	# HUD label
	_hud_label = Label.new()
	_hud_label.text = "ACCESS: 0%"
	_hud_label.add_theme_font_size_override("font_size", 18)
	_hud_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_hud_label.add_theme_font_size_override("font_size", 18)
	# anchor across the top and center the text
	_hud_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.custom_minimum_size = Vector2(0, 28) # give some top padding
	add_child(_hud_label)

	# instantiate player and enemy into demo container
	_player = PLAYER_SCENE.instantiate()
	_enemy = WORM_SCENE.instantiate()

	# position them offscreen initially
	var vp = get_viewport_rect().size
	_player.position = Vector2(-220, vp.y * 0.62)
	_enemy.position = Vector2(vp.x + 220, vp.y * 0.62)

	# ensure they start invisible
	if _player.has_method("set_modulate"):
		_player.modulate = Color(1,1,1,0)
	else:
		# many nodes have modulate property at root, try setting on a Sprite child
		pass

	if _enemy.has_method("set_modulate"):
		_enemy.modulate = Color(1,1,1,0)

	_demo_container.add_child(_player)
	_demo_container.add_child(_enemy)

func _play_intro_sequence() -> void:
	# slower timings for dramatic effect
	_scanline.position = Vector2(0, -24)
	_scanline.size = Vector2(get_viewport_rect().size.x, 6)
	_flash.size = get_viewport_rect().size

	_intro_tween = create_tween()
	_intro_tween.tween_callback(func():
		AudioManager.play_sfx_with_options("whoosh", -18.0, 0.95, 1.02)
	)
	_intro_tween.tween_interval(0.28)
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(_logo, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_logo, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_title, "modulate:a", 1.0, 0.6)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_interval(0.6)
	_intro_tween.tween_callback(func():
		AudioManager.play_sfx("dragon-studio-cinematic-boom")
		_flash.modulate.a = 0.8
		var flash_tween := create_tween()
		flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.4)
	)
	_intro_tween.tween_interval(0.28)
	_intro_tween.tween_callback(func():
		_subtitle.text = "BOOT SEQUENCE // BREACH LINK ESTABLISHED"
		_subtitle.modulate.a = 1.0
	)
	_intro_tween.tween_interval(1.2)
	_intro_tween.tween_callback(func():
		_status.text = "SYNCING INTERFACE"
		_status.modulate.a = 1.0
		_start_scanline_sweep()
		# start the player/enemy demo shortly after sync, slower
		var demo_delay := create_tween()
		demo_delay.tween_interval(1.6)
		demo_delay.tween_callback(_start_demo_sequence)
	)
	_intro_tween.tween_interval(2.4)
	_intro_tween.tween_callback(_transition_to_menu)

func _start_scanline_sweep() -> void:
	if is_instance_valid(_scanline):
		_scanline.modulate.a = 0.34
		_scanline.position = Vector2(0, -24)
		var sweep := create_tween()
		sweep.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sweep.tween_property(_scanline, "position", Vector2(0, get_viewport_rect().size.y + 24.0), 0.85)
		sweep.tween_callback(func():
			if is_instance_valid(_scanline):
				_scanline.modulate.a = 0.0
		)

func _start_demo_sequence() -> void:
	# Fade in and move player to center (slower pacing)
	var vp = get_viewport_rect().size
	_player.modulate = Color(1,1,1,0)
	_enemy.modulate = Color(1,1,1,0)

	var t := create_tween()
	# camera slight zoom-in during intro
	if is_instance_valid(_demo_camera):
		var cam_zoom_t := _demo_camera.create_tween()
		cam_zoom_t.tween_property(_demo_camera, "zoom", Vector2(1.0,1.0), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# player enters
	t.tween_property(_player, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_player, "position", Vector2(vp.x * 0.36, vp.y * 0.62), 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# enemy enters slightly later and then pressures the player
	t.tween_interval(0.6)
	t.tween_callback(func():
		AudioManager.play_sfx_with_options("enemy-approach", -12.0, 0.95, 1.0)
	)
	t.tween_property(_enemy, "modulate:a", 1.0, 0.6)
	t.tween_property(_enemy, "position", Vector2(vp.x * 0.66, vp.y * 0.62), 1.8).set_trans(Tween.TRANS_LINEAR)

	# enemy lunges closer (threatening move)
	t.tween_interval(0.9)
	t.tween_callback(func():
		var lunge := create_tween()
		lunge.tween_property(_enemy, "position", Vector2(vp.x * 0.56, vp.y * 0.62), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		AudioManager.play_sfx_with_options("enemy-lunge", -10.0, 1.0, 1.0)
		if is_instance_valid(_demo_camera):
			var caml := _demo_camera.create_tween()
			caml.tween_property(_demo_camera, "zoom", Vector2(0.88,0.88), 0.45)
			caml.tween_interval(0.6)
			caml.tween_property(_demo_camera, "zoom", Vector2(1.0,1.0), 0.6)
	)

	# enemy fires a laser toward the player
	t.tween_interval(1.1)
	t.tween_callback(func():
		AudioManager.play_sfx_with_options("laser-shoot", -6.0, 1.0, 1.0)
		# spawn a projectile from the enemy aimed at the player
		if is_instance_valid(_enemy) and is_instance_valid(_player):
			var laser = ENEMY_LASER.instantiate()
			get_tree().current_scene.add_child(laser)
			laser.global_position = _enemy.global_position
			var dir = (_player.global_position - _enemy.global_position).normalized()
			if laser.has_method("setup"):
				laser.setup(_enemy, dir)
			# ensure it reaches in this slowed demo
			laser.speed = 360.0
			laser.lifetime = 2.6
			# if player exists, simulate near hit/damage
			if _player.has_method("take_damage"):
				# small damage to show stakes
				_player.take_damage(8)
			# visual cue on player
			ScreenFX.screen_shake(6.0, 0.22)
			ScreenFX.flash_screen(Color(1.0, 0.15, 0.15, 0.35), 0.18)
	)

	# enemy disintegrates after a short pause
	t.tween_interval(1.6)
	t.tween_callback(func():
		var die := create_tween()
		die.tween_property(_enemy, "scale", Vector2(1.6,1.6), 0.9).set_trans(Tween.TRANS_BOUNCE)
		die.tween_property(_enemy, "modulate:a", 0.0, 1.0)
		# HUD progress slower
		var hud_t := create_tween()
		for i in range(1, 7):
			var pct = i * 16
			hud_t.tween_interval(0.12)
			hud_t.tween_callback(func(pct_value=pct):
				_hud_label.text = "ACCESS: %d%%" % [pct_value]
			)
		# final text
		hud_t.tween_interval(0.5)
		hud_t.tween_callback(func():
			_hud_label.text = "ACCESS: GRANTED"
			AudioManager.play_sfx_with_options("success-chime", -6.0, 1.0, 1.0)
		)
	)

func _transition_to_menu() -> void:
	if _transition_started:
		return
	_transition_started = true
	ScreenFX.transition_to_scene(MAIN_MENU_SCENE, 0.28, 0.48)
