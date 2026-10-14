extends RefCounted
## Chronik des Refugiums mit Rettungen, gemeinsamen Momenten und Geschichten.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Refugiums-Tagebuch")
	var c: VBoxContainer = ui.content
	c.add_child(UiKit.wrap_label("Kleine Erinnerungen an neue Zuhause, gemeinsame Zeit und Geschichten aus der Nachbarschaft.", 24, UiKit.earth_dark()))
	if GameState.diary.is_empty():
		c.add_child(UiKit.wrap_label("Deine Chronik beginnt mit dem ersten besonderen Moment.", 26))
		return
	var entries: Array = GameState.diary.duplicate()
	entries.reverse()
	for entry in entries:
		var card := UiKit.card(12)
		var row := UiKit.hbox(10)
		row.add_child(UiKit.icon("paw" if int(entry.get("animal_uid", -1)) >= 0 else "scroll", 36))
		var text := UiKit.wrap_label(String(entry.get("text", "")), 24, UiKit.earth_dark())
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var stamp := Time.get_datetime_dict_from_unix_time(int(entry.get("time", 0.0)))
		var date := UiKit.label("%02d.%02d.%04d" % [int(stamp.day), int(stamp.month), int(stamp.year)], 18, UiKit.sage_dark())
		date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(date)
		card.add_child(row)
		c.add_child(card)
