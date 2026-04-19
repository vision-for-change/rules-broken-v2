## AudioManager.gd
extends Node

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _fade_tween: Tween
var _current_track := ""

const POOL_SIZE   = 8
const MUSIC_VOL   = -10.0
const FADE_TIME   = 1.0

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
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	# Connect to system events for automatic music transitions
	EventBus.system_unstable.connect(func(): switch_music("unstable"))
	EventBus.system_critical.connect(func(): switch_music("critical"))
	EventBus.system_stable.connect(func(): switch_music("stable"))
	EventBus.watchdog_alert.connect(func(_a, _b, _c): switch_music("alert"))

func play_music(state: String) -> void:
	var track = STATE_TRACKS.get(state, "music_stable")
	if _current_track == track and _music.playing:
		return
	_current_track = track
	var path = "res://assets/audio/music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		return
	_music.stream = load(path)
	_music.volume_db = MUSIC_VOL
	_music.play()

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

func play_sfx(name: String) -> void:
	for p in ["res://assets/audio/sfx/%s.wav" % name, "res://assets/audio/sfx/%s.ogg" % name]:
		if ResourceLoader.exists(p):
			var player = _free_sfx()
			player.stream = load(p)
			player.play()
			return

func _free_sfx() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]
