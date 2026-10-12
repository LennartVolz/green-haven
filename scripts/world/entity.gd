extends Node2D
## Ein platziertes Objekt der Farm: Produktionsgebäude, Gehege-Zaun (vorne)
## oder Dekoration. Position = Mitte der Unterkante der Grundfläche, damit die
## Tiefensortierung (y-sort) funktioniert.

var uid := 0
var kind := ""
var type := ""
var cell := Vector2i.ZERO
var selected := false
var t := 0.0
var _acc := 0.0


func setup(obj: Dictionary) -> void:
	uid = int(obj.uid)
	kind = obj.kind
	type = obj.type
	cell = obj.cell
	var sz := GameData.object_size(type)
	var T := GameData.TILE
	position = Vector2((cell.x + sz.x * 0.5) * T, (cell.y + sz.y) * T)
	t = randf() * 10.0
	queue_redraw()


func footprint_rect() -> Rect2:
	var sz := GameData.object_size(type)
	var T := float(GameData.TILE)
	return Rect2(Vector2(cell) * T, Vector2(sz) * T)


## Tippfläche in Weltkoordinaten (Gebäude reichen nach oben über die Grundfläche).
func hit_rect() -> Rect2:
	var r := footprint_rect()
	if kind == "production":
		return Rect2(r.position + Vector2(-10, -120), r.size + Vector2(20, 120))
	if kind == "deco":
		return Rect2(r.position + Vector2(0, -70), r.size + Vector2(0, 70))
	return r


func _process(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc >= 0.05:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	match kind:
		"production":
			var o := GameState.get_object(uid)
			var working := false
			var ready := 0
			if not o.is_empty():
				ready = GameState.ready_count(o)
				working = (o.queue as Array).size() > ready
			Painter.draw_building(self, type, t, working)
			_draw_status(o, ready, working)
		"paddock":
			Painter.draw_paddock_front(self, footprint_rect().size.x)
		"deco":
			Painter.draw_deco(self, type, t)
	if selected:
		var r := hit_rect()
		var local := Rect2(r.position - position, r.size)
		draw_rect(local, Color(1, 1, 1, 0.12 + 0.08 * sin(t * 6.0)), true)
		draw_rect(local, Painter.col("#FFFFFF"), false, 4.0)


func _draw_status(o: Dictionary, ready: int, working: bool) -> void:
	if o.is_empty():
		return
	var q: Array = o.queue
	if ready > 0:
		var bob := sin(t * 4.0) * 5.0
		var c := Vector2(0, -262 + bob)
		draw_circle(c, 34.0, Color(1, 0.97, 0.88, 0.97))
		draw_arc(c, 34.0, 0.0, TAU, 28, Painter.col("#8DB580"), 4.0, true)
		Painter.draw_item(self, q[0]["recipe"], c, 46.0)
		if ready > 1:
			draw_circle(c + Vector2(26, -24), 14.0, Painter.col("#E0783A"))
			draw_string(ThemeDB.fallback_font, c + Vector2(19, -17), str(ready), HORIZONTAL_ALIGNMENT_CENTER, 14, 22, Color.WHITE)
	elif working:
		var e: Dictionary = q[0]
		var p := GameState.entry_progress(e)
		var w := 120.0
		Painter.rrect(self, Rect2(-w * 0.5, -250, w, 18), Color(0, 0, 0, 0.35), 9)
		Painter.rrect(self, Rect2(-w * 0.5 + 2, -248, maxf(14.0, (w - 4.0) * p), 14), Painter.col("#8DB580"), 7)
		Painter.draw_item(self, e["recipe"], Vector2(0, -276), 36.0)
