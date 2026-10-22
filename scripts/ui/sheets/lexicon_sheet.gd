extends RefCounted
## Hoflexikon: alles, was der Hof bisher hervorgebracht hat – Feldfrüchte,
## Rezepte, wilde Funde und Tierarten. Entdecktes zeigt Wert und Herkunft,
## Unbekanntes nur den Hinweis, wo es zu finden ist. Nichts läuft ab, nichts
## muss gesammelt werden; Lücken sind eine Karte, kein Auftrag.

const SECTIONS := [
	{"kind": "crop", "title": "Feldfrüchte", "icon": "leaf"},
	{"kind": "recipe", "title": "Rezepte", "icon": "factory"},
	{"kind": "forage", "title": "Wilde Funde", "icon": "leaf"},
	{"kind": "animal", "title": "Tierarten", "icon": "paw"},
]


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Hoflexikon")
	ui.set_subtitle(I18n.t("Was dein Hof bisher hervorgebracht hat. Lücken sind kein Auftrag – sie zeigen nur, was noch fehlt."))
	var c: VBoxContainer = ui.content
	var total_seen := 0
	var total_all := 0
	for section in SECTIONS:
		var kind := str(section["kind"])
		var progress: Dictionary = GameState.lexicon_progress(kind)
		total_seen += int(progress["seen"])
		total_all += int(progress["total"])
		c.add_child(_head(str(section["title"]), str(section["icon"]), progress))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for id in GameState.lexicon_ids(kind):
			grid.add_child(_entry(kind, str(id)))
		c.add_child(grid)
	var foot := UiKit.label(I18n.t("Zusammen %d von %d entdeckt") % [total_seen, total_all], 26, UiKit.earth_dark())
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(foot)


static func _head(title: String, icon_name: String, progress: Dictionary) -> HBoxContainer:
	var h := UiKit.hbox(10)
	var ic := UiKit.icon(icon_name, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var name_label := UiKit.label(title, 32, UiKit.earth_dark())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_label)
	var count := UiKit.label(I18n.t("%d von %d entdeckt") % [int(progress["seen"]), int(progress["total"])], 24, UiKit.sage_dark())
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count)
	return h


static func _entry(kind: String, id: String) -> PanelContainer:
	var seen := GameState.lexicon_discovered(kind, id)
	var definition := _definition(kind, id)
	var card := UiKit.card(10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UiKit.hbox(12)
	var preview := _preview(kind, id, seen)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(preview)
	var v := UiKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Unbekanntes verrät nur, dass es existiert – der Name kommt mit der Entdeckung.
	var title := UiKit.label(String(definition.get("name", id)) if seen else "???", 28, UiKit.ink() if seen else UiKit.earth_dark())
	v.add_child(title)
	var hint := _hint(kind, id, definition, seen)
	if hint != "":
		v.add_child(UiKit.wrap_label(hint, 21, UiKit.earth_dark()))
	h.add_child(v)
	var mark := UiKit.icon("star" if seen else "lock", 32)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mark)
	card.add_child(h)
	return card


## Tiere zeigen ihre Zeichnung erst, wenn sie schon einmal hier gelebt haben;
## vorher bleibt nur die Pfote. Pflanzen und Gerichte sind als Silhouette zu sehen.
static func _preview(kind: String, id: String, seen: bool) -> Control:
	if kind == "animal":
		if not seen:
			var paw := UiKit.icon("paw", 64)
			paw.modulate.a = 0.4
			return paw
		var pv := ObjPreview.new()
		pv.setup("animal", id, [])
		pv.custom_minimum_size = Vector2(84, 84)
		return pv
	var item := UiKit.item_icon(id, 64)
	item.dim = not seen
	return item


static func _hint(kind: String, id: String, definition: Dictionary, seen: bool) -> String:
	var level := int(definition.get("level", 1))
	if not seen:
		if kind == "forage":
			return I18n.t("Wächst wild ab Stufe %d") % level
		return I18n.t("Ab Stufe %d") % level
	match kind:
		"crop", "forage":
			return I18n.t("%d pro Stück") % int(definition.get("sell", 0))
		"recipe":
			var parts: Array = []
			var building_id := str(definition.get("building", ""))
			var building := str(GameData.BUILDINGS.get(building_id, {}).get("name", ""))
			if building != "":
				parts.append(building)
			var inputs: Dictionary = definition.get("inputs", {})
			var ingredients: Array = []
			for input in inputs:
				ingredients.append("%s ×%d" % [GameData.item_name(str(input)), int(inputs[input])])
			if not ingredients.is_empty():
				parts.append(" · ".join(ingredients))
			return " · ".join(parts)
		"animal":
			var traits: Array = []
			for trait_id in definition.get("traits", []):
				var entry: Dictionary = GameData.ANIMAL_TRAITS.get(str(trait_id), {})
				if entry.has("name"):
					traits.append(str(entry["name"]))
			return " · ".join(traits)
	return ""


static func _definition(kind: String, id: String) -> Dictionary:
	match kind:
		"crop":
			return GameData.CROPS.get(id, {})
		"recipe":
			return GameData.RECIPES.get(id, {})
		"forage":
			return GameData.FORAGE.get(id, {})
		"animal":
			return GameData.ANIMALS.get(id, {})
	return {}
