extends RefCounted
## Ein Besuch auf dem Nachbarhof: gemalte Szene, zwei antippbare Stellen und die
## gefundenen Sätze. Der Besuch ist freiwillig; jede Stelle zählt einmal.


static func build(ui, args: Dictionary) -> void:
	var neighbor_id := str(args.get("neighbor", ""))
	if not GameData.NEIGHBORS.has(neighbor_id):
		ui.close_sheet()
		return
	var neighbor: Dictionary = GameData.NEIGHBORS[neighbor_id]
	var spots: Array = GameState.neighbor_spot_texts(neighbor_id)
	var found: Array = GameState.neighbor_spots(neighbor_id)
	ui.set_title(I18n.t("Zu Besuch bei %s") % String(neighbor["name"]))
	var c: VBoxContainer = ui.content
	c.add_child(UiKit.wrap_label(String(neighbor.get("visit", {}).get("intro", "")), 26))
	c.add_child(UiKit.wrap_label("Ein ruhiger Nachmittag auf dem Nachbarhof. Tippe auf die Stellen im Bild – es eilt nicht.", 22, UiKit.earth_dark()))
	var scene := NeighborScene.new()
	scene.setup(GameData.NEIGHBORS.keys().find(neighbor_id), spots.size(), found)
	scene.spot_pressed.connect(func(index: int) -> void: ui.act_visit_spot(neighbor_id, index))
	c.add_child(scene)
	if found.is_empty():
		c.add_child(UiKit.wrap_label("Noch ist nichts entdeckt. Zwei Stellen warten auf einen Blick.", 24, UiKit.earth_dark()))
	else:
		for index in found:
			var card := UiKit.card(10)
			card.add_child(UiKit.wrap_label(String(spots[int(index)]), 24, UiKit.earth_dark()))
			c.add_child(card)
	if found.size() >= spots.size():
		c.add_child(UiKit.wrap_label(I18n.t("Du kennst jetzt jede Ecke dieses Hofes. %s freut sich über den Besuch.") % String(neighbor["name"]), 24, UiKit.sage_dark()))
	else:
		c.add_child(UiKit.wrap_label(I18n.t("Noch %d Stellen warten.") % (spots.size() - found.size()), 22, UiKit.earth_dark()))
	var back := UiKit.button("Zurück zum Briefkasten", "warm", 28)
	back.pressed.connect(ui.act_open_letters)
	c.add_child(back)
