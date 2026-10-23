class_name Painter
extends RefCounted
## Zeichnet die gesamte Spielgrafik prozedural (handgezeichneter, weicher Look).
## Alle Funktionen zeichnen auf ein CanvasItem; es werden keine Bilddateien
## benötigt, dadurch bleibt die Designsprache einheitlich und das Spiel klein.

static var _cc: Dictionary = {}
static var _boxes: Dictionary = {}


static func col(h: String) -> Color:
	if not _cc.has(h):
		_cc[h] = Color.html(h)
	return _cc[h]


static func rrect(ci: CanvasItem, r: Rect2, c: Color, rad: float = 16.0) -> void:
	var key := "%s_%d" % [c.to_html(true), int(rad)]
	var sb: StyleBoxFlat
	if _boxes.has(key):
		sb = _boxes[key]
	else:
		sb = StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		_boxes[key] = sb
	ci.draw_style_box(sb, r)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, n: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


static func poly(ci: CanvasItem, pts: Array, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), color)


## Ein Holzpfahl mit cremefarbenem Schild und dem Namen des Nachbarn.
static func neighbor_sign(ci: CanvasItem, label: String) -> void:
	shadow(ci, Vector2(0, -22), 44, 10)
	ci.draw_line(Vector2(0, -24), Vector2(0, -92), col("#8E6240"), 9.0, true)
	rrect(ci, Rect2(-62, -152, 124, 64), col("#8E6240"), 10)
	rrect(ci, Rect2(-55, -146, 110, 52), col("#FFF6E0"), 8)
	ci.draw_string(ThemeDB.fallback_font, Vector2(-52, -112), label, HORIZONTAL_ALIGNMENT_CENTER, 104, 24, col("#54351D"))


static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	ellipse(ci, c, rx, ry, Color(0, 0, 0, 0.17))


static func sway(t: float, i: int, amp: float) -> float:
	return sin(t * 1.9 + float(i) * 1.7) * amp


static func heart(ci: CanvasItem, p: Vector2, s: float, color: Color) -> void:
	ci.draw_circle(p + Vector2(-s * 0.5, -s * 0.25), s * 0.55, color)
	ci.draw_circle(p + Vector2(s * 0.5, -s * 0.25), s * 0.55, color)
	poly(ci, [p + Vector2(-s * 1.0, -s * 0.05), p + Vector2(s * 1.0, -s * 0.05), p + Vector2(0, s * 1.05)], color)


static func star(ci: CanvasItem, p: Vector2, r: float, color: Color) -> void:
	var pts: Array = []
	for i in range(10):
		var a := -PI / 2.0 + TAU * float(i) / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	poly(ci, pts, color)


# ------------------------------------------------------------------ Feld

static func draw_field(ci: CanvasItem, pos: Vector2) -> void:
	var T := float(GameData.TILE)
	rrect(ci, Rect2(pos + Vector2(5, 13), Vector2(T - 10, T - 16)), col("#6B4426"), 22)
	rrect(ci, Rect2(pos + Vector2(5, 5), Vector2(T - 10, T - 18)), col("#8C5C3A"), 22)
	for i in range(3):
		var y := pos.y + 34.0 + float(i) * 28.0
		ci.draw_line(Vector2(pos.x + 22, y), Vector2(pos.x + T - 22, y), col("#7A4D2F"), 6.0, true)
		ci.draw_line(Vector2(pos.x + 22, y - 3), Vector2(pos.x + T - 22, y - 3), col("#A06E49"), 2.0, true)


# ----------------------------------------------------------- Pflanzen

