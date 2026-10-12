extends Node2D
## Zeichnet Felder, Pflanzen (mit Wachstumsphasen und sanftem Wiegen) und die
## Böden der Gehege. Nur sichtbare Felder werden gezeichnet.

var t := 0.0
var _acc := 0.0
var _pop: Dictionary = {}     ## Vector2i -> Startzeit (ms) der Pflanz-Animation
var highlight: Array = []     ## Zellen mit zusätzlicher Markierung


func _ready() -> void:
	# Nach dem Terrain (z = 0), vor den Objekten (z = 2) zeichnen.
	z_index = 1
	z_as_relative = true
	GameState.world_changed.connect(_on_world_changed)
	GameState.animals_changed.connect(_on_world_changed)
	queue_redraw()


func _on_world_changed() -> void:
	queue_redraw()


func pop(cell: Vector2i) -> void:
	_pop[cell] = Time.get_ticks_msec()


func _process(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc >= 0.05:
		_acc = 0.0
		queue_redraw()


func _view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(-100000, -100000, 200000, 200000)
	var size := get_viewport_rect().size / cam.zoom.x
	return Rect2(cam.position - size * 0.5, size).grow(160.0)


func _draw() -> void:
	var T := float(GameData.TILE)
	var view := _view()
	for o in GameState.objects:
		if o.kind == "paddock":
			var sz := GameData.object_size(o.type)
			var r := Rect2(Vector2(o.cell) * T, Vector2(sz) * T)
			if r.intersects(view):
				Painter.draw_paddock_back(self, r)
	var now_ms := Time.get_ticks_msec()
	var cells: Array = GameState.fields.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell in cells:
		var pos := Vector2(cell) * T
		if not Rect2(pos, Vector2(T, T)).intersects(view):
			continue
		Painter.draw_field(self, pos)
		var f: Dictionary = GameState.fields[cell]
		if f.crop == "":
			continue
		var stage := GameState.crop_stage(cell)
		var pop_s := 1.0
		if _pop.has(cell):
			var k := float(now_ms - int(_pop[cell])) / 380.0
			if k >= 1.0:
				_pop.erase(cell)
			else:
				pop_s = 0.25 + 0.75 * (1.0 + 0.35 * sin(k * PI)) * k + 0.0
				pop_s = clampf(pop_s, 0.2, 1.25)
		Painter.draw_crop(self, f.crop, stage, pos + Vector2(T, T) * 0.5, t, pop_s)
		if stage == 3:
			var bob := sin(t * 3.0 + pos.x * 0.01) * 4.0
			var c := pos + Vector2(T * 0.5, -14.0 + bob)
			draw_circle(c, 24.0, Color(1, 0.97, 0.88, 0.95))
			draw_arc(c, 24.0, 0.0, TAU, 24, Painter.col("#E0B93C"), 3.0, true)
			Painter.draw_item(self, f.crop, c, 34.0)
	for cell in highlight:
		draw_rect(Rect2(Vector2(cell) * T + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(1, 1, 1, 0.22), true)
