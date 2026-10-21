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


func world_to_screen(world_node: Node, world_pos: Vector2) -> Vector2:
	return (world_pos - world_node.cam.position) * world_node.cam.zoom.x + world_node.get_viewport_rect().size * 0.5


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
	# Das Gelände wird in Chunks gestreamt und deckt den sichtbaren Ausschnitt lückenlos ab.
	var world = main.get_node("World")
	var terrain = world.terrain
	check(terrain._chunks.size() > 0, "Gelände-Chunks werden für den Startausschnitt erzeugt")
	var view: Rect2 = terrain.visible_world_rect()
	var chunk_cover := true
	for corner in [view.position + Vector2(1, 1), view.end - Vector2(1, 1)]:
		var cell := Vector2i(floori(corner.x / 128.0), floori(corner.y / 128.0))
		var hit := false
		for chunk in terrain._chunks.values():
			if chunk.bounds.has_point(cell):
				hit = true
				break
		chunk_cover = chunk_cover and hit
	check(chunk_cover, "der sichtbare Ausschnitt ist lückenlos mit Chunks belegt")
	var start_chunks: Array = terrain._chunks.keys()
	world.cam.position += Vector2(4000, 4000)
	await frames(3)
	var streamed := false
	for coord in terrain._chunks.keys():
		if not start_chunks.has(coord):
			streamed = true
			break
	check(streamed and terrain._chunks.size() > 0, "beim Schwenken werden neue Chunks nachgeladen")
	world.reset_camera()
	await frames(2)
	check(world.forage_layer != null and world.forage_layer.z_index == 1, "Sammel-Ebene für Wildware liegt über dem Gelände")
	check(world.forage_layer.view_rect().size.x > 0.0, "Sammel-Ebene kennt den sichtbaren Ausschnitt")
	gs.level = 6
	var forage_data: Node = root.get_node("GameData")
	var band: int = int(forage_data.FORAGE_BAND_CELLS)
	var forage_cell := Vector2i(-999, -999)
	for y in range(gs.land.position.y - band, gs.land.end.y + band):
		for x in range(gs.land.position.x - band, gs.land.end.x + band):
			if gs.forage_ready(Vector2i(x, y)):
				forage_cell = Vector2i(x, y)
				break
		if forage_cell.x != -999:
			break
	check(forage_cell.x != -999, "in der Umgebung gibt es eine reife Sammelstelle")
	if forage_cell.x != -999:
		var forage_id: String = gs.forage_spot_at(forage_cell)
		var forage_before: int = gs.item_count(forage_id)
		var forage_world := Vector2(forage_cell) * 128.0 + Vector2(64, 96)
		world._handle_tap(world_to_screen(world, forage_world))
		await frames(2)
		check(gs.item_count(forage_id) == forage_before + int(forage_data.FORAGE[forage_id]["amount"]), "Tippen in der Wildnis sammelt die Ware ein")
		check(int(gs.stats.get("foraged", 0)) == 1, "Sammeln wird in der Statistik gezählt")
	# Ziehen verschiebt immer die Kamera und erntet nicht nebenbei – auch mit aktivem Werkzeug.
	var swipe_cell := Vector2i(-999, -999)
	for y in range(gs.land.position.y - band, gs.land.end.y + band):
		for x in range(gs.land.position.x - band, gs.land.end.x + band):
			if Vector2i(x, y) != forage_cell and gs.forage_ready(Vector2i(x, y)):
				swipe_cell = Vector2i(x, y)
				break
		if swipe_cell.x != -999:
			break
	check(swipe_cell.x != -999, "es gibt eine zweite reife Sammelstelle")
	if swipe_cell.x != -999:
		var swipe_id: String = gs.forage_spot_at(swipe_cell)
		var swipe_before: int = gs.item_count(swipe_id)
		var foraged_before: int = int(gs.stats.get("foraged", 0))
		world.ui_blocker = Callable()
		world.reset_camera()
		# Im Testfenster ist der Viewport quadratisch; erst mit engerem Zoom ist die
		# Startfarm größer als die Anzeige und damit wirklich verschiebbar.
		world.cam.zoom = Vector2(1.5, 1.5)
		world._clamp_camera()
		var cam_before: Vector2 = world.cam.position
		var drag_start := world_to_screen(world, Vector2(swipe_cell) * 128.0 + Vector2(64, 96))
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = drag_start
		press.pressed = true
		world._on_touch(press)
		var motion := InputEventScreenDrag.new()
		motion.index = 0
		motion.position = drag_start + Vector2(0, 150)
		world._on_drag(motion)
		check(world.cam.position.distance_to(cam_before) > 10.0, "Ziehen verschiebt die Kamera über der Farm")
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.position = motion.position
		release.pressed = false
		world._on_touch(release)
		await frames(2)
		check(gs.item_count(swipe_id) == swipe_before and int(gs.stats.get("foraged", 0)) == foraged_before, "Ziehen erntet keine reife Stelle")
		# Mit aktivem Werkzeug bleibt das Verschieben möglich, ohne Felder zu bepflanzen.
		world.set_plant_tool("wheat")
		world.reset_camera()
		world.cam.zoom = Vector2(1.5, 1.5)
		world._clamp_camera()
		var cam_before_tool: Vector2 = world.cam.position
		var planted_before: int = int(gs.stats.get("planted", 0))
		var empty_cell := Vector2i(-1, -1)
		for c in gs.fields:
			if gs.fields[c].crop == "":
				empty_cell = c
				break
		check(empty_cell.x != -1, "es gibt ein leeres Feld für die Werkzeugprobe")
		var field_start := world_to_screen(world, gs.cell_center(empty_cell))
		var press_tool := InputEventScreenTouch.new()
		press_tool.index = 0
		press_tool.position = field_start
		press_tool.pressed = true
		world._on_touch(press_tool)
		var motion_tool := InputEventScreenDrag.new()
		motion_tool.index = 0
		motion_tool.position = field_start + Vector2(0, 150)
		world._on_drag(motion_tool)
		check(world.cam.position.distance_to(cam_before_tool) > 10.0, "Ziehen verschiebt die Karte auch mit aktivem Sä-Werkzeug")
		var release_tool := InputEventScreenTouch.new()
		release_tool.index = 0
		release_tool.position = motion_tool.position
		release_tool.pressed = false
		world._on_touch(release_tool)
		await frames(2)
		check(int(gs.stats.get("planted", 0)) == planted_before, "Ziehen sät keine Felder")
		# Tippen bleibt die Aktion zum Säen.
		world._handle_tap(world_to_screen(world, gs.cell_center(empty_cell)))
		await frames(2)
		check(int(gs.stats.get("planted", 0)) == planted_before + 1 and gs.fields[empty_cell].crop == "wheat", "Tippen sät weiterhin ein Feld")
		world.clear_tool()
		world.ui_blocker = Callable(ui, "is_over_ui")
		world.reset_camera()
		await frames(2)
	# Die Saat-Auswahl zeigt den aktuellen Wettereffekt und wetterbasierte Reifezeiten.
	gs.level = 1
	var weather_duration: float = root.get_node("GameData").WEATHER_DURATION_SECONDS
	for weather_case in [
		{"name": "Bewölkt", "time": weather_duration + 30.0, "effect": "Wachstum −10%", "rate": 0.9},
		{"name": "Regen", "time": 2.0 * weather_duration + 30.0, "effect": "Wachstum +25%", "rate": 1.25},
	]:
		gs.time_offset = float(weather_case["time"]) - Time.get_unix_time_from_system()
		ui.act_open("crops", {})
		await frames()
		check(contains_label(ui.content, "Wetter: %s" % weather_case["name"]), "Saat-Auswahl zeigt aktuelles Wetter (%s)" % weather_case["name"])
		check(contains_label(ui.content, String(weather_case["effect"])), "Saat-Auswahl zeigt Wachstumsbonus (%s)" % weather_case["name"])
		check(contains_label(ui.content, root.get_node("GameData").season_label_at(gs.day_number())), "Saat-Auswahl nennt die Jahreszeit (%s)" % weather_case["name"])
		check(contains_label(ui.content, root.get_node("GameData").season_effect_text_at(gs.day_number())), "Saat-Auswahl zeigt den Saisonbonus (%s)" % weather_case["name"])
		var wheat_grow: float = root.get_node("GameData").CROPS["wheat"]["grow"]
		var wheat_seconds: float = root.get_node("GameData").real_seconds_for_crop_growth(gs.now(), wheat_grow)
		check(contains_label(ui.content, "Reif in ca. %s" % root.get_node("GameData").format_time(wheat_seconds)), "Weizen-Reifezeit entspricht dem Wetterverlauf (%s)" % weather_case["name"])
		var weather_expected := wheat_grow / float(weather_case["rate"])
		check(is_equal_approx(wheat_seconds, weather_expected), "Wachstumsberechnung nutzt Wetterrate (%s)" % weather_case["name"])
		if String(weather_case["name"]) == "Bewölkt":
			gs.time_offset = 2.0 * weather_duration + 30.0 - Time.get_unix_time_from_system()
			ui._tick()
			var rain_seconds: float = root.get_node("GameData").real_seconds_for_crop_growth(gs.now(), wheat_grow)
			check(contains_label(ui.content, "Wetter: Regen · Wachstum +25%"), "offene Saat-Auswahl aktualisiert den Wetterhinweis beim Wetterwechsel")
			check(contains_label(ui.content, "Reif in ca. %s" % root.get_node("GameData").format_time(rain_seconds)), "offene Saat-Auswahl aktualisiert Reifezeiten beim Wetterwechsel")
		ui.close_sheet()
	gs.time_offset = 0.0
	# Mandeln sind ab Stufe 8 eine Feldfrucht und tauchen nicht mehr unter Land auf.
	gs.level = 8
	ui.act_open("crops", {})
	await frames()
	check(contains_label(ui.content, "Mandeln"), "Mandeln sind in der Pflanzenauswahl integriert")
	ui.act_open("shop", {"tab": "crops"})
	await frames()
	check(contains_label(ui.content, "Mandeln"), "Mandeln stehen im Shop unter Pflanzen")
	ui.act_open("shop", {"tab": "land"})
	await frames()
	check(not contains_label(ui.content, "Mandeln"), "Mandeln erscheinen nicht mehr unter Land")
	ui.close_sheet()
	# Tageszähler und Rückblick auf Ernten, Aufträge und Tiermomente.
	gs.new_game()
	var data: Node = root.get_node("GameData")
	gs.day_anchor = gs.now() - float(data.REAL_DAY_SECONDS)
	gs.bump("harvested", 3)
	gs.bump("orders", 1)
	gs.bump("pets", 2)
	ui._show_welcome_back()
	await frames()
	if check(ui._modal != null and ui._modal.visible, "Tagesrückblick öffnet sich"):
		check(contains_label(ui._modal, "Tag 2 · Rückblick"), "Rückblick nennt den neuen Tag")
		check(contains_label(ui._modal, "Ernten: 3"), "Rückblick zählt Ernten")
		check(contains_label(ui._modal, "Erfüllte Aufträge: 1"), "Rückblick zählt Aufträge")
		check(contains_label(ui._modal, "Tiermomente: 2"), "Rückblick zählt Tiermomente")
		ui._close_modal()
		await frames()
	ui._process(0.3)
	check(ui._day_label.text.begins_with("Tag 2"), "HUD zeigt den Tageszähler")
	check(ui._day_label.text.contains(data.season_name_at(gs.day_number())), "HUD nennt die Jahreszeit")
	# Der Tageswechsel im laufenden Spiel öffnet den Rückblick von selbst.
	gs.day_anchor -= float(data.REAL_DAY_SECONDS)
	gs.bump("harvested", 2)
	ui._process(0.3)
	await frames()
	if check(ui._modal != null and ui._modal.visible, "Tageswechsel öffnet den Rückblick automatisch"):
		check(contains_label(ui._modal, "Tag 3 · Rückblick"), "automatischer Rückblick nennt Tag 3")
		check(contains_label(ui._modal, "Ernten: 2"), "automatischer Rückblick zählt nur den neuen Tag")
		ui._close_modal()
		await frames()
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

	# Ton und Hintergrundmusik werden über echte Lautstärkeregler gesteuert.
	ui.act_open("settings", {})
	await frames()
	var music_available: bool = load("res://scripts/core/background_music.gd").track_available()
	var slider_script: GDScript = load("res://scripts/ui/volume_slider.gd")
	var sound_slider = ui.content.find_child("Volume_sound", true, false)
	var music_slider = ui.content.find_child("Volume_music", true, false)
	check(sound_slider != null and sound_slider.get_script() == slider_script, "Tonlautstärke ist ein Regler")
	check(music_slider != null and music_slider.get_script() == slider_script, "Musiklautstärke ist ein Regler")
	if sound_slider != null:
		var track: Rect2 = sound_slider.track_rect()
		var handle: Rect2 = sound_slider.handle_rect()
		check(track.size.x > 100.0 and track.size.y >= 12.0, "Tonregler zeichnet eine sichtbare Schiene")
		check(handle.size.x >= 40.0 and handle.size.x <= 64.0, "Tonregler hat einen sichtbaren Griff")
		check(sound_slider.size.y >= 64.0, "Tonregler ist hoch genug für den Finger")
		sound_slider.value = 0.4
		await frames()
		check(is_equal_approx(float(gs.settings.get("sound_volume", -1.0)), 0.4), "Tonregler speichert 40 %")
		sound_slider.value = 0.0
		await frames()
		check(is_equal_approx(float(gs.settings.get("sound_volume", -1.0)), 0.0), "Tonregler kann stumm schalten")
		sound_slider.value = 1.0
		await frames()
	if music_slider != null:
		if music_available:
			music_slider.value = 0.3
			await frames()
			check(is_equal_approx(float(gs.settings.get("music_volume", -1.0)), 0.3), "Musikregler speichert Lautstärke")
			music_slider.value = 1.0
			await frames()
		else:
			check(not music_slider.editable, "Musikregler ist ohne Track deaktiviert")

	# Neue Gebäude und Pflanzen erscheinen in Shop und Produktionsansicht.
	gs.level = 18
	gs.coins = 50000
	ui.act_open("shop", {"tab": "buildings"})
	await frames()
	check(contains_label(ui.content, "Nudelwerkstatt"), "Nudelwerkstatt steht im Gebäude-Shop")
	check(contains_label(ui.content, "Eismanufaktur"), "Eismanufaktur steht im Gebäude-Shop")
	check(contains_label(ui.content, "Zuckermühle"), "Zuckermühle steht im Gebäude-Shop")
	ui.act_open("shop", {"tab": "crops"})
	await frames()
	check(contains_label(ui.content, "Zucchini"), "Zucchini ist in der Pflanzenauswahl")
	check(contains_label(ui.content, "Rhabarber"), "Rhabarber ist in der Pflanzenauswahl")
	check(contains_label(ui.content, "Zuckerrohr"), "Zuckerrohr ist in der Pflanzenauswahl")
	ui.act_open("shop", {"tab": "land"})
	await frames()
	check(not contains_label(ui.content, "im Vorrat"), "keine fertige Zucker-Zutat mehr im Land-Shop")
	var new_buildings := {
		"sugarmill": [Vector2i(14, 17), "Zucker"],
		"florist": [Vector2i(8, 11), "Sonnenblumenstrauß"],
		"oilmill": [Vector2i(10, 11), "Sonnenblumenöl"],
		"preserves": [Vector2i(12, 11), "Erdbeerkonfitüre"],
		"pasta": [Vector2i(8, 17), "Weizennudeln"],
		"icecream": [Vector2i(10, 17), "Erdbeer-Eis"],
		"muesli": [Vector2i(12, 17), "Beeren-Müsli"],
	}
	for id in new_buildings:
		var spot: Vector2i = new_buildings[id][0]
		var uid: int = gs.place_object(str(id), spot)
		if check(uid > 0, "%s lässt sich platzieren" % id):
			ui.act_open("production", {"uid": uid})
			await frames()
			check(ui._sheet_name == "production" and contains_label(ui.content, String(new_buildings[id][1])), "%s zeigt sein Rezept" % id)
	ui.close_sheet()

	# Der Gartentag bekommt im HUD und Auftragsbuch echte Sichtbarkeit.
	gs.new_game()
	gs.level = 11
	gs.coins = 5000
	var event_cafe_uid: int = gs.place_object("cafe", Vector2i(8, 11))
	check(event_cafe_uid > 0, "Café kann für Gartentag-UI-Test gebaut werden")
	gs.time_offset = float(gs.neighborhood_event_cycle_at(gs.now())) * gs.NEIGHBORHOOD_EVENT_CYCLE_SECONDS - Time.get_unix_time_from_system() + 10.0
	gs.neighborhood_event_stage = 0
	gs._fill_orders()
	ui.act_open("orders", {})
	await frames()
	check(contains_label(ui.content, "Gartentag · Samen & Geschichten"), "Gartentag-Abschnitt erscheint im Auftragsbuch")
	check(contains_label(ui.content, "Gartentag läuft"), "laufendes Event zeigt Restzeit im Auftragsbuch")
	var event_order_card := find_button(ui.content, "Liefern")
	check(event_order_card != null, "Eventbestellung wird mit echter Lieferaktion angezeigt")

	# Café-Besuchsgeschichte erscheint im Auftragsbuch an der echten Oberfläche.
	gs.new_game()
	gs.level = 13
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

	# Saisonziele: eigener Block im Ziele-Menü, mit Resttagen und Belohnung.
	gs.new_game()
	ui.act_open("quests", {})
	await frames()
	var days_left: int = int(data.SEASON_DAYS) - int(data.season_day_at(gs.day_number()))
	var days_text := "letzter Tag" if days_left == 0 else ("noch 1 Tag" if days_left == 1 else "noch %d Tage" % days_left)
	check(contains_label(ui.content, "%s · %s" % [data.season_name_at(gs.day_number()), days_text]), "Ziele-Menü nennt Jahreszeit und Resttage")
	check(contains_label(ui.content, "Erdbeeren ernten"), "Saisonziel erscheint in seiner Jahreszeit")
	check(contains_label(ui.content, "Blütenbogen"), "Saisonbelohnung wird im Ziele-Menü genannt")
	gs.bump("harvested:strawberry", 12)
	ui._update_badges()
	check(int(ui._badge_values.get("quests", 0)) == 1, "Badge zählt abholbare Saisonziele")
	ui.refresh_sheet()
	await frames()
	var season_claim := find_button(ui.content, "Abholen")
	if check(season_claim != null, "erfülltes Saisonziel ist in der UI abholbar"):
		season_claim.pressed.emit()
		await frames()
		check(gs.claimed_quests.has("season:%d:spring_strawberries" % gs.season_epoch()), "Saisonziel wird über die UI abgeholt")
	ui._update_badges()
	check(int(ui._badge_values.get("quests", 0)) == 0, "Badge verschwindet nach dem Abholen")
	# Hofbuch öffnet über die Erfolge.
	ui.act_open("achievements", {})
	await frames()
	check(ui._sheet_name == "achievements" and ui._title.text == "Erfolge", "Erfolge öffnen über die Navigation")
	check(ui.content.get_child_count() == GameData.ACHIEVEMENTS.size() + 2, "alle Erfolge und der Hofbuch-Knopf werden angezeigt")
	check(contains_label(ui.content, "Geschichten am Kaffeetisch"), "Café-Meilenstein erscheint in der echten Erfolge-UI")
	var book_button := find_button(ui.content, "Hofbuch öffnen")
	if check(book_button != null, "Erfolge bieten das Hofbuch an"):
		book_button.pressed.emit()
		await frames()
		check(ui._sheet_name == "hofbuch" and ui._title.text == "Hofbuch", "Hofbuch öffnet über die Erfolge")
		check(contains_label(ui.content, "Ein Jahr im Garten"), "Hofbuch zeigt die Jahres-Auszeichnung")
		check(contains_label(ui.content, "Jahresbaum"), "Hofbuch nennt die Belohnungsdeko")
		check(ui.content.get_child_count() == GameData.HOFBUCH.size() + 1, "alle acht Auszeichnungen werden angezeigt")
	print("achievements UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	call_deferred("run")
