extends SceneTree
## Spielt eine Szenenfolge durch und speichert Screenshots (zur visuellen Prüfung).
## Start (mit Display, z. B. xvfb):
##   godot --path . --rendering-driver opengl3 --resolution 960x540 -s res://tests/screenshots.gd -- /pfad/zum/ordner

var out_dir := "/tmp"
var gs: Node
var main: Node
var world: Node2D
var ui: Node
var shots := 0
var log: Array = []


func find_button_with_prefix(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and String((child as Button).text).begins_with(prefix):
			return child as Button
		var found: Button = find_button_with_prefix(child, prefix)
		if found != null:
			return found
	return null


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


func shot(name: String) -> void:
	await frames(4)
	if DisplayServer.get_name() == "headless":
		print("screenshot skipped (headless dummy renderer): ", name)
		return
	var img := root.get_texture().get_image()
	if name == "start":
		assert(img.get_width() > img.get_height(), "Startbild muss im Querformat sein: %s" % img.get_size())
		var cell: Vector2i = gs.fields.keys()[0]
		var p := win(world_to_screen(gs.cell_center(cell)))
		var soil := img.get_pixel(clampi(roundi(p.x), 0, img.get_width() - 1), clampi(roundi(p.y), 0, img.get_height() - 1))
		assert(soil.r > soil.g and soil.r > 0.25, "Startfeld muss im Screenshot als sichtbarer Boden gerendert sein: %s" % soil)
		assert(world.terrain.is_visible_in_tree() and world.fields_layer.is_visible_in_tree(), "Terrain und Felder müssen sichtbar sein")
	if name == "land_button":
		assert(ui._sheet.visible and ui._sheet.size.y > 0.0, "Land-Shop muss eine positive sichtbare Höhe haben: %s" % ui._sheet.size)
		assert(ui.content.get_child_count() >= 2, "Land-Shop muss Erweiterungs-Karten enthalten")
	var path := "%s/%02d_%s.png" % [out_dir, shots, name]
	img.save_png(path)
	shots += 1
	print("shot ", path, " ", img.get_size())


func win(p: Vector2) -> Vector2:
	## Viewport-Koordinaten (1920x1080) -> Fensterkoordinaten
	return p * Vector2(root.size) / root.get_visible_rect().size


func tap(vp_pos: Vector2) -> void:
	var p := win(vp_pos)
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = p
	d.pressed = true
	Input.parse_input_event(d)
	await frames(2)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = p
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)


func drag(a_vp: Vector2, b_vp: Vector2, steps: int = 8) -> void:
	var a := win(a_vp)
	var b := win(b_vp)
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = a
	d.pressed = true
	Input.parse_input_event(d)
	await frames(1)
	for i in range(1, steps + 1):
		var m := InputEventScreenDrag.new()
		m.index = 0
		m.position = a.lerp(b, float(i) / float(steps))
		m.relative = (b - a) / float(steps)
		Input.parse_input_event(m)
		await frames(1)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = b
	u.pressed = false
	Input.parse_input_event(u)
	await frames(3)


func world_to_screen(w: Vector2) -> Vector2:
	var vp := root.get_visible_rect().size
	return (w - world.cam.position) * world.cam.zoom.x + vp * 0.5


func _initialize() -> void:
	# Die Prüfungen vergleichen deutsche Texte; unabhängig von der Gerätesprache.
	I18n.apply("de")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_node("SaveSystem").path_override = "user://shots_save.json"
	root.get_node("SaveSystem").delete_save()
	gs = root.get_node("GameState")
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	world = main.get_node("World")
	ui = main.get_node("UI")
	run()


