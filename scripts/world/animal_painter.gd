class_name AnimalPainter
extends RefCounted
## Zeichnet die geretteten Tiere. Ursprung = Standpunkt (Mitte der Füße),
## alle Tiere schauen standardmäßig nach rechts und werden bei Bedarf gespiegelt.

const HEAD := {
	"cow": Vector2(46, -70), "chicken": Vector2(20, -60), "pig": Vector2(40, -50),
	"sheep": Vector2(44, -52), "rabbit": Vector2(24, -44),
}
const HEAD_R := {"cow": 24.0, "chicken": 13.0, "pig": 22.0, "sheep": 18.0, "rabbit": 15.0}


static func _c(h: String) -> Color:
	return Painter.col(h)


static func _erot(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		var p := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.append(c + p)
	ci.draw_colored_polygon(pts, color)


## flip: nach links schauen. peck: 0..1 Pick-/Schnupper-Bewegung.
static func draw(ci: CanvasItem, species: String, t: float, flip: bool, walking: bool, cosmetics: Array, peck: float = 0.0, scale_f: float = 1.0, sleeping: bool = false) -> void:
	var sx := -scale_f if flip else scale_f
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, scale_f))
	Painter.shadow(ci, Vector2(0, -2), 50.0, 11.0)
	var bob := 0.0
	if walking:
		bob = absf(sin(t * 9.0)) * (13.0 if species == "rabbit" else 4.0)
	else:
		bob = sin(t * (1.25 if sleeping else 2.0)) * (2.2 if sleeping else 1.3)
	ci.draw_set_transform(Vector2(0, -bob * scale_f), 0.0, Vector2(sx, scale_f))
	var blink := sleeping or fmod(t + float(species.length()), 4.3) < 0.14
	var sw := sin(t * 9.0) * 6.0 if walking else 0.0
	match species:
		"cow":
			_cow(ci, blink, sw)
		"chicken":
			_chicken(ci, blink, sw, peck)
		"pig":
			_pig(ci, blink, sw)
		"sheep":
			_sheep(ci, blink, sw)
		"rabbit":
			_rabbit(ci, blink, sw)
	_accessories(ci, species, cosmetics, t, peck)
	if sleeping:
		Painter.ellipse(ci, Vector2(0, -8), 15.0, 7.0 + sin(t * 1.25) * 1.5, Color(1.0, 1.0, 1.0, 0.18))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _eye(ci: CanvasItem, p: Vector2, r: float, blink: bool) -> void:
	if blink:
		ci.draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), _c("#3A3030"), 2.0, true)
	else:
		ci.draw_circle(p, r, _c("#2E2626"))
		ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color.WHITE)


static func _cow(ci: CanvasItem, blink: bool, sw: float) -> void:
	var lx := [-34.0, -18.0, 24.0, 40.0]
	for i in range(4):
		var off := sw * (0.5 if i % 2 == 0 else -0.5)
		Painter.rrect(ci, Rect2(lx[i] - 6.0 + off, -36, 12, 36), _c("#EFE9DA"), 5)
		Painter.rrect(ci, Rect2(lx[i] - 6.0 + off, -8, 12, 8), _c("#5E4C3E"), 3)
	ci.draw_line(Vector2(-52, -72), Vector2(-62, -38), _c("#3A3636"), 4.0, true)
	Painter.ellipse(ci, Vector2(-62, -34), 6, 10, _c("#3A3636"), 10)
	Painter.ellipse(ci, Vector2(0, -58), 54, 33, _c("#FBF8F0"))
	Painter.ellipse(ci, Vector2(-22, -66), 19, 15, _c("#3A3636"))
	Painter.ellipse(ci, Vector2(14, -48), 15, 11, _c("#3A3636"))
	Painter.ellipse(ci, Vector2(-42, -46), 11, 13, _c("#3A3636"))
	Painter.ellipse(ci, Vector2(20, -82), 28, 12, Color(1, 1, 1, 0.35))
	var h: Vector2 = HEAD["cow"]
	Painter.poly(ci, [h + Vector2(-8, -18), h + Vector2(-14, -34), h + Vector2(-2, -20)], _c("#F1E4BE"))
	Painter.poly(ci, [h + Vector2(8, -18), h + Vector2(14, -34), h + Vector2(2, -20)], _c("#F1E4BE"))
	Painter.ellipse(ci, h + Vector2(-16, -12), 12, 7, _c("#E8B8AC"), 12)
	Painter.ellipse(ci, h, 24, 21, _c("#FBF8F0"))
	Painter.ellipse(ci, h + Vector2(6, -6), 10, 9, _c("#3A3636"))
	Painter.ellipse(ci, h + Vector2(14, 8), 16, 12, _c("#F2B8B0"))
	ci.draw_circle(h + Vector2(9, 8), 2.2, _c("#B07A70"))
	ci.draw_circle(h + Vector2(19, 8), 2.2, _c("#B07A70"))
	_eye(ci, h + Vector2(7, -6), 3.6, blink)


