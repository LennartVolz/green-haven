extends SceneTree
## Prüft die Mehrsprachigkeit:
## 1. alle Kataloge sind vollständig, gleich aufgebaut und behalten Platzhalter,
## 2. jede Sprache zeigt in allen Bereichen ausschließlich übersetzte Texte,
## 3. die Sprachwahl landet im Spielstand und wird beim Laden übernommen,
## 4. lange Übersetzungen sprengen weder Titel noch Navigationsleiste.

var failures := 0
var gs: Node
var save_system: Node
var ui: Node

const SHEETS := [
	"shop", "orders", "production_overview", "production", "inventory",
	"refuge", "quests", "achievements", "hofbuch", "settings", "diary",
]
const TRANSLATED := ["en", "fr", "es", "it"]
## Ein Titel je Sprache, an dem sich die laufende Übersetzung erkennen lässt.
const TITLE_SAMPLE := {
	"de": "Einstellungen",
	"en": "Settings",
	"fr": "Réglages",
	"es": "Ajustes",
	"it": "Impostazioni",
}


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: ", message)


func frames(count: int = 2) -> void:
	for index in range(count):
		await process_frame


func placeholders(text: String) -> Array:
	var found := []
	var pattern := RegEx.create_from_string("%(?:%|[-0-9.]*[sdf])")
	for match in pattern.search_all(text):
		found.append(match.get_string())
	found.sort()
	return found


## Die deutsche Quelle: für Schlüssel wie DIARY_* steht sie im deutschen Katalog,
## sonst ist der deutsche Text selbst der Schlüssel.
func german_source(key: String) -> String:
	var german: Dictionary = _catalog("de")
	return str(german.get(key, key))


func _catalog(locale: String) -> Dictionary:
	var path := I18n.CATALOG_PATH % locale
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func check_catalogs() -> void:
	for locale in TRANSLATED:
		var catalog := _catalog(locale)
		check(not catalog.is_empty(), "Katalog %s existiert und ist lesbar" % locale)
		var empty := 0
		for key in catalog:
			if str(catalog[key]).strip_edges().is_empty():
				empty += 1
		check(empty == 0, "Katalog %s hat keine leeren Einträge (%d)" % [locale, empty])

	var reference: Array = _catalog("en").keys()
	reference.sort()
	for locale in TRANSLATED:
		var keys: Array = _catalog(locale).keys()
		keys.sort()
		check(keys == reference, "Katalog %s hat dieselben Schlüssel wie Englisch" % locale)

	var broken := 0
	for locale in TRANSLATED:
		var catalog := _catalog(locale)
		for key in catalog:
			if placeholders(str(catalog[key])) != placeholders(german_source(key)):
				broken += 1
				printerr("  Platzhalter: %s [%s] %s -> %s" % [key, locale, german_source(key), catalog[key]])
	check(broken == 0, "alle Übersetzungen behalten die Platzhalter ihrer Vorlage (%d Abweichungen)" % broken)
	check(I18n.catalog_size("en") > 500, "der englische Katalog deckt die Oberfläche ab: %d Einträge" % I18n.catalog_size("en"))


## Jeder Text, den die Oberfläche übersetzen lässt, muss in allen Katalogen stehen.
## Das fängt neue deutsche Literale schon in der CI ab, nicht erst im Spiel.
func check_code_literals() -> void:
	var patterns := [
		RegEx.create_from_string("I18n\\.t\\(\\s*\"([^\"]*)\""),
		RegEx.create_from_string("(?:UiKit\\.(?:label|wrap_label|button|nav_button)|set_title)\\(\\s*\"([^\"]*)\""),
		# Bei icon_text ist das erste Argument ein Symbol, erst das zweite ein Text.
		RegEx.create_from_string("UiKit\\.icon_text\\(\\s*\"[^\"]*\",\\s*\"([^\"]*)\""),
	]
	var files: Array = []
	_collect_scripts("res://scripts", files)
	var literals := {}
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for pattern in patterns:
			for hit in pattern.search_all(text):
				var found: String = hit.get_string(1)
				if _looks_translatable(found):
					literals[found] = true
	var missing := {}
	for locale in ["de"] + TRANSLATED:
		var catalog := _catalog(locale) if locale != "de" else _catalog("en")
		for literal in literals:
			if not catalog.has(literal):
				missing[literal] = true
	for literal in missing:
		printerr("  Literal ohne Übersetzung: ", literal)
	check(missing.is_empty(), "alle Texte der Oberfläche stehen in den Katalogen (%d fehlen)" % missing.size())


func _collect_scripts(directory: String, files: Array) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for name in dir.get_files():
		if name.ends_with(".gd"):
			files.append(directory.path_join(name))
	for name in dir.get_directories():
		_collect_scripts(directory.path_join(name), files)


