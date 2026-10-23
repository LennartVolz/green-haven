extends SceneTree
## UI-Test für den Foto-Knopf: Die Kopfzeile hat eine Kamera, ein Tippen legt
## ein PNG ab, die Menüs verschwinden für die Aufnahme und kommen zurück, und
## das Fotoblatt zeigt Bild, Datum und die letzten Aufnahmen. Fotos bleiben
## Dateien – der Spielstand wächst nicht mit.

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


func find_named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := find_named(child, wanted)
		if found != null:
			return found
	return null


func find_button(node: Node, prefix: String) -> Button:
	if node is Button and String((node as Button).text).begins_with(prefix):
		return node as Button
	for child in node.get_children():
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


## Ein Bild, wie es der Bildschirm liefern würde – ohne Renderer, den es im
## Kopflos-Modus nicht gibt.
func sample_image() -> Image:
	var image := Image.create_empty(640, 360, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.55, 0.7, 0.4))
	return image


func clear_photos() -> void:
	var dir := DirAccess.open(Photos.directory())
	if dir == null:
		return
	for name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Photos.directory().path_join(str(name))))


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://photo_ui.json"
	save_system.delete_save()
	# Ein eigener Ordner: der Test darf keine echten Fotos wegräumen.
	Photos.path_override = "user://photo_ui"
	clear_photos()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	ui = main.get_node("UI")
	await frames(6)
	gs.level = 1
	gs.coins = 500

	# Die Kamera steht in der Kopfzeile, neben den Einstellungen.
	var camera: Button = find_named(ui._top, "CameraButton") as Button
	if not check(camera != null, "die Kopfzeile hat einen Foto-Knopf"):
		quit(1)
		return
	check(camera.tooltip_text == I18n.t("Foto vom Hof aufnehmen"), "der Foto-Knopf erklärt sich beim Halten (%s)" % camera.tooltip_text)
	check(camera.icon != null, "der Foto-Knopf zeigt eine Kamera")
	check(Photos.photos().is_empty(), "vor der ersten Aufnahme liegt kein Foto im Ordner")

	# Ein Tippen: Menüs weg, Bild aufgenommen, Menüs zurück, Blatt offen.
	ui.photo_source = func() -> Image: return sample_image()
	camera.pressed.emit()
	await frames(10)
	var saved: Array = Photos.photos()
	if not check(saved.size() == 1, "die Aufnahme landet als Datei im Fotoordner (%d)" % saved.size()):
		quit(1)
		return
	var first := str(saved[0])
	check(FileAccess.file_exists(first), "die Datei existiert")
	check(ui._top.visible and ui._side.visible and ui._nav.visible, "die Menüs sind nach der Aufnahme wieder da")
	check(ui._sheet_name == "photo", "das Fotoblatt öffnet sich nach der Aufnahme")
	check(String(ui._title.text) == I18n.t("Fotos"), "das Blatt heißt Fotos (%s)" % ui._title.text)
	check(contains_label(ui.content, first.get_file()), "das Blatt nennt die gespeicherte Datei")
	check(contains_label(ui.content, "Aufgenommen am "), "das Blatt nennt Datum und Uhrzeit")
	check(ui._toast_panel.visible and String(ui._toast_label.text).contains(first.get_file()), "der Hinweis nennt das gespeicherte Foto")
	var preview := find_named(ui.content, "PhotoImage") as TextureRect
	check(preview != null and preview.texture != null, "das Blatt zeigt das Foto")
	if preview != null:
		check(preview.size.y >= 100.0, "die Vorschau hat sichtbare Höhe (%.0f px)" % preview.size.y)
	var folder_button := find_button(ui.content, I18n.t("Ordner öffnen"))
	if OS.has_feature("android"):
		check(folder_button == null, "auf Android gibt es keinen Ordner-Knopf")
		check(contains_label(ui.content, I18n.t("Auf Android bleiben die Fotos im App-Ordner. Sie verlassen das Gerät nicht.")), "auf Android erklärt das Blatt den App-Ordner")
	else:
		check(folder_button != null, "auf dem Rechner lässt sich der Ordner öffnen")
	check(find_named(ui.content, "PhotoThumb0") == null, "bei einem einzigen Foto gibt es keinen Streifen")

	# Ein zweites Foto: der Streifen erscheint, ein Tippen zeigt das ältere Bild.
	ui.close_sheet()
	await frames(3)
	camera.pressed.emit()
	await frames(10)
	var two: Array = Photos.photos()
	check(two.size() == 2, "die zweite Aufnahme kommt dazu (%d)" % two.size())
	check(contains_label(ui.content, I18n.t("Zuletzt aufgenommen")), "ab dem zweiten Foto erscheint der Streifen")
	check(find_named(ui.content, "PhotoThumb0") != null and find_named(ui.content, "PhotoThumb1") != null, "der Streifen zeigt beide Aufnahmen")
	var older := find_named(ui.content, "PhotoThumb1") as Button
	if check(older != null, "das ältere Foto ist antippbar"):
		older.pressed.emit()
		await frames(8)
		check(contains_label(ui.content, String(two[1]).get_file()), "der Streifen öffnet die ältere Aufnahme (%s)" % String(two[1]).get_file())
	ui.close_sheet()
	await frames(2)

	# Ohne Bild: kein stiller Fehlschlag, sondern ein Hinweis und keine Datei.
	var before_failure: int = Photos.photos().size()
	ui.photo_source = func() -> Image: return null
	camera.pressed.emit()
	await frames(8)
	check(String(ui._toast_label.text) == I18n.t("Foto konnte nicht aufgenommen werden."), "ein fehlendes Bild meldet sich (%s)" % ui._toast_label.text)
	check(Photos.photos().size() == before_failure, "ein fehlgeschlagenes Foto legt keine Datei an")
	check(ui._sheet_name == "", "nach dem Fehlschlag bleibt kein leeres Blatt offen")

	# Die Sammlung bleibt erreichbar, ohne ein neues Foto zu machen.
	ui.photo_source = func() -> Image: return sample_image()
	ui.act_open("settings", {})
	await frames(6)
	var photos_button := find_button(ui.content, I18n.t("Fotos ansehen"))
	if check(photos_button != null, "die Einstellungen führen zu den Fotos"):
		photos_button.pressed.emit()
		await frames(8)
	check(ui._sheet_name == "photo", "der Weg über die Einstellungen öffnet das Fotoblatt")

	# Der Ordner wächst nicht unbegrenzt.
	for i in range(Photos.KEEP + 2):
		ui.act_photo()
		await frames(4)
	check(Photos.photos().size() == Photos.KEEP, "nach vielen Aufnahmen bleiben genau %d Fotos (%d)" % [Photos.KEEP, Photos.photos().size()])

	# Leerer Ordner: das Blatt erklärt, wie ein Foto entsteht.
	ui.close_sheet()
	clear_photos()
	await frames(2)
	ui.act_open("photo", {})
	await frames(6)
	check(contains_label(ui.content, I18n.t("Noch kein Foto aufgenommen. Tippe oben auf die Kamera, um deinen Hof zu fotografieren.")), "ohne Fotos erklärt das Blatt die Kamera")
	var shoot := find_button(ui.content, I18n.t("Foto aufnehmen"))
	if check(shoot != null, "das leere Blatt bietet das Fotografieren an"):
		shoot.pressed.emit()
		await frames(10)
	check(Photos.photos().size() == 1, "der Knopf im leeren Blatt nimmt ein Foto auf (%d)" % Photos.photos().size())
	check(ui._sheet_name == "photo" and find_named(ui.content, "PhotoImage") != null, "danach zeigt das Blatt die Aufnahme")
	ui.close_sheet()
	await frames(2)

	# Fotos sind Dateien; der Spielstand kennt sie nicht.
	check(not gs.serialize().has("photos"), "der Spielstand enthält keine Bilddaten")
	check(gs.SAVE_VERSION == 11, "die Spielstand-Version bleibt unverändert")

	ui.photo_source = Callable()
	clear_photos()
	Photos.path_override = ""
	print("photo UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	I18n.apply("de")
	call_deferred("run")
