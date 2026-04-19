## ScreenFX.gd
extends Node

var _camera: Camera2D = null
var _overlay_layer: CanvasLayer
var _glitch_active := false
var _shake_tween: Tween
var _glitch_timer := 0.0
var _integrity := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 99
	add_child(_overlay_layer)
	EventBus.integrity_changed.connect(_on_integrity_changed)
	EventBus.rule_conflict_detected.connect(func(_a, _b): glitch_flash(0.2))
	EventBus.action_exploited.connect(func(_a, _b): exploit_flash())

func register_camera(cam: Camera2D) -> void:
	_camera = cam

func _process(delta: float) -> void:
	# Ambient glitch based on system integrity
	if _integrity < 0.5:
		_glitch_timer -= delta
		if _glitch_timer <= 0.0:
			var freq = lerp(4.0, 0.3, _integrity / 0.5)
			_glitch_timer = randf_range(freq * 0.5, freq)
			if _integrity < 0.25:
				glitch_flash(0.08)
			else:
				_scanline_flash()

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
	flash_screen(Color(0.0, 1.0, 0.5, 0.35), 0.3)
	screen_shake(4.0, 0.2)
	AudioManager.play_sfx("exploit")

func _scanline_flash() -> void:
	var r = ColorRect.new()
	r.color = Color(0.0, 1.0, 0.4, 0.06)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(r)
	var t = create_tween()
	t.tween_property(r, "modulate:a", 0.0, 0.15)
	t.tween_callback(r.queue_free)

func _on_integrity_changed(new_val: float, _delta: float) -> void:
	_integrity = new_val
