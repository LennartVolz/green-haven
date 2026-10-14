extends SceneTree
## Prüft Tagebuch, Erzählaufträge und Erfolge über die echte UI.

var gs: Node
var ui: Node
var failures := 0


func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame


func check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failures += 1
	printerr("FAIL: ", message)
	return false


func find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and String((child as Button).text).begins_with(prefix):
			return child as Button
		var found := find_button(child, prefix)
		if found != null:
			return found
	return null


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://achievements_ui_save.json"
	save_system.delete_save()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	ui = main.get_node("UI")
	await frames(5)
	gs.level = 10
	gs.add_diary_entry("Testeintrag aus einer Rettung", 1)

	ui.act_open("refuge", {})
	await frames()
	var diary_button := find_button(ui.content, "Refugiums-Tagebuch")
	if check(diary_button != null, "Refugium bietet Tagebuch an"):
		diary_button.pressed.emit()
		await frames()
		check(ui._sheet_name == "diary" and ui._title.text == "Refugiums-Tagebuch", "Tagebuch öffnet über den Refuge-Button")
		check(ui.content.get_child_count() > 1, "Eintrag ist im Tagebuch sichtbar")
		print("diary UI checked")

	ui.act_open("orders", {})
	await frames()
	var story_button := find_button(ui.content, "Geschichte beginnen")
	if check(story_button != null, "Auftragsbuch bietet Story-Start"):
		story_button.pressed.emit()
		await frames()
		check(not gs.active_delivery_story.is_empty(), "Story-Button startet Reihe")
		var has_story_order := false
		for order in gs.orders:
			if order.has("story_text"):
				has_story_order = true
				break
		check(has_story_order, "Reihe erzeugt Story-Auftrag")
		print("delivery story UI checked")

	ui.act_open("achievements", {})
	await frames()
	check(ui._sheet_name == "achievements" and ui._title.text == "Erfolge", "Erfolge öffnen über die Navigation")
	check(ui.content.get_child_count() == GameData.ACHIEVEMENTS.size() + 1, "alle zehn Erfolge werden angezeigt")
	print("achievements UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	call_deferred("run")
