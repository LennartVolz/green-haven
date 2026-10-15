extends SceneTree
## Headless-Tests für Spiellogik, Wirtschaft und Speicherstand.
## Start:  godot --headless --path . -s res://tests/run_tests.gd
## Exit-Code 0 = alle Tests bestanden.

var world_script: GDScript
var gs: Node
var gd: Node
var ss: Node
var passed := 0
var failed := 0
var section := ""


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  FAIL [%s] %s" % [section, msg])


func begin(name: String) -> void:
	section = name
	print("• ", name)
	gs.time_offset = 0.0
	gs.new_game()
	gs.rng.seed = 12345


func level_to(n: int) -> void:
	while gs.level < n:
		gs.add_xp(gd.xp_needed(gs.level))


func _initialize() -> void:
	gs = root.get_node("GameState")
	gd = root.get_node("GameData")
	ss = root.get_node("SaveSystem")
	world_script = load("res://scripts/world/world.gd")
	ss.path_override = "user://test_save.json"
	ss.delete_save()
	test_new_game()
	test_day_night()
	test_farming()
	test_inventory()
	test_levels()
	test_production()
	test_orders()
	test_delivery_stories()
	test_cafe()
	test_achievements()
	test_quests()
	test_animals()
	test_animal_extensions()
	test_land_and_objects()
	test_save_roundtrip()
	test_offline_progress()
	test_corrupt_and_migration()
	test_economy()
	test_new_crops()
	ss.delete_save()
	print("")
	print("Ergebnis: %d bestanden, %d fehlgeschlagen" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_day_night() -> void:
	begin("Tag-Nacht-Zyklus")
	check(world_script.daylight_at(0.0) < 0.01, "Mitternacht ist dunkel")
	check(world_script.daylight_at(12.0 * 3600.0) > 0.99, "Mittag ist hell")
	check(world_script.daylight_at(6.0 * 3600.0) < world_script.daylight_at(9.0 * 3600.0), "Sonnenaufgang wird heller")
	check(world_script.daylight_at(18.0 * 3600.0) > world_script.daylight_at(21.0 * 3600.0), "Sonnenuntergang wird dunkler")
	check(world_script.clock_text_at(8.0 * 3600.0) == "08:00 · Tag", "Uhr zeigt Tageszeit")
	check(world_script.clock_text_at(20.0 * 3600.0) == "20:00 · Nacht", "Uhr zeigt Nachtzeit")
	check(world_script.weather_at(0.0) == "Sonnig", "Wetterzyklus startet sonnig")
	check(world_script.weather_at(120.0) == "Bewölkt", "Wetter wechselt zu bewölkt")
	check(world_script.weather_at(240.0) == "Regen", "Wetter wechselt zu Regen")
	check(world_script.weather_at(360.0) == "Nebel", "Wetter wechselt zu Nebel")
	check(world_script.weather_at(480.0) == "Sonnig", "Wetterzyklus wiederholt sich")
	check(world_script.weather_tint_at("Regen") != Color.WHITE, "Regen verändert die Lichtfarbe")


func test_new_game() -> void:
	begin("Neues Spiel")
	check(gs.coins == gd.START_COINS, "Startmünzen")
	check(gs.level == 1 and gs.xp == 0, "Start auf Stufe 1")
	check(gs.fields.size() == 4, "vier Startfelder")
	check(gs.orders.size() >= 1, "Aufträge werden erzeugt")
	check(gs.inventory.is_empty(), "leeres Inventar")


func test_farming() -> void:
	begin("Anbau und Ernte")
	var cell: Vector2i = gs.fields.keys()[0]
	check(not gs.plant(cell, "tomato"), "Tomate ist auf Stufe 1 gesperrt")
	var before: int = gs.coins
	check(gs.plant(cell, "wheat"), "Weizen pflanzen")
	check(gs.coins == before - 1, "Saatgut kostet Münzen")
	check(not gs.plant(cell, "wheat"), "nicht doppelt auf dasselbe Feld")
	check(not gs.harvest(cell), "unreif nicht erntbar")
	check(gs.crop_stage(cell) == 0, "Phase 0 direkt nach dem Säen")
	gs.time_offset += 10.0
	check(gs.crop_stage(cell) == 1, "Phase 1 nach 1/3 der Zeit")
	gs.time_offset += 12.0
	check(gs.crop_stage(cell) == 2, "Phase 2 nach ~73%")
	gs.time_offset += 10.0
	check(gs.is_ready(cell), "nach 32 s reif")
	check(gs.crop_stage(cell) == 3, "Phase 3 = reif")
	check(gs.harvest(cell), "ernten")
	check(gs.item_count("wheat") == 2, "Erntemenge 2")
	check(gs.xp == 2, "XP aus Ernte")
	check(not gs.harvest(cell), "keine doppelte Ernte")
	check(gs.fields[cell].crop == "", "Feld ist danach frei")
	# Kein Geld, kein Saatgut
	gs.coins = 0
	check(not gs.plant(cell, "wheat"), "ohne Münzen kein Säen")
	check(gs.coins == 0, "Münzen bleiben 0")
	check(gs.item_count("wheat") == 2, "Inventar unverändert")


func test_inventory() -> void:
	begin("Inventar")
	check(not gs.remove_item("wheat", 1), "nichts zu entfernen")
	gs.add_item("wheat", 3)
	gs.add_item("carrot", 1)
	check(not gs.take_items({"wheat": 2, "carrot": 2}), "atomar: fehlende Zutat verhindert alles")
	check(gs.item_count("wheat") == 3 and gs.item_count("carrot") == 1, "nichts wurde abgezogen")
	check(gs.take_items({"wheat": 2, "carrot": 1}), "vollständig vorhanden")
	check(gs.item_count("wheat") == 1 and gs.item_count("carrot") == 0, "korrekt abgezogen")
	check(not gs.inventory.has("carrot"), "Bestand 0 wird entfernt")
	gs.add_item("nonsense", 5)
	check(not gs.inventory.has("nonsense"), "unbekannte Items werden abgelehnt")
	gs.add_item("wheat", -4)
	check(gs.item_count("wheat") == 1, "negative Mengen werden ignoriert")
	var c0: int = gs.coins
	check(gs.sell_item("wheat", 5) == 3, "Verkauf begrenzt auf Bestand")
	check(gs.coins == c0 + 3, "Münzen aus Verkauf")
	check(gs.sell_item("wheat", 1) == 0, "nichts mehr zu verkaufen")
	check(not gs.buy_item("almond", 1), "Mandeln erst ab Stufe 5")
	level_to(5)
	gs.coins = 100
	check(gs.buy_item("almond", 2), "Mandeln kaufen")
	check(gs.coins == 100 - 24, "Mandelpreis")
	check(gs.item_count("almond") == 2, "Mandeln im Inventar")
	check(not gs.spend_coins(1000), "zu teuer")
	check(gs.coins == 76, "Münzen unverändert bei Fehlschlag")


func test_levels() -> void:
	begin("Level")
	var got: Array = []
	gs.level_up.connect(func(l: int, _u: Array) -> void: got.append(l))
	gs.add_xp(gd.xp_needed(1) + gd.xp_needed(2) + 3)
	check(gs.level == 3, "zwei Aufstiege auf einmal")
	check(gs.xp == 3, "Rest-XP bleibt")
	check(got == [2, 3], "level_up Signale")
	gs.level_up.disconnect(gs.level_up.get_connections()[0]["callable"])
	level_to(gd.MAX_LEVEL)
	check(gs.level == gd.MAX_LEVEL, "Maximalstufe")
	gs.add_xp(99999)
	check(gs.level == gd.MAX_LEVEL and gs.xp == 0, "kein Überlauf auf Maximalstufe")
	check(gd.unlocks_at(2).has("Bäckerei"), "Stufe 2 schaltet Bäckerei frei")


func test_production() -> void:
	begin("Produktion")
	check(gs.place_object("bakery", Vector2i(8, 11)) == -1, "Bäckerei erst ab Stufe 2")
	level_to(2)
	gs.coins = 1000
	var uid: int = gs.place_object("bakery", Vector2i(8, 11))
	check(uid > 0, "Bäckerei bauen")
	check(gs.coins == 850, "Baukosten")
	check(gs.place_object("bakery", Vector2i(10, 11)) == -1, "nur eine Bäckerei")
	check(gs.place_object("tree", Vector2i(8, 11)) == -1, "Fläche belegt")
	check(not gs.start_recipe(uid, "bread"), "ohne Zutaten kein Start")
	gs.add_item("wheat", 7)
	check(gs.start_recipe(uid, "bread"), "Vollkornbrot starten")
	check(gs.item_count("wheat") == 4, "Zutaten verbraucht")
	check(gs.start_recipe(uid, "bread"), "zweiter Slot")
	check(not gs.start_recipe(uid, "bread"), "Warteschlange voll (2 Slots)")
	check(gs.item_count("wheat") == 1, "bei vollem Slot keine Zutaten abgezogen")
	check(not gs.start_recipe(uid, "carrot_soup"), "falsches Gebäude")
	check(not gs.start_recipe(uid, "oat_cookies"), "Rezept erst ab Stufe 3")
	var o: Dictionary = gs.get_object(uid)
	check(gs.ready_count(o) == 0, "noch nichts fertig")
	check(gs.collect_ready(uid).is_empty(), "nichts abzuholen")
	gs.time_offset += 61.0
	check(gs.ready_count(o) == 1, "erstes Brot nach 60 s")
	var got: Array = gs.collect_ready(uid)
	check(got.size() == 1 and gs.item_count("bread") == 1, "einmal abholen")
	check(gs.collect_ready(uid).is_empty(), "keine doppelte Abholung")
	gs.time_offset += 60.0
	check(gs.collect_ready(uid).size() == 1, "zweites Brot sequenziell fertig")
	check(gs.item_count("bread") == 2, "zwei Brote insgesamt")
	check(gs.stats.get("crafted", 0) == 2, "Statistik")
	# Ausbau
	var c: int = gs.coins
	check(gs.upgrade_building(uid), "Slot ausbauen")
	check(gs.coins == c - 200, "Ausbaukosten")
	check(gs.queue_capacity(o) == 3, "3 Slots")
	# Verkaufen nur bei leerer Warteschlange
	gs.add_item("wheat", 3)
	gs.start_recipe(uid, "bread")
	check(not gs.sell_object(uid), "Verkauf blockiert bei laufender Produktion")
	gs.time_offset += 70.0
	gs.collect_ready(uid)
	check(gs.sell_object(uid), "Verkauf möglich")
	check(gs.object_at(Vector2i(8, 11)).is_empty(), "Fläche wieder frei")


func test_orders() -> void:
	begin("Aufträge")
	check(gs.orders.size() > 0, "Aufträge vorhanden")
	for i in range(40):
		var o: Dictionary = gs.generate_order()
		check(o.coins > 0 and o.xp > 0 and not o.items.is_empty(), "gültiger Auftrag")
		for id in o.items:
			check(gd.items.has(id) and int(o.items[id]) > 0, "gültige Position")
	var order: Dictionary = gs.orders[0]
	check(not gs.fulfill_order(order.id), "ohne Waren nicht erfüllbar")
	check(gs.orders.size() > 0 and gs.find_order(order.id) >= 0, "Auftrag bleibt bestehen")
	for id in order.items:
		gs.add_item(id, int(order.items[id]) + 1)
	var c: int = gs.coins
	var xp: int = gs.xp
	var lvl: int = gs.level
	check(gs.fulfill_order(order.id), "erfüllen")
	check(gs.coins == c + int(order.coins), "Belohnung Münzen")
	check(gs.level > lvl or gs.xp == xp + int(order.xp), "Belohnung XP")
	check(not gs.fulfill_order(order.id), "keine doppelte Belohnung")
	check(gs.coins == c + int(order.coins), "Münzen unverändert nach Doppelversuch")
	var cafe_order := {"id": 7654, "customer": "Mira", "items": {"filter_coffee": 1}, "coins": 55, "xp": 16, "cafe_order": true, "visitor_story": "Ein ruhiger Ort zum Erzählen."}
	gs.orders.append(cafe_order)
	check(not gs.skip_order(7654), "Besucherbestellung mit Geschichte lässt sich nicht wegklicken")
	gs.add_item("filter_coffee", 1)
	check(gs.fulfill_order(7654), "Café-Besuch bedienen")
	check(int(gs.stats.get("cafe_orders", 0)) == 1 and int(gs.stats.get("cafe_stories_shared", 0)) == 1, "Café-Gäste und Geschichten zählen")
	check(String(gs.diary.back().text).contains("Ein ruhiger Ort zum Erzählen."), "Gästegeschichte ist im Tagebuch")
	for id in order.items:
		check(gs.item_count(id) == 1, "genau die benötigte Menge abgezogen")
	check(gs.stats.get("orders", 0) == 2, "Statistik enthält Standard- und Café-Auftrag")
	# Nachfüllen
	gs.time_offset += 200.0
	gs._fill_orders()
	check(gs.orders.size() >= 3, "Aufträge füllen sich wieder auf")
	gs.time_offset += 30.0
	gs._fill_orders()
	check(gs.orders.size() == gs.MAX_ORDERS, "nach der Wartezeit kommt der vierte Kunde")


func test_delivery_stories() -> void:
	begin("Erzählende Lieferaufträge")
	level_to(8)
	check(gs.available_delivery_stories().has("lena_cafe"), "Geschichte wird ab ihrem Freischaltlevel angeboten")
	check(not gs.start_delivery_story("jonas_autumn"), "höherstufige Geschichte bleibt gesperrt")
	check(gs.start_delivery_story("lena_cafe"), "optionale Liefergeschichte startet")
	check(not gs.start_delivery_story("lena_cafe"), "keine parallele Geschichte startbar")
	check(gs.orders.size() == gs.MAX_ORDERS, "Story verdrängt bei vollem Buch eine optionale Standardbestellung")
	var story_to_skip := -1
	for pending_order in gs.orders:
		if pending_order.has("story_id"):
			story_to_skip = int(pending_order.id)
	check(story_to_skip > 0 and not gs.skip_order(story_to_skip), "Storyauftrag kann nicht versehentlich abgebrochen werden")
	check(gs.orders.size() == 4, "erster Storyauftrag kommt ins volle Auftragsbuch")
	var story_order: Dictionary = {}
	for order in gs.orders:
		if str(order.get("story_id", "")) == "lena_cafe":
			story_order = order
	check(not story_order.is_empty() and story_order.has("story_text"), "Storyauftrag enthält Abschnittserzählung")
	var encoded: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(encoded), "Storyfortschritt speichern und laden")
	check(gs.active_delivery_story == "lena_cafe" and gs.delivery_story_stage == 0, "aktive Reihe und Abschnitt bleiben erhalten")
	story_order = {}
	for order in gs.orders:
		if str(order.get("story_id", "")) == "lena_cafe":
			story_order = order
	for i in range(3):
		if story_order.is_empty():
			gs._fill_orders()
			for order in gs.orders:
				if str(order.get("story_id", "")) == "lena_cafe":
					story_order = order
		check(not story_order.is_empty(), "nächster Storyabschnitt wird angeboten")
		if story_order.is_empty():
			break
		for item in story_order.items:
			gs.add_item(str(item), int(story_order.items[item]))
		var story_order_id := int(story_order.id)
		var coins_before: int = gs.coins
		check(gs.fulfill_order(story_order_id), "Storyabschnitt %d erfüllen" % (i + 1))
		check(gs.coins > coins_before, "Abschnitt gibt Belohnung")
		story_order = {}
		if i < 2:
			gs._fill_orders()
			for order in gs.orders:
				if str(order.get("story_id", "")) == "lena_cafe":
					story_order = order
	check(gs.active_delivery_story.is_empty(), "abgeschlossene Reihe wird beendet")
	check(gs.diary.size() >= 5 and String(gs.diary.back().text).contains("abgeschlossen"), "Abschluss und Abschnitte stehen im Refugiums-Tagebuch")
	check(gd.RECIPES.size() == 24, "Café ergänzt vier neue Rezepte")


