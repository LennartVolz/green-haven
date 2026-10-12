extends CanvasLayer
## Gesamte Benutzeroberfläche: HUD, Navigation, Bottom-Sheets, Werkzeugleiste,
## Tutorial, Hinweise und Popups. Enthält alle Aktionen, die Buttons auslösen.
## Die Spiellogik selbst liegt in GameState.

const InventorySheet := preload("res://scripts/ui/sheets/inventory_sheet.gd")
const ShopSheet := preload("res://scripts/ui/sheets/shop_sheet.gd")
const OrdersSheet := preload("res://scripts/ui/sheets/orders_sheet.gd")
const QuestsSheet := preload("res://scripts/ui/sheets/quests_sheet.gd")
const SettingsSheet := preload("res://scripts/ui/sheets/settings_sheet.gd")
const CropsSheet := preload("res://scripts/ui/sheets/crops_sheet.gd")
const ProductionSheet := preload("res://scripts/ui/sheets/production_sheet.gd")
const RefugeSheet := preload("res://scripts/ui/sheets/refuge_sheet.gd")
const AnimalSheet := preload("res://scripts/ui/sheets/animal_sheet.gd")

const TUTORIAL := [
	"Willkommen auf Green Haven! Tippe auf ein leeres Feld und wähle Weizen.",
	"Prima! Wähle eine Sorte und wische mit dem Finger über mehrere Felder, um schnell zu säen.",
	"Warte, bis der Weizen reif ist (ca. 30 Sekunden). Tippe oder wische dann über die Pflanzen, um zu ernten.",
	"Öffne unten das Auftragsbuch und erfülle deinen ersten Kundenauftrag.",
	"Gut gemacht! Verkaufe Überschüsse im Vorrat, baue ab Stufe 2 eine Bäckerei und rette später Tiere. Mit einem Finger verschiebst du die Kamera, mit zwei zoomst du.",
]
const TUTORIAL_DONE := 99

var world: Node2D
var content: VBoxContainer
var state: Dictionary = {}
var ticker: Array = []

var _layer: Control
var _safe: MarginContainer
var _top: PanelContainer
var _bottom: VBoxContainer
var _sheet: PanelContainer
var _scroll: ScrollContainer
var _title: Label
var _toolbar: PanelContainer
var _nav: PanelContainer
var _side: VBoxContainer
var _coins_label: Label
var _day_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _tut_panel: PanelContainer
var _tut_label: Label
var _tut_button: Button
var _modal: Control
var _nav_buttons: Dictionary = {}
var _sheet_name := ""
var _sheet_args: Dictionary = {}
var _refresh_queued := false
var _tick_acc := 0.0
var _coin_shown := -1.0
var _displayed_coins := 0.0
var _modal_queue: Array = []


