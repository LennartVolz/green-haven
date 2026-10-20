extends RefCounted
## Phase 1: sichere Dateiübertragung für Spielstände.

var _tests
var _save_path := "user://phase1-transfer-save.json"


func run(test_runner) -> void:
	_tests = test_runner
	var previous_path: String = SaveSystem.path_override
	SaveSystem.path_override = _save_path
	SaveSystem.delete_save()
	test_v8_fixture_roundtrip()
	test_export_import_roundtrip()
	test_reject_invalid_imports_without_changing_current_state()
	SaveSystem.delete_save()
	SaveSystem.path_override = previous_path
	for path in ["user://phase1-export.json", "user://phase1-corrupt.json", "user://phase1-newer.json", "user://phase1-valid-import.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _roundtrip_match(actual: Dictionary, expected: Dictionary) -> bool:
	return SaveSystem._json_values_match(actual, expected)


func test_v8_fixture_roundtrip() -> void:
	var file := FileAccess.open("res://tests/fixtures/save_v8.json", FileAccess.READ)
	_tests.check(file != null, "v8-Fixture lässt sich öffnen")
	if file == null:
		return
	var fixture: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_tests.check(typeof(fixture) == TYPE_DICTIONARY, "v8-Fixture ist gültiges JSON")
	if typeof(fixture) != TYPE_DICTIONARY:
		return
	var expected_fixture: Dictionary = SaveSystem.migrate(fixture.duplicate(true))
	var prior_offset: float = GameState.time_offset
	GameState.time_offset = float(fixture.get("saved_at", 0.0)) - Time.get_unix_time_from_system()
	_tests.check(GameState.deserialize(fixture), "aktueller v8-Spielstand wird aus Fixture geladen")
	# Die Fixture enthält keinen echten Speicherzeitpunkt. Der Tagesanker wird
	# deshalb beim Laden auf "jetzt" gesetzt und ist nicht reproduzierbar.
	if float(fixture.get("saved_at", 0.0)) <= 0.0:
		expected_fixture["day_anchor"] = GameState.day_anchor
	if GameState.loaded:
		var roundtrip := GameState.serialize()
		var expected: Dictionary = expected_fixture.duplicate(true)
		roundtrip.erase("saved_at")
		expected.erase("saved_at")
		_tests.check(_roundtrip_match(roundtrip, expected), "v8 serialize/deserialize/serialize ist vollständig identisch, abgesehen vom neu erzeugten saved_at")
	GameState.time_offset = prior_offset


func test_export_import_roundtrip() -> void:
	GameState.new_game()
	GameState.coins = 321
	var expected: Dictionary = GameState.serialize()
	var export_ok: bool = SaveSystem.export_to_file("user://phase1-export.json")
	_tests.check(export_ok, "Spielstand als JSON exportieren")
	_tests.check(FileAccess.file_exists("user://phase1-export.json"), "Exportdatei wurde angelegt")
	GameState.coins = 999
	var imported: bool = SaveSystem.import_from_file("user://phase1-export.json")
	_tests.check(imported, "gültigen exportierten Spielstand importieren")
	var imported_state: Dictionary = GameState.serialize()
	_tests.check(_roundtrip_match(imported_state, expected), "Import stellt den exportierten Spielstand vollständig wieder her")


func _backup_path_for_test() -> String:
	return _save_path + ".bak"


func test_reject_invalid_imports_without_changing_current_state() -> void:
	GameState.new_game()
	GameState.coins = 765
	SaveSystem.save_game()
	var original: Dictionary = GameState.serialize()
	var original_file := FileAccess.open(_save_path, FileAccess.READ)
	var original_saved_file_data: Dictionary = JSON.parse_string(original_file.get_as_text())
	original_file.close()
	var corrupt := FileAccess.open("user://phase1-corrupt.json", FileAccess.WRITE)
	corrupt.store_string("{ kaputt :::")
	corrupt.close()
	_tests.check(not SaveSystem.import_from_file("user://phase1-corrupt.json"), "beschädigte JSON-Datei wird abgelehnt")
	_tests.check(not SaveSystem.import_from_file(_save_path), "Hauptstand wird nicht als eigene Importquelle akzeptiert")
	var after_corrupt: Dictionary = GameState.serialize()
	_tests.check(_roundtrip_match(after_corrupt, original), "beschädigter Import lässt den aktuellen Spielstand unverändert")
	_tests.check(SaveSystem._json_values_match(SaveSystem._read(_save_path), original_saved_file_data), "beschädigter Import verändert auch die gespeicherte Hauptdatei nicht")
	var newer_data: Dictionary = original.duplicate(true)
	newer_data["version"] = GameState.SAVE_VERSION + 1
	var newer := FileAccess.open("user://phase1-newer.json", FileAccess.WRITE)
	newer.store_string(JSON.stringify(newer_data))
	newer.close()
	_tests.check(not SaveSystem.import_from_file("user://phase1-newer.json"), "Spielstand aus neuerer Version wird abgelehnt")
	var after_newer: Dictionary = GameState.serialize()
	_tests.check(_roundtrip_match(after_newer, original), "zu neuer Import lässt den aktuellen Spielstand unverändert")
	_tests.check(SaveSystem._json_values_match(SaveSystem._read(_save_path), original_saved_file_data), "zu neuer Import verändert auch die gespeicherte Hauptdatei nicht")
	_tests.check(FileAccess.file_exists(_save_path), "Hauptstand bleibt nach fehlgeschlagenen Importen vorhanden")
	var current_before_success: Dictionary = GameState.serialize()
	current_before_success["coins"] = 900
	var before_import_file := FileAccess.open(_save_path, FileAccess.WRITE)
	before_import_file.store_string(JSON.stringify(current_before_success))
	before_import_file.close()
	var valid_import := FileAccess.open("user://phase1-export.json", FileAccess.READ)
	var valid_import_text := valid_import.get_as_text()
	valid_import.close()
	var valid_import_file := FileAccess.open("user://phase1-valid-import.json", FileAccess.WRITE)
	valid_import_file.store_string(valid_import_text)
	valid_import_file.close()
	GameState.coins = 900
	_tests.check(SaveSystem.import_from_file("user://phase1-valid-import.json"), "gültigen Import nach Ablehnungsfällen übernehmen")
	_tests.check(int(SaveSystem._read(_backup_path_for_test()).get("coins", -1)) == 900, "bisheriger Stand wird vor erfolgreichem Import als Backup gesichert")
	var missing_version := FileAccess.open("user://phase1-corrupt.json", FileAccess.WRITE)
	missing_version.store_string(JSON.stringify({"coins": 123}))
	missing_version.close()
	var main_before_missing: Dictionary = SaveSystem._read(_save_path)
	var backup_before_missing: Dictionary = SaveSystem._read(_backup_path_for_test())
	var state_before_missing: Dictionary = GameState.serialize()
	_tests.check(not SaveSystem.import_from_file("user://phase1-corrupt.json"), "JSON ohne Versionsfeld wird abgelehnt")
	var invalid_version := FileAccess.open("user://phase1-corrupt.json", FileAccess.WRITE)
	invalid_version.store_string(JSON.stringify({"version": 7.5, "coins": 123}))
	invalid_version.close()
	_tests.check(not SaveSystem.import_from_file("user://phase1-corrupt.json"), "nicht ganzzahlige Save-Version wird abgelehnt")
	var after_missing_version: Dictionary = GameState.serialize()
	_tests.check(_roundtrip_match(after_missing_version, state_before_missing), "ungültige Save-Version lässt den aktuellen Spielstand unverändert")
	_tests.check(SaveSystem._json_values_match(SaveSystem._read(_save_path), main_before_missing), "ungültiger Import verändert die gespeicherte Hauptdatei nicht")
	_tests.check(SaveSystem._json_values_match(SaveSystem._read(_backup_path_for_test()), backup_before_missing), "ungültiger Import verändert das Backup nicht")
