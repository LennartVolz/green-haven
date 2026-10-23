extends Node2D
## Die interaktive Farmwelt: Kamera (Verschieben, Pinch-Zoom, Trägheit),
## Touch-Eingabe (Tippen zum Pflanzen/Ernten, Ziehen zum Verschieben), Platzieren und Bearbeiten.

signal open_sheet(sheet_name: String, args: Dictionary)
signal close_sheets
signal tool_changed(mode: String, data: Dictionary)

const ENTITY_SCENE := preload("res://scenes/entity.tscn")
const ANIMAL_SCENE := preload("res://scenes/animal.tscn")
const TerrainScript := preload("res://scripts/world/terrain.gd")
const FieldsScript := preload("res://scripts/world/fields_layer.gd")
const ForageScript := preload("res://scripts/world/forage_layer.gd")
const GhostScript := preload("res://scripts/world/ghost.gd")
const OverlayScript := preload("res://scripts/world/overlay.gd")

const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.5
const DRAG_THRESHOLD := 16.0
const PLACE_FINGER_OFFSET := 96.0
const DAY_LENGTH_SECONDS := 24.0 * 60.0 * 60.0


## Wird von der UI gesetzt: gibt true zurück, wenn ein Bildschirmpunkt auf UI liegt.
var ui_blocker := Callable()

var cam: Camera2D
var day_modulate: CanvasModulate
var day_time_seconds := 8.0 * 60.0 * 60.0
var weather_elapsed_seconds := 0.0
var current_weather := "Sonnig"
var _weather_index := 0
var _weather_accumulator := 0.0
var _ambient_night := false
var _ambient_accumulator := 0.0
var terrain: Node2D
var fields_layer: Node2D
var forage_layer: Node2D
var entities: Node2D
var ghost: Node2D
var overlay: Node2D

var tool_mode := ""         ## "", "plant", "till", "place", "edit"
var tool_crop := ""
var place_type := ""
var place_cell := Vector2i.ZERO
var place_valid := false
var moving_uid := -1
var selected_uid := -1

var _entity_nodes: Dictionary = {}
var _animal_nodes: Dictionary = {}
var _camera_land := Rect2i()
var _touches: Dictionary = {}
var _start: Dictionary = {}
var _ui_touches: Dictionary = {}
var _moved := false
var _gesture := ""
var _pinch_dist := 1.0
var _pinch_mid := Vector2.ZERO
var _pan_vel := Vector2.ZERO
var _last_drag_ms := 0
var _focus_tween: Tween


func _ready() -> void:
	var weather_cycle := GameData.WEATHER_DURATION_SECONDS * float(GameData.WEATHER_TYPES.size())
	weather_elapsed_seconds = fposmod(GameState.now(), weather_cycle)
	_weather_index = GameData.weather_index_at(weather_elapsed_seconds)
	current_weather = GameData.WEATHER_TYPES[_weather_index]
	_ambient_night = is_night_at(day_time_seconds)
	day_modulate = CanvasModulate.new()
	day_modulate.color = day_color_at(day_time_seconds)
	add_child(day_modulate)
	terrain = TerrainScript.new()
	add_child(terrain)
	fields_layer = FieldsScript.new()
	add_child(fields_layer)
	forage_layer = ForageScript.new()
	add_child(forage_layer)
	entities = Node2D.new()
	entities.z_index = 2
	entities.z_as_relative = true
	entities.y_sort_enabled = true
	add_child(entities)
	ghost = GhostScript.new()
	add_child(ghost)
	overlay = OverlayScript.new()
	add_child(overlay)
	overlay.set_weather(current_weather)
	cam = Camera2D.new()
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	cam.make_current()
	_camera_land = GameState.land
	GameState.world_changed.connect(_sync)
	GameState.world_changed.connect(_on_land_changed)
	GameState.animals_changed.connect(_sync)
	GameState.excursion_changed.connect(_sync)
	GameState.fx.connect(_on_fx)
	GameState.game_event.connect(_on_event)
	_sync()
	reset_camera()


