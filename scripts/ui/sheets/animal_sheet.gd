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
	pv.setup("animal", a.species, GameState.equipped_cosmetics_of(a))
	pv.custom_minimum_size = Vector2(260, 220)
	top.add_child(pv)
	var v := UiKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(String(d["name"]), 30, UiKit.earth_dark()))
	v.add_child(UiKit.icon_text("heart", I18n.t("%d Herzen · Freundschaft %d/4") % [int(a.hearts), GameState.friendship_level(a)], 32))
	var stories: Array = d["stories"]
	var story: String = stories[clampi(int(a.story), 0, stories.size() - 1)]
	v.add_child(UiKit.label("Seine Geschichte", 24, UiKit.earth_dark()))
	v.add_child(UiKit.wrap_label("%s %s" % [a.name, story], 26))
	var friendship_level := GameState.friendship_level(a)
	if friendship_level > 0:
		var friendship_story: String = GameData.FRIENDSHIP_STORIES[a.species][friendship_level - 1]
		v.add_child(UiKit.wrap_label(I18n.t("Euer Moment: %s %s") % [a.name, friendship_story], 23, UiKit.sage_dark()))
	var traits: Array = a.get("traits", [])
	var trait_names: Array = []
	for trait_id in traits:
		var trait_info: Dictionary = GameData.ANIMAL_TRAITS[trait_id]
		trait_names.append(String(trait_info["name"]))
	v.add_child(UiKit.wrap_label(I18n.t("Charakter: %s") % ", ".join(PackedStringArray(trait_names)), 22, UiKit.earth_dark()))
	for trait_id in traits:
		var trait_info: Dictionary = GameData.ANIMAL_TRAITS[trait_id]
		v.add_child(UiKit.wrap_label(String(trait_info["description"]), 20, UiKit.earth_dark()))
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
	var feed := UiKit.button(I18n.t("Füttern  (%s ×%d)") % [GameData.item_name(food), GameState.item_count(food)], "warm", 28)
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed.pressed.connect(ui.act_feed.bind(uid))
	actions.add_child(feed)
	var pet := UiKit.button("Streicheln", "primary", 30)
	pet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet.pressed.connect(ui.act_pet.bind(uid))
	actions.add_child(pet)
	c.add_child(actions)

	var activity: Dictionary = GameData.ANIMAL_ACTIVITIES[a.species]
	var play := UiKit.button("%s" % activity["name"], "warm", 28)
	play.pressed.connect(ui.act_play_animal.bind(uid))
	c.add_child(play)
	c.add_child(UiKit.wrap_label(String(activity["description"]), 22, UiKit.earth_dark()))
	ui.ticker.append(func() -> void:
		var cur := GameState.get_animal(uid)
		if cur.is_empty():
			return
		var left := GameState.activity_cooldown_left(cur)
		play.disabled = left > 0.0
		play.text = String(activity["name"]) if left <= 0.0 else I18n.t("%s · in %s") % [activity["name"], GameData.format_time(left)])

	c.add_child(UiKit.label("Accessoires", 28, UiKit.earth_dark()))
	for cos in GameData.COSMETICS:
		var unlocked: bool = GameState.cosmetics_of(a).has(cos["id"])
		var equipped: bool = GameState.equipped_cosmetics_of(a).has(cos["id"])
		var cosmetic_button := UiKit.button(I18n.t("%s · %s") % [cos["name"], I18n.t("Angelegt") if equipped else (I18n.t("Anlegen") if unlocked else I18n.t("ab %d Herzen") % int(cos["hearts"]))], "primary" if equipped else "light", 24)
		cosmetic_button.name = "Cosmetic_%d" % GameData.COSMETICS.find(cos)
		cosmetic_button.disabled = not unlocked
		cosmetic_button.set_meta("cosmetic_id", String(cos["id"]))
		cosmetic_button.pressed.connect(ui.act_toggle_cosmetic.bind(uid, String(cos["id"]), not equipped))
		c.add_child(cosmetic_button)
	ui.ticker.append(func() -> void:
		var cur := GameState.get_animal(uid)
		if cur.is_empty():
			return
		var left := GameState.pet_cooldown_left(cur)
		pet.disabled = left > 0.0
		pet.text = I18n.t("Streicheln") if left <= 0.0 else I18n.t("Gleich wieder (%ds)") % int(ceil(left))
		for cosmetic_control in c.get_children():
			if not cosmetic_control is Button or not cosmetic_control.has_meta("cosmetic_id"):
				continue
			var cosmetic_id: String = str(cosmetic_control.get_meta("cosmetic_id"))
			for cosmetic in GameData.COSMETICS:
				if str(cosmetic["id"]) != cosmetic_id:
					continue
				var unlocked_now: bool = GameState.cosmetics_of(cur).has(cosmetic_id)
				var equipped_now: bool = GameState.equipped_cosmetics_of(cur).has(cosmetic_id)
				cosmetic_control.disabled = not unlocked_now
				cosmetic_control.text = I18n.t("%s · %s") % [cosmetic["name"], I18n.t("Angelegt") if equipped_now else (I18n.t("Anlegen") if unlocked_now else I18n.t("ab %d Herzen") % int(cosmetic["hearts"]))]
				break
		feed.disabled = GameState.animal_stat(cur, "hunger") >= 95.0 or GameState.item_count(food) < 1
		feed.text = I18n.t("Füttern  (%s ×%d)") % [GameData.item_name(food), GameState.item_count(food)])
	c.add_child(UiKit.wrap_label("Kein Zeitdruck: Tiere werden langsam hungrig und freuen sich über Besuch. Nichts geht verloren, wenn du länger fort bist.", 24, UiKit.earth_dark()))

	c.add_child(UiKit.label("Belohnungen für Zuneigung", 28, UiKit.earth_dark()))
	for cos in GameData.COSMETICS:
		var got: bool = int(a.hearts) >= int(cos["hearts"])
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon("heart" if got else "lock", 40))
		var txt := I18n.t("%s – %s") % [String(cos["name"]), I18n.t("freigeschaltet") if got else I18n.t("ab %d Herzen") % int(cos["hearts"])]
		row.add_child(UiKit.label(txt, 28, UiKit.sage_dark() if got else UiKit.earth_dark()))
		c.add_child(row)