## stage: 0 Saat, 1 Keimling, 2 wachsend, 3 erntereif. center = Feldmitte.
static func draw_crop(ci: CanvasItem, id: String, stage: int, center: Vector2, t: float, pop: float = 1.0) -> void:
	ci.draw_set_transform(center + Vector2(0, 30), 0.0, Vector2(pop, pop))
	if stage <= 0:
		ellipse(ci, Vector2(-24, -14), 7, 4, col("#C4975F"))
		ellipse(ci, Vector2(2, -24), 7, 4, col("#C4975F"))
		ellipse(ci, Vector2(26, -12), 7, 4, col("#C4975F"))
	else:
		match id:
			"wheat":
				_stalks(ci, stage, t, "#9BC15A", "#E0B93C", false)
			"oat":
				_stalks(ci, stage, t, "#A6C46A", "#D6D2A0", true)
			"carrot":
				_fan(ci, stage, t)
			"potato":
				_potato(ci, stage, t)
			"tomato":
				_tomato(ci, stage, t)
			"corn":
				_corn(ci, stage, t)
			"soy":
				_soy(ci, stage, t)
			"strawberry":
				_strawberry(ci, stage, t)
			"sunflower":
				_sunflower(ci, stage, t)
			"apple":
				_apple_tree(ci, stage, t)
			"almond":
				_almond_tree(ci, stage, t)
			"pumpkin":
				_pumpkin(ci, stage, t)
			"beet":
				_root_vegetable(ci, stage, t, "#A93659")
			"lettuce":
				_lettuce(ci, stage, t)
			"cucumber":
				_cucumber(ci, stage, t)
			"zucchini":
				_zucchini(ci, stage, t)
			"rhubarb":
				_rhubarb(ci, stage, t)
			"sugarcane":
				_sugarcane(ci, stage, t)
			"pea":
				_pea(ci, stage, t)
			"blueberry":
				_blueberry_bush(ci, stage, t)
			"coffee":
				_coffee_bush(ci, stage, t)
			"rice":
				_rice(ci, stage, t)
			"quinoa":
				_quinoa(ci, stage, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _stalks(ci: CanvasItem, stage: int, t: float, green: String, head: String, droop: bool) -> void:
	var h: float = [0.0, 22.0, 42.0, 60.0][stage]
	for i in range(5):
		var x := -40.0 + float(i) * 20.0
		var top := Vector2(x + sway(t, i, 3.0) * float(stage) / 3.0, -h - float(i % 2) * 7.0 - 6.0)
		ci.draw_line(Vector2(x, -4), top, col(green), 4.0, true)
		if stage == 2:
			poly(ci, [Vector2(x, -h * 0.5), top + Vector2(10, 4), top + Vector2(2, 12)], col(green))
		if stage == 3:
			if droop:
				for k in range(3):
					ellipse(ci, top + Vector2(float(k - 1) * 6.0, 4.0 + float(k % 2) * 6.0), 3.5, 7.0, col(head))
			else:
				ellipse(ci, top + Vector2(0, -8), 6.0, 15.0, col(head))
				ci.draw_line(top + Vector2(0, -22), top + Vector2(0, -30), col(head), 2.0, true)
				ci.draw_line(top + Vector2(-5, -18), top + Vector2(-9, -26), col(head), 2.0, true)
				ci.draw_line(top + Vector2(5, -18), top + Vector2(9, -26), col(head), 2.0, true)


static func _fan(ci: CanvasItem, stage: int, t: float) -> void:
	var h: float = [0.0, 18.0, 34.0, 46.0][stage]
	for i in range(3):
		var x := -24.0 + float(i) * 24.0
		for k in range(-1, 2):
			var tip := Vector2(x + float(k) * 11.0 + sway(t, i + k, 2.5), -6.0 - h + absf(float(k)) * 6.0)
			ci.draw_line(Vector2(x, -6), tip, col("#5FA84A"), 5.0, true)
			ellipse(ci, tip, 5.0, 8.0, col("#74BC55"), 12)
		if stage == 3:
			poly(ci, [Vector2(x - 10, -8), Vector2(x + 10, -8), Vector2(x, 10)], col("#EE8A2E"))
			ci.draw_line(Vector2(x - 4, -4), Vector2(x + 3, -2), col("#C96F1C"), 2.0)


static func _potato(ci: CanvasItem, stage: int, t: float) -> void:
	var r := 11.0 + float(stage) * 5.0
	ellipse(ci, Vector2(-20, -12), r, r * 0.8, col("#58974A"))
	ellipse(ci, Vector2(20, -14), r, r * 0.8, col("#5FA050"))
	ellipse(ci, Vector2(sway(t, 1, 1.5), -26 - float(stage) * 3.0), r, r * 0.85, col("#6BB05A"))
	if stage == 3:
		for p in [Vector2(-30, 0), Vector2(0, 4), Vector2(30, 0)]:
			ellipse(ci, p, 11, 7, col("#B98B55"), 14)
			ci.draw_circle(p + Vector2(-3, -1), 1.5, col("#8E6A3E"))
		ci.draw_circle(Vector2(0, -38), 4, col("#FFFFFF"))


static func _tomato(ci: CanvasItem, stage: int, t: float) -> void:
	var h: float = [0.0, 30.0, 52.0, 70.0][stage]
	ci.draw_line(Vector2(0, 0), Vector2(0, -h - 8), col("#8E6240"), 4.0, true)
	var r := 10.0 + float(stage) * 6.0
	ellipse(ci, Vector2(-16, -h * 0.5), r, r * 0.9, col("#5FA050"))
	ellipse(ci, Vector2(16, -h * 0.65), r, r * 0.9, col("#68AA58"))
	ellipse(ci, Vector2(sway(t, 2, 1.5), -h), r * 0.9, r * 0.8, col("#5FA050"))
	if stage >= 2:
		var spots := [Vector2(-22, -h * 0.4), Vector2(20, -h * 0.55), Vector2(4, -h * 0.9), Vector2(-4, -h * 0.25)]
		for p in spots:
			ci.draw_circle(p, 9.0, col("#E04B3A") if stage == 3 else col("#9CC060"))
			if stage == 3:
				ci.draw_circle(p + Vector2(-3, -3), 2.5, Color(1, 1, 1, 0.55))


static func _corn(ci: CanvasItem, stage: int, t: float) -> void:
	var h: float = [0.0, 32.0, 62.0, 88.0][stage]
	for i in range(3):
		var x := -28.0 + float(i) * 28.0
		var top := Vector2(x + sway(t, i, 2.5), -h - float(i % 2) * 8.0)
		ci.draw_line(Vector2(x, -2), top, col("#6FA84C"), 6.0, true)
		for j in range(3):
			var y := -h * (0.3 + float(j) * 0.25)
			var dirx := -1.0 if (j + i) % 2 == 0 else 1.0
			poly(ci, [Vector2(x, y), Vector2(x + dirx * 30.0, y - 22.0), Vector2(x + dirx * 8.0, y + 4.0)], col("#7FBA55"))
		if stage == 3:
			var cp := Vector2(x + 7.0, -h * 0.55)
			ellipse(ci, cp, 8.0, 18.0, col("#F2CF3E"))
			poly(ci, [cp + Vector2(-9, 12), cp + Vector2(0, -20), cp + Vector2(2, 14)], col("#8BC060"))
			ci.draw_line(top, top + Vector2(0, -10), col("#D9B84A"), 3.0)


static func _soy(ci: CanvasItem, stage: int, t: float) -> void:
	var r := 12.0 + float(stage) * 5.0
	for i in range(4):
		var x := -30.0 + float(i) * 20.0
		ellipse(ci, Vector2(x, -r * 0.7 - float(i % 2) * 8.0 + sway(t, i, 1.2)), r * 0.85, r * 0.8, col("#8DB04F") if i % 2 == 0 else col("#7EA546"))
	if stage == 3:
		for i in range(6):
			var p := Vector2(-34.0 + float(i) * 14.0, -14.0 - float(i % 3) * 12.0)
			ellipse(ci, p, 4.5, 9.0, col("#C9B864"), 10)
			ci.draw_line(p + Vector2(0, -6), p + Vector2(0, 6), col("#8F7E3A"), 1.5)


static func _strawberry(ci: CanvasItem, stage: int, t: float) -> void:
	var r := 11.0 + float(stage) * 4.0
	for i in range(3):
		var x := -28.0 + float(i) * 28.0
		ellipse(ci, Vector2(x, -r * 0.6 + sway(t, i, 1.0)), r * 1.2, r * 0.7, col("#5FA050"))
		ellipse(ci, Vector2(x + 8, -r * 0.9), r * 0.8, r * 0.5, col("#74B65E"))
	if stage == 2:
		for p in [Vector2(-26, -20), Vector2(4, -26), Vector2(30, -18)]:
			ci.draw_circle(p, 5.0, Color.WHITE)
			ci.draw_circle(p, 2.0, col("#F4C95D"))
	if stage == 3:
		for p in [Vector2(-28, -8), Vector2(2, -4), Vector2(30, -8), Vector2(-12, -22), Vector2(16, -22)]:
			poly(ci, [p + Vector2(-9, -4), p + Vector2(9, -4), p + Vector2(0, 12)], col("#D9344F"))
			ci.draw_circle(p + Vector2(-4, -3), 6.0, col("#D9344F"))
			ci.draw_circle(p + Vector2(4, -3), 6.0, col("#D9344F"))
			ci.draw_circle(p + Vector2(-2, 1), 1.2, col("#F6E08A"))
			ci.draw_circle(p + Vector2(3, 3), 1.2, col("#F6E08A"))


static func _sunflower(ci: CanvasItem, stage: int, t: float) -> void:
	var h: float = [0.0, 30.0, 62.0, 90.0][stage]
	for i in range(2):
		var x := -22.0 + float(i) * 44.0
		var top := Vector2(x + sway(t, i, 2.5), -h + float(i) * 10.0)
		ci.draw_line(Vector2(x, -2), top, col("#5E9A45"), 6.0, true)
		poly(ci, [Vector2(x, -h * 0.45), Vector2(x - 26, -h * 0.45 - 12), Vector2(x - 6, -h * 0.45 + 6)], col("#6FB052"))
		if stage == 3:
			for k in range(12):
				var a := TAU * float(k) / 12.0
				ellipse(ci, top + Vector2(cos(a), sin(a)) * 19.0, 8.0, 5.0, col("#F6C21C"), 8)
			ci.draw_circle(top, 13.0, col("#7A4A22"))
			ci.draw_circle(top + Vector2(-3, -3), 4.0, col("#9A6A3A"))
		elif stage == 2:
			ci.draw_circle(top, 9.0, col("#8CC05A"))


static func _pumpkin(ci: CanvasItem, stage: int, t: float) -> void:
	var h := 12.0 + float(stage) * 8.0
	for i in range(4):
		var x := -30.0 + float(i) * 20.0
		ci.draw_line(Vector2(0, -4), Vector2(x, -h - float(i % 2) * 8.0), col("#5E9A45"), 4.0, true)
		ellipse(ci, Vector2(x - 8, -h * 0.5), 11, 5, col("#6DAE58"))
	if stage == 3:
		var p := Vector2(0, -h - 3)
		for dx in [-12.0, 0.0, 12.0]:
			ellipse(ci, p + Vector2(dx, 0), 12, 16, col("#E8792F"), 14)
		ci.draw_line(p + Vector2(0, -15), p + Vector2(2, -23), col("#547A3C"), 4.0, true)


static func _root_vegetable(ci: CanvasItem, stage: int, t: float, color: String) -> void:
	for i in range(4):
		var x := -24.0 + float(i) * 16.0
		ci.draw_line(Vector2(0, -4), Vector2(x + sway(t, i, 1.5), -18.0 - float(stage) * 7.0), col("#5FA84A"), 5.0, true)
	if stage == 3:
		ellipse(ci, Vector2(0, 5), 15, 20, col(color))
		ci.draw_line(Vector2(0, -6), Vector2(0, 14), col("#7A2442"), 2.0, true)


static func _lettuce(ci: CanvasItem, stage: int, t: float) -> void:
	var r := 10.0 + float(stage) * 7.0
	for i in range(7):
		var a := TAU * float(i) / 7.0
		var p := Vector2(cos(a), sin(a)) * r * 0.75
		ellipse(ci, p + Vector2(sway(t, i, 1.0), -r * 0.35), r * 0.72, r * 0.52, col("#79B85A") if i % 2 == 0 else col("#91C96D"))
	if stage == 3:
		ellipse(ci, Vector2(0, -r * 0.45), 13, 17, col("#B8D98A"))


static func _cucumber(ci: CanvasItem, stage: int, t: float) -> void:
	var h := 14.0 + float(stage) * 11.0
	for i in range(3):
		var x := -28.0 + float(i) * 28.0
		var y := -h - sway(t, i, 1.5)
		ci.draw_line(Vector2(x, -3), Vector2(x + 12, y), col("#5FA050"), 4.0, true)
		ellipse(ci, Vector2(x + 5, y * 0.65), 8, 4, col("#78B85B"))
		if stage == 3:
			ellipse(ci, Vector2(x + 13, y + 6), 6, 17, col("#4F9A55"))
			for k in range(3):
				ci.draw_circle(Vector2(x + 13 + float(k - 1) * 3, y + 3 + float(k) * 5), 1.4, col("#B8D779"))


static func _zucchini(ci: CanvasItem, stage: int, t: float) -> void:
	var h := 12.0 + float(stage) * 10.0
	for i in range(4):
		var x := -30.0 + float(i) * 20.0
		var top := Vector2(x + sway(t, i, 1.4), -h - float(i % 2) * 6.0)
		ci.draw_line(Vector2(0, -3), top, col("#5A9147"), 4.0, true)
		ellipse(ci, top + Vector2(-8, 4), 12, 8, col("#6FAE56"))
		ellipse(ci, top + Vector2(7, 1), 11, 7, col("#7DBB62"))
	if stage == 3:
		ellipse(ci, Vector2(12, -20), 8, 20, col("#4F9A48"), 12)
		ci.draw_circle(Vector2(12, -38), 4, col("#F2C24A"))
		for k in range(3):
			ci.draw_circle(Vector2(10 + float(k) * 2, -26 + float(k) * 6), 1.2, col("#B8D779"))


static func _rhubarb(ci: CanvasItem, stage: int, t: float) -> void:
	var h := 14.0 + float(stage) * 14.0
	for i in range(3):
		var x := -22.0 + float(i) * 22.0
		var top := Vector2(x + sway(t, i, 1.8), -h - float(i % 2) * 4.0)
		ci.draw_line(Vector2(x, -2), top, col("#B84B55"), 5.0, true)
		if stage >= 2:
			ellipse(ci, top + Vector2(-10, -4), 15, 9, col("#6FAE56"), 10)
			ellipse(ci, top + Vector2(9, -7), 13, 8, col("#7DBB62"), 10)
		if stage == 3:
			ci.draw_circle(top + Vector2(-10, 5), 2.5, col("#F2D6A2"))


## Hohe, gegliederte Halme mit langen Blättern – Zuckerrohr.
static func _sugarcane(ci: CanvasItem, stage: int, t: float) -> void:
	var h := 14.0 + float(stage) * 26.0
	for i in range(3):
		var x := -26.0 + float(i) * 26.0
		var top := Vector2(x + sway(t, i, 2.2), -h - float(i % 2) * 8.0)
		ci.draw_line(Vector2(x, -2), top, col("#A8C46A"), 8.0, true)
		ci.draw_line(Vector2(x, -2), top, col("#C2D98A"), 3.0, true)
		if stage >= 2:
			for k in range(3):
				var node := Vector2(x, -8.0 - float(k) * (h * 0.3))
				ci.draw_line(node + Vector2(-5, 0), node + Vector2(5, 0), col("#86A84E"), 2.5, true)
			ellipse(ci, top + Vector2(-13, 10), 17, 6, col("#7DBB62"), 10)
			ellipse(ci, top + Vector2(13, 6), 15, 6, col("#8CC96E"), 10)
		if stage == 3:
			ellipse(ci, top + Vector2(0, -7), 4.5, 10, col("#D8C58A"))


static func _pea(ci: CanvasItem, stage: int, t: float) -> void:
	var h := 14.0 + float(stage) * 12.0
	for i in range(3):
		var x := -24.0 + float(i) * 24.0
		var top := Vector2(x + sway(t, i, 2.0), -h - float(i % 2) * 5)
		ci.draw_line(Vector2(x, -4), top, col("#679B48"), 4.0, true)
		for side in [-1.0, 1.0]:
			ellipse(ci, top + Vector2(side * 9, 8), 10, 5, col("#8BC56A"))
		if stage == 3:
			for j in range(2):
				var p := top + Vector2(10, 7 + float(j) * 15)
				ellipse(ci, p, 5, 4, col("#79A94B"))


static func _coffee_bush(ci: CanvasItem, stage: int, t: float) -> void:
	var height := 16.0 + float(stage) * 13.0
	for i in range(5):
		var x := -30.0 + float(i) * 15.0
		var top := Vector2(x + sway(t, i, 1.5), -height - float(i % 2) * 7.0)
		ci.draw_line(Vector2(0, -3), top, col("#648D4D"), 4.0, true)
		ellipse(ci, top + Vector2(-7, 4), 12, 7, col("#4F8F4C"))
		ellipse(ci, top + Vector2(6, 1), 11, 7, col("#65A256"))
		if stage == 3:
			for k in range(2):
				ci.draw_circle(top + Vector2(float(k) * 8.0 - 4.0, 10), 5.0, col("#A9463D"))


static func _blueberry_bush(ci: CanvasItem, stage: int, t: float) -> void:
	for i in range(5):
		var x := -32.0 + float(i) * 16.0
		ellipse(ci, Vector2(x + sway(t, i, 1.0), -12.0 - float(i % 2) * float(stage) * 5.0), 14 + float(stage) * 3, 12 + float(stage) * 3, col("#5A9647") if i % 2 == 0 else col("#6DAE58"))
	if stage == 3:
		for p in [Vector2(-25, -16), Vector2(-5, -30), Vector2(18, -20), Vector2(30, -8), Vector2(4, -10)]:
			ci.draw_circle(p, 6, col("#5365A8"))
			ci.draw_circle(p + Vector2(-2, -2), 2, col("#8996D0"))


static func _rice(ci: CanvasItem, stage: int, t: float) -> void:
	for i in range(6):
		var x := -36.0 + float(i) * 14.0
		var top := Vector2(x + sway(t, i, 1.3), -12.0 - float(stage) * 12.0)
		ci.draw_line(Vector2(x, -2), top, col("#72A652"), 3.5, true)
		if stage == 3:
			for k in range(3):
				ellipse(ci, top + Vector2(float(k - 1) * 5, 7 + float(k % 2) * 5), 3.5, 6, col("#D5C98E"))


static func _quinoa(ci: CanvasItem, stage: int, t: float) -> void:
	for i in range(5):
		var x := -32.0 + float(i) * 16.0
		var top := Vector2(x + sway(t, i, 1.7), -16.0 - float(stage) * 13.0)
		ci.draw_line(Vector2(x, -2), top, col("#789B4D"), 4.0, true)
		for side in [-1.0, 1.0]:
			ci.draw_line(top, top + Vector2(side * 13, 8), col("#89A95A"), 3.0, true)
		if stage == 3:
			for k in range(5):
				var p := top + Vector2(float(k - 2) * 5, 9 + float(k % 2) * 4)
				ci.draw_circle(p, 3, col("#B66D70"))


static func _apple_tree(ci: CanvasItem, stage: int, t: float) -> void:
	var g: float = [0.0, 0.35, 0.7, 1.0][stage]
	rrect(ci, Rect2(-7, -58.0 * g - 2.0, 14, 58.0 * g + 4.0), col("#8A5A36"), 5)
	var cy := -64.0 * g - 18.0
	ellipse(ci, Vector2(-22.0 * g, cy + 8.0 * g), 28.0 * g + 4.0, 24.0 * g + 3.0, col("#5E9E4C"))
	ellipse(ci, Vector2(22.0 * g, cy + 8.0 * g), 28.0 * g + 4.0, 24.0 * g + 3.0, col("#68A856"))
	ellipse(ci, Vector2(sway(t, 0, 1.5), cy - 10.0 * g), 32.0 * g + 4.0, 28.0 * g + 3.0, col("#74B65E"))
	if stage == 3:
		for p in [Vector2(-26, cy + 8), Vector2(20, cy + 14), Vector2(-4, cy - 16), Vector2(30, cy - 4), Vector2(-14, cy + 22)]:
			ci.draw_circle(p, 8.0, col("#C9362D"))
			ci.draw_circle(p + Vector2(-2.5, -2.5), 2.5, Color(1, 1, 1, 0.5))


## Mandelbaum: schlanker Stamm, hellgrüne Krone und hellbraune Nüsse.
static func _almond_tree(ci: CanvasItem, stage: int, t: float) -> void:
	var g: float = [0.0, 0.35, 0.7, 1.0][stage]
	rrect(ci, Rect2(-6, -52.0 * g - 2.0, 12, 52.0 * g + 4.0), col("#8A5A36"), 5)
	var cy := -58.0 * g - 18.0
	ellipse(ci, Vector2(-19.0 * g, cy + 8.0 * g), 24.0 * g + 4.0, 21.0 * g + 3.0, col("#6FA356"))
	ellipse(ci, Vector2(19.0 * g, cy + 8.0 * g), 24.0 * g + 4.0, 21.0 * g + 3.0, col("#7BB262"))
	ellipse(ci, Vector2(sway(t, 0, 1.2), cy - 10.0 * g), 28.0 * g + 4.0, 25.0 * g + 3.0, col("#8CC273"))
	if stage == 3:
		for p in [Vector2(-22, cy + 10), Vector2(16, cy + 15), Vector2(-2, cy - 15), Vector2(27, cy - 2), Vector2(-12, cy + 23)]:
			ellipse(ci, p, 5.0, 7.5, col("#D8B98A"))
			ci.draw_line(p + Vector2(0, -4), p + Vector2(0, 4), col("#A07C4E"), 1.5, true)


# ------------------------------------------------------------ Wildnis

## Wilde Sammelstelle außerhalb des Zauns. Ursprung = untere Zellmitte.
## `ready` zeigt die reife Pflanze, sonst nur den jungen Nachwuchs.
static func draw_forage(ci: CanvasItem, id: String, base: Vector2, ready: bool) -> void:
	var s := 1.0 if ready else 0.7
	ci.draw_set_transform(base, 0.0, Vector2(s, s))
	match id:
		"wild_herbs":
			shadow(ci, Vector2(0, -4), 26, 7)
			for i in range(5):
				var x := -18.0 + float(i) * 9.0
				var top := Vector2(x + sway(0.0, i, 2.0), -26.0 - float(i % 3) * 8.0)
				ci.draw_line(Vector2(x, -4), top, col("#5F9A4A"), 3.0, true)
				ellipse(ci, top + Vector2(-4, 0), 7, 4, col("#7FB56A"), 8)
				ellipse(ci, top + Vector2(4, -2), 6, 3.5, col("#8FC777"), 8)
			if ready:
				for p in [Vector2(-8, -40), Vector2(6, -46), Vector2(14, -32)]:
					ci.draw_circle(p, 2.6, col("#FFF6E0"))
		"mushroom":
			shadow(ci, Vector2(0, -3), 24, 6)
			for i in range(3):
				var x := -14.0 + float(i) * 14.0
				var h := 14.0 + float(i % 2) * 8.0
				rrect(ci, Rect2(x - 4, -4 - h, 8, h), col("#F1E4C8"), 3)
				ellipse(ci, Vector2(x, -4 - h - 2), 13, 8, col("#B5643F") if i != 1 else col("#C97A4A"))
				if ready:
					ci.draw_circle(Vector2(x - 4, -4 - h - 4), 2.0, col("#FFF1D0"))
		"wild_berries":
			shadow(ci, Vector2(0, -4), 30, 8)
			ellipse(ci, Vector2(0, -22), 24, 16, col("#4F8A45"))
			ellipse(ci, Vector2(-14, -28), 13, 10, col("#5F9A4A"))
			ellipse(ci, Vector2(13, -26), 12, 9, col("#71AA5A"))
			if ready:
				for p in [Vector2(-12, -22), Vector2(2, -18), Vector2(12, -26), Vector2(-2, -30)]:
					ci.draw_circle(p, 3.5, col("#C43A4E"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------- Gegenstände

## Zeichnet das Symbol eines Gegenstands, zentriert auf pos, Kantenlänge ~size.
static func draw_item(ci: CanvasItem, id: String, pos: Vector2, size: float) -> void:
	var s := size / 64.0
	ci.draw_set_transform(pos, 0.0, Vector2(s, s))
	var info: Dictionary = GameData.items.get(id, {})
	var base: Color = col(String(info.get("col", "#CCCCCC")))
	match id:
		"wheat", "oat":
			for i in range(3):
				var x := -14.0 + float(i) * 14.0
				ci.draw_line(Vector2(x, 28), Vector2(x + float(i - 1) * 3.0, -6), col("#8DB05A"), 3.0, true)
				ellipse(ci, Vector2(x + float(i - 1) * 3.0, -14), 5.5, 15.0, base)
		"carrot":
			poly(ci, [Vector2(-13, -12), Vector2(13, -12), Vector2(0, 32)], base)
			for k in range(-1, 2):
				ci.draw_line(Vector2(0, -12), Vector2(float(k) * 11.0, -30), col("#5FA84A"), 4.0, true)
		"potato":
			ellipse(ci, Vector2(0, 2), 26, 19, base)
			ci.draw_circle(Vector2(-9, -3), 2.2, col("#8E6A3E"))
			ci.draw_circle(Vector2(8, 6), 2.2, col("#8E6A3E"))
		"tomato", "apple":
			ci.draw_circle(Vector2(0, 4), 23, base)
			ci.draw_circle(Vector2(-8, -4), 6, Color(1, 1, 1, 0.35))
			poly(ci, [Vector2(0, -18), Vector2(-12, -26), Vector2(0, -22), Vector2(12, -26)], col("#4E9A3C"))
		"corn":
			ellipse(ci, Vector2(0, 2), 13, 27, base)
			poly(ci, [Vector2(-8, 28), Vector2(-20, -8), Vector2(2, 20)], col("#7FBA55"))
			poly(ci, [Vector2(8, 28), Vector2(20, -8), Vector2(-2, 20)], col("#6FA84C"))
		"soy":
			for i in range(3):
				var p := Vector2(-14.0 + float(i) * 14.0, float(i % 2) * 8.0 - 6.0)
				ellipse(ci, p, 8, 20, base, 14)
				ci.draw_circle(p + Vector2(0, -6), 3, col("#6F8A3A"))
				ci.draw_circle(p + Vector2(0, 6), 3, col("#6F8A3A"))
		"strawberry":
			poly(ci, [Vector2(-22, -4), Vector2(22, -4), Vector2(0, 30)], base)
			ci.draw_circle(Vector2(-11, -6), 13, base)
			ci.draw_circle(Vector2(11, -6), 13, base)
			poly(ci, [Vector2(0, -14), Vector2(-14, -24), Vector2(0, -20), Vector2(14, -24)], col("#5FA84A"))
			for p in [Vector2(-8, 2), Vector2(8, 4), Vector2(0, 14), Vector2(-2, -4)]:
				ci.draw_circle(p, 1.8, col("#F6E08A"))
		"sunflower":
			for k in range(12):
				var a := TAU * float(k) / 12.0
				ellipse(ci, Vector2(cos(a), sin(a)) * 19.0, 9, 5.5, base, 8)
			ci.draw_circle(Vector2.ZERO, 12, col("#7A4A22"))
		"pumpkin":
			for dx in [-12.0, 0.0, 12.0]:
				ellipse(ci, Vector2(dx, 3), 12, 20, base, 14)
			ci.draw_line(Vector2(0, -14), Vector2(2, -24), col("#547A3C"), 4.0, true)
		"beet":
			ci.draw_circle(Vector2(0, 7), 20, base)
			poly(ci, [Vector2(-3, 18), Vector2(4, 18), Vector2(0, 31)], col("#7A2442"))
			poly(ci, [Vector2(0, -8), Vector2(-17, -28), Vector2(-2, -20), Vector2(2, -8)], col("#5FA84A"))
			poly(ci, [Vector2(2, -8), Vector2(18, -27), Vector2(5, -18)], col("#79B85A"))
		"lettuce":
			for i in range(6):
				var a := TAU * float(i) / 6.0
				ellipse(ci, Vector2(cos(a), sin(a)) * 12, 15, 10, col("#79B85A") if i % 2 == 0 else col("#91C96D"))
			ci.draw_circle(Vector2.ZERO, 11, col("#B8D98A"))
		"cucumber":
			ellipse(ci, Vector2(0, 2), 10, 27, base)
			for y in [-14.0, -4.0, 6.0, 16.0]:
				ci.draw_circle(Vector2(0, y), 2, col("#B8D779"))
		"pea":
			poly(ci, [Vector2(-22, 4), Vector2(-12, -12), Vector2(0, -17), Vector2(18, -7), Vector2(22, 10), Vector2(5, 20)], col("#8BC56A"))
			for x in [-10.0, 0.0, 10.0]:
				ci.draw_circle(Vector2(x, 3), 6, base)
		"coffee":
			for p in [Vector2(-13, 8), Vector2(0, -5), Vector2(14, 8), Vector2(-4, 18)]:
				ci.draw_circle(p, 11, base)
				ci.draw_circle(p + Vector2(-3, -3), 3, col("#E89469"))
		"roasted_coffee":
			for p in [Vector2(-13, 8), Vector2(0, -5), Vector2(14, 8), Vector2(-4, 18)]:
				ellipse(ci, p, 8, 12, base)
				ci.draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), col("#D6B184"), 2.0)
		"filter_coffee":
			ci.draw_circle(Vector2(0, 3), 23, col("#8E6240"))
			ci.draw_circle(Vector2(0, 0), 18, col("#FFF6E0"))
			ellipse(ci, Vector2(0, 0), 14, 8, base)
			ci.draw_line(Vector2(-10, 25), Vector2(10, 25), col("#8E6240"), 4.0, true)
			ci.draw_line(Vector2(-5, -25), Vector2(-8, -34), Color(1, 1, 1, 0.75), 2.0, true)
			ci.draw_line(Vector2(6, -25), Vector2(9, -34), Color(1, 1, 1, 0.75), 2.0, true)
		"oat_latte":
			rrect(ci, Rect2(-16, -20, 32, 48), col("#FFF6E0"), 7)
			rrect(ci, Rect2(-12, -7, 24, 26), base, 5)
			ci.draw_circle(Vector2(0, -8), 9, col("#F2E4C9"))
			ci.draw_circle(Vector2(-3, -8), 3, col("#9B6540"))
			ci.draw_line(Vector2(8, -18), Vector2(18, -31), col("#8E6240"), 3.0, true)
		"coffee_cookie_plate":
			ellipse(ci, Vector2(0, 9), 29, 12, col("#FFF6E0"))
			ci.draw_circle(Vector2(-10, 3), 12, col("#D2A765"))
			ci.draw_circle(Vector2(-10, 3), 2, col("#805437"))
			ci.draw_circle(Vector2(-3, 1), 2, col("#805437"))
			ci.draw_circle(Vector2(17, -5), 11, col("#8E6240"))
			ci.draw_circle(Vector2(17, -6), 7, col("#9B6540"))
		"pumpkin_spice_latte":
			rrect(ci, Rect2(-16, -20, 32, 48), col("#FFF6E0"), 7)
			rrect(ci, Rect2(-12, -7, 24, 26), base, 5)
			ci.draw_circle(Vector2(0, -8), 9, col("#F2E4C9"))
			ci.draw_circle(Vector2(-3, -8), 3, col("#D98B4F"))
			for i in range(3):
				ci.draw_circle(Vector2(-8.0 + float(i) * 8.0, 4.0 + float(i % 2) * 5.0), 1.8, col("#805437"))
		"blueberry_coffee_cake":
			poly(ci, [Vector2(-24, -8), Vector2(20, -8), Vector2(10, 20), Vector2(-16, 20)], base)
			poly(ci, [Vector2(-24, -8), Vector2(-12, -20), Vector2(30, -20), Vector2(20, -8)], col("#E8D8BC"))
			for p in [Vector2(-8, -13), Vector2(3, -15), Vector2(13, -11)]:
				ci.draw_circle(p, 4, col("#5365A8"))
				ci.draw_circle(p + Vector2(-1, -1), 1.2, col("#8996D0"))
		"sugar":
			for p in [Vector2(-12, 8), Vector2(6, 10), Vector2(-2, -8)]:
				rrect(ci, Rect2(p.x - 9, p.y - 9, 18, 18), base, 4)
				ci.draw_line(Vector2(p.x - 6, p.y - 5), Vector2(p.x + 6, p.y - 5), Color(1, 1, 1, 0.55), 2.0, true)
		"zucchini":
			ellipse(ci, Vector2(2, 4), 12, 26, base, 12)
			ci.draw_circle(Vector2(2, -24), 7, col("#F2C24A"))
			for i in range(4):
				ci.draw_circle(Vector2(-2 + float(i % 2) * 4, -8 + float(i) * 7), 1.2, col("#B8D779"))
		"rhubarb":
			for i in range(3):
				var x := -14.0 + float(i) * 14.0
				ci.draw_line(Vector2(x, 30), Vector2(x + 2, -12), base, 6.0, true)
				ellipse(ci, Vector2(x + 2, -20), 10, 7, col("#6FAE56"), 8)
				ellipse(ci, Vector2(x + 12, -24), 9, 6, col("#7DBB62"), 8)
		"sugarcane":
			for i in range(3):
				var x0 := -16.0 + float(i) * 16.0
				ci.draw_line(Vector2(x0, 30), Vector2(x0 + 6, -26), col("#C2D98A"), 8.0, true)
				ci.draw_line(Vector2(x0, 30), Vector2(x0 + 6, -26), col("#A8C46A"), 3.0, true)
				for k in range(4):
					var p := Vector2(x0, 30).lerp(Vector2(x0 + 6, -26), float(k + 1) / 5.0)
					ci.draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), col("#86A84E"), 2.0, true)
			ellipse(ci, Vector2(8, -24), 16, 6, col("#7DBB62"), 10)
			ellipse(ci, Vector2(-4, -30), 13, 5, col("#8CC96E"), 10)
		"wild_herbs":
			for i in range(3):
				var x := -14.0 + float(i) * 14.0
				ci.draw_line(Vector2(x, 28), Vector2(x + 4, -14), col("#6FA84C"), 4.0, true)
				ellipse(ci, Vector2(x + 6, -18), 9, 6, col("#7FB56A"), 10)
				ellipse(ci, Vector2(x - 2, -22), 8, 5, col("#8FC777"), 10)
			rrect(ci, Rect2(-16, 10, 32, 12), col("#C9A24A"), 4)
		"mushroom":
			for i in range(2):
				var x := -12.0 + float(i) * 24.0
				var h := 18.0 + float(i) * 8.0
				rrect(ci, Rect2(x - 5, 26 - h, 10, h), col("#F1E4C8"), 3)
				ellipse(ci, Vector2(x, 24 - h), 16, 10, col("#B5643F") if i == 0 else col("#C97A4A"))
				ci.draw_circle(Vector2(x - 5, 20 - h), 2.2, col("#FFF1D0"))
		"wild_berries":
			for p in [Vector2(-12, 6), Vector2(2, 12), Vector2(12, -2), Vector2(-2, -6)]:
				ci.draw_circle(p, 9, base)
				ci.draw_circle(p + Vector2(-3, -3), 2.5, col("#E892A4"))
			poly(ci, [Vector2(0, -18), Vector2(-14, -30), Vector2(0, -24), Vector2(14, -30)], col("#5FA84A"))
		"sunflower_oil":
			rrect(ci, Rect2(-13, -8, 26, 38), col("#F6F2E6"), 7)
			rrect(ci, Rect2(-8, -22, 16, 16), col("#F6F2E6"), 4)
			rrect(ci, Rect2(-10, -28, 20, 8), col("#D9A93A"), 3)
			rrect(ci, Rect2(-10, 2, 20, 20), base, 4)
			ci.draw_circle(Vector2(0, -12), 4, col("#E2BC52"))
		"almond_butter":
			rrect(ci, Rect2(-18, -12, 36, 40), col("#F6F2E6"), 8)
			rrect(ci, Rect2(-14, -4, 28, 24), base, 6)
			rrect(ci, Rect2(-19, -20, 38, 10), col("#8E6240"), 4)
			ellipse(ci, Vector2(0, 7), 7, 10, col("#E8D0A8"))
		"pasta":
			for i in range(5):
				var x := -14.0 + float(i) * 7.0
				ci.draw_line(Vector2(x, 24), Vector2(x + 4, -22), base, 5.0, true)
			rrect(ci, Rect2(-18, -2, 36, 8), col("#C97A3A"), 4)
		"tomato_ravioli", "pumpkin_ravioli":
			for p in [Vector2(-10, 2), Vector2(12, 8)]:
				rrect(ci, Rect2(p.x - 14, p.y - 14, 28, 28), col("#E8C77A"), 6)
				rrect(ci, Rect2(p.x - 10, p.y - 10, 20, 20), base, 4)
				ci.draw_circle(Vector2(p.x, p.y), 3, col("#F1D9A0"))
		"zucchini_noodles":
			for i in range(3):
				var y := -12.0 + float(i) * 12.0
				ci.draw_line(Vector2(-22, y), Vector2(22, y + 4), base, 6.0, true)
				ci.draw_line(Vector2(-22, y + 6), Vector2(22, y + 10), col("#B8D779"), 2.0, true)
		"strawberry_ice", "apple_cookie_ice", "rhubarb_ice", "blueberry_ice":
			poly(ci, [Vector2(-15, -2), Vector2(15, -2), Vector2(0, 32)], col("#D9A93A"))
			ci.draw_circle(Vector2(0, -8), 17, base)
			ci.draw_circle(Vector2(-5, -13), 5, Color(1, 1, 1, 0.35))
			ci.draw_line(Vector2(-13, -2), Vector2(13, -2), col("#B88050"), 3.0, true)
		"sunflower_bouquet":
			for i in range(3):
				var x := -13.0 + float(i) * 13.0
				ci.draw_line(Vector2(0, 28), Vector2(x, -6), col("#5FA84A"), 4.0, true)
				for k in range(8):
					var a := TAU * float(k) / 8.0
					ellipse(ci, Vector2(x, -6) + Vector2(cos(a), sin(a)) * 9.0, 4.5, 3.0, base, 6)
				ci.draw_circle(Vector2(x, -6), 5.0, col("#7A4A22"))
			rrect(ci, Rect2(-15, 8, 30, 20), col("#E9D9B0"), 5)
		"dried_wreath", "autumn_wreath":
			for i in range(12):
				var a := TAU * float(i) / 12.0
				ellipse(ci, Vector2(cos(a), sin(a)) * 22.0, 8, 6, col("#6FAE56") if i % 2 == 0 else base, 8)
			ci.draw_circle(Vector2(-16, -16), 4, base)
			ci.draw_circle(Vector2(16, -12), 4, base)
		"berry_muesli", "apple_rice_pudding":
			poly(ci, [Vector2(-26, 0), Vector2(26, 0), Vector2(18, 24), Vector2(-18, 24)], col("#EAD9B0"))
			ellipse(ci, Vector2(0, 0), 26, 8, base)
			for p in [Vector2(-12, 0), Vector2(0, -3), Vector2(12, 1)]:
				ci.draw_circle(p, 3, col("#F1D9A0"))
		"quinoa_bar":
			rrect(ci, Rect2(-24, -12, 48, 32), base, 8)
			rrect(ci, Rect2(-20, -8, 40, 24), base.lightened(0.15), 6)
			for p in [Vector2(-12, 0), Vector2(0, 6), Vector2(11, -2)]:
				ci.draw_circle(p, 2.5, col("#F1D9A0"))
		"strawberry_jam", "apple_jam", "rhubarb_jam", "blueberry_jam":
			rrect(ci, Rect2(-18, -6, 36, 36), col("#F6F2E6"), 8)
			rrect(ci, Rect2(-14, 2, 28, 22), base, 5)
			rrect(ci, Rect2(-20, -16, 40, 12), col("#B5532F"), 4)
			rrect(ci, Rect2(-10, 7, 20, 10), col("#FFF6E0"), 3)
		"blueberry":
			for p in [Vector2(-13, 8), Vector2(0, -5), Vector2(14, 8), Vector2(-4, 18)]:
				ci.draw_circle(p, 11, base)
				ci.draw_circle(p + Vector2(-3, -3), 3, col("#8996D0"))
		"rice":
			for i in range(3):
				var x := -14.0 + float(i) * 14.0
				ci.draw_line(Vector2(x, 26), Vector2(x, -4), col("#72A652"), 3.0, true)
				for k in range(3):
					ellipse(ci, Vector2(x + float(k - 1) * 5, -12 + float(k % 2) * 7), 3.5, 7, base)
		"quinoa":
			for i in range(5):
				var a := TAU * float(i) / 5.0
				ci.draw_circle(Vector2(cos(a), sin(a)) * 13, 6, base)
			ci.draw_circle(Vector2.ZERO, 6, col("#89A95A"))
		"almond":
			ellipse(ci, Vector2(0, 0), 14, 22, base)
			ci.draw_line(Vector2(0, -18), Vector2(0, 18), col("#A07C4E"), 2.0)
		"bread":
			ellipse(ci, Vector2(0, 4), 28, 18, base)
			ellipse(ci, Vector2(0, 0), 25, 14, col("#C98E4F"))
			for i in range(3):
				ci.draw_line(Vector2(-12.0 + float(i) * 12.0, -6), Vector2(-6.0 + float(i) * 12.0, 6), col("#F1D9A8"), 3.0, true)
		"oat_cookies":
			for p in [Vector2(-10, 6), Vector2(10, -4)]:
				ci.draw_circle(p, 17, base)
				ci.draw_circle(p, 13, col("#E0BC7C"))
				ci.draw_circle(p + Vector2(-4, -3), 2.5, col("#7A4A22"))
				ci.draw_circle(p + Vector2(5, 4), 2.5, col("#7A4A22"))
		"carrot_muffin":
			poly(ci, [Vector2(-18, -2), Vector2(18, -2), Vector2(13, 26), Vector2(-13, 26)], col("#C99A5E"))
			ellipse(ci, Vector2(0, -8), 24, 18, base)
			ci.draw_circle(Vector2(-6, -14), 3, col("#6FB052"))
			ci.draw_circle(Vector2(8, -10), 3, col("#6FB052"))
		"carrot_soup", "pumpkin_soup":
			ellipse(ci, Vector2(0, 0), 28, 9, col("#EAD9B0"))
			poly(ci, [Vector2(-28, 0), Vector2(28, 0), Vector2(18, 22), Vector2(-18, 22)], col("#EAD9B0"))
			ellipse(ci, Vector2(0, 0), 23, 6, base)
			ci.draw_line(Vector2(-8, -10), Vector2(-4, -24), Color(1, 1, 1, 0.7), 3.0, true)
			ci.draw_line(Vector2(8, -10), Vector2(12, -24), Color(1, 1, 1, 0.7), 3.0, true)
		"beet_spread":
			rrect(ci, Rect2(-21, -12, 42, 32), base, 8)
			ellipse(ci, Vector2(0, -12), 21, 8, col("#D7A0AB"))
			ci.draw_circle(Vector2(-8, -14), 3, col("#F4D7D9"))
			ci.draw_circle(Vector2(7, -10), 3, col("#F4D7D9"))
		"garden_salad":
			ellipse(ci, Vector2(0, 5), 27, 17, col("#E9E1CC"))
			for p in [Vector2(-12, 3), Vector2(0, -5), Vector2(12, 4), Vector2(-3, 12)]:
				ci.draw_circle(p, 7, base)
			ci.draw_circle(Vector2(8, -10), 5, col("#79B85A"))
		"quinoa_bowl":
			poly(ci, [Vector2(-26, 0), Vector2(26, 0), Vector2(18, 21), Vector2(-18, 21)], col("#EAD9B0"))
			ellipse(ci, Vector2(0, 0), 26, 8, col("#B66D70"))
			for p in [Vector2(-12, -1), Vector2(0, -4), Vector2(12, 0)]:
				ci.draw_circle(p, 3, col("#F1D9A0"))
		"rice_milk":
			rrect(ci, Rect2(-14, -6, 28, 36), col("#F6F2E6"), 8)
			rrect(ci, Rect2(-8, -20, 16, 16), col("#F6F2E6"), 4)
			rrect(ci, Rect2(-9, -26, 18, 8), col("#6F9A63"), 3)
			rrect(ci, Rect2(-11, 6, 22, 14), base, 4)
		"tomato_sauce":
			rrect(ci, Rect2(-17, -14, 34, 42), col("#DCEFEF"), 8)
			rrect(ci, Rect2(-14, -4, 28, 30), base, 6)
			rrect(ci, Rect2(-14, -22, 28, 10), col("#8E6240"), 4)
		"veg_pan":
			ci.draw_circle(Vector2(-4, 2), 25, col("#4A4A52"))
			ci.draw_circle(Vector2(-4, 2), 20, col("#6A6A72"))
			ci.draw_line(Vector2(20, 2), Vector2(34, -6), col("#4A4A52"), 6.0, true)
			ci.draw_circle(Vector2(-12, -4), 6, col("#E04B3A"))
			ci.draw_circle(Vector2(2, 6), 6, col("#EE8A2E"))
			ci.draw_circle(Vector2(-4, -10), 5, col("#8DB05A"))
			ci.draw_circle(Vector2(-14, 10), 5, col("#B98B55"))
		"oat_milk", "almond_milk", "soy_milk":
			rrect(ci, Rect2(-14, -6, 28, 36), col("#F6F2E6"), 8)
			rrect(ci, Rect2(-8, -20, 16, 16), col("#F6F2E6"), 4)
			rrect(ci, Rect2(-9, -26, 18, 8), col("#6F9A63"), 3)
			rrect(ci, Rect2(-11, 6, 22, 14), base, 4)
		"berry_smoothie", "blueberry_smoothie", "apple_juice":
			poly(ci, [Vector2(-18, -16), Vector2(18, -16), Vector2(13, 28), Vector2(-13, 28)], Color(0.9, 0.96, 0.97, 0.9))
			poly(ci, [Vector2(-16, -4), Vector2(16, -4), Vector2(12, 26), Vector2(-12, 26)], base)
			ci.draw_line(Vector2(6, -6), Vector2(14, -32), col("#E0783A"), 4.0, true)
		"tofu", "smoked_tofu", "marinated_tofu":
			rrect(ci, Rect2(-24, -12, 48, 36), base.darkened(0.15), 8)
			rrect(ci, Rect2(-24, -18, 48, 34), base, 8)
			if id == "marinated_tofu":
				for p in [Vector2(-12, -6), Vector2(6, 2), Vector2(14, -8)]:
					ci.draw_circle(p, 2.5, col("#4E9A3C"))
			if id == "smoked_tofu":
				ci.draw_line(Vector2(-14, -8), Vector2(14, -8), col("#6E4C2C"), 3.0)
				ci.draw_line(Vector2(-14, 4), Vector2(14, 4), col("#6E4C2C"), 3.0)
		_:
			ci.draw_circle(Vector2.ZERO, 22, base)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- Natur

