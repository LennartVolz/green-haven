extends RefCounted
## Ein Ausflug als kleine Szene: Foto, zwei Sätze und je ein Herz.
## Die Szene ist eine Erinnerung, keine Aufgabe – der Ausflug läuft weiter,
## auch wenn das Sheet geschlossen wird.


## Das Foto: die beiden Tiere vor ihrem Ziel, gerahmt wie ein Bild im Tagebuch.
## Wird auch vom Tagebuch benutzt, damit Erinnerung und Eintrag gleich aussehen.
static func photo_frame(species: Array, caption: String) -> PanelContainer:
	var frame := UiKit.panel(UiKit.cream(), 26, 10, UiKit.cream_dark(), 6)
	frame.name = "ExcursionPhoto"
	var v := UiKit.vbox(6)
	var scene := UiKit.panel(UiKit.sage(), 18, 10)
	var row := UiKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in species:
		var species_id := str(id)
		if not GameData.ANIMALS.has(species_id):
			continue
		var pv := ObjPreview.new()
		pv.setup("animal", species_id)
		pv.name = "PhotoAnimal%d" % row.get_child_count()
		pv.custom_minimum_size = Vector2(148, 148)
		row.add_child(pv)
	scene.add_child(row)
	v.add_child(scene)
	var label := UiKit.label(I18n.t("Foto · %s") % caption, 22, UiKit.earth_dark())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(label)
	frame.add_child(v)
	return frame


static func build(ui, args: Dictionary) -> void:
	var destination := str(args.get("destination", GameState.excursion.get("destination", "")))
	var d: Dictionary = GameData.EXCURSIONS.get(destination, {})
	if d.is_empty():
		ui.close_sheet()
		return
	var name := String(d["name"])
	ui.set_title(I18n.t("Ausflug %s") % String(d["place"]))
	var c: VBoxContainer = ui.content
	var participants := GameState.excursion_participants()
	var species: Array = []
	var names: Array = []
	for a in participants:
		species.append(String(a.species))
		names.append(String(a.name))
	c.add_child(photo_frame(species, name))
	var lines := UiKit.vbox(10)
	for line in d["text"]:
		lines.add_child(UiKit.wrap_label(String(line), 28))
	c.add_child(lines)
	if names.size() == 2:
		c.add_child(UiKit.wrap_label(I18n.t("%s und %s sind noch eine Weile draußen.") % [names[0], names[1]], 24, UiKit.earth_dark()))
	c.add_child(UiKit.icon_text("heart", I18n.t("Jedes der beiden Tiere hat ein Herz dazugewonnen."), 30, UiKit.sage_dark()))
	if GameState.excursion_active():
		c.add_child(UiKit.wrap_label(I18n.t("Noch %s unterwegs. Danach sind sie wieder im Gehege.") % GameData.format_time(GameState.excursion_seconds_left()), 22, UiKit.earth_dark()))
	var diary := UiKit.button("Im Tagebuch ansehen", "warm", 30)
	diary.pressed.connect(ui.act_open_diary)
	c.add_child(diary)
	var back := UiKit.button("Zurück zum Refugium", "primary", 32)
	back.pressed.connect(ui.act_open.bind("refuge", {}))
	c.add_child(back)
