extends RefCounted
## Tierrefugium: gerettete Tiere ansehen und neue aufnehmen.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Tierrefugium")
	var c: VBoxContainer = ui.content
	var paddocks := 0
	var capacity := 0
	for o in GameState.objects:
		if o.kind == "paddock":
			paddocks += 1
			capacity += int(GameData.BUILDINGS[o.type]["capacity"])
	if paddocks == 0:
		c.add_child(UiKit.wrap_label("Hier finden gerettete Tiere ein friedliches Zuhause – ganz ohne Gegenleistung. Baue zuerst ein Gehege.", 32))
		var b := UiKit.button("Gehege ansehen", "primary", 32)
		b.pressed.connect(ui.act_open_shop_tab.bind("buildings"))
		c.add_child(b)
		return
	c.add_child(UiKit.wrap_label("Plätze: %d von %d belegt. Die Tiere geben nichts her – sie dürfen einfach leben." % [GameState.animals.size(), capacity], 26, UiKit.earth_dark()))
	if not GameState.animals.is_empty():
		c.add_child(UiKit.label("Deine Schützlinge", 30, UiKit.earth_dark()))
	for a in GameState.animals:
		var d: Dictionary = GameData.ANIMALS[a.species]
		var btn := UiKit.button("", "light", 30)
		btn.custom_minimum_size = Vector2(0, 170)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := UiKit.hbox(14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pv := ObjPreview.new()
		pv.setup("animal", a.species, GameState.cosmetics_of(a))
		pv.custom_minimum_size = Vector2(150, 150)
		h.add_child(pv)
		var v := UiKit.vbox(4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(UiKit.label("%s  (%s)" % [a.name, String(d["name"])], 32))
		v.add_child(UiKit.progress(GameState.wellbeing(a) / 100.0, _mood_color(GameState.wellbeing(a)), 20))
		v.add_child(UiKit.icon_text("heart", str(int(a.hearts)), 26))
		h.add_child(v)
		btn.add_child(h)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		btn.pressed.connect(ui.act_open.bind("animal", {"uid": int(a.uid)}))
		c.add_child(btn)
	c.add_child(UiKit.label("Tier aufnehmen", 30, UiKit.earth_dark()))
	var free := GameState.free_paddock()
	if free.is_empty():
		c.add_child(UiKit.wrap_label("Alle Gehege sind voll. Baue ein weiteres Gehege, um mehr Tieren zu helfen.", 26, UiKit.red()))
	var ids: Array = GameData.ANIMALS.keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return int(GameData.ANIMALS[x]["level"]) < int(GameData.ANIMALS[y]["level"]))
	for id in ids:
		var d: Dictionary = GameData.ANIMALS[id]
		var locked: bool = GameState.level < int(d["level"])
		var card := UiKit.card(12)
		var h := UiKit.hbox(14)
		var pv := ObjPreview.new()
		pv.setup("animal", id)
		pv.custom_minimum_size = Vector2(140, 140)
		if locked:
			pv.modulate = Color(1, 1, 1, 0.4)
		h.add_child(pv)
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(String(d["name"]), 32))
		v.add_child(UiKit.icon_text("coin", str(int(d["cost"])), 28, UiKit.ink() if GameState.coins >= int(d["cost"]) else UiKit.red()))
		v.add_child(UiKit.label("Mag: %s" % GameData.item_name(String(d["food"])), 24, UiKit.earth_dark()))
		h.add_child(v)
		var b := UiKit.button("Retten", "primary", 28)
		b.custom_minimum_size = Vector2(190, 96)
		if locked:
			b.text = "Stufe %d" % int(d["level"])
			b.disabled = true
		elif free.is_empty() or GameState.coins < int(d["cost"]):
			b.disabled = true
		else:
			b.pressed.connect(ui.act_adopt.bind(id))
		h.add_child(b)
		card.add_child(h)
		c.add_child(card)


static func _mood_color(w: float) -> Color:
	if w >= 60.0:
		return UiKit.sage()
	if w >= 35.0:
		return UiKit.yellow()
	return UiKit.red()
