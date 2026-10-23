extends RefCounted
## Auftragsbuch: Kundenbestellungen mit Fortschritt und Belohnung.
## Die Aufträge stehen bewusst oben – sie sind der Grund, das Buch zu öffnen.
## Ereignisse, Tagesgericht und Geschichten folgen darunter.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Auftragsbuch")
	ui.set_subtitle("Kleine Geschichten aus der Nachbarschaft")
	_build_mailbox(ui)
	var c: VBoxContainer = ui.content
	_build_orders(ui, c)
	_build_extras(ui, c)


## Der Briefkasten sitzt als kleiner Knopf in der Kopfzeile: dort ist Platz, und
## die vier Aufträge darunter bleiben ohne Scrollen sichtbar. Die Zahl nennt nur
## ungelesene Briefe, damit nichts doppelt gelesen werden muss.
static func _build_mailbox(ui) -> void:
	var unread := GameState.unread_letters()
	var label := I18n.t("Briefe") if unread == 0 else I18n.t("Briefe · %d") % unread
	ui.set_header_action(label, ui.act_open_letters)


## Eine kompakte Karte je Auftrag: Name und Belohnung in der Kopfzeile, die Ware
## darunter, „Liefern" rechts über beide Zeilen. Vorher wuchs jede Karte auf ein
## Drittel des Bildschirms, weil die Belohnungstexte senkrecht umbrachen und der
## Knopf auf die Höhe der kaputten Zeile mitwuchs.
static func _build_orders(ui, c: VBoxContainer) -> void:
	if GameState.orders.is_empty():
		c.add_child(UiKit.wrap_label("Gerade wartet niemand. Bald kommen neue Kundinnen und Kunden vorbei!", 28))
	for o in GameState.orders:
		c.add_child(_order_card(ui, o))
	if GameState.orders.size() < GameState.MAX_ORDERS:
		var wait := UiKit.label("", 24, UiKit.earth_dark())
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(wait)
		ui.ticker.append(func() -> void:
			var rem := GameState.next_order_at - GameState.now()
			wait.text = I18n.t("Nächster Kunde in %s") % GameData.format_time(rem) if rem > 0.0 else I18n.t("Ein neuer Kunde kommt gleich …"))


static func _order_card(ui, o: Dictionary) -> PanelContainer:
	var ok := GameState.can_fulfill(o)
	var card := UiKit.panel(UiKit.cream(), 22, 12, UiKit.sage() if ok else UiKit.cream_dark(), 3)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UiKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := UiKit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_head(ui, o))
	for line in _notes(o):
		v.add_child(UiKit.wrap_label(line, 21, UiKit.sage_dark()))
	v.add_child(_wares(o))
	row.add_child(v)
	var deliver := UiKit.button("Liefern", "primary" if ok else "light", 28)
	deliver.custom_minimum_size = Vector2(190, 96)
	deliver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deliver.disabled = not ok
	deliver.pressed.connect(ui.act_fulfill.bind(int(o["id"])))
	row.add_child(deliver)
	card.add_child(row)
	return card


