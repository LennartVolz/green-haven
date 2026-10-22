extends SceneTree
## Prüft die Übersichtlichkeit des Layouts – in allen Sprachen:
## 1. kein Text wird zusammengequetscht (schmaler als sein längstes Wort),
## 2. der Tutorial-Hinweis ist ein Streifen statt einer halben Bildschirmkarte,
## 3. vier Aufträge passen ohne Scrollen ins Auftragsbuch,
## 4. die Werkzeugleiste weicht dem Sheet und kommt danach zurück.

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
	check(tallest <= view.y * 0.18, "[%s] Hinweis bleibt ein Streifen: %.0f von %.0f px" % [locale, tallest, view.y])
	check(panel.size.x <= view.x * 0.74, "[%s] Hinweis nutzt höchstens 74 %% der Breite: %.0f px" % [locale, panel.size.x])
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
	if failures > 0:
		printerr("layout_ui: %d Fehler" % failures)
		quit(1)
		return
	print("layout_ui checked")
	quit(0)