static func tree(ci: CanvasItem, base: Vector2, s: float, t: float, shade: float = 0.0) -> void:
	shadow(ci, base + Vector2(0, -2) * s, 46.0 * s, 12.0 * s)
	rrect(ci, Rect2(base + Vector2(-9, -62) * s, Vector2(18, 64) * s), col("#7E5230"), 6)
	var sw := sin(t * 1.2 + base.x * 0.01) * 2.0 * s
	var d := 1.0 - shade
	ellipse(ci, base + Vector2(-28 + sw, -84) * s, 36 * s, 32 * s, col("#5A9647").darkened(shade))
	ellipse(ci, base + Vector2(28 + sw, -84) * s, 36 * s, 32 * s, col("#62A04E").darkened(shade))
	ellipse(ci, base + Vector2(sw * 1.4, -112) * s, 40 * s, 36 * s, col("#6DAE58").darkened(shade))
	ellipse(ci, base + Vector2(-12 + sw, -118) * s, 14 * s, 10 * s, Color(1, 1, 1, 0.12 * d))


static func bush(ci: CanvasItem, base: Vector2, s: float, berries: bool = false) -> void:
	shadow(ci, base + Vector2(0, -2) * s, 40.0 * s, 10.0 * s)
	ellipse(ci, base + Vector2(-20, -22) * s, 26 * s, 22 * s, col("#5A9647"))
	ellipse(ci, base + Vector2(20, -22) * s, 26 * s, 22 * s, col("#62A04E"))
	ellipse(ci, base + Vector2(0, -34) * s, 28 * s, 24 * s, col("#6DAE58"))
	if berries:
		for p in [Vector2(-22, -26), Vector2(12, -18), Vector2(-2, -42), Vector2(26, -34), Vector2(-10, -12)]:
			ci.draw_circle(base + p * s, 5.0 * s, col("#B8324E"))
			ci.draw_circle(base + p * s + Vector2(-1.5, -1.5) * s, 1.5 * s, Color(1, 1, 1, 0.5))


