## ScreenFX.gd
extends Node

var _camera: Camera2D = null
var _overlay_layer: CanvasLayer
var _glitch_active := false
var _shake_tween: Tween
var _glitch_timer := 0.0
var _integrity_ratio := 1.0
var _vignette: ColorRect
var _bloom_overlay: ColorRect
var _bloom_mat: ShaderMaterial
var _slowmo_end_ms := 0
var _timescale_override_active := false
var _timescale_override := 1.0
var _scene_transitioning := false
var _transition_overlay: Control
var _transition_columns: Array = []
var _transition_is_exiting := false
var _transition_exit_elapsed := 0.0

const TRANSITION_COL_SPACING := 34.0
const TRANSITION_ROW_SPACING := 28.0
const TRANSITION_FONT_SIZE := 18
const TRANSITION_BASE_COLOR := Color(0.3, 1.0, 0.55, 0.85)
const TRANSITION_FADE_IN := 0.6
const TRANSITION_FADE_OUT := 1.5
const TRANSITION_TAIL_SPEED_START := 0.45
const TRANSITION_TAIL_FADE_START := 0.68
const TRANSITION_TAIL_MAX_SPEED_MULT := 4.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 99
	add_child(_overlay_layer)
	_setup_bloom_overlay()
	_setup_vignette()
	EventBus.integrity_changed.connect(_on_integrity_changed)
	EventBus.rule_conflict_detected.connect(func(_a, _b): glitch_flash(0.2))
	EventBus.action_exploited.connect(func(_a, _b): exploit_flash())

func register_camera(cam: Camera2D) -> void:
	_camera = cam

func _process(delta: float) -> void:
	# Ambient glitch based on system integrity
	if _integrity_ratio < 0.5:
		_glitch_timer -= delta
		if _glitch_timer <= 0.0:
			var freq = lerp(4.0, 0.3, _integrity_ratio / 0.5)
			_glitch_timer = randf_range(freq * 0.5, freq)
			if _integrity_ratio < 0.25:
				glitch_flash(0.08)
			else:
				_scanline_flash()
	_update_slowmo()
	_update_transition_overlay(delta)
	_update_bloom_overlay()

func _exit_tree() -> void:
	_timescale_override_active = false
	_timescale_override = 1.0
	Engine.time_scale = 1.0

func slow_motion_pulse(scale: float = 0.3, duration: float = 0.22) -> void:
	if _timescale_override_active:
		return
	Engine.time_scale = clampf(scale, 0.05, 1.0)
	var now_ms := Time.get_ticks_msec()
	var duration_ms := int(maxf(duration, 0.01) * 1000.0)
	_slowmo_end_ms = max(_slowmo_end_ms, now_ms) + duration_ms
	AudioManager.play_sfx("freesound_community-matrix-jump")

func set_time_scale_override(scale: float) -> void:
	_timescale_override_active = true
	_timescale_override = clampf(scale, 0.05, 1.0)
	Engine.time_scale = _timescale_override

func clear_time_scale_override() -> void:
	_timescale_override_active = false
	_timescale_override = 1.0
	Engine.time_scale = 1.0

func _update_slowmo() -> void:
	if _timescale_override_active:
		Engine.time_scale = _timescale_override
		return
	if Engine.time_scale >= 1.0:
		return
	if Time.get_ticks_msec() >= _slowmo_end_ms:
		Engine.time_scale = 1.0

func screen_shake(intensity: float = 6.0, duration: float = 0.25) -> void:
	if not is_instance_valid(_camera):
		return
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var origin = _camera.offset
	var steps = int(duration / 0.04)
	for i in steps:
		_shake_tween.tween_callback(func():
			if is_instance_valid(_camera):
				_camera.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		)
		_shake_tween.tween_interval(0.04)
	_shake_tween.tween_callback(func():
		if is_instance_valid(_camera): _camera.offset = origin
	)

func flash_screen(color: Color = Color(1, 0, 0, 0.4), duration: float = 0.2) -> void:
	var r = ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(r)
	var t = create_tween()
	t.tween_property(r, "modulate:a", 0.0, duration)
	t.tween_callback(r.queue_free)

func glitch_flash(duration: float = 0.12) -> void:
	# Horizontal scanline distortion effect
	for i in 3:
		var r = ColorRect.new()
		r.color = Color(randf(), randf(), randf(), 0.15)
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.offset_top = randf_range(0, 160)
		r.offset_bottom = r.offset_top + randf_range(2, 12)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay_layer.add_child(r)
		var t = create_tween()
		t.tween_interval(randf_range(0, duration * 0.3))
		t.tween_property(r, "modulate:a", 0.0, duration)
		t.tween_callback(r.queue_free)
	screen_shake(3.0, duration)

