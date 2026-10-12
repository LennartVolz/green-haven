extends SceneTree
## Spielt eine Szenenfolge durch und speichert Screenshots (zur visuellen Prüfung).
## Start (mit Display, z. B. xvfb):
##   godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tests/screenshots.gd -- /pfad/zum/ordner

var out_dir := "/tmp"
var gs: Node
var main: Node
var world: Node2D
var ui: Node
var shots := 0
var log: Array = []


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


func shot(name: String) -> void:
	await frames(4)
	var img := root.get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, shots, name]
	img.save_png(path)
	shots += 1
	print("shot ", path, " ", img.get_size())


func win(p: Vector2) -> Vector2:
	## Viewport-Koordinaten (1080x1920) -> Fensterkoordinaten
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

	# Feld antippen -> Saatauswahl
	var cell: Vector2i = gs.fields.keys()[0]
	await tap(world_to_screen(gs.cell_center(cell)))
	log.append("sheet after field tap: %s" % ui._sheet_name)
	await shot("crops_sheet")
	# Weizen wählen -> Werkzeug
	ui.act_plant_pick("wheat", cell)
	await frames(3)
	log.append("tool after pick: %s, planted=%s" % [world.tool_mode, gs.stats.get("planted", 0)])
	# Über die anderen Felder wischen
	var cells: Array = gs.fields.keys()
	await drag(world_to_screen(gs.cell_center(cells[0]) + Vector2(-60, 0)), world_to_screen(gs.cell_center(cells[3]) + Vector2(60, 0)), 14)
	log.append("planted after swipe: %s" % gs.stats.get("planted", 0))
	await shot("planted_swipe")
	world.clear_tool()
	gs.time_offset += 16.0
	await frames(3)
	await shot("growing")
	gs.time_offset += 20.0
	await frames(3)
	await shot("ripe")
	# Ernte per Wischen
	await drag(world_to_screen(gs.cell_center(cells[0]) + Vector2(-60, 0)), world_to_screen(gs.cell_center(cells[3]) + Vector2(60, 0)), 14)
	log.append("harvested after swipe: %s wheat=%s" % [gs.stats.get("harvested", 0), gs.item_count("wheat")])
	await shot("harvested")

	# Kamera: verschieben und zoomen
	var cp0: Vector2 = world.cam.position
	await drag(Vector2(300, 1000), Vector2(200, 800), 8)
	log.append("camera moved: %s" % (world.cam.position - cp0))
	world.zoom_at(Vector2(540, 900), 0.8)
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
	ui.act_open("orders", {})
	await shot("sheet_orders")
	ui.act_open("inventory", {})
	await shot("sheet_inventory")
	ui.act_open("refuge", {})
	await shot("sheet_refuge")
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
