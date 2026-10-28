extends Node
## Músicas de fundo (com troca suave) e vinhetas de vitória.
## Arquivos em res://assets/audio/music/<nome>.ogg

const VOLUME_DB := -9.0
const FOLDER := "res://assets/audio/music/"

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _jingle: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	_jingle = AudioStreamPlayer.new()
	_jingle.volume_db = VOLUME_DB + 2.0
	add_child(_jingle)
	_jingle.finished.connect(_on_jingle_finished)


func play(track: String) -> void:
	if track == _current and _players[_active].playing:
		return
	_current = track
	if not Game.music_enabled:
		_stop_all()
		return
	var stream := _load(track)
	if stream == null:
		return
	var old := _players[_active]
	_active = 1 - _active
	var player := _players[_active]
	player.stream = stream
	player.volume_db = -40.0
	player.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(player, "volume_db", VOLUME_DB, 1.2)
	tween.tween_property(old, "volume_db", -60.0, 1.0)
	tween.chain().tween_callback(old.stop)


## Vinheta curta (vitória). A música de fundo abaixa enquanto toca.
func play_jingle(name: String) -> void:
	if not Game.music_enabled:
		return
	var stream := _load(name, false)
	if stream == null:
		return
	_jingle.stream = stream
	_jingle.play()
	create_tween().tween_property(_players[_active], "volume_db", -40.0, 0.3)


func refresh() -> void:
	if Game.music_enabled:
		var track := _current
		_current = ""
		play(track)
	else:
		_stop_all()


func _on_jingle_finished() -> void:
	if Game.music_enabled:
		create_tween().tween_property(_players[_active], "volume_db", VOLUME_DB, 1.5)


func _stop_all() -> void:
	for player in _players:
		player.stop()


func _load(name: String, loop := true) -> AudioStream:
	var path := FOLDER + name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream:
		stream.loop = loop
	return stream