func test_cafe() -> void:
	begin("Veganes Gartencafé")
	check(gd.BUILDINGS.has("cafe") and int(gd.BUILDINGS["cafe"]["level"]) == 8, "Café ab Stufe 8 freigeschaltet")
	check(gd.CROPS.has("coffee") and bool(gd.CROPS["coffee"]["perennial"]), "Kaffee wächst als mehrjährige Pflanze")
	check(gd.RECIPES.has("roasted_coffee") and gd.RECIPES.has("filter_coffee") and gd.RECIPES.has("oat_latte"), "Kaffeekette mit Hafer-Latte")
	level_to(8)
	gs.coins = 10000
	var cafe_uid: int = gs.place_object("cafe", Vector2i(8, 11))
	check(cafe_uid > 0, "Gartencafé bauen")
	check(gs.quest_progress({"type": "building", "building": "cafe", "target": 1}) == 1, "Café-Ziel nimmt Baufortschritt auf")
	var cafe_achievement: Dictionary = {}
	for achievement in gd.ACHIEVEMENTS:
		if str(achievement["id"]) == "cafe_open":
			cafe_achievement = achievement
	check(not cafe_achievement.is_empty() and gs.achievement_unlocked(cafe_achievement), "Café-Erfolg erkennt das Gebäude")
	check(gs.available_delivery_stories().has("cafe_opening"), "Café-Geschichte wird mit Gebäude angeboten")
	check(gs.start_delivery_story("cafe_opening"), "Café-Geschichte starten")
	var cafe_story_order: Dictionary = {}
	for order in gs.orders:
		if str(order.get("story_id", "")) == "cafe_opening":
			cafe_story_order = order
	check(not cafe_story_order.is_empty(), "Café-Geschichte erzeugt Besuchsauftrag")
	for i in range(3):
		if cafe_story_order.is_empty():
			gs._fill_orders()
			for order in gs.orders:
				if str(order.get("story_id", "")) == "cafe_opening":
					cafe_story_order = order
		for item in cafe_story_order.get("items", {}):
			gs.add_item(str(item), int(cafe_story_order.items[item]))
		check(gs.fulfill_order(int(cafe_story_order.get("id", -1))), "Café-Storyabschnitt wird geliefert")
		cafe_story_order = {}
		gs._fill_orders()
		for order in gs.orders:
			if str(order.get("story_id", "")) == "cafe_opening":
				cafe_story_order = order
	check(int(gs.stats.get("cafe_orders", 0)) == 3, "Story-Gäste zählen als Café-Besuche")
	check(int(gs.stats.get("cafe_stories_completed", 0)) == 1, "abgeschlossene Café-Reihe zählt für Ziele")
	check(int(gs.stats.get("cafe_stories_shared", 0)) == 3, "Gästeerzählungen landen in der Langzeitstatistik")
	check(gs.diary.size() >= 4, "Café-Geschichten werden im Tagebuch festgehalten")
	var v4_save: Dictionary = gs.serialize()
	v4_save["version"] = 4
	check(int(ss.migrate(v4_save)["version"]) == 5, "ältere Spielstände werden auf Café-Schema migriert")


