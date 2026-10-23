extends SceneTree
## Hilfswerkzeug für die Übersetzungspflege:
## öffnet jeden Bereich in jeder Sprache und schreibt die fehlenden Schlüssel
## nach res://locale/_missing.json. Nicht Teil des Spiels, nicht in der CI.
##
## Aufruf: godot --headless --path . -s res://tools/dump_i18n.gd

const SHEETS := [
	"shop", "orders", "production_overview", "production", "inventory",
	"refuge", "quests", "achievements", "hofbuch", "lexicon", "settings", "diary", "excursion",
	"letters", "photo",
]


func frames(count: int = 2) -> void:
	for i in range(count):
		await process_frame


func collect_data() -> void:
	var gd: Variant = root.get_node_or_null("GameData")
	if gd == null:
		return
	for table in ["SEASONS", "SEASON_GOALS", "HOFBUCH", "CROPS", "FORAGE", "EXTRA_ITEMS",
			"BUILDINGS", "RECIPES", "DECOS", "ANIMALS", "COSMETICS", "QUESTS",
			"ACHIEVEMENTS", "HOFRANKS", "ANIMAL_TRAITS", "ANIMAL_ACTIVITIES", "FRIENDSHIP_STORIES", "EXCURSIONS", "NEIGHBORS",
			"DELIVERY_STORIES", "NEIGHBORHOOD_EVENT_STAGES", "NEIGHBORHOOD_EVENT_STORIES",
			"CAFE_VISITOR_STORIES"]:
		walk(gd.get(table))


func walk(value: Variant) -> void:
	if typeof(value) == TYPE_STRING:
		I18n.t(str(value))
	elif typeof(value) == TYPE_ARRAY:
		for entry in value:
			walk(entry)
	elif typeof(value) == TYPE_DICTIONARY:
		for key in value:
			walk(value[key])


## Alle Texte, die im Quellcode als Zeichenkette stehen. Nur die sind echte
## Schlüssel; zusammengesetzte Anzeigen („0/3  Wheat") meldet I18n zwar auch als
## fehlend, sind aber schon übersetzt und würden die Liste nur verwässern.
func source_literals() -> Dictionary:
	var patterns := [
		RegEx.create_from_string("I18n\\.t\\(\\s*\"([^\"]*)\""),
		RegEx.create_from_string("(?:UiKit\\.(?:label|wrap_label|button|nav_button)|set_title|set_subtitle)\\(\\s*\"([^\"]*)\""),
		RegEx.create_from_string("UiKit\\.icon_text\\(\\s*\"[^\"]*\",\\s*\"([^\"]*)\""),
		# Deutsche Datennamen stehen als Tabellenwerte im Quelltext.
		RegEx.create_from_string("\"name\": \"([^\"]*)\""),
	]
	var found := {}
	var files: Array = []
	_collect("res://scripts", files)
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for pattern in patterns:
			for hit in pattern.search_all(text):
				found[hit.get_string(1)] = true
	return found


func _collect(directory: String, files: Array) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for name in dir.get_files():
		if name.ends_with(".gd"):
			files.append(directory.path_join(name))
	for name in dir.get_directories():
		_collect(directory.path_join(name), files)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.new_game()
	var literals := source_literals()
	var result := {}
	for locale in ["de", "en", "fr", "es", "it"]:
		I18n.apply(locale)
		I18n.missing.clear()
		collect_data()
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await frames(4)
		var ui: Node = main.get_node("UI")
		for sheet in SHEETS:
			ui.open_sheet(sheet)
			await frames(1)
			ui.close_sheet()
		main.queue_free()
		await frames(2)
		var keys: Array = []
		for key in I18n.missing:
			if literals.has(key):
				keys.append(key)
		keys.sort()
		result[locale] = keys
		print("%s: %d fehlende Texte" % [locale, keys.size()])
	var file := FileAccess.open("res://locale/_missing.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("geschrieben: res://locale/_missing.json")
	quit()