func reset_camera() -> void:
	var l := GameState.land
	var T := float(GameData.TILE)
	cam.position = (Vector2(l.position) + Vector2(l.size) * 0.5) * T
	cam.zoom = Vector2(0.75, 0.75)
	_clamp_camera()


# ----------------------------------------------------------- Synchronisation

func _on_land_changed() -> void:
	if GameState.land != _camera_land:
		_camera_land = GameState.land
		_clamp_camera()


func _sync() -> void:
	var seen := {}
	for o in GameState.objects:
		var uid := int(o.uid)
		seen[uid] = true
		var n = _entity_nodes.get(uid)
		if n == null:
			n = ENTITY_SCENE.instantiate()
			entities.add_child(n)
			_entity_nodes[uid] = n
		n.setup(o)
		n.visible = uid != moving_uid
		n.selected = uid == selected_uid
	for uid in _entity_nodes.keys():
		if not seen.has(uid):
			_entity_nodes[uid].queue_free()
			_entity_nodes.erase(uid)
			if selected_uid == uid:
				selected_uid = -1
	var seen_a := {}
	for a in GameState.animals:
		var uid := int(a.uid)
		var pad := GameState.get_object(int(a.paddock))
		if pad.is_empty():
			continue
		seen_a[uid] = true
		var n = _animal_nodes.get(uid)
		if n == null:
			n = ANIMAL_SCENE.instantiate()
			entities.add_child(n)
			_animal_nodes[uid] = n
		n.setup(a, pad)
		n.set_ambient(current_weather, _ambient_night, day_time_seconds)
		# Wer gerade unterwegs ist, steht nicht im Gehege.
		n.visible = not GameState.animal_on_excursion(uid)
	for uid in _animal_nodes.keys():
		if not seen_a.has(uid):
			_animal_nodes[uid].queue_free()
			_animal_nodes.erase(uid)
	_update_highlight()


func _update_animal_ambience() -> void:
	for animal in _animal_nodes.values():
		animal.set_ambient(current_weather, _ambient_night, day_time_seconds)


func _update_highlight() -> void:
	var cells: Array = []
	if tool_mode == "plant":
		for c in GameState.fields:
			if GameState.fields[c].crop == "":
				cells.append(c)
	fields_layer.highlight = cells
	fields_layer.queue_redraw()


func _on_fx(kind: String, pos: Vector2, text: String) -> void:
	overlay.add_fx(kind, pos, text)
	if kind == "plant":
		fields_layer.pop(Vector2i(floori(pos.x / GameData.TILE), floori(pos.y / GameData.TILE)))


func _on_event(event_name: String, data: Dictionary) -> void:
	if event_name == "friendship_milestone" and _animal_nodes.has(int(data.uid)):
		_animal_nodes[int(data.uid)].friendship_milestone()
		GameState.fx.emit("collect", _animal_nodes[int(data.uid)].position, I18n.t("Freundschaft!"))
	elif event_name == "petted" and _animal_nodes.has(int(data.uid)):
		_animal_nodes[int(data.uid)].petted()
		GameState.fx.emit("coin", _animal_nodes[int(data.uid)].position, "")
	elif event_name == "played" and _animal_nodes.has(int(data.uid)):
		_animal_nodes[int(data.uid)].activity_played()
		GameState.fx.emit("collect", _animal_nodes[int(data.uid)].position, "")


# ------------------------------------------------------------------ Kamera

static func daylight_at(seconds: float) -> float:
	var solar_height := sin(fposmod(seconds, DAY_LENGTH_SECONDS) / DAY_LENGTH_SECONDS * TAU - PI * 0.5)
	var value := clampf((solar_height + 0.12) / 0.72, 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)


static func day_color_at(seconds: float) -> Color:
	var daylight := daylight_at(seconds)
	var solar_height := sin(fposmod(seconds, DAY_LENGTH_SECONDS) / DAY_LENGTH_SECONDS * TAU - PI * 0.5)
	var tint := Color(0.42, 0.52, 0.78).lerp(Color.WHITE, daylight)
	var twilight := clampf(1.0 - absf(solar_height) / 0.3, 0.0, 1.0)
	return tint.lerp(Color(1.0, 0.72, 0.52), twilight * 0.28)


