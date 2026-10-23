extends RefCounted
## Dauerhafte Erfolge mit Fortschritt und einmalig abholbaren Belohnungen.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Erfolge")
	var c: VBoxContainer = ui.content
	c.add_child(UiKit.wrap_label("Kleine und große Meilensteine auf deiner Farm. Belohnungen kannst du jederzeit abholen.", 24, UiKit.earth_dark()))
	# Hofbuch und Lexikon haben ihren eigenen Bereich in der Navigation; hier
	# bleibt die Liste wieder eine reine Erfolgsliste.
	var achievements: Array = GameData.ACHIEVEMENTS.duplicate()
	achievements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a) < _rank(b))
	for achievement in achievements:
		var id: String = str(achievement["id"])
		var claimed := GameState.claimed_achievements.has(id)
		var progress := mini(GameState.achievement_progress(achievement), int(achievement["target"]))
		var target := int(achievement["target"])
		var card := UiKit.card(14)
		var v := UiKit.vbox(8)
		var title_row := UiKit.hbox(10)
		title_row.add_child(UiKit.icon("star" if GameState.achievement_unlocked(achievement) else "lock", 40))
		var title := UiKit.label(String(achievement["text"]), 30, UiKit.sage_dark() if claimed else UiKit.ink())
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		v.add_child(title_row)
		v.add_child(UiKit.wrap_label(String(achievement["description"]), 22, UiKit.earth_dark()))
		v.add_child(UiKit.progress(float(progress) / float(target), UiKit.sage(), 22))
		var foot := UiKit.hbox(10)
		foot.add_child(UiKit.label("%d/%d" % [progress, target], 24, UiKit.earth_dark()))
		foot.add_child(UiKit.icon_text("coin", "+%d" % int(achievement["coins"]), 23))
		foot.add_child(UiKit.icon_text("star", "+%d XP" % int(achievement["xp"]), 23))
		foot.add_child(UiKit.spacer())
		var button: Button
		if claimed:
			button = UiKit.button("Abgeholt", "light", 24)
			button.disabled = true
		elif progress >= target:
			button = UiKit.button("Belohnung abholen", "warm", 24)
			button.pressed.connect(ui.act_claim_achievement.bind(id))
		else:
			button = UiKit.button("In Arbeit", "light", 24)
			button.disabled = true
		button.custom_minimum_size = Vector2(220, 78)
		foot.add_child(button)
		v.add_child(foot)
		card.add_child(v)
		c.add_child(card)


static func _rank(achievement: Dictionary) -> int:
	var id := str(achievement["id"])
	if GameState.claimed_achievements.has(id):
		return 2
	if GameState.achievement_unlocked(achievement):
		return 0
	return 1
