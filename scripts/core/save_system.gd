extends Node
## Lokale, versionierte Spielstandspeicherung (JSON in user://).
## - atomares Schreiben (temporäre Datei, dann umbenennen)
## - Backup des letzten gültigen Stands
## - Migration älterer Versionen
## - Autosave und Speichern beim Pausieren/Schließen der App

const PATH := "user://savegame.json"
const BACKUP := "user://savegame.bak.json"
const TMP := "user://savegame.tmp"
const AUTOSAVE_SECONDS := 15.0

var path_override := ""   ## nur für Tests
var _timer := 0.0


func _path() -> String:
	return path_override if path_override != "" else PATH


func _backup_path() -> String:
	return _path() + ".bak"


func _tmp_path() -> String:
	return _path() + ".tmp"


func _process(delta: float) -> void:
	if not GameState.loaded:
		return
	_timer += delta
	if _timer >= AUTOSAVE_SECONDS:
		_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GameState.loaded:
			save_game()


func has_save() -> bool:
	return FileAccess.file_exists(_path()) or FileAccess.file_exists(_backup_path())


func save_game() -> bool:
	if not GameState.loaded:
		return false
	var text := JSON.stringify(GameState.serialize())
	var f := FileAccess.open(_tmp_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(_path()):
		DirAccess.copy_absolute(_path(), _backup_path())
		DirAccess.remove_absolute(_path())
	var err := DirAccess.rename_absolute(_tmp_path(), _path())
	if err != OK:
		push_warning("Speichern fehlgeschlagen (rename): %s" % error_string(err))
		return false
	return true


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


## Lädt den Spielstand; fällt bei beschädigter Hauptdatei auf das Backup zurück.
func load_game() -> bool:
	for p in [_path(), _backup_path()]:
		var data := _read(p)
		if data.is_empty():
			continue
		data = migrate(data)
		if GameState.deserialize(data):
			return true
	return false


## Hebt ältere Speicherstände schrittweise auf SAVE_VERSION.
func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v < 1:
		# Version 0 kannte weder Land-Erweiterungen noch Tutorial-Fortschritt.
		data["version"] = 1
		if not data.has("land_level"):
			data["land_level"] = 0
		if not data.has("tutorial_step"):
			data["tutorial_step"] = 99
		v = 1
	if v < 2:
		# Neue Tierprofile und Rettungsfälle sind optionale Felder alter Stände.
		data["rescue_case"] = {}
		data["next_rescue_at"] = 0.0
		for animal in data.get("animals", []):
			animal["traits"] = []
			animal["accessories"] = []
			animal["activity_at"] = 0.0
		data["version"] = 2
		v = 2
	if v < 3:
		# Tagebuch und Story-Aufträge sind optionale, leere Ergänzungen für Altstände.
		data["diary"] = []
		data["active_delivery_story"] = ""
		data["delivery_story_stage"] = 0
		data["version"] = 3
		v = 3
	if v < 4:
		# Erfolge nutzen bestehende Statistiken, neue Belohnungs-IDs starten ungeclaimt.
		data["claimed_achievements"] = []
		data["version"] = 4
		v = 4
	if v < 5:
		# Café-Fortschritt startet für alte Spielstände bei null.
		var stats: Dictionary = data.get("stats", {})
		stats["cafe_orders"] = int(stats.get("cafe_orders", 0))
		stats["cafe_stories_shared"] = int(stats.get("cafe_stories_shared", 0))
		stats["cafe_stories_completed"] = int(stats.get("cafe_stories_completed", 0))
		data["stats"] = stats
		data["version"] = 5
		v = 5
	if v < 6:
		# Das 24-Stunden-Tagesgericht wird für bestehende Café-Spielstände ausgewählt.
		data["daily_cafe_special_id"] = str(data.get("daily_cafe_special_id", ""))
		data["daily_cafe_special_at"] = float(data.get("daily_cafe_special_at", 0.0))
		var cafe_stats: Dictionary = data.get("stats", {})
		cafe_stats["cafe_special_orders"] = int(cafe_stats.get("cafe_special_orders", 0))
		data["stats"] = cafe_stats
		data["version"] = 6
		v = 6
	if v < 7:
		# Wettereffekte verwenden ausschließlich vorhandene Zeitstempel und benötigen keine neuen Save-Felder.
		data["version"] = 7
	return data


func delete_save() -> void:
	for p in [_path(), _backup_path(), _tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
