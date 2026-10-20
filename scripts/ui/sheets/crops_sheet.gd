extends RefCounted
## Saatgut-Auswahl. args.cell = Zielfeld (oder Vector2i(-1,-1), wenn nur die
## Sorte gewechselt wird).


static func _weather_text() -> String:
	return GameData.weather_effect_text(GameData.weather_at(GameState.now()))


static func _growth_text(id: String) -> String:
	var crop: Dictionary = GameData.CROPS[id]
	var seconds := GameData.real_seconds_for_crop_growth(GameState.now(), float(crop["grow"]))
	return "Reif in ca. %s · Ertrag %d" % [GameData.format_time(seconds), int(crop["yield"])]


static func build(ui, args: Dictionary) -> void:
	ui.set_title("Was soll wachsen?")
	var c: VBoxContainer = ui.content
	var cell: Vector2i = args.get("cell", Vector2i(-1, -1))
	c.add_child(UiKit.wrap_label("Tippe auf eine Sorte. Danach kannst du mit dem Finger über viele Felder wischen.", 26, UiKit.earth_dark()))
	var weather_card := UiKit.card(12)
	var weather_content := UiKit.vbox(4)
	var weather_label := UiKit.label(_weather_text(), 28, UiKit.sage_dark())
	weather_content.add_child(weather_label)
	weather_content.add_child(UiKit.wrap_label("Wachstumszeiten berücksichtigen den Wetterverlauf ab jetzt.", 20, UiKit.earth_dark()))
	weather_card.add_child(weather_content)
	c.add_child(weather_card)
	var ids: Array = GameData.CROPS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(GameData.CROPS[a]["level"]) < int(GameData.CROPS[b]["level"]))
	var growth_labels: Dictionary = {}
	for id in ids:
		var d: Dictionary = GameData.CROPS[id]
		var locked: bool = GameState.level < int(d["level"])
		var afford: bool = GameState.coins >= int(d["seed"])
		var b := UiKit.button("", "light", 30)
		b.custom_minimum_size = Vector2(0, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := UiKit.hbox(14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UiKit.item_icon(id, 84)
		ic.dim = locked
		h.add_child(ic)
		var v := UiKit.vbox(0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(UiKit.label(String(d["name"]), 32))
		var growth_label := UiKit.label(_growth_text(id), 24, UiKit.earth_dark())
		if locked:
			growth_label.text = "Ab Stufe %d" % int(d["level"])
		growth_labels[id] = growth_label
		v.add_child(growth_label)
		h.add_child(v)
		var cost := UiKit.icon_text("coin", str(int(d["seed"])), 30, UiKit.ink() if afford else UiKit.red())
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(cost)
		b.add_child(h)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
		if locked:
			b.disabled = true
		else:
			b.pressed.connect(ui.act_plant_pick.bind(id, cell))
		c.add_child(b)
	var last_weather := [GameData.weather_at(GameState.now())]
	ui.ticker.append(func() -> void:
		var weather := GameData.weather_at(GameState.now())
		if weather == last_weather[0]:
			return
		last_weather[0] = weather
		weather_label.text = _weather_text()
		for id in growth_labels:
			if GameState.level >= int(GameData.CROPS[id]["level"]):
				(growth_labels[id] as Label).text = _growth_text(str(id))
	)