static func _head(ui, o: Dictionary) -> HBoxContainer:
	var head := UiKit.hbox(8)
	head.add_child(UiKit.icon("heart", 34))
	var name_label := UiKit.label(I18n.t("%s wünscht sich:") % String(o["customer"]), 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	head.add_child(UiKit.reward_chip("coin", "+%d" % int(o["coins"])))
	head.add_child(UiKit.reward_chip("star", "+%d XP" % int(o["xp"])))
	var skip := UiKit.button("✕", "ghost", 26)
	skip.custom_minimum_size = Vector2(56, 56)
	if o.has("story_id") or o.has("visitor_story") or o.has("neighborhood_event_cycle"):
		skip.disabled = true
		skip.tooltip_text = I18n.t("Geschichts- und Gartentag-Gäste bleiben, bis du ihre Bestellung annimmst.")
	else:
		skip.pressed.connect(ui.act_skip_order.bind(int(o["id"])))
	head.add_child(skip)
	return head


## Begleitzeilen eines Auftrags – nur wenn es sie gibt, damit normale Aufträge
## eine Zeile hoch bleiben.
static func _notes(o: Dictionary) -> Array:
	var lines: Array = []
	if o.has("neighborhood_event_cycle"):
		# Etappe und Fortschritt stehen in der Gartentag-Karte unter den Aufträgen.
		# Hier bleibt nur der Satz des Gastes – eine Zeile, damit auch während eines
		# Gartentags alle vier Aufträge ohne Scrollen ins Buch passen.
		lines.append(I18n.t("Gartentag · %s") % String(o.get("neighborhood_event_story", "")))
	if o.has("story_text"):
		lines.append(I18n.t("Geschichte · %s") % String(o["story_text"]))
	if o.has("visitor_story"):
		lines.append(I18n.t("Zu Besuch im Café · %s") % String(o["visitor_story"]))
	if bool(o.get("cafe_daily_special", false)):
		lines.append(I18n.t("Tagesgericht · +50%% Münzen · +5 XP"))
	return lines


## Ware als Chip (Symbol, „3/3", Name) in einem Flow: mehrere Waren bleiben in
## einer Zeile, bis der Platz wirklich zu Ende ist.
static func _wares(o: Dictionary) -> HFlowContainer:
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_PASS
	chips.add_theme_constant_override("h_separation", 20)
	chips.add_theme_constant_override("v_separation", 4)
	for id in o["items"]:
		var have: int = GameState.item_count(id)
		var need: int = int(o["items"][id])
		var color := UiKit.sage_dark() if have >= need else UiKit.red()
		var chip := UiKit.hbox(6)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(UiKit.item_icon(id, 40))
		var count := UiKit.label("%d/%d" % [mini(have, need), need], 26, color)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(count)
		var item_name := UiKit.label(GameData.item_name(id), 26, color)
		item_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(item_name)
		chips.add_child(chip)
	return chips


## Gartentag, Tagesgericht und Geschichten – hinter den Aufträgen.
static func _build_extras(ui, c: VBoxContainer) -> void:
	if GameState.has_building("cafe"):
		var event_card := UiKit.card(14)
		var event_v := UiKit.vbox(6)
		var event_stage := clampi(GameState.neighborhood_event_stage, 0, GameState.NEIGHBORHOOD_EVENT_SERIES_LENGTH - 1)
		var event_def: Dictionary = GameData.NEIGHBORHOOD_EVENT_STAGES[event_stage]
		event_v.add_child(UiKit.label(I18n.t("Gartentag · %s") % String(event_def["name"]), 26, UiKit.earth_dark()))
		event_v.add_child(UiKit.wrap_label(String(event_def["description"]), 22, UiKit.earth_dark()))
		var event_progress := I18n.t("Etappe %d/%d · %d Gartentage abgeschlossen") % [event_stage + 1, GameState.NEIGHBORHOOD_EVENT_SERIES_LENGTH, int(GameState.stats.get("neighborhood_events_completed", 0))]
		event_v.add_child(UiKit.label(event_progress, 21, UiKit.sage_dark()))
		var event_timer := UiKit.label("", 21, UiKit.earth_dark())
		event_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_v.add_child(event_timer)
		event_card.add_child(event_v)
		c.add_child(event_card)
		ui.ticker.append(func() -> void:
			if GameState.neighborhood_event_active():
				event_timer.text = I18n.t("Gartentag läuft · noch %s") % GameData.format_time(GameState.neighborhood_event_window_seconds_left())
			else:
				event_timer.text = I18n.t("Nächster Gartentag in %s") % GameData.format_time(GameState.neighborhood_event_seconds_left()))
	var daily_special := GameState.daily_cafe_special()
	if not daily_special.is_empty():
		var special_card := UiKit.card(14)
		var special_v := UiKit.vbox(6)
		special_v.add_child(UiKit.label("Heutiges Café-Gericht", 26, UiKit.earth_dark()))
		var special_row := UiKit.hbox(12)
		special_row.add_child(UiKit.item_icon(daily_special, 64))
		var special_text := UiKit.wrap_label(I18n.t("%s · Gäste bestellen es heute besonders gern!\n+50%% Münzen und +5 XP pro Lieferung") % GameData.item_name(daily_special), 22, UiKit.sage_dark())
		special_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		special_row.add_child(special_text)
		special_v.add_child(special_row)
		var special_timer := UiKit.label("", 21, UiKit.earth_dark())
		special_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		special_v.add_child(special_timer)
		special_card.add_child(special_v)
		c.add_child(special_card)
		ui.ticker.append(func() -> void:
			var remaining := GameState.daily_cafe_special_seconds_left()
			special_timer.text = I18n.t("Wechselt in %s") % GameData.format_time(remaining))
	if not GameState.active_delivery_story.is_empty():
		var campaign: Dictionary = GameData.DELIVERY_STORIES[GameState.active_delivery_story]
		var stages: Array = campaign["stages"]
		var story_card := UiKit.card(14)
		var story_v := UiKit.vbox(8)
		story_v.add_child(UiKit.label(I18n.t("Geschichtenreihe · %s") % campaign["title"], 26, UiKit.earth_dark()))
		if GameState.delivery_story_stage < stages.size():
			story_v.add_child(UiKit.wrap_label(I18n.t("Abschnitt %d von %d · %s") % [GameState.delivery_story_stage + 1, stages.size(), str(stages[GameState.delivery_story_stage]["text"])], 22, UiKit.earth_dark()))
		story_v.add_child(UiKit.label(I18n.t("Fortschritt: %d/%d") % [GameState.delivery_story_stage, stages.size()], 21, UiKit.sage_dark()))
		if str(campaign.get("feature", "")) == "cafe":
			story_v.add_child(UiKit.wrap_label(I18n.t("Café-Geschichten abgeschlossen: %d · Gäste bedient: %d") % [int(GameState.stats.get("cafe_stories_completed", 0)), int(GameState.stats.get("cafe_orders", 0))], 21, UiKit.sage_dark()))
		story_card.add_child(story_v)
		c.add_child(story_card)
	else:
		for story_id in GameState.available_delivery_stories():
			var campaign: Dictionary = GameData.DELIVERY_STORIES[story_id]
			var story_card := UiKit.card(14)
			var story_v := UiKit.vbox(8)
			story_v.add_child(UiKit.label(String(campaign["title"]), 26))
			story_v.add_child(UiKit.wrap_label(String(campaign["intro"]), 22, UiKit.earth_dark()))
			var start := UiKit.button(I18n.t("Geschichte beginnen · %d Abschnitte") % campaign["stages"].size(), "warm", 24)
			start.pressed.connect(ui.act_start_delivery_story.bind(story_id))
			story_v.add_child(start)
			story_card.add_child(story_v)
			c.add_child(story_card)