func _ready() -> void:
	world = get_parent().get_node("World")
	_build()
	world.ui_blocker = Callable(self, "is_over_ui")
	world.open_sheet.connect(open_sheet)
	world.close_sheets.connect(close_sheet)
	world.tool_changed.connect(_on_tool_changed)
	GameState.coins_changed.connect(_on_coins)
	GameState.xp_changed.connect(_on_xp)
	GameState.level_up.connect(_on_level_up)
	GameState.toast.connect(show_toast)
	GameState.inventory_changed.connect(_on_state_changed)
	GameState.world_changed.connect(_on_state_changed)
	GameState.orders_changed.connect(_on_state_changed)
	GameState.animals_changed.connect(_on_state_changed)
	GameState.quests_changed.connect(_on_state_changed)
	GameState.coins_changed.connect(_on_state_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_displayed_coins = float(GameState.coins)
	_on_coins()
	_on_xp()
	_update_badges()
	_update_tutorial()
	_update_toolbar("", {})
	call_deferred("_show_welcome_back")


# ------------------------------------------------------------------ Aufbau

func _build() -> void:
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe = MarginContainer.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.add_child(_layer)
	_apply_safe_area()
	_build_top()
	_build_side()
	_build_tutorial()
	_build_toast()
	_build_bottom()


func _apply_safe_area() -> void:
	var l := 6
	var t := 6
	var r := 6
	var b := 6
	if OS.has_feature("mobile"):
		var area := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		var vp := get_viewport().get_visible_rect().size
		if win.x > 0 and win.y > 0:
			var sx := vp.x / float(win.x)
			var sy := vp.y / float(win.y)
			l += int(maxf(0.0, float(area.position.x)) * sx)
			t += int(maxf(0.0, float(area.position.y)) * sy)
			r += int(maxf(0.0, float(win.x - area.end.x)) * sx)
			b += int(maxf(0.0, float(win.y - area.end.y)) * sy)
	_safe.add_theme_constant_override("margin_left", l)
	_safe.add_theme_constant_override("margin_top", t)
	_safe.add_theme_constant_override("margin_right", r)
	_safe.add_theme_constant_override("margin_bottom", b)


func _build_top() -> void:
	_top = UiKit.panel(UiKit.sage(), 34, 14, UiKit.sage_dark(), 0, 10)
	_layer.add_child(_top)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.custom_minimum_size = Vector2(0, 124)
	var h := UiKit.hbox(18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var star := UiKit.icon("star", 76)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(star)
	var lv := UiKit.vbox(4)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_label = UiKit.label("Stufe 1", 34, UiKit.cream())
	lv.add_child(_level_label)
	_xp_bar = UiKit.progress(0.0, UiKit.yellow(), 22)
	_xp_bar.custom_minimum_size = Vector2(250, 22)
	_xp_bar.size_flags_horizontal = Control.SIZE_FILL
	lv.add_child(_xp_bar)
	h.add_child(lv)
	var day_panel := UiKit.panel(Color(0, 0, 0, 0.16), 24, 10)
	_day_label = UiKit.label("08:00 · Tag", 27, UiKit.cream())
	_day_label.custom_minimum_size = Vector2(190, 0)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_panel.add_child(_day_label)
	h.add_child(day_panel)
	h.add_child(UiKit.spacer())
	var cp := UiKit.panel(Color(0, 0, 0, 0.2), 30, 10)
	var ch := UiKit.hbox(10)
	ch.add_child(UiKit.icon("coin", 54))
	_coins_label = UiKit.label("0", 40, UiKit.cream())
	_coins_label.custom_minimum_size = Vector2(110, 0)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ch.add_child(_coins_label)
	cp.add_child(ch)
	h.add_child(cp)
	var gear := UiKit.icon_button("gear", "light", 84)
	gear.pressed.connect(act_open.bind("settings", {}))
	h.add_child(gear)
	_top.add_child(h)


func _build_side() -> void:
	_side = UiKit.vbox(14)
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_side)
	_side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_side.position += Vector2(0, 150)
	var till := UiKit.icon_button("plus", "warm", 96)
	till.pressed.connect(act_till)
	_side.add_child(till)
	var edit := UiKit.icon_button("hammer", "light", 96)
	edit.pressed.connect(act_edit)
	_side.add_child(edit)


func _build_tutorial() -> void:
	_tut_panel = UiKit.panel(UiKit.cream(), 28, 16, UiKit.yellow(), 4, 8)
	_layer.add_child(_tut_panel)
	_tut_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tut_panel.offset_top = 150
	_tut_panel.offset_right = -120
	var v := UiKit.vbox(8)
	_tut_label = UiKit.wrap_label("", 28)
	v.add_child(_tut_label)
	var row := UiKit.hbox(10)
	row.add_child(UiKit.spacer())
	var skip := UiKit.button("Überspringen", "ghost", 24)
	skip.custom_minimum_size = Vector2(0, 64)
	skip.pressed.connect(_tutorial_skip)
	row.add_child(skip)
	_tut_button = UiKit.button("Verstanden", "warm", 26)
	_tut_button.custom_minimum_size = Vector2(200, 64)
	_tut_button.pressed.connect(_tutorial_skip)
	row.add_child(_tut_button)
	v.add_child(row)
	_tut_panel.add_child(v)


func _build_toast() -> void:
	_toast_panel = UiKit.panel(UiKit.cream(), 28, 14, UiKit.sage_dark(), 3, 8)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_toast_panel)
	_toast_label = UiKit.label("", 30)
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position.y = 420.0


