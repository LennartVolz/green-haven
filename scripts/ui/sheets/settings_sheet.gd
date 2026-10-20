extends RefCounted
## Einstellungen sowie Speichern und Laden.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Einstellungen")
	var c: VBoxContainer = ui.content
	var MusicScript := load("res://scripts/core/background_music.gd")
	var sound_volume := clampf(float(GameState.settings.get("sound_volume", 1.0)), 0.0, 1.0)
	var music_volume := clampf(float(GameState.settings.get("music_volume", 1.0)), 0.0, 1.0)
	var vib: bool = GameState.settings.get("vibration", true)
	var music_available: bool = MusicScript.track_available()
	c.add_child(UiKit.label("Lautstärke", 30, UiKit.earth_dark()))
	c.add_child(_volume_row(ui, "sound", "Ton", sound_volume))
	c.add_child(_volume_row(ui, "music", "Hintergrundmusik", music_volume, music_available))
	if not music_available:
		c.add_child(UiKit.wrap_label("Für Hintergrundmusik ist auf diesem Gerät kein Track verfügbar.", 22, UiKit.earth_dark()))
	var b2 := UiKit.button("Vibration: %s" % ("An" if vib else "Aus"), "primary" if vib else "light", 32)
	b2.pressed.connect(ui.act_toggle.bind("vibration"))
	c.add_child(b2)

	c.add_child(UiKit.label("Spielstand", 30, UiKit.earth_dark()))
	var info := "Wird automatisch alle %d Sekunden und beim Verlassen der App gespeichert." % int(SaveSystem.AUTOSAVE_SECONDS)
	c.add_child(UiKit.wrap_label(info, 26, UiKit.earth_dark()))
	var row := UiKit.hbox(12)
	var save := UiKit.button("Speichern", "warm", 30)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(ui.act_save)
	row.add_child(save)
	var load_armed: bool = ui.state.get("confirm_load", false)
	var load_b := UiKit.button("Wirklich laden? Nochmal tippen" if load_armed else "Laden", "danger" if load_armed else "light", 30)
	load_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_b.disabled = not SaveSystem.has_save()
	load_b.pressed.connect(ui.act_load)
	row.add_child(load_b)
	c.add_child(row)
	var transfer_row := UiKit.hbox(12)
	var export_armed: bool = ui.state.get("confirm_export_save", false)
	var export_button := UiKit.button("Wirklich exportieren? Nochmal tippen" if export_armed else "Spielstand exportieren", "danger" if export_armed else "light", 28)
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(ui.act_export_save)
	transfer_row.add_child(export_button)
	var import_armed: bool = ui.state.get("confirm_import_save", false)
	var import_button := UiKit.button("Wirklich importieren? Nochmal tippen" if import_armed else "Spielstand importieren", "danger" if import_armed else "light", 28)
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(ui.act_import_save)
	transfer_row.add_child(import_button)
	c.add_child(transfer_row)
	if OS.has_feature("android"):
		c.add_child(UiKit.wrap_label("Android: Godot 4.4.1 zeigt den Dateidialog, kann ausgewählte Dokumente aber nicht zuverlässig öffnen. Import: savegame.json in den app-internen Ordner user://save_transfer kopieren. Export: Dort die gespeicherte JSON-Datei herauskopieren.", 22, UiKit.earth_dark()))
	else:
		c.add_child(UiKit.wrap_label("JSON-Spielstände lassen sich auf diesem Gerät auswählen und als Datei weitergeben.", 22, UiKit.earth_dark()))

	c.add_child(UiKit.label("Weiteres", 30, UiKit.earth_dark()))
	var cam := UiKit.button("Kamera zur Farm zentrieren", "light", 30)
	cam.pressed.connect(ui.act_recenter)
	c.add_child(cam)
	var tut := UiKit.button("Tutorial wiederholen", "light", 30)
	tut.pressed.connect(ui.act_restart_tutorial)
	c.add_child(tut)
	var armed: bool = ui.state.get("confirm_new", false)
	var nb := UiKit.button("Alles löschen und neu beginnen? Nochmal tippen" if armed else "Neues Spiel beginnen", "danger" if armed else "light", 30)
	nb.pressed.connect(ui.act_new_game)
	c.add_child(nb)
	var ver := UiKit.label("Green Haven · Version %s · Spielstand-Format %d" % [ProjectSettings.get_setting("application/config/version", "0.1.0"), GameState.SAVE_VERSION], 22, UiKit.earth_dark())
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)


static func _volume_row(ui, key: String, title: String, value: float, enabled: bool = true) -> HBoxContainer:
	var row := UiKit.hbox(14)
	var name_label := UiKit.label(title, 30)
	name_label.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_label)
	var slider := UiKit.slider(value)
	slider.name = "Volume_" + key
	slider.editable = enabled
	if not enabled:
		slider.tooltip_text = "Kein Hintergrundmusik-Track verfügbar"
	row.add_child(slider)
	var percent := UiKit.label("%d%%" % roundi(value * 100.0), 28, UiKit.earth_dark())
	percent.custom_minimum_size = Vector2(90, 0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	slider.value_changed.connect(func(v: float) -> void:
		percent.text = "%d%%" % roundi(v * 100.0)
		if enabled:
			ui.act_set_volume(key, v)
	)
	return row
