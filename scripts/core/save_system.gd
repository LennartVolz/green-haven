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


## Exportiert den aktuellen Stand als einzelne JSON-Datei.
func export_to_file(destination: String) -> bool:
	if not GameState.loaded or destination.strip_edges().is_empty():
		return false
	return _replace_json(destination, GameState.serialize())


## Prüft den Import vollständig an einer separaten GameState-Instanz, bevor
## Sicherung, Datei oder laufender Zustand verändert werden.
func import_from_file(source: String) -> bool:
	last_load_error = ""
	if source == _path() or source == _backup_path():
		last_load_error = "invalid"
		return false
	if source.strip_edges().is_empty():
		last_load_error = "invalid"
		return false
	var candidate := _read(source)
	if candidate.is_empty() or not candidate.has("version") or (typeof(candidate["version"]) != TYPE_INT and typeof(candidate["version"]) != TYPE_FLOAT):
		last_load_error = "invalid"
		return false
	var source_version := float(candidate["version"])
	if not is_finite(source_version) or source_version < 0.0 or source_version != floorf(source_version):
		last_load_error = "invalid"
		return false
	if source_version > GameState.SAVE_VERSION:
		last_load_error = "newer"
		return false
	candidate = migrate(candidate.duplicate(true))
	var probe_script: GDScript = load("res://scripts/core/game_state.gd")
	var probe: Node = probe_script.new()
	probe.time_offset = GameState.time_offset
	var valid: bool = probe.deserialize(candidate.duplicate(true))
	probe.free()
	if not valid:
		last_load_error = "invalid"
		return false
	var old_state: Dictionary = GameState.serialize() if GameState.loaded else {}
	var backup_before_import: Dictionary = _read(_backup_path()) if FileAccess.file_exists(_backup_path()) else {}
	if not old_state.is_empty() and not _replace_json(_backup_path(), old_state):
		last_load_error = "invalid"
		return false
	if not _replace_json(_path(), candidate):
		_restore_import_backup(backup_before_import)
		last_load_error = "invalid"
		return false
	if not GameState.deserialize(candidate.duplicate(true)):
		# Die Probe und der echte Ladevorgang verwenden denselben Validator. Dieser
		# Rückweg schützt zusätzlich vor unerwarteten Plattform-/Laufzeitfehlern.
		if not old_state.is_empty():
			_replace_json(_path(), old_state)
			GameState.deserialize(old_state.duplicate(true))
		_restore_import_backup(backup_before_import)
		last_load_error = "invalid"
		return false
	_last_saved_fingerprint = _fingerprint(GameState.serialize())
	last_load_error = ""
	return true


func _restore_import_backup(previous: Dictionary) -> void:
	if previous.is_empty():
		if FileAccess.file_exists(_backup_path()):
			DirAccess.remove_absolute(_backup_path())
		return
	_replace_json(_backup_path(), previous)


func _json_values_match(left: Variant, right: Variant) -> bool:
	if (typeof(left) == TYPE_INT or typeof(left) == TYPE_FLOAT) and (typeof(right) == TYPE_INT or typeof(right) == TYPE_FLOAT):
		return is_equal_approx(float(left), float(right))
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _json_values_match(left[key], right[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _json_values_match(left[index], right[index]):
				return false
		return true
	return left == right


func _write_json(destination: String, data: Dictionary) -> bool:
	var parent_directory := destination.get_base_dir()
	if parent_directory.begins_with("user://") or parent_directory.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_directory))
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return _json_values_match(_read(destination), data)


