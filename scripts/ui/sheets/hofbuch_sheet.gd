extends RefCounted
## Hofbuch: acht Auszeichnungen jenseits der Höchststufe. Sie messen Breite statt
## Zahlen und belohnen mit einer kostenlosen Deko und einer kurzen Geschichte.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Hofbuch")
	var c: VBoxContainer = ui.content
	c.add_child(UiKit.wrap_label("Acht Auszeichnungen für alles, was nebenbei entsteht. Nichts läuft ab, nichts muss gejagt werden.", 24, UiKit.earth_dark()))
	var entries: Array = GameData.HOFBUCH.duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a) < _rank(b))
	for entry in entries:
		var id := str(entry["id"])
		var claimed := GameState.hofbuch_entry_claimed(id)
		var prog := mini(GameState.hofbuch_progress(entry), int(entry["target"]))
		var target := int(entry["target"])
		var card := UiKit.card(14)
		var v := UiKit.vbox(8)
		var title_row := UiKit.hbox(10)
		title_row.add_child(UiKit.icon("star" if claimed else "lock", 40))
		var title := UiKit.label(String(entry["text"]), 30, UiKit.sage_dark() if claimed else UiKit.ink())
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		v.add_child(title_row)
		v.add_child(UiKit.wrap_label(String(entry["description"]), 22, UiKit.earth_dark()))
		v.add_child(UiKit.progress(float(prog) / float(target), UiKit.sage(), 22))
		var foot := UiKit.hbox(10)
		foot.add_child(UiKit.label("%d/%d" % [prog, target], 24, UiKit.earth_dark()))
		var deco := str(entry.get("deco", ""))
		var deco_name := str(GameData.DECOS.get(deco, {}).get("name", "Deko"))
		foot.add_child(UiKit.icon_text("leaf", deco_name, 23))
		foot.add_child(UiKit.spacer())
		var button: Button
		if claimed:
			button = UiKit.button("Eingetragen", "light", 24)
			button.disabled = true
		elif prog >= target:
			button = UiKit.button("Eintragen", "warm", 24)
			button.pressed.connect(ui.act_claim_hofbuch.bind(id))
		else:
			button = UiKit.button("In Arbeit", "light", 24)
			button.disabled = true
		button.custom_minimum_size = Vector2(220, 78)
		foot.add_child(button)
		v.add_child(foot)
		if claimed:
			v.add_child(UiKit.wrap_label(String(entry.get("story", "")), 22, UiKit.sage_dark()))
		card.add_child(v)
		c.add_child(card)


static func _rank(entry: Dictionary) -> int:
	if GameState.hofbuch_entry_claimed(str(entry["id"])):
		return 2
	if GameState.hofbuch_unlocked(entry):
		return 0
	return 1
