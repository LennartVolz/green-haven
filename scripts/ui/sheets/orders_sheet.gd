extends RefCounted
## Auftragsbuch: Kundenbestellungen mit Fortschritt und Belohnung.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Auftragsbuch")
	var c: VBoxContainer = ui.content
	var daily_special := GameState.daily_cafe_special()
	if not daily_special.is_empty():
		var special_card := UiKit.card(14)
		var special_v := UiKit.vbox(6)
		special_v.add_child(UiKit.label("Heutiges Café-Gericht", 30, UiKit.earth_dark()))
		var special_row := UiKit.hbox(12)
		special_row.add_child(UiKit.item_icon(daily_special, 72))
		var special_text := UiKit.wrap_label("%s · Gäste bestellen es heute besonders gern!\n+50%% Münzen und +5 XP pro Lieferung" % GameData.item_name(daily_special), 24, UiKit.sage_dark())
		special_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		special_row.add_child(special_text)
		special_v.add_child(special_row)
		var special_timer := UiKit.label("", 22, UiKit.earth_dark())
		special_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		special_v.add_child(special_timer)
		special_card.add_child(special_v)
		c.add_child(special_card)
		ui.ticker.append(func() -> void:
			var remaining := GameState.daily_cafe_special_seconds_left()
			special_timer.text = "Wechselt in %s" % GameData.format_time(remaining))
	if not GameState.active_delivery_story.is_empty():
		var campaign: Dictionary = GameData.DELIVERY_STORIES[GameState.active_delivery_story]
		var stages: Array = campaign["stages"]
		var story_card := UiKit.card(16)
		var story_v := UiKit.vbox(8)
		story_v.add_child(UiKit.label("Geschichtenreihe · %s" % campaign["title"], 30, UiKit.earth_dark()))
		if GameState.delivery_story_stage < stages.size():
			story_v.add_child(UiKit.wrap_label("Abschnitt %d von %d · %s" % [GameState.delivery_story_stage + 1, stages.size(), str(stages[GameState.delivery_story_stage]["text"])], 24, UiKit.earth_dark()))
		story_v.add_child(UiKit.label("Fortschritt: %d/%d" % [GameState.delivery_story_stage, stages.size()], 22, UiKit.sage_dark()))
		if str(campaign.get("feature", "")) == "cafe":
			story_v.add_child(UiKit.wrap_label("Café-Geschichten abgeschlossen: %d · Gäste bedient: %d" % [int(GameState.stats.get("cafe_stories_completed", 0)), int(GameState.stats.get("cafe_orders", 0))], 22, UiKit.sage_dark()))
		story_card.add_child(story_v)
		c.add_child(story_card)
	else:
		c.add_child(UiKit.label("Kleine Geschichten aus der Nachbarschaft", 28, UiKit.earth_dark()))
		for story_id in GameState.available_delivery_stories():
			var campaign: Dictionary = GameData.DELIVERY_STORIES[story_id]
			var story_card := UiKit.card(14)
			var story_v := UiKit.vbox(8)
			story_v.add_child(UiKit.label(String(campaign["title"]), 30))
			story_v.add_child(UiKit.wrap_label(String(campaign["intro"]), 23, UiKit.earth_dark()))
			var start := UiKit.button("Geschichte beginnen · %d Abschnitte" % campaign["stages"].size(), "warm", 26)
			start.pressed.connect(ui.act_start_delivery_story.bind(story_id))
			story_v.add_child(start)
			story_card.add_child(story_v)
			c.add_child(story_card)
	if GameState.orders.is_empty():
		c.add_child(UiKit.wrap_label("Gerade wartet niemand. Bald kommen neue Kundinnen und Kunden vorbei!", 32))
	for o in GameState.orders:
		var ok := GameState.can_fulfill(o)
		var card := UiKit.panel(UiKit.cream(), 26, 14, UiKit.sage() if ok else UiKit.cream_dark(), 4)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UiKit.vbox(8)
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		var head := UiKit.hbox(10)
		head.add_child(UiKit.icon("heart", 40))
		var nm := UiKit.label("%s wünscht sich:" % String(o["customer"]), 32)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		var skip := UiKit.button("✕", "ghost", 30)
		skip.custom_minimum_size = Vector2(80, 80)
		if o.has("story_id") or o.has("visitor_story"):
			skip.disabled = true
			skip.tooltip_text = "Geschichtengäste bleiben, bis du ihre Bestellung annimmst."
		else:
			skip.pressed.connect(ui.act_skip_order.bind(int(o["id"])))
		head.add_child(skip)
		v.add_child(head)
		if o.has("story_text"):
			v.add_child(UiKit.wrap_label("Geschichte · %s" % String(o["story_text"]), 23, UiKit.earth_dark()))
		if o.has("visitor_story"):
			v.add_child(UiKit.wrap_label("Zu Besuch im Café · %s" % String(o["visitor_story"]), 23, UiKit.earth_dark()))
		if bool(o.get("cafe_daily_special", false)):
			v.add_child(UiKit.wrap_label("Tagesgericht · +50%% Münzen · +5 XP", 22, UiKit.sage_dark()))
		var chips := HFlowContainer.new()
		chips.mouse_filter = Control.MOUSE_FILTER_PASS
		chips.add_theme_constant_override("h_separation", 22)
		chips.add_theme_constant_override("v_separation", 6)
		for id in o["items"]:
			var chip := UiKit.hbox(6)
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			chip.add_child(UiKit.item_icon(id, 64))
			var have: int = GameState.item_count(id)
			var need: int = int(o["items"][id])
			var l := UiKit.label("%d/%d  %s" % [mini(have, need), need, GameData.item_name(id)], 26, UiKit.sage_dark() if have >= need else UiKit.red())
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.add_child(l)
			chips.add_child(chip)
		v.add_child(chips)
		var foot := UiKit.hbox(14)
		foot.add_child(UiKit.icon_text("coin", "+%d" % int(o["coins"]), 32))
		foot.add_child(UiKit.icon_text("star", "+%d XP" % int(o["xp"]), 32))
		foot.add_child(UiKit.spacer())
		var b := UiKit.button("Liefern", "primary" if ok else "light", 30)
		b.custom_minimum_size = Vector2(220, 96)
		b.disabled = not ok
		b.pressed.connect(ui.act_fulfill.bind(int(o["id"])))
		foot.add_child(b)
		v.add_child(foot)
		card.add_child(v)
		c.add_child(card)
	if GameState.orders.size() < GameState.MAX_ORDERS:
		var wait := UiKit.label("", 26, UiKit.earth_dark())
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(wait)
		ui.ticker.append(func() -> void:
			var rem := GameState.next_order_at - GameState.now()
			wait.text = "Nächster Kunde in %s" % GameData.format_time(rem) if rem > 0.0 else "Ein neuer Kunde kommt gleich …")