static func _chicken(ci: CanvasItem, blink: bool, sw: float, peck: float) -> void:
	ci.draw_line(Vector2(-4, -16), Vector2(-4 + sw * 0.4, 0), _c("#E8962E"), 4.0, true)
	ci.draw_line(Vector2(8, -16), Vector2(8 - sw * 0.4, 0), _c("#E8962E"), 4.0, true)
	ci.draw_line(Vector2(-4 + sw * 0.4, 0), Vector2(4 + sw * 0.4, 0), _c("#E8962E"), 3.0, true)
	ci.draw_line(Vector2(8 - sw * 0.4, 0), Vector2(16 - sw * 0.4, 0), _c("#E8962E"), 3.0, true)
	Painter.poly(ci, [Vector2(-22, -40), Vector2(-46, -66), Vector2(-40, -44), Vector2(-48, -34), Vector2(-26, -26)], _c("#F3EEE0"))
	Painter.ellipse(ci, Vector2(0, -34), 27, 23, _c("#FFFFFF"))
	Painter.ellipse(ci, Vector2(2, -26), 22, 14, _c("#F6F1E4"))
	Painter.ellipse(ci, Vector2(-4, -34), 16, 11, _c("#EDE5D0"))
	var h: Vector2 = HEAD["chicken"] + Vector2(peck * 12.0, peck * 20.0)
	Painter.ellipse(ci, Vector2(12, -46), 11, 14, _c("#FFFFFF"), 14)
	ci.draw_circle(h, 13, _c("#FFFFFF"))
	for p in [Vector2(-3, -13), Vector2(4, -16), Vector2(10, -12)]:
		ci.draw_circle(h + p, 5.5, _c("#E04B3A"))
	Painter.poly(ci, [h + Vector2(11, -3), h + Vector2(25, 2), h + Vector2(11, 6)], _c("#F0A030"))
	ci.draw_circle(h + Vector2(10, 9), 4.0, _c("#E04B3A"))
	_eye(ci, h + Vector2(5, -3), 2.8, blink)


static func _pig(ci: CanvasItem, blink: bool, sw: float) -> void:
	var lx := [-28.0, -12.0, 20.0, 36.0]
	for i in range(4):
		var off := sw * (0.4 if i % 2 == 0 else -0.4)
		Painter.rrect(ci, Rect2(lx[i] - 6.0 + off, -24, 12, 24), _c("#E898A6"), 5)
		Painter.rrect(ci, Rect2(lx[i] - 6.0 + off, -6, 12, 6), _c("#7A5A5A"), 3)
	ci.draw_arc(Vector2(-48, -50), 7.0, 0.5, 5.6, 14, _c("#E898A6"), 4.0, true)
	Painter.ellipse(ci, Vector2(0, -42), 46, 30, _c("#F6B5C0"))
	Painter.ellipse(ci, Vector2(0, -28), 38, 14, _c("#F9C5CD"))
	var h: Vector2 = HEAD["pig"]
	Painter.poly(ci, [h + Vector2(-16, -14), h + Vector2(-2, -26), h + Vector2(2, -10)], _c("#E898A6"))
	Painter.poly(ci, [h + Vector2(8, -18), h + Vector2(20, -24), h + Vector2(16, -6)], _c("#E898A6"))
	ci.draw_circle(h, 22, _c("#F6B5C0"))
	Painter.ellipse(ci, h + Vector2(17, 4), 12, 10, _c("#EE8FA0"))
	ci.draw_circle(h + Vector2(14, 4), 2.3, _c("#A55868"))
	ci.draw_circle(h + Vector2(21, 4), 2.3, _c("#A55868"))
	_eye(ci, h + Vector2(5, -6), 3.2, blink)


static func _sheep(ci: CanvasItem, blink: bool, sw: float) -> void:
	var lx := [-26.0, -10.0, 20.0, 36.0]
	for i in range(4):
		var off := sw * (0.4 if i % 2 == 0 else -0.4)
		Painter.rrect(ci, Rect2(lx[i] - 4.0 + off, -32, 8, 32), _c("#5A4A42"), 3)
	var wool := [Vector2(-34, -50), Vector2(-12, -66), Vector2(14, -64), Vector2(34, -48), Vector2(-28, -32), Vector2(0, -38), Vector2(26, -34)]
	for i in range(wool.size()):
		ci.draw_circle(wool[i], 23.0, _c("#F6F1E3") if i % 2 == 0 else _c("#EDE6D2"))
	var h: Vector2 = HEAD["sheep"]
	Painter.ellipse(ci, h + Vector2(-12, 0), 13, 6, _c("#7A6450"), 12)
	Painter.ellipse(ci, h, 15, 18, _c("#8A7360"))
	ci.draw_circle(h + Vector2(-2, -18), 11, _c("#F6F1E3"))
	ci.draw_circle(h + Vector2(8, 10), 3.0, _c("#5A4A42"))
	_eye(ci, h + Vector2(6, -4), 3.0, blink)


