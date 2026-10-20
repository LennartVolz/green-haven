extends Node2D
## Zeichnet wilde Sammelstellen außerhalb des Zauns. Die Fundstellen ergeben
## sich deterministisch aus der Zellposition (GameData.forage_at), gespeichert
## werden nur die Nachwuchszeiten. Es werden ausschließlich Zellen im
## sichtbaren Kamerabereich geprüft.

var _view_cache := Rect2()
var _acc := 0.0


func _ready() -> void:
	# Über dem Gelände und den Feldern, unter Gebäuden und Tieren.
	z_index = 1
	z_as_relative = true
	GameState.forage_changed.connect(queue_redraw)
	GameState.world_changed.connect(queue_redraw)
	call_deferred("queue_redraw")


func _process(delta: float) -> void:
	var view := view_rect()
	if view != _view_cache:
		_view_cache = view
		queue_redraw()
		return
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	# Nachwuchs wird sichtbar, sobald die Zeit abgelaufen ist.
	if not GameState.forage.is_empty():
		queue_redraw()


func view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var cam := viewport.get_camera_2d()
	if cam == null:
		return Rect2(-100000, -100000, 200000, 200000)
	var half := get_viewport_rect().size / cam.zoom.x * 0.5
	return Rect2(cam.position - half, half * 2.0)


func _draw() -> void:
	var view := view_rect()
	var T := GameData.TILE
	var first := Vector2i(floori(view.position.x / T), floori(view.position.y / T))
	var last := Vector2i(ceili(view.end.x / T), ceili(view.end.y / T))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var id := GameState.forage_spot_at(cell)
			if id == "" or GameState.level < int(GameData.FORAGE[id]["level"]):
				continue
			var ready := GameState.forage_ready(cell)
			var base := Vector2(x * T + T * 0.5, y * T + T * 0.82)
			Painter.draw_forage(self, id, base, ready)
			if ready:
				# Sanfter Hinweis, dass hier geerntet werden kann.
				Painter.ellipse(self, base + Vector2(0, -46), 26, 12, Color(1.0, 0.96, 0.7, 0.18))