func test_achievements() -> void:
	begin("Erfolge")
	var order_achievement: Dictionary = {}
	for achievement in gd.ACHIEVEMENTS:
		if achievement["id"] == "orders_2":
			order_achievement = achievement
	check(not order_achievement.is_empty(), "Erfolg für zwei Bestellungen vorhanden")
	check(gs.achievement_progress(order_achievement) == 0 and not gs.achievement_unlocked(order_achievement), "Bestellerfolg beginnt bei null")
	gs.bump("orders")
	check(not gs.achievement_unlocked(order_achievement), "eine Bestellung reicht noch nicht")
	gs.bump("orders")
	check(gs.achievement_unlocked(order_achievement), "zwei Bestellungen schalten den Erfolg frei")
	var coins_before: int = gs.coins
	check(gs.claimable_achievements() == 1, "freigeschaltete Belohnung wird gezählt")
	check(gs.claim_achievement("orders_2"), "Belohnung ist abholbar")
	check(gs.coins == coins_before + int(order_achievement["coins"]), "Erfolg vergibt Münzen")
	check(not gs.claim_achievement("orders_2"), "Erfolgsbelohnung gibt es nur einmal")
	check(gs.coins == coins_before + int(order_achievement["coins"]), "kein doppelter Münzbonus")
	var animals_achievement: Dictionary = {}
	for achievement in gd.ACHIEVEMENTS:
		if achievement["id"] == "friendship_15":
			animals_achievement = achievement
	var animal := {"hearts": 14}
	gs.animals.append(animal)
	check(gs.achievement_progress(animals_achievement) == 14, "Freundschaft zählt den höchsten Tierwert")
	animal.hearts = 15
	check(gs.achievement_unlocked(animals_achievement), "15 Herzen schalten Freundschaftserfolg frei")
	var encoded: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(encoded), "Erfolgs-Status laden")
	check(gs.claimed_achievements.has("orders_2") and not gs.claim_achievement("orders_2"), "abgeholte Erfolge bleiben dauerhaft gespeichert")
	check(gs.claimed_achievements.size() == 1, "unbekannte Erfolgs-IDs werden nicht gespeichert")
	check(gs.SAVE_VERSION == 5, "Café-Fortschritt verwendet Save-Version 5")
	var cafe_orders_achievement: Dictionary = {}
	for achievement in gd.ACHIEVEMENTS:
		if str(achievement["id"]) == "cafe_orders_10":
			cafe_orders_achievement = achievement
	gs.bump("cafe_orders", 10)
	check(gs.achievement_unlocked(cafe_orders_achievement), "Café-Gäste schalten eigenen Erfolg frei")
	var cafe_open_achievement: Dictionary = {}
	for achievement in gd.ACHIEVEMENTS:
		if str(achievement["id"]) == "cafe_open":
			cafe_open_achievement = achievement
	gs.objects.append({"type": "cafe"})
	check(gs.achievement_unlocked(cafe_open_achievement), "Café-Erfolg zählt platziertes Gebäude")


