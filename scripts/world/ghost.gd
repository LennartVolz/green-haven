extends Node2D
## Vorschau beim Platzieren/Verschieben: halbtransparentes Objekt auf einer
## grün (frei) oder rot (belegt) eingefärbten Grundfläche.

var type := ""
var valid := true
var t := 0.0


func _ready() -> void:
	z_index = 50
	visible = false
	modulate = Color(1, 1, 1, 0.82)


func show_ghost(obj_type: String, cell: Vector2i, is_valid: bool) -> void:
	type = obj_type
	valid = is_valid
	var sz := GameData.object_size(type)
	var T := GameData.TILE
	position = Vector2((cell.x + sz.x * 0.5) * T, (cell.y + sz.y) * T)
	visible = true
	queue_redraw()


func hide_ghost() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()


func _draw() -> void:
	if type == "":
		return
	var sz := GameData.object_size(type)
	var T := float(GameData.TILE)
	var w := sz.x * T
	var h := sz.y * T
	var tint := Color(0.35, 0.8, 0.35, 0.45) if valid else Color(0.9, 0.3, 0.3, 0.5)
	Painter.rrect(self, Rect2(-w * 0.5 + 4, -h + 4, w - 8, h - 8), tint, 18)
	var d := GameData.object_def(type)
	match String(d["kind"]):
		"production":
			Painter.draw_building(self, type, t, false)
		"paddock":
			Painter.draw_paddock_back(self, Rect2(-w * 0.5, -h, w, h))
			Painter.draw_paddock_front(self, w)
		"deco":
			Painter.draw_deco(self, type, t)
	Painter.rrect(self, Rect2(-w * 0.5 + 4, -h + 4, w - 8, h - 8), Color(tint.r, tint.g, tint.b, 0.18), 18)
