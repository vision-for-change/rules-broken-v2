## AudioManager.gd
extends Node

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _fade_tween: Tween
var _current_track := ""

const MUSIC_VOL   = -10.0
const MUSIC_VOL_MENU = -3.0
const FADE_TIME   = 1.0
const INITIAL_POOL_SIZE = 16
const SFX_DIRS := [
	"res://assets/audio/sfx",
	"res://Sounds",
]
const SFX_EXTS := [".wav", ".ogg", ".mp3"]
const SFX_ALIASES := {
	"universfield-gunshot": "universfield-gunshot-352466",
	"universfield-magic-teleport-whoosh": "universfield-magic-teleport-whoosh-352764",
	"freesound_community-glass-shatter": "freesound_community-glass-shatter-3-100155",
	"dragon-studio-cinematic-boom": "dragon-studio-cinematic-boom-454254",
	"whoosh": "dragon-studio-simple-whoosh-382724",
	"explosive-glass-shatter": "daviddumaisaudio-explosive-glass-shattering-09-190267",
	"hover": "miraclei-sample_hover_subtle02_kofi_by_miraclei-364170",
	"click": "miraclei-sample_hover_subtle04_kofi_by_miraclei-364171",
}

# Track mapping: system state -> track name
const STATE_TRACKS := {
	"stable":   "music_stable",
	"unstable": "music_unstable",
	"critical": "music_critical",
	"alert":    "music_alert",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in INITIAL_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	# Connect to system events for automatic music transitions
	EventBus.system_unstable.connect(func(): switch_music("unstable"))
	EventBus.system_critical.connect(func(): switch_music("critical"))
	EventBus.system_stable.connect(func(): switch_music("stable"))
	EventBus.watchdog_alert.connect(func(_a, _b, _c): switch_music("alert"))

func _process(_delta: float) -> void:
	# Update pitch to match current time scale
	var pitch = Engine.time_scale
	if _music:
		_music.pitch_scale = pitch
		# Safeguard: restart music if it stopped unexpectedly
		if _current_track != "" and not _music.playing:
			_music.play()
	
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.pitch_scale = pitch

func play_music(state: String) -> void:
	var track = STATE_TRACKS.get(state, "music_stable")
	if _current_track == track and _music.playing:
		return
	_current_track = track
	var path = "res://assets/audio/music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		return
	_music.stream = load(path)
	if _music.stream:
		_music.stream.set_loop(true)
	_music.volume_db = MUSIC_VOL
	_music.play()

func play_music_by_file(file_name: String) -> void:
	if _current_track == file_name and _music.playing:
		return
	for dir_path in SFX_DIRS:
		for ext in SFX_EXTS:
			var p = "%s/%s%s" % [dir_path, file_name, ext]
			if ResourceLoader.exists(p):
				_current_track = file_name
				_music.stream = load(p)
				if _music.stream:
					_music.stream.set_loop(true)
				_music.volume_db = MUSIC_VOL
				_music.play()
				return

func switch_music(state: String) -> void:
	var track = STATE_TRACKS.get(state, "music_stable")
	if _current_track == track and _music.playing:
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_music, "volume_db", -80.0, FADE_TIME * 0.4)
	_fade_tween.tween_callback(func():
		_current_track = track
		var path = "res://assets/audio/music/%s.ogg" % track
		if ResourceLoader.exists(path):
			_music.stream = load(path)
			_music.play()
			_music.volume_db = -80.0
			var t2 = create_tween()
			t2.tween_property(_music, "volume_db", MUSIC_VOL, FADE_TIME * 0.4)
	)

func stop_music() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_music, "volume_db", -80.0, FADE_TIME * 0.4)
	_fade_tween.tween_callback(func():
		_music.stop()
		_current_track = ""
	)

func stop_music_immediate() -> void:
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	_music.stop()
	_current_track = ""

func play_sfx(name: String) -> void:
	var resolved_name: String = name
	if SFX_ALIASES.has(name):
		resolved_name = str(SFX_ALIASES[name])
	var candidates: Array[String] = [resolved_name]
	if resolved_name != name:
		candidates.append(name)
	for base_name in candidates:
		for dir_path in SFX_DIRS:
			for ext in SFX_EXTS:
				var p = "%s/%s%s" % [dir_path, base_name, ext]
				if ResourceLoader.exists(p):
					var player = _free_sfx()
					player.stream = load(p)
					player.play()
					return

func play_sfx_with_volume(name: String, volume_db: float) -> void:
	var resolved_name: String = name
	if SFX_ALIASES.has(name):
		resolved_name = str(SFX_ALIASES[name])
	var candidates: Array[String] = [resolved_name]
	if resolved_name != name:
		candidates.append(name)
	for base_name in candidates:
		for dir_path in SFX_DIRS:
			for ext in SFX_EXTS:
				var p = "%s/%s%s" % [dir_path, base_name, ext]
				if ResourceLoader.exists(p):
					var player = _free_sfx()
					player.stream = load(p)
					player.volume_db = volume_db
					player.play()
					return

func play_sfx_with_pitch(name: String, pitch_min: float, pitch_max: float) -> void:
	var resolved_name: String = name
	if SFX_ALIASES.has(name):
		resolved_name = str(SFX_ALIASES[name])
	var candidates: Array[String] = [resolved_name]
	if resolved_name != name:
		candidates.append(name)
	for base_name in candidates:
		for dir_path in SFX_DIRS:
			for ext in SFX_EXTS:
				var p = "%s/%s%s" % [dir_path, base_name, ext]
				if ResourceLoader.exists(p):
					var player = _free_sfx()
					player.stream = load(p)
					player.pitch_scale = randf_range(pitch_min, pitch_max)
					player.play()
					return

func play_sfx_with_options(name: String, volume_db: float = 0.0, pitch_min: float = 1.0, pitch_max: float = 1.0) -> void:
	var resolved_name: String = name
	if SFX_ALIASES.has(name):
		resolved_name = str(SFX_ALIASES[name])
	var candidates: Array[String] = [resolved_name]
	if resolved_name != name:
		candidates.append(name)
	for base_name in candidates:
		for dir_path in SFX_DIRS:
			for ext in SFX_EXTS:
				var p = "%s/%s%s" % [dir_path, base_name, ext]
				if ResourceLoader.exists(p):
					var player = _free_sfx()
					player.stream = load(p)
					player.volume_db = volume_db
					player.pitch_scale = randf_range(pitch_min, pitch_max)
					player.play()
					return

func _free_sfx() -> AudioStreamPlayer:
	# Try to find a free player in the pool
	for p in _sfx_pool:
		if not p.playing:
			return p
	
	# If no free players, create a new one
	var p = AudioStreamPlayer.new()
	p.bus = "SFX"
	p.pitch_scale = Engine.time_scale
	add_child(p)
	_sfx_pool.append(p)
	
	# Auto-cleanup: queue free after a reasonable max duration
	var cleanup_timer = get_tree().create_timer(10.0, false)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
			_sfx_pool.erase(p)
	)
	
	return p