func _build_bottom() -> void:
	_bottom = VBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 8)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bottom)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Sheet
	var sb := UiKit.style(UiKit.cream(), 40, UiKit.cream_dark(), 4, 14, 18)
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", sb)
	_sheet.visible = false
	var sv := UiKit.vbox(10)
	var head := UiKit.hbox(12)
	_title = UiKit.label("", 42)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := UiKit.icon_button("close", "danger", 84)
	close.pressed.connect(close_sheet)
	head.add_child(close)
	sv.add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 24
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 760)
	content = UiKit.vbox(14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	sv.add_child(_scroll)
	_sheet.add_child(sv)
	_bottom.add_child(_sheet)
	# Werkzeugleiste
	_toolbar = UiKit.panel(UiKit.cream(), 34, 14, UiKit.yellow(), 4, 10)
	_toolbar.visible = false
	_bottom.add_child(_toolbar)
	# Navigation
	_nav = UiKit.panel(UiKit.sage(), 40, 10, UiKit.sage_dark(), 0, 10)
	var nh := UiKit.hbox(8)
	var defs := [
		["shop", "shop", "Shop"],
		["orders", "scroll", "Aufträge"],
		["inventory", "crate", "Vorrat"],
		["refuge", "paw", "Refugium"],
		["quests", "flag", "Ziele"],
	]
	for d in defs:
		var b := UiKit.nav_button(d[1], d[2], 120, 130)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_nav_pressed.bind(d[0]))
		nh.add_child(b)
		_nav_buttons[d[0]] = b
	_nav.add_child(nh)
	_bottom.add_child(_nav)


# --------------------------------------------------------------- Blockierung

func is_over_ui(p: Vector2) -> bool:
	if _modal != null and _modal.visible:
		return true
	for c in [_top, _side, _sheet, _toolbar, _nav, _tut_panel]:
		var ctrl := c as Control
		if ctrl != null and ctrl.is_visible_in_tree() and ctrl.get_global_rect().has_point(p):
			return true
	return false


# ---------------------------------------------------------------- Sheets

func set_title(text: String) -> void:
	_title.text = text


func set_state(key: String, value: Variant) -> void:
	state[key] = value
	refresh_sheet()


func open_sheet(sheet_name: String, args: Dictionary = {}) -> void:
	_sheet_name = sheet_name
	_sheet_args = args
	_sheet.visible = true
	_toolbar.visible = false if world.tool_mode == "" else _toolbar.visible
	_scroll.scroll_vertical = 0
	_rebuild()
	_update_nav_highlight()


func close_sheet() -> void:
	_sheet_name = ""
	_sheet.visible = false
	ticker.clear()
	_update_nav_highlight()


func refresh_sheet() -> void:
	if _sheet_name == "":
		return
	var keep := _scroll.scroll_vertical
	_rebuild()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep


func _rebuild() -> void:
	ticker.clear()
	for ch in content.get_children():
		content.remove_child(ch)
		ch.queue_free()
	match _sheet_name:
		"inventory":
			InventorySheet.build(self, _sheet_args)
		"shop":
			ShopSheet.build(self, _sheet_args)
		"orders":
			OrdersSheet.build(self, _sheet_args)
		"quests":
			QuestsSheet.build(self, _sheet_args)
		"settings":
			SettingsSheet.build(self, _sheet_args)
		"crops":
			CropsSheet.build(self, _sheet_args)
		"production":
			ProductionSheet.build(self, _sheet_args)
		"refuge":
			RefugeSheet.build(self, _sheet_args)
		"animal":
			AnimalSheet.build(self, _sheet_args)
	_tick()


