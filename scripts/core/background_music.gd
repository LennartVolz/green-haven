extends Node
## Spielt den optional bereitgestellten Hintergrundtrack in einer leisen Schleife.

const TRACK_PATH := "res://audio/Sunlight_on_the_Path.mp3"
const MUSIC_VOLUME_DB := -14.0

var player: AudioStreamPlayer
var has_track := false
var _missing_track_reported := false


static func track_available() -> bool:
	return FileAccess.file_exists(TRACK_PATH)


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = MUSIC_VOLUME_DB
	add_child(player)
	if not track_available():
		if not _missing_track_reported:
			push_warning("Hintergrundmusik fehlt: %s" % TRACK_PATH)
			_missing_track_reported = true
		return
	var stream := load(TRACK_PATH) as AudioStreamMP3
	if stream == null:
		push_warning("Hintergrundmusik konnte nicht als MP3 geladen werden: %s" % TRACK_PATH)
		return
	stream.loop = true
	player.stream = stream
	has_track = true
	call_deferred("refresh")


func music_volume() -> float:
	return clampf(float(GameState.settings.get("music_volume", 1.0)), 0.0, 1.0)


func volume_db_for(value: float) -> float:
	var volume := clampf(value, 0.0, 1.0)
	return MUSIC_VOLUME_DB + linear_to_db(volume) if volume > 0.0 else -80.0


func refresh() -> void:
	if player == null:
		return
	var volume := music_volume()
	player.volume_db = volume_db_for(volume)
	if not has_track:
		return
	if volume > 0.0:
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()
