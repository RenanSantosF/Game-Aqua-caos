extends Node
## Efeitos sonoros gerados por código (sem arquivos de áudio).
## Uso: Sfx.play("jump")

const RATE := 22050
const VOICES := 10

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _lowpass := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_sounds()


func play(sound: String, volume_db := 0.0, pitch_variation := 0.06) -> void:
	if not Game.sound_enabled or not _sounds.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _sounds[sound]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _build_sounds() -> void:
	_sounds["jump"] = _make(0.22, func(t, k): return _sweep(t, 0.22, 330.0, 720.0) * _env(k, 0.01) * 0.5)
	_sounds["land"] = _make(0.09, func(t, k): return (_noise_lp(0.25) * 0.8 + sin(TAU * 110.0 * t) * 0.5) * _env(k, 0.0) * 0.45)
	_sounds["dive"] = _make(0.3, func(t, k): return _noise_lp(0.15 + 0.5 * k) * sin(PI * k) * 0.6)
	_sounds["coin"] = _make(0.28, func(t, k): return _square_soft(988.0 if t < 0.07 else 1319.0, t) * _env(k, 0.0) * 0.32)
	_sounds["bounce"] = _make(0.4, func(t, k): return sin(TAU * (180.0 + 380.0 * k + sin(t * 70.0) * 30.0) * t) * _env(k, 0.01) * 0.55)
	_sounds["hit"] = _make(0.3, func(t, k): return (_sweep(t, 0.3, 190.0, 60.0) * 0.8 + _noise_lp(0.4) * (1.0 - k) * 0.5) * _env(k, 0.0) * 0.6)
	_sounds["splash"] = _make(0.7, func(t, k): return (_noise_lp(0.35 - 0.25 * k) * 0.9 + _sweep(t, 0.7, 400.0, 90.0) * 0.25) * _env(k, 0.02) * 0.6)
	_sounds["checkpoint"] = _make(0.45, func(t, k): return _arpeggio(t, [523.25, 659.25, 783.99], 0.12) * _env(k, 0.0) * 0.35)
	_sounds["win"] = _make(1.1, func(t, k): return _arpeggio(t, [523.25, 659.25, 783.99, 1046.5, 1318.5], 0.13) * _env(k, 0.0) * 0.35)
	_sounds["beep"] = _make(0.14, func(t, k): return _square_soft(660.0, t) * _env(k, 0.0) * 0.3)
	_sounds["go"] = _make(0.4, func(t, k): return _square_soft(990.0, t) * _env(k, 0.0) * 0.32)
	_sounds["click"] = _make(0.06, func(t, k): return sin(TAU * 1500.0 * t) * _env(k, 0.0) * 0.3)
	_sounds["whoosh"] = _make(0.35, func(t, k): return _noise_lp(0.1 + 0.3 * sin(PI * k)) * sin(PI * k) * 0.45)


func _make(duration: float, generator: Callable) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	_lowpass = 0.0
	for i in count:
		var t := float(i) / RATE
		var value: float = clampf(generator.call(t, t / duration), -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


func _env(k: float, attack: float) -> float:
	if k < attack:
		return k / attack
	return pow(1.0 - k, 2.0)


func _sweep(t: float, duration: float, from_hz: float, to_hz: float) -> float:
	return sin(TAU * (from_hz * t + (to_hz - from_hz) * t * t / (2.0 * duration)))


func _square_soft(hz: float, t: float) -> float:
	var p := TAU * hz * t
	return sin(p) + sin(p * 3.0) / 3.0 + sin(p * 5.0) / 5.0


func _arpeggio(t: float, notes: Array, step: float) -> float:
	var index := mini(int(t / step), notes.size() - 1)
	return _square_soft(notes[index], t) * 0.7


func _noise_lp(amount: float) -> float:
	_lowpass = lerpf(_lowpass, randf_range(-1.0, 1.0), clampf(amount, 0.01, 1.0))
	return _lowpass * 2.0
