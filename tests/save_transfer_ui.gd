extends SceneTree
## UI-Test für den Spielstand-Export/Import in den Einstellungen.

var failures := 0
var save_system: Node
var ui: Node
var gs: Node


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: ", message)


func frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame


func find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and String(child.text).begins_with(prefix):
			return child
		var result := find_button(child, prefix)
		if result != null:
			return result
	return null


func run() -> void:
	save_system = root.get_node("SaveSystem")
	save_system.path_override = "user://save_transfer_ui.json"
	save_system.delete_save()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = main_scene.instantiate()
	main.name = "Main"
	root.add_child(main)
	ui = main.get_node("UI")
	gs = root.get_node("GameState")
	await frames(5)
	gs.new_game()
	gs.coins = 432
	ui.act_open("settings", {})
	await frames()
	var export_button := find_button(ui.content, "Spielstand exportieren")
	var import_button := find_button(ui.content, "Spielstand importieren")
	check(export_button != null, "Einstellungen zeigen Spielstand-Export")
	check(import_button != null, "Einstellungen zeigen Spielstand-Import")
	if export_button != null:
		export_button.pressed.emit()
		await frames()
		check(find_button(ui.content, "Wirklich exportieren?") != null, "Export erfordert eine zweite Bestätigung")
		var confirm := find_button(ui.content, "Wirklich exportieren?")
		if confirm != null:
			confirm.pressed.emit()
			await frames()
			check(FileAccess.file_exists("user://save_transfer/savegame.json"), "Export-Fallback schreibt in user://save_transfer")
			check(int(save_system._read("user://save_transfer/savegame.json").get("coins", -1)) == 432, "Fallback enthält den aktuellen Spielstand")
			gs.coins = 123
	check(find_button(ui.content, "Spielstand importieren") != null, "Import-Menü bleibt nach Export verfügbar")
	if find_button(ui.content, "Spielstand importieren") != null:
		find_button(ui.content, "Spielstand importieren").pressed.emit()
		await frames()
		check(find_button(ui.content, "Wirklich importieren?") != null, "Import erfordert eine zweite Bestätigung")
		var import_confirm := find_button(ui.content, "Wirklich importieren?")
		if import_confirm != null:
			import_confirm.pressed.emit()
			await frames()
			check(gs.coins == 432 and ui._sheet_name == "", "Bestätigter user://-Import ersetzt den Spielstand und schließt das Menü")
			check(int(save_system._read("user://save_transfer_ui.json.bak").get("coins", -1)) == 123, "vorheriger Stand wird vor dem UI-Import gesichert")
	print("save transfer UI checked")
	var main_node := root.get_node_or_null("Main")
	if main_node != null:
		main_node.queue_free()
	await frames(2)
	save_system.delete_save()
	for path in ["user://save_transfer/savegame.json", "user://save_transfer/savegame.json.import.previous", "user://save_transfer/savegame.json.import.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	# Die Prüfungen vergleichen deutsche Texte; unabhängig von der Gerätesprache.
	I18n.apply("de")
	call_deferred("run")