func test_quests() -> void:
	begin("Quests")
	var q: Dictionary = gd.QUESTS[0]
	check(not gs.claim_quest(q.id), "unerledigt nicht abholbar")
	for i in range(5):
		gs.bump("planted")
	check(gs.quest_done(q), "Ziel erreicht")
	check(gs.claimable_quests() >= 1, "abholbar gezählt")
	var c: int = gs.coins
	check(gs.claim_quest(q.id), "Belohnung abholen")
	check(gs.coins == c + int(q.coins), "Münzen")
	check(not gs.claim_quest(q.id), "nur einmal abholbar")
	check(gs.coins == c + int(q.coins), "keine doppelte Belohnung")


func test_animals() -> void:
	begin("Tierrefugium")
	check(gs.adopt_animal("rabbit") == -1, "ohne Gehege nicht möglich")
	level_to(3)
	gs.coins = 5000
	var pad: int = gs.place_object("paddock", Vector2i(8, 11))
	check(pad > 0, "Gehege bauen")
	check(gs.adopt_animal("cow") == -1, "Kuh erst ab Stufe 8")
	var rab: int = gs.adopt_animal("rabbit")
	check(rab > 0, "Kaninchen retten")
	var a: Dictionary = gs.get_animal(rab)
	check(a.name != "" and gs.wellbeing(a) > 0.0, "Name und Wohlbefinden")
	check(not gs.feed_animal(rab) or gs.item_count("carrot") >= 0, "Füttern ohne Futter scheitert")
	gs.add_item("carrot", 5)
	gs.time_offset += 4.0 * 3600.0
	var h0: float = gs.animal_stat(a, "hunger")
	check(h0 < 70.0, "Hunger sinkt mit der Zeit")
	check(gs.feed_animal(rab), "füttern")
	check(gs.item_count("carrot") == 4, "Futter verbraucht")
	check(gs.animal_stat(a, "hunger") > h0, "Sattheit steigt")
	check(gs.pet_animal(rab), "streicheln")
	check(gs.diary.size() >= 2 and String(gs.diary.back().text).contains(a.name), "Rettung und gemeinsamer Moment landen im Tagebuch")
	check(not gs.pet_animal(rab), "Streicheln hat Pause")
	gs.time_offset += gs.PET_COOLDOWN + 1.0
	check(gs.pet_animal(rab), "nach Pause wieder möglich")
	check(int(a.hearts) >= 4, "Herzen sammeln sich")
	check(gs.friendship_level(a) == 0, "Freundschaftsmeilenstein noch nicht voreilig erreicht")
	gs.record_animal_moment(a, "ein besonderer Testmoment", 1)
	check(gs.friendship_level(a) == 1, "Freundschaft schaltet erste Profilzeile frei")
	check(String(gs.diary.back().text).contains("vertraut dir jetzt mehr"), "Meilenstein wird im Tagebuch festgehalten")
	gs.time_offset += 48.0 * 3600.0
	check(gs.animal_stat(a, "hunger") >= 0.0 and gs.animal_stat(a, "happy") >= 0.0, "Werte nie negativ")
	check(gs.get_animal(rab).name == a.name, "Tier bleibt trotz Vernachlässigung erhalten")
	# Kapazität
	gs.adopt_animal("rabbit")
	gs.adopt_animal("chicken")
	check(gs.animals_in(pad) == 3, "Gehege voll nach 3 Tieren")
	check(gs.adopt_animal("chicken") == -1, "kein Platz mehr")
	check(not gs.sell_object(pad), "Gehege mit Tieren nicht verkaufbar")
	a.hearts = 100
	check(gs.cosmetics_of(a).size() == 3, "alle Belohnungen bei 100 Herzen")
	for an in gs.animals:
		check(not gd.RECIPES.has("egg") and not gd.items.has("milk") and not gd.items.has("egg"), "Tiere liefern keine Waren")