func _on_state_changed() -> void:
	_update_badges()
	_update_tutorial()
	if _sheet_name == "" or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_do_refresh")


func _do_refresh() -> void:
	_refresh_queued = false
	refresh_sheet()


func _tick() -> void:
	for f in ticker:
		(f as Callable).call()


func _process(delta: float) -> void:
	_tick_acc += delta
	if _tick_acc >= 0.25:
		_tick_acc = 0.0
		_day_label.text = world.day_clock_text()
		if _sheet_name != "":
			_tick()
	# Münzanzeige zählt sanft hoch
	var target := float(GameState.coins)
	if absf(_displayed_coins - target) > 0.5:
		_displayed_coins = lerpf(_displayed_coins, target, clampf(delta * 10.0, 0.0, 1.0))
		if absf(_displayed_coins - target) < 1.0:
			_displayed_coins = target
		_coins_label.text = str(int(round(_displayed_coins)))


func _nav_pressed(sheet_name: String) -> void:
	GameState.sound.emit("tap")
	if world.tool_mode != "":
		world.clear_tool()
	if _sheet_name == sheet_name:
		close_sheet()
		return
	open_sheet(sheet_name, {})


func _update_nav_highlight() -> void:
	for k in _nav_buttons:
		UiKit.style_button(_nav_buttons[k], "warm" if k == _sheet_name else "light")


func _update_badges() -> void:
	if _nav_buttons.is_empty():
		return
	UiKit.badge(_nav_buttons["orders"], GameState.fulfillable_orders())
	UiKit.badge(_nav_buttons["quests"], GameState.claimable_quests())


# ------------------------------------------------------------------ HUD

func _on_coins() -> void:
	if _coins_label != null and absf(_displayed_coins - float(GameState.coins)) <= 0.5:
		_coins_label.text = str(GameState.coins)


func _on_xp() -> void:
	_level_label.text = "Stufe %d" % GameState.level
	if GameState.level >= GameData.MAX_LEVEL:
		_xp_bar.value = 1.0
	else:
		_xp_bar.value = float(GameState.xp) / float(GameData.xp_needed(GameState.level))


func show_toast(text: String, kind: String = "info") -> void:
	if text == "":
		return
	_toast_label.text = text
	var bg := UiKit.cream()
	var border := UiKit.sage_dark()
	if kind == "error":
		bg = Painter.col("#FBE3DA")
		border = UiKit.red()
	elif kind == "good":
		bg = Painter.col("#E6F3DC")
	_toast_panel.add_theme_stylebox_override("panel", UiKit.style(bg, 28, border, 3, 8, 14))
	_toast_panel.reset_size()
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position.y = 420.0
	_toast_panel.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)


func _fail() -> void:
	GameState.sound.emit("error")
	show_toast(GameState.last_error, "error")


func _check(ok: bool) -> bool:
	if not ok:
		_fail()
	return ok


# ------------------------------------------------------------- Werkzeugleiste

func _on_tool_changed(mode: String, data: Dictionary) -> void:
	_update_toolbar(mode, data)