static func is_night_at(seconds: float) -> bool:
	var hour := fposmod(seconds, DAY_LENGTH_SECONDS) / 3600.0
	return hour >= 18.0 or hour < 6.0


static func time_text_at(seconds: float) -> String:
	var total_minutes := int(floor(fposmod(seconds, DAY_LENGTH_SECONDS) / 60.0))
	var hour := floori(float(total_minutes) / 60.0)
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]


static func clock_text_at(seconds: float) -> String:
	var hour := floori(fposmod(seconds, DAY_LENGTH_SECONDS) / 3600.0)
	var period := I18n.t("Tag") if hour >= 6 and hour < 18 else I18n.t("Nacht")
	return I18n.t("%s · %s") % [time_text_at(seconds), period]


func day_time_text() -> String:
	return time_text_at(day_time_seconds)


func day_clock_text() -> String:
	return clock_text_at(day_time_seconds)


static func weather_index_at(seconds: float) -> int:
	return GameData.weather_index_at(seconds)


static func weather_at(seconds: float) -> String:
	return GameData.weather_at(seconds)


static func weather_tint_at(weather: String) -> Color:
	match weather:
		"Bewölkt":
			return Color(0.86, 0.88, 0.92)
		"Regen":
			return Color(0.76, 0.82, 0.91)
		"Nebel":
			return Color(0.91, 0.93, 0.90)
	return Color.WHITE


func _vp_size() -> Vector2:
	return get_viewport_rect().size


func screen_to_world(p: Vector2) -> Vector2:
	return cam.position + (p - _vp_size() * 0.5) / cam.zoom.x


func world_to_cell(w: Vector2) -> Vector2i:
	return Vector2i(floori(w.x / GameData.TILE), floori(w.y / GameData.TILE))


static func camera_position_bounds(land_rect: Rect2i, viewport_size: Vector2, zoom: float) -> Rect2:
	var half := viewport_size / zoom * 0.5
	var margin := float(GameData.WORLD_MARGIN_CELLS * GameData.TILE)
	var world_min := Vector2(GameData.WORLD_ORIGIN) * float(GameData.TILE)
	var world_max := Vector2(GameData.WORLD_ORIGIN + Vector2i(GameData.WORLD_COLS, GameData.WORLD_ROWS)) * float(GameData.TILE)
	var land_min := Vector2(land_rect.position) * float(GameData.TILE)
	var land_max := Vector2(land_rect.end) * float(GameData.TILE)
	var min_camera := Vector2(maxf(world_min.x, land_min.x - margin), maxf(world_min.y, land_min.y - margin)) + half
	var max_camera := Vector2(minf(world_max.x, land_max.x + margin), minf(world_max.y, land_max.y + margin)) - half
	if min_camera.x > max_camera.x:
		min_camera.x = (min_camera.x + max_camera.x) * 0.5
		max_camera.x = min_camera.x
	if min_camera.y > max_camera.y:
		min_camera.y = (min_camera.y + max_camera.y) * 0.5
		max_camera.y = min_camera.y
	return Rect2(min_camera, max_camera - min_camera)