func run() -> void:
	await frames(10)
	print("viewport ", root.get_visible_rect().size)
	await shot("start")
	assert(world.terrain.z_index == 0, "Terrain muss über der Clear-Color gezeichnet werden")
	assert(world.fields_layer.z_index > world.terrain.z_index, "Felder müssen über dem Terrain liegen")
	assert(world.fields_layer.z_index < world.entities.z_index, "Felder müssen unter Gebäuden und Tieren liegen")
	var land_button := ui._side.get_child(1) as Button
	assert(land_button.text == "Land" and land_button.is_visible_in_tree(), "Direkter Land-Button muss sichtbar sein")
	land_button.pressed.emit()
	await frames(3)
	assert(ui._sheet_name == "shop" and ui.state.get("shop_tab", "") == "land", "Land-Button muss die Land-Erweiterung öffnen")
	assert(ui.content.get_child_count() > 0 and ui._title.text == "Shop", "Shop-Land-Tab muss Inhalte zeigen")
	await shot("land_button")
	ui.close_sheet()

	# Feld antippen -> Saatauswahl
	var cell: Vector2i = gs.fields.keys()[0]
	await tap(world_to_screen(gs.cell_center(cell)))
	assert(ui._sheet.size.y > 0.0 and ui._sheet.size.y < ui._layer.size.y * 0.9, "Sheet muss nach dem Öffnen in den Viewport passen: %s" % ui._sheet.size)
	log.append("sheet after field tap: %s" % ui._sheet_name)
	await shot("crops_sheet")
	# Weizen wählen -> Werkzeug
	ui.act_plant_pick("wheat", cell)
	await frames(3)
	log.append("tool after pick: %s, planted=%s" % [world.tool_mode, gs.stats.get("planted", 0)])
	# Felder einzeln antippen
	var cells: Array = gs.fields.keys()
	for i in range(mini(4, cells.size())):
		await tap(world_to_screen(gs.cell_center(cells[i])))
	log.append("planted after taps: %s" % gs.stats.get("planted", 0))
	await shot("planted_taps")
	world.clear_tool()
	gs.time_offset += 16.0
	await frames(3)
	await shot("growing")
	gs.time_offset += 20.0
	await frames(3)
	await shot("ripe")
	# Ernte per Tippen
	for i in range(mini(4, cells.size())):
		await tap(world_to_screen(gs.cell_center(cells[i])))
	log.append("harvested after taps: %s wheat=%s" % [gs.stats.get("harvested", 0), gs.item_count("wheat")])
	await shot("harvested")

	# Headless hat ein quadratisches Dummy-Viewport ohne Kamerabewegung; visuelle
	# Szenen werden dort übersprungen, die restlichen Logik-Tests laufen normal.
	if DisplayServer.get_name() == "headless":
		print("visual screenshot scenes unavailable on headless renderer")
		quit()
		return

	# Kamera: verschieben und zoomen
	var cp0: Vector2 = world.cam.position
	await drag(Vector2(1100, 500), Vector2(900, 500), 8)
	var camera_delta: Vector2 = world.cam.position - cp0
	assert(camera_delta.length() > 0.0, "Kamera muss sich im Querformat per Wischgeste bewegen")
	log.append("camera moved: %s" % camera_delta)
	world.zoom_at(Vector2(960, 540), 0.8)
	await frames(2)
	log.append("zoom: %s" % world.cam.zoom)
	world.reset_camera()

	# Fortgeschrittener Spielstand
	gs.coins = 20000
	while gs.level < 9:
		gs.add_xp(root.get_node("GameData").xp_needed(gs.level))
	await frames(2)
	ui._close_modal()
	ui._close_modal()
	ui._close_modal()
	ui._close_modal()
	ui._close_modal()
	ui._close_modal()
	ui._close_modal()
	ui._close_modal()
	await frames(2)
	gs.place_object("bakery", Vector2i(8, 11))
	gs.place_object("kitchen", Vector2i(10, 11))
	gs.place_object("milkery", Vector2i(12, 11))
	gs.place_object("tofu", Vector2i(14, 11))
	gs.place_object("paddock", Vector2i(8, 16))
	gs.place_object("tree", Vector2i(13, 14))
	gs.place_object("bench", Vector2i(13, 16))
	gs.place_object("scarecrow", Vector2i(15, 14))
	gs.place_object("pond", Vector2i(12, 17))
	gs.place_object("lantern", Vector2i(15, 17))
	gs.place_object("flowers", Vector2i(14, 18))
	gs.place_object("bush", Vector2i(15, 18))
	for s in ["cow", "pig", "sheep"]:
		gs.adopt_animal(s)
	gs.expand_land()
	for cs in gs.fields.keys():
		gs.fields[cs] = {"crop": "", "t": 0.0}
	var crops := ["carrot", "potato", "tomato", "corn"]
	var ci := 0
	for cs in gs.fields.keys():
		gs.fields[cs] = {"crop": crops[ci % crops.size()], "t": gs.now() - 5.0 - float(ci) * 20.0}
		ci += 1
	gs.add_item("wheat", 20)
	gs.add_item("carrot", 12)
	gs.add_item("soy", 6)
	gs.add_item("oat", 9)
	gs.add_item("apple", 3)
	gs.add_item("strawberry", 8)
	gs.world_changed.emit()
	for o in gs.objects:
		if o.type == "bakery":
			gs.start_recipe(o.uid, "bread")
			gs.start_recipe(o.uid, "bread")
		if o.type == "tofu":
			gs.start_recipe(o.uid, "tofu")
	gs.time_offset += 70.0
	await frames(3)
	world.reset_camera()
	await shot("farm_built")
	# Kosmetische Ambient-Szenen für die manuelle Sichtprüfung.
	var game_data: Node = root.get_node("GameData")
	gs.time_offset = 2.0 * game_data.WEATHER_DURATION_SECONDS + 30.0 - Time.get_unix_time_from_system()
	gs.clock_seconds = 12.0 * 3600.0
	world.day_time_seconds = 12.0 * 3600.0
	world.current_weather = "Regen"
	world.overlay.set_weather("Regen")
	world._ambient_night = false
	world._update_animal_ambience()
	for animal_node in world._animal_nodes.values():
		animal_node.position = animal_node.get("bounds").end - Vector2(20, 18)
	# Tiere bewegen sich mit artspezifischer Laufgeschwindigkeit; die langsame Kuh
	# benötigt für den Weg vom Rand des Geheges mehrere Sekunden.
	await frames(900)
	assert(world.current_weather == "Regen" and world._animal_nodes.values().all(func(animal: Node) -> bool: return bool(animal.get("sheltering")) and animal.position.distance_to(animal.get("ambient_target")) < 1.0), "Regen-Screenshot zeigt alle Tiere angekommen im Unterstand")
	await shot("animals_rain_shelter")
	gs.clock_seconds = 22.0 * 3600.0
	world.day_time_seconds = 22.0 * 3600.0
	world._ambient_night = true
	for animal_node in world._animal_nodes.values():
		animal_node.set_ambient("Regen", true, world.day_time_seconds)
	await frames(40)
	assert(world._animal_nodes.values().all(func(animal: Node) -> bool: return bool(animal.get("sheltering"))), "Nacht-Screenshot zeigt alle Tiere im Unterstand")
	assert(world._animal_nodes.values().any(func(animal: Node) -> bool: return bool(animal.get("sleeping"))), "Nacht-Screenshot zeigt mindestens ein schlafendes Tier")
	await shot("animals_sleeping")
	gs.time_offset = 3.0 * game_data.WEATHER_DURATION_SECONDS + 2.0 - Time.get_unix_time_from_system()
	world.current_weather = "Nebel"
	world.overlay.set_weather("Nebel")
	gs.clock_seconds = 12.0 * 3600.0
	world.day_time_seconds = 12.0 * 3600.0
	world._ambient_night = false
	world._update_animal_ambience()
	await frames(20)
	assert(game_data.weather_at(gs.now()) == "Nebel" and game_data.rainbow_strength_at(gs.now(), false) > 0.0, "Regenbogen-Screenshot liegt in den ersten Nebelsekunden")
	await shot("after_rain_rainbow")
	gs.time_offset = 0.0

	ui.act_open("shop", {})
	await frames(3)
	await shot("sheet_shop_crops")
	ui.state["shop_tab"] = "buildings"
	ui.refresh_sheet()
	await frames(3)
	await shot("sheet_shop_buildings")
	ui.state["shop_tab"] = "land"
	ui.refresh_sheet()
	await frames(3)
	await shot("sheet_shop_land")
	# Acht Aufträge erzwingen echte Scrollstrecke und testen Touch-Drag im Sheet.
	# Vier reichen seit den kompakten Auftragskarten nicht mehr: Sie passen auf einen Blick.
	var order_template: Dictionary = gs.generate_order()
	gs.orders.clear()
	for i in range(gs.MAX_ORDERS * 2):
		var order: Dictionary = order_template.duplicate(true)
		order["id"] = 9000 + i
		order["customer"] = "Kundschaft %d" % (i + 1)
		gs.orders.append(order)
	ui.act_open("orders", {})
	await frames(5)
	var orders_scroll: ScrollContainer = ui._scroll
	var scroll_bar := orders_scroll.get_v_scroll_bar()
	assert(scroll_bar.max_value > scroll_bar.page, "Auftragsbuch mit acht Karten muss scrollbar sein")
	var scroll_rect := orders_scroll.get_global_rect()
	var start_scroll := Vector2(scroll_rect.position.x + scroll_rect.size.x * 0.5, scroll_rect.position.y + scroll_rect.size.y * 0.8)
	var end_scroll := Vector2(start_scroll.x, scroll_rect.position.y + scroll_rect.size.y * 0.25)
	await drag(start_scroll, end_scroll, 12)
	await frames(3)
	assert(orders_scroll.scroll_vertical > 0, "Touch-Wisch auf Auftragskarten muss nach unten scrollen")
	print("order touch scroll passed: %d / %d" % [orders_scroll.scroll_vertical, scroll_bar.max_value - scroll_bar.page])
	if DisplayServer.get_name() == "headless":
		var saved_scroll := orders_scroll.scroll_vertical
		ui.refresh_sheet()
		await frames(3)
		assert(absf(float(orders_scroll.scroll_vertical - saved_scroll)) < 2.0, "Sheet-Aktualisierung behält die Scrollposition")
		print("order refresh scroll restore passed: %d" % orders_scroll.scroll_vertical)
		var down_scroll := orders_scroll.scroll_vertical
		start_scroll.y = scroll_rect.position.y + scroll_rect.size.y * 0.25
		end_scroll.y = scroll_rect.position.y + scroll_rect.size.y * 0.8
		await drag(start_scroll, end_scroll, 12)
		assert(orders_scroll.scroll_vertical < down_scroll, "Touch-Wisch zurück nach oben funktioniert ebenfalls")
		print("reverse order touch scroll passed: %d" % orders_scroll.scroll_vertical)
		ui.act_open("refuge", {})
		await frames(3)
		var diary_button: Button
		for child in ui.content.get_children():
			if child is Button and String(child.text).begins_with("Refugiums-Tagebuch"):
				diary_button = child
				break
		assert(diary_button != null, "Refugium zeigt den Einstieg ins Tagebuch")
		diary_button.pressed.emit()
		await frames(3)
		assert(ui._sheet_name == "diary" and ui._title.text == "Refugiums-Tagebuch", "Tagebuch-Einstieg öffnet das richtige Sheet")
		assert(ui.content.get_child_count() > 1, "Tagebuch zeigt Einträge")
		ui.act_open("orders", {})
		await frames(2)
		var story_button := find_button_with_prefix(ui.content, "Geschichte beginnen")
		if story_button == null:
			printerr("FAIL: keine Story-Startschaltfläche; Level=%d verfügbar=%s active=%s title=%s children=%d" % [gs.level, str(gs.available_delivery_stories()), gs.active_delivery_story, ui._title.text, ui.content.get_child_count()])
			ui.close_sheet()
			quit(1)
			return
		story_button.pressed.emit()
		await frames(3)
		assert(not gs.active_delivery_story.is_empty(), "UI-Start aktiviert eine Liefergeschichte")
		assert(ui._sheet_name == "orders", "Auftragsbuch bleibt nach dem Start geöffnet")
		# Das Scroll-Fixture füllt alle vier Plätze; nach einem freigewordenen
		# regulären Auftrag muss die Reihe ihren reservierten Platz erhalten.
		for order in gs.orders:
			if not order.has("story_text"):
				gs.skip_order(int(order.id))
				break
		gs._fill_orders()
		var has_story_order := false
		for order in gs.orders:
			if order.has("story_text"):
				has_story_order = true
				break
		assert(has_story_order, "Storyauftrag wird im Auftragsbuch angezeigt")
		ui.act_open("achievements", {})
		await frames(3)
		assert(ui._sheet_name == "achievements" and ui._title.text == "Erfolge", "Erfolge öffnen sich über die Navigation")
		assert(ui.content.get_child_count() == root.get_node("GameData").ACHIEVEMENTS.size() + 1, "Erfolgsübersicht zeigt alle Meilensteine")
		ui.close_sheet()
		quit()
		return
	var saved_scroll := orders_scroll.scroll_vertical
	ui.refresh_sheet()
	await frames(3)
	assert(orders_scroll.scroll_vertical > 0 and absf(orders_scroll.scroll_vertical - saved_scroll) < 2.0, "Sheet-Aktualisierung erhält die Scrollposition")
	await shot("sheet_orders_scrolled")
	var current_scroll := orders_scroll.scroll_vertical
	start_scroll.y = scroll_rect.position.y + scroll_rect.size.y * 0.25
	end_scroll.y = scroll_rect.position.y + scroll_rect.size.y * 0.8
	await drag(start_scroll, end_scroll, 12)
	assert(orders_scroll.scroll_vertical < current_scroll, "Touch-Wisch nach unten scrollt wieder zum Anfang")
	print("reverse order touch scroll passed: %d" % orders_scroll.scroll_vertical)
	await shot("sheet_orders")
	ui.act_open("inventory", {})
	await shot("sheet_inventory")
	ui.act_open("refuge", {})
	await shot("sheet_refuge")
	var diary_button: Button
	for child in ui.content.get_children():
		if child is Button and String(child.text).begins_with("Refugiums-Tagebuch"):
			diary_button = child
			break
	assert(diary_button != null, "Refugium zeigt den Einstieg ins Tagebuch")
	diary_button.pressed.emit()
	await frames(3)
	assert(ui._sheet_name == "diary" and ui._title.text == "Refugiums-Tagebuch", "Tagebuch-Einstieg öffnet das richtige Sheet")
	assert(ui.content.get_child_count() > 1, "Tagebuch zeigt Einträge")
	await shot("sheet_diary")
	ui.act_open("orders", {})
	await frames(2)
	var story_button := find_button_with_prefix(ui.content, "Geschichte beginnen")
	assert(story_button != null, "Auftragsbuch bietet freigeschaltete Geschichten an")
	story_button.pressed.emit()
	await frames(3)
	assert(not gs.active_delivery_story.is_empty(), "UI-Start aktiviert eine Liefergeschichte")
	assert(ui._sheet_name == "orders", "Auftragsbuch bleibt nach dem Start geöffnet")
	for order in gs.orders:
		if not order.has("story_text"):
			gs.skip_order(int(order.id))
			break
	gs._fill_orders()
	var has_story_order := false
	for order in gs.orders:
		if order.has("story_text"):
			has_story_order = true
			break
	assert(has_story_order, "Storyauftrag wird im Auftragsbuch angezeigt")
	await shot("sheet_story_order")
	ui.act_open("achievements", {})
	await frames(3)
	assert(ui._sheet_name == "achievements" and ui._title.text == "Erfolge", "Erfolge öffnen sich über die Navigation")
	assert(ui.content.get_child_count() == root.get_node("GameData").ACHIEVEMENTS.size() + 1, "Erfolgsübersicht zeigt alle Meilensteine")
	await shot("sheet_achievements")
	ui.act_open("animal", {"uid": gs.animals[0].uid})
	await shot("sheet_animal")
	ui.act_open("quests", {})
	await shot("sheet_quests")
	ui.act_open("settings", {})
	await shot("sheet_settings")
	var bak: int = -1
	for o in gs.objects:
		if o.type == "bakery":
			bak = int(o.uid)
	ui.act_open("production", {"uid": bak})
	await shot("sheet_production")
	ui.close_sheet()

	# Platzieren per Vorschau
	world.start_placement("haybale")
	await frames(3)
	await shot("placing")
	world.cancel_placement()
	await frames(2)

	# Gebäude antippen -> Abholen
	for o in gs.objects:
		if o.type == "bakery":
			var ent: Node2D = world._entity_nodes[int(o.uid)]
			await tap(world_to_screen(ent.position + Vector2(0, -100)))
	log.append("bread after tap-collect: %s" % gs.item_count("bread"))

	# Tier antippen
	var an: Node2D = world._animal_nodes[int(gs.animals[0].uid)]
	await tap(world_to_screen(an.position + Vector2(0, -44)))
	log.append("sheet after animal tap: %s" % ui._sheet_name)
	ui.act_pet(int(gs.animals[0].uid))
	await frames(10)
	await shot("animal_petted")

	# Speichern/Laden
	var sv: Node = root.get_node("SaveSystem")
	log.append("save ok: %s" % sv.save_game())
	var coins_before: int = gs.coins
	gs.new_game()
	log.append("load ok: %s coins %d -> %d" % [sv.load_game(), coins_before, gs.coins])
	await frames(5)
	await shot("after_load")
	sv.delete_save()
	for l in log:
		print("LOG ", l)
	quit()
