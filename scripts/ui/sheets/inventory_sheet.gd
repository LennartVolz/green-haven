extends RefCounted
## Vorratskammer: alle Feldfrüchte, Zutaten und Produkte, direkt verkaufbar.


static func _order_key(id: String) -> String:
	var kind: String = GameData.items[id]["kind"]
	var rank := "1"
	if kind == "extra":
		rank = "2"
	elif kind == "product":
		rank = "3"
	return rank + String(GameData.items[id]["name"])


static func build(ui, _args: Dictionary) -> void:
	ui.set_title("Vorratskammer")
	var c: VBoxContainer = ui.content
	var ids: Array = GameState.inventory.keys()
	if ids.is_empty():
		c.add_child(UiKit.wrap_label("Hier ist noch nichts. Ernte Pflanzen auf deinen Feldern oder stelle Produkte in den Gebäuden her!", 32))
		return
	ids.sort_custom(func(a: String, b: String) -> bool: return _order_key(a) < _order_key(b))
	var total := 0
	for id in ids:
		total += int(GameState.inventory[id]) * int(GameData.items[id]["sell"])
		var n: int = GameState.item_count(id)
		var price: int = GameData.items[id]["sell"]
		var card := UiKit.card(12)
		var h := UiKit.hbox(14)
		h.add_child(UiKit.item_icon(id, 84))
		var v := UiKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiKit.label("%s ×%d" % [GameData.item_name(id), n], 34))
		v.add_child(UiKit.icon_text("coin", "%d pro Stück" % price, 26))
		h.add_child(v)
		var b1 := UiKit.button("1×  +%d" % price, "warm", 28)
		b1.custom_minimum_size = Vector2(190, 96)
		b1.pressed.connect(ui.act_sell.bind(id, 1))
		h.add_child(b1)
		if n > 1:
			var b2 := UiKit.button("Alle  +%d" % (price * n), "primary", 28)
			b2.custom_minimum_size = Vector2(230, 96)
			b2.pressed.connect(ui.act_sell.bind(id, n))
			h.add_child(b2)
		card.add_child(h)
		c.add_child(card)
	var foot := UiKit.label("Gesamtwert des Vorrats: %d Münzen" % total, 26, UiKit.earth_dark())
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(foot)