func test_animal_extensions() -> void:
	begin("Tierprofile, Beschäftigung, Accessoires und Rettung")
	var used_names: Array = []
	for i in range(7):
		var next_name: String = gs._next_animal_name(["A", "B"], used_names, i + 1)
		check(not used_names.has(next_name), "freie Namen werden nicht wiederholt")
		used_names.append(next_name)
	check(gs._next_animal_name(["A", "B"], ["A", "B"], 3) == "A 2", "Namen bleiben auch bei mehr als acht Tieren eindeutig")
	for species in gd.ANIMALS:
		var animal_def: Dictionary = gd.ANIMALS[species]
		check(animal_def["names"].size() == 8, "%s hat acht Rufnamen" % species)
		var unique_names := {}
		for animal_name in animal_def["names"]:
			check(not unique_names.has(animal_name), "%s Rufnamen sind verschieden" % species)
			unique_names[animal_name] = true
		check(animal_def["stories"].size() == 8, "%s hat acht persönliche Geschichten" % species)
		var unique_stories := {}
		for story_text in animal_def["stories"]:
			check(not String(story_text).strip_edges().is_empty(), "%s Geschichte ist ausgefüllt" % species)
			check(not unique_stories.has(story_text), "%s Geschichten unterscheiden sich" % species)
			unique_stories[story_text] = true
	level_to(3)
	gs.coins = 5000
	var pad: int = gs.place_object("paddock", Vector2i(8, 11))
	check(pad > 0, "Gehege für Rettungsfall")
	check(not gs.rescue_case.is_empty(), "Rettungsangebot erscheint bei freiem Gehege")
	var offered_story: int = int(gs.rescue_case["story"])
	var offer_save: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(offer_save), "aktives Rettungsangebot laden")
	check(int(gs.rescue_case["story"]) == offered_story, "Rettungsfall samt Geschichte bleibt gespeichert")
	var species: String = gs.rescue_case["species"]
	var coins_before: int = gs.coins
	var rescued: int = gs.adopt_animal(species, true)
	check(rescued > 0, "Rettung aufnehmen")
	check(not String(gs.get_animal(rescued).name).is_empty(), "gerettetes Tier erhält individuellen Rufnamen")
	check(int(gs.get_animal(rescued).story) == offered_story, "Rettung behält ihre angebotene Geschichte")
	check(not String(gd.ANIMALS[species]["stories"][offered_story]).is_empty(), "gerettetes Tier hat eine erzählte Vorgeschichte")
	check(gs.coins == coins_before, "Rettungsfall kostet keine Aufnahmegebühr")
	check(gs.rescue_case.is_empty(), "angenommener Fall wird entfernt")
	var animal: Dictionary = gs.get_animal(rescued)
	check(animal.traits.size() == 2, "Tier bekommt zwei Charakterzüge")
	for trait_id in animal.traits:
		check(gd.ANIMAL_TRAITS.has(trait_id) and gd.ANIMALS[species]["traits"].has(trait_id), "Charakterzug passt zur Tierart")
	check(gs.animals_in_paddock(pad).size() == 1, "Gehegeübersicht liefert Bewohner")
	var old_happy: float = gs.animal_stat(animal, "happy")
	check(gs.animal_activity(rescued), "optionale Beschäftigung funktioniert")
	check(gs.stats.get("activities", 0) == 1, "Beschäftigung wird gezählt")
	check(gs.animal_stat(animal, "happy") > old_happy, "Beschäftigung hebt Wohlbefinden")
	check(not gs.animal_activity(rescued), "Beschäftigung hat eine Abklingzeit")
	animal.hearts = 100
	check(gs.set_animal_cosmetic(rescued, "flower", true), "freigeschaltetes Accessoire anlegen")
	check(gs.equipped_cosmetics_of(animal).has("flower"), "Accessoire wird getragen")
	check(not gs.set_animal_cosmetic(rescued, "unknown", true), "unbekanntes Accessoire ablehnen")
	var encoded: Dictionary = gs.serialize()
	check(int(encoded.version) == 5 and encoded.animals[0].has("traits") and encoded.animals[0].has("accessories"), "neue Profildaten werden gespeichert")
	gs.new_game()
	check(gs.deserialize(encoded), "erweiterte Tierdaten laden")
	var restored: Dictionary = gs.get_animal(rescued)
	check(restored.traits.size() == 2 and restored.accessories.has("flower"), "Profil und Accessoire bleiben beim Speichern/Laden erhalten")
	check(gs.animals_in_paddock(pad).size() == 1, "Gehegezuordnung bleibt erhalten")
	check(gs.set_animal_cosmetic(rescued, "flower", false), "Accessoire wieder ablegen")
	check(not gs.equipped_cosmetics_of(restored).has("flower"), "abgelegtes Accessoire wird nicht gerendert")
	gs.time_offset += gs.RESCUE_COOLDOWN
	gs._refresh_rescue_case()
	check(not gs.rescue_case.is_empty(), "neues Rettungsangebot nach der freiwilligen Pause")


