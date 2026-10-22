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
	var shelter_summary := UiKit.card(12)
	var summary := UiKit.vbox(6)
	summary.add_child(UiKit.label(I18n.t("Gehegeübersicht · %d Tiere von %d Plätzen") % [GameState.animals.size(), capacity], 28))
	if paddocks == 0:
		summary.add_child(UiKit.wrap_label("Noch kein Gehege gebaut.", 24, UiKit.earth_dark()))
	else:
		for o in GameState.objects:
			if o.kind != "paddock":
				continue
			var occupants: Array = GameState.animals_in_paddock(int(o.uid))
			var cap: int = int(GameData.BUILDINGS[o.type]["capacity"])
			var min_mood := 100.0
			for animal in occupants:
				min_mood = minf(min_mood, GameState.wellbeing(animal))
			var row := UiKit.hbox(8)
			row.add_child(UiKit.icon("paw", 36))
			var mood_text := I18n.t(" · niedrigstes Wohlbefinden %d%%") % int(round(min_mood)) if not occupants.is_empty() else I18n.t(" · bereit für eine Rettung")
			row.add_child(UiKit.label(I18n.t("Gehege %d: %d/%d Tiere%s") % [int(o.uid), occupants.size(), cap, mood_text], 23, UiKit.earth_dark()))
			summary.add_child(row)
	c.add_child(shelter_summary)
	var diary_button := UiKit.button(I18n.t("Refugiums-Tagebuch · %d Erinnerungen") % GameState.diary.size(), "warm", 27)
	diary_button.pressed.connect(ui.act_open_diary)
	c.add_child(diary_button)
	if not GameState.rescue_case.is_empty():
		var rescue: Dictionary = GameState.rescue_case
		var species: String = rescue["species"]
		var rescue_def: Dictionary = GameData.ANIMALS[species]
		var rescue_card := UiKit.card(14)
		var rescue_v := UiKit.vbox(8)
		rescue_v.add_child(UiKit.label("Ein Tier braucht ein Zuhause", 30))
		var rescue_story: String = rescue_def["stories"][clampi(int(rescue.get("story", 0)), 0, rescue_def["stories"].size() - 1)]
		rescue_v.add_child(UiKit.wrap_label("%s · %s" % [rescue_def["name"], rescue_story], 24, UiKit.earth_dark()))
		var rescue_button := UiKit.button(I18n.t("%s aufnehmen") % rescue_def["name"], "warm", 28)
		rescue_button.disabled = GameState.free_paddock().is_empty()
		rescue_button.pressed.connect(ui.act_adopt.bind(species, true))
		rescue_v.add_child(rescue_button)
		rescue_card.add_child(rescue_v)
		c.add_child(rescue_card)
	else:
		c.add_child(UiKit.wrap_label("Gelegentlich wird ein passender Rettungsfall angeboten, wenn ein Gehege Platz hat. Das Warten hat keine Nachteile.", 22, UiKit.earth_dark()))
	if paddocks == 0:
		var b := UiKit.button("Gehege ansehen", "primary", 32)
		b.pressed.connect(ui.act_open_shop_tab.bind("buildings"))
		c.add_child(b)
		return
	c.add_child(UiKit.wrap_label(I18n.t("Plätze: %d von %d belegt. Die Tiere geben nichts her – sie dürfen einfach leben.") % [GameState.animals.size(), capacity], 26, UiKit.earth_dark()))
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
		pv.setup("animal", a.species, GameState.equipped_cosmetics_of(a))
		pv.custom_minimum_size = Vector2(150, 150)
		h.add_child(pv)
		var v := UiKit.vbox(4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(UiKit.label("%s  (%s)" % [a.name, String(d["name"])], 32))
		v.add_child(UiKit.progress(GameState.wellbeing(a) / 100.0, _mood_color(GameState.wellbeing(a)), 20))
		v.add_child(UiKit.icon_text("heart", str(int(a.hearts)), 26))
		var trait_ids: Array = a.get("traits", [])
		var trait_names: Array = []
		for trait_id in trait_ids:
			trait_names.append(str(GameData.ANIMAL_TRAITS[trait_id]["name"]))
		if not trait_names.is_empty():
			v.add_child(UiKit.label(", ".join(PackedStringArray(trait_names)), 21, UiKit.earth_dark()))
		h.add_child(v)
		btn.add_child(h)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		btn.pressed.connect(ui.act_open.bind("animal", {"uid": int(a.uid)}))
		c.add_child(btn)
	c.add_child(UiKit.label("Tier aufnehmen", 30, UiKit.earth_dark()))
	var free: Dictionary = GameState.free_paddock()
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
		v.add_child(UiKit.label(I18n.t("Mag: %s") % GameData.item_name(String(d["food"])), 24, UiKit.earth_dark()))
		h.add_child(v)
		var b := UiKit.button("Retten", "primary", 28)
		b.custom_minimum_size = Vector2(190, 96)
		if locked:
			b.text = I18n.t("Stufe %d") % int(d["level"])
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
