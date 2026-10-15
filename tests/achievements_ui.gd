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


func contains_label(node: Node, text: String) -> bool:
	if node is Label and String((node as Label).text).contains(text):
		return true
	for child in node.get_children():
		if contains_label(child, text):
			return true
	return false


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

	# Wetterhinweis und Musikschalter erscheinen in den echten Einstellungen.
	ui.act_open("settings", {})
	await frames()
	var music_available: bool = load("res://scripts/core/background_music.gd").track_available()
	check(find_button(ui.content, "Hintergrundmusik: Datei fehlt") != null if not music_available else find_button(ui.content, "Hintergrundmusik: An") != null, "Musikoption zeigt Trackstatus in den Einstellungen")
	var music_button := find_button(ui.content, "Hintergrundmusik:")
	if music_available and check(music_button != null, "Musik lässt sich über die Einstellungen umschalten"):
		music_button.pressed.emit()
		await frames()
		check(find_button(ui.content, "Hintergrundmusik: Aus") != null and not bool(gs.settings.get("music", true)), "Musikschalter aktualisiert Einstellung und Anzeige")
		ui.act_open("settings", {})
		await frames()
		music_button = find_button(ui.content, "Hintergrundmusik:")
		if music_button != null:
			music_button.pressed.emit()
		await frames()

	# Café-Besuchsgeschichte erscheint im Auftragsbuch an der echten Oberfläche.
	gs.new_game()
	gs.level = 8
	gs.coins = 5000
	var cafe_uid: int = gs.place_object("cafe", Vector2i(8, 11))
	check(cafe_uid > 0, "Café kann für UI-Test gebaut werden")
	gs.orders.clear()
	var special_id: String = gs.daily_cafe_special()
	gs.orders.append({"id": 9876, "customer": "Mira", "items": {special_id: 1}, "coins": 100, "xp": 30, "cafe_order": true, "cafe_daily_special": true, "visitor_story": "Ich mag die ruhige Gartenecke."})
	ui.act_open("orders", {})
	await frames()
	check(contains_label(ui.content, "Ich mag die ruhige Gartenecke."), "Besuchergeschichte ist im Auftragsbuch sichtbar")
	check(contains_label(ui.content, "Mira wünscht sich:"), "Café-Bestellung wird im Auftragsbuch gezeigt")
	check(contains_label(ui.content, "Heutiges Café-Gericht"), "Tagesangebot erscheint im Auftragsbuch")
	check(contains_label(ui.content, "+50% Münzen und +5 XP"), "Tagesbonus ist sichtbar")
	check(contains_label(ui.content, "Tagesgericht · +50% Münzen · +5 XP") or contains_label(ui.content, "Tagesgericht · +50%% Münzen · +5 XP"), "Besondere Café-Bestellung weist den Bonus aus")
	var cafe_skip := find_button(ui.content, "✕")
	if check(cafe_skip != null, "optionale Café-Bestellung hat Abbrechen-Schaltfläche"):
		check(cafe_skip.disabled, "Bestellungen mit Besuchergeschichte können nicht versehentlich übersprungen werden")

	ui.act_open("achievements", {})
	await frames()
	check(ui._sheet_name == "achievements" and ui._title.text == "Erfolge", "Erfolge öffnen über die Navigation")
	check(ui.content.get_child_count() == GameData.ACHIEVEMENTS.size() + 1, "alle Erfolge werden angezeigt")
	check(contains_label(ui.content, "Geschichten am Kaffeetisch"), "Café-Meilenstein erscheint in der echten Erfolge-UI")
	print("achievements UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	call_deferred("run")