static func rock(ci: CanvasItem, base: Vector2, s: float) -> void:
	shadow(ci, base, 34.0 * s, 8.0 * s)
	poly(ci, [base + Vector2(-30, 0) * s, base + Vector2(-22, -24) * s, base + Vector2(0, -32) * s, base + Vector2(24, -20) * s, base + Vector2(32, 0) * s], col("#9A9A94"))
	poly(ci, [base + Vector2(-22, -24) * s, base + Vector2(0, -32) * s, base + Vector2(10, -18) * s, base + Vector2(-12, -12) * s], col("#B4B4AC"))


static func tuft(ci: CanvasItem, base: Vector2, s: float, t: float) -> void:
	for i in range(-2, 3):
		var tip := base + Vector2(float(i) * 7.0 * s + sin(t * 1.6 + base.x * 0.02 + float(i)) * 2.0 * s, -22.0 * s + absf(float(i)) * 5.0 * s)
		ci.draw_line(base + Vector2(float(i) * 4.0 * s, 0), tip, col("#4E8A3E"), 3.0 * s, true)


static func flower_dot(ci: CanvasItem, p: Vector2, s: float, c: Color) -> void:
	ci.draw_line(p, p + Vector2(0, 14.0 * s), col("#4E8A3E"), 2.0 * s)
	for k in range(5):
		var a := TAU * float(k) / 5.0
		ci.draw_circle(p + Vector2(cos(a), sin(a)) * 5.0 * s, 4.0 * s, c)
	ci.draw_circle(p, 3.0 * s, col("#F6D84A"))


