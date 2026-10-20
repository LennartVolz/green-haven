extends Node
## Zentraler Spielzustand: Wirtschaft, Inventar, Felder, Produktion, Aufträge,
## Tierrefugium und Quests. Enthält die gesamte Spiellogik ohne Darstellung,
## damit sie headless getestet werden kann.
##
## Zeitbasierte Systeme (Wachstum, Produktion, Tierbedürfnisse) speichern nur
## Zeitstempel. Dadurch läuft die Welt offline "weiter": beim nächsten Start
## wird der Fortschritt einfach aus der verstrichenen Zeit berechnet.

signal coins_changed
signal xp_changed
signal level_up(new_level: int, unlocks: Array)
signal inventory_changed
signal world_changed
signal orders_changed
signal animals_changed
signal quests_changed
signal toast(text: String, kind: String)
signal game_event(event_name: String, data: Dictionary)
signal fx(kind: String, world_pos: Vector2, text: String)
signal sound(sound_name: String)

const SAVE_VERSION := 8
const MAX_ORDERS := 4
const NEIGHBORHOOD_EVENT_CYCLE_SECONDS := 3.0 * 60.0 * 60.0
const NEIGHBORHOOD_EVENT_DURATION_SECONDS := 30.0 * 60.0
const NEIGHBORHOOD_EVENT_SERIES_LENGTH := 3
## Belohnung für den Abschluss der dritten Etappe eines Gartentags.
const NEIGHBORHOOD_EVENT_FINALE_COINS := 90
const NEIGHBORHOOD_EVENT_FINALE_XP := 30
const REFRESH_INTERVAL_SECONDS := 0.5
const CAFE_SPECIAL_DURATION := 24.0 * 60.0 * 60.0
const CAFE_SPECIAL_ORDER_CHANCE := 0.7
const CAFE_SPECIAL_COIN_BONUS := 0.5
const CAFE_SPECIAL_XP_BONUS := 5
const ORDER_COOLDOWN := 25.0
const PET_COOLDOWN := 12.0
const ACTIVITY_COOLDOWN := 180.0
const RESCUE_COOLDOWN := 600.0
const MAX_UPGRADES := 3
## Tiere sind in 8 Stunden von "voll" auf "leer"; ohne Strafe, nur Stimmung.
const ANIMAL_DECAY_PER_SEC := 100.0 / (8.0 * 3600.0)

var rng := RandomNumberGenerator.new()
var loaded := false
var time_offset := 0.0   ## nur für Tests: verschiebt die Spielzeit
var last_error := ""

var coins := 0
var level := 1
var xp := 0
var inventory: Dictionary = {}
var fields: Dictionary = {}      ## Vector2i -> {"crop": String, "t": float}
var objects: Array = []          ## {"uid","kind","type","cell","queue","upgrades"}
var animals: Array = []          ## {uid,species,name,story,traits,hunger,happy,hearts,last,paddock,pet_at,activity_at,accessories}
var rescue_case: Dictionary = {}
var next_rescue_at := 0.0
var land := Rect2i()
var land_level := 0
var orders: Array = []
var active_delivery_story := ""
var delivery_story_stage := 0
var daily_cafe_special_id := ""
var daily_cafe_special_at := 0.0
var neighborhood_event_stage := 0
var neighborhood_event_order: Dictionary = {}
var neighborhood_event_completed_cycle := -1
var diary: Array = []
var stats: Dictionary = {}
var claimed_quests: Array = []
var claimed_achievements: Array = []
var settings: Dictionary = {"sound": true, "music": true, "vibration": true}
var tutorial_step := 0
var next_uid := 1
var next_order_at := 0.0
var away_seconds := 0.0

var _occ: Dictionary = {}        ## Vector2i -> uid
var _refresh_acc := 0.0


func _ready() -> void:
	rng.randomize()
	if not loaded:
		reset_state()


func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func _process(delta: float) -> void:
	if not loaded:
		return
	# Aufträge und Rettungsfälle ändern sich nur im Sekundentakt; pro Frame wäre das Verschwendung.
	_refresh_acc += delta
	if _refresh_acc < REFRESH_INTERVAL_SECONDS:
		return
	_refresh_acc = 0.0
	_fill_orders()
	_refresh_rescue_case()


# ---------------------------------------------------------------- Zustand

func reset_state() -> void:
	coins = 0
	level = 1
	xp = 0
	inventory = {}
	fields = {}
	objects = []
	animals = []
	rescue_case = {}
	next_rescue_at = 0.0
	land = GameData.START_LAND
	land_level = 0
	orders = []
	active_delivery_story = ""
	delivery_story_stage = 0
	daily_cafe_special_id = ""
	daily_cafe_special_at = 0.0
	neighborhood_event_stage = 0
	neighborhood_event_order = {}
	neighborhood_event_completed_cycle = -1
	diary = []
	stats = {}
	claimed_quests = []
	claimed_achievements = []
	tutorial_step = 0
	next_uid = 1
	next_order_at = 0.0
	away_seconds = 0.0
	_occ = {}


func new_game() -> void:
	reset_state()
	coins = GameData.START_COINS
	for dx in range(2):
		for dy in range(2):
			fields[Vector2i(land.position.x + 3 + dx, land.position.y + 3 + dy)] = {"crop": "", "t": 0.0}
	loaded = true
	_fill_orders()
	_emit_all()


func _emit_all() -> void:
	coins_changed.emit()
	xp_changed.emit()
	inventory_changed.emit()
	world_changed.emit()
	orders_changed.emit()
	animals_changed.emit()
	quests_changed.emit()


func _new_uid() -> int:
	var u := next_uid
	next_uid += 1
	return u


func bump(stat: String, n: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + n


func add_diary_entry(text: String, animal_uid: int = -1) -> void:
	diary.append({"time": now(), "text": text, "animal_uid": animal_uid})
	while diary.size() > 100:
		diary.pop_front()


func friendship_level(a: Dictionary) -> int:
	var result := 0
	for i in range(GameData.FRIENDSHIP_THRESHOLDS.size()):
		if int(a.get("hearts", 0)) >= int(GameData.FRIENDSHIP_THRESHOLDS[i]):
			result = i + 1
	return result


func record_animal_moment(a: Dictionary, moment: String, hearts_gained: int) -> void:
	var old_level := friendship_level(a)
	a.hearts = int(a.get("hearts", 0)) + hearts_gained
	add_diary_entry("%s: %s" % [a.name, moment], int(a.uid))
	var new_level := friendship_level(a)
	if new_level > old_level:
		var species: String = str(a.species)
		var story: String = GameData.FRIENDSHIP_STORIES[species][new_level - 1]
		add_diary_entry("%s vertraut dir jetzt mehr und %s" % [a.name, story], int(a.uid))
		event("friendship_milestone", {"uid": int(a.uid), "level": new_level})


func event(event_name: String, data: Dictionary = {}) -> void:
	game_event.emit(event_name, data)


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * GameData.TILE


# ---------------------------------------------------------- Münzen / XP

func add_coins(n: int) -> void:
	if n <= 0:
		return
	coins += n
	coins_changed.emit()


func spend_coins(n: int) -> bool:
	if n < 0 or n > coins:
		return false
	coins -= n
	coins_changed.emit()
	return true


func add_xp(n: int) -> void:
	if n <= 0:
		return
	if level >= GameData.MAX_LEVEL:
		xp = 0
		xp_changed.emit()
		return
	xp += n
	while level < GameData.MAX_LEVEL and xp >= GameData.xp_needed(level):
		xp -= GameData.xp_needed(level)
		level += 1
		sound.emit("level")
		level_up.emit(level, GameData.unlocks_at(level))
	if level >= GameData.MAX_LEVEL:
		xp = 0
	xp_changed.emit()
	quests_changed.emit()


# ------------------------------------------------------------- Inventar

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n: int = 1) -> void:
	if n <= 0 or not GameData.items.has(id):
		return
	inventory[id] = item_count(id) + n
	inventory_changed.emit()


func remove_item(id: String, n: int = 1) -> bool:
	if n <= 0 or item_count(id) < n:
		return false
	var left := item_count(id) - n
	if left <= 0:
		inventory.erase(id)
	else:
		inventory[id] = left
	inventory_changed.emit()
	return true


