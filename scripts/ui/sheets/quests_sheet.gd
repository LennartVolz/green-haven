extends RefCounted
## Zieliste: saisonale Ziele der laufenden Jahreszeit oben, danach die
## dauerhaften Ziele. Abholbare Belohnungen stehen jeweils zuerst.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Ziele")
	var c: VBoxContainer = ui.content
	_season_block(ui, c)
	c.add_child(UiKit.wrap_label("Dauerhafte Ziele", 26, UiKit.earth_dark()))
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


## Saisonblock: Jahreszeit, Resttage und die drei Ziele. Die Ziele zählen nur
## innerhalb der Saison und verfallen nie – dieselbe Jahreszeit kommt wieder.
static func _season_block(ui, c: VBoxContainer) -> void:
	var day: int = GameState.day_number()
	var season: Dictionary = GameData.season_at(day)
	var season_id := str(season["id"])
	var card := UiKit.card(14)
	var v := UiKit.vbox(8)
	var head := UiKit.hbox(10)
	head.add_child(UiKit.icon("leaf", 40))
	var title := UiKit.label("%s · %s" % [String(season["name"]), _days_text(GameState.season_days_left())], 30, UiKit.ink())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	v.add_child(head)
	v.add_child(UiKit.wrap_label("Saisonziele gelten in der laufenden Jahreszeit. Verpasstes kommt im nächsten Jahr wieder.", 22, UiKit.earth_dark()))
	for goal in GameState.season_goals():
		var id := str(goal["id"])
		var claimed := GameState.season_goal_claimed(goal)
		var done := GameState.season_goal_done(goal)
		var prog := mini(GameState.season_goal_progress(goal), int(goal["target"]))
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon("star" if claimed else "leaf", 32))
		var col := UiKit.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(String(goal["text"]), 26, UiKit.sage_dark() if claimed else UiKit.ink()))
		col.add_child(UiKit.progress(float(prog) / float(goal["target"]), UiKit.sage(), 18))
		col.add_child(UiKit.label("%d/%d" % [prog, int(goal["target"])], 22, UiKit.earth_dark()))
		row.add_child(col)
		var b: Button
		if claimed:
			b = UiKit.button("Erledigt", "light", 24)
			b.disabled = true
		elif done:
			b = UiKit.button("Abholen", "warm", 26)
			b.pressed.connect(ui.act_claim_season_goal.bind(id))
		else:
			b = UiKit.button("Offen", "light", 24)
			b.disabled = true
		b.custom_minimum_size = Vector2(180, 72)
		row.add_child(b)
		v.add_child(row)
	v.add_child(_season_reward_label(season_id))
	card.add_child(v)
	c.add_child(card)


static func _season_reward_label(season_id: String) -> Control:
	var deco := str(GameData.SEASON_REWARD_DECOS.get(season_id, ""))
	var deco_name := str(GameData.DECOS.get(deco, {}).get("name", "Deko"))
	var text := "Alle drei Ziele schalten %s frei." % deco_name
	if GameState.deco_unlocked(deco):
		text = "%s ist freigeschaltet und im Shop unter Deko kostenlos platzierbar." % deco_name
	return UiKit.wrap_label(text, 22, UiKit.earth_dark())


static func _days_text(days_left: int) -> String:
	if days_left <= 0:
		return "letzter Tag"
	if days_left == 1:
		return "noch 1 Tag"
	return "noch %d Tage" % days_left


static func _rank(q: Dictionary) -> int:
	if GameState.quest_claimed(q["id"]):
		return 3
	if GameState.quest_done(q):
		return 0
	return 1