# ----------------------------------------------------------- Dekoration

## Ursprung = Mitte der Unterkante der Grundfläche.
static func draw_deco(ci: CanvasItem, type: String, t: float) -> void:
	# Namensschilder der Nachbarn: ein kleines Holzschild mit dem Vornamen.
	if type.begins_with("sign_"):
		neighbor_sign(ci, String(GameData.DECOS.get(type, {}).get("label", "")))
		return
	match type:
		"bush":
			bush(ci, Vector2(0, -26), 1.0, true)
		"flowers", "hofbuch_herbs":
			shadow(ci, Vector2(0, -22), 44, 12)
			ellipse(ci, Vector2(0, -26), 46, 20, col("#6DAE58"))
			var cols := ["#F28BB0", "#F6D84A", "#FFFFFF", "#B79AE8", "#F28BB0", "#F6A04A"]
			for i in range(6):
				flower_dot(ci, Vector2(-34.0 + float(i) * 14.0, -34.0 - float(i % 3) * 8.0), 1.0, col(cols[i]))
		"haybale":
			shadow(ci, Vector2(0, -20), 52, 12)
			rrect(ci, Rect2(-46, -70, 92, 56), col("#E2BC52"), 22)
			for i in range(4):
				ci.draw_line(Vector2(-30.0 + float(i) * 20.0, -64), Vector2(-30.0 + float(i) * 20.0, -20), col("#C79A36"), 3.0)
			ci.draw_line(Vector2(-46, -42), Vector2(46, -42), col("#B58A2E"), 4.0)
		"tree", "hofbuch_tree":
			tree(ci, Vector2(0, -22), 1.0, t)
		"bench", "season_bench", "hofbuch_bench", "hofbuch_table":
			shadow(ci, Vector2(0, -22), 110, 14)
			rrect(ci, Rect2(-108, -64, 216, 14), col("#B07A4A"), 5)
			rrect(ci, Rect2(-108, -92, 216, 22), col("#C28E5B"), 6)
			rrect(ci, Rect2(-96, -50, 12, 36), col("#8E6240"), 3)
			rrect(ci, Rect2(84, -50, 12, 36), col("#8E6240"), 3)
		"lantern", "season_lantern":
			shadow(ci, Vector2(0, -22), 24, 7)
			rrect(ci, Rect2(-5, -112, 10, 96), col("#4A4A52"), 3)
			ellipse(ci, Vector2(0, -120), 34, 34, Color(1.0, 0.86, 0.45, 0.25 + 0.06 * sin(t * 2.0)))
			rrect(ci, Rect2(-14, -136, 28, 34), col("#F6D870"), 8)
			rrect(ci, Rect2(-18, -142, 36, 8), col("#4A4A52"), 3)
		"scarecrow":
			shadow(ci, Vector2(0, -22), 34, 9)
			ci.draw_line(Vector2(0, -20), Vector2(0, -118), col("#8E6240"), 8.0, true)
			ci.draw_line(Vector2(-46, -84), Vector2(46, -84), col("#8E6240"), 7.0, true)
			poly(ci, [Vector2(-22, -90), Vector2(22, -90), Vector2(16, -50), Vector2(-16, -50)], col("#6D9AB0"))
			ci.draw_circle(Vector2(0, -112), 17, col("#E9CF84"))
			poly(ci, [Vector2(-26, -120), Vector2(26, -120), Vector2(12, -150), Vector2(-12, -150)], col("#8E6240"))
			ci.draw_circle(Vector2(-6, -114), 2.2, col("#4A3A2A"))
			ci.draw_circle(Vector2(6, -114), 2.2, col("#4A3A2A"))
			for k in range(-1, 2):
				ci.draw_line(Vector2(-44.0 + float(k) * 3.0, -84), Vector2(-52.0 + float(k) * 4.0, -74), col("#E2BC52"), 3.0)
				ci.draw_line(Vector2(44.0 + float(k) * 3.0, -84), Vector2(52.0 + float(k) * 4.0, -74), col("#E2BC52"), 3.0)
		"season_arch", "hofbuch_gate":
			shadow(ci, Vector2(0, -16), 150, 16)
			rrect(ci, Rect2(-106, -154, 20, 138), col("#C28E5B"), 9)
			rrect(ci, Rect2(86, -154, 20, 138), col("#C28E5B"), 9)
			rrect(ci, Rect2(-114, -176, 228, 28), col("#C28E5B"), 13)
			for i in range(7):
				var blossom := "#F28BB0" if i % 2 == 0 else "#F6D84A"
				flower_dot(ci, Vector2(-90.0 + float(i) * 30.0, -174.0 - float(i % 2) * 8.0), 1.0, col(blossom))
		"season_basket", "hofbuch_basket":
			shadow(ci, Vector2(0, -16), 62, 13)
			rrect(ci, Rect2(-42, -58, 84, 44), col("#B07A4A"), 11)
			rrect(ci, Rect2(-48, -68, 96, 17), col("#C28E5B"), 8)
			ci.draw_arc(Vector2(0, -68), 32, PI, TAU, 24, col("#8E6240"), 6.0, true)
			ci.draw_circle(Vector2(-18, -70), 9, col("#E8792F"))
			ci.draw_circle(Vector2(4, -72), 8, col("#D9344F"))
			ci.draw_circle(Vector2(22, -68), 7, col("#8DB580"))
		"year_wreath", "hofbuch_wreath":
			shadow(ci, Vector2(0, -18), 74, 13)
			ci.draw_arc(Vector2(0, -66), 42, 0.0, TAU, 40, col("#6F9A63"), 10.0, true)
			for i in range(8):
				var angle := TAU * float(i) / 8.0
				var leaf_col := "#8DB580" if i % 2 == 0 else "#F28BB0"
				ci.draw_circle(Vector2(0, -66) + Vector2(cos(angle), sin(angle)) * 42.0, 9.0, col(leaf_col))
			ci.draw_circle(Vector2(0, -66), 8, col("#F6D84A"))
		"hofbuch_sign":
			shadow(ci, Vector2(0, -16), 40, 9)
			rrect(ci, Rect2(-6, -100, 12, 84), col("#8E6240"), 4)
			rrect(ci, Rect2(-54, -132, 108, 46), col("#C28E5B"), 11)
			rrect(ci, Rect2(-44, -122, 88, 26), col("#FFF6E0"), 7)
			ci.draw_line(Vector2(-32, -112), Vector2(32, -112), col("#6F9A63"), 4.0, true)
			ci.draw_line(Vector2(-32, -103), Vector2(16, -103), col("#B07A4A"), 4.0, true)
		"pond":
			ellipse(ci, Vector2(0, -60), 118, 56, col("#A9A18C"))
			ellipse(ci, Vector2(0, -62), 108, 48, col("#6FB4D0"))
			ellipse(ci, Vector2(-14, -70), 60, 22, Color(1, 1, 1, 0.16))
			for p in [Vector2(-40, -56), Vector2(30, -70), Vector2(54, -50)]:
				ellipse(ci, p, 20, 9, col("#5FA050"))
				poly(ci, [p, p + Vector2(20, -2), p + Vector2(18, 4)], col("#6FB4D0"))
			ci.draw_circle(Vector2(30, -74), 6, col("#F28BB0"))


