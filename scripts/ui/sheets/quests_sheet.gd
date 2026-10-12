extends RefCounted
## Questliste: offene Ziele mit Fortschritt, abholbare Belohnungen zuerst.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Ziele")
	var c: VBoxContainer = ui.content
	var qs: Array = GameData.QUESTS.duplicate()
	qs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a) < _rank(b))
	for q in qs:
		var claimed := GameState.quest_claimed(q["id"])
		var done := GameState.quest_done(q)
		var prog := mini(GameState.quest_progress(q), int(q["target"]))
		var card := UiKit.card(12)
		var v := UiKit.vbox(6)
		var head := UiKit.hbox(10)
		head.add_child(UiKit.icon("flag", 44))
		var t := UiKit.wrap_label(String(q["text"]), 32, UiKit.sage_dark() if claimed else UiKit.ink())
		head.add_child(t)
		v.add_child(head)
		v.add_child(UiKit.progress(float(prog) / float(q["target"]), UiKit.sage(), 24))
		var foot := UiKit.hbox(12)
		foot.add_child(UiKit.label("%d/%d" % [prog, int(q["target"])], 26, UiKit.earth_dark()))
		foot.add_child(UiKit.icon_text("coin", "+%d" % int(q["coins"]), 26))
		if int(q["xp"]) > 0:
			foot.add_child(UiKit.icon_text("star", "+%d" % int(q["xp"]), 26))
		foot.add_child(UiKit.spacer())
		var b: Button
		if claimed:
			b = UiKit.button("Erledigt", "light", 26)
			b.disabled = true
		elif done:
			b = UiKit.button("Abholen", "warm", 28)
			b.pressed.connect(ui.act_claim.bind(String(q["id"])))
		else:
			b = UiKit.button("Offen", "light", 26)
			b.disabled = true
		b.custom_minimum_size = Vector2(200, 84)
		foot.add_child(b)
		v.add_child(foot)
		card.add_child(v)
		c.add_child(card)


static func _rank(q: Dictionary) -> int:
	if GameState.quest_claimed(q["id"]):
		return 3
	if GameState.quest_done(q):
		return 0
	return 1
