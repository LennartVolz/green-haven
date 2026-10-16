extends Node
## Lokale, versionierte Spielstandspeicherung (JSON in user://).
## - Schreiben über eine temporäre Datei, die vor dem Umbenennen geprüft wird
## - Backup eines älteren gültigen Stands (höchstens alle BACKUP_MIN_AGE_SECONDS erneuert)
## - Unlesbare oder zu neue Spielstände werden als Kopie aufbewahrt statt überschrieben
## - Migration älterer Versionen
## - Autosave (nur bei Änderungen) und Speichern beim Pausieren der App

const PATH := "user://savegame.json"
const AUTOSAVE_SECONDS := 15.0
## Das Backup ist ein Sicherheitsnetz gegen Fehlstände und wird deshalb nicht bei
## jedem Autosave überschrieben, sondern höchstens alle zehn Minuten erneuert.
const BACKUP_MIN_AGE_SECONDS := 600.0

var path_override := ""   ## nur für Tests
## Grund des letzten gescheiterten load_game(): "", "newer", "invalid"
var last_load_error := ""
var _timer := 0.0
var _last_saved_fingerprint := ""


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
		save_game(false)


## Beenden (Fenster schließen, Zurück-Taste) behandelt Main; hier nur das Pausieren.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if GameState.loaded:
			save_game()


func has_save() -> bool:
	return FileAccess.file_exists(_path()) or FileAccess.file_exists(_backup_path())


## Speichert den Spielstand. Mit force = false (Autosave) wird nichts geschrieben,
## solange sich seit dem letzten Speichern nichts geändert hat.
func save_game(force: bool = true) -> bool:
	if not GameState.loaded:
		return false
	var data := GameState.serialize()
	var fingerprint := _fingerprint(data)
	if not force and fingerprint == _last_saved_fingerprint and FileAccess.file_exists(_path()):
		return true
	var f := FileAccess.open(_tmp_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if _read(_tmp_path()).is_empty():
		push_warning("Speichern fehlgeschlagen: die temporäre Datei ist nicht lesbar")
		DirAccess.remove_absolute(_tmp_path())
		return false
	_rotate_backup()
	var err := DirAccess.rename_absolute(_tmp_path(), _path())
	if err != OK:
		# Nicht jede Plattform überschreibt beim Umbenennen; dann erst die alte Datei entfernen.
		DirAccess.remove_absolute(_path())
		err = DirAccess.rename_absolute(_tmp_path(), _path())
		if err != OK:
			push_warning("Speichern fehlgeschlagen (rename): %s" % error_string(err))
			return false
	_last_saved_fingerprint = fingerprint
	return true


## Fingerabdruck des Spielstands ohne den Zeitstempel, der sich bei jedem Speichern ändert.
func _fingerprint(data: Dictionary) -> String:
	var copy := data.duplicate()
	copy.erase("saved_at")
	return JSON.stringify(copy).sha256_text()


## Sichert den bisherigen Hauptstand, aber nur wenn er gültig ist und das Backup
## älter als BACKUP_MIN_AGE_SECONDS ist (oder fehlt).
func _rotate_backup() -> void:
	if not FileAccess.file_exists(_path()):
		return
	var backup := _backup_path()
	if FileAccess.file_exists(backup):
		var age := Time.get_unix_time_from_system() - float(FileAccess.get_modified_time(backup))
		if age < BACKUP_MIN_AGE_SECONDS:
			return
	if _read(_path()).is_empty():
		return   # einen beschädigten Hauptstand nie über ein gutes Backup kopieren
	DirAccess.copy_absolute(_path(), backup)


## Bewahrt eine nicht ladbare Datei als Kopie auf, damit ein folgender Neustart sie nicht überschreibt.
func _quarantine(p: String, tag: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.copy_absolute(p, "%s.%s" % [p, tag])


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
	last_load_error = ""
	for p in [_path(), _backup_path()]:
		if not FileAccess.file_exists(p):
			continue
		var data := _read(p)
		if data.is_empty():
			last_load_error = "invalid"
			_quarantine(p, "corrupt")
			continue
		if int(data.get("version", 0)) > GameState.SAVE_VERSION:
			# Stand einer neueren App-Version: nicht laden und nicht überschreiben.
			last_load_error = "newer"
			_quarantine(p, "newer")
			continue
		data = migrate(data)
		if GameState.deserialize(data):
			last_load_error = ""
			# Nur nach dem Laden der Hauptdatei ist der Stand "bereits gespeichert".
			_last_saved_fingerprint = _fingerprint(GameState.serialize()) if p == _path() else ""
			return true
		last_load_error = "invalid"
		_quarantine(p, "corrupt")
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
		v = 7
	if v < 8:
		# Nachbarschaftsevents beginnen für bestehende Spielstände ohne alte Event-Bestellung.
		data["neighborhood_event_stage"] = 0
		data["neighborhood_event_order"] = {}
		data["neighborhood_event_completed_cycle"] = -1
		data["version"] = 8
	return data


func delete_save() -> void:
	for p in [_path(), _backup_path(), _tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
