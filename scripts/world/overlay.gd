extends Node2D
## Effekte über der Spielwelt: schwebende Zahlen/Texte und kleine Partikel
## als sichtbare Rückmeldung für Pflanzen, Ernten und Abholen.

var _pops: Array = []        ## {text, pos, age, color}
var _parts: Array = []       ## {pos, vel, age, life, color, size}
var _weather_drops: Array = []
var _weather_time := 0.0
var _weather_acc := 0.0
var current_weather := "Sonnig"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 100
	_rng.randomize()


func set_weather(weather: String) -> void:
	current_weather = weather
	set_process(current_weather != "Sonnig" or not _pops.is_empty() or not _parts.is_empty() or not _weather_drops.is_empty())
	queue_redraw()


func _weather_view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(-540.0, -960.0, 1080.0, 1920.0)
	var size := get_viewport_rect().size / cam.zoom.x
	return Rect2(cam.position - size * 0.5, size)


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
	_weather_time += delta
	if current_weather == "Regen":
		_weather_acc += delta
		while _weather_acc >= 0.05 and _weather_drops.size() < 90:
			_weather_acc -= 0.05
			var view := _weather_view()
			_weather_drops.append({
				"pos": Vector2(_rng.randf_range(view.position.x, view.end.x), view.position.y - 30.0),
				"age": 0.0,
				"length": _rng.randf_range(18.0, 34.0),
			})
	for drop in _weather_drops:
		drop.age += delta
		drop.pos += Vector2(190.0, 650.0) * delta
	_weather_drops = _weather_drops.filter(func(drop: Dictionary) -> bool: return drop.age < 4.5)
	if _pops.is_empty() and _parts.is_empty() and _weather_drops.is_empty() and current_weather == "Sonnig":
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
	var view := _weather_view()
	match current_weather:
		"Bewölkt":
			var cloud := Color(0.72, 0.78, 0.83, 0.52)
			for i in range(3):
				var x := view.position.x + fposmod(_weather_time * 12.0 + view.size.x * float(i) / 3.0, view.size.x + 240.0) - 120.0
				var y := view.position.y + 150.0 + float(i % 2) * 55.0
				Painter.ellipse(self, Vector2(x, y), 92.0, 23.0, cloud)
				Painter.ellipse(self, Vector2(x - 24.0, y - 12.0), 35.0, 28.0, cloud)
				Painter.ellipse(self, Vector2(x + 18.0, y - 17.0), 42.0, 35.0, cloud)
		"Regen":
			for drop in _weather_drops:
				var alpha := clampf(1.0 - drop.age / 4.5, 0.0, 1.0) * 0.52
				draw_line(drop.pos, drop.pos + Vector2(-5.0, drop.length), Color(0.68, 0.84, 0.97, alpha), 3.0, true)
		"Nebel":
			var fog := Color(0.88, 0.93, 0.91, 0.20)
			for i in range(4):
				var phase := _weather_time * 9.0 + float(i) * 240.0
				var x := view.position.x + fposmod(phase, view.size.x + 360.0) - 180.0
				var y := view.position.y + view.size.y * (0.42 + float(i) * 0.13)
				Painter.ellipse(self, Vector2(x, y), view.size.x * 0.48, 42.0, fog)
				Painter.ellipse(self, Vector2(x + 110.0, y + 8.0), view.size.x * 0.36, 32.0, fog)
			"Sonnig":
				pass
	queue_redraw()
