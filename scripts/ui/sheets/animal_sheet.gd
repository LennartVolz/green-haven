extends RefCounted
## Ein einzelnes gerettetes Tier: Geschichte, Bedürfnisse, Streicheln, Füttern.


static func build(ui, args: Dictionary) -> void:
	var uid := int(args.get("uid", -1))
	var a := GameState.get_animal(uid)
	if a.is_empty():
		ui.close_sheet()
		return
	var d: Dictionary = GameData.ANIMALS[a.species]
	ui.set_title(String(a.name))
	var c: VBoxContainer = ui.content
	var top := UiKit.hbox(16)
	var pv := ObjPreview.new()
	pv.setup("animal", a.species, GameState.cosmetics_of(a))
	pv.custom_minimum_size = Vector2(260, 220)
	top.add_child(pv)
	var v := UiKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(String(d["name"]), 30, UiKit.earth_dark()))
	v.add_child(UiKit.icon_text("heart", "%d Herzen" % int(a.hearts), 32))
	var stories: Array = d["stories"]
	var story: String = stories[clampi(int(a.story), 0, stories.size() - 1)]
	v.add_child(UiKit.wrap_label("%s %s" % [a.name, story], 26))
	top.add_child(v)
	c.add_child(top)

	var needs := UiKit.card(14)
	var nv := UiKit.vbox(8)
	var hunger_bar := UiKit.progress(GameState.animal_stat(a, "hunger") / 100.0, UiKit.yellow(), 24)
	var happy_bar := UiKit.progress(GameState.animal_stat(a, "happy") / 100.0, Painter.col("#E8587A"), 24)
	nv.add_child(UiKit.label("Sattheit", 26, UiKit.earth_dark()))
	nv.add_child(hunger_bar)
	nv.add_child(UiKit.label("Wohlbefinden", 26, UiKit.earth_dark()))
	nv.add_child(happy_bar)
	needs.add_child(nv)
	c.add_child(needs)
	ui.ticker.append(func() -> void:
		var cur := GameState.get_animal(uid)
		if cur.is_empty():
			return
		hunger_bar.value = GameState.animal_stat(cur, "hunger") / 100.0
		happy_bar.value = GameState.animal_stat(cur, "happy") / 100.0)

	var actions := UiKit.hbox(12)
	var food: String = d["food"]
	var feed := UiKit.button("Füttern  (%s ×%d)" % [GameData.item_name(food), GameState.item_count(food)], "warm", 28)
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed.pressed.connect(ui.act_feed.bind(uid))
	actions.add_child(feed)
	var pet := UiKit.button("Streicheln", "primary", 30)
	pet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet.pressed.connect(ui.act_pet.bind(uid))
	actions.add_child(pet)
	c.add_child(actions)
	ui.ticker.append(func() -> void:
		var cur := GameState.get_animal(uid)
		if cur.is_empty():
			return
		var left := GameState.pet_cooldown_left(cur)
		pet.disabled = left > 0.0
		pet.text = "Streicheln" if left <= 0.0 else "Gleich wieder (%ds)" % int(ceil(left)))
	c.add_child(UiKit.wrap_label("Kein Zeitdruck: Tiere werden langsam hungrig und freuen sich über Besuch. Nichts geht verloren, wenn du länger fort bist.", 24, UiKit.earth_dark()))

	c.add_child(UiKit.label("Belohnungen für Zuneigung", 28, UiKit.earth_dark()))
	for cos in GameData.COSMETICS:
		var got: bool = int(a.hearts) >= int(cos["hearts"])
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon("heart" if got else "lock", 40))
		var txt := "%s – %s" % [String(cos["name"]), "freigeschaltet" if got else "ab %d Herzen" % int(cos["hearts"])]
		row.add_child(UiKit.label(txt, 28, UiKit.sage_dark() if got else UiKit.earth_dark()))
		c.add_child(row)
