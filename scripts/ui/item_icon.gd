class_name ItemIcon
extends Control
## Zeichnet das Symbol eines Gegenstands (Feldfrucht, Zutat, Produkt).

var item_id := ""
var dim := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	Painter.draw_item(self, item_id, size * 0.5, s * 0.92)
	if dim:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.45), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
