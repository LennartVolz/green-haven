extends SceneTree
## UI-Test für das Produktions-Dashboard: Gebäudeliste, Restzeiten,
## Sammelabholung, Einzelabholung und Badge in der Navigation.

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


func badge_text() -> String:
	var button: Button = ui._nav_buttons.get("production_overview", null)
	if button == null:
		return ""
	var badge := button.get_node_or_null("Badge")
	if badge == null or badge.get_child_count() == 0:
		return ""
	return String((badge.get_child(0) as Label).text)


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://production_overview_ui.json"
	save_system.delete_save()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	ui = main.get_node("UI")
	await frames(5)

	# Die Navigation bietet den neuen Bereich an und öffnet ihn.
	var nav: Button = ui._nav_buttons.get("production_overview", null)
	if check(nav != null, "Navigation enthält Produktion"):
		nav.pressed.emit()
		await frames()
		check(ui._sheet_name == "production_overview" and ui._title.text == "Produktion", "Produktions-Dashboard öffnet über die Navigation")
		check(contains_label(ui.content, "Noch gibt es kein Produktionsgebäude"), "leerer Zustand erklärt den Einstieg")
		var shop_button := find_button(ui.content, "Gebäude im Shop ansehen")
		if check(shop_button != null, "leerer Zustand verlinkt in den Shop"):
			shop_button.pressed.emit()
			await frames()
			check(ui._sheet_name == "shop" and String(ui.state.get("shop_tab", "")) == "buildings", "Shop öffnet direkt die Gebäude")
			ui.close_sheet()

	# Zwei Gebäude mit je einer laufenden Produktion aufbauen.
	gs.level = 4
	gs.coins = 5000
	var bakery: int = gs.place_object("bakery", Vector2i(8, 11))
	var milkery: int = gs.place_object("milkery", Vector2i(10, 11))
	gs.add_item("wheat", 3)
	gs.add_item("oat", 3)
	check(bakery > 0 and milkery > 0, "Testgebäude gebaut")
	check(gs.start_recipe(bakery, "bread") and gs.start_recipe(milkery, "oat_milk"), "Produktionen gestartet")
	ui.act_open("production_overview", {})
	await frames()
	check(contains_label(ui.content, "Bäckerei"), "Bäckerei erscheint in der Übersicht")
	check(contains_label(ui.content, "Pflanzenmilch-Manufaktur"), "Manufaktur erscheint in der Übersicht")
	check(contains_label(ui.content, "2 Gebäude"), "Zusammenfassung zählt die Gebäude")
	check(contains_label(ui.content, "in Arbeit"), "laufende Produktionen werden gezählt")
	check(contains_label(ui.content, "Läuft") or contains_label(ui.content, "Wartet"), "Warteschlangeneinträge zeigen ihren Zustand")
	var details := find_button(ui.content, "Details")
	if check(details != null, "Gebäudekarten verweisen auf die Detailansicht"):
		details.pressed.emit()
		await frames()
		check(ui._sheet_name == "production", "Detailansicht öffnet sich aus der Übersicht")
		var back := find_button(ui.content, "Zur Produktionsübersicht")
		if check(back != null, "Detailansicht führt zurück zur Übersicht"):
			back.pressed.emit()
			await frames()
			check(ui._sheet_name == "production_overview", "Rückweg öffnet das Dashboard erneut")
	var early_collect := find_button(ui.content, "Nichts abzuholen")
	if check(early_collect != null, "Sammelabholung ist sichtbar"):
		check(early_collect.disabled, "Sammelabholung ist ohne fertige Ware deaktiviert")

	# Nach Ablauf der Backzeit aktualisieren sich Badge und offene Übersicht.
	gs.time_offset += 61.0
	await create_timer(0.5).timeout
	await frames()
	check(badge_text() == "1", "Badge zeigt ein fertiges Produkt")
	check(contains_label(ui.content, "Bereit zum Abholen"), "fertiges Produkt ist in der Übersicht markiert")
	var collect_all := find_button(ui.content, "Alles abholen (1)")
	if check(collect_all != null and not collect_all.disabled, "Sammelabholung wird mit fertiger Ware aktiv"):
		collect_all.pressed.emit()
		await frames(5)
		check(gs.item_count("bread") == 1, "Sammelabholung legt das Produkt in den Vorrat")
		check(gs.total_ready_products() == 0, "nach der Abholung ist nichts mehr fertig")
		check(badge_text() == "", "Badge verschwindet nach der Abholung")
		check(find_button(ui.content, "Nichts abzuholen") != null, "Übersicht zeigt den leeren Sammelzustand")

	# Das verbleibende Produkt lässt sich direkt am Gebäude abholen.
	gs.time_offset += 30.0
	await create_timer(0.5).timeout
	await frames()
	var collect_one := find_button(ui.content, "Abholen (1)")
	if check(collect_one != null, "Gebäudekarte bietet Einzelabholung"):
		collect_one.pressed.emit()
		await frames(5)
		check(gs.item_count("oat_milk") == 1, "Einzelabholung legt das Produkt in den Vorrat")
		check(gs.total_ready_products() == 0 and badge_text() == "", "Zähler und Badge bleiben leer")
	print("production overview UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	call_deferred("run")
