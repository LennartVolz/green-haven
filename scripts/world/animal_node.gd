extends Node2D
## Ein gerettetes Tier, das im Gehege umherstreift. Reagiert auf Streicheln
## (Herzchen) und zeigt in einer Sprechblase, wenn es Futter oder Zuwendung mag.

var uid := 0
var species := ""
var bounds := Rect2()
var t := 0.0
var flip := false
var walking := false
var peck := 0.0

var _target := Vector2.ZERO
var _wait := 1.0
var _heart_t := -1.0


func setup(a: Dictionary, paddock: Dictionary) -> void:
	var first := uid == 0
	uid = int(a.uid)
	species = a.species
	var T := float(GameData.TILE)
	var sz := GameData.object_size(paddock.type)
	var r := Rect2(Vector2(paddock.cell) * T, Vector2(sz) * T)
	bounds = Rect2(r.position + Vector2(44, 76), r.size - Vector2(88, 96))
	if first:
		t = randf() * 10.0
		position = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
		_target = position
		_wait = randf_range(0.5, 2.5)
	else:
		position = Vector2(clampf(position.x, bounds.position.x, bounds.end.x), clampf(position.y, bounds.position.y, bounds.end.y))


func hit(p: Vector2) -> bool:
	return p.distance_to(position + Vector2(0, -44)) < 62.0


func petted() -> void:
	_heart_t = 0.0
	_wait = maxf(_wait, 1.5)
	walking = false


func _speed() -> float:
	match species:
		"rabbit":
			return 70.0
		"chicken":
			return 55.0
		"cow":
			return 28.0
	return 38.0


func _process(delta: float) -> void:
	t += delta
	if _heart_t >= 0.0:
		_heart_t += delta
		if _heart_t > 1.4:
			_heart_t = -1.0
	if walking:
		var d := _target - position
		var step := _speed() * delta
		if d.length() <= step:
			position = _target
			walking = false
			_wait = randf_range(1.5, 4.5)
		else:
			position += d.normalized() * step
			flip = d.x < 0.0
	else:
		_wait -= delta
		peck = maxf(0.0, sin(t * 7.0)) if species == "chicken" and fmod(t, 5.0) < 2.0 else 0.0
		if _wait <= 0.0:
			_target = Vector2(randf_range(bounds.position.x, bounds.end.x), randf_range(bounds.position.y, bounds.end.y))
			walking = true
	queue_redraw()


func _draw() -> void:
	var a := GameState.get_animal(uid)
	if a.is_empty():
		return
	AnimalPainter.draw(self, species, t, flip, walking, GameState.cosmetics_of(a), peck, 1.0)
	# Stimmungsblase
	var hunger := GameState.animal_stat(a, "hunger")
	var happy := GameState.animal_stat(a, "happy")
	if hunger < 45.0 or happy < 45.0:
		var c := Vector2(0, -150.0 + sin(t * 3.0) * 4.0)
		draw_circle(c, 24.0, Color(1, 0.97, 0.88, 0.95))
		draw_circle(c + Vector2(-14, 26), 5.0, Color(1, 0.97, 0.88, 0.95))
		if hunger < 45.0:
			Painter.draw_item(self, GameData.ANIMALS[species]["food"], c, 30.0)
		else:
			Painter.heart(self, c + Vector2(0, -2), 10.0, Painter.col("#C9A0A8"))
	if _heart_t >= 0.0:
		for i in range(3):
			var k := clampf(_heart_t - float(i) * 0.15, 0.0, 1.2) / 1.2
			var hp := Vector2(float(i - 1) * 24.0 + sin(k * 6.0 + float(i)) * 6.0, -130.0 - k * 70.0)
			Painter.heart(self, hp, 11.0, Color(0.93, 0.35, 0.5, 1.0 - k))