func exploit_flash() -> void:
	flash_screen(Color(0.0, 1.0, 0.5, 0.5), 0.32)
	screen_shake(4.0, 0.2)
	AudioManager.play_sfx("exploit")

func _scanline_flash() -> void:
	var r = ColorRect.new()
	r.color = Color(0.0, 1.0, 0.45, 0.1)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(r)
	var t = create_tween()
	t.tween_property(r, "modulate:a", 0.0, 0.15)
	t.tween_callback(r.queue_free)

func transition_to_scene(scene_path: String, fade_in_time: float = -1.0, fade_out_time: float = -1.0) -> void:
	if _scene_transitioning:
		return
	var in_time = fade_in_time if fade_in_time >= 0 else TRANSITION_FADE_IN
	var out_time = fade_out_time if fade_out_time >= 0 else TRANSITION_FADE_OUT
	_scene_transitioning = true
	_transition_is_exiting = false
	_transition_exit_elapsed = 0.0
	_transition_overlay = _create_matrix_transition_overlay()
	_transition_overlay.modulate.a = 0.0
	_overlay_layer.add_child(_transition_overlay)

	var fade_in = create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(_transition_overlay, "modulate:a", 1.0, in_time)
	fade_in.finished.connect(func():
		var err := get_tree().change_scene_to_file(scene_path)
		if err != OK:
			push_error("Scene transition failed: %s" % scene_path)
			_finish_scene_transition()
			return
		_transition_is_exiting = true
		_transition_exit_elapsed = 0.0
		var fade_out = create_tween()
		fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fade_out.tween_interval(0.04)
		fade_out.tween_property(_transition_overlay, "modulate:a", 0.0, out_time)
		fade_out.finished.connect(_finish_scene_transition, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)

func transition_to_scene_with_black_fade(scene_path: String, black_in_time: float = 0.5, matrix_display_time: float = 0.8, black_out_time: float = 0.5) -> void:
	if _scene_transitioning:
		return
	_scene_transitioning = true
	
	# Create black fade overlay
	var black_rect = ColorRect.new()
	black_rect.color = Color.BLACK
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.modulate.a = 0.0
	_overlay_layer.add_child(black_rect)
	
	# Fade to black
	var fade_to_black = create_tween()
	fade_to_black.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_to_black.tween_property(black_rect, "modulate:a", 1.0, black_in_time)
	fade_to_black.finished.connect(func():
		# Create and show matrix overlay
		_transition_overlay = _create_matrix_transition_overlay()
		_transition_overlay.modulate.a = 0.0
		_overlay_layer.add_child(_transition_overlay)
		
		# Fade in matrix
		var fade_in_matrix = create_tween()
		fade_in_matrix.tween_property(_transition_overlay, "modulate:a", 1.0, 0.2)
		fade_in_matrix.tween_interval(matrix_display_time)
		fade_in_matrix.tween_callback(func():
			var err := get_tree().change_scene_to_file(scene_path)
			if err != OK:
				push_error("Scene transition failed: %s" % scene_path)
				_finish_scene_transition()
				black_rect.queue_free()
				return
			
			# Fade out matrix and black
			_transition_is_exiting = true
			_transition_exit_elapsed = 0.0
			var fade_out = create_tween()
			fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			fade_out.tween_property(_transition_overlay, "modulate:a", 0.0, black_out_time * 0.5)
			fade_out.parallel().tween_property(black_rect, "modulate:a", 0.0, black_out_time)
			fade_out.finished.connect(func():
				_finish_scene_transition()
				black_rect.queue_free()
			, CONNECT_ONE_SHOT)
		)
	, CONNECT_ONE_SHOT)

func _create_matrix_transition_overlay() -> Control:
	_transition_columns.clear()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.08, 0.05, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var viewport_size = get_viewport().get_visible_rect().size
	var cols = int(ceil(viewport_size.x / TRANSITION_COL_SPACING)) + 2
	var rows = int(ceil(viewport_size.y / TRANSITION_ROW_SPACING)) + 3
	
	var minecraft_font = load("res://Minecraft.ttf") as FontFile

	for col in range(cols):
		var x_pos = col * TRANSITION_COL_SPACING + 8.0
		var direction = -1.0 if (col % 2 == 0) else 1.0
		var speed = randf_range(120.0, 260.0)
		var labels: Array = []
		for row in range(rows):
			var lbl = Label.new()
			lbl.text = str(randi() % 2)
			lbl.position = Vector2(x_pos, row * TRANSITION_ROW_SPACING + randf_range(-10.0, 10.0))
			lbl.add_theme_font_override("font", minecraft_font)
			lbl.add_theme_font_size_override("font_size", TRANSITION_FONT_SIZE)
			lbl.add_theme_color_override("font_color", TRANSITION_BASE_COLOR)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(lbl)
			labels.append(lbl)
		_transition_columns.append({
			"labels": labels,
			"speed": speed,
			"direction": direction
		})
	return root

func _update_transition_overlay(delta: float) -> void:
	if _transition_columns.is_empty():
		return
	var speed_mult := 1.0
	var label_alpha_mult := 1.0
	if _transition_is_exiting:
		_transition_exit_elapsed += delta
		var exit_ratio := clampf(_transition_exit_elapsed / TRANSITION_FADE_OUT, 0.0, 1.0)
		var tail_speed_ratio := clampf((exit_ratio - TRANSITION_TAIL_SPEED_START) / (1.0 - TRANSITION_TAIL_SPEED_START), 0.0, 1.0)
		var tail_fade_ratio := clampf((exit_ratio - TRANSITION_TAIL_FADE_START) / (1.0 - TRANSITION_TAIL_FADE_START), 0.0, 1.0)
		speed_mult = lerpf(1.0, TRANSITION_TAIL_MAX_SPEED_MULT, tail_speed_ratio)
		label_alpha_mult = 1.0 - tail_fade_ratio
	var viewport_h = get_viewport().get_visible_rect().size.y
	for column in _transition_columns:
		var speed: float = column["speed"]
		var direction: float = column["direction"]
		var labels: Array = column["labels"]
		for lbl in labels:
			if not is_instance_valid(lbl):
				continue
			var y = lbl.position.y + (speed * speed_mult * direction * delta)
			if direction > 0.0 and y > viewport_h + TRANSITION_ROW_SPACING:
				y = -TRANSITION_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif direction < 0.0 and y < -TRANSITION_ROW_SPACING:
				y = viewport_h + TRANSITION_ROW_SPACING
				lbl.text = str(randi() % 2)
			elif randi() % 24 == 0:
				lbl.text = str(randi() % 2)
			lbl.position.y = y
			lbl.modulate.a = label_alpha_mult

func _finish_scene_transition() -> void:
	if is_instance_valid(_transition_overlay):
		_transition_overlay.queue_free()
	_transition_overlay = null
	_transition_columns.clear()
	_transition_is_exiting = false
	_transition_exit_elapsed = 0.0
	_scene_transitioning = false

func _on_integrity_changed(new_val: float, _delta: float) -> void:
	var max_integrity := RuleManager.get_max_integrity() if RuleManager.has_method("get_max_integrity") else 1.0
	_integrity_ratio = new_val / max_integrity if max_integrity > 0.0 else 0.0

func _setup_bloom_overlay() -> void:
	_bloom_overlay = ColorRect.new()
	_bloom_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloom_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(0.05, 1.0, 0.55, 1.0);
uniform float strength : hint_range(0.0, 0.6) = 0.12;
uniform float pulse_strength : hint_range(0.0, 0.3) = 0.06;
uniform float radius : hint_range(0.2, 2.0) = 1.25;
uniform float scanline_density : hint_range(20.0, 300.0) = 140.0;

void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - vec2(1.0);
	float dist = length(uv);
	float radial = clamp(1.0 - (dist / radius), 0.0, 1.0);
	radial = pow(radial, 1.6);

	float pulse = 0.5 + 0.5 * sin(TIME * 2.8);
	float scanline = 0.7 + 0.3 * sin((SCREEN_UV.y + TIME * 0.14) * scanline_density);
	float glow = (strength + pulse_strength * pulse) * radial * scanline;

	COLOR = vec4(glow_color.rgb, glow);
}
"""

	_bloom_mat = ShaderMaterial.new()
	_bloom_mat.shader = shader
	_bloom_overlay.material = _bloom_mat
	_overlay_layer.add_child(_bloom_overlay)

func _update_bloom_overlay() -> void:
	if _bloom_mat == null:
		return
	var stress := clampf(1.0 - _integrity_ratio, 0.0, 1.0)
	_bloom_mat.set_shader_parameter("strength", lerpf(0.10, 0.22, stress))
	_bloom_mat.set_shader_parameter("pulse_strength", lerpf(0.05, 0.14, stress))

func set_vignette_visible(visible: bool) -> void:
	if is_instance_valid(_vignette):
		_vignette.visible = visible

func _setup_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform float radius : hint_range(0.0, 1.5) = 0.64;
uniform float softness : hint_range(0.01, 1.0) = 0.22;

void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - vec2(1.0);
	float dist = length(uv);
	float edge = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(vignette_color.rgb, edge * strength);
}
"""

	var mat := ShaderMaterial.new()
	mat.shader = shader
	_vignette.material = mat
	_overlay_layer.add_child(_vignette)
