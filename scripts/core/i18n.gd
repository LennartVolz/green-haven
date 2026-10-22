class_name I18n
extends RefCounted
## Mehrsprachigkeit für Green Haven.
##
## Der deutsche Text im Quellcode ist der Schlüssel (gettext-Prinzip): Steht in
## einem Menü `I18n.t("Vorrat")`, liefert das den Eintrag aus
## res://locale/<sprache>.json – oder, wenn dort keiner existiert, den deutschen
## Text selbst. Eine fehlende Übersetzung ist damit nie ein Fehler, sondern
## höchstens eine gemischte Sprache.
##
## Bewusst eine statische Klasse statt eines Autoloads: So ist `I18n.t()` auch in
## `RefCounted`-Sheets und in `-s`-Testläufen verfügbar, wo Autoload-Namen beim
## Kompilieren nicht aufgelöst werden.

## Reihenfolge = Reihenfolge in den Einstellungen.
const LOCALES := [
	{"id": "de", "name": "Deutsch"},
	{"id": "en", "name": "English"},
	{"id": "fr", "name": "Français"},
	{"id": "es", "name": "Español"},
	{"id": "it", "name": "Italiano"},
]
## Leerer Eintrag bedeutet: der Gerätesprache folgen.
const AUTO := ""
const CATALOG_PATH := "res://locale/%s.json"
## Rückfall für Geräte, deren Sprache wir nicht anbieten (z. B. Japanisch).
const DEVICE_FALLBACK := "en"

static var locale := "de"
static var missing: Dictionary = {}   ## msgid -> Anzahl fehlender Übersetzungen
static var _catalogs := {}
static var _registered := {}
static var _loaded := false


## Lädt die Kataloge beim ersten Zugriff und übernimmt die Gerätesprache.
static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for entry in LOCALES:
		var id := str(entry["id"])
		_catalogs[id] = _read_catalog(id)
	_set_locale(resolve(AUTO), false)


static func _read_catalog(id: String) -> Dictionary:
	var path := CATALOG_PATH % id
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Übersetzungskatalog %s ist kein JSON-Objekt" % path)
		return {}
	var out := {}
	for key in parsed:
		var value: Variant = parsed[key]
		if typeof(value) == TYPE_STRING and not str(value).is_empty():
			out[str(key)] = str(value)
	return out


## Setzt die Sprache und baut die Datentabellen neu auf. `preference` ist eine
## Sprach-ID oder AUTO für die Gerätesprache.
static func apply(preference: String) -> String:
	_ensure()
	_set_locale(resolve(preference), true)
	return locale


static func _set_locale(next: String, refresh_tables: bool) -> void:
	locale = next
	missing.clear()
	TranslationServer.set_locale(next)
	if not _registered.has(next):
		_register(next)
	if refresh_tables:
		_refresh_tables()


static func _refresh_tables() -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	var game_data: Variant = loop.root.get_node_or_null("GameData") if loop is SceneTree else null
	if game_data != null and game_data.has_method("refresh_locale"):
		game_data.call("refresh_locale")


## Die Übersetzungen zusätzlich als Translation anmelden, damit auch Godots
## eigenes tr() und TranslationServer.get_locale() dieselbe Sprache sehen.
static func _register(id: String) -> void:
	var catalog: Dictionary = _catalogs.get(id, {})
	var translation := Translation.new()
	translation.locale = id
	for key in catalog:
		translation.add_message(key, str(catalog[key]))
	TranslationServer.add_translation(translation)
	_registered[id] = true


## Sprach-ID aus einer gespeicherten Einstellung; unbekannte Werte fallen auf die
## Gerätesprache zurück.
static func resolve(preference: String) -> String:
	if preference != AUTO and has_locale(preference):
		return preference
	var language := OS.get_locale_language()
	if has_locale(language):
		return language
	var full := OS.get_locale()
	if has_locale(full):
		return full
	return DEVICE_FALLBACK


static func has_locale(id: String) -> bool:
	for entry in LOCALES:
		if str(entry["id"]) == id:
			return true
	return false


## Anzeigename einer Sprache, z. B. für die Einstellungen.
static func locale_name(id: String) -> String:
	for entry in LOCALES:
		if str(entry["id"]) == id:
			return str(entry["name"])
	return id


## Übersetzt einen deutschen Text. Unbekannte Texte bleiben unverändert deutsch.
static func t(msg: String) -> String:
	_ensure()
	if msg.is_empty():
		return msg
	# Auch Deutsch hat einen Katalog: Schlüssel wie DIARY_RESCUE_HOME brauchen ihn,
	# und einzelne Texte lassen sich dort gezielt überarbeiten.
	var catalog: Dictionary = _catalogs.get(locale, {})
	if catalog.has(msg):
		return str(catalog[msg])
	if locale == "de":
		return msg
	if _is_translatable(msg):
		missing[msg] = int(missing.get(msg, 0)) + 1
	return msg


## Nur echte Sätze für die Diagnose zählen, keine Bezeichner oder Farben.
## Sätze erkennt man am Leerzeichen; Einzelwörter nur, wenn sie groß
## beginnen („Weizen"). Kleingeschriebene IDs wie „wheat" oder „q_harvest10"
## sind Verweise und werden nie übersetzt.
static func _is_translatable(msg: String) -> bool:
	if msg.begins_with("#"):
		return false
	if msg.contains(" ") or msg.contains("\n"):
		return true
	var first := msg.substr(0, 1)
	return not first.is_empty() and first != first.to_lower()


## Pluralform: `one` gilt für genau eins (im Französischen auch für null),
## `other` für alles andere. Beide Formen sind vollständige Sätze.
static func tn(one: String, other: String, n: int) -> String:
	return t(one) if plural_is_one(n) else t(other)


static func plural_is_one(n: int) -> bool:
	if locale == "fr":
		return n <= 1
	return n == 1


## Anzahl der Katalog-Einträge einer Sprache – für Tests und Diagnose.
static func catalog_size(id: String) -> int:
	_ensure()
	return (_catalogs.get(id, {}) as Dictionary).size()


static func catalog_keys(id: String) -> Array:
	_ensure()
	return (_catalogs.get(id, {}) as Dictionary).keys()


## Setzt die internen Zustände zurück (nur für Tests).
static func reset_cache() -> void:
	_loaded = false
	_catalogs = {}
	_registered = {}
	missing = {}
	locale = "de"
