extends Node2D
## Effekte über der Spielwelt: schwebende Zahlen/Texte und kleine Partikel
## als sichtbare Rückmeldung für Pflanzen, Ernten und Abholen.

var _pops: Array = []        ## {text, pos, age, color}
var _parts: Array = []       ## {pos, vel, age, life, color, size}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 100
	_rng.randomize()


func add_fx(kind: String, pos: Vector2, text: String) -> void:
	match kind:
		"plant":
			burst(pos + Vector2(0, 20), Painter.col("#B98B55"), 7, 70.0)
		"harvest":
			burst(pos, Painter.col("#F6D84A"), 10, 110.0)
			burst(pos, Painter.col("#9BD06A"), 6, 90.0)
			add_text(pos + Vector2(0, -30), text, Painter.col("#FFFFFF"))
		"collect":
			burst(pos, Painter.col("#F6D84A"), 12, 120.0)
			add_text(pos + Vector2(0, -40), text, Painter.col("#FFFFFF"))
		"coin":
			burst(pos, Painter.col("#F4C95D"), 8, 100.0)
			add_text(pos, text, Painter.col("#F4C95D"))


func add_text(pos: Vector2, text: String, color: Color) -> void:
	_pops.append({"text": text, "pos": pos, "age": 0.0, "color": color})
	set_process(true)


func burst(pos: Vector2, color: Color, n: int, speed: float) -> void:
	for i in range(n):
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.7 - 0.5) * _rng.randf_range(0.4, 1.0) * speed
		_parts.append({"pos": pos, "vel": v, "age": 0.0, "life": _rng.randf_range(0.4, 0.8), "color": color, "size": _rng.randf_range(3.0, 7.0)})
	set_process(true)


func _process(delta: float) -> void:
	if _pops.is_empty() and _parts.is_empty():
		set_process(false)
		queue_redraw()
		return
	for p in _pops:
		p.age += delta
		p.pos += Vector2(0, -46.0) * delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.age < 1.2)
	for q in _parts:
		q.age += delta
		q.vel += Vector2(0, 220.0) * delta
		q.pos += q.vel * delta
	_parts = _parts.filter(func(q: Dictionary) -> bool: return q.age < q.life)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for p in _pops:
		var a := clampf(1.0 - (p.age - 0.6) / 0.6, 0.0, 1.0)
		var c: Color = p.color
		c.a = a
		var oc := Color(0.25, 0.18, 0.1, a)
		draw_string_outline(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 34, 8, oc)
		draw_string(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 34, c)
	for q in _parts:
		var col: Color = q.color
		col.a = clampf(1.0 - q.age / q.life, 0.0, 1.0)
		draw_circle(q.pos, q.size * (1.0 - 0.5 * q.age / q.life), col)