func _update_toolbar(mode: String, data: Dictionary) -> void:
	for ch in _toolbar.get_children():
		_toolbar.remove_child(ch)
		ch.queue_free()
	if mode == "":
		_toolbar.visible = false
		return
	if mode == "plant" or mode == "till" or mode == "place" or mode == "edit":
		close_sheet()
	var v := UiKit.vbox(10)
	var h := UiKit.hbox(12)
	match mode:
		"plant":
			var crop: String = data.get("crop", "")
			var d: Dictionary = GameData.CROPS[crop]
			h.add_child(UiKit.item_icon(crop, 80))
			var tv := UiKit.vbox(0)
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv.add_child(UiKit.label("Säen: %s" % String(d["name"]), 32))
			tv.add_child(UiKit.label("Tippe oder wische über leere Felder · Saat %d" % int(d["seed"]), 22, UiKit.earth_dark()))
			h.add_child(tv)
			var sw := UiKit.button("Sorte", "light", 26)
			sw.custom_minimum_size = Vector2(140, 88)
			sw.pressed.connect(act_open.bind("crops", {"cell": Vector2i(-1, -1)}))
			h.add_child(sw)
			var done := UiKit.button("Fertig", "primary", 28)
			done.custom_minimum_size = Vector2(160, 88)
			done.pressed.connect(world.clear_tool)
			h.add_child(done)
		"till":
			h.add_child(UiKit.icon("plus", 70))
			var tv2 := UiKit.vbox(0)
			tv2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv2.add_child(UiKit.label("Felder anlegen", 32))
			tv2.add_child(UiKit.label("Tippe oder wische über freie Wiese · %d Münzen pro Feld" % GameData.TILL_COST, 22, UiKit.earth_dark()))
			h.add_child(tv2)
			var done2 := UiKit.button("Fertig", "primary", 28)
			done2.custom_minimum_size = Vector2(160, 88)
			done2.pressed.connect(world.clear_tool)
			h.add_child(done2)
		"place":
			var type: String = data.get("type", "")
			var def := GameData.object_def(type)
			var tv3 := UiKit.vbox(0)
			tv3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv3.add_child(UiKit.label(String(def.get("name", "")), 32))
			var valid: bool = data.get("valid", false)
			var hint := "Ziehe auf der Karte, um die Stelle zu wählen" if valid else "Hier ist kein Platz – ziehe weiter"
			var hl := UiKit.label(hint, 22, UiKit.sage_dark() if valid else UiKit.red())
			tv3.add_child(hl)
			h.add_child(tv3)
			var cancel := UiKit.button("Abbrechen", "light", 26)
			cancel.custom_minimum_size = Vector2(190, 88)
			cancel.pressed.connect(world.cancel_placement)
			h.add_child(cancel)
			var ok := UiKit.button("Platzieren", "primary", 28)
			ok.custom_minimum_size = Vector2(200, 88)
			ok.disabled = not valid
			ok.pressed.connect(_confirm_place)
			h.add_child(ok)
		"edit":
			var uid := int(data.get("uid", -1))
			var tv4 := UiKit.vbox(0)
			tv4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if uid < 0:
				tv4.add_child(UiKit.label("Farm bearbeiten", 32))
				tv4.add_child(UiKit.label("Tippe auf ein Gebäude oder eine Dekoration", 22, UiKit.earth_dark()))
			else:
				tv4.add_child(UiKit.label(String(data.get("name", "")), 32))
				tv4.add_child(UiKit.label("Verschieben oder verkaufen", 22, UiKit.earth_dark()))
			h.add_child(tv4)
			if uid >= 0:
				var mv := UiKit.button("Bewegen", "light", 24)
				mv.custom_minimum_size = Vector2(150, 88)
				mv.pressed.connect(world.edit_move_selected)
				h.add_child(mv)
				var sell := UiKit.button("+%d" % int(data.get("price", 0)), "warm", 26)
				sell.icon = Icons.tex("coin", 48)
				sell.custom_minimum_size = Vector2(150, 88)
				sell.pressed.connect(world.edit_sell_selected)
				h.add_child(sell)
			var done3 := UiKit.button("Fertig", "primary", 26)
			done3.custom_minimum_size = Vector2(140, 88)
			done3.pressed.connect(world.clear_tool)
			h.add_child(done3)
	v.add_child(h)
	_toolbar.add_child(v)
	_toolbar.visible = true


func _confirm_place() -> void:
	world.confirm_placement()


# ---------------------------------------------------------------- Aktionen

func act_open(sheet_name: String, args: Dictionary = {}) -> void:
	GameState.sound.emit("tap")
	open_sheet(sheet_name, args)