func test_land_and_objects() -> void:
	begin("Land und Objekte")
	var cell := Vector2i(8, 11)
	check(gs.till(cell), "Feld anlegen")
	check(not gs.till(cell), "nicht doppelt anlegen")
	check(not gs.till(Vector2i(0, 0)), "außerhalb des Landes nicht möglich")
	level_to(3)
	check(not gs.expand_land(), "Erweiterung braucht Münzen")
	gs.coins = 5000
	var area: int = gs.land.get_area()
	check(gs.expand_land(), "Land erweitern")
	check(gs.land.get_area() > area, "mehr Fläche")
	check(gs.till(Vector2i(7, 10)), "neues Land nutzbar")
	level_to(2)
	var id: int = gs.place_object("flowers", Vector2i(9, 11))
	check(id > 0, "Dekoration platzieren")
	check(gs.move_object(id, Vector2i(10, 12)), "verschieben")
	check(not gs.move_object(id, Vector2i(11, 14)), "nicht auf Feld verschieben")
	check(gs.object_at(Vector2i(10, 12)).uid == id, "Belegung folgt dem Objekt")
	check(gs.object_at(Vector2i(9, 11)).is_empty(), "alte Position frei")
	var c: int = gs.coins
	check(gs.sell_object(id), "Dekoration verkaufen")
	check(gs.coins == c + 12, "halber Preis")


func _snapshot() -> Dictionary:
	return {"coins": gs.coins, "level": gs.level, "xp": gs.xp, "inv": gs.inventory.duplicate(),
		"fields": gs.fields.size(), "objects": gs.objects.size(), "animals": gs.animals.size(),
		"orders": gs.orders.size(), "stats": gs.stats.duplicate(), "land": gs.land}