# ------------------------------------------------------------- Gebäude

const BUILDING_ICON := {"bakery": "bread", "kitchen": "carrot_soup", "milkery": "oat_milk", "juicebar": "apple_juice", "tofu": "tofu", "cafe": "filter_coffee", "florist": "sunflower_bouquet", "oilmill": "sunflower_oil", "preserves": "strawberry_jam", "sugarmill": "sugar", "pasta": "pasta", "icecream": "strawberry_ice", "muesli": "berry_muesli"}


## Ursprung = Mitte der Unterkante; Grundfläche 2x2 Zellen (256 px).
static func draw_building(ci: CanvasItem, type: String, t: float, working: bool) -> void:
	var d: Dictionary = GameData.BUILDINGS[type]
	var wall: Color = col(String(d["col"]))
	var roof: Color = col(String(d["roof"]))
	shadow(ci, Vector2(0, -14), 140, 30)
	rrect(ci, Rect2(-104, -134, 208, 124), wall, 12)
	rrect(ci, Rect2(-104, -34, 208, 24), wall.darkened(0.12), 12)
	# Dach
	poly(ci, [Vector2(-128, -118), Vector2(-14, -218), Vector2(14, -218), Vector2(128, -118)], roof)
	poly(ci, [Vector2(-128, -118), Vector2(-14, -218), Vector2(-6, -208), Vector2(-112, -118)], roof.lightened(0.18))
	rrect(ci, Rect2(-132, -126, 264, 14), roof.darkened(0.18), 6)
	# Schornstein + Rauch
	if type != "juicebar" and type != "milkery":
		rrect(ci, Rect2(54, -206, 26, 52), col("#9A6A4A"), 4)
		if working:
			for i in range(3):
				var k := fmod(t * 0.7 + float(i) * 0.33, 1.0)
				ci.draw_circle(Vector2(67 + sin(t + float(i)) * 6.0, -214 - k * 50.0), 7.0 + k * 9.0, Color(1, 1, 1, 0.5 * (1.0 - k)))
	# Tür & Fenster
	rrect(ci, Rect2(-24, -86, 48, 78), col("#8E6240"), 10)
	ci.draw_circle(Vector2(12, -48), 3.5, col("#F6D870"))
	var glow: Color = col("#FFE79A") if working else col("#CFE6EC")
	for x in [-88.0, 52.0]:
		rrect(ci, Rect2(x, -100, 36, 34), glow, 6)
		ci.draw_line(Vector2(x + 18, -100), Vector2(x + 18, -66), col("#8E6240"), 3.0)
		ci.draw_line(Vector2(x, -83), Vector2(x + 36, -83), col("#8E6240"), 3.0)
	# Schild mit Produktsymbol
	rrect(ci, Rect2(-34, -150, 68, 52), col("#FFF6E0"), 14)
	draw_item(ci, BUILDING_ICON.get(type, "bread"), Vector2(0, -124), 42.0)
	if type == "juicebar":
		for i in range(8):
			var c1: Color = roof if i % 2 == 0 else col("#FFF6E0")
			poly(ci, [Vector2(-104.0 + float(i) * 26.0, -112), Vector2(-78.0 + float(i) * 26.0, -112), Vector2(-82.0 + float(i) * 26.0, -90), Vector2(-100.0 + float(i) * 26.0, -90)], c1)
	elif type == "cafe":
		for i in range(8):
			var stripe: Color = roof if i % 2 == 0 else col("#FFF6E0")
			poly(ci, [Vector2(-104.0 + float(i) * 26.0, -112), Vector2(-78.0 + float(i) * 26.0, -112), Vector2(-82.0 + float(i) * 26.0, -90), Vector2(-100.0 + float(i) * 26.0, -90)], stripe)
		# Kleines Gartenschild und Blumenkübel im bestehenden warmen Stil.
		rrect(ci, Rect2(-102, -176, 46, 30), col("#FFF6E0"), 5)
		ci.draw_string(ThemeDB.fallback_font, Vector2(-96, -155), I18n.t("CAFE"), HORIZONTAL_ALIGNMENT_LEFT, 36, 12, col("#6F6248"))
		ellipse(ci, Vector2(-84, -87), 14, 8, col("#9CC47A"))
		ellipse(ci, Vector2(82, -87), 14, 8, col("#9CC47A"))
	elif type == "icecream":
		for i in range(8):
			var stripe: Color = roof if i % 2 == 0 else col("#FFF6E0")
			poly(ci, [Vector2(-104.0 + float(i) * 26.0, -112), Vector2(-78.0 + float(i) * 26.0, -112), Vector2(-82.0 + float(i) * 26.0, -90), Vector2(-100.0 + float(i) * 26.0, -90)], stripe)
		ellipse(ci, Vector2(-82, -88), 13, 8, col("#F2C24A"))
		ellipse(ci, Vector2(82, -88), 13, 8, col("#F2C24A"))
	elif type == "florist":
		for x in [-84.0, 72.0]:
			ellipse(ci, Vector2(x, -88), 15, 9, col("#9CC47A"))
			for k in range(3):
				ci.draw_circle(Vector2(x - 8.0 + float(k) * 8.0, -98 + float(k % 2) * 4.0), 5, col("#E2BC52") if k % 2 == 0 else col("#D96A7A"))
	elif type == "sugarmill":
		# Gemauerte Mühle mit Zuckerrohrbündeln und einer kleinen Presse.
		rrect(ci, Rect2(-100, -46, 200, 18), col("#C6B294"), 6)
		for x in [-88.0, -68.0, 68.0, 88.0]:
			for k in range(3):
				ci.draw_line(Vector2(x - 6.0 + float(k) * 6.0, -12), Vector2(x - 2.0 + float(k) * 6.0, -50), col("#C2D98A"), 4.0, true)
			ci.draw_line(Vector2(x - 9, -34), Vector2(x + 9, -34), col("#8E6240"), 3.0, true)
		ci.draw_circle(Vector2(-40, -28), 13, col("#B58A5A"))
		ci.draw_circle(Vector2(-40, -28), 5, col("#8E6240"))
		ci.draw_circle(Vector2(40, -28), 13, col("#B58A5A"))
		ci.draw_circle(Vector2(40, -28), 5, col("#8E6240"))


