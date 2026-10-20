extends Node2D
## Statisches Gelände: Wiese, wachsende Wildnis rings um die Farm und der Zaun.
## Die Fläche wird in Chunks (8×8 Zellen) prozedural erzeugt. Nur Chunks im
## sichtbaren Kamerabereich werden instanziiert und gezeichnet; außerhalb der
## Farm ist dadurch nie leere Fläche, sondern immer Wald und Wiese.

const CHUNK_CELLS := 8

var _land_cache := Rect2i()
var _chunks: Dictionary = {}  ## Vector2i -> Chunk
var _fence: Node2D
var _view_cache := Rect2()


## Ein Chunk zeichnet Grundfläche und – eine Ebene darüber – den Bewuchs.
## Zwei Ebenen verhindern, dass die Wiese des Nachbar-Chunks Baumkronen
## übermalt, die über die Chunkgrenze ragen.
class Chunk extends Node2D:
	var terrain
	var coord := Vector2i.ZERO
	var bounds := Rect2i()

	func _ready() -> void:
		var props := Props.new()
		props.terrain = terrain
		props.bounds = bounds
		props.z_index = 1
		add_child(props)

	func _draw() -> void:
		terrain.draw_ground(self, bounds)


class Props extends Node2D:
	var terrain
	var bounds := Rect2i()

	func _draw() -> void:
		terrain.draw_props(self, bounds)


## Der Zaun liegt über den Chunks, damit Rasen und Bäume ihn nie verdecken.
class Fence extends Node2D:
	var terrain

	func _draw() -> void:
		terrain.draw_fence(self)


func _ready() -> void:
	z_index = 0
	z_as_relative = true
	GameState.world_changed.connect(_on_world_changed)
	_land_cache = GameState.land
	_fence = Fence.new()
	_fence.terrain = self
	_fence.z_index = 2
	add_child(_fence)
	_refresh_chunks()
	call_deferred("_refresh_chunks")


func _process(_delta: float) -> void:
	# Die Kamera kann sich per Wisch, Zoom oder Tween bewegen: Chunks wandern
	# mit, sobald sich der Ausschnitt ändert. Neue Chunks entstehen nur am Rand.
	var view := visible_world_rect()
	if view == _view_cache:
		return
	_view_cache = view
	_refresh_chunks()


func _on_world_changed() -> void:
	if GameState.land == _land_cache:
		return
	_land_cache = GameState.land
	for chunk in _chunks.values():
		chunk.queue_redraw()
		for child in chunk.get_children():
			child.queue_redraw()
	if _fence != null:
		_fence.queue_redraw()


# --------------------------------------------------------------- Geometrie

static func world_bounds() -> Rect2i:
	return Rect2i(GameData.WORLD_ORIGIN, Vector2i(GameData.WORLD_COLS, GameData.WORLD_ROWS))


## Weltkarte plus der prozedural erzeugte Wildnisgürtel drumherum.
static func scenery_bounds() -> Rect2i:
	var margin := GameData.SCENERY_MARGIN_CELLS
	return world_bounds().grow(margin)


static func chunk_bounds(coord: Vector2i) -> Rect2i:
	var scenery := scenery_bounds()
	var raw := Rect2i(scenery.position + coord * CHUNK_CELLS, Vector2i(CHUNK_CELLS, CHUNK_CELLS))
	return raw.intersection(scenery)


## Chunk-Koordinaten, die einen Weltbereich (Pixel) abdecken – inklusive Rand,
## damit beim Schwenken keine Lücke aufblitzt.
static func chunk_coords_for(area: Rect2, margin_chunks: int = 1) -> Array:
	var scenery := scenery_bounds()
	var T := float(GameData.TILE)
	var pad := margin_chunks * CHUNK_CELLS
	var lo := Vector2i(floori(area.position.x / T) - pad, floori(area.position.y / T) - pad)
	var hi := Vector2i(ceili(area.end.x / T) + pad, ceili(area.end.y / T) + pad)
	lo = Vector2i(maxi(lo.x, scenery.position.x), maxi(lo.y, scenery.position.y))
	hi = Vector2i(mini(hi.x, scenery.end.x), mini(hi.y, scenery.end.y))
	var out: Array = []
	if lo.x >= hi.x or lo.y >= hi.y:
		return out
	var first := Vector2i((lo.x - scenery.position.x) / CHUNK_CELLS, (lo.y - scenery.position.y) / CHUNK_CELLS)
	var last := Vector2i((hi.x - 1 - scenery.position.x) / CHUNK_CELLS, (hi.y - 1 - scenery.position.y) / CHUNK_CELLS)
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var cell_rect := chunk_bounds(Vector2i(cx, cy))
			if cell_rect.size.x > 0 and cell_rect.size.y > 0:
				out.append(Vector2i(cx, cy))
	return out


