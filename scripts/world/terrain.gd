extends Node2D
## Statisches Gelände: Wiese, verwilderter Rand und der Zaun um das eigene Land.
## Wird nur neu gezeichnet, wenn sich das Land ändert.

var _land_cache := Rect2i()


func _ready() -> void:
	z_index = -20
	GameState.world_changed.connect(_on_world_changed)
	_land_cache = GameState.land
	queue_redraw()


func _on_world_changed() -> void:
	if GameState.land != _land_cache:
		_land_cache = GameState.land
		queue_redraw()


static func _hash(x: int, y: int, salt: int = 0) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n) % 10000) / 10000.0


func _draw() -> void:
	var T := GameData.TILE
	var cols := GameData.WORLD_COLS
	var rows := GameData.WORLD_ROWS
	var land := GameState.land
	draw_rect(Rect2(-400, -400, cols * T + 800, rows * T + 800), Painter.col("#6FA354"))
	for y in range(rows):
		for x in range(cols):
			var h := _hash(x, y)
			var inside := land.has_point(Vector2i(x, y))
			var c: Color
			if inside:
				c = Painter.col("#9CCB7C") if (x + y) % 2 == 0 else Painter.col("#94C575")
				c = c.lightened(h * 0.04)
			else:
				c = Painter.col("#7BB367").darkened(0.06 + h * 0.08)
			draw_rect(Rect2(x * T, y * T, T + 1, T + 1), c)
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			if land.has_point(cell):
				if _hash(x, y, 7) < 0.1:
					Painter.tuft(self, Vector2(x * T + 30 + _hash(x, y, 8) * 70.0, y * T + 100), 0.7, 0.0)
				continue
			var base := Vector2(x * T + 30.0 + _hash(x, y, 1) * 68.0, y * T + 96.0 + _hash(x, y, 2) * 20.0)
			var r := _hash(x, y, 3)
			var edge := x < 2 or y < 2 or x >= cols - 2 or y >= rows - 2
			if edge and r < 0.75:
				Painter.tree(self, base, 0.95 + _hash(x, y, 4) * 0.4, 0.0, 0.1)
			elif r < 0.07:
				Painter.tree(self, base, 0.9, 0.0, 0.05)
			elif r < 0.2:
				Painter.bush(self, base, 0.9 + _hash(x, y, 5) * 0.3, r < 0.11)
			elif r < 0.27:
				Painter.rock(self, base, 0.8 + _hash(x, y, 6) * 0.5)
			elif r < 0.45:
				Painter.tuft(self, base, 1.0, 0.0)
			elif r < 0.52:
				var fc := ["#F28BB0", "#F6D84A", "#FFFFFF", "#B79AE8"]
				Painter.flower_dot(self, base - Vector2(0, 14), 1.0, Painter.col(fc[int(_hash(x, y, 9) * 4.0) % 4]))
	# Zaun um das eigene Land
	var x0 := float(land.position.x * T)
	var x1 := float(land.end.x * T)
	var y0 := float(land.position.y * T)
	var y1 := float(land.end.y * T)
	Painter._fence_h(self, x0 + 8.0, x1 - 8.0, y0 + 6.0)
	Painter._post_line(self, x0 + 8.0, y0 + 6.0, y1)
	Painter._post_line(self, x1 - 8.0, y0 + 6.0, y1)
	Painter._fence_h(self, x0 + 8.0, x1 - 8.0, y1 + 2.0)