func test_save_roundtrip() -> void:
	begin("Speichern und Laden")
	level_to(4)
	gs.coins = 4000
	var cell: Vector2i = gs.fields.keys()[0]
	gs.plant(cell, "carrot")
	var bak: int = gs.place_object("bakery", Vector2i(8, 11))
	gs.add_item("wheat", 6)
	gs.start_recipe(bak, "bread")
	var pad: int = gs.place_object("paddock", Vector2i(12, 11))
	gs.adopt_animal("rabbit")
	gs.place_object("bench", Vector2i(8, 16))
	gs.bump("planted", 3)
	gs.claimed_quests.append("q_plant5")
	gs.claimed_achievements.append("orders_2")
	gs.settings["sound"] = false
	var before := _snapshot()
	check(ss.save_game(), "speichern")
	check(FileAccess.file_exists("user://test_save.json"), "Datei existiert")
	gs.new_game()
	check(gs.coins == gd.START_COINS, "Zustand wurde zurückgesetzt")
	check(ss.load_game(), "laden")
	var after := _snapshot()
	check(before == after, "Zustand identisch: %s vs %s" % [before, after])
	check(gs.fields[cell].crop == "carrot", "Pflanze erhalten")
	check(gs.get_object(bak).queue.size() == 1, "Produktionsschlange erhalten")
	check(gs.animals.size() == 1 and int(gs.animals[0].paddock) == pad, "Tier im Gehege erhalten")
	check(gs.claimed_quests.has("q_plant5"), "Quest-Status erhalten")
	check(gs.claimed_achievements.has("orders_2"), "Erfolgs-Status erhalten")
	check(gs.settings["sound"] == false, "Einstellungen erhalten")
	check(not gs.object_at(Vector2i(8, 11)).is_empty(), "Belegung neu aufgebaut")
	check(not gs.can_place("tree", Vector2i(8, 11)), "belegte Fläche bleibt belegt")
	var uid: int = gs.place_object("tree", Vector2i(14, 16))
	check(uid > 0 and gs.get_object(uid).uid != bak, "neue UIDs kollidieren nicht")
	var d: Dictionary = gs.serialize()
	check(int(d.version) == gs.SAVE_VERSION, "Version im Spielstand")
	check(gs.SAVE_VERSION == 5, "Café-Fortschritt verwendet Save-Version 5")


func test_offline_progress() -> void:
	begin("Offline-Fortschritt")
	level_to(2)
	gs.coins = 1000
	var cell: Vector2i = gs.fields.keys()[0]
	gs.plant(cell, "carrot")
	var bak: int = gs.place_object("bakery", Vector2i(8, 11))
	gs.add_item("wheat", 6)
	gs.start_recipe(bak, "bread")
	gs.start_recipe(bak, "bread")
	check(ss.save_game(), "speichern")
	gs.time_offset += 3.0 * 3600.0   # App ist 3 Stunden geschlossen
	check(ss.load_game(), "laden nach 3 Stunden")
	check(gs.away_seconds >= 3.0 * 3600.0 - 5.0, "Abwesenheit erkannt")
	check(gs.is_ready(cell), "Möhre ist inzwischen reif")
	check(gs.ready_count(gs.get_object(bak)) == 2, "beide Brote fertig")
	var rep: Dictionary = gs.offline_report()
	check(int(rep.fields) >= 1 and int(rep.products) == 2, "Bericht: %s" % rep)
	check(gs.collect_ready(bak).size() == 2, "Abholen nach Offline-Zeit")
	check(gs.harvest(cell), "Ernten nach Offline-Zeit")
	check(gs.orders.size() >= 3, "Aufträge nach Offline-Zeit vorhanden")
	# Uhr geht zurück (Geräteuhr verstellt): kein Absturz, kein negativer Wert
	gs.time_offset -= 10.0 * 3600.0
	check(gs.away_seconds >= 0.0, "away nie negativ")
	check(gs.crop_progress(cell) >= 0.0 and gs.crop_progress(cell) <= 1.0, "Fortschritt bleibt in 0..1")


func test_corrupt_and_migration() -> void:
	begin("Beschädigter Spielstand und Migration")
	gs.coins = 777
	check(ss.save_game(), "erster Speicherstand")
	gs.coins = 888
	check(ss.save_game(), "zweiter Speicherstand (erzeugt Backup)")
	check(FileAccess.file_exists("user://test_save.json.bak"), "Backup vorhanden")
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("{ kaputt ::: ")
	f.close()
	gs.new_game()
	check(ss.load_game(), "Fallback auf Backup")
	check(gs.coins == 777, "Backup-Stand geladen (%d)" % gs.coins)
	# Version 0 ohne neue Felder
	var old := {"coins": 55, "level": 2, "xp": 3, "inventory": {"wheat": 4, "ghost": 9, "carrot": -2}, "fields": [{"x": 8, "y": 11, "crop": "unknown", "t": 0}]}
	var f2 := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(old))
	f2.close()
	DirAccess.remove_absolute("user://test_save.json.bak")
	check(ss.load_game(), "Version 0 migrieren")
	check(gs.coins == 55 and gs.level == 2, "Werte übernommen")
	check(gs.item_count("wheat") == 4, "gültiges Item übernommen")
	check(not gs.inventory.has("ghost") and not gs.inventory.has("carrot"), "ungültige/negative Items verworfen")
	check(gs.fields[Vector2i(8, 11)].crop == "", "unbekannte Pflanze verworfen")
	check(gs.tutorial_step == 99, "Tutorial bei Altstand übersprungen")
	var v1_migrated: Dictionary = ss.migrate({"version": 1, "animals": []})
	check(int(v1_migrated.version) == 5, "Version 1 migriert schrittweise auf Version 5")
	check(v1_migrated.stats.get("cafe_orders", -1) == 0, "Café-Fortschritt alter Spielstände startet bei null")
	var v2_migrated: Dictionary = ss.migrate({"version": 2, "animals": []})
	check(int(v2_migrated.version) == 5 and v2_migrated.diary.is_empty() and v2_migrated.claimed_achievements.is_empty(), "Version 2 erhält Story-, Erfolgs- und Café-Migration")
	var v3_migrated: Dictionary = ss.migrate({"version": 3, "animals": []})
	check(int(v3_migrated.version) == 5 and v3_migrated.claimed_achievements.is_empty(), "Version 3 erhält leere Erfolgs- und Café-Historie")
	var legacy_animal := {"uid": 10, "species": "rabbit", "name": "Alt-Tier", "hunger": 60, "happy": 55, "last": gs.now(), "paddock": 1}
	var migrated: Dictionary = ss.migrate({"version": 1, "animals": [legacy_animal]})
	check(legacy_animal.has("traits") and legacy_animal.has("accessories") and legacy_animal.has("activity_at"), "Tierfelder aus altem Spielstand ergänzt")
	var legacy_state: Dictionary = {"version": 2, "animals": [legacy_animal], "objects": [{"uid": 1, "type": "paddock", "x": 8, "y": 11}], "land": [8, 11, 8, 8]}
	check(gs.deserialize(legacy_state), "älteres Tierprofil laden")
	check(gs.get_animal(10).traits.size() == 2 and gs.get_animal(10).accessories.is_empty(), "altes Profil erhält gültige Standard-Charakterzüge")
	# Komplett unbrauchbar
	var f3 := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f3.store_string("müll")
	f3.close()
	check(not ss.load_game(), "unbrauchbare Datei wird abgelehnt")
	ss.delete_save()


