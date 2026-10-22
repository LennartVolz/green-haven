extends SceneTree
## Prüft die Übersichtlichkeit des Layouts – in allen Sprachen:
## 1. kein Text wird zusammengequetscht (schmaler als sein längstes Wort),
## 2. der Tutorial-Hinweis ist ein Streifen statt einer halben Bildschirmkarte,
## 3. vier Aufträge passen ohne Scrollen ins Auftragsbuch,
## 4. die Werkzeugleiste weicht dem Sheet und kommt danach zurück,
## 5. die drei Lesbarkeitsstufen vergrößern Schrift und Schaltflächen, ohne
##    Text zu quetschen oder das Sheet zu sprengen.

const TRANSLATED := ["en", "fr", "es", "it"]
## Sheets, die Belohnungszeilen zeigen – dort brach der Text vorher um.
const CHECKED_SHEETS := ["orders", "quests", "achievements", "inventory", "shop"]

var gs: Node
var ui: Node
var failures := 0


func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame


func check(condition: bool, message: String) -> bool:
	if condition:
		return true
	failures += 1
	printerr("FAIL: ", message)
	return false


## Ein Text gilt als zusammengequetscht, wenn er deutlich schmaler ist als sein
## längstes Wort und deshalb in einzelne Buchstabenzeilen umbricht. Genau das
## passierte den Belohnungen („+18" wurde 1 px breit und 294 px hoch).
func squeezed(c: Control, text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	var font := c.get_theme_font("font")
	var size := c.get_theme_font_size("font_size")
	if font == null or size <= 0:
		return ""
	var widest := 0.0
	for word in text.split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if widest <= 0.0:
		return ""
	if c.size.x < widest * 0.6 and c.size.y > font.get_height(size) * 2.5:
		return "%.0f×%.0f px, längstes Wort %.0f px: «%s»" % [c.size.x, c.size.y, widest, text]
	return ""


func find_squeezed(node: Node, out: Array) -> void:
	if node is Label or node is Button:
		var c := node as Control
		var text := String((node as Label).text) if node is Label else String((node as Button).text)
		if c.is_visible_in_tree():
			var problem := squeezed(c, text)
			if problem != "":
				out.append("%s – %s" % [c.get_path(), problem])
	for child in node.get_children():
		find_squeezed(child, out)


func check_text(locale: String, where: String) -> void:
	var out: Array = []
	find_squeezed(ui, out)
	for line in out:
		printerr("  ", line)
	check(out.is_empty(), "[%s] %s: kein zusammengequetschter Text (%d Stellen)" % [locale, where, out.size()])


## Nichts darf über den Inhaltsrand hinauslaufen: bei 1920 logischen Pixeln passt
## fast alles, aber eine lange Übersetzung in einer festen Zeile kann überstehen.
func check_overflow(locale: String, where: String) -> void:
	var limit: float = ui.content.get_global_rect().end.x
	var out: Array = []
	find_overflow(ui.content, limit, out)
	for line in out:
		printerr("  ", line)
	check(out.is_empty(), "[%s] %s: nichts läuft über den Inhaltsrand (%d Stellen)" % [locale, where, out.size()])


func find_overflow(node: Node, limit: float, out: Array) -> void:
	for child in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			var c := child as Control
			if c.get_global_rect().end.x > limit + 2.0:
				out.append("%s endet bei %.0f px (Grenze %.0f px)" % [c.get_path(), c.get_global_rect().end.x, limit])
			find_overflow(c, limit, out)


func check_tutorial(locale: String) -> void:
	# Jeder Schritt muss in den Streifen passen – die Hinweisschritte sind länger
	# als der erste Satz.
	var steps: Array = ui.get_script().get_script_constant_map()["TUTORIAL"]
	var panel: PanelContainer = ui._tut_panel
	var view: Vector2 = ui._layer.size
	var tallest := 0.0
	for step in range(steps.size()):
		gs.tutorial_step = step
		ui._update_tutorial()
		await frames(2)
		tallest = maxf(tallest, panel.size.y)
	gs.tutorial_step = 0
	ui._update_tutorial()
	await frames(3)
	check(panel.visible, "[%s] Tutorial-Hinweis ist sichtbar" % locale)
	# Ein Fünftel der Höhe ist die harte Grenze (vorher füllte die Karte über die
	# Hälfte). Bei normaler Schrift bleibt der Streifen unter 10 %; die große
	# Stufe braucht eine Zeile mehr, liegt aber weiterhin deutlich darunter.
	check(tallest <= view.y * 0.20, "[%s] Hinweis bleibt ein Streifen: %.0f von %.0f px" % [locale, tallest, view.y])
	# Mit großer Schrift darf der Streifen breiter werden, statt höher zu wachsen.
	var width_share := 0.74 if float(gs.settings.get("text_scale", 1.0)) <= 1.0 else 0.84
	check(panel.size.x <= view.x * width_share,
		"[%s] Hinweis nutzt höchstens %.0f %% der Breite: %.0f px" % [locale, width_share * 100.0, panel.size.x])
	var nav: Control = ui._nav
	check(panel.get_global_rect().end.y <= nav.get_global_rect().position.y + 2.0,
		"[%s] Hinweis liegt über der Navigation (Hinweis endet bei %.0f, Navigation beginnt bei %.0f)" % [locale, panel.get_global_rect().end.y, nav.get_global_rect().position.y])
	check(not String(ui._tut_step.text).is_empty(), "[%s] Hinweis nennt den Schritt" % locale)


func check_orders(locale: String) -> void:
	while gs.orders.size() < gs.MAX_ORDERS:
		gs.orders.append(gs.generate_order())
	ui.open_sheet("orders")
	await frames(5)
	check(ui._sheet.visible, "[%s] Auftragsbuch öffnet sich" % locale)
	check(not String(ui._subtitle.text).is_empty(), "[%s] Auftragsbuch hat einen Untertitel" % locale)
	var bar: VScrollBar = ui._scroll.get_v_scroll_bar()
	check(bar.max_value <= bar.page + 1.0,
		"[%s] %d Aufträge passen ohne Scrollen ins Buch (Inhalt %.0f px, Fenster %.0f px)" % [locale, gs.orders.size(), bar.max_value, bar.page])
	var view: Vector2 = ui._layer.size
	for child in ui.content.get_children():
		if child is PanelContainer:
			var card := child as PanelContainer
			check(card.size.y <= view.y * 0.18,
				"[%s] Auftragskarte bleibt eine Zeile hoch: %.0f px von %.0f px" % [locale, card.size.y, view.y])
	check_text(locale, "Auftragsbuch")
	check_overflow(locale, "Auftragsbuch")


func check_sheets(locale: String) -> void:
	var view: Vector2 = ui._layer.size
	for sheet in CHECKED_SHEETS:
		ui.open_sheet(sheet)
		await frames(4)
		check(ui._sheet.visible, "[%s] %s öffnet sich" % [locale, sheet])
		check(ui._sheet.size.y >= view.y * 0.3, "[%s] %s: Sheet hat nutzbare Höhe (%.0f px)" % [locale, sheet, ui._sheet.size.y])
		check(ui._sheet.size.y <= view.y * 0.83, "[%s] %s: Sheet bleibt im Bild (%.0f von %.0f px)" % [locale, sheet, ui._sheet.size.y, view.y])
		check_text(locale, sheet)
		check_overflow(locale, sheet)


func check_toolbar(locale: String) -> void:
	ui.close_sheet()
	await frames(3)
	ui.world.tool_mode = "plant"
	ui._update_toolbar("plant", {"crop": "wheat"})
	await frames(3)
	check(ui._toolbar.visible, "[%s] Werkzeugleiste erscheint beim Werkzeug" % locale)
	var tool_height: float = ui._toolbar.size.y
	ui.open_sheet("orders")
	await frames(3)
	check(not ui._toolbar.visible, "[%s] Werkzeugleiste weicht dem offenen Sheet" % locale)
	check(ui._sheet.get_global_rect().end.y <= ui._nav.get_global_rect().position.y + 2.0,
		"[%s] Sheet endet über der Navigation" % locale)
	ui.close_sheet()
	await frames(3)
	check(ui._toolbar.visible, "[%s] Werkzeugleiste kommt nach dem Schließen zurück" % locale)
	check(ui._toolbar.size.y >= tool_height - 1.0,
		"[%s] Werkzeugleiste hat wieder ihre Höhe (%.0f statt %.0f px)" % [locale, ui._toolbar.size.y, tool_height])
	ui.world.tool_mode = ""
	ui._update_toolbar("", {})
	await frames(2)


func find_button(node: Node, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null


func has_text(node: Node, text: String) -> bool:
	if (node is Label or node is Button) and String(node.get("text")) == text:
		return true
	for child in node.get_children():
		if has_text(child, text):
			return true
	return false


## Die drei Stufen müssen überall greifen: mehr Schrift, höhere Schaltflächen,
## und trotzdem kein gequetschter oder überlaufender Text. Geprüft wird nur über
## die echte Oberfläche und die gespeicherten Werte – UiKit absichtlich nicht, denn
## dieser Test läuft als `-s`-Skript, bevor die Autoloads für den Compiler da sind.
func check_readability(locale: String) -> void:
	ui.close_sheet()
	await frames(3)
	var view: Vector2 = ui._layer.size
	for scale in [0.9, 1.0, 1.2]:
		ui.act_set_text_scale(scale)
		await frames(6)
		check(is_equal_approx(float(gs.settings.get("text_scale", 0.0)), scale),
			"[%s] Schriftstufe %.0f %% landet in den Einstellungen" % [locale, scale * 100.0])
		await check_tutorial(locale)
		ui.open_sheet("orders")
		await frames(5)
		# Der Sheet-Titel ist 36 px im Normalfall und muss mitskalieren.
		var title_size: int = ui._title.get_theme_font_size("font_size")
		check(title_size == maxi(11, roundi(36.0 * float(scale))),
			"[%s] Sheet-Titel nutzt %d px bei %.0f %%" % [locale, title_size, scale * 100.0])
		check(ui._sheet.size.y <= view.y * 0.83,
			"[%s] Auftragsbuch bleibt im Bild bei %.0f %% Schrift (%.0f px)" % [locale, scale * 100.0, ui._sheet.size.y])
		check_text(locale, "Auftragsbuch, Schrift %.0f %%" % (scale * 100.0))
		check_overflow(locale, "Auftragsbuch, Schrift %.0f %%" % (scale * 100.0))
		ui.close_sheet()
		await frames(2)
	# Der Weg über die Oberfläche: Einstellungen öffnen, „Groß“ tippen.
	ui.open_sheet("settings")
	await frames(5)
	check(ui._sheet.size.y <= view.y * 0.83, "[%s] Einstellungen bleiben im Bild" % locale)
	check(has_text(ui.content, I18n.t("Lesbarkeit")), "[%s] Einstellungen zeigen den Bereich Lesbarkeit" % locale)
	check(has_text(ui.content, I18n.t("Schriftgröße")), "[%s] Einstellungen zeigen die Schriftgröße" % locale)
	check_text(locale, "Einstellungen")
	check_overflow(locale, "Einstellungen")
	var big := find_button(ui.content, I18n.t("Groß"))
	check(big != null, "[%s] Einstellungen bieten die große Schrift" % locale)
	if big != null:
		big.emit_signal("pressed")
		await frames(8)
		check(is_equal_approx(float(gs.settings.get("text_scale", 0.0)), 1.2),
			"[%s] Tippen auf „Groß“ vergrößert die Schrift" % locale)
		check(ui._sheet.visible, "[%s] die Einstellungen bleiben nach dem Wechsel offen" % locale)
		check(ui._title.get_theme_font_size("font_size") == maxi(11, roundi(36.0 * 1.2)),
			"[%s] der Titel wächst sofort mit" % locale)
		check_text(locale, "Einstellungen, große Schrift")
		check_overflow(locale, "Einstellungen, große Schrift")
	# Große Schaltflächen: die Navigation wächst mit, ohne über den Rand zu laufen.
	ui.close_sheet()
	await frames(3)
	var normal_nav: float = ui._nav_buttons["shop"].size.y
	ui.act_toggle_accessibility("large_targets")
	await frames(6)
	check(bool(gs.settings.get("large_targets", false)), "[%s] größere Schaltflächen sind eingeschaltet" % locale)
	check(ui._nav_buttons["shop"].size.y >= normal_nav + 4.0,
		"[%s] die Navigation wird höher (%.0f statt %.0f px)" % [locale, ui._nav_buttons["shop"].size.y, normal_nav])
	check(ui._tut_panel.get_global_rect().end.y <= ui._nav.get_global_rect().position.y + 2.0,
		"[%s] der Hinweis bleibt über der höheren Navigation" % locale)
	check_overflow(locale, "große Schaltflächen")
	# Kontrast: die Schrift wird dunkler, die Palette bleibt stimmig.
	ui.open_sheet("orders")
	await frames(4)
	var bright_text: Color = ui._title.get_theme_color("font_color")
	ui.act_toggle_accessibility("high_contrast")
	await frames(8)
	check(bool(gs.settings.get("high_contrast", false)), "[%s] hoher Kontrast ist eingeschaltet" % locale)
	check(ui._title.get_theme_color("font_color").get_luminance() < bright_text.get_luminance(),
		"[%s] hoher Kontrast dunkelt die Schrift ab" % locale)
	check_text(locale, "hoher Kontrast")
	check_overflow(locale, "hoher Kontrast")
	# Zurück auf die Standardwerte, damit die nächste Sprache sauber startet.
	ui.close_sheet()
	await frames(2)
	ui.act_toggle_accessibility("high_contrast")
	ui.act_toggle_accessibility("large_targets")
	ui.act_set_text_scale(1.0)
	await frames(6)
	check(is_equal_approx(float(gs.settings.get("text_scale", 0.0)), 1.0)
		and not bool(gs.settings.get("large_targets", true)) and not bool(gs.settings.get("high_contrast", true)),
		"[%s] die Lesbarkeit lässt sich zurücksetzen" % locale)
	check(absf(ui._nav_buttons["shop"].size.y - normal_nav) <= 1.0,
		"[%s] die Navigation kehrt auf ihre Höhe zurück" % locale)


func _initialize() -> void:
	run()


func run() -> void:
	var save_system: Node = root.get_node("SaveSystem")
	save_system.path_override = "user://layout_ui_save.json"
	save_system.delete_save()
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	ui = main.get_node("UI")
	await frames(6)
	for locale in ["de"] + TRANSLATED:
		I18n.apply(locale)
		ui.relocalize()
		await frames(5)
		await check_tutorial(locale)
		await check_text(locale, "Startbildschirm")
		await check_orders(locale)
		await check_sheets(locale)
		await check_toolbar(locale)
		gs.orders.clear()
	# Die Lesbarkeitsstufen einmal in der längsten und der kürzesten Sprache:
	# Deutsch als Maßstab, Französisch als der Fall, der am ehesten überläuft.
	I18n.apply("de")
	ui.relocalize()
	await frames(5)
	await check_readability("de")
	I18n.apply("fr")
	ui.relocalize()
	await frames(5)
	await check_readability("fr")
	if failures > 0:
		printerr("layout_ui: %d Fehler" % failures)
		quit(1)
		return
	print("layout_ui checked")
	quit(0)
