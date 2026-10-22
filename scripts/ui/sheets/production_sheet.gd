extends RefCounted
## Produktionsgebäude: Warteschlange, Rezepte, Abholen und Ausbau.


## Gartencafé als Ort: Tische, wartende Gäste, Tagesumsatz. Die Gäste leben nur
## im laufenden Spiel; nach einer Pause steht hier wieder der leere Morgen.
static func _build_cafe(ui, c: VBoxContainer) -> void:
	var tables := GameState.cafe_tables()
	var head := UiKit.card(14)
	var v := UiKit.vbox(6)
	var row := UiKit.hbox(10)
	row.add_child(UiKit.icon("clock", 42))
	var title := UiKit.label("Gäste", 30, UiKit.sage_dark())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	v.add_child(row)
	var status := UiKit.label("", 24, UiKit.earth_dark())
	v.add_child(status)
	ui.ticker.append(func() -> void:
		if GameState.cafe_is_open():
			status.text = I18n.t("Geöffnet · %s") % GameState.clock_text()
		else:
			status.text = I18n.t("Gerade geschlossen · %s") % GameState.clock_text())
	v.add_child(UiKit.wrap_label(I18n.t("Gäste kommen zwischen %d und %d Uhr") % [int(GameState.CAFE_OPEN_HOUR), int(GameState.CAFE_CLOSE_HOUR)], 22, UiKit.earth_dark()))
	var served := GameState.cafe_day_served
	var summary := "Heute noch niemand bedient." if served == 0 else "Heute bedient: %d · Umsatz: %d Münzen" % [served, GameState.cafe_day_coins]
	v.add_child(UiKit.wrap_label(summary, 24, UiKit.sage_dark()))
	if not GameState.cafe_menu_ready():
		v.add_child(UiKit.wrap_label("Sobald ein Gericht auf der Karte steht, kommen auch Gäste.", 22, UiKit.earth_dark()))
	head.add_child(v)
	c.add_child(head)
	for table in range(1, tables + 1):
		var guest := GameState.cafe_guest_at(table)
		var card := UiKit.card(12)
		var h := UiKit.hbox(12)
		if guest.is_empty():
			var free_label := UiKit.label(I18n.t("Tisch %d ist frei") % table, 28, UiKit.earth_dark())
			free_label.custom_minimum_size = Vector2(0, 72)
			free_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(free_label)
			card.add_child(h)
			c.add_child(card)
			continue
		var dish := str(guest.get("dish", ""))
		var eating := float(guest.get("ate_at", 0.0)) > 0.0
		var stock := GameState.item_count(dish)
		h.add_child(UiKit.item_icon(dish, 76))
		var tv := UiKit.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UiKit.label(I18n.t("Tisch %d · %s") % [table, str(guest.get("name", ""))], 24, UiKit.earth_dark()))
		tv.add_child(UiKit.label(GameData.item_name(dish), 30))
		if eating:
			var eta := UiKit.label("", 24, UiKit.sage_dark())
			tv.add_child(eta)
			ui.ticker.append(func() -> void:
				eta.text = I18n.t("zahlt in %s") % GameData.format_time(maxf(0.0, float(guest["ate_at"]) - GameState.now())))
		else:
			var stock_text := I18n.t("%d im Vorrat") % stock if stock > 0 else I18n.t("nicht vorrätig")
			tv.add_child(UiKit.label(stock_text, 24, UiKit.sage_dark() if stock > 0 else UiKit.red()))
		h.add_child(tv)
		if eating:
			var paid := UiKit.label(I18n.t("zahlt %d") % int(guest.get("pay", 0)), 26, UiKit.sage_dark())
			paid.custom_minimum_size = Vector2(0, 80)
			paid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(paid)
		else:
			var serve := UiKit.button(I18n.t("Servieren  +%d") % int(guest.get("pay", 0)), "primary", 28)
			serve.custom_minimum_size = Vector2(230, 90)
			serve.disabled = stock <= 0
			if stock > 0:
				serve.pressed.connect(ui.act_serve_cafe.bind(table))
			h.add_child(serve)
			var send_home := UiKit.button("Gehen lassen", "light", 26)
			send_home.custom_minimum_size = Vector2(210, 90)
			send_home.pressed.connect(ui.act_send_cafe_home.bind(table))
			h.add_child(send_home)
		card.add_child(h)
		c.add_child(card)
	if tables < 1 + GameState.MAX_UPGRADES:
		c.add_child(UiKit.wrap_label("Ein Ausbau stellt einen weiteren Tisch auf.", 22, UiKit.earth_dark()))


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
	if o.type == "cafe":
		_build_cafe(ui, c)
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