## Sichtbarer Weltausschnitt in Pixeln, aus der aktuellen Kamera-Transform.
func visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var inv := viewport.get_canvas_transform().affine_inverse()
	var size := viewport.get_visible_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * size
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _refresh_chunks() -> void:
	var needed := {}
	for coord in chunk_coords_for(visible_world_rect()):
		needed[coord] = true
		if not _chunks.has(coord):
			var chunk := Chunk.new()
			chunk.terrain = self
			chunk.coord = coord
			chunk.bounds = chunk_bounds(coord)
			add_child(chunk)
			_chunks[coord] = chunk
	for coord in _chunks.keys():
		if needed.has(coord):
			continue
		_chunks[coord].queue_free()
		_chunks.erase(coord)


# ---------------------------------------------------------------- Zeichnen

static func hash_at(x: int, y: int, salt: int = 0) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n) % 10000) / 10000.0


## Grundfläche eines Chunks: gepflegter Rasen im Land, Wildnis außerhalb.
func draw_ground(ci: CanvasItem, bounds: Rect2i) -> void:
	var T := GameData.TILE
	var land: Rect2i = GameState.land
	var world := world_bounds()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var h := hash_at(x, y)
			var inside := land.has_point(cell)
			var color: Color
			if inside:
				color = Painter.col("#9CCB7C") if (x + y) % 2 == 0 else Painter.col("#94C575")
				color = color.lightened(h * 0.04)
			elif world.has_point(cell):
				color = Painter.col("#7BB367").darkened(0.06 + h * 0.08)
			else:
				color = Painter.col("#74AC5F").darkened(0.1 + h * 0.1)
			ci.draw_rect(Rect2(x * T, y * T, T + 1, T + 1), color)


## Bewuchs eines Chunks: Bäume, Büsche, Steine, Gras und Blumen.
func draw_props(ci: CanvasItem, bounds: Rect2i) -> void:
	var T := GameData.TILE
	var land: Rect2i = GameState.land
	var world := world_bounds()
	var near_land := land.grow(3)
	var land_edge := land.grow(2)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var base := Vector2(x * T + 30.0 + hash_at(x, y, 1) * 68.0, y * T + 96.0 + hash_at(x, y, 2) * 20.0)
			if land.has_point(cell):
				if hash_at(x, y, 7) < 0.1:
					Painter.tuft(ci, Vector2(x * T + 30.0 + hash_at(x, y, 8) * 70.0, y * T + 100), 0.7, 0.0)
				continue
			var r := hash_at(x, y, 3)
			if land_edge.has_point(cell):
				# Schmaler Saum direkt am Zaun: nur niedriges Gras und Blumen.
				if r < 0.34:
					Painter.tuft(ci, base, 0.9 + hash_at(x, y, 5) * 0.2, 0.0)
				elif r < 0.46:
					Painter.flower_dot(ci, base - Vector2(0, 14), 1.0, Painter.col(_flower_colors()[int(hash_at(x, y, 9) * 4.0) % 4]))
				continue
			var wild := not world.has_point(cell)
			var tree_chance := 0.5 if wild else 0.1
			if near_land.has_point(cell):
				tree_chance = 0.02
			if r < tree_chance:
				var scale := 0.95 + hash_at(x, y, 4) * 0.4
				Painter.tree(ci, base, scale, 0.0, 0.12 if wild else 0.04)
			elif r < tree_chance + 0.18:
				Painter.bush(ci, base, 0.9 + hash_at(x, y, 5) * 0.3, r < tree_chance + 0.08)
			elif r < tree_chance + 0.24:
				Painter.rock(ci, base, 0.8 + hash_at(x, y, 6) * 0.5)
			elif r < tree_chance + 0.62:
				Painter.tuft(ci, base, 1.0, 0.0)
			elif r < tree_chance + 0.72:
				Painter.flower_dot(ci, base - Vector2(0, 14), 1.0, Painter.col(_flower_colors()[int(hash_at(x, y, 9) * 4.0) % 4]))


static func _flower_colors() -> Array:
	return ["#F28BB0", "#F6D84A", "#FFFFFF", "#B79AE8"]


func draw_fence(ci: CanvasItem) -> void:
	var T := GameData.TILE
	var land: Rect2i = GameState.land
	var x0 := float(land.position.x * T)
	var x1 := float(land.end.x * T)
	var y0 := float(land.position.y * T)
	var y1 := float(land.end.y * T)
	Painter._fence_h(ci, x0 + 8.0, x1 - 8.0, y0 + 6.0)
	Painter._post_line(ci, x0 + 8.0, y0 + 6.0, y1)
	Painter._post_line(ci, x1 - 8.0, y0 + 6.0, y1)
	Painter._fence_h(ci, x0 + 8.0, x1 - 8.0, y1 + 2.0)
