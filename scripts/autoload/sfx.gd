extends Node
## Efeitos sonoros suaves (arquivos em res://assets/audio/sfx).
## Uso: Sfx.play("jump")

const FOLDER := "res://assets/audio/sfx/"
const VOICES := 10
const BASE_DB := -7.0
const NAMES := ["jump", "land", "dive", "coin", "bounce", "hit", "splash", "checkpoint",
	"beep", "go", "click", "whoosh", "unlock", "pop"]

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for name: String in NAMES:
		var path := FOLDER + name + ".ogg"
		if ResourceLoader.exists(path):
			_sounds[name] = load(path)


func play(sound: String, volume_db := 0.0, pitch_variation := 0.04) -> void:
	if not Game.sound_enabled or not _sounds.has(sound):
		return
	# Evita o mesmo som "metralhado" várias vezes no mesmo instante.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 45:
		return
	_last_played[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _sounds[sound]
	player.volume_db = BASE_DB + volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
