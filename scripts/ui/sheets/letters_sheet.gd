extends RefCounted
## Briefkasten: Briefe aus der Nachbarschaft, kleine Bitten und die Freundschaft
## zu jedem Nachbarn. Nichts läuft ab, nichts muss beantwortet werden.

static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Briefkasten")
	ui.set_subtitle("Post aus der Nachbarschaft")
	var c: VBoxContainer = ui.content
	_build_letters(ui, c)
	_build_neighbors(ui, c)


static func _build_letters(ui, c: VBoxContainer) -> void:
	if GameState.letters.is_empty():
		c.add_child(UiKit.wrap_label("Noch ist der Briefkasten leer. Die Nachbarschaft meldet sich bald – ganz ohne Eile.", 28))
		return
	var entries: Array = GameState.letters.duplicate()
	entries.reverse()
	for letter in entries:
		var definition := GameState.letter_definition(letter)
		if definition.is_empty():
			continue
		var neighbor: Dictionary = GameData.NEIGHBORS[str(letter["neighbor"])]
		var card := UiKit.card(14)
		var v := UiKit.vbox(8)
		var head := UiKit.hbox(10)
		head.add_child(UiKit.icon("scroll", 42))
		var name := UiKit.label(String(neighbor["name"]), 30)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		var stamp := Time.get_datetime_dict_from_unix_time(int(float(letter.get("at", 0.0))))
		head.add_child(UiKit.label("%02d.%02d." % [int(stamp.day), int(stamp.month)], 20, UiKit.earth_dark()))
		v.add_child(head)
		v.add_child(UiKit.wrap_label(String(definition.get("text", "")), 26))
		var request: Dictionary = definition.get("request", {})
		if not request.is_empty():
			if bool(letter.get("delivered", false)):
				v.add_child(UiKit.icon_text("heart", I18n.t("Schon geliefert – danke!"), 24, UiKit.sage_dark()))
			else:
				var chips := HFlowContainer.new()
				chips.add_theme_constant_override("h_separation", 16)
				chips.add_theme_constant_override("v_separation", 4)
				var items: Dictionary = request.get("items", {})
				for item_id in items:
					chips.add_child(UiKit.item_chip(str(item_id), GameState.item_count(str(item_id)), int(items[item_id])))
				v.add_child(chips)
				var deliver := UiKit.button(I18n.t("Liefern  +%d") % int(request.get("coins", 0)), "primary", 28)
				deliver.disabled = not GameState.can_deliver_letter(str(letter["id"]))
				deliver.pressed.connect(ui.act_deliver_letter.bind(str(letter["id"])))
				v.add_child(deliver)
		card.add_child(v)
		c.add_child(card)


## Die sechs Nachbarn: Ton, Freundschaftsstufe und der Weg zu ihrem Hof.
static func _build_neighbors(ui, c: VBoxContainer) -> void:
	c.add_child(UiKit.label("Nachbarschaft", 30, UiKit.earth_dark()))
	c.add_child(UiKit.wrap_label("Ab dem zweiten Brief darfst du einen Hof besuchen. Zwei Stellen dort erzählen je einen Satz.", 22, UiKit.earth_dark()))
	for neighbor_id in GameData.NEIGHBORS:
		var id := str(neighbor_id)
		var neighbor: Dictionary = GameData.NEIGHBORS[id]
		var level := GameState.neighbor_level(id)
		var card := UiKit.card(12)
		var h := UiKit.hbox(12)
		h.add_child(UiKit.icon("heart", 40))
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label(I18n.t("%s · Freundschaft %d/3") % [String(neighbor["name"]), level], 28))
		v.add_child(UiKit.wrap_label(String(neighbor["note"]), 21, UiKit.earth_dark()))
		if GameState.neighbor_sign_unlocked(id):
			v.add_child(UiKit.icon_text("flag", I18n.t("Namensschild für den Hof freigeschaltet"), 20, UiKit.sage_dark()))
		var unlocked := GameState.visit_unlocked(id)
		var visit := UiKit.button("Besuchen" if unlocked else I18n.t("Ab %d Briefen") % GameState.VISIT_LETTERS_REQUIRED, "primary" if unlocked else "light", 26)
		visit.custom_minimum_size = Vector2(200, 88)
		visit.disabled = not unlocked
		if unlocked:
			visit.pressed.connect(ui.act_visit_neighbor.bind(id))
		h.add_child(visit)
		card.add_child(h)
		c.add_child(card)