func has_items(req: Dictionary) -> bool:
	for id in req:
		if item_count(id) < int(req[id]):
			return false
	return true


## Entnimmt alle Zutaten atomar: entweder vollständig oder gar nicht.
func take_items(req: Dictionary) -> bool:
	if not has_items(req):
		return false
	for id in req:
		remove_item(id, int(req[id]))
	return true


func sell_item(id: String, n: int) -> int:
	if n <= 0 or not GameData.items.has(id):
		return 0
	n = mini(n, item_count(id))
	if n <= 0 or not remove_item(id, n):
		return 0
	var gain: int = n * int(GameData.items[id].sell)
	add_coins(gain)
	sound.emit("coin")
	return gain


func buy_item(id: String, n: int = 1) -> bool:
	if not GameData.EXTRA_ITEMS.has(id) or n <= 0:
		return false
	var d: Dictionary = GameData.EXTRA_ITEMS[id]
	if level < int(d["level"]):
		last_error = "Ab Stufe %d" % int(d["level"])
		return false
	if not spend_coins(int(d["shop"]) * n):
		last_error = "Nicht genug Münzen"
		return false
	add_item(id, n)
	sound.emit("coin")
	return true


# ------------------------------------------------------------ Welt/Raster

func in_land(cell: Vector2i) -> bool:
	return land.has_point(cell)


func rebuild_occupancy() -> void:
	_occ = {}
	for o in objects:
		for c in footprint_cells(o.type, o.cell):
			_occ[c] = o.uid


func footprint_cells(type: String, cell: Vector2i) -> Array:
	var sz := GameData.object_size(type)
	var out: Array = []
	for x in range(sz.x):
		for y in range(sz.y):
			out.append(Vector2i(cell.x + x, cell.y + y))
	return out


func is_free(cell: Vector2i, ignore_uid: int = -1) -> bool:
	if not in_land(cell) or fields.has(cell):
		return false
	if _occ.has(cell) and int(_occ[cell]) != ignore_uid:
		return false
	return true


func can_place(type: String, cell: Vector2i, ignore_uid: int = -1) -> bool:
	for c in footprint_cells(type, cell):
		if not is_free(c, ignore_uid):
			return false
	return true


func get_object(uid: int) -> Dictionary:
	for o in objects:
		if int(o.uid) == uid:
			return o
	return {}


func object_at(cell: Vector2i) -> Dictionary:
	if _occ.has(cell):
		return get_object(int(_occ[cell]))
	return {}


func count_type(type: String) -> int:
	var n := 0
	for o in objects:
		if o.type == type:
			n += 1
	return n


func has_building(type: String) -> bool:
	return count_type(type) > 0


func can_till(cell: Vector2i) -> bool:
	return is_free(cell)


func till(cell: Vector2i) -> bool:
	if not can_till(cell):
		last_error = "Hier kann kein Feld entstehen"
		return false
	if not spend_coins(GameData.TILL_COST):
		last_error = "Nicht genug Münzen"
		return false
	fields[cell] = {"crop": "", "t": 0.0}
	world_changed.emit()
	event("tilled", {"cell": cell})
	return true


func place_object(type: String, cell: Vector2i) -> int:
	var d := GameData.object_def(type)
	if d.is_empty():
		last_error = "Unbekanntes Objekt"
		return -1
	if level < int(d["level"]):
		last_error = "Ab Stufe %d" % int(d["level"])
		return -1
	if d.has("max") and count_type(type) >= int(d["max"]):
		last_error = "Davon ist nur %d Stück möglich" % int(d["max"])
		return -1
	if not can_place(type, cell):
		last_error = "Hier ist kein Platz"
		return -1
	if not spend_coins(int(d["cost"])):
		last_error = "Nicht genug Münzen"
		return -1
	var obj := {"uid": _new_uid(), "kind": d["kind"], "type": type, "cell": cell, "queue": [], "upgrades": 0}
	objects.append(obj)
	rebuild_occupancy()
	if obj.kind == "paddock":
		_refresh_rescue_case()
	bump("built")
	world_changed.emit()
	quests_changed.emit()
	event("built", {"type": type, "uid": obj.uid})
	return obj.uid


func move_object(uid: int, cell: Vector2i) -> bool:
	var o := get_object(uid)
	if o.is_empty() or not can_place(o.type, cell, uid):
		last_error = "Hier ist kein Platz"
		return false
	o.cell = cell
	rebuild_occupancy()
	world_changed.emit()
	return true


func sell_price(o: Dictionary) -> int:
	return int(GameData.object_def(o.type)["cost"]) / 2


