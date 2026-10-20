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
var sheltering := false
var sleeping := false
var shelter_slot := 0
var ambient_target := Vector2.ZERO
var sleep_wake_timer := 0.0
var _ambient_state := "Normal"
var _ambient_weather := "Sonnig"
var _ambient_night := false
var _ambient_day_seconds := 8.0 * 3600.0

var _target := Vector2.ZERO
var _wait := 1.0
var _heart_t := -1.0
var _friendship_t := -1.0


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
	_update_ambient_target()
	_apply_ambient_state()


func set_ambient(weather: String, night: bool, day_seconds: float = -1.0) -> void:
	var changed := weather != _ambient_weather or night != _ambient_night
	var previous_day_seconds := _ambient_day_seconds
	var previous_night := _ambient_night
	_ambient_weather = weather
	_ambient_night = night
	if day_seconds >= 0.0:
		_ambient_day_seconds = day_seconds
	if changed:
		_update_ambient_target()
	if night and previous_night and previous_day_seconds > 12.0 * 3600.0 and _ambient_day_seconds < 12.0 * 3600.0:
		sleep_wake_timer = 0.0
	_apply_ambient_state()
	queue_redraw()


func _update_ambient_target() -> void:
	# Alle Tiere eines Geheges teilen dieselben drei Standplätze, damit auch nach
	# Laden oder Neu-Synchronisieren keine Zufallspositionen übereinanderliegen.
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var animal_data := GameState.get_animal(uid)
	var paddock_uid := int(animal_data.get("paddock", -1))
	var paddock_animals: Array = GameState.animals_in_paddock(paddock_uid)
	shelter_slot = 0
	for index in range(paddock_animals.size()):
		if int(paddock_animals[index].uid) == uid:
			shelter_slot = index
			break
	var slot_x := bounds.position.x + bounds.size.x * (0.22 + 0.28 * float(shelter_slot))
	var slot_y := bounds.position.y + maxf(18.0, bounds.size.y * 0.13)
	ambient_target = Vector2(clampf(slot_x, bounds.position.x, bounds.end.x), clampf(slot_y, bounds.position.y, bounds.end.y))


func _scheduled_to_sleep() -> bool:
	if not _ambient_night:
		return false
	var night_elapsed_game := fposmod(_ambient_day_seconds - 18.0 * 3600.0, 24.0 * 3600.0)
	var night_elapsed := night_elapsed_game / 180.0
	# 90-second rotation with 30-second per-animal offsets: one animal is always
	# in its awake window while the other two can nap.
	return fposmod(night_elapsed + float(shelter_slot) * 30.0, 90.0) < 60.0


func _apply_ambient_state() -> void:
	var should_sleep := _scheduled_to_sleep() and sleep_wake_timer <= 0.0
	var was_sleeping := sleeping
	var should_shelter := _ambient_night or _ambient_weather == "Regen"
	var next_state := "Schlafen" if should_sleep else "Unterstand" if should_shelter else "Normal"
	if next_state == _ambient_state:
		return
	_ambient_state = next_state
	sleeping = next_state == "Schlafen"
	sheltering = next_state != "Normal"
	if sheltering:
		walking = position.distance_to(ambient_target) > 0.5
		_target = ambient_target
		_wait = 0.0 if walking else 99999.0
	else:
		walking = false
		_wait = randf_range(0.25, 2.5)
	if was_sleeping and not sleeping:
		sleep_wake_timer = maxf(sleep_wake_timer, 2.5)
		_wait = 2.5
		walking = false


func hit(p: Vector2) -> bool:
	return p.distance_to(position + Vector2(0, -44)) < 62.0


func petted() -> void:
	_heart_t = 0.0
	if sleeping:
		sleep_wake_timer = 2.5
		sleeping = false
		_ambient_state = "Unterstand"
		walking = false
		_wait = 2.5
		queue_redraw()
		return
	_wait = maxf(_wait, 1.5)
	walking = false


func activity_played() -> void:
	_heart_t = 0.0
	_wait = maxf(_wait, 2.0)
	walking = false


func friendship_milestone() -> void:
	_heart_t = 0.0
	_friendship_t = 0.0
	_wait = maxf(_wait, 2.5)
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
	if sleep_wake_timer > 0.0:
		sleep_wake_timer = maxf(0.0, sleep_wake_timer - delta)
		if sleep_wake_timer <= 0.0:
			_apply_ambient_state()
	var world_node := get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else null
	if world_node != null and world_node.has_method("get"):
		var day_time: Variant = world_node.get("day_time_seconds")
		if typeof(day_time) == TYPE_FLOAT or typeof(day_time) == TYPE_INT:
			_ambient_day_seconds = float(day_time)
	var expected_state := "Schlafen" if _scheduled_to_sleep() and sleep_wake_timer <= 0.0 else "Unterstand" if _ambient_night or _ambient_weather == "Regen" else "Normal"
	if expected_state != _ambient_state:
		_apply_ambient_state()
	if _heart_t >= 0.0:
		_heart_t += delta
		if _heart_t > 1.4:
			_heart_t = -1.0
	if _friendship_t >= 0.0:
		_friendship_t += delta
		if _friendship_t > 2.0:
			_friendship_t = -1.0
	if sleeping:
		walking = false
		peck = 0.0
	elif sheltering and position.distance_to(ambient_target) > 0.5:
		_target = ambient_target
		walking = true
		var shelter_delta := _target - position
		var shelter_step := _speed() * delta
		if shelter_delta.length() <= shelter_step:
			position = ambient_target
			walking = false
		else:
			position += shelter_delta.normalized() * shelter_step
			flip = shelter_delta.x < 0.0
		peck = 0.0
	elif sheltering:
		walking = false
		peck = 0.0
	elif walking:
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
	AnimalPainter.draw(self, species, t, flip, walking, GameState.equipped_cosmetics_of(a), peck, 1.0, sleeping)
	if sleeping and sleep_wake_timer <= 0.0:
		var z_phase := fposmod(t + float(shelter_slot) * 0.7, 2.2)
		var z_alpha := clampf(minf(minf(z_phase / 0.25, (2.2 - z_phase) / 0.6), 1.0), 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(32.0 + sin(t * 1.8) * 5.0, -135.0 - fmod(z_phase * 24.0, 30.0)), "Z", HORIZONTAL_ALIGNMENT_CENTER, 24, 22, Color(0.34, 0.43, 0.61, z_alpha))
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
	if _friendship_t >= 0.0:
		var pulse := 1.0 + sin(_friendship_t * 10.0) * 0.15
		var halo_color := Color(1.0, 0.82, 0.35, clampf(1.0 - _friendship_t / 2.0, 0.0, 1.0))
		draw_arc(Vector2(0, -62), 72.0 * pulse, 0.0, TAU, 36, halo_color, 5.0, true)
