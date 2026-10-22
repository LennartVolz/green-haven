extends SceneTree
## UI-Test für das Gartencafé: Tische, Gäste, Servieren, Gehen lassen und der
## Tagesumsatz im Café-Sheet – bedient über die echte Oberfläche.

var gs: Node
var gd: Node
var ui: Node
var cafe_uid := 0
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


## Setzt einen Gast an einen freien Tisch, ohne auf die Wartezeit zu warten.
func seat_guest() -> void:
	gs.cafe_next_guest_at = 0.0
	gs._tick_cafe(0.5)


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://cafe_ui.json"
	save_system.delete_save()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	gd = root.get_node("GameData")
	ui = main.get_node("UI")
	await frames(5)

	# Café auf Stufe 11: gebaut, aber die Karte ist noch leer.
	gs.level = 11
	gs.coins = 10000
	for y in range(gs.land.position.y, gs.land.end.y):
		for x in range(gs.land.position.x, gs.land.end.x):
			if cafe_uid == 0 and gs.can_place("cafe", Vector2i(x, y)):
				cafe_uid = gs.place_object("cafe", Vector2i(x, y))
	if not check(cafe_uid > 0, "Café gebaut"):
		quit(1)
		return
	gs.clock_seconds = 11.0 * 3600.0
	ui.act_open("production", {"uid": cafe_uid})
	await frames(5)
	check(ui._sheet_name == "production", "Café-Sheet öffnet sich")
	check(String(ui._title.text).contains("Veganes Gartencafé"), "Titel nennt das Café")
	check(contains_label(ui.content, "Gäste"), "Gästebereich ist da")
	check(contains_label(ui.content, "Heute noch niemand bedient."), "leerer Tag wird erklärt")
	check(contains_label(ui.content, "Tisch 1 ist frei"), "ein Tisch steht bereit")
	check(contains_label(ui.content, "Sobald ein Gericht auf der Karte steht"), "leere Karte erklärt, warum niemand kommt")
	check(contains_label(ui.content, "Geöffnet"), "Öffnungszustand wird angezeigt")

	# Karte ab Stufe 14: jetzt kommen Gäste.
	gs.level = 14
	gs.coins = 10000
	seat_guest()
	await frames(5)
	check(gs.cafe_guests.size() == 1, "ein Gast sitzt am Tisch")
	var guest: Dictionary = gs.cafe_guests[0]
	var dish := str(guest["dish"])
	gs.add_item(dish, 2)
	ui.refresh_sheet()
	await frames(5)
	check(contains_label(ui.content, I18n.t("Tisch %d · %s") % [int(guest["table"]), str(guest["name"])]), "Gast wird am Tisch genannt")
	check(contains_label(ui.content, gd.item_name(dish)), "Bestellung steht auf der Karte")
	var serve := find_button(ui.content, "Servieren")
	if check(serve != null, "Servieren wird angeboten"):
		check(not serve.disabled, "mit Vorrat ist Servieren möglich")
		var stock_before: int = gs.item_count(dish)
		serve.pressed.emit()
		await frames(6)
		check(gs.item_count(dish) == stock_before - 1, "Servieren nimmt ein Gericht aus dem Vorrat")
		check(not gs.cafe_guests.is_empty() and float(gs.cafe_guests[0]["ate_at"]) > 0.0, "der Gast isst jetzt")
		check(contains_label(ui.content, "zahlt in"), "Restzeit bis zur Bezahlung wird gezeigt")
		check(find_button(ui.content, "Gehen lassen") == null, "wer schon isst, wird nicht hinausgeschickt")

	# Nach dem Essen zahlt der Gast; der Tagesumsatz wächst mit.
	var coins_before: int = gs.coins
	gs.cafe_guests[0]["ate_at"] = gs.now() - 1.0
	await create_timer(0.8).timeout
	await frames(6)
	check(gs.coins > coins_before, "nach dem Essen kommt Geld an")
	check(gs.cafe_day_served == 1 and gs.cafe_day_coins == gs.coins - coins_before, "Tagesumsatz wird gezählt")
	check(contains_label(ui.content, "Heute bedient: 1"), "Sheet zeigt den Tagesumsatz")
	check(gs.cafe_guest_at(int(guest["table"])).is_empty(), "der Tisch ist wieder frei")

	# Ohne Vorrat lässt sich nicht servieren – der Gast darf gehen.
	seat_guest()
	await frames(6)
	var waiting: Dictionary = gs.cafe_guests[0]
	gs.inventory.erase(str(waiting["dish"]))
	ui.refresh_sheet()
	await frames(5)
	var blocked := find_button(ui.content, "Servieren")
	if check(blocked != null, "Servieren bleibt sichtbar"):
		check(blocked.disabled, "ohne Vorrat ist Servieren gesperrt")
	var send_home := find_button(ui.content, "Gehen lassen")
	if check(send_home != null, "Gehen lassen wird angeboten"):
		var coins_now: int = gs.coins
		send_home.pressed.emit()
		await frames(6)
		check(gs.cafe_guests.is_empty(), "der Gast ist gegangen")
		check(gs.coins == coins_now, "Gehen lassen kostet nichts")
		check(contains_label(ui.content, "Tisch 1 ist frei"), "der Tisch ist wieder frei")

	# Nach Ladenschluss bleibt das Café ruhig.
	gs.clock_seconds = 20.0 * 3600.0
	ui.refresh_sheet()
	await frames(5)
	check(contains_label(ui.content, "Gerade geschlossen"), "geschlossenes Café wird angezeigt")
	check(gs.cafe_guests.is_empty(), "geschlossen sitzt niemand mehr")

	print("cafe UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	# Die Prüfungen vergleichen deutsche Texte; unabhängig von der Gerätesprache.
	I18n.apply("de")
	call_deferred("run")
