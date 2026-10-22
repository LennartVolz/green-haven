extends RefCounted
## Produktionsgebäude: Warteschlange, Rezepte, Abholen und Ausbau.


static func build(ui, args: Dictionary) -> void:
	var uid := int(args.get("uid", -1))
	var o := GameState.get_object(uid)
	if o.is_empty() or o.kind != "production":
		ui.close_sheet()
		return
	var d: Dictionary = GameData.BUILDINGS[o.type]
	ui.set_title(String(d["name"]))
	var c: VBoxContainer = ui.content
	if bool(args.get("from_overview", false)):
		var back := UiKit.button("Zur Produktionsübersicht", "light", 26)
		back.pressed.connect(ui.act_open.bind("production_overview", {}))
		c.add_child(back)
	var ready := GameState.ready_count(o)
	if ready > 0:
		var cb := UiKit.button(I18n.t("Abholen (%d)") % ready, "warm", 36)
		cb.pressed.connect(ui.act_collect.bind(uid))
		c.add_child(cb)
	c.add_child(UiKit.label("Produktion", 30, UiKit.earth_dark()))
	var cap := GameState.queue_capacity(o)
	for i in range(cap):
		var card := UiKit.card(12)
		var h := UiKit.hbox(14)
		if i < (o.queue as Array).size():
			var e: Dictionary = o.queue[i]
			var rid: String = e["recipe"]
			h.add_child(UiKit.item_icon(rid, 80))
			var v := UiKit.vbox(4)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(UiKit.label(GameData.item_name(rid), 32))
			var bar := UiKit.progress(GameState.entry_progress(e), UiKit.sage(), 22)
			v.add_child(bar)
			var tl := UiKit.label("", 26, UiKit.earth_dark())
			v.add_child(tl)
			h.add_child(v)
			ui.ticker.append(func() -> void:
				bar.value = GameState.entry_progress(e)
				var rem: float = float(e["end"]) - GameState.now()
				if rem <= 0.0:
					tl.text = I18n.t("Fertig!")
				elif float(e["start"]) > GameState.now():
					tl.text = I18n.t("wartet · dann %s") % GameData.format_time(float(e["end"]) - float(e["start"]))
				else:
					tl.text = I18n.t("noch %s") % GameData.format_time(rem))
		else:
			var lbl := UiKit.label("Freier Platz", 30, UiKit.earth_dark())
			lbl.custom_minimum_size = Vector2(0, 80)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(lbl)
		card.add_child(h)
		c.add_child(card)
	if int(o.upgrades) < GameState.MAX_UPGRADES:
		var cost := GameState.upgrade_cost(o)
		var ub := UiKit.button(I18n.t("Platz ausbauen  ·  %d Münzen") % cost, "light", 28)
		ub.disabled = GameState.coins < cost
		ub.pressed.connect(ui.act_upgrade.bind(uid))
		c.add_child(ub)
	c.add_child(UiKit.label("Rezepte", 30, UiKit.earth_dark()))
	var rids: Array = GameData.recipes_for(o.type)
	rids.sort_custom(func(a: String, b: String) -> bool: return int(GameData.RECIPES[a]["level"]) < int(GameData.RECIPES[b]["level"]))
	var full: bool = (o.queue as Array).size() >= cap
	for rid in rids:
		var r: Dictionary = GameData.RECIPES[rid]
		var locked: bool = GameState.level < int(r["level"])
		var can := GameState.has_items(r["inputs"])
		var card := UiKit.card(12)
		var v := UiKit.vbox(8)
		var top := UiKit.hbox(14)
		var ic := UiKit.item_icon(rid, 80)
		ic.dim = locked
		top.add_child(ic)
		var tv := UiKit.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UiKit.label(String(r["name"]), 32))
		var sub := I18n.t("%s · Wert %d · %d XP") % [GameData.format_time(float(r["time"])), int(r["sell"]), int(r["xp"])]
		if locked:
			sub = I18n.t("Ab Stufe %d") % int(r["level"])
		tv.add_child(UiKit.label(sub, 24, UiKit.earth_dark()))
		top.add_child(tv)
		v.add_child(top)
		var bottom := UiKit.hbox(14)
		var chips := HFlowContainer.new()
		chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chips.add_theme_constant_override("h_separation", 16)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in r["inputs"]:
			chips.add_child(UiKit.item_chip(id, GameState.item_count(id), int(r["inputs"][id])))
		bottom.add_child(chips)
		var b := UiKit.button("Start", "primary", 30)
		b.custom_minimum_size = Vector2(180, 90)
		if locked or full or not can:
			b.disabled = true
			if full and not locked:
				b.text = I18n.t("Voll")
		else:
			b.pressed.connect(ui.act_start_recipe.bind(uid, rid))
		bottom.add_child(b)
		v.add_child(bottom)
		card.add_child(v)
		c.add_child(card)
