extends SceneTree
## UI-Test für die Nachbarschaft: der Briefkasten im Auftragsbuch, das Lesen,
## eine kleine Lieferung, der Besuch auf dem Nachbarhof und das Namensschild,
## das ein Nachbar ab Freundschaftsstufe 2 verschenkt – alles über die echte
## Oberfläche.

var gs: Node
var gd: Node
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
	if node is Button and String((node as Button).text).begins_with(prefix):
		return node as Button
	for child in node.get_children():
		var found := find_button(child, prefix)
		if found != null:
			return found
	return null


func find_named(node: Node, wanted: String) -> Button:
	if node is Button and String(node.name) == wanted:
		return node as Button
	for child in node.get_children():
		var found := find_named(child, wanted)
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


## Erzwingt die nächste Post, ohne auf den Takt zu warten.
func next_letter(count: int = 1) -> void:
	for i in range(count):
		gs.next_letter_at = 0.0
		gs._refresh_letters()


## Ob ein bestimmter Eintrag in der Chronik steht – er muss nicht der letzte sein,
## weil Freundschaftspunkte beim Lesen und beim Besuch zusammenkommen.
func _has_diary_key(key: String) -> bool:
	for entry in gs.diary:
		if str(entry.get("key", "")) == key:
			return true
	return false


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://letters_ui.json"
	save_system.delete_save()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	gd = root.get_node("GameData")
	ui = main.get_node("UI")
	await frames(5)
	gs.level = 1
	gs.coins = 500

	# Der Briefkasten ist ein Reiter im Hof-Bereich, nicht mehr im Auftragsbuch.
	ui.act_open("orders", {})
	await frames(6)
	check(not ui._sheet_tabs.visible, "das Auftragsbuch zeigt keine Reiter")
	ui.close_sheet()
	await frames(2)
	check(ui._nav_buttons.has("hof"), "die Navigation hat einen Hof-Bereich")
	var hof_button: Button = ui._nav_buttons["hof"]
	check(int(ui._badge_values.get("hof", -1)) == gs.unread_letters() + gs.claimable_hofbuch(), "der Hof-Badge zählt Post und offene Einträge")
	hof_button.pressed.emit()
	await frames(8)
	check(ui._sheet_name == "hof", "der Hof-Bereich öffnet sich")
	check(String(ui.state.get("hof_tab", "")) == "hofbuch", "der Hof beginnt beim Hofbuch")
	var letters_tab := find_button(ui._sheet_tabs, I18n.t("Briefe"))
	if check(letters_tab != null, "der Brief-Reiter steht unter dem Titel"):
		letters_tab.pressed.emit()
		await frames(8)
	check(ui._sheet_name == "hof" and String(ui.state.get("hof_tab", "")) == "letters", "der Brief-Reiter öffnet den Briefkasten")
	check(String(ui._title.text) == I18n.t("Briefkasten"), "der Briefkasten nennt sich beim Namen")
	check(contains_label(ui.content, I18n.t("Noch ist der Briefkasten leer. Die Nachbarschaft meldet sich bald – ganz ohne Eile.")), "der leere Briefkasten hat einen Text")
	check(gs.letters.is_empty(), "ohne Post gibt es keine Briefe")
	ui.close_sheet()
	await frames(2)

	# Ein Brief kommt von selbst; das Auftragsbuch zählt ihn.
	next_letter()
	await frames(4)
	if not check(gs.letters.size() == 1, "ein Brief ist angekommen"):
		quit(1)
		return
	var first: Dictionary = gs.letters[0]
	var sender := str(first["neighbor"])
	var sender_name: String = gs.neighbor_name(sender)
	ui._update_badges()
	check(int(ui._badge_values.get("hof", 0)) == 1 + gs.claimable_hofbuch(), "der Hof-Badge zählt die ungelesene Post")
	# Der alte Weg bleibt gültig: "letters" führt in den Hof auf den Brief-Reiter.
	ui.act_open("letters", {})
	await frames(8)
	check(ui._sheet_name == "hof" and String(ui.state.get("hof_tab", "")) == "letters", "Briefe öffnen über ihren Reiter")
	check(gs.unread_letters() == 0, "das Öffnen liest die Post")
	check(int(ui._badge_values.get("hof", 0)) == gs.claimable_hofbuch(), "der Badge erlischt nach dem Lesen")
	check(contains_label(ui.content, sender_name), "der Brief nennt den Absender")
	var definition: Dictionary = gs.letter_definition(first)
	check(contains_label(ui.content, String(definition.get("text", ""))), "der Brief zeigt seinen Text")
	check(gs.neighbor_points(sender) == gs.LETTER_READ_POINTS, "das Lesen zählt als Zuwendung")
	# Vor dem zweiten Brief bleibt der Hof verschlossen.
	var locked := find_button(ui.content, I18n.t("Ab %d Briefen") % gs.VISIT_LETTERS_REQUIRED)
	check(locked != null and locked.disabled, "vor dem zweiten Brief ist der Besuch gesperrt")
	ui.close_sheet()
	await frames(2)

	# Bis der Absender ein zweites Mal schreibt, kommen weitere Briefe an.
	var guard := 0
	while gs.letters_from(sender) < gs.VISIT_LETTERS_REQUIRED and guard < 12:
		next_letter()
		guard += 1
	check(gs.letters_from(sender) >= gs.VISIT_LETTERS_REQUIRED, "der Nachbar schreibt ein zweites Mal")
	ui.act_open("letters", {})
	await frames(6)
	var visit := find_button(ui.content, "Besuchen")
	if check(visit != null and not visit.disabled, "ab dem zweiten Brief lässt sich der Hof besuchen"):
		visit.pressed.emit()
		await frames(8)

	# Die Besuchsszene: Intro, zwei Stellen und der erste Satz.
	check(ui._sheet_name == "visit", "der Besuch öffnet sich")
	check(String(ui._title.text) == I18n.t("Zu Besuch bei %s") % sender_name, "der Besuch ist nach dem Nachbarn benannt")
	check(contains_label(ui.content, gs.neighbor_visit_intro(sender)), "die Szene erzählt das Intro")
	check(contains_label(ui.content, I18n.t("Noch ist nichts entdeckt. Zwei Stellen warten auf einen Blick.")), "beide Stellen sind noch offen")
	var spot: Button = find_named(ui.content, "NeighborSpot0")
	if check(spot != null, "die erste Stelle ist antippbar"):
		spot.pressed.emit()
		await frames(8)
	check(gs.neighbor_spots(sender) == [0], "die erste Stelle ist gefunden")
	check(contains_label(ui.content, String(gs.neighbor_spot_texts(sender)[0])), "der gefundene Satz steht in der Szene")
	# Beim Öffnen des Briefkastens gilt jede neue Post als gelesen; der Besuch
	# zählt zusätzlich. Deshalb zählen alle Briefe des Absenders mit.
	check(gs.neighbor_points(sender) == gs.letters_from(sender) * gs.LETTER_READ_POINTS + gs.VISIT_POINTS, "der Besuch zählt Freundschaft")
	check(int(gs.stats.get("neighbor_visits", 0)) == 1, "der Besuch wurde gezählt")
	check(str(gs.diary[gs.diary.size() - 1]["key"]) == "DIARY_NEIGHBOR_VISIT", "der Besuch steht im Tagebuch")
	var back := find_button(ui.content, "Zurück zum Briefkasten")
	if check(back != null, "der Besuch führt zurück zum Briefkasten"):
		back.pressed.emit()
		await frames(6)
	check(ui._sheet_name == "hof" and String(ui.state.get("hof_tab", "")) == "letters", "zurück im Briefbereich")
	check(not contains_label(ui.content, String(gs.neighbor_spot_texts(sender)[1])), "die zweite Stelle bleibt offen")
	ui.close_sheet()
	await frames(2)

	# Eine Bitte: ohne Ware gesperrt, mit Ware lieferbar.
	var request_letter := {}
	for letter in gs.letters:
		if not gs.letter_request(letter).is_empty() and not bool(letter.get("delivered", false)):
			request_letter = letter
			break
	if not check(not request_letter.is_empty(), "es gibt einen Brief mit Bitte"):
		quit(1)
		return
	var request: Dictionary = gs.letter_request(request_letter)
	var request_id := str(request_letter["id"])
	var requester := str(request_letter["neighbor"])
	var points_before_delivery: int = gs.neighbor_points(requester)
	# Nur dieser Brief liegt im Kasten, damit die Schaltfläche eindeutig ist.
	var other_letters: Array = gs.letters.filter(func(entry: Dictionary) -> bool: return entry != request_letter)
	gs.letters = [request_letter]
	gs.letters_changed.emit()
	ui.act_open("letters", {})
	await frames(6)
	var deliver := find_button(ui.content, I18n.t("Liefern  +%d") % int(request.get("coins", 0)))
	check(deliver != null and deliver.disabled, "ohne Ware ist die Lieferung gesperrt")
	for item_id in request["items"]:
		gs.add_item(str(item_id), int(request["items"][item_id]))
	ui.act_open("letters", {})
	await frames(6)
	var coins_before: int = gs.coins
	deliver = find_button(ui.content, I18n.t("Liefern  +%d") % int(request.get("coins", 0)))
	if check(deliver != null and not deliver.disabled, "mit Ware lässt sich liefern"):
		deliver.pressed.emit()
		await frames(8)
	check(bool(request_letter.get("delivered", false)), "der Brief ist beantwortet")
	check(gs.coins == coins_before + int(request.get("coins", 0)), "die Lieferung bringt Münzen")
	check(gs.neighbor_points(requester) == points_before_delivery + gs.LETTER_DELIVERY_POINTS, "die Lieferung zählt Freundschaft")
	check(contains_label(ui.content, I18n.t("Schon geliefert – danke!")), "der beantwortete Brief zeigt den Dank")
	check(find_button(ui.content, "Liefern  +") == null, "eine Bitte lässt sich nicht zweimal liefern")
	ui.close_sheet()
	await frames(2)
	# Die übrigen Briefe kommen in den Kasten zurück.
	gs.letters = [request_letter] + other_letters
	gs.letters_changed.emit()

	# Freundschaftsstufe 2: der Nachbar schenkt sein Namensschild.
	var sign_id: String = gs.neighbor_sign_deco(sender)
	var level_guard := 0
	while gs.neighbor_level(sender) < gs.NEIGHBOR_SIGN_LEVEL and level_guard < 20:
		gs.add_neighbor_friendship(sender, 1)
		level_guard += 1
	check(gs.neighbor_sign_unlocked(sender), "Stufe 2 schaltet das Namensschild frei")
	check(_has_diary_key("DIARY_NEIGHBOR_SIGN"), "das Geschenk steht im Tagebuch")
	ui.act_open_shop_tab("decos")
	await frames(6)
	check(contains_label(ui.content, String(gd.DECOS[sign_id]["name"])), "der Shop zeigt das geschenkte Schild")
	check(contains_label(ui.content, I18n.t("Geschenk der Nachbarschaft · kostenlos")), "das Schild ist als Geschenk gekennzeichnet")
	# Das Schild lässt sich aufstellen und wird gezeichnet.
	var placed := 0
	for y in range(gs.land.position.y, gs.land.end.y):
		for x in range(gs.land.position.x, gs.land.end.x):
			if placed == 0 and gs.can_place(sign_id, Vector2i(x, y)):
				placed = gs.place_object(sign_id, Vector2i(x, y))
	check(placed > 0, "das Namensschild lässt sich aufstellen")
	await frames(4)
	check(contains_label(ui.content, String(gd.DECOS[sign_id]["name"])), "der Shop bleibt nach dem Aufstellen bedienbar")
	ui.close_sheet()
	await frames(3)

	# Gespeichert und geladen bleibt die Nachbarschaft erhalten.
	var points_before: int = gs.neighbor_points(sender)
	var saved: Dictionary = gs.serialize()
	check((saved["letters"] as Array).size() == gs.letters.size(), "die Post steht im Spielstand")
	check(gs.deserialize(saved), "der Spielstand mit Nachbarschaft lädt")
	check(gs.neighbor_points(sender) == points_before, "die Freundschaft bleibt nach dem Laden")
	check(gs.visit_unlocked(sender), "der Besuch bleibt frei")

	print("letters UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	I18n.apply("de")
	call_deferred("run")