static func draw_paddock_back(ci: CanvasItem, rect: Rect2) -> void:
	rrect(ci, rect.grow(-6), col("#9CCB7C"), 26)
	rrect(ci, Rect2(rect.position + Vector2(10, 10), rect.size - Vector2(20, 24)), col("#A9D88A"), 22)
	var top := rect.position.y + 14.0
	_fence_h(ci, rect.position.x + 8.0, rect.end.x - 8.0, top)
	_post_line(ci, rect.position.x + 10.0, top, rect.end.y - 10.0)
	_post_line(ci, rect.end.x - 10.0, top, rect.end.y - 10.0)
	# Offener, kleiner Unterstand an der Gehegerückwand; Tiere stehen im Vordergrund.
	var cx := rect.position.x + rect.size.x * 0.5
	var shed_width := minf(380.0, rect.size.x * 0.82)
	var shed_top := rect.position.y + 22.0
	var shed_bottom := shed_top + 112.0
	shadow(ci, Vector2(cx, shed_bottom - 2.0), shed_width * 0.52, 12.0)
	rrect(ci, Rect2(cx - shed_width * 0.5, shed_top + 28.0, shed_width, 76.0), col("#C99C69"), 8)
	for x in [cx - shed_width * 0.5 + 14.0, cx + shed_width * 0.5 - 14.0]:
		rrect(ci, Rect2(x - 9.0, shed_top + 10.0, 18.0, 98.0), col("#8E6240"), 5)
	poly(ci, [Vector2(cx - shed_width * 0.5 - 24.0, shed_top + 32.0), Vector2(cx - shed_width * 0.5 + 4.0, shed_top - 18.0), Vector2(cx + shed_width * 0.5 - 4.0, shed_top - 18.0), Vector2(cx + shed_width * 0.5 + 24.0, shed_top + 32.0)], col("#9B6540"))
	poly(ci, [Vector2(cx - shed_width * 0.5 - 18.0, shed_top + 27.0), Vector2(cx, shed_top - 8.0), Vector2(cx + shed_width * 0.5 + 18.0, shed_top + 27.0)], col("#B88050"))
	ci.draw_line(Vector2(cx - shed_width * 0.5 - 18.0, shed_top + 27.0), Vector2(cx + shed_width * 0.5 + 18.0, shed_top + 27.0), col("#805437"), 8.0, true)


static func _post_line(ci: CanvasItem, x: float, y0: float, y1: float) -> void:
	ci.draw_line(Vector2(x, y0 + 10), Vector2(x, y1 - 10), col("#B07A4A"), 8.0, true)
	var y := y0
	while y <= y1:
		rrect(ci, Rect2(x - 7, y - 24, 14, 34), col("#C28E5B"), 5)
		y += 64.0


static func _fence_h(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	ci.draw_line(Vector2(x0, y - 26), Vector2(x1, y - 26), col("#B07A4A"), 7.0, true)
	ci.draw_line(Vector2(x0, y - 8), Vector2(x1, y - 8), col("#B07A4A"), 7.0, true)
	var x := x0
	while x <= x1 + 1.0:
		rrect(ci, Rect2(x - 7, y - 40, 14, 48), col("#C28E5B"), 5)
		x += 64.0


## Vorderer Zaun (wird vor den Tieren gezeichnet). Ursprung = Mitte Unterkante.
static func draw_paddock_front(ci: CanvasItem, width: float) -> void:
	_fence_h(ci, -width * 0.5 + 8.0, width * 0.5 - 8.0, -2.0)
