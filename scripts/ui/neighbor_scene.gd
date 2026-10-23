class_name NeighborScene
extends Control
## Statische, gemalte Nachbarschaft für einen Besuch: Himmel, Hügel, Haus, Baum
## und Beet. Die zwei antippbaren Stellen liegen unsichtbar darüber – gezeichnet
## werden sie hier, damit sie zum Bild gehören statt wie Formularknöpfe zu wirken.

signal spot_pressed(index: int)

const SPOT_SIZE := 96.0
## Relative Positionen der Stellen im Bild.
const SPOT_POSITIONS := [Vector2(0.24, 0.68), Vector2(0.74, 0.62)]
const SKY := Color("#CFE6EC")
const SKY_LOW := Color("#E4F0E4")
const GRASS := Color("#8DB580")
const GRASS_DARK := Color("#6F9A63")
const HILL_BACK := Color("#B6D49A")
const HILL_FRONT := Color("#9CC57F")
const CREAM := Color("#FFF6E0")
const WOOD := Color("#8E6240")
const WOOD_LIGHT := Color("#C28E5B")
const ROOF := Color("#B5532F")
const LEAF := Color("#6DAE58")
const LEAF_DARK := Color("#5C9A4A")

var _index := 0
var _spot_count := 0
var _found: Array = []
var _buttons: Array[Button] = []


func setup(neighbor_index: int, spot_count: int, found: Array) -> void:
	_index = neighbor_index
	_spot_count = spot_count
	_found = found.duplicate()
	custom_minimum_size = Vector2(0, 430)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if is_inside_tree():
		_build_buttons()
	queue_redraw()


func _ready() -> void:
	resized.connect(_layout_buttons)
	_build_buttons()


func _build_buttons() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()
	for i in range(_spot_count):
		var button := UiKit.button("", "ghost", 24)
		button.name = "NeighborSpot%d" % i
		button.flat = true
		button.tooltip_text = I18n.t("Antippen")
		button.pressed.connect(func() -> void: spot_pressed.emit(i))
		add_child(button)
		_buttons.append(button)
	_layout_buttons()


func _layout_buttons() -> void:
	if _buttons.is_empty():
		return
	var w := size.x
	var h := size.y
	for i in range(_buttons.size()):
		var button: Button = _buttons[i]
		var ratio: Vector2 = SPOT_POSITIONS[i % SPOT_POSITIONS.size()]
		var center := Vector2(ratio.x * w, ratio.y * h)
		button.size = Vector2(SPOT_SIZE, SPOT_SIZE)
		button.position = Vector2(
			clampf(center.x - SPOT_SIZE * 0.5, 2.0, maxf(2.0, w - SPOT_SIZE - 2.0)),
			clampf(center.y - SPOT_SIZE * 0.5, 2.0, maxf(2.0, h - SPOT_SIZE - 2.0)))


func _spot_center(index: int) -> Vector2:
	var ratio: Vector2 = SPOT_POSITIONS[index % SPOT_POSITIONS.size()]
	return Vector2(ratio.x * size.x, ratio.y * size.y)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	# Himmel mit weichem Übergang zum Horizont.
	draw_rect(Rect2(0, 0, w, h * 0.56), SKY)
	draw_rect(Rect2(0, h * 0.44, w, h * 0.12), SKY_LOW)
	draw_circle(Vector2(w * 0.87, h * 0.14), 34.0, Color("#F6D870"))
	# Zwei Hügel hinter dem Hof, leicht je Nachbar verschoben.
	var shift := 0.03 * float(_index % 3)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.05, h * 0.56), Vector2(w * (0.28 + shift), h * 0.36),
		Vector2(w * (0.62 + shift), h * 0.56)]), HILL_BACK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * (0.34 + shift), h * 0.58), Vector2(w * (0.72 + shift), h * 0.4),
		Vector2(w * 1.05, h * 0.58)]), HILL_FRONT)
	# Wiese.
	draw_rect(Rect2(0, h * 0.55, w, h * 0.45), GRASS)
	# Feldreihen rechts.
	for i in range(4):
		var y := h * (0.8 + float(i) * 0.045)
		draw_line(Vector2(w * 0.62, y), Vector2(w * 0.95, y + 6.0), GRASS_DARK, 5.0)
	# Haus links.
	var house_x := w * 0.1
	var house_w := w * 0.24
	var house_top := h * 0.4
	var house_bottom := h * 0.63
	draw_rect(Rect2(house_x, house_top, house_w, house_bottom - house_top), CREAM)
	draw_colored_polygon(PackedVector2Array([
		Vector2(house_x - 10.0, house_top + 2.0),
		Vector2(house_x + house_w * 0.5, house_top - h * 0.1),
		Vector2(house_x + house_w + 10.0, house_top + 2.0)]), ROOF)
	draw_rect(Rect2(house_x + house_w * 0.42, house_bottom - h * 0.11, house_w * 0.18, h * 0.11), WOOD)
	draw_rect(Rect2(house_x + house_w * 0.12, house_top + h * 0.05, house_w * 0.2, h * 0.065), SKY)
	draw_rect(Rect2(house_x + house_w * 0.66, house_top + h * 0.05, house_w * 0.2, h * 0.065), SKY)
	# Baum.
	var tree_x := w * (0.55 - shift)
	var tree_y := h * 0.62
	draw_rect(Rect2(tree_x - 8.0, tree_y - 44.0, 16.0, 44.0), WOOD)
	draw_circle(Vector2(tree_x, tree_y - 62.0), 40.0, LEAF)
	draw_circle(Vector2(tree_x - 30.0, tree_y - 40.0), 28.0, LEAF_DARK)
	draw_circle(Vector2(tree_x + 30.0, tree_y - 42.0), 26.0, LEAF)
	# Zaun am unteren Rand.
	for i in range(7):
		var x := w * (0.08 + float(i) * 0.13)
		draw_line(Vector2(x, h * 0.93), Vector2(x, h * 0.99), WOOD_LIGHT, 6.0)
	draw_line(Vector2(w * 0.06, h * 0.95), Vector2(w * 0.95, h * 0.95), WOOD_LIGHT, 5.0)
	# Die antippbaren Stellen: Fragezeichen, nach dem Finden ein Haken.
	for i in range(_spot_count):
		var center := _spot_center(i)
		var found := _found.has(i)
		draw_circle(center, 48.0, Color(1, 0.96, 0.88, 0.92))
		draw_arc(center, 48.0, 0.0, TAU, 40, WOOD if not found else GRASS_DARK, 4.0, true)
		if found:
			draw_circle(center, 34.0, Color(0.55, 0.71, 0.5, 0.95))
		draw_string(ThemeDB.fallback_font, center + Vector2(-24, 13), "✓" if found else "?",
			HORIZONTAL_ALIGNMENT_CENTER, 48, 44, CREAM if found else WOOD)