static func clamp_camera_position(position: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(clampf(position.x, bounds.position.x, bounds.end.x), clampf(position.y, bounds.position.y, bounds.end.y))


func _clamp_camera() -> void:
	cam.position = clamp_camera_position(cam.position, camera_position_bounds(GameState.land, _vp_size(), cam.zoom.x))


func focus_on(world_pos: Vector2) -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(cam, "position", world_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_callback(_clamp_camera)


func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var anchor := screen_to_world(screen_pos)
	var z := clampf(cam.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	cam.zoom = Vector2(z, z)
	cam.position = anchor - (screen_pos - _vp_size() * 0.5) / z
	_clamp_camera()


func _process(delta: float) -> void:
	# Die Spieluhr gehört dem Spielstand-Autoload, damit Café-Öffnungszeiten und
	# Lichtwechsel dieselbe Zeit zeigen. Hier wird sie nur übernommen.
	day_time_seconds = GameState.clock_seconds
	_ambient_accumulator += delta
	if _ambient_accumulator >= 0.25:
		_ambient_accumulator = 0.0
		var night_now := is_night_at(day_time_seconds)
		if night_now != _ambient_night:
			_ambient_night = night_now
		_update_animal_ambience()
	var daylight_color := day_color_at(day_time_seconds)
	var weather_strength := 0.0
	match current_weather:
		"Bewölkt":
			weather_strength = 0.16
		"Regen":
			weather_strength = 0.28
		"Nebel":
			weather_strength = 0.12
	day_modulate.color = daylight_color.lerp(daylight_color * weather_tint_at(current_weather), weather_strength)
	_weather_accumulator += delta
	if _weather_accumulator >= 1.0:
		# Jede Sekunde aus der echten Zeit neu setzen (wie das Pflanzenwachstum), statt Frame-Zeit
		# aufzusummieren: so bleibt die Anzeige auch nach einer App-Pause korrekt.
		weather_elapsed_seconds = fposmod(GameState.now(), GameData.WEATHER_DURATION_SECONDS * float(GameData.WEATHER_TYPES.size()))
		_weather_accumulator = 0.0
		var next_weather_index := GameData.weather_index_at(weather_elapsed_seconds)
		if next_weather_index != _weather_index:
			_weather_index = next_weather_index
			current_weather = GameData.WEATHER_TYPES[_weather_index]
			overlay.set_weather(current_weather)
			_update_animal_ambience()
		elif current_weather == "Nebel" and fposmod(weather_elapsed_seconds, GameData.WEATHER_DURATION_SECONDS) < 16.0:
			overlay.set_weather(current_weather)
	if _touches.is_empty() and _pan_vel.length() > 25.0:
		cam.position -= _pan_vel * delta / cam.zoom.x
		_pan_vel *= pow(0.004, delta)
		_clamp_camera()
	else:
		_pan_vel = Vector2.ZERO if not _touches.is_empty() else _pan_vel


# ------------------------------------------------------------------ Eingabe

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if ui_blocker.is_valid() and ui_blocker.call(event.position):
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, 1.0 / 1.1)


func _over_ui(p: Vector2) -> bool:
	return ui_blocker.is_valid() and bool(ui_blocker.call(p))


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if _over_ui(e.position):
			_ui_touches[e.index] = true
			return
		_touches[e.index] = e.position
		_start[e.index] = e.position
		if _touches.size() == 1:
			_moved = false
			_gesture = ""
			_pan_vel = Vector2.ZERO
			_last_drag_ms = Time.get_ticks_msec()
			_begin_single(e.position)
		else:
			_begin_pinch()
	else:
		if _ui_touches.erase(e.index):
			return
		if not _touches.has(e.index):
			return
		var was_single := _touches.size() == 1
		_touches.erase(e.index)
		if was_single:
			_end_single(e.position)
		elif _touches.size() == 1:
			_moved = true
			_gesture = "pan"
		if _touches.is_empty():
			_gesture = ""


func _on_drag(e: InputEventScreenDrag) -> void:
	if _ui_touches.has(e.index) or not _touches.has(e.index):
		return
	var old: Vector2 = _touches[e.index]
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		_do_pinch()
		return
	if tool_mode == "place":
		_update_ghost(e.position)
		return
	if not _moved and e.position.distance_to(_start[e.index]) > DRAG_THRESHOLD:
		_moved = true
		# Ziehen verschiebt immer die Karte – auch über reifen Feldern und mit
		# aktivem Werkzeug. Säen, Anlegen und Ernten laufen über das Tippen.
		_gesture = "pan"
	if _gesture == "pan":
		var d: Vector2 = e.position - old
		cam.position -= d / cam.zoom.x
		_clamp_camera()
		var now_ms := Time.get_ticks_msec()
		var dt := maxf(0.008, float(now_ms - _last_drag_ms) / 1000.0)
		_last_drag_ms = now_ms
		_pan_vel = _pan_vel.lerp(d / dt, 0.5)


func _begin_single(p: Vector2) -> void:
	if tool_mode == "place":
		_gesture = "place"
		_update_ghost(p)


func _end_single(p: Vector2) -> void:
	if _gesture == "place":
		return
	if not _moved:
		_handle_tap(p)


func _begin_pinch() -> void:
	var ps: Array = _touches.values()
	_pinch_dist = maxf(8.0, (ps[0] as Vector2).distance_to(ps[1]))
	_pinch_mid = ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5
	_gesture = "pinch"
	_moved = true
	_pan_vel = Vector2.ZERO


func _do_pinch() -> void:
	var ps: Array = _touches.values()
	var dist := maxf(8.0, (ps[0] as Vector2).distance_to(ps[1]))
	var mid := ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5
	var anchor := screen_to_world(_pinch_mid)
	var z := clampf(cam.zoom.x * dist / _pinch_dist, MIN_ZOOM, MAX_ZOOM)
	cam.zoom = Vector2(z, z)
	cam.position = anchor - (mid - _vp_size() * 0.5) / z
	_pinch_dist = dist
	_pinch_mid = mid
	_clamp_camera()


func _error() -> void:
	GameState.sound.emit("error")
	GameState.toast.emit(GameState.last_error, "error")


# ---------------------------------------------------------------- Tippen

func _animal_at(w: Vector2) -> Node2D:
	var best: Node2D = null
	for n in _animal_nodes.values():
		if n.visible and n.hit(w) and (best == null or n.position.y > best.position.y):
			best = n
	return best


func _entity_at(w: Vector2) -> Node2D:
	var best: Node2D = null
	for n in _entity_nodes.values():
		if n.visible and n.hit_rect().has_point(w):
			if best == null or n.position.y > best.position.y:
				best = n
	return best


func _handle_tap(p: Vector2) -> void:
	var w := screen_to_world(p)
	var cell := world_to_cell(w)
	if tool_mode == "edit":
		_tap_edit(w)
		return
	if tool_mode == "till":
		if not GameState.till(cell) and GameState.in_land(cell):
			_error()
		return
	var an := _animal_at(w)
	if an != null:
		GameState.sound.emit("tap")
		open_sheet.emit("animal", {"uid": an.uid})
		return
	var ent := _entity_at(w)
	if ent != null:
		_tap_entity(ent)
		return
	var forage_id := GameState.forage_spot_at(cell)
	if forage_id != "" and GameState.level >= int(GameData.FORAGE[forage_id]["level"]):
		_tap_forage(cell)
		return
	if GameState.fields.has(cell):
		_tap_field(cell)
		return
	close_sheets.emit()


func _tap_entity(ent: Node2D) -> void:
	GameState.sound.emit("tap")
	match ent.kind:
		"production":
			var o := GameState.get_object(ent.uid)
			if GameState.ready_count(o) > 0:
				GameState.collect_ready(ent.uid)
			else:
				open_sheet.emit("production", {"uid": ent.uid})
		"paddock":
			open_sheet.emit("refuge", {"uid": ent.uid})


func _tap_forage(cell: Vector2i) -> void:
	var got := GameState.collect_forage(cell)
	if got.is_empty():
		GameState.sound.emit("tap")
		GameState.toast.emit(GameState.last_error, "info")
		return
	var pos := Vector2(cell) * GameData.TILE + Vector2(GameData.TILE * 0.5, GameData.TILE * 0.6)
	GameState.fx.emit("collect", pos, I18n.t("+%d %s") % [int(got["amount"]), String(got["name"])])


func _tap_field(cell: Vector2i) -> void:
	var f: Dictionary = GameState.fields[cell]
	if f.crop == "":
		if tool_mode == "plant":
			if not GameState.plant(cell, tool_crop):
				_error()
		else:
			open_sheet.emit("crops", {"cell": cell})
		return
	if GameState.is_ready(cell):
		GameState.harvest(cell)
	else:
		GameState.sound.emit("tap")
		GameState.toast.emit(I18n.t("%s: noch %s") % [GameData.CROPS[f.crop]["name"], GameData.format_time(GameState.crop_remaining(cell))], "info")


# ----------------------------------------------------------- Werkzeuge

func clear_tool() -> void:
	if tool_mode == "place":
		ghost.hide_ghost()
		moving_uid = -1
		_sync()
	tool_mode = ""
	tool_crop = ""
	place_type = ""
	selected_uid = -1
	_update_highlight()
	_sync()
	tool_changed.emit("", {})


func set_plant_tool(crop: String) -> void:
	clear_tool()
	tool_mode = "plant"
	tool_crop = crop
	_update_highlight()
	tool_changed.emit("plant", {"crop": crop})


func plant_with_tool(crop: String, cell: Vector2i) -> void:
	set_plant_tool(crop)
	if GameState.fields.has(cell) and not GameState.plant(cell, crop):
		_error()


func set_till_tool() -> void:
	clear_tool()
	tool_mode = "till"
	tool_changed.emit("till", {"cost": GameData.TILL_COST})


func set_edit_mode(on: bool) -> void:
	clear_tool()
	if on:
		tool_mode = "edit"
		tool_changed.emit("edit", {"uid": -1})


func _tap_edit(w: Vector2) -> void:
	var ent := _entity_at(w)
	selected_uid = ent.uid if ent != null else -1
	_sync()
	if ent != null:
		var o := GameState.get_object(selected_uid)
		tool_changed.emit("edit", {"uid": selected_uid, "name": GameData.object_def(o.type)["name"], "price": GameState.sell_price(o), "can_move": true})
	else:
		tool_changed.emit("edit", {"uid": -1})


func edit_move_selected() -> void:
	if selected_uid < 0:
		return
	var o := GameState.get_object(selected_uid)
	if o.is_empty():
		return
	start_placement(o.type, selected_uid)


func edit_sell_selected() -> void:
	if selected_uid < 0:
		return
	var uid := selected_uid
	if GameState.sell_object(uid):
		selected_uid = -1
		GameState.sound.emit("coin")
		tool_changed.emit("edit", {"uid": -1})
	else:
		_error()


func start_placement(type: String, moving: int = -1) -> void:
	var was_edit := tool_mode == "edit"
	clear_tool()
	tool_mode = "place"
	place_type = type
	moving_uid = moving
	if moving >= 0:
		var o := GameState.get_object(moving)
		place_cell = o.cell
	else:
		place_cell = _first_valid_cell(type)
	_refresh_ghost()
	_sync()
	tool_changed.emit("place", {"type": type, "valid": place_valid, "moving": moving >= 0, "from_edit": was_edit})


func _first_valid_cell(type: String) -> Vector2i:
	var sz := GameData.object_size(type)
	var center := world_to_cell(cam.position) - sz / 2
	for radius in range(0, 24):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := center + Vector2i(dx, dy)
				if GameState.can_place(type, c):
					return c
	return center


func _update_ghost(screen_p: Vector2) -> void:
	var w := screen_to_world(screen_p - Vector2(0, PLACE_FINGER_OFFSET))
	var sz := GameData.object_size(place_type)
	var T := float(GameData.TILE)
	place_cell = Vector2i(floori(w.x / T - float(sz.x) * 0.5 + 0.5), floori(w.y / T - float(sz.y) * 0.5 + 0.5))
	_refresh_ghost()


func _refresh_ghost() -> void:
	place_valid = GameState.can_place(place_type, place_cell, moving_uid)
	ghost.show_ghost(place_type, place_cell, place_valid)
	tool_changed.emit("place", {"type": place_type, "valid": place_valid, "moving": moving_uid >= 0})


func confirm_placement() -> bool:
	if tool_mode != "place":
		return false
	if not place_valid:
		GameState.last_error = I18n.t("Hier ist kein Platz")
		_error()
		return false
	if moving_uid >= 0:
		if not GameState.move_object(moving_uid, place_cell):
			_error()
			return false
		GameState.sound.emit("build")
	else:
		var uid := GameState.place_object(place_type, place_cell)
		if uid < 0:
			_error()
			return false
		GameState.sound.emit("build")
	var cell := place_cell
	ghost.hide_ghost()
	clear_tool()
	GameState.fx.emit("coin", GameState.cell_center(cell), "")
	return true


func cancel_placement() -> void:
	clear_tool()