func test_economy() -> void:
	begin("Wirtschaft und Balance")
	for id in gd.RECIPES:
		var r: Dictionary = gd.RECIPES[id]
		var input_value := 0
		for k in r.inputs:
			input_value += int(gd.items[k].sell) * int(r.inputs[k])
		check(int(r.sell) > input_value, "%s: Verkaufswert %d > Zutaten %d" % [id, int(r.sell), input_value])
		check(gd.BUILDINGS.has(r.building), "%s: Gebäude existiert" % id)
		for k in r.inputs:
			check(gd.items.has(k), "%s: Zutat %s existiert" % [id, k])
	for id in gd.CROPS:
		var c: Dictionary = gd.CROPS[id]
		check(int(c["yield"]) * int(c.sell) > int(c.seed), "%s: Ernte lohnt sich" % id)
	check(gd.CROPS.size() == 19, "neunzehn Pflanzen einschließlich Kaffeepflanze")
	check(gd.RECIPES.size() >= 8, "mindestens acht Rezepte")
	# Erste Minuten: Spieler erreicht Stufe 2 nach wenigen Ernten
	gs.new_game()
	var harvests := 0
	var guard := 0
	while gs.level < 2 and guard < 200:
		guard += 1
		for cell in gs.fields.keys():
			if gs.fields[cell].crop == "":
				gs.plant(cell, "wheat")
		gs.time_offset += 31.0
		for cell in gs.fields.keys():
			if gs.harvest(cell):
				harvests += 1
	check(gs.level == 2 and harvests <= 25, "Stufe 2 nach %d Ernten" % harvests)
	print("   Stufe 2 nach %d Ernten (~%d s)" % [harvests, int(gs.time_offset)])
	# Alle Level-Freischaltungen sind erreichbar
	var seen := {}
	for l in range(1, gd.MAX_LEVEL + 1):
		for u in gd.unlocks_at(l):
			seen[u] = true
	var total: int = gd.CROPS.size() + gd.RECIPES.size() + gd.ANIMALS.size()
	check(seen.size() >= total, "jede Pflanze, jedes Rezept und jedes Tier hat ein Freischaltlevel")


func test_new_crops() -> void:
	begin("Neue Pflanzen")
	gs.coins = 100000
	var cell: Vector2i = gs.fields.keys()[0]
	var new_crops := {
		"coffee": 8, "pumpkin": 9, "beet": 10, "lettuce": 11, "cucumber": 12,
		"pea": 13, "blueberry": 14, "rice": 16, "quinoa": 18,
	}
	for crop in new_crops:
		var level: int = int(new_crops[crop])
		level_to(level)
		var definition: Dictionary = gd.CROPS[crop]
		check(gs.plant(cell, crop), "%s auf Freischaltstufe pflanzbar" % crop)
		gs.time_offset += float(definition["grow"])
		check(gs.harvest(cell), "%s nach Wachstumszeit erntbar" % crop)
		check(gs.item_count(crop) == int(definition["yield"]), "%s liefert Inventar-Ertrag" % crop)
		if crop == "coffee" or crop == "blueberry":
			check(gs.fields[cell].crop == crop, "%s wächst nach Ernte weiter" % crop)
			gs.time_offset += float(definition["grow"])
			check(gs.harvest(cell), "%s kann erneut geerntet werden" % crop)
		gs.fields[cell] = {"crop": "", "t": 0.0}
	check(gd.RECIPES.size() == 24, "Café ergänzt vier neue Rezepte")
	for recipe in ["pumpkin_soup", "beet_spread", "garden_salad", "blueberry_smoothie", "rice_milk", "quinoa_bowl"]:
		check(gd.items.has(recipe), "%s ist als Produkt im Inventar registriert" % recipe)
	check(gd.unlocks_at(18).has("Quinoa"), "Quinoa wird auf Stufe 18 freigeschaltet")
	check(gd.items.has("pumpkin") and gd.items.has("blueberry"), "neue Ernten als handelbare Items registriert")