## Ersetzt die Zieldatei über eine geprüfte temporäre Datei und stellt sie bei
## einem fehlgeschlagenen Umbenennen wieder her.
func _replace_json(destination: String, data: Dictionary) -> bool:
	var temporary := destination + ".import.tmp"
	if not _write_json(temporary, data):
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
		return false
	var had_destination := FileAccess.file_exists(destination)
	var previous := destination + ".import.previous"
	if had_destination:
		if FileAccess.file_exists(previous):
			DirAccess.remove_absolute(previous)
		if DirAccess.rename_absolute(destination, previous) != OK:
			DirAccess.remove_absolute(temporary)
			return false
	var result := DirAccess.rename_absolute(temporary, destination)
	if result != OK:
		if had_destination:
			DirAccess.rename_absolute(previous, destination)
		DirAccess.remove_absolute(temporary)
		return false
	if not _json_values_match(_read(destination), data):
		DirAccess.remove_absolute(destination)
		if had_destination and FileAccess.file_exists(previous):
			DirAccess.rename_absolute(previous, destination)
		return false
	if had_destination and FileAccess.file_exists(previous):
		DirAccess.remove_absolute(previous)
	return true


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
		var legacy_animals: Variant = data.get("animals", [])
		if typeof(legacy_animals) == TYPE_ARRAY:
			for animal in legacy_animals:
				if typeof(animal) != TYPE_DICTIONARY:
					continue
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
		var stats_value: Variant = data.get("stats", {})
		var stats: Dictionary = stats_value if typeof(stats_value) == TYPE_DICTIONARY else {}
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
		var cafe_stats_value: Variant = data.get("stats", {})
		var cafe_stats: Dictionary = cafe_stats_value if typeof(cafe_stats_value) == TYPE_DICTIONARY else {}
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
		v = 8
	if v < 9:
		# Tageszähler und Rückblick starten mit dem Speicherzeitpunkt; der erste
		# Rückblick zählt nur Aktionen nach dem Laden, nicht die gesamte Historie.
		var day_snapshot_value: Variant = data.get("stats", {})
		var day_snapshot: Dictionary = day_snapshot_value if typeof(day_snapshot_value) == TYPE_DICTIONARY else {}
		data["day_anchor"] = float(data.get("saved_at", 0.0))
		data["last_day_recap"] = 1
		data["day_stats_snapshot"] = day_snapshot.duplicate(true)
		data["version"] = 9
		v = 9
	if v < 10:
		# Saisonziele und Hofbuch: Der Saison-Schnappschuss startet auf den
		# aktuellen Lebenszeit-Zählern, damit alte Stände keine Belohnung
		# rückwirkend abholen. Freischaltungen beginnen leer.
		var season_snapshot_value: Variant = data.get("stats", {})
		var season_snapshot: Dictionary = season_snapshot_value if typeof(season_snapshot_value) == TYPE_DICTIONARY else {}
		data["season_stats_snapshot"] = season_snapshot.duplicate(true)
		# Die Epoche folgt dem gespeicherten Spieltag; beim Laden einer späteren
		# Saison wird der Schnappschuss ohnehin neu gesetzt.
		var saved_at := float(data.get("saved_at", 0.0))
		var anchor := float(data.get("day_anchor", saved_at))
		var day := 1
		if anchor > 0.0 and saved_at >= anchor:
			day = maxi(1, floori((saved_at - anchor) / GameData.REAL_DAY_SECONDS) + 1)
		var epoch := floori(float(day - 1) / float(GameData.SEASON_DAYS))
		data["season_snapshot_epoch"] = epoch
		data["seasons_seen"] = [String(GameData.SEASONS[posmod(epoch, GameData.SEASONS.size())]["id"])]
		data["unlocked_decos"] = []
		data["hofbuch_claimed"] = []
		data["version"] = 10
	# Wilde Sammelstellen sind eine optionale Ergänzung. Altstände starten ohne
	# Nachwuchszeiten; die Fundstellen selbst ergeben sich aus der Zellposition.
	if not data.has("forage"):
		data["forage"] = []
	# Lautstärken sind optionale Einstellungen. Ältere Stände kannten nur An/Aus;
	# sie werden auf 0 % bzw. 100 % abgebildet, ohne die Save-Version zu erhöhen.
	var settings_value: Variant = data.get("settings", {})
	if typeof(settings_value) == TYPE_DICTIONARY:
		var migrated_settings: Dictionary = settings_value
		var legacy_sound := bool(migrated_settings.get("sound", true))
		var legacy_music := bool(migrated_settings.get("music", true))
		migrated_settings["sound_volume"] = clampf(float(migrated_settings.get("sound_volume", 1.0 if legacy_sound else 0.0)), 0.0, 1.0)
		migrated_settings["music_volume"] = clampf(float(migrated_settings.get("music_volume", 1.0 if legacy_music else 0.0)), 0.0, 1.0)
		migrated_settings["sound"] = float(migrated_settings["sound_volume"]) > 0.0
		migrated_settings["music"] = float(migrated_settings["music_volume"]) > 0.0
		data["settings"] = migrated_settings
	return data


func delete_save() -> void:
	for p in [_path(), _backup_path(), _tmp_path(), _path() + ".import.tmp", _path() + ".import.previous"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