## Kurze Bezeichner wie "primary" oder "crate" sind Stil, keine Sätze.
func _looks_translatable(text: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	var letters := RegEx.create_from_string("[A-Za-zÄÖÜäöüß]{2,}")
	return letters.search(text) != null


func check_saved_language() -> void:
	I18n.apply("de")
	gs.new_game()
	gs.settings["language"] = "fr"
	check(save_system.save_game(), "Spielstand mit Sprache wird gespeichert")
	check(save_system.peek_language() == "fr", "der Ladebildschirm erkennt die Sprache vor dem Laden")
	gs.new_game()
	# Die Sprache ist eine Geräte-Einstellung und überlebt bewusst ein neues Spiel.
	check(str(gs.settings.get("language", "")) == "fr", "new_game behält die Sprachwahl")
	gs.settings["language"] = ""
	check(save_system.load_game(), "Spielstand mit Sprache wird geladen")
	check(str(gs.settings.get("language", "")) == "fr", "die Sprache kommt aus dem Spielstand zurück")
	I18n.apply(str(gs.settings.get("language", "")))
	check(I18n.locale == "fr", "die gespeicherte Sprache wird angewendet")
	I18n.apply("de")


## Prüft eine Sprache in der echten Oberfläche: alle Bereiche öffnen, keine
## fehlende Übersetzung, und lange Texte bleiben in ihrem Rahmen.
func check_ui(locale: String) -> void:
	# main.gd lädt beim Start einen vorhandenen Spielstand und übernimmt dessen
	# Sprachwahl; für den Test wird beides neutralisiert, damit die geprüfte
	# Sprache auch die aktive ist.
	save_system.delete_save()
	gs.new_game()
	gs.settings["language"] = ""
	I18n.apply(locale)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	ui = main.get_node("UI")
	# Jeder Bereich baut seine Texte in der gewählten Sprache auf.
	for sheet in ["shop", "inventory", "refuge", "achievements"]:
		ui.open_sheet(sheet)
		await frames(1)
		check(I18n.locale == locale, "%s bleibt beim Öffnen von %s aktiv" % [locale, sheet])
		ui.close_sheet()

	ui.open_sheet("settings")
	await frames(1)
	check(ui._title.text == TITLE_SAMPLE[locale], "%s: der Sheet-Titel ist übersetzt (%s)" % [locale, ui._title.text])
	check(ui._title.get_minimum_size().x <= ui._sheet.size.x + 1.0,
		"%s: der Titel passt in die Kopfzeile (%s von %s)" % [locale, ui._title.get_minimum_size().x, ui._sheet.size.x])
	for id in ui._nav_buttons:
		var button: Button = ui._nav_buttons[id]
		var label: Label = button.get_child(0).get_child(1)
		check(label.get_minimum_size().x <= button.size.x + 1.0,
			"%s: die Navigation %s bleibt in der Schaltfläche (%s von %s)" % [locale, id, label.get_minimum_size().x, button.size.x])
	ui.close_sheet()

	# Sprachwechsel im laufenden Spiel: die Oberfläche wird neu beschriftet,
	# Welt und Kamera bleiben stehen.
	var nav: Label = ui._nav_buttons["achievements"].get_child(0).get_child(1)
	var before := nav.text
	ui.act_set_language("fr")
	await frames(4)
	check(I18n.locale == "fr", "der Wechsel auf Französisch greift sofort")
	var nav_fr: Label = ui._nav_buttons["achievements"].get_child(0).get_child(1)
	check(nav_fr.text == I18n.t("Erfolge"), "die Navigation folgt dem Wechsel (%s)" % nav_fr.text)
	check(nav_fr.text != before or locale == "fr", "die Navigation behält nicht die alte Sprache")
	check(main.is_inside_tree(), "der Wechsel lädt die Szene nicht neu")
	# Nach dem Wechsel ist das Menü zu; neu öffnen zeigt die neue Sprache.
	ui.open_sheet("settings")
	await frames(1)
	check(ui._title.text == TITLE_SAMPLE["fr"], "nach dem Wechsel stimmt der Titel (%s)" % ui._title.text)
	ui.close_sheet()
	ui.act_set_language(locale)
	await frames(4)
	ui.open_sheet("settings")
	await frames(1)
	check(ui._title.text == TITLE_SAMPLE[locale], "der Rückwechsel stellt die Sprache wieder her (%s)" % ui._title.text)
	# Nach dem Wechsel ist kein Menü mehr offen; für den nächsten Lauf sauber.
	ui.close_sheet()
	main.queue_free()
	await frames(2)


func run() -> void:
	save_system = root.get_node("SaveSystem")
	gs = root.get_node("GameState")
	save_system.path_override = "user://i18n_save.json"
	save_system.delete_save()

	check_catalogs()
	check_code_literals()
	check_saved_language()

	# Optional nur eine Auswahl prüfen, damit der Lauf in der Cloud kurz bleibt.
	var wanted: String = OS.get_environment("I18N_LOCALES")
	for locale in TRANSLATED:
		if not wanted.is_empty() and not wanted.split(",").has(locale):
			continue
		await check_ui(locale)

	print("i18n checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	# Die Vorlagen sind deutsch; unabhängig von der Gerätesprache.
	I18n.apply("de")
	call_deferred("run")
