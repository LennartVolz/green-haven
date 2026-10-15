extends RefCounted
## Shop: Pflanzen, Gebäude, Dekoration sowie Land und Zutaten.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Shop")
	var c: VBoxContainer = ui.content
	var tab: String = str(_args.get("tab", ui.state.get("shop_tab", "crops")))
	if not ["crops", "buildings", "decos", "land"].has(tab):
		tab = "crops"
		ui.state["shop_tab"] = tab
	var tabs := [["crops", "Pflanzen"], ["buildings", "Gebäude"], ["decos", "Deko"], ["land", "Land"]]
	var th := UiKit.hbox(8)
	for t in tabs:
		var b := UiKit.button(t[1], "warm" if t[0] == tab else "light", 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(ui.set_state.bind("shop_tab", t[0]))
		th.add_child(b)
	c.add_child(th)
	match tab:
		"crops":
			_crops(ui, c)
		"buildings":
			_buildings(ui, c)
		"decos":
			_decos(ui, c)
		_:
			_land(ui, c)


static func _crops(ui, c: VBoxContainer) -> void:
	c.add_child(UiKit.wrap_label("Saatgut wird beim Pflanzen bezahlt. Wähle eine Sorte und tippe oder wische über leere Felder.", 26, UiKit.earth_dark()))
	var ids: Array = GameData.CROPS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(GameData.CROPS[a]["level"]) < int(GameData.CROPS[b]["level"]))
	for id in ids:
		var d: Dictionary = GameData.CROPS[id]
		var locked: bool = GameState.level < int(d["level"])
		var card := UiKit.card(12)
		var h := UiKit.hbox(14)
		var ic := UiKit.item_icon(id, 90)
		if locked:
			ic.dim = true
		h.add_child(ic)
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(String(d["name"]), 34))
		v.add_child(UiKit.label("Wächst %s · Ertrag %d" % [GameData.format_time(float(d["grow"])), int(d["yield"])], 24, UiKit.earth_dark()))
		v.add_child(UiKit.label("Saat %d · Verkauf %d · %d XP" % [int(d["seed"]), int(d["sell"]), int(d["xp"])], 24, UiKit.earth_dark()))
		h.add_child(v)
		var b := UiKit.button("Pflanzen", "primary", 28)
		b.custom_minimum_size = Vector2(210, 96)
		if locked:
			b.text = "Stufe %d" % int(d["level"])
			b.disabled = true
		else:
			b.pressed.connect(ui.act_plant_tool.bind(id))
		h.add_child(b)
		card.add_child(h)
		c.add_child(card)


static func _buildings(ui, c: VBoxContainer) -> void:
	var ids: Array = GameData.BUILDINGS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(GameData.BUILDINGS[a]["level"]) < int(GameData.BUILDINGS[b]["level"]))
	for id in ids:
		_object_card(ui, c, id)


static func _decos(ui, c: VBoxContainer) -> void:
	var ids: Array = GameData.DECOS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(GameData.DECOS[a]["level"]) < int(GameData.DECOS[b]["level"]))
	for id in ids:
		_object_card(ui, c, id)


static func _object_card(ui, c: VBoxContainer, id: String) -> void:
	var d := GameData.object_def(id)
	var cost: int = d["cost"]
	var locked: bool = GameState.level < int(d["level"])
	var maxed: bool = d.has("max") and GameState.count_type(id) >= int(d["max"])
	var card := UiKit.card(12)
	var h := UiKit.hbox(14)
	var pv := ObjPreview.new()
	pv.setup("object", id)
	pv.custom_minimum_size = Vector2(160, 160)
	h.add_child(pv)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(String(d["name"]), 32))
	var info := ""
	match String(d["kind"]):
		"production":
			info = "%d Produktionsplätze" % int(d["slots"])
			if id == "cafe":
				info = "Veganer Kaffee, Hafer-Latte und Geschichten aus der Nachbarschaft"
		"paddock":
			info = "Platz für %d gerettete Tiere" % int(d["capacity"])
		_:
			info = "Dekoration"
	v.add_child(UiKit.label(info, 24, UiKit.earth_dark()))
	var price_col := UiKit.ink() if GameState.coins >= cost else UiKit.red()
	v.add_child(UiKit.icon_text("coin", str(cost), 28, price_col))
	h.add_child(v)
	var b := UiKit.button("Bauen", "primary", 28)
	b.custom_minimum_size = Vector2(190, 96)
	if locked:
		b.text = "Stufe %d" % int(d["level"])
		b.disabled = true
	elif maxed:
		b.text = "Gebaut"
		b.disabled = true
	elif GameState.coins < cost:
		b.disabled = true
	else:
		b.pressed.connect(ui.act_place.bind(id))
	h.add_child(b)
	card.add_child(h)
	c.add_child(card)


static func _land(ui, c: VBoxContainer) -> void:
	# Neues Feld
	var card := UiKit.card(14)
	var v := UiKit.vbox(8)
	v.add_child(UiKit.label("Neue Felder anlegen", 34))
	v.add_child(UiKit.wrap_label("Tippe oder wische über freie Wiese. Jedes Feld kostet %d Münzen." % GameData.TILL_COST, 26, UiKit.earth_dark()))
	var b := UiKit.button("Felder anlegen", "primary", 30)
	b.pressed.connect(ui.act_till)
	v.add_child(b)
	card.add_child(v)
	c.add_child(card)
	# Erweiterung
	var ex := GameState.next_expansion()
	var card2 := UiKit.card(14)
	var v2 := UiKit.vbox(8)
	v2.add_child(UiKit.label("Farm erweitern", 34))
	if ex.is_empty():
		v2.add_child(UiKit.wrap_label("Deine Farm ist vollständig ausgebaut. Wunderschön!", 26, UiKit.earth_dark()))
	else:
		v2.add_child(UiKit.wrap_label("Mehr Platz für Felder, Gebäude und Gehege.", 26, UiKit.earth_dark()))
		var e := UiKit.button("Erweitern  ·  %d Münzen" % int(ex["cost"]), "warm", 30)
		if GameState.level < int(ex["level"]):
			e.text = "Ab Stufe %d" % int(ex["level"])
			e.disabled = true
		elif GameState.coins < int(ex["cost"]):
			e.disabled = true
		else:
			e.pressed.connect(ui.act_expand)
		v2.add_child(e)
	card2.add_child(v2)
	c.add_child(card2)
	# Zutaten
	for id in GameData.EXTRA_ITEMS:
		var d: Dictionary = GameData.EXTRA_ITEMS[id]
		var card3 := UiKit.card(12)
		var h := UiKit.hbox(14)
		var ic := UiKit.item_icon(id, 84)
		var locked: bool = GameState.level < int(d["level"])
		ic.dim = locked
		h.add_child(ic)
		var vv := UiKit.vbox(2)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv.add_child(UiKit.label(String(d["name"]), 32))
		vv.add_child(UiKit.icon_text("coin", "%d pro Stück · im Vorrat: %d" % [int(d["shop"]), GameState.item_count(id)], 24))
		h.add_child(vv)
		var b1 := UiKit.button("Kaufen", "primary", 28)
		b1.custom_minimum_size = Vector2(190, 96)
		if locked:
			b1.text = "Stufe %d" % int(d["level"])
			b1.disabled = true
		elif GameState.coins < int(d["shop"]):
			b1.disabled = true
		else:
			b1.pressed.connect(ui.act_buy_item.bind(id, 1))
		h.add_child(b1)
		card3.add_child(h)
		c.add_child(card3)