func act_open_shop_tab(tab: String) -> void:
	state["shop_tab"] = tab
	open_sheet("shop", {})


func act_place(type: String) -> void:
	close_sheet()
	world.start_placement(type)


func act_plant_tool(crop: String) -> void:
	close_sheet()
	world.set_plant_tool(crop)


func act_plant_pick(crop: String, cell: Vector2i) -> void:
	close_sheet()
	world.plant_with_tool(crop, cell)


func act_till() -> void:
	GameState.sound.emit("tap")
	close_sheet()
	world.set_till_tool()


func act_edit() -> void:
	GameState.sound.emit("tap")
	close_sheet()
	world.set_edit_mode(world.tool_mode != "edit")


func act_sell(item: String, n: int) -> void:
	var gain := GameState.sell_item(item, n)
	if gain > 0:
		show_toast("+%d Münzen" % gain, "good")
	else:
		_check(false)


func act_buy_item(item: String, n: int) -> void:
	if _check(GameState.buy_item(item, n)):
		show_toast("%s gekauft" % GameData.item_name(item), "good")


func act_expand() -> void:
	if _check(GameState.expand_land()):
		show_toast("Deine Farm ist größer geworden!", "good")
		world.focus_on(world.cam.position)


func act_fulfill(order_id: int) -> void:
	if _check(GameState.fulfill_order(order_id)):
		show_toast("Auftrag erfüllt!", "good")


func act_skip_order(order_id: int) -> void:
	GameState.skip_order(order_id)


func act_claim(quest_id: String) -> void:
	if _check(GameState.claim_quest(quest_id)):
		show_toast("Belohnung erhalten!", "good")


func act_start_recipe(uid: int, recipe: String) -> void:
	_check(GameState.start_recipe(uid, recipe))


func act_collect(uid: int) -> void:
	var got := GameState.collect_ready(uid)
	if got.is_empty():
		_check(false)


func act_upgrade(uid: int) -> void:
	if _check(GameState.upgrade_building(uid)):
		show_toast("Neuer Produktionsplatz!", "good")


func act_adopt(species: String) -> void:
	var uid := GameState.adopt_animal(species)
	if uid < 0:
		_fail()
		return
	var a := GameState.get_animal(uid)
	show_toast("%s hat ein neues Zuhause gefunden!" % a.name, "good")
	open_sheet("animal", {"uid": uid})


func act_feed(uid: int) -> void:
	if _check(GameState.feed_animal(uid)):
		show_toast("Mmh, lecker!", "good")


func act_pet(uid: int) -> void:
	_check(GameState.pet_animal(uid))


func act_toggle(key: String) -> void:
	GameState.settings[key] = not bool(GameState.settings.get(key, true))
	GameState.sound.emit("tap")
	refresh_sheet()


func act_save() -> void:
	if SaveSystem.save_game():
		show_toast("Spielstand gespeichert", "good")
	else:
		show_toast("Speichern fehlgeschlagen", "error")


func act_load() -> void:
	if SaveSystem.load_game():
		world.clear_tool()
		world.reset_camera()
		show_toast("Spielstand geladen", "good")
		close_sheet()
	else:
		show_toast("Kein Spielstand gefunden", "error")


func act_recenter() -> void:
	world.reset_camera()
	close_sheet()


func act_restart_tutorial() -> void:
	GameState.tutorial_step = 0
	close_sheet()
	_update_tutorial()


func act_new_game() -> void:
	if not bool(state.get("confirm_new", false)):
		state["confirm_new"] = true
		refresh_sheet()
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			state["confirm_new"] = false
			if _sheet_name == "settings":
				refresh_sheet())
		return
	state["confirm_new"] = false
	SaveSystem.delete_save()
	world.clear_tool()
	GameState.new_game()
	world.reset_camera()
	close_sheet()
	show_toast("Ein neuer Anfang auf Green Haven!", "good")


