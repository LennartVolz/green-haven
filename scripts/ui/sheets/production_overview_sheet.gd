extends RefCounted
## Übersicht aller Produktionsgebäude: Warteschlangen, Restzeiten, abholbare
## Produkte sowie Sammelabholung. Einzelne Gebäude öffnen die Detailansicht.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Produktion")
	var c: VBoxContainer = ui.content
	var buildings: Array = GameState.production_buildings()
	if buildings.is_empty():
		c.add_child(UiKit.wrap_label("Noch gibt es kein Produktionsgebäude. Ab Stufe 2 kannst du im Shop eine Bäckerei bauen – danach siehst du hier alle Warteschlangen und fertigen Produkte auf einen Blick.", 28, UiKit.earth_dark()))
		var shop := UiKit.button("Gebäude im Shop ansehen", "primary", 30)
		shop.pressed.connect(ui.act_open_shop_tab.bind("buildings"))
		c.add_child(shop)
		return

	var total_ready := GameState.total_ready_products()
	var active := GameState.active_product_count()
	var free := 0
	for o in buildings:
		free += maxi(0, GameState.queue_capacity(o) - (o.queue as Array).size())

	var summary := UiKit.card(14)
	var sv := UiKit.vbox(10)
	var head := UiKit.hbox(14)
	head.add_child(UiKit.icon("factory", 76))
	var hv := UiKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UiKit.label("Alles im Blick", 34))
	hv.add_child(UiKit.label(I18n.t("%d Gebäude · %d fertig · %d in Arbeit · %d freie Plätze") % [buildings.size(), total_ready, active, free], 25, UiKit.earth_dark()))
	head.add_child(hv)
	sv.add_child(head)
	var collect_all := UiKit.button(I18n.t("Alles abholen (%d)") % total_ready if total_ready > 0 else I18n.t("Nichts abzuholen"), "warm" if total_ready > 0 else "light", 32)
	collect_all.disabled = total_ready <= 0
	collect_all.pressed.connect(ui.act_collect_all)
	sv.add_child(collect_all)
	summary.add_child(sv)
	c.add_child(summary)

	for o in buildings:
		c.add_child(_building_card(ui, o))
	var hint := UiKit.label("Tippe auf Details, um Rezepte zu starten oder einen Platz auszubauen.", 24, UiKit.earth_dark())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(hint)


static func _building_card(ui, o: Dictionary) -> PanelContainer:
	var def: Dictionary = GameData.BUILDINGS[o.type]
	var card := UiKit.card(12)
	var v := UiKit.vbox(10)
	var head := UiKit.hbox(12)
	head.add_child(UiKit.icon("factory", 64))
	var tv := UiKit.vbox(1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UiKit.label(String(def["name"]), 31))
	var queue: Array = o.queue
	var ready := GameState.ready_count(o)
	var status := I18n.t("%d von %d Plätzen belegt · Ausbau %d/%d") % [queue.size(), GameState.queue_capacity(o), int(o.upgrades), GameState.MAX_UPGRADES]
	var status_color := UiKit.earth_dark()
	if ready > 0:
		status += I18n.t(" · %d fertig") % ready
		status_color = UiKit.sage_dark()
	tv.add_child(UiKit.label(status, 23, status_color))
	head.add_child(tv)
	var details := UiKit.button("Details", "light", 26)
	details.custom_minimum_size = Vector2(150, 88)
	details.pressed.connect(ui.act_open.bind("production", {"uid": int(o.uid), "from_overview": true}))
	head.add_child(details)
	v.add_child(head)
	if queue.is_empty():
		v.add_child(UiKit.label("Warteschlange leer", 24, UiKit.earth_dark()))
	else:
		for e in queue:
			v.add_child(_entry_row(ui, e))
	if ready > 0:
		var collect := UiKit.button(I18n.t("Abholen (%d)") % ready, "warm", 27)
		collect.pressed.connect(ui.act_collect.bind(int(o.uid)))
		v.add_child(collect)
	card.add_child(v)
	return card


static func _entry_row(ui, entry: Dictionary) -> HBoxContainer:
	var h := UiKit.hbox(12)
	var rid: String = String(entry.get("recipe", ""))
	h.add_child(UiKit.item_icon(rid, 64))
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiKit.label(GameData.item_name(rid), 27))
	var bar := UiKit.progress(GameState.entry_progress(entry), UiKit.sage(), 18)
	v.add_child(bar)
	var tl := UiKit.label("", 23, UiKit.earth_dark())
	v.add_child(tl)
	h.add_child(v)
	var state := UiKit.label("", 24, UiKit.earth_dark())
	state.custom_minimum_size = Vector2(130, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(state)
	_apply_entry_state(bar, tl, state, entry)
	ui.ticker.append(func() -> void:
		_apply_entry_state(bar, tl, state, entry))
	return h


## Aktualisiert Fortschrittsbalken und Beschriftung eines Warteschlangeneintrags.
static func _apply_entry_state(bar: ProgressBar, tl: Label, state: Label, entry: Dictionary) -> void:
	var remaining := float(entry["end"]) - GameState.now()
	bar.value = GameState.entry_progress(entry)
	if remaining <= 0.0:
		tl.text = I18n.t("Bereit zum Abholen")
		state.text = I18n.t("Fertig")
		state.add_theme_color_override("font_color", UiKit.sage_dark())
	elif float(entry["start"]) > GameState.now():
		tl.text = I18n.t("wartet · fertig in %s") % GameData.format_time(remaining)
		state.text = I18n.t("Wartet")
	else:
		tl.text = I18n.t("noch %s") % GameData.format_time(remaining)
		state.text = I18n.t("Läuft")
