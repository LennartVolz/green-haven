extends RefCounted
## Hofbuch: acht Auszeichnungen und sechs Hofränge. Beide messen Breite statt
## Zahlen; ein Rang belohnt mit einem sichtbaren Zeichen am Hof und einem Absatz.
## Die Ränge stehen oben, weil sie den längeren Bogen erzählen.

## Anzeigenamen der Bedingungstypen. Neue Typen kommen aus GameState; fehlt hier
## ein Name, steht der Typ selbst da, statt dass der Rang verschwindet.
const NEED_NAMES := {
	"lexicon": "Lexikon",
	"crops": "Erntesorten",
	"recipes": "Rezepte",
	"seasons": "Jahreszeiten",
	"season_goals": "Saisonziele",
	"cafe_guests": "Café-Gäste",
	"cafe_stories": "Café-Geschichten",
	"letters": "Briefe",
	"visits": "Hofbesuche",
	"friends": "Freundschaften",
	"hofbuch": "Hofbuch",
	"achievements": "Erfolge",
}


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Hofbuch")
	var c: VBoxContainer = ui.content
	c.add_child(UiKit.wrap_label("Acht Auszeichnungen und sechs Hofränge für alles, was nebenbei entsteht. Nichts läuft ab, nichts muss gejagt werden.", 24, UiKit.earth_dark()))
	_build_ranks(ui, c)
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


## Die sechs Hofränge: Fortschritt je Bedingung, und nach dem Erreichen der
## kurze Absatz, der zum Rang gehört. Kein Knopf, keine Belohnung zum Abholen.
static func _build_ranks(ui, c: VBoxContainer) -> void:
	c.add_child(UiKit.label("Hofränge", 32, UiKit.earth_dark()))
	c.add_child(UiKit.wrap_label("Sechs Ränge für die Breite: Sie zählen, was du überall ausprobiert hast, nicht wie hoch deine Stufe ist. Einmal erreicht, bleibt ein Rang.", 22, UiKit.earth_dark()))
	for index in range(1, GameData.HOFRANKS.size() + 1):
		var rank: Dictionary = GameData.HOFRANKS[index - 1]
		var reached: bool = GameState.hofrang_reached(index)
		var card := UiKit.card(12)
		var v := UiKit.vbox(6)
		var head := UiKit.hbox(10)
		head.add_child(UiKit.icon("flag" if reached else "lock", 38))
		var title := UiKit.label(String(rank["text"]), 30, UiKit.sage_dark() if reached else UiKit.ink())
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(UiKit.label(I18n.t("Rang %d") % index, 20, UiKit.earth_dark()))
		v.add_child(head)
		v.add_child(UiKit.wrap_label(String(rank["description"]), 21, UiKit.earth_dark()))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 16)
		chips.add_theme_constant_override("v_separation", 2)
		for need in rank.get("needs", []):
			var target := int(need.get("target", 0))
			var done := mini(GameState.hofrang_need_progress(need), target)
			var need_name := str(NEED_NAMES.get(str(need.get("type", "")), str(need.get("type", ""))))
			var color := UiKit.sage_dark() if done >= target else UiKit.earth_dark()
			chips.add_child(UiKit.label(I18n.t("%s %d/%d") % [I18n.t(need_name), done, target], 20, color))
		v.add_child(chips)
		if reached:
			v.add_child(UiKit.wrap_label(String(rank["story"]), 22, UiKit.sage_dark()))
		card.add_child(v)
		c.add_child(card)


static func _rank(entry: Dictionary) -> int:
	if GameState.hofbuch_entry_claimed(str(entry["id"])):
		return 2
	if GameState.hofbuch_unlocked(entry):
		return 0
	return 1