# ----------------------------------------------------------------- Tutorial

func _tutorial_cond(step: int) -> bool:
	match step:
		0:
			return int(GameState.stats.get("planted", 0)) >= 1
		1:
			return int(GameState.stats.get("planted", 0)) >= 3
		2:
			return int(GameState.stats.get("harvested", 0)) >= 1
		3:
			return int(GameState.stats.get("orders", 0)) >= 1
	return false


func _update_tutorial() -> void:
	if _tut_panel == null:
		return
	while GameState.tutorial_step < TUTORIAL.size() - 1 and _tutorial_cond(GameState.tutorial_step):
		GameState.tutorial_step += 1
	var step := GameState.tutorial_step
	var active := step < TUTORIAL.size()
	_tut_panel.visible = active and (_modal == null or not _modal.visible)
	if active:
		_tut_label.text = TUTORIAL[step]
		_tut_button.visible = step == TUTORIAL.size() - 1


func _tutorial_skip() -> void:
	GameState.tutorial_step = TUTORIAL_DONE
	_update_tutorial()


# ------------------------------------------------------------------ Popups

func _show_modal(title: String, lines: Array, button_text: String = "Weiter", icon_name: String = "star") -> void:
	if _modal != null and _modal.visible:
		_modal_queue.append([title, lines, button_text, icon_name])
		return
	if _modal != null:
		_modal.queue_free()
	_modal = Control.new()
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.1, 0.05, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := UiKit.panel(UiKit.cream(), 44, 30, UiKit.yellow(), 6, 18)
	card.custom_minimum_size = Vector2(840, 0)
	center.add_child(card)
	var v := UiKit.vbox(16)
	var ic := UiKit.icon(icon_name, 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t := UiKit.label(title, 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for line in lines:
		var l := UiKit.wrap_label(String(line), 32)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var b := UiKit.button(button_text, "primary", 38)
	b.pressed.connect(_close_modal)
	v.add_child(b)
	card.add_child(v)
	card.pivot_offset = Vector2(420, 200)
	card.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tut_panel.visible = false


func _close_modal() -> void:
	GameState.sound.emit("tap")
	if _modal != null:
		_modal.visible = false
		_modal.queue_free()
		_modal = null
	if not _modal_queue.is_empty():
		var n: Array = _modal_queue.pop_front()
		_show_modal(n[0], n[1], n[2], n[3])
	else:
		_update_tutorial()


func _on_level_up(level: int, unlocks: Array) -> void:
	var lines: Array = ["Du hast Stufe %d erreicht!" % level]
	if unlocks.is_empty():
		lines.append("Weiter so – deine Farm wächst und gedeiht.")
	else:
		lines.append("Neu freigeschaltet:")
		lines.append(", ".join(PackedStringArray(unlocks)))
	_show_modal("Stufe %d!" % level, lines, "Super!", "star")


func _show_welcome_back() -> void:
	var away := GameState.away_seconds
	if away < 120.0:
		return
	var rep := GameState.offline_report()
	var lines: Array = []
	var mins := int(away / 60.0)
	if mins >= 60:
		lines.append("Du warst %d Std. %d Min. weg." % [mins / 60, mins % 60])
	else:
		lines.append("Du warst %d Min. weg." % mins)
	if int(rep["fields"]) > 0:
		lines.append("%d Felder sind erntereif." % int(rep["fields"]))
	if int(rep["products"]) > 0:
		lines.append("%d fertige Produkte warten auf dich." % int(rep["products"]))
	var sleepy := 0
	for a in GameState.animals:
		if GameState.wellbeing(a) < 50.0:
			sleepy += 1
	if sleepy > 0:
		lines.append("Deine Tiere freuen sich über Besuch.")
	if lines.size() == 1:
		lines.append("Auf deiner Farm ist alles ruhig.")
	_show_modal("Willkommen zurück!", lines, "Los geht's", "leaf")
