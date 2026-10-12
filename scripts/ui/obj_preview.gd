class_name ObjPreview
extends Control
## Kleine Vorschau eines Objekts (Gebäude, Deko, Gehege oder Tier) für Listen.
## Die Zeichnung läuft in einem skalierten Node2D-Kind, damit Painter-Funktionen
## ihre eigenen Transformationen setzen dürfen.

class Drawer extends Node2D:
	var mode := "object"    ## "object" oder "animal"
	var type := ""
	var cosmetics: Array = []
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if mode == "animal":
			AnimalPainter.draw(self, type, t, false, false, cosmetics, 0.0, 1.0)
			return
		var d := GameData.object_def(type)
		match String(d.get("kind", "")):
			"production":
				Painter.draw_building(self, type, t, true)
			"paddock":
				Painter.draw_paddock_back(self, Rect2(-256, -384, 512, 384))
				Painter.draw_paddock_front(self, 512.0)
			"deco":
				Painter.draw_deco(self, type, t)

var _drawer: Drawer
var _extent := Vector2(300, 300)


func setup(mode: String, type: String, cosmetics: Array = []) -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_drawer = Drawer.new()
	_drawer.mode = mode
	_drawer.type = type
	_drawer.cosmetics = cosmetics
	add_child(_drawer)
	if mode == "animal":
		_extent = Vector2(210, 175)
	else:
		var sz := GameData.object_size(type)
		match String(GameData.object_def(type).get("kind", "")):
			"production":
				_extent = Vector2(300, 300)
			"paddock":
				_extent = Vector2(540, 400)
			_:
				_extent = Vector2(float(sz.x) * 140.0 + 30.0, 190.0 + float(sz.y - 1) * 60.0)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


func _fit() -> void:
	if _drawer == null:
		return
	var s := minf(size.x / _extent.x, size.y / _extent.y)
	_drawer.scale = Vector2(s, s)
	_drawer.position = Vector2(size.x * 0.5, size.y * 0.96)
