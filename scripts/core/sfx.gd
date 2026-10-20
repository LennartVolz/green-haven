extends Node
## Kleine, zur Laufzeit synthetisierte Soundeffekte (keine Audiodateien nötig)
## plus Vibrations-Feedback auf Smartphones.

const RATE := 22050
const BASE_VOLUME_DB := -7.0

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0


func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.volume_db = BASE_VOLUME_DB
		add_child(p)
		_players.append(p)
	_streams = {
		"tap": _make([[720.0, 0.05]], 0.35),
		"plant": _make([[420.0, 0.05], [330.0, 0.08]], 0.45),
		"harvest": _make([[520.0, 0.07], [780.0, 0.12]], 0.5),
		"coin": _make([[988.0, 0.06], [1319.0, 0.16]], 0.4),
		"level": _make([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.3]], 0.5),
		"error": _make([[180.0, 0.12], [150.0, 0.12]], 0.5),
		"pet": _make([[600.0, 0.08], [720.0, 0.08], [680.0, 0.14]], 0.35),
		"build": _make([[160.0, 0.09], [240.0, 0.14]], 0.6),
	}
	GameState.sound.connect(play)
	refresh_volume()


func sound_volume() -> float:
	return clampf(float(GameState.settings.get("sound_volume", 1.0)), 0.0, 1.0)


func volume_db_for(value: float) -> float:
	var volume := clampf(value, 0.0, 1.0)
	return BASE_VOLUME_DB + linear_to_db(volume) if volume > 0.0 else -80.0


## Wendet die Lautstärke auf alle Effekt-Player an; 0 % schaltet sie stumm.
func refresh_volume() -> void:
	var db := volume_db_for(sound_volume())
	for p in _players:
		p.volume_db = db


func _make(notes: Array, vol: float) -> AudioStreamWAV:
	var total := 0
	for n in notes:
		total += int(float(n[1]) * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var pos := 0
	for n in notes:
		var freq: float = n[0]
		var count := int(float(n[1]) * RATE)
		for i in range(count):
			var env := minf(1.0, float(i) / (0.004 * RATE)) * exp(-3.2 * float(i) / float(count))
			var s := sin(TAU * freq * float(i) / RATE) + 0.25 * sin(TAU * freq * 2.0 * float(i) / RATE)
			data.encode_s16(pos * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
			pos += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func play(sound_name: String) -> void:
	if not _streams.has(sound_name):
		return
	var volume := sound_volume()
	if volume > 0.0 and not _players.is_empty():
		var p: AudioStreamPlayer = _players[_next]
		_next = (_next + 1) % _players.size()
		p.volume_db = volume_db_for(volume)
		p.stream = _streams[sound_name]
		p.play()
	if bool(GameState.settings.get("vibration", true)) and OS.has_feature("mobile"):
		match sound_name:
			"harvest", "coin", "pet":
				Input.vibrate_handheld(18)
			"level", "build":
				Input.vibrate_handheld(45)
			"error":
				Input.vibrate_handheld(30)