static func _rabbit(ci: CanvasItem, blink: bool, sw: float) -> void:
	Painter.ellipse(ci, Vector2(-16, -6), 17, 8, _c("#E3DACB"), 14)
	Painter.ellipse(ci, Vector2(18, -4), 9, 5, _c("#E3DACB"), 12)
	ci.draw_circle(Vector2(-30, -30), 10, _c("#FFFFFF"))
	Painter.ellipse(ci, Vector2(0, -26), 27, 22, _c("#E3DACB"))
	Painter.ellipse(ci, Vector2(6, -18), 20, 12, _c("#F1EBDF"))
	var h: Vector2 = HEAD["rabbit"]
	var ear := sin(sw * 0.2) * 0.05
	_erot(ci, h + Vector2(-5, -28), 6.5, 23, -0.18 + ear, _c("#E3DACB"))
	_erot(ci, h + Vector2(7, -28), 6.5, 23, 0.16 - ear, _c("#E3DACB"))
	_erot(ci, h + Vector2(-5, -28), 3.2, 17, -0.18 + ear, _c("#F2B8C2"))
	_erot(ci, h + Vector2(7, -28), 3.2, 17, 0.16 - ear, _c("#F2B8C2"))
	ci.draw_circle(h, 16, _c("#EBE3D6"))
	ci.draw_circle(h + Vector2(14, 5), 3.0, _c("#E58CA0"))
	ci.draw_line(h + Vector2(12, 7), h + Vector2(26, 5), Color(0.4, 0.35, 0.3, 0.6), 1.5)
	ci.draw_line(h + Vector2(12, 9), h + Vector2(26, 12), Color(0.4, 0.35, 0.3, 0.6), 1.5)
	_eye(ci, h + Vector2(7, -3), 3.0, blink)


static func _accessories(ci: CanvasItem, species: String, cosmetics: Array, t: float, peck: float) -> void:
	if cosmetics.is_empty():
		return
	var h: Vector2 = HEAD[species]
	if species == "chicken":
		h += Vector2(peck * 12.0, peck * 20.0)
	var r: float = HEAD_R[species]
	var top := h + Vector2(0, -r * (1.55 if species == "rabbit" else 0.95))
	if species == "rabbit":
		top = h + Vector2(1, -r * 0.8)
	if cosmetics.has("flower"):
		var cs := ["#F28BB0", "#FFFFFF", "#F6A04A"]
		for i in range(3):
			var p := top + Vector2(float(i - 1) * r * 0.75, float(absi(i - 1)) * 3.0)
			for k in range(5):
				var a := TAU * float(k) / 5.0 + t * 0.2
				ci.draw_circle(p + Vector2(cos(a), sin(a)) * 3.8, 3.0, _c(cs[i]))
			ci.draw_circle(p, 2.4, _c("#F6D84A"))
	if cosmetics.has("bow"):
		var b := h + Vector2(-r * 0.55, -r * 0.55)
		Painter.poly(ci, [b, b + Vector2(-11, -8), b + Vector2(-11, 8)], _c("#E8587A"))
		Painter.poly(ci, [b, b + Vector2(11, -8), b + Vector2(11, 8)], _c("#E8587A"))
		ci.draw_circle(b, 4.0, _c("#C93E60"))
	if cosmetics.has("crown"):
		var c := top + Vector2(0, -9)
		ci.draw_line(c + Vector2(-16, 5), c + Vector2(16, 5), _c("#F2C94C"), 4.0, true)
		for i in range(5):
			var q := c + Vector2(-16.0 + float(i) * 8.0, 0)
			Painter.poly(ci, [q + Vector2(-4, 5), q + Vector2(0, -8), q + Vector2(4, 5)], _c("#F2C94C"))
			ci.draw_circle(q + Vector2(0, -8), 2.2, _c("#E8587A") if i % 2 == 0 else _c("#7ACBE0"))
		var tw := 0.5 + 0.5 * sin(t * 4.0)
		Painter.star(ci, c + Vector2(20, -10), 4.0 + tw * 2.0, Color(1, 0.95, 0.6, 0.6 + 0.4 * tw))
