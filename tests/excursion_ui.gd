extends SceneTree
## UI-Test für Tierausflüge: die Karte im Refugium, das Begleiten über die echte
## Oberfläche, die Szene mit Foto, der Eintrag im Tagebuch und der Tagesablauf
## im Tier-Sheet.

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


## Zählt die kleinen Tiervorschauen – sie stehen im Foto und im Tagebuch und
## tragen dort einen eigenen Namen.
func count_previews(node: Node) -> int:
	var n := 1 if String(node.name).begins_with("PhotoAnimal") else 0
	for child in node.get_children():
		n += count_previews(child)
	return n


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://excursion_ui.json"
	save_system.delete_save()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	gd = root.get_node("GameData")
	ui = main.get_node("UI")
	await frames(5)

	# Zwei Tiere in einem Gehege sind die Voraussetzung.
	gs.level = 8
	gs.coins = 10000
	var paddock := 0
	for y in range(gs.land.position.y, gs.land.end.y):
		for x in range(gs.land.position.x, gs.land.end.x):
			if paddock == 0 and gs.can_place("paddock", Vector2i(x, y)):
				paddock = gs.place_object("paddock", Vector2i(x, y))
	if not check(paddock > 0, "Gehege gebaut"):
		quit(1)
		return
	var rabbit: int = gs.adopt_animal("rabbit")
	var chicken: int = gs.adopt_animal("chicken")
	if not check(rabbit > 0 and chicken > 0, "zwei Tiere aufgenommen"):
		quit(1)
		return
	gs.clock_seconds = 9.0 * 3600.0
	gs.excursion_next_at = 0.0
	gs._tick_excursions(0.5)
	if not check(gs.excursion_active(), "ein Ausflug läuft"):
		quit(1)
		return
	var destination: Dictionary = gs.excursion_destination()
	var names: Array = []
	for a in gs.excursion_participants():
		names.append(String(a.name))

	# Das Refugium zeigt die beiden samt Ziel und Einladung.
	ui.act_open("refuge", {})
	await frames(6)
	check(ui._sheet_name == "refuge", "Refugium öffnet sich")
	check(contains_label(ui.content, I18n.t("Ausflug %s") % String(destination["place"])), "die Ausflugskarte nennt das Ziel")
	check(contains_label(ui.content, I18n.t("%s und %s sind zusammen unterwegs.") % [names[0], names[1]]), "die Karte nennt beide Tiere")
	var join := find_button(ui.content, "Begleiten")
	if check(join != null, "die Karte bietet das Begleiten an"):
		join.pressed.emit()
		await frames(8)

	# Die Szene: Titel, Foto, zwei Sätze und das Herz.
	check(ui._sheet_name == "excursion", "die Szene öffnet sich")
	check(String(ui._title.text).begins_with("Ausflug"), "die Szene ist überschrieben")
	check(count_previews(ui.content) >= 2, "das Foto zeigt beide Tiere (%d Vorschauen)" % count_previews(ui.content))
	check(contains_label(ui.content, String(destination["text"][0])), "die Szene erzählt den ersten Satz")
	check(contains_label(ui.content, String(destination["text"][1])), "die Szene erzählt den zweiten Satz")
	check(contains_label(ui.content, I18n.t("Jedes der beiden Tiere hat ein Herz dazugewonnen.")), "die Szene nennt das Herz")
	check(int(gs.stats.get("excursions", 0)) == 1, "der Ausflug wurde gezählt")

	# Über die Szene ins Tagebuch: dort hängt das Foto.
	var diary := find_button(ui.content, "Im Tagebuch ansehen")
	if check(diary != null, "die Szene führt ins Tagebuch"):
		diary.pressed.emit()
		await frames(6)
	check(ui._sheet_name == "diary", "das Tagebuch öffnet sich")
	check(contains_label(ui.content, "Foto ·"), "das Foto steht im Tagebuch")
	check(count_previews(ui.content) >= 2, "das Tagebuch zeigt die Tiere im Foto")
	check(contains_label(ui.content, names[0]), "der Eintrag nennt das erste Tier")

	# Zurück im Refugium steht die Erinnerung, aber kein zweites Begleiten.
	ui.act_open("refuge", {})
	await frames(6)
	check(contains_label(ui.content, I18n.t("Ihr wart dabei – das Foto liegt im Refugiums-Tagebuch.")), "das Refugium kennt die Erinnerung")
	check(find_button(ui.content, "Begleiten") == null, "derselbe Ausflug lässt sich nicht doppelt begleiten")

	# Nach der Rückkehr verschwindet die Karte.
	gs.time_offset += 200.0
	gs._tick_excursions(0.5)
	await frames(6)
	check(not contains_label(ui.content, "Ausflug"), "nach der Rückkehr ist die Karte weg")

	# Tagesablauf im Tier-Sheet: mittags Schatten, unterwegs als Ausnahme.
	gs.clock_seconds = 12.0 * 3600.0
	ui.act_open("animal", {"uid": rabbit})
	await frames(6)
	check(contains_label(ui.content, I18n.t("Tagesablauf: gerade im Schatten")), "das Tier-Sheet zeigt den Tagesablauf")
	ui.close_sheet()
	await frames(2)

	# Ein neuer Ausflug macht die Tiere im Tier-Sheet sichtbar unerreichbar.
	gs.add_item("carrot", 2)
	gs.add_item("wheat", 2)
	gs.excursion_next_at = 0.0
	gs._tick_excursions(0.5)
	if check(gs.excursion_active(), "ein zweiter Ausflug läuft"):
		var away := int(gs.excursion.get("animals", [rabbit])[0])
		ui.act_open("animal", {"uid": away})
		await frames(6)
		check(contains_label(ui.content, "Unterwegs"), "das Tier-Sheet zeigt den Ausflug")
		check(contains_label(ui.content, String(gs.excursion_destination().get("place", ""))), "das Tier-Sheet nennt das Ziel")
		var feed := find_button(ui.content, "Füttern")
		check(feed != null and feed.disabled, "unterwegs lässt sich nicht füttern")
		var pet := find_button(ui.content, "Streicheln")
		check(pet != null and pet.disabled, "unterwegs lässt sich nicht streicheln")

	print("excursion UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	I18n.apply("de")
	call_deferred("run")
