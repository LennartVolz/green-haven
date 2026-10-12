extends RefCounted
## Einstellungen sowie Speichern und Laden.


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Einstellungen")
	var c: VBoxContainer = ui.content
	var snd: bool = GameState.settings.get("sound", true)
	var vib: bool = GameState.settings.get("vibration", true)
	var b1 := UiKit.button("Ton: %s" % ("An" if snd else "Aus"), "primary" if snd else "light", 32)
	b1.pressed.connect(ui.act_toggle.bind("sound"))
	c.add_child(b1)
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
	var load_b := UiKit.button("Laden", "light", 30)
	load_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_b.disabled = not SaveSystem.has_save()
	load_b.pressed.connect(ui.act_load)
	row.add_child(load_b)
	c.add_child(row)

	c.add_child(UiKit.label("Weiteres", 30, UiKit.earth_dark()))
	var cam := UiKit.button("Kamera zur Farm zentrieren", "light", 30)
	cam.pressed.connect(ui.act_recenter)
	c.add_child(cam)
	var tut := UiKit.button("Tutorial wiederholen", "light", 30)
	tut.pressed.connect(ui.act_restart_tutorial)
	c.add_child(tut)
	var armed: bool = ui.state.get("confirm_new", false)
	var nb := UiKit.button("Wirklich neu beginnen? Nochmal tippen" if armed else "Neues Spiel beginnen", "danger" if armed else "light", 30)
	nb.pressed.connect(ui.act_new_game)
	c.add_child(nb)
	var ver := UiKit.label("Green Haven · Version %s · Spielstand-Format %d" % [ProjectSettings.get_setting("application/config/version", "0.1.0"), GameState.SAVE_VERSION], 22, UiKit.earth_dark())
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)