func sell_object(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty():
		return false
	if not (o.queue as Array).is_empty():
		last_error = "Erst die Produktion abholen"
		return false
	for a in animals:
		if int(a.paddock) == uid:
			last_error = "Im Gehege leben noch Tiere"
			return false
	add_coins(sell_price(o))
	objects.erase(o)
	rebuild_occupancy()
	world_changed.emit()
	quests_changed.emit()
	return true


func next_expansion() -> Dictionary:
	if land_level >= GameData.LAND_EXPANSIONS.size():
		return {}
	return GameData.LAND_EXPANSIONS[land_level]


func expand_land() -> bool:
	var ex := next_expansion()
	if ex.is_empty():
		last_error = "Die Farm ist voll ausgebaut"
		return false
	if level < int(ex["level"]):
		last_error = "Ab Stufe %d" % int(ex["level"])
		return false
	var grown := land.grow(1)
	if grown.position.x < GameData.WORLD_ORIGIN.x or grown.position.y < GameData.WORLD_ORIGIN.y \
			or grown.end.x > GameData.WORLD_ORIGIN.x + GameData.WORLD_COLS \
			or grown.end.y > GameData.WORLD_ORIGIN.y + GameData.WORLD_ROWS:
		last_error = "Die Farm hat die Weltgrenze erreicht"
		return false
	if not spend_coins(int(ex["cost"])):
		last_error = "Nicht genug Münzen"
		return false
	land = grown
	land_level += 1
	bump("expansions")
	world_changed.emit()
	sound.emit("build")
	event("expanded", {})
	return true


# --------------------------------------------------------------- Anbau

func crop_progress(cell: Vector2i) -> float:
	if not fields.has(cell):
		return 0.0
	var f: Dictionary = fields[cell]
	if f.crop == "":
		return 0.0
	var grow: float = float(GameData.CROPS[f.crop]["grow"])
	var effective_growth := GameData.crop_growth_seconds_between(float(f.t), now())
	return clampf(effective_growth / grow, 0.0, 1.0)


func crop_remaining(cell: Vector2i) -> float:
	if not fields.has(cell) or fields[cell].crop == "":
		return 0.0
	var f: Dictionary = fields[cell]
	var grow: float = float(GameData.CROPS[f.crop]["grow"])
	var effective_growth := GameData.crop_growth_seconds_between(float(f.t), now())
	return GameData.real_seconds_for_crop_growth(now(), maxf(0.0, grow - effective_growth))


func is_ready(cell: Vector2i) -> bool:
	return fields.has(cell) and fields[cell].crop != "" and crop_progress(cell) >= 1.0


## 0 = Saat, 1 = Keimling, 2 = wachsend, 3 = erntereif
func crop_stage(cell: Vector2i) -> int:
	var p := crop_progress(cell)
	if p >= 1.0:
		return 3
	if p >= 0.6:
		return 2
	if p >= 0.25:
		return 1
	return 0


func plant(cell: Vector2i, crop: String) -> bool:
	if not fields.has(cell) or not GameData.CROPS.has(crop):
		last_error = "Hier ist kein Feld"
		return false
	if fields[cell].crop != "":
		last_error = "Hier wächst schon etwas"
		return false
	var c: Dictionary = GameData.CROPS[crop]
	if level < int(c["level"]):
		last_error = "%s ab Stufe %d" % [c["name"], int(c["level"])]
		return false
	if not spend_coins(int(c["seed"])):
		last_error = "Nicht genug Münzen für Saatgut"
		return false
	fields[cell] = {"crop": crop, "t": now()}
	bump("planted")
	world_changed.emit()
	quests_changed.emit()
	fx.emit("plant", cell_center(cell), "")
	sound.emit("plant")
	event("planted", {"crop": crop, "cell": cell})
	return true


func harvest(cell: Vector2i) -> bool:
	if not is_ready(cell):
		return false
	var crop: String = fields[cell].crop
	var c: Dictionary = GameData.CROPS[crop]
	var amount: int = int(c["yield"])
	add_item(crop, amount)
	add_xp(int(c["xp"]))
	bump("harvested")
	if c["perennial"]:
		fields[cell] = {"crop": crop, "t": now()}
	else:
		fields[cell] = {"crop": "", "t": 0.0}
	world_changed.emit()
	fx.emit("harvest", cell_center(cell), "+%d %s" % [amount, c["name"]])
	sound.emit("harvest")
	event("harvested", {"crop": crop, "cell": cell})
	return true


# ----------------------------------------------------------- Produktion

func queue_capacity(o: Dictionary) -> int:
	return int(GameData.BUILDINGS[o.type]["slots"]) + int(o.upgrades)


func upgrade_cost(o: Dictionary) -> int:
	return 200 * (int(o.upgrades) + 1)


func upgrade_building(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o.kind != "production":
		return false
	if int(o.upgrades) >= MAX_UPGRADES:
		last_error = "Maximal ausgebaut"
		return false
	if not spend_coins(upgrade_cost(o)):
		last_error = "Nicht genug Münzen"
		return false
	o.upgrades = int(o.upgrades) + 1
	world_changed.emit()
	sound.emit("build")
	return true


func start_recipe(uid: int, recipe_id: String) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o.kind != "production" or not GameData.RECIPES.has(recipe_id):
		return false
	var r: Dictionary = GameData.RECIPES[recipe_id]
	if r["building"] != o.type:
		last_error = "Dieses Rezept gehört in ein anderes Gebäude"
		return false
	if level < int(r["level"]):
		last_error = "Ab Stufe %d" % int(r["level"])
		return false
	var q: Array = o.queue
	if q.size() >= queue_capacity(o):
		last_error = "Die Warteschlange ist voll"
		return false
	if not take_items(r["inputs"]):
		last_error = "Zutaten fehlen"
		return false
	var start: float = now()
	if not q.is_empty():
		start = maxf(start, float(q[q.size() - 1]["end"]))
	q.append({"recipe": recipe_id, "start": start, "end": start + float(r["time"])})
	world_changed.emit()
	sound.emit("tap")
	event("recipe_started", {"recipe": recipe_id})
	return true


func entry_progress(entry: Dictionary) -> float:
	var span: float = float(entry["end"]) - float(entry["start"])
	if span <= 0.0:
		return 1.0
	return clampf((now() - float(entry["start"])) / span, 0.0, 1.0)


func ready_count(o: Dictionary) -> int:
	var n := 0
	for e in o.queue:
		if float(e["end"]) <= now():
			n += 1
	return n


## Alle fertigen Produkte über alle Gebäude (für Navigation und Übersicht).
func total_ready_products() -> int:
	var n := 0
	for o in objects:
		if o.kind == "production":
			n += ready_count(o)
	return n


## Noch laufende oder wartende Produktionen über alle Gebäude.
func active_product_count() -> int:
	var n := 0
	for o in objects:
		if o.kind == "production":
			n += maxi(0, (o.queue as Array).size() - ready_count(o))
	return n


## Alle Produktionsgebäude in Bau-Reihenfolge für die Übersicht.
func production_buildings() -> Array:
	var out: Array = []
	for o in objects:
		if o.kind == "production":
			out.append(o)
	return out


## Holt alle fertigen Produkte ab. Die Warteschlange läuft sequenziell, daher
## bilden fertige Einträge immer ein Präfix.
func collect_ready(uid: int, with_sound: bool = true) -> Array:
	var o := get_object(uid)
	var got: Array = []
	if o.is_empty():
		return got
	var q: Array = o.queue
	while not q.is_empty() and float(q[0]["end"]) <= now():
		var e: Dictionary = q.pop_front()
		var rid: String = e["recipe"]
		add_item(rid, 1)
		add_xp(int(GameData.RECIPES[rid]["xp"]))
		bump("crafted")
		got.append(rid)
	if not got.is_empty():
		world_changed.emit()
		fx.emit("collect", cell_center(o.cell) + Vector2(GameData.TILE, 0), "+%d" % got.size())
		if with_sound:
			sound.emit("harvest")
		event("collected", {"uid": uid, "items": got})
	return got


## Sammelabholung: holt aus allen Gebäuden ab und meldet Anzahl, Sorten und
## beteiligte Gebäude für Hinweis und Tests.
func collect_all_ready() -> Dictionary:
	var items: Dictionary = {}
	var count := 0
	var buildings := 0
	for o in production_buildings():
		var got := collect_ready(int(o.uid), false)
		if got.is_empty():
			continue
		buildings += 1
		for rid in got:
			items[rid] = int(items.get(rid, 0)) + 1
			count += 1
	if count > 0:
		sound.emit("harvest")
	return {"count": count, "items": items, "buildings": buildings}


# -------------------------------------------------------------- Aufträge

func _order_candidates() -> Array:
	var crops: Array = []
	var products: Array = []
	for id in GameData.CROPS:
		if int(GameData.CROPS[id]["level"]) <= level:
			crops.append(id)
	for id in GameData.RECIPES:
		var r: Dictionary = GameData.RECIPES[id]
		if int(r["level"]) <= level and has_building(r["building"]):
			products.append(id)
	return [crops, products]


func _available_cafe_specials() -> Array[String]:
	var available: Array[String] = []
	for recipe_id in GameData.CAFE_MENU:
		if GameData.RECIPES.has(recipe_id) and int(GameData.RECIPES[recipe_id]["level"]) <= level:
			available.append(recipe_id)
	return available


## Tagesangebote bleiben einen vollen echten Tag gültig und werden im Spielstand gespeichert.
func daily_cafe_special() -> String:
	if not has_building("cafe"):
		return ""
	_refresh_daily_cafe_special()
	return daily_cafe_special_id


func daily_cafe_special_seconds_left() -> float:
	if daily_cafe_special().is_empty():
		return 0.0
	return maxf(0.0, daily_cafe_special_at + CAFE_SPECIAL_DURATION - now())


func _refresh_daily_cafe_special() -> bool:
	if not has_building("cafe"):
		daily_cafe_special_id = ""
		daily_cafe_special_at = 0.0
		return false
	var available := _available_cafe_specials()
	if available.is_empty():
		daily_cafe_special_id = ""
		daily_cafe_special_at = 0.0
		return false
	var previous_index := available.find(daily_cafe_special_id)
	if previous_index >= 0 and daily_cafe_special_at > 0.0:
		var elapsed := now() - daily_cafe_special_at
		if elapsed < CAFE_SPECIAL_DURATION:
			return false
		var elapsed_periods := maxi(1, int(floor(elapsed / CAFE_SPECIAL_DURATION)))
		daily_cafe_special_id = available[(previous_index + elapsed_periods) % available.size()]
		daily_cafe_special_at += float(elapsed_periods) * CAFE_SPECIAL_DURATION
		return true
	daily_cafe_special_id = available[rng.randi_range(0, available.size() - 1)]
	daily_cafe_special_at = now()
	return true


func generate_order() -> Dictionary:
	if has_building("cafe") and rng.randf() < 0.25:
		var cafe_menu: Array[String] = _available_cafe_specials()
		if not cafe_menu.is_empty():
			var special_id := daily_cafe_special()
			var is_special := not special_id.is_empty() and rng.randf() < CAFE_SPECIAL_ORDER_CHANCE
			var cafe_item: String = special_id if is_special else cafe_menu[rng.randi_range(0, cafe_menu.size() - 1)]
			var cafe_recipe: Dictionary = GameData.RECIPES[cafe_item]
			var visitor_story: String = GameData.CAFE_VISITOR_STORIES[rng.randi_range(0, GameData.CAFE_VISITOR_STORIES.size() - 1)]
			var cafe_quantity := rng.randi_range(1, 2)
			var base_reward := int(cafe_recipe["sell"]) * cafe_quantity + 8
			var reward := int(ceil(float(base_reward) * (1.0 + CAFE_SPECIAL_COIN_BONUS))) if is_special else base_reward
			var bonus_xp := CAFE_SPECIAL_XP_BONUS if is_special else 0
			var cafe_order := {"id": _new_uid(), "customer": GameData.CUSTOMERS[rng.randi_range(0, GameData.CUSTOMERS.size() - 1)],
				"items": {cafe_item: cafe_quantity}, "coins": reward,
				"xp": maxi(4, int(cafe_recipe["xp"])) + bonus_xp, "cafe_order": true, "visitor_story": visitor_story}
			if is_special:
				cafe_order["cafe_daily_special"] = true
			return cafe_order
	var cand := _order_candidates()
	var crops: Array = cand[0]
	var products: Array = cand[1]
	var want := 1 + rng.randi_range(0, 1 if level < 5 else 2)
	var items: Dictionary = {}
	var tries := 0
	while items.size() < want and tries < 30:
		tries += 1
		var use_product := not products.is_empty() and rng.randf() < 0.45
		var pool: Array = products if use_product else crops
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if items.has(id):
			continue
		if use_product:
			items[id] = rng.randi_range(1, 2 + level / 8)
		else:
			items[id] = rng.randi_range(2, 4 + level / 6)
	var value := 0
	for id in items:
		value += int(GameData.items[id]["sell"]) * int(items[id])
	var reward := int(round(value * rng.randf_range(1.25, 1.55))) + 2
	return {
		"id": _new_uid(),
		"customer": GameData.CUSTOMERS[rng.randi_range(0, GameData.CUSTOMERS.size() - 1)],
		"items": items,
		"coins": reward,
		"xp": maxi(3, int(round(reward * 0.3))),
	}


func neighborhood_event_cycle_at(timestamp: float) -> int:
	return floori(timestamp / NEIGHBORHOOD_EVENT_CYCLE_SECONDS)


func neighborhood_event_seconds_left(timestamp: float = -1.0) -> float:
	var current_time := now() if timestamp < 0.0 else timestamp
	return maxf(0.0, float(neighborhood_event_cycle_at(current_time) + 1) * NEIGHBORHOOD_EVENT_CYCLE_SECONDS - current_time)


func neighborhood_event_active(timestamp: float = -1.0) -> bool:
	var current_time := now() if timestamp < 0.0 else timestamp
	return fposmod(current_time, NEIGHBORHOOD_EVENT_CYCLE_SECONDS) < NEIGHBORHOOD_EVENT_DURATION_SECONDS


func neighborhood_event_window_seconds_left(timestamp: float = -1.0) -> float:
	var current_time := now() if timestamp < 0.0 else timestamp
	var elapsed := fposmod(current_time, NEIGHBORHOOD_EVENT_CYCLE_SECONDS)
	return NEIGHBORHOOD_EVENT_DURATION_SECONDS - elapsed if elapsed < NEIGHBORHOOD_EVENT_DURATION_SECONDS else NEIGHBORHOOD_EVENT_CYCLE_SECONDS - elapsed


func _neighborhood_event_candidates(stage_index: int) -> Array[String]:
	var definition: Dictionary = GameData.NEIGHBORHOOD_EVENT_STAGES[stage_index]
	var candidates: Array[String] = []
	for crop_id in definition.get("crops", []):
		if GameData.CROPS.has(str(crop_id)) and int(GameData.CROPS[str(crop_id)]["level"]) <= level:
			candidates.append(str(crop_id))
	for recipe_id in definition.get("cafe_recipes", []):
		if GameData.RECIPES.has(str(recipe_id)) and int(GameData.RECIPES[str(recipe_id)]["level"]) <= level and has_building("cafe"):
			candidates.append(str(recipe_id))
	return candidates


func _ensure_neighborhood_event_order(cycle: int) -> bool:
	if neighborhood_event_order.has("cycle") and int(neighborhood_event_order.cycle) == cycle:
		return false
	if neighborhood_event_completed_cycle == cycle:
		return false
	if not neighborhood_event_active(float(cycle) * NEIGHBORHOOD_EVENT_CYCLE_SECONDS) or not has_building("cafe"):
		return false
	var stage_index := posmod(neighborhood_event_stage, NEIGHBORHOOD_EVENT_SERIES_LENGTH)
	var candidates := _neighborhood_event_candidates(stage_index)
	if candidates.is_empty():
		return false
	var item_id: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var quantity := rng.randi_range(2, 4) if GameData.CROPS.has(item_id) else 1
	var stage: Dictionary = GameData.NEIGHBORHOOD_EVENT_STAGES[stage_index]
	var base_reward := int(GameData.items[item_id]["sell"]) * quantity + 16
	var event_order := {"id": _new_uid(), "cycle": cycle, "stage": stage_index,
		"customer": GameData.CUSTOMERS[rng.randi_range(0, GameData.CUSTOMERS.size() - 1)],
		"items": {item_id: quantity}, "coins": base_reward + int(stage["bonus_coins"]),
		"xp": maxi(5, int(round(float(base_reward) * 0.25))) + int(stage["bonus_xp"]),
		"story": String(GameData.NEIGHBORHOOD_EVENT_STORIES[stage_index]), "cafe": stage_index == 2 and has_building("cafe")}
	neighborhood_event_order = event_order
	return true


func _fill_orders() -> void:
	var changed := _refresh_daily_cafe_special()
	var event_cycle := neighborhood_event_cycle_at(now())
	var event_active := neighborhood_event_active(now()) and has_building("cafe")
	if event_active and neighborhood_event_completed_cycle != event_cycle:
		changed = _ensure_neighborhood_event_order(event_cycle) or changed
	if not neighborhood_event_order.is_empty() and (int(neighborhood_event_order.get("cycle", -1)) != event_cycle or not event_active):
		neighborhood_event_order = {}
		changed = true
	for stale_index in range(orders.size() - 1, -1, -1):
		if orders[stale_index].has("neighborhood_event_cycle") and (int(orders[stale_index].neighborhood_event_cycle) != event_cycle or not event_active):
			orders.remove_at(stale_index)
			changed = true
	var reserve_story_slot := not active_delivery_story.is_empty() and not _has_story_order()
	var reserve_event_slot := event_active and neighborhood_event_order.has("cycle") and not _has_neighborhood_event_order(event_cycle)
	if event_active and neighborhood_event_order.has("cycle") and bool(neighborhood_event_order.get("cafe", false)) != has_building("cafe"):
		neighborhood_event_order["cafe"] = has_building("cafe")
		changed = true
	while orders.size() < MAX_ORDERS - (1 if reserve_story_slot else 0) - (1 if reserve_event_slot else 0) and now() >= next_order_at:
		orders.append(generate_order())
		next_order_at = now() + (0.0 if orders.size() < 3 else ORDER_COOLDOWN)
		changed = true
	for existing_index in range(orders.size() - 1, -1, -1):
		if int(orders[existing_index].get("neighborhood_event_cycle", -1)) == event_cycle:
			orders[existing_index]["neighborhood_event_cafe"] = has_building("cafe")
	# Die Geschichtenbestellung kommt vor der Event-Bestellung: Eine gerade angenommene Reihe
	# soll sofort beginnen, auch wenn gleichzeitig der Gartentag läuft. Reicht der Platz dann
	# nicht für beide, weicht unten eine gewöhnliche Bestellung der Event-Bestellung.
	if not active_delivery_story.is_empty() and orders.size() < MAX_ORDERS and not _has_story_order():
		var campaign: Dictionary = GameData.DELIVERY_STORIES.get(active_delivery_story, {})
		var stages: Array = campaign.get("stages", [])
		if delivery_story_stage < stages.size():
			var stage: Dictionary = stages[delivery_story_stage]
			orders.append({"id": _new_uid(), "customer": String(campaign["customer"]),
				"items": (stage["items"] as Dictionary).duplicate(), "coins": int(stage["coins"]), "xp": int(stage["xp"]),
				"story_id": active_delivery_story, "story_stage": delivery_story_stage, "story_text": String(stage["text"])})
			changed = true
	if reserve_event_slot and orders.size() >= MAX_ORDERS:
		var evicted_order := false
		for overflow_index in range(orders.size() - 1, -1, -1):
			if not orders[overflow_index].has("story_id") and not orders[overflow_index].has("visitor_story"):
				orders.remove_at(overflow_index)
				evicted_order = true
				break
		changed = changed or evicted_order
		if not evicted_order:
			reserve_event_slot = false
	if reserve_event_slot and orders.size() < MAX_ORDERS and not _has_neighborhood_event_order(event_cycle):
		var event_order := neighborhood_event_order.duplicate(true)
		event_order["neighborhood_event_cycle"] = event_cycle
		event_order["neighborhood_event_stage"] = int(neighborhood_event_order.stage)
		event_order["neighborhood_event_story"] = str(neighborhood_event_order.story)
		event_order["neighborhood_event_cafe"] = bool(neighborhood_event_order.cafe)
		orders.append(event_order)
		changed = true
	if changed:
		orders_changed.emit()


func _has_story_order() -> bool:
	for order in orders:
		if str(order.get("story_id", "")) == active_delivery_story:
			return true
	return false


func _has_neighborhood_event_order(cycle: int) -> bool:
	for order in orders:
		if int(order.get("neighborhood_event_cycle", -1)) == cycle:
			return true
	return false


func start_delivery_story(story_id: String) -> bool:
	if not GameData.DELIVERY_STORIES.has(story_id) or not active_delivery_story.is_empty():
		return false
	var campaign: Dictionary = GameData.DELIVERY_STORIES[story_id]
	if level < int(campaign["level"]):
		return false
	if campaign.has("requires_building") and not has_building(str(campaign["requires_building"])):
		last_error = "Baue zuerst das Gartencafé"
		return false
	active_delivery_story = story_id
	delivery_story_stage = 0
	if orders.size() >= MAX_ORDERS:
		# Eine optionale Standardbestellung weicht, damit die angenommene Reihe sofort beginnt.
		orders.pop_back()
	add_diary_entry("Begonnen: %s. %s" % [campaign["title"], campaign["intro"]])
	_fill_orders()
	orders_changed.emit()
	return true


func available_delivery_stories() -> Array:
	var result: Array = []
	for story_id in GameData.DELIVERY_STORIES:
		var story: Dictionary = GameData.DELIVERY_STORIES[story_id]
		var building_ready := not story.has("requires_building") or has_building(str(story["requires_building"]))
		if level >= int(story["level"]) and building_ready:
			result.append(story_id)
	return result


func find_order(order_id: int) -> int:
	for i in range(orders.size()):
		if int(orders[i].id) == order_id:
			return i
	return -1


func can_fulfill(order: Dictionary) -> bool:
	return has_items(order.items)


func fulfillable_orders() -> int:
	var n := 0
	for o in orders:
		if can_fulfill(o):
			n += 1
	return n


func fulfill_order(order_id: int) -> bool:
	var idx := find_order(order_id)
	if idx < 0:
		return false
	var o: Dictionary = orders[idx]
	if not take_items(o.items):
		last_error = "Dir fehlen noch Waren"
		return false
	orders.remove_at(idx)   # zuerst entfernen: keine doppelte Belohnung möglich
	next_order_at = now() + ORDER_COOLDOWN
	var cafe_story_id := str(o.get("story_id", ""))
	var is_cafe_story := cafe_story_id == active_delivery_story and GameData.DELIVERY_STORIES.has(cafe_story_id) and str(GameData.DELIVERY_STORIES[cafe_story_id].get("feature", "")) == "cafe"
	var neighborhood_event := int(o.get("neighborhood_event_cycle", -1)) >= 0
	var event_cafe_guest := neighborhood_event and bool(o.get("neighborhood_event_cafe", false)) and neighborhood_event_active()
	if bool(o.get("cafe_order", false)) or is_cafe_story or event_cafe_guest:
		bump("cafe_orders")
		if bool(o.get("cafe_daily_special", false)):
			bump("cafe_special_orders")
		var shared_story := str(o.get("visitor_story", o.get("story_text", "")))
		if not shared_story.is_empty():
			bump("cafe_stories_shared")
			add_diary_entry("%s erzählte im Gartencafé: %s" % [str(o.get("customer", "Ein Gast")), shared_story])
	var event_completed_now := false
	if neighborhood_event:
		var neighborhood_cycle := int(o.get("neighborhood_event_cycle", -1))
		if neighborhood_event_order.has("cycle") and neighborhood_cycle == int(neighborhood_event_order.get("cycle", -2)) and neighborhood_event_active():
			var event_stage := clampi(int(o.get("neighborhood_event_stage", 0)), 0, NEIGHBORHOOD_EVENT_SERIES_LENGTH - 1)
			var event_def: Dictionary = GameData.NEIGHBORHOOD_EVENT_STAGES[event_stage]
			neighborhood_event_stage = (event_stage + 1) % NEIGHBORHOOD_EVENT_SERIES_LENGTH
			var event_story := str(o.get("neighborhood_event_story", ""))
			add_diary_entry("Gartentag · %s: %s" % [String(event_def["name"]), event_story])
			if event_cafe_guest:
				bump("cafe_stories_shared")
			if event_stage == NEIGHBORHOOD_EVENT_SERIES_LENGTH - 1:
				add_coins(NEIGHBORHOOD_EVENT_FINALE_COINS)
				add_xp(NEIGHBORHOOD_EVENT_FINALE_XP)
				bump("neighborhood_events_completed")
				add_diary_entry("Der Gartentag endet mit einem langen Café-Nachmittag. Gemeinsam habt ihr drei Geschichten geteilt!")
				neighborhood_event_completed_cycle = neighborhood_cycle
				event_completed_now = true
			neighborhood_event_order = {}
	if o.has("story_id") and str(o["story_id"]) == active_delivery_story and GameData.DELIVERY_STORIES.has(active_delivery_story):
		var campaign: Dictionary = GameData.DELIVERY_STORIES[active_delivery_story]
		var completed_stage := delivery_story_stage
		delivery_story_stage += 1
		add_diary_entry("%s · Abschnitt %d abgeschlossen: %s" % [campaign["title"], completed_stage + 1, str(o.get("story_text", ""))])
		var stages: Array = campaign["stages"]
		if delivery_story_stage >= stages.size():
			if str(campaign.get("feature", "")) == "cafe":
				bump("cafe_stories_completed")
			add_coins(int(campaign["bonus_coins"]))
			add_xp(int(campaign["bonus_xp"]))
			bump("stories_completed")
			add_diary_entry("%s ist abgeschlossen. Die Nachbarschaft bedankt sich für deine Hilfe!" % campaign["title"])
			active_delivery_story = ""
			delivery_story_stage = 0
	add_coins(int(o.coins))
	add_xp(int(o.xp))
	bump("orders")
	orders_changed.emit()
	quests_changed.emit()
	if event_completed_now:
		toast.emit("Der Gartentag ist ein voller Erfolg! +%d Münzen · +%d XP" % [NEIGHBORHOOD_EVENT_FINALE_COINS, NEIGHBORHOOD_EVENT_FINALE_XP], "good")
		sound.emit("level")
	else:
		sound.emit("coin")
	event("order_done", {"id": order_id})
	return true


func skip_order(order_id: int) -> bool:
	var idx := find_order(order_id)
	if idx < 0 or orders[idx].has("story_id") or orders[idx].has("visitor_story") \
			or orders[idx].has("neighborhood_event_cycle"):
		return false   # Geschichts-, Café- und Gartentag-Gäste bleiben, bis ihre Bestellung angenommen wird
	orders.remove_at(idx)
	next_order_at = now() + ORDER_COOLDOWN
	orders_changed.emit()
	return true


# ------------------------------------------------------------- Tierrefugium

func animal_stat(a: Dictionary, key: String) -> float:
	var elapsed := maxf(0.0, now() - float(a.last))
	var rate := ANIMAL_DECAY_PER_SEC * (1.0 if key == "hunger" else 0.7)
	return clampf(float(a[key]) - elapsed * rate, 0.0, 100.0)


func wellbeing(a: Dictionary) -> float:
	return (animal_stat(a, "hunger") + animal_stat(a, "happy")) * 0.5


func _settle(a: Dictionary) -> void:
	a.hunger = animal_stat(a, "hunger")
	a.happy = animal_stat(a, "happy")
	a.last = now()


func get_animal(uid: int) -> Dictionary:
	for a in animals:
		if int(a.uid) == uid:
			return a
	return {}


func animals_in(paddock_uid: int) -> int:
	var n := 0
	for a in animals:
		if int(a.paddock) == paddock_uid:
			n += 1
	return n


func free_paddock() -> Dictionary:
	for o in objects:
		if o.kind == "paddock" and animals_in(int(o.uid)) < int(GameData.BUILDINGS[o.type]["capacity"]):
			return o
	return {}


func adopt_animal(species: String, rescue: bool = false) -> int:
	if not GameData.ANIMALS.has(species):
		return -1
	var d: Dictionary = GameData.ANIMALS[species]
	if level < int(d["level"]):
		last_error = "Ab Stufe %d" % int(d["level"])
		return -1
	if rescue and (rescue_case.is_empty() or str(rescue_case.get("species", "")) != species):
		last_error = "Dieser Rettungsfall ist nicht mehr verfügbar"
		return -1
	var pad: Dictionary = free_paddock()
	if pad.is_empty():
		last_error = "Du brauchst ein Gehege mit freiem Platz"
		return -1
	if not rescue and not spend_coins(int(d["cost"])):
		last_error = "Nicht genug Münzen"
		return -1
	var used: Array = []
	for a in animals:
		used.append(a.name)
	var names: Array = d["names"]
	var nm := _next_animal_name(names, used, animals.size() + 1)
	var stories: Array = d["stories"]
	var a := {
		"uid": _new_uid(), "species": species, "name": nm,
		"story": int(rescue_case.get("story", 0)) if rescue else rng.randi_range(0, stories.size() - 1),
		"hunger": 70.0, "happy": 70.0, "hearts": 0, "last": now(),
		"paddock": int(pad.uid), "pet_at": 0.0, "activity_at": 0.0,
		"traits": _choose_animal_traits(species), "accessories": [],
	}
	animals.append(a)
	add_diary_entry("%s hat im Refugium ein sicheres Zuhause gefunden." % a.name, int(a.uid))
	if rescue:
		rescue_case = {}
		next_rescue_at = now() + RESCUE_COOLDOWN
		animals_changed.emit()
		event("rescue_accepted", {"species": species, "uid": a.uid})
	else:
		animals_changed.emit()
	quests_changed.emit()
	sound.emit("pet")
	event("adopted", {"species": species, "uid": a.uid})
	return int(a.uid)


func animals_in_paddock(paddock_uid: int) -> Array:
	var result: Array = []
	for a in animals:
		if int(a.get("paddock", -1)) == paddock_uid:
			result.append(a)
	return result


func _next_animal_name(names: Array, used: Array, sequence: int) -> String:
	var available: Array = []
	for candidate in names:
		if not used.has(candidate):
			available.append(String(candidate))
	if not available.is_empty():
		return String(available[rng.randi_range(0, available.size() - 1)])
	var base_name := String(names[(sequence - 1) % names.size()])
	var suffix := maxi(2, int(floor(float(sequence - 1) / float(names.size()))) + 1)
	var unique_name := "%s %d" % [base_name, suffix]
	while used.has(unique_name):
		suffix += 1
		unique_name = "%s %d" % [base_name, suffix]
	return unique_name


func _choose_animal_traits(species: String) -> Array:
	var available: Array = GameData.ANIMALS.get(species, {}).get("traits", []).duplicate()
	var chosen: Array = []
	while not available.is_empty() and chosen.size() < 2:
		var index := rng.randi_range(0, available.size() - 1)
		chosen.append(available.pop_at(index))
	return chosen


func _refresh_rescue_case() -> void:
	if level < 3 or count_type("paddock") == 0:
		return
	if not rescue_case.is_empty():
		return
	if now() < next_rescue_at or free_paddock().is_empty():
		return
	var eligible: Array = []
	for species in GameData.ANIMALS:
		if level >= int(GameData.ANIMALS[species]["level"]):
			eligible.append(species)
	if eligible.is_empty():
		return
	var species: String = eligible[rng.randi_range(0, eligible.size() - 1)]
	var stories: Array = GameData.ANIMALS[species]["stories"]
	rescue_case = {"species": species, "story": rng.randi_range(0, stories.size() - 1)}
	animals_changed.emit()
	event("rescue_offered", {"species": species})


func activity_cooldown_left(a: Dictionary) -> float:
	return maxf(0.0, float(a.get("activity_at", 0.0)) - now())


func animal_activity(uid: int) -> bool:
	var a := get_animal(uid)
	if a.is_empty() or activity_cooldown_left(a) > 0.0:
		return false
	_settle(a)
	a.happy = minf(100.0, float(a.happy) + 12.0)
	a.activity_at = now() + ACTIVITY_COOLDOWN
	record_animal_moment(a, "ihr habt zusammen gespielt", 1)
	add_xp(1)
	bump("activities")
	animals_changed.emit()
	quests_changed.emit()
	sound.emit("pet")
	event("played", {"uid": uid, "species": a.species})
	return true


func set_animal_cosmetic(uid: int, cosmetic_id: String, equipped: bool) -> bool:
	var a := get_animal(uid)
	if a.is_empty():
		return false
	var unlocked := cosmetics_of(a)
	if not unlocked.has(cosmetic_id):
		last_error = "Diese Belohnung ist noch nicht freigeschaltet"
		return false
	var equipped_items: Array = a.get("accessories", []).duplicate()
	if equipped and not equipped_items.has(cosmetic_id):
		equipped_items.append(cosmetic_id)
	elif not equipped:
		equipped_items.erase(cosmetic_id)
	a.accessories = equipped_items
	animals_changed.emit()
	return true


func equipped_cosmetics_of(a: Dictionary) -> Array:
	var unlocked := cosmetics_of(a)
	var result: Array = []
	for id in a.get("accessories", []):
		if unlocked.has(id):
			result.append(id)
	return result


func feed_animal(uid: int) -> bool:
	var a := get_animal(uid)
	if a.is_empty():
		return false
	var food: String = GameData.ANIMALS[a.species]["food"]
	if animal_stat(a, "hunger") >= 95.0:
		last_error = "%s ist schon satt" % a.name
		return false
	if not remove_item(food, 1):
		last_error = "Dir fehlt: %s" % GameData.item_name(food)
		return false
	_settle(a)
	a.hunger = minf(100.0, float(a.hunger) + 45.0)
	record_animal_moment(a, "wurde liebevoll gefüttert", 2)
	add_xp(3)
	bump("fed")
	animals_changed.emit()
	quests_changed.emit()
	sound.emit("pet")
	event("fed", {"uid": uid})
	return true


func pet_cooldown_left(a: Dictionary) -> float:
	return maxf(0.0, float(a.pet_at) - now())


func pet_animal(uid: int) -> bool:
	var a := get_animal(uid)
	if a.is_empty() or pet_cooldown_left(a) > 0.0:
		return false
	_settle(a)
	a.happy = minf(100.0, float(a.happy) + 18.0)
	a.pet_at = now() + PET_COOLDOWN
	record_animal_moment(a, "hat eine ruhige Streicheleinheit genossen", 1)
	add_xp(1)
	bump("pets")
	animals_changed.emit()
	quests_changed.emit()
	sound.emit("pet")
	event("petted", {"uid": uid})
	return true


func cosmetics_of(a: Dictionary) -> Array:
	var out: Array = []
	for c in GameData.COSMETICS:
		if int(a.hearts) >= int(c["hearts"]):
			out.append(c["id"])
	return out


# ----------------------------------------------------------------- Quests

func quest_progress(q: Dictionary) -> int:
	match q["type"]:
		"stat":
			return int(stats.get(q["key"], 0))
		"level":
			return level
		"building":
			return count_type(q["building"])
		"animals":
			return animals.size()
		"decos":
			var n := 0
			for o in objects:
				if o.kind == "deco":
					n += 1
			return n
	return 0


func achievement_progress(achievement: Dictionary) -> int:
	match str(achievement["type"]):
		"stat":
			return int(stats.get(str(achievement["key"]), 0))
		"animals":
			return animals.size()
		"building":
			return count_type(str(achievement.get("key", achievement.get("building", ""))))
		"friendship":
			var best := 0
			for animal in animals:
				best = maxi(best, int(animal.get("hearts", 0)))
			return best
	return 0


func achievement_unlocked(achievement: Dictionary) -> bool:
	return achievement_progress(achievement) >= int(achievement["target"])


func claimable_achievements() -> int:
	var count := 0
	for achievement in GameData.ACHIEVEMENTS:
		if achievement_unlocked(achievement) and not claimed_achievements.has(achievement["id"]):
			count += 1
	return count


func claim_achievement(id: String) -> bool:
	for achievement in GameData.ACHIEVEMENTS:
		if str(achievement["id"]) != id:
			continue
		if claimed_achievements.has(id) or not achievement_unlocked(achievement):
			return false
		claimed_achievements.append(id)
		add_coins(int(achievement["coins"]))
		add_xp(int(achievement["xp"]))
		quests_changed.emit()
		sound.emit("coin")
		return true
	return false


func quest_done(q: Dictionary) -> bool:
	return quest_progress(q) >= int(q["target"])


func quest_claimed(id: String) -> bool:
	return claimed_quests.has(id)


func claimable_quests() -> int:
	var n := 0
	for q in GameData.QUESTS:
		if quest_done(q) and not quest_claimed(q["id"]):
			n += 1
	return n


func claim_quest(id: String) -> bool:
	for q in GameData.QUESTS:
		if q["id"] == id:
			if quest_claimed(id) or not quest_done(q):
				return false
			claimed_quests.append(id)   # zuerst markieren: keine doppelte Belohnung
			add_coins(int(q["coins"]))
			add_xp(int(q["xp"]))
			quests_changed.emit()
			sound.emit("coin")
			return true
	return false


# ------------------------------------------------------ Offline-Fortschritt

func offline_report() -> Dictionary:
	var ready_fields := 0
	for cell in fields:
		if is_ready(cell):
			ready_fields += 1
	var ready_products := 0
	for o in objects:
		if o.kind == "production":
			ready_products += ready_count(o)
	return {"fields": ready_fields, "products": ready_products, "away": away_seconds}


# ------------------------------------------------------------ Speichern

func serialize() -> Dictionary:
	var f: Array = []
	for cell in fields:
		f.append({"x": cell.x, "y": cell.y, "crop": fields[cell].crop, "t": fields[cell].t})
	var objs: Array = []
	for o in objects:
		objs.append({"uid": o.uid, "kind": o.kind, "type": o.type, "x": o.cell.x, "y": o.cell.y,
			"queue": (o.queue as Array).duplicate(true), "upgrades": o.upgrades})
	return {
		"version": SAVE_VERSION,
		"saved_at": now(),
		"coins": coins, "level": level, "xp": xp,
		"inventory": inventory.duplicate(),
		"fields": f, "objects": objs,
		"animals": animals.duplicate(true),
		"rescue_case": rescue_case.duplicate(true),
		"next_rescue_at": next_rescue_at,
		"land": [land.position.x, land.position.y, land.size.x, land.size.y],
		"land_level": land_level,
		"orders": orders.duplicate(true),
		"active_delivery_story": active_delivery_story,
		"delivery_story_stage": delivery_story_stage,
		"daily_cafe_special_id": daily_cafe_special_id,
		"daily_cafe_special_at": daily_cafe_special_at,
		"neighborhood_event_stage": neighborhood_event_stage,
		"neighborhood_event_order": neighborhood_event_order.duplicate(true),
		"neighborhood_event_completed_cycle": neighborhood_event_completed_cycle,
		"diary": diary.duplicate(true),
		"stats": stats.duplicate(),
		"claimed_quests": claimed_quests.duplicate(),
		"claimed_achievements": claimed_achievements.duplicate(),
		"settings": settings.duplicate(),
		"tutorial_step": tutorial_step,
		"next_uid": next_uid,
		"next_order_at": next_order_at,
	}


## Liefert ein Array aus einem geladenen Spielstand; ein Wert mit falschem Typ zählt als leer.
func _save_array(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	if typeof(v) == TYPE_ARRAY:
		return v
	return []


## Wie _save_array, für Dictionaries.
func _save_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}


## Prüft, ob ein geladener Eintrag ein Dictionary mit allen Schlüsseln ist.
func _has_keys(e: Variant, keys: Array) -> bool:
	if typeof(e) != TYPE_DICTIONARY:
		return false
	for k in keys:
		if not (e as Dictionary).has(k):
			return false
	return true


func _world_rect() -> Rect2i:
	return Rect2i(GameData.WORLD_ORIGIN, Vector2i(GameData.WORLD_COLS, GameData.WORLD_ROWS))


## Liest einen (bereits migrierten) Spielstand. Ungültige Einträge werden
## verworfen, negative Bestände, unbekannte IDs, doppelte UIDs, überlappende
## Objekte und Einträge außerhalb der Welt können nicht entstehen. Ein Stand aus
## einer neueren Spielversion wird abgelehnt, bevor der aktuelle Zustand angetastet wird.
func deserialize(d: Dictionary) -> bool:
	if not d.has("version"):
		return false
	if int(d.get("version", 0)) > SAVE_VERSION:
		last_error = "Der Spielstand stammt aus einer neueren Version des Spiels"
		return false
	reset_state()
	var world := _world_rect()
	coins = maxi(0, int(d.get("coins", 0)))
	level = clampi(int(d.get("level", 1)), 1, GameData.MAX_LEVEL)
	xp = maxi(0, int(d.get("xp", 0)))
	var inv := _save_dict(d, "inventory")
	for id in inv:
		var n := int(inv[id])
		if GameData.items.has(id) and n > 0:
			inventory[id] = n
	var l := _save_array(d, "land")
	if l.size() == 4:
		var saved_land := Rect2i(int(l[0]), int(l[1]), int(l[2]), int(l[3]))
		if saved_land.size.x > 0 and saved_land.size.y > 0 and world.encloses(saved_land):
			land = saved_land
	land_level = clampi(int(d.get("land_level", 0)), 0, GameData.LAND_EXPANSIONS.size())
	for e in _save_array(d, "fields"):
		if not _has_keys(e, ["x", "y"]):
			continue
		var cell := Vector2i(int(e["x"]), int(e["y"]))
		if not world.has_point(cell):
			continue
		var crop: String = str(e.get("crop", ""))
		if crop != "" and not GameData.CROPS.has(crop):
			crop = ""
		fields[cell] = {"crop": crop, "t": float(e.get("t", 0.0))}
	var object_uids := {}
	for e in _save_array(d, "objects"):
		if not _has_keys(e, ["uid", "type", "x", "y"]):
			continue
		var type: String = str(e["type"])
		var definition := GameData.object_def(type)
		var object_uid := int(e["uid"])
		if definition.is_empty() or object_uid <= 0 or object_uids.has(object_uid):
			continue
		var object_cell := Vector2i(int(e["x"]), int(e["y"]))
		var footprint := footprint_cells(type, object_cell)
		var fits := true
		for c in footprint:
			if not world.has_point(c) or _occ.has(c):
				fits = false
				break
		if not fits:
			continue
		var queue: Array = []
		for qe in _save_array(e, "queue"):
			if _has_keys(qe, ["recipe", "start", "end"]) and GameData.RECIPES.has(str(qe["recipe"])):
				queue.append({"recipe": str(qe["recipe"]), "start": float(qe["start"]), "end": float(qe["end"])})
		objects.append({"uid": object_uid, "kind": definition["kind"], "type": type,
			"cell": object_cell, "queue": queue, "upgrades": clampi(int(e.get("upgrades", 0)), 0, MAX_UPGRADES)})
		object_uids[object_uid] = true
		for c in footprint:
			_occ[c] = object_uid
	for c in _occ:
		fields.erase(c)   # Objekte haben Vorrang vor Feldern auf derselben Zelle
	var animal_uids := {}
	for e in _save_array(d, "animals"):
		if not _has_keys(e, ["uid", "species"]) or not GameData.ANIMALS.has(str(e["species"])):
			continue
		var animal_uid := int(e["uid"])
		if animal_uid <= 0 or animal_uids.has(animal_uid):
			continue
		animal_uids[animal_uid] = true
		var species: String = str(e["species"])
		var valid_traits: Array = []
		for trait_id in _save_array(e, "traits"):
			if GameData.ANIMAL_TRAITS.has(str(trait_id)) and GameData.ANIMALS[species]["traits"].has(str(trait_id)) and not valid_traits.has(str(trait_id)):
				valid_traits.append(str(trait_id))
		if valid_traits.is_empty():
			valid_traits = _choose_animal_traits(species)
		var hearts := maxi(0, int(e.get("hearts", 0)))
		var valid_accessories: Array = []
		for cosmetic in _save_array(e, "accessories"):
			for definition in GameData.COSMETICS:
				if str(definition["id"]) == str(cosmetic) and hearts >= int(definition["hearts"]) and not valid_accessories.has(str(cosmetic)):
					valid_accessories.append(str(cosmetic))
		var paddock_uid := int(e.get("paddock", -1))
		var paddock_object := get_object(paddock_uid)
		if paddock_object.is_empty() or str(paddock_object["kind"]) != "paddock":
			paddock_uid = -1
		animals.append({"uid": animal_uid, "species": species, "name": str(e.get("name", "Tier")),
			"story": clampi(int(e.get("story", 0)), 0, GameData.ANIMALS[species]["stories"].size() - 1),
			"traits": valid_traits, "hunger": clampf(float(e.get("hunger", 70)), 0.0, 100.0), "happy": clampf(float(e.get("happy", 70)), 0.0, 100.0),
			"hearts": hearts, "last": float(e.get("last", now())),
			"paddock": paddock_uid, "pet_at": float(e.get("pet_at", 0.0)),
			"activity_at": float(e.get("activity_at", 0.0)), "accessories": valid_accessories})
	for a in animals:
		if int(a.paddock) < 0:
			# Tiere ohne gültiges Gehege ziehen in ein Gehege mit freiem Platz (falls vorhanden).
			var pad := free_paddock()
			if not pad.is_empty():
				a.paddock = int(pad.uid)
	var saved_rescue := _save_dict(d, "rescue_case")
	if GameData.ANIMALS.has(str(saved_rescue.get("species", ""))):
		var rescue_species: String = str(saved_rescue["species"])
		rescue_case = {"species": rescue_species,
			"story": clampi(int(saved_rescue.get("story", 0)), 0, GameData.ANIMALS[rescue_species]["stories"].size() - 1)}
	next_rescue_at = float(d.get("next_rescue_at", 0.0))
	active_delivery_story = str(d.get("active_delivery_story", ""))
	if not GameData.DELIVERY_STORIES.has(active_delivery_story):
		active_delivery_story = ""
	var order_ids := {}
	for e in _save_array(d, "orders"):
		if not _has_keys(e, ["id", "items"]) or typeof(e["items"]) != TYPE_DICTIONARY:
			continue
		var order_id := int(e["id"])
		if order_id <= 0 or order_ids.has(order_id) or orders.size() >= MAX_ORDERS:
			continue
		var items: Dictionary = {}
		for id in e["items"]:
			if GameData.items.has(id) and int(e["items"][id]) > 0:
				items[id] = int(e["items"][id])
		if items.is_empty():
			continue
		var story_id := str(e.get("story_id", ""))
		if GameData.DELIVERY_STORIES.has(story_id) and story_id != active_delivery_story:
			continue   # Auftrag einer nicht (mehr) aktiven Geschichte: sonst bliebe er unüberspringbar liegen
		order_ids[order_id] = true
		var order := {"id": order_id, "customer": str(e.get("customer", "Gast")), "items": items,
			"coins": maxi(0, int(e.get("coins", 0))), "xp": maxi(0, int(e.get("xp", 0)))}
		if GameData.DELIVERY_STORIES.has(story_id):
			order["story_id"] = story_id
			order["story_stage"] = int(e.get("story_stage", 0))
			order["story_text"] = str(e.get("story_text", ""))
		if bool(e.get("cafe_order", false)):
			order["cafe_order"] = true
			order["visitor_story"] = str(e.get("visitor_story", ""))
		if bool(e.get("cafe_daily_special", false)):
			order["cafe_daily_special"] = true
		if int(e.get("neighborhood_event_cycle", -1)) >= 0:
			order["neighborhood_event_cycle"] = int(e["neighborhood_event_cycle"])
			order["neighborhood_event_stage"] = clampi(int(e.get("neighborhood_event_stage", 0)), 0, NEIGHBORHOOD_EVENT_SERIES_LENGTH - 1)
			order["neighborhood_event_story"] = str(e.get("neighborhood_event_story", ""))
			order["neighborhood_event_cafe"] = bool(e.get("neighborhood_event_cafe", false))
		orders.append(order)
	var st := _save_dict(d, "stats")
	for k in st:
		stats[k] = int(st[k])
	daily_cafe_special_id = str(d.get("daily_cafe_special_id", ""))
	daily_cafe_special_at = maxf(0.0, float(d.get("daily_cafe_special_at", 0.0)))
	if not GameData.CAFE_MENU.has(daily_cafe_special_id):
		daily_cafe_special_id = ""
		daily_cafe_special_at = 0.0
	neighborhood_event_stage = posmod(int(d.get("neighborhood_event_stage", 0)), NEIGHBORHOOD_EVENT_SERIES_LENGTH)
	neighborhood_event_completed_cycle = int(d.get("neighborhood_event_completed_cycle", -1))
	var saved_event := _save_dict(d, "neighborhood_event_order")
	if saved_event.has("cycle") and typeof(saved_event.get("items", {})) == TYPE_DICTIONARY:
		var valid_event_items: Dictionary = {}
		for event_item in saved_event.get("items", {}):
			if GameData.items.has(str(event_item)) and int(saved_event["items"][event_item]) > 0:
				valid_event_items[str(event_item)] = int(saved_event["items"][event_item])
		if not valid_event_items.is_empty():
			neighborhood_event_order = {"id": maxi(1, int(saved_event.get("id", 0))),
				"cycle": int(saved_event["cycle"]), "stage": clampi(int(saved_event.get("stage", 0)), 0, NEIGHBORHOOD_EVENT_SERIES_LENGTH - 1),
				"customer": str(saved_event.get("customer", "Ein Nachbar")), "items": valid_event_items,
				"coins": maxi(0, int(saved_event.get("coins", 0))), "xp": maxi(0, int(saved_event.get("xp", 0))),
				"story": str(saved_event.get("story", "")), "cafe": bool(saved_event.get("cafe", false))}
	var story_stage_count := int(GameData.DELIVERY_STORIES.get(active_delivery_story, {}).get("stages", []).size())
	delivery_story_stage = clampi(int(d.get("delivery_story_stage", 0)), 0, maxi(0, story_stage_count - 1)) if not active_delivery_story.is_empty() else 0
	for entry in _save_array(d, "diary"):
		if _has_keys(entry, ["text"]):
			diary.append({"time": float(entry.get("time", now())), "text": str(entry["text"]), "animal_uid": int(entry.get("animal_uid", -1))})
	while diary.size() > 100:
		diary.pop_front()
	claimed_quests = []
	for quest_id in _save_array(d, "claimed_quests"):
		for q in GameData.QUESTS:
			if str(q["id"]) == str(quest_id):
				if not claimed_quests.has(str(quest_id)):
					claimed_quests.append(str(quest_id))
				break
	claimed_achievements = []
	for achievement_id in _save_array(d, "claimed_achievements"):
		for achievement in GameData.ACHIEVEMENTS:
			if str(achievement["id"]) == str(achievement_id):
				if not claimed_achievements.has(str(achievement_id)):
					claimed_achievements.append(str(achievement_id))
				break
	var s := _save_dict(d, "settings")
	settings["sound"] = bool(s.get("sound", true))
	settings["music"] = bool(s.get("music", true))
	settings["vibration"] = bool(s.get("vibration", true))
	tutorial_step = int(d.get("tutorial_step", 0))
	# next_uid darf nie auf eine bereits vergebene ID zeigen, auch nicht bei beschädigten Ständen.
	var max_uid := 0
	for o in objects:
		max_uid = maxi(max_uid, int(o.uid))
	for a in animals:
		max_uid = maxi(max_uid, int(a.uid))
	for o in orders:
		max_uid = maxi(max_uid, int(o.id))
	if not neighborhood_event_order.is_empty():
		max_uid = maxi(max_uid, int(neighborhood_event_order.id))
	next_uid = maxi(maxi(int(d.get("next_uid", 1)), 1), max_uid + 1)
	next_order_at = float(d.get("next_order_at", 0.0))
	away_seconds = maxf(0.0, now() - float(d.get("saved_at", now())))
	rebuild_occupancy()
	loaded = true
	_fill_orders()
	_emit_all()
	return true
