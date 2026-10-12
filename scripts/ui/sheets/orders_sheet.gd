extends RefCounted
## Auftragsbuch: Kundenbestellungen mit Fortschritt und Belohnung.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Auftragsbuch")
	var c: VBoxContainer = ui.content
	if GameState.orders.is_empty():
		c.add_child(UiKit.wrap_label("Gerade wartet niemand. Bald kommen neue Kundinnen und Kunden vorbei!", 32))
	for o in GameState.orders:
		var ok := GameState.can_fulfill(o)
		var card := UiKit.panel(UiKit.cream(), 26, 14, UiKit.sage() if ok else UiKit.cream_dark(), 4)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UiKit.vbox(8)
		var head := UiKit.hbox(10)
		head.add_child(UiKit.icon("heart", 40))
		var nm := UiKit.label("%s wünscht sich:" % String(o["customer"]), 32)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		var skip := UiKit.button("✕", "ghost", 30)
		skip.custom_minimum_size = Vector2(80, 80)
		skip.pressed.connect(ui.act_skip_order.bind(int(o["id"])))
		head.add_child(skip)
		v.add_child(head)
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 22)
		chips.add_theme_constant_override("v_separation", 6)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in o["items"]:
			var chip := UiKit.hbox(6)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
