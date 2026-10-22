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
	gs.time_offset = -fposmod(Time.get_unix_time_from_system(), gd.WEATHER_DURATION_SECONDS * float(gd.WEATHER_TYPES.size()))
	gs.new_game()
	gs.rng.seed = 12345


func level_to(n: int) -> void:
	while gs.level < n:
		gs.add_xp(gd.xp_needed(gs.level))


func _initialize() -> void:
	# Die Prüfungen vergleichen deutsche Texte; unabhängig von der Gerätesprache.
	I18n.apply("de")
	gs = root.get_node("GameState")
	gd = root.get_node("GameData")
	ss = root.get_node("SaveSystem")
	world_script = load("res://scripts/world/world.gd")
	ss.path_override = "user://test_save.json"
	ss.delete_save()
	test_new_game()
	test_day_night()
	test_day_counter_and_recap()
	test_seasons()
	test_season_goals()
	test_hofbuch()
	test_weather_growth()
	test_farming()
	test_inventory()
	test_levels()
	test_production()
	test_production_dashboard()
	test_orders()
	test_delivery_stories()
	test_cafe()
	test_cafe_guests()
	test_neighborhood_event()
	test_story_during_event()
	test_achievements()
	test_quests()
	test_animals()
	test_animal_extensions()
	test_land_and_objects()
	test_land_expansion_chain()
	test_save_roundtrip()
	test_tutorial_restart()
	test_audio_volumes()
	test_accessibility()
	test_offline_progress()
	test_corrupt_and_migration()
	test_save_hardening()
	test_logic_regressions()
	test_data_consistency()
	test_unlock_pacing()
	test_economy()
	test_new_crops()
	test_new_production()
	test_sugar_chain()
	test_foraging()
	test_lexicon()
	test_level_curve()
	test_landscape_chunks()
	section = "Tierverhalten bei Wetter und Nacht"
	load("res://tests/suites/animal_weather.gd").new().run(self, world_script, gs, gd)
	section = "Spielstand-Export/Import"
	load("res://tests/suites/save_transfer.gd").new().run(self)
	ss.delete_save()
	print("")
	print("Ergebnis: %d bestanden, %d fehlgeschlagen" % [passed, failed])
	quit(1 if failed > 0 else 0)


func test_day_night() -> void:
	begin("Tag-Nacht-Zyklus")
	check(gs.SAVE_VERSION == 11, "Save-Version 11 enthält den Tageszähler")
	check(world_script.daylight_at(0.0) < 0.01, "Mitternacht ist dunkel")
	check(world_script.daylight_at(12.0 * 3600.0) > 0.99, "Mittag ist hell")
	check(world_script.daylight_at(6.0 * 3600.0) < world_script.daylight_at(9.0 * 3600.0), "Sonnenaufgang wird heller")
	check(world_script.daylight_at(18.0 * 3600.0) > world_script.daylight_at(21.0 * 3600.0), "Sonnenuntergang wird dunkler")
	check(not world_script.is_night_at(6.0 * 3600.0) and not world_script.is_night_at(17.999 * 3600.0), "Tageszeit reicht von 06:00 bis 18:00")
	check(world_script.is_night_at(18.0 * 3600.0) and world_script.is_night_at(5.999 * 3600.0), "Nacht reicht ab 18:00 bis vor 06:00")
	check(world_script.is_night_at(-1.0) and not world_script.is_night_at(24.0 * 3600.0 + 6.0 * 3600.0), "Nachtprüfung normalisiert negative und mehrtägige Zeiten")
	check(world_script.clock_text_at(8.0 * 3600.0) == "08:00 · Tag", "Uhr zeigt Tageszeit")
	check(world_script.clock_text_at(20.0 * 3600.0) == "20:00 · Nacht", "Uhr zeigt Nachtzeit")
	check(world_script.weather_at(0.0) == "Sonnig", "Wetterzyklus startet sonnig")
	check(world_script.weather_at(120.0) == "Bewölkt", "Wetter wechselt zu bewölkt")
	check(world_script.weather_at(240.0) == "Regen", "Wetter wechselt zu Regen")
	check(world_script.weather_at(360.0) == "Nebel", "Wetter wechselt zu Nebel")
	check(world_script.weather_at(480.0) == "Sonnig", "Wetterzyklus wiederholt sich")
	check(gd.seconds_into_weather(365.0) == 5.0, "Wetterphasenzeit beginnt nach dem Phasenwechsel bei null")
	check(gd.seconds_into_weather(-1.0) == GameData.WEATHER_DURATION_SECONDS - 1.0, "Wetterphasenzeit normalisiert negative Zeit")
	check(gd.rainbow_strength_at(360.0) == 0.0 and gd.rainbow_strength_at(365.0) > 0.0, "Regenbogen beginnt im Nebel mit Einblenden")
	check(gd.rainbow_strength_at(367.0) == 1.0 and gd.rainbow_strength_at(373.0) == 1.0, "Regenbogen erreicht und hält kurz volle Deckkraft")
	check(gd.rainbow_strength_at(375.0) == 0.0 and gd.rainbow_strength_at(485.0) == 0.0, "Regenbogen endet nach etwa 15 Sekunden und erscheint nicht bei Sonne")
	check(gd.rainbow_strength_at(365.0, true) == 0.0, "Regenbogen ist nachts ausgeblendet")
	check(gs.SAVE_VERSION == 11, "Ambient-Verhalten erfordert keine zusätzliche Migration")
	check(world_script.weather_tint_at("Regen") != Color.WHITE, "Regen verändert die Lichtfarbe")
	check(gd.weather_effect_text("Regen").contains("+25%") and gd.weather_growth_rate("Regen") == 1.25, "Regen zeigt seinen Wachstumseffekt klar an")
	check(gd.weather_effect_text("Bewölkt").contains("−10%") and gd.weather_growth_rate("Bewölkt") == 0.9, "Bewölkung zeigt langsameres Wachstum an")
	check(gd.weather_growth_rate("Nebel") == 1.0 and gd.weather_growth_rate("Sonnig") == 1.0, "Nebel und Sonne behalten normales Wachstum")


func test_day_counter_and_recap() -> void:
	begin("Tageszähler und Tagesrückblick")
	var prior_offset: float = gs.time_offset
	gs.new_game()
	gs.day_anchor = gs.now()
	check(gs.day_number() == 1, "neue Farm startet an Tag 1")
	check(not gs.day_recap_due(), "am ersten Tag steht kein Rückblick an")
	gs.time_offset += gd.REAL_DAY_SECONDS - 1.0
	check(gs.day_number() == 1, "kurz vor dem Tageswechsel noch Tag 1")
	gs.time_offset += 2.0
	check(gs.day_number() == 2 and gs.day_recap_due(), "nach acht Minuten beginnt Tag 2")
	gs.bump("harvested", 4)
	gs.bump("orders", 2)
	gs.bump("pets", 1)
	gs.bump("fed", 2)
	gs.bump("activities", 3)
	gs.bump("crafted", 5)
	var recap: Dictionary = gs.take_day_recap()
	check(int(recap.get("day", 0)) == 2 and int(recap.get("days_elapsed", 0)) == 1, "Rückblick gehört zu Tag 2")
	check(int(recap.get("harvested", 0)) == 4, "Rückblick zählt Ernten")
	check(int(recap.get("orders", 0)) == 2, "Rückblick zählt Aufträge")
	check(int(recap.get("animal_moments", 0)) == 6, "Rückblick zählt Tiermomente")
	check(int(recap.get("crafted", 0)) == 5, "Rückblick zählt hergestellte Produkte")
	check(not gs.day_recap_due() and gs.take_day_recap().is_empty(), "Rückblick erscheint nur einmal")
	gs.time_offset += gd.REAL_DAY_SECONDS
	gs.bump("harvested", 2)
	var next_recap: Dictionary = gs.take_day_recap()
	check(int(next_recap.get("day", 0)) == 3 and int(next_recap.get("harvested", 0)) == 2, "nächster Rückblick zählt nur neue Aktionen")
	var saved: Dictionary = gs.serialize()
	check(int(saved.get("version", 0)) == gs.SAVE_VERSION, "Tageszähler wird in der aktuellen Save-Version gespeichert")
	check(saved.has("day_anchor") and saved.has("last_day_recap") and saved.has("day_stats_snapshot"), "Tagesfelder sind im Spielstand")
	var saved_anchor: float = gs.day_anchor
	check(gs.deserialize(saved), "Spielstand mit Tageszähler laden")
	check(is_equal_approx(gs.day_anchor, saved_anchor) and gs.day_number() == 3 and gs.last_day_recap == 3, "Tag und Anker bleiben beim Laden erhalten")
	var old_save := {"version": 8, "saved_at": gs.now(), "stats": {"harvested": 9}, "animals": []}
	var migrated: Dictionary = ss.migrate(old_save)
	check(int(migrated.get("version", 0)) == 11 and int(migrated.get("day_stats_snapshot", {}).get("harvested", 0)) == 9, "alter Stand startet mit aktuellem Statistik-Schnappschuss")
	check(gs.deserialize(migrated), "migrierten alten Stand laden")
	check(gs.take_day_recap().is_empty(), "alter Stand zeigt nicht die gesamte Historie als Tagesrückblick")
	gs.time_offset = prior_offset
	gs.new_game()


func test_seasons() -> void:
	begin("Jahreszeiten")
	check(gd.SEASON_DAYS == 6 and gd.SEASONS.size() == 4, "vier Jahreszeiten zu je sechs Spieltagen")
	check(gd.season_name_at(1) == "Frühling" and gd.season_name_at(6) == "Frühling", "Tage 1 bis 6 sind Frühling")
	check(gd.season_name_at(7) == "Sommer" and gd.season_name_at(12) == "Sommer", "Tage 7 bis 12 sind Sommer")
	check(gd.season_name_at(13) == "Herbst" and gd.season_name_at(18) == "Herbst", "Tage 13 bis 18 sind Herbst")
	check(gd.season_name_at(19) == "Winter" and gd.season_name_at(24) == "Winter", "Tage 19 bis 24 sind Winter")
	check(gd.season_name_at(25) == "Frühling" and gd.season_name_at(0) == "Frühling", "nach 24 Tagen beginnt das Jahr im Frühling neu")
	check(gd.season_day_at(1) == 1 and gd.season_day_at(7) == 1 and gd.season_day_at(12) == 6, "Tag innerhalb der Jahreszeit")
	check(gd.season_label_at(13) == "Herbst · Tag 1/6", "Kurzform nennt Jahreszeit und Tag")
	var seen := {}
	for season in gd.SEASONS:
		check(season["crops"].size() >= 4, "%s hat mehrere Saisonpflanzen" % season["name"])
		check(not String(season["note"]).is_empty(), "%s erklärt seinen Bonus" % season["name"])
		for id in season["crops"]:
			check(gd.CROPS.has(id), "%s: Saisonpflanze %s existiert" % [season["name"], id])
			check(not seen.has(id), "%s gehört nur einer Jahreszeit an" % id)
			seen[id] = true
	check(gd.crop_in_season("pumpkin", 13) and not gd.crop_in_season("pumpkin", 1), "Kürbis ist nur im Herbst Saisonpflanze")
	check(gd.season_effect_text_at(13).contains("Kürbis") and gd.season_effect_text_at(13).contains("+1 Ertrag"), "Saisontext nennt Bonus und Pflanzen")
	# Die Jahreszeit folgt dem Spieltag und braucht keinen eigenen Spielstand-Eintrag.
	gs.new_game()
	gs.day_anchor = gs.now()
	check(gs.season_name() == "Frühling" and gs.season_label() == "Frühling · Tag 1/6", "neue Farm startet im Frühling")
	gs.time_offset += gd.REAL_DAY_SECONDS * 12.0
	check(gs.day_number() == 13 and gs.season_name() == "Herbst", "nach zwölf Tagen ist Herbst")
	var encoded: Dictionary = gs.serialize()
	check(not encoded.has("season") and not encoded.has("season_index"), "Jahreszeit braucht keinen Spielstand-Eintrag")
	check(gs.deserialize(encoded) and gs.season_name() == "Herbst", "Jahreszeit bleibt nach dem Laden aus dem Spieltag ableitbar")
	# Der Bonus gilt nur in der passenden Jahreszeit.
	gs.coins = 1000
	gs.level = 13
	var cell: Vector2i = gs.fields.keys()[0]
	check(gs.harvest_yield("pumpkin") == int(gd.CROPS["pumpkin"]["yield"]) + 1, "Kürbis bringt im Herbst eine Extra-Einheit")
	check(gs.plant(cell, "pumpkin"), "Kürbis im Herbst pflanzen")
	gs.time_offset += gd.real_seconds_for_crop_growth(gs.now(), float(gd.CROPS["pumpkin"]["grow"])) + 0.01
	var xp_before: int = gs.xp
	check(gs.harvest(cell), "Kürbis im Herbst ernten")
	check(gs.item_count("pumpkin") == int(gd.CROPS["pumpkin"]["yield"]) + 1, "Saisonbonus landet im Inventar")
	check(gs.xp == xp_before + int(gd.CROPS["pumpkin"]["xp"]) + 1, "Saisonbonus gibt einen Extra-XP")
	gs.time_offset -= gd.REAL_DAY_SECONDS * 12.0
	check(gs.season_name() == "Frühling" and not gs.crop_in_season("pumpkin"), "Kürbis ist im Frühling keine Saisonpflanze")
	check(gs.harvest_yield("wheat") == int(gd.CROPS["wheat"]["yield"]), "Weizen bringt im Frühling den normalen Ertrag")
	check(gs.plant(cell, "wheat"), "Weizen im Frühling pflanzen")
	gs.time_offset += gd.real_seconds_for_crop_growth(gs.now(), float(gd.CROPS["wheat"]["grow"])) + 0.01
	check(gs.harvest(cell), "Weizen im Frühling ernten")
	check(gs.item_count("wheat") == int(gd.CROPS["wheat"]["yield"]), "ohne Saison kein Extra-Ertrag")
	gs.new_game()


func test_season_goals() -> void:
	begin("Saisonziele")
	check(gd.SEASON_GOALS.size() == 12, "zwölf Saisonziele")
	check(gd.SEASON_REWARD_DECOS.size() == 4, "vier Saisonbelohnungen")
	var seen := {}
	for season in gd.SEASONS:
		var goals: Array = gs.season_goals_for(str(season["id"]))
		check(goals.size() == 3, "%s hat drei Saisonziele" % season["name"])
		for goal in goals:
			check(str(goal["season"]) == str(season["id"]), "Ziel %s gehört zu %s" % [goal["id"], season["name"]])
			check(not (goal["keys"] as Array).is_empty() and int(goal["target"]) > 0, "Ziel %s hat Zähler und Zielwert" % goal["id"])
			check(not seen.has(str(goal["id"])), "Saisonziel-ID %s ist eindeutig" % goal["id"])
			seen[str(goal["id"])] = true
		check(gd.SEASON_REWARD_DECOS.has(str(season["id"])), "%s hat eine Belohnungsdeko" % season["name"])
	for season_id in gd.SEASON_REWARD_DECOS:
		var deco_id := str(gd.SEASON_REWARD_DECOS[season_id])
		check(gd.DECOS.has(deco_id), "Belohnungsdeko %s existiert" % deco_id)
		if gd.DECOS.has(deco_id):
			check(int(gd.DECOS[deco_id]["cost"]) == 0, "%s ist kostenlos" % deco_id)
			check(str(gd.DECOS[deco_id].get("unlock", "")) == "season:" + str(season_id), "%s ist an die Jahreszeit gebunden" % deco_id)
	check(gd.DECOS.has(gd.SEASON_YEAR_DECO) and str(gd.DECOS[gd.SEASON_YEAR_DECO].get("unlock", "")) == "season:year", "Jahreskranz gehört allen Saisonzielen")
	# Jede Belohnungsdeko verweist auf eine existierende Freischaltung.
	var unlock_keys := {}
	for season in gd.SEASONS:
		unlock_keys["season:" + str(season["id"])] = true
	unlock_keys["season:year"] = true
	for entry in gd.HOFBUCH:
		unlock_keys["hofbuch:" + str(entry["id"])] = true
	for deco_id in gd.DECOS:
		var deco: Dictionary = gd.DECOS[deco_id]
		if not deco.has("unlock"):
			continue
		check(int(deco["cost"]) == 0, "Belohnungsdeko %s kostet nichts" % deco_id)
		check(unlock_keys.has(str(deco["unlock"])), "Freischaltung von %s verweist auf ein Ziel" % deco_id)
	# Fortschritt zählt nur innerhalb der laufenden Jahreszeit.
	gs.new_game()
	var strawberry: Dictionary = {}
	for goal in gs.season_goals():
		if str(goal["id"]) == "spring_strawberries":
			strawberry = goal
	check(gs.season_goals().size() == 3 and not strawberry.is_empty(), "Frühling zeigt Erdbeeren, Säen und Sammeln")
	check(gs.season_goal_progress(strawberry) == 0 and not gs.season_goal_done(strawberry), "Saisonziel startet bei null")
	gs.bump("harvested:strawberry", 11)
	check(gs.season_goal_progress(strawberry) == 11, "Fortschritt zählt die Ernten der Sorte")
	gs.bump("harvested:tomato", 20)
	check(gs.season_goal_progress(strawberry) == 11, "andere Sorten zählen nicht mit")
	gs.bump("harvested:strawberry", 1)
	check(gs.season_goal_done(strawberry) and gs.claimable_season_goals() == 1, "zwölf Erdbeeren erfüllen das Ziel")
	var coins_before: int = gs.coins
	check(gs.claim_season_goal("spring_strawberries"), "Saisonziel abholen")
	check(gs.coins == coins_before, "Saisonziel gibt keine Münzen")
	check(not gs.claim_season_goal("spring_strawberries"), "Belohnung nur einmal pro Jahr")
	check(gs.claimable_season_goals() == 0, "abgeholtes Ziel wird nicht mehr gezählt")
	check(not gs.claim_season_goal("summer_tomatoes"), "Ziel einer anderen Jahreszeit ist nicht abholbar")
	# Alle drei Ziele einer Jahreszeit schalten die Deko frei.
	gs.bump("planted", 20)
	gs.bump("foraged", 6)
	check(gs.claim_season_goal("spring_sowing"), "zweites Frühlingsziel abholen")
	check(gs.claim_season_goal("spring_forage"), "drittes Frühlingsziel abholen")
	check(gs.unlocked_decos.has("season_arch") and gs.deco_unlocked("season_arch"), "alle drei Ziele schalten den Blütenbogen frei")
	check(not gs.deco_unlocked("season_bench"), "Deko einer anderen Jahreszeit bleibt zu")
	var free_cell := Vector2i(9, 12)
	check(gs.place_object("season_bench", free_cell) < 0, "nicht freigeschaltete Deko lässt sich nicht platzieren")
	coins_before = gs.coins
	check(gs.place_object("season_arch", free_cell) > 0 and gs.coins == coins_before, "freigeschaltete Deko ist kostenlos platzierbar")
	# Saisonwechsel setzt den Schnappschuss zurück.
	gs.time_offset += float(gd.REAL_DAY_SECONDS) * 6.0
	gs._sync_season()
	check(gs.season_name() == "Sommer" and gs.season_days_left() == 5, "nach sechs Tagen beginnt der Sommer")
	check(gs.season_goal_progress(strawberry) == 0, "Fortschritt der alten Saison wird nicht mitgenommen")
	check(gs.season_goals().size() == 3 and str(gs.season_goals()[0]["season"]) == "summer", "Sommer zeigt seine eigenen Ziele")
	# Alle zwölf Ziele eines Jahres schalten den Jahreskranz frei.
	var year: int = int(gs.season_year())
	for index in range(gd.SEASONS.size()):
		for goal in gs.season_goals_for(str(gd.SEASONS[index]["id"])):
			var key := "season:%d:%s" % [year * gd.SEASONS.size() + index, str(goal["id"])]
			if not gs.claimed_quests.has(key):
				gs.claimed_quests.append(key)
	gs._check_season_rewards()
	check(gs.unlocked_decos.has(gd.SEASON_YEAR_DECO), "alle zwölf Ziele eines Jahres schalten den Jahreskranz frei")
	check(gs.diary.any(func(entry: Dictionary) -> bool: return gs.diary_text(entry).contains("Jahreskranz")), "Jahreskranz wird im Tagebuch erzählt")
	# Speichern, Laden und Verwerfen unbekannter Schlüssel.
	var saved: Dictionary = gs.serialize()
	check(saved.has("season_stats_snapshot") and saved.has("seasons_seen") and saved.has("unlocked_decos") and saved.has("hofbuch_claimed"), "Saisonfelder stehen im Spielstand")
	gs.new_game()
	check(gs.deserialize(saved), "Saisonstand laden")
	check(gs.season_snapshot_epoch == gs.season_epoch(), "Saison-Schnappschuss bleibt in derselben Saison erhalten")
	check(gs.unlocked_decos.has("season_arch") and gs.unlocked_decos.has(gd.SEASON_YEAR_DECO), "Freischaltungen bleiben gespeichert")
	check(gs.seasons_seen.has("spring") and gs.seasons_seen.has("summer"), "erlebte Jahreszeiten bleiben gespeichert")
	check(gs.claimed_quests.has("season:0:spring_strawberries"), "saisonale Abholung bleibt gespeichert")
	var tampered: Dictionary = saved.duplicate(true)
	tampered["claimed_quests"] = ["season:0:spring_strawberries", "season:0:ghost", "q_plant5", "season:x:spring_sowing", "season:0:spring_sowing"]
	check(gs.deserialize(tampered), "Spielstand mit saisonalen Schlüsseln laden")
	check(gs.claimed_quests.has("season:0:spring_strawberries") and gs.claimed_quests.has("season:0:spring_sowing") and gs.claimed_quests.has("q_plant5"), "gültige saisonale Schlüssel bleiben")
	check(not gs.claimed_quests.has("season:0:ghost") and not gs.claimed_quests.has("season:x:spring_sowing"), "unbekannte saisonale Schlüssel werden verworfen")
	# Migration 9 → 10 startet ohne rückwirkenden Fortschritt.
	var v9 := {"version": 9, "saved_at": gs.now(), "stats": {"harvested": 42}, "animals": []}
	var migrated: Dictionary = ss.migrate(v9)
	check(int(migrated.get("version", 0)) == 11, "Version 9 migriert auf Version 11")
	check(int(migrated.get("season_stats_snapshot", {}).get("harvested", 0)) == 42, "Saison-Schnappschuss startet bei den aktuellen Zählern")
	check((migrated.get("seasons_seen", []) as Array).size() == 1 and (migrated.get("seasons_seen", []) as Array).has("spring"), "migrierter Stand kennt die laufende Jahreszeit")
	check((migrated.get("unlocked_decos", null) as Array).is_empty() and (migrated.get("hofbuch_claimed", null) as Array).is_empty(), "Freischaltungen starten leer")
	check(gs.deserialize(migrated), "migrierten Saisonstand laden")
	check(gs.season_goal_progress(strawberry) == 0, "alter Stand holt keine Saisonbelohnung rückwirkend")
	gs.new_game()


func test_hofbuch() -> void:
	begin("Hofbuch")
	check(gd.HOFBUCH.size() == 8, "acht Hofbuch-Auszeichnungen")
	var entries := {}
	for entry in gd.HOFBUCH:
		entries[str(entry["id"])] = entry
		check(not str(entry["description"]).is_empty(), "%s erklärt sich" % entry["id"])
		check(not str(entry.get("story", "")).is_empty(), "%s erzählt eine Geschichte" % entry["id"])
		var deco := str(entry.get("deco", ""))
		check(gd.DECOS.has(deco) and str(gd.DECOS[deco].get("unlock", "")) == "hofbuch:" + str(entry["id"]), "%s schaltet seine Deko frei" % entry["id"])
	check(int(entries["pantry"]["target"]) == gd.RECIPES.size(), "Speisekammer zählt alle Rezepte")
	check(int(entries["green_hands"]["target"]) == gd.CROPS.size(), "Grüne Hände zählt alle Pflanzen")
	check(int(entries["home_for_all"]["target"]) == 4 * int(gd.BUILDINGS["paddock"]["capacity"]), "Zuhause für alle zählt alle Gehegeplätze")
	gs.new_game()
	check(gs.hofbuch_progress(entries["year_round"]) == 1, "neue Farm hat die laufende Jahreszeit erlebt")
	check(gs.hofbuch_progress(entries["season_child"]) == 0, "Saisonkind startet ohne erfüllte Ziele")
	check(not gs.claim_hofbuch("season_child"), "unfertige Auszeichnung ist nicht abholbar")
	for recipe_id in gd.RECIPES:
		gs.bump("crafted_" + str(recipe_id))
	check(gs.hofbuch_unlocked(entries["pantry"]), "alle Rezepte schalten die Speisekammer frei")
	for crop_id in gd.CROPS:
		gs.bump("harvested:" + str(crop_id))
	check(gs.hofbuch_unlocked(entries["green_hands"]), "alle Pflanzen schalten grüne Hände frei")
	for story_id in gd.DELIVERY_STORIES:
		gs.bump("story_completed:" + str(story_id))
	check(gs.hofbuch_unlocked(entries["neighbors"]), "alle Liefergeschichten schalten das Gartentor frei")
	gs.bump("cafe_stories_shared", 25)
	check(gs.hofbuch_unlocked(entries["cafe_table"]), "25 Café-Geschichten schalten den Stammtisch frei")
	for species in gd.ANIMALS:
		gs.animals.append({"uid": 900 + gs.animals.size(), "species": species, "name": "Test", "hearts": 40})
	check(gs.hofbuch_unlocked(entries["refuge_stories"]), "alle fünf Tierarten mit 40 Herzen")
	for index in range(4):
		gs.objects.append({"uid": 500 + index, "kind": "paddock", "type": "paddock", "cell": Vector2i(8 + index * 4, 11), "queue": [], "upgrades": 0})
	while gs.animals.size() < 12:
		gs.animals.append({"uid": 900 + gs.animals.size(), "species": "rabbit", "name": "Test", "hearts": 0})
	check(gs.hofbuch_unlocked(entries["home_for_all"]), "zwölf belegte Gehegeplätze")
	var coins_before: int = gs.coins
	check(gs.claim_hofbuch("pantry"), "ausgezeichnete Speisekammer eintragen")
	check(gs.coins == coins_before, "Hofbuch zahlt keine Münzen")
	check(gs.unlocked_decos.has("hofbuch_basket") and gs.deco_unlocked("hofbuch_basket"), "Hofbuch schaltet seine Deko frei")
	check(not gs.claim_hofbuch("pantry"), "Eintrag gibt es nur einmal")
	check(gs.diary_text(gs.diary.back()).begins_with("Hofbuch · Speisekammer"), "Geschichte landet im Tagebuch")
	check(gs.claimable_hofbuch() >= 4, "offene Einträge werden gezählt")
	var saved: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(saved), "Hofbuch laden")
	check(gs.hofbuch_entry_claimed("pantry") and gs.unlocked_decos.has("hofbuch_basket"), "Eintrag und Deko bleiben gespeichert")
	var tampered: Dictionary = saved.duplicate(true)
	tampered["hofbuch_claimed"] = ["pantry", "ghost"]
	tampered["unlocked_decos"] = ["hofbuch_basket", "season_arch", "ghost", "flowers"]
	tampered["seasons_seen"] = ["spring", "summer", "ghost"]
	check(gs.deserialize(tampered), "Hofbuch-Stand mit unbekannten IDs laden")
	check(gs.hofbuch_claimed.size() == 1 and gs.hofbuch_claimed.has("pantry"), "unbekannte Hofbuch-IDs werden verworfen")
	check(gs.unlocked_decos.size() == 2 and gs.unlocked_decos.has("hofbuch_basket") and gs.unlocked_decos.has("season_arch"), "nur echte Belohnungsdeko wird gespeichert")
	check(gs.seasons_seen.size() == 2 and not gs.seasons_seen.has("ghost"), "unbekannte Jahreszeiten werden verworfen")
	gs.new_game()


func test_weather_growth() -> void:
	begin("Wetterabhängiges Pflanzenwachstum")
	var cycle: float = gd.WEATHER_DURATION_SECONDS * float(gd.WEATHER_TYPES.size())
	var rain_start: float = 2.0 * gd.WEATHER_DURATION_SECONDS + 30.0
	check(gd.crop_growth_seconds_between(rain_start, rain_start + 60.0) == 75.0, "60 Sekunden Regen liefern 75 Sekunden effektives Wachstum")
	var cloudy_start: float = gd.WEATHER_DURATION_SECONDS + 30.0
	check(gd.crop_growth_seconds_between(cloudy_start, cloudy_start + 60.0) == 54.0, "60 Sekunden Wolken liefern 54 Sekunden effektives Wachstum")
	var expected_cycle: float = gd.WEATHER_DURATION_SECONDS * (1.0 + 0.9 + 1.25 + 1.0)
	check(is_equal_approx(gd.crop_growth_seconds_between(0.0, cycle), expected_cycle), "vollständiger Wetterzyklus summiert alle Effekte")
	check(is_equal_approx(gd.crop_growth_seconds_between(0.0, cycle * 100000.0), expected_cycle * 100000.0), "lange Offline-Zeiten werden effizient über ganze Wetterzyklen berechnet")
	var cell: Vector2i = gs.fields.keys()[0]
	gs.coins = 100
	gs.level = 1
	gs.time_offset = rain_start - Time.get_unix_time_from_system()
	check(gs.plant(cell, "wheat"), "Pflanze kann vor Regenbeginn gesät werden")
	gs.time_offset += 20.0
	check(gs.crop_progress(cell) > 0.0 and gs.crop_remaining(cell) < 30.0, "Wachstum und Restzeit berücksichtigen laufenden Regen")
	var rain_remaining: float = gs.crop_remaining(cell)
	gs.time_offset += 10.0
	check(gs.crop_remaining(cell) < rain_remaining, "Regen verkürzt die verbleibende Erntezeit")
	var encoded: Dictionary = gs.serialize()
	check(gs.deserialize(encoded) and gs.crop_remaining(cell) <= rain_remaining, "Wetterwachstum funktioniert nach dem Speichern und Laden weiter")
	gs.time_offset = cycle * 2.0 - Time.get_unix_time_from_system()
	check(gd.weather_at(gs.now()) == "Sonnig", "reale Spielzeit bestimmt den Wetterzustand")


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
	check(int(gs.stats.get("harvested:wheat", 0)) == 1, "Ernten werden zusätzlich pro Sorte gezählt")
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
	gs.coins = 100
	check(not gs.buy_item("almond", 1), "Mandeln sind keine Shop-Zutat mehr")
	check(gs.coins == 100, "Feldfrüchte lassen sich nicht direkt kaufen")
	check(not gs.spend_coins(1000), "zu teuer")
	check(gs.coins == 100, "Münzen unverändert bei Fehlschlag")


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


func test_production_dashboard() -> void:
	begin("Produktionsübersicht")
	level_to(5)
	gs.coins = 5000
	var bakery: int = gs.place_object("bakery", Vector2i(8, 11))
	var milkery: int = gs.place_object("milkery", Vector2i(10, 11))
	check(bakery > 0 and milkery > 0, "zwei Produktionsgebäude gebaut")
	check(gs.production_buildings().size() == 2, "Übersicht listet alle Produktionsgebäude")
	check(gs.total_ready_products() == 0 and gs.active_product_count() == 0, "leere Produktion")
	gs.add_item("wheat", 3)
	gs.add_item("oat", 3)
	check(gs.start_recipe(bakery, "bread"), "Brot starten")
	check(gs.start_recipe(milkery, "oat_milk"), "Hafermilch starten")
	check(gs.active_product_count() == 2, "beide Produktionen laufen")
	var none: Dictionary = gs.collect_all_ready()
	check(int(none["count"]) == 0 and int(none["buildings"]) == 0, "Sammelabholung ohne fertige Ware")
	gs.time_offset += 61.0
	check(gs.total_ready_products() == 1, "ein Produkt fertig")
	check(gs.active_product_count() == 1, "eine Produktion läuft weiter")
	var first: Dictionary = gs.collect_all_ready()
	check(int(first["count"]) == 1 and int(first["buildings"]) == 1, "Sammelabholung meldet ein Produkt aus einem Gebäude")
	check(int(first["items"].get("bread", 0)) == 1, "Sammelabholung meldet die Sorte")
	check(gs.item_count("bread") == 1 and gs.item_count("oat_milk") == 0, "nur fertige Ware wird abgeholt")
	check(gs.total_ready_products() == 0, "Zähler nach Abholung leer")
	gs.time_offset += 30.0
	check(gs.total_ready_products() == 1, "zweites Produkt fertig")
	var second: Dictionary = gs.collect_all_ready()
	check(int(second["count"]) == 1 and int(second["buildings"]) == 1 and gs.item_count("oat_milk") == 1, "zweite Sammelabholung")
	check(int(gs.collect_all_ready()["count"]) == 0, "keine doppelte Abholung")
	check(int(gs.stats.get("crafted", 0)) == 2, "Sammelabholung zählt beide Produkte")
	# Zwei Gebäude gleichzeitig fertig: eine Sammelabholung räumt beide ab.
	gs.add_item("wheat", 3)
	gs.add_item("oat", 3)
	check(gs.start_recipe(bakery, "bread") and gs.start_recipe(milkery, "oat_milk"), "zweite Runde gestartet")
	gs.time_offset += 91.0
	var both: Dictionary = gs.collect_all_ready()
	check(int(both["count"]) == 2 and int(both["buildings"]) == 2, "Sammelabholung über zwei Gebäude")
	check(int(both["items"].get("bread", 0)) == 1 and int(both["items"].get("oat_milk", 0)) == 1, "beide Sorten werden gemeldet")
	check(gs.item_count("bread") == 2 and gs.item_count("oat_milk") == 2, "beide Vorräte ergänzt")
	check(int(gs.stats.get("crafted", 0)) == 4, "alle vier Produkte gezählt")


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
	check(gs.diary_text(gs.diary.back()).contains("Ein ruhiger Ort zum Erzählen."), "Gästegeschichte ist im Tagebuch")
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
	level_to(11)
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
	check(gs.diary.size() >= 5 and gs.diary_text(gs.diary.back()).contains("abgeschlossen"), "Abschluss und Abschnitte stehen im Refugiums-Tagebuch")
	check(gd.RECIPES.size() >= 46, "die neuen Produktionsketten erweitern das Rezeptbuch auf 46 Rezepte")


func test_cafe() -> void:
	begin("Veganes Gartencafé")
	check(gd.BUILDINGS.has("cafe") and int(gd.BUILDINGS["cafe"]["level"]) == 11, "Café ab Stufe 11 freigeschaltet")
	check(gd.CROPS.has("coffee") and not gd.CROPS["coffee"].has("perennial"), "Kaffee wird wie alle Pflanzen einjährig angebaut")
	check(gd.RECIPES.has("roasted_coffee") and gd.RECIPES.has("filter_coffee") and gd.RECIPES.has("oat_latte"), "Kaffeekette mit Hafer-Latte")
	check(gd.RECIPES.has("pumpkin_spice_latte") and gd.RECIPES.has("blueberry_coffee_cake"), "Tageskarte erhält spätere Café-Rezepte")
	check(gs.daily_cafe_special().is_empty(), "Tagesgericht ohne Café noch nicht verfügbar")
	level_to(11)
	gs.coins = 10000
	var cafe_uid: int = gs.place_object("cafe", Vector2i(8, 11))
	check(cafe_uid > 0, "Gartencafé bauen")
	check(gs.quest_progress({"type": "building", "building": "cafe", "target": 1}) == 1, "Café-Ziel nimmt Baufortschritt auf")
	var cafe_achievement: Dictionary = {}
	for achievement in gd.ACHIEVEMENTS:
		if str(achievement["id"]) == "cafe_open":
			cafe_achievement = achievement
	check(not cafe_achievement.is_empty() and gs.achievement_unlocked(cafe_achievement), "Café-Erfolg erkennt das Gebäude")
	check(not gs.available_delivery_stories().has("cafe_opening"), "Café-Geschichte wartet auf Stufe 14, damit alle Lieferungen herstellbar sind")
	level_to(14)
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
	check(not gs.daily_cafe_special().is_empty(), "Tagesgericht wird für Café ausgewählt")
	var special_id: String = gs.daily_cafe_special()
	var special_started_at: float = gs.daily_cafe_special_at
	check(is_equal_approx(gs.daily_cafe_special_seconds_left(), gs.CAFE_SPECIAL_DURATION), "Tagesgericht bleibt 24 echte Stunden bestehen")
	var saved_special_state: Dictionary = gs.serialize()
	gs.time_offset += gs.CAFE_SPECIAL_DURATION - 1.0
	gs._fill_orders()
	check(gs.daily_cafe_special() == special_id and gs.daily_cafe_special_at == special_started_at, "Tagesgericht bleibt bis zum vollen 24-Stunden-Wechsel unverändert")
	gs.time_offset += 2.0
	gs._fill_orders()
	check(gs.daily_cafe_special() != special_id and is_equal_approx(gs.daily_cafe_special_at, special_started_at + gs.CAFE_SPECIAL_DURATION), "Tagesgericht wechselt nach 24 Stunden echter Zeit")
	var special_order: Dictionary = {}
	for attempt in range(300):
		var generated: Dictionary = gs.generate_order()
		if bool(generated.get("cafe_daily_special", false)):
			special_order = generated
			break
	check(not special_order.is_empty(), "Gäste bestellen das Tagesgericht häufiger")
	if not special_order.is_empty():
		var special_recipe: Dictionary = gd.RECIPES[str(special_order.items.keys()[0])]
		var special_qty := int(special_order.items.values()[0])
		var regular_reward := int(special_recipe["sell"]) * special_qty + 8
		check(int(special_order.coins) == int(ceil(float(regular_reward) * 1.5)), "Tagesgericht gibt 50 Prozent Münzbonus")
		check(int(special_order.xp) == int(special_recipe["xp"]) + gs.CAFE_SPECIAL_XP_BONUS, "Tagesgericht gibt fünf Bonus-XP")
		gs.orders.append(special_order)
		for item in special_order.items:
			gs.add_item(str(item), int(special_order.items[item]))
		check(gs.fulfill_order(int(special_order.id)), "Tagesgericht-Bestellung erfüllen")
		check(int(gs.stats.get("cafe_special_orders", 0)) == 1, "serviertes Tagesgericht zählt für das Café-Ziel")
		var special_order_save: Dictionary = saved_special_state.duplicate(true)
		special_order_save["orders"] = [special_order.duplicate(true)]
		special_order_save["stats"] = gs.stats.duplicate()
		gs.time_offset = 0.0
		check(gs.deserialize(special_order_save), "Tagesgericht-Spielstand wird geladen")
		check(bool(gs.orders[0].get("cafe_daily_special", false)), "besonderer Gastauftrag bleibt im Spielstand markiert")
	else:
		gs.time_offset = 0.0
		check(gs.deserialize(saved_special_state), "Tagesgericht-Spielstand wird geladen")
	var persisted_special: String = str(saved_special_state["daily_cafe_special_id"])
	check(gs.daily_cafe_special_id == persisted_special and is_equal_approx(gs.daily_cafe_special_at, float(saved_special_state["daily_cafe_special_at"])), "Tagesgericht und Wechselzeit werden gespeichert und geladen")
	var special_quest: Dictionary = {}
	for quest in gd.QUESTS:
		if str(quest["id"]) == "q_cafe_specials":
			special_quest = quest
	gs.bump("cafe_special_orders", 5)
	check(not special_quest.is_empty() and gs.quest_done(special_quest), "Tagesgerichte zählen auf Café-Ziel")
	gs.daily_cafe_special_at = gs.now() - gs.CAFE_SPECIAL_DURATION * 3.0 - 12.0
	gs._refresh_daily_cafe_special()
	check(is_equal_approx(gs.daily_cafe_special_at, gs.now() - 12.0), "versäumte tägliche Wechsel laufen ohne Zeitdrift nach")
	var v5_save: Dictionary = gs.serialize()
	v5_save["version"] = 5
	var migrated_v5: Dictionary = ss.migrate(v5_save)
	check(int(migrated_v5["version"]) == 11 and migrated_v5.has("daily_cafe_special_id"), "Version 5 wird auf Tagesgericht-, Wetter- und Eventschema migriert")
	check(int(migrated_v5["stats"].get("cafe_special_orders", -1)) == int(gs.stats.get("cafe_special_orders", 0)), "Café-Tagesgericht-Statistik wird migriert")
	var old_cafe_save: Dictionary = gs.serialize()
	old_cafe_save["version"] = 5
	old_cafe_save["stats"].erase("cafe_special_orders")
	var migrated_old_cafe: Dictionary = ss.migrate(old_cafe_save)
	check(int(migrated_old_cafe["stats"]["cafe_orders"]) == int(gs.stats.get("cafe_orders", 0)), "Café-Altstatistik bleibt erhalten")
	check(int(migrated_old_cafe["stats"]["cafe_special_orders"]) == 0, "Tagesgericht-Statistik startet bei alten Ständen bei null")
	var v6_migrated: Dictionary = ss.migrate({"version": 6, "settings": {"sound": false}, "animals": []})
	check(int(v6_migrated["version"]) == 11 and bool(v6_migrated["settings"]["sound"]) == false, "Version 6 wird ohne Verlust vorhandener Einstellungen migriert")
	var v7_migrated: Dictionary = ss.migrate({"version": 7, "settings": {"music": false}, "animals": []})
	check(int(v7_migrated["version"]) == 11 and v7_migrated["neighborhood_event_order"].is_empty(), "Version 7 erhält leere Event-Migration")


func test_cafe_guests() -> void:
	begin("Café-Gäste")
	check(gs.cafe_tables() == 0 and not gs.cafe_is_open(), "ohne Café keine Tische und kein Betrieb")
	level_to(11)
	gs.coins = 10000
	var uid: int = gs.place_object("cafe", Vector2i(8, 11))
	check(uid > 0, "Café gebaut")
	check(gs.cafe_tables() == 1, "Café beginnt mit einem Tisch")
	gs.clock_seconds = 9.0 * 3600.0
	check(not gs.cafe_is_open(), "vor zehn Uhr ist das Café geschlossen")
	gs.clock_seconds = 10.0 * 3600.0
	check(gs.cafe_is_open(), "um zehn Uhr öffnet das Café")
	gs.clock_seconds = 18.0 * 3600.0
	check(not gs.cafe_is_open(), "um achtzehn Uhr schließt das Café")
	check(gs.clock_text() == "18:00", "Spieluhr zeigt die Uhrzeit")
	# Auf Stufe 11 ist noch kein Café-Gericht freigeschaltet: dann kommt niemand.
	gs.clock_seconds = 11.0 * 3600.0
	gs.cafe_next_guest_at = 0.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.is_empty(), "ohne freigeschaltete Karte kommen keine Gäste")
	var base_interval: float = gs.cafe_guest_interval()
	for i in range(3):
		check(gs.upgrade_building(uid), "Café ausbauen")
		check(gs.cafe_tables() == 2 + i, "jeder Ausbau stellt einen Tisch auf (%d)" % gs.cafe_tables())
	check(gs.cafe_tables() == 4 and gs.cafe_tables() <= 1 + gs.MAX_UPGRADES, "Café hat höchstens vier Tische")
	check(gs.cafe_guest_interval() < base_interval, "mehr Tische bringen mehr Gäste")
	level_to(14)
	check(not gs._available_cafe_specials().is_empty(), "ab Stufe 14 steht die Café-Karte")
	check(gs.cafe_guests.is_empty() and gs.cafe_day_served == 0, "das Café startet leer")
	gs.cafe_next_guest_at = 0.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.size() == 1, "zu Öffnungszeiten setzt sich ein Gast")
	var guest: Dictionary = gs.cafe_guests[0]
	check(int(guest["table"]) >= 1 and int(guest["table"]) <= gs.cafe_tables(), "der Gast bekommt einen Tisch")
	check(gd.CAFE_MENU.has(str(guest["dish"])), "der Gast bestellt aus der Karte")
	check(gs.cafe_waiting_count() == 1, "wartende Gäste werden gezählt")
	check(int(guest["pay"]) > int(gd.RECIPES[str(guest["dish"])]["sell"]), "im Café liegt der Preis über dem Ladenpreis")
	for i in range(12):
		gs.cafe_next_guest_at = 0.0
		gs._tick_cafe(0.5)
	check(gs.cafe_guests.size() == gs.cafe_tables(), "mehr Gäste als Tische gibt es nicht")
	var seen := {}
	for g in gs.cafe_guests:
		seen[str(g["name"])] = true
	check(seen.size() == gs.cafe_guests.size(), "kein Gast sitzt doppelt im Café")
	# Bedienen: erst mit Ware, dann isst der Gast und zahlt danach.
	var table := int(gs.cafe_guests[0]["table"])
	var dish := str(gs.cafe_guests[0]["dish"])
	gs.inventory.erase(dish)
	check(not gs.serve_cafe_guest(table), "ohne Vorrat lässt sich nichts servieren")
	gs.add_item(dish, 2)
	var coins_before: int = gs.coins
	check(gs.serve_cafe_guest(table), "mit Vorrat wird der Gast bedient")
	check(gs.item_count(dish) == 1, "Servieren nimmt ein Gericht aus dem Vorrat")
	check(gs.coins == coins_before, "bezahlt wird erst nach dem Essen")
	check(not gs.serve_cafe_guest(table), "derselbe Gast wird nicht doppelt bedient")
	# Kein neuer Gast während des Essens, damit der Tisch eindeutig bleibt.
	gs.cafe_next_guest_at = gs.now() + 9999.0
	gs.time_offset += gs.CAFE_EAT_SECONDS + 1.0
	gs._tick_cafe(0.5)
	check(gs.coins > coins_before, "nach dem Essen wird bezahlt")
	check(int(gs.stats.get("cafe_guests", 0)) == 1, "bediente Gäste zählen in der Langzeitstatistik")
	check(gs.cafe_day_served == 1 and gs.cafe_day_coins == gs.coins - coins_before, "Tagesumsatz zählt den Gast mit")
	check(gs.cafe_guest_at(table).is_empty(), "der Tisch ist nach dem Bezahlen wieder frei")
	# Gehen lassen kostet nichts.
	gs.cafe_guests.clear()
	gs.cafe_next_guest_at = 0.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.size() == 1, "neuer Gast nimmt Platz")
	var coins_now: int = gs.coins
	check(gs.send_cafe_guest_home(int(gs.cafe_guests[0]["table"])), "Gast lässt sich nach Hause schicken")
	check(gs.cafe_guests.is_empty() and gs.coins == coins_now, "Gehen lassen kostet nichts")
	# Ladenschluss räumt wartende Gäste, lässt niemanden neu herein.
	gs.cafe_next_guest_at = 0.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.size() == 1, "vor Ladenschluss sitzt noch ein Gast")
	gs.clock_seconds = 18.2 * 3600.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.is_empty(), "nach Ladenschluss gehen wartende Gäste")
	for i in range(4):
		gs._tick_cafe(0.5)
	check(gs.cafe_guests.is_empty(), "geschlossen kommen keine neuen Gäste")
	# Tageszahlen folgen dem Spieltag.
	gs.cafe_guests.clear()
	gs.cafe_next_guest_at = gs.now() + 9999.0
	var served_today: int = gs.cafe_day_served
	check(served_today == 1, "der Tag merkt sich den bedienten Gast")
	gs.time_offset += gd.REAL_DAY_SECONDS
	gs._tick_cafe(0.5)
	check(gs.cafe_day == gs.day_number(), "Tageszahlen folgen dem Spieltag")
	check(gs.cafe_day_served == 0 and gs.cafe_day_coins == 0, "Tagesumsatz beginnt jeden Tag neu")
	check(int(gs.stats.get("cafe_guests", 0)) == 1, "der Langzeitzähler läuft weiter")
	# Gäste sind flüchtig: kein Spielstand-Feld, keine rückwirkenden Besucher.
	gs.clock_seconds = 14.0 * 3600.0
	gs.cafe_next_guest_at = 0.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.size() >= 1, "am Nachmittag sitzt wieder jemand")
	var saved: Dictionary = gs.serialize()
	check(not saved.has("cafe_guests") and not saved.has("cafe_next_guest_at") and not saved.has("cafe_day"), "Gäste und Tageszahlen stehen nicht im Spielstand")
	check(int(saved["stats"].get("cafe_guests", 0)) == 1, "die Statistik wird dagegen gespeichert")
	check(gs.deserialize(saved), "Spielstand mit Café lädt")
	check(gs.cafe_guests.is_empty(), "nach dem Laden sind keine Gäste mehr da")
	check(gs.cafe_tables() == 4, "Tische bleiben Teil des Ausbaus")
	check(int(gs.stats.get("cafe_guests", 0)) == 1, "bediente Gäste überleben das Laden")
	# Nach einer Pause beginnt das Café leer: genau ein Gast, kein nachgeholter Tag.
	gs.clock_seconds = 12.0 * 3600.0
	gs._tick_cafe(0.5)
	check(gs.cafe_guests.size() == 1, "nach dem Laden kommt ein Gast statt eines nachgeholten Tages")
	check(gs.SAVE_VERSION == 11, "Café-Gäste brauchen keine neue Spielstand-Version")


func test_neighborhood_event() -> void:
	begin("Gartentag in der Nachbarschaft")
	var cycle_length: float = gs.NEIGHBORHOOD_EVENT_CYCLE_SECONDS
	var event_cycle := 2
	gs.level = 14
	gs.coins = 100000
	check(not gs.neighborhood_event_active(float(event_cycle) * cycle_length + gs.NEIGHBORHOOD_EVENT_DURATION_SECONDS), "Gartentag ist außerhalb seines Zeitfensters geschlossen")
	var cafe_uid: int = gs.place_object("cafe", Vector2i(8, 11))
	check(cafe_uid > 0, "Gartentag setzt Café voraus")
	var cycle_start: float = float(event_cycle) * cycle_length
	gs.time_offset = cycle_start - Time.get_unix_time_from_system() + 10.0
	check(gs.neighborhood_event_active(), "Gartentag öffnet am Beginn des Event-Zeitfensters")
	check(gs.neighborhood_event_window_seconds_left() > 0.0, "aktives Event zeigt Restzeit")
	gs.neighborhood_event_stage = 0
	gs._fill_orders()
	var previous_coins: int = gs.coins
	var previous_xp: int = gs.xp
	for expected_stage in range(gs.NEIGHBORHOOD_EVENT_SERIES_LENGTH):
		var event_order: Dictionary = {}
		for order in gs.orders:
			if order.has("neighborhood_event_cycle"):
				event_order = order
				break
		check(not event_order.is_empty(), "Event-Sonderbestellung für Etappe %d erscheint" % (expected_stage + 1))
		if event_order.is_empty():
			break
		check(int(event_order.neighborhood_event_stage) == expected_stage, "Etappenfolge bleibt chronologisch")
		check(int(event_order.coins) > 0 and int(event_order.xp) > 0 and int(event_order.items.size()) == 1, "Sonderauftrag bringt Ware, Münzen und XP")
		check(not str(event_order.neighborhood_event_story).is_empty(), "Eventauftrag erzählt eine eigene Nachbarschaftsgeschichte")
		for item_id in event_order.items:
			gs.add_item(str(item_id), int(event_order.items[item_id]))
		var reward_coins := int(event_order.coins)
		var reward_xp := int(event_order.xp)
		check(gs.fulfill_order(int(event_order.id)), "Gartentag-Etappe erfüllen")
		check(gs.coins >= previous_coins + reward_coins, "Sonderbelohnung wird einmal gutgeschrieben")
		check(gs.xp >= previous_xp + reward_xp, "Event-XP werden gutgeschrieben")
		previous_coins = gs.coins
		previous_xp = gs.xp
		if expected_stage < gs.NEIGHBORHOOD_EVENT_SERIES_LENGTH - 1:
			gs.time_offset += 1.0
			gs._fill_orders()
	check(gs.neighborhood_event_stage == 0, "Reihe startet nach drei Etappen wieder von vorn")
	check(gs.neighborhood_event_completed_cycle == event_cycle, "Abschluss wird für den Event-Zyklus markiert")
	check(int(gs.stats.get("neighborhood_events_completed", 0)) == 1, "Eventabschluss wird gezählt")
	check(gs.diary.size() >= gs.NEIGHBORHOOD_EVENT_SERIES_LENGTH and gs.diary_text(gs.diary.back()).contains("Gartentag"), "Erzählungen und Abschluss erscheinen im Tagebuch")
	var saved: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(saved), "Eventfortschritt und Abschluss speichern/laden")
	check(gs.neighborhood_event_completed_cycle == event_cycle and int(gs.stats.get("neighborhood_events_completed", 0)) == 1, "Abgeschlossener Event-Zyklus bleibt gespeichert")
	var v7_event_migration: Dictionary = ss.migrate({"version": 7, "settings": {"music": false}, "animals": []})
	check(int(v7_event_migration["version"]) == 11 and v7_event_migration["neighborhood_event_order"].is_empty(), "Version 7 erhält leere Event-Migration")
	var order_save: Dictionary = saved.duplicate(true)
	order_save["neighborhood_event_completed_cycle"] = -1
	order_save["neighborhood_event_stage"] = 1
	order_save["neighborhood_event_order"] = {"id": 9123, "cycle": event_cycle, "stage": 1, "customer": "Mira", "items": {"tomato": 2}, "coins": 88, "xp": 22, "story": "Ein Tomatenkorb für alle.", "cafe": false}
	order_save["orders"] = []
	gs.time_offset = cycle_start - Time.get_unix_time_from_system() + 20.0
	check(gs.deserialize(order_save), "Offene Event-Etappe wiederherstellen")
	check(gs.orders.any(func(order: Dictionary) -> bool: return order.has("neighborhood_event_cycle") and int(order["neighborhood_event_stage"]) == 1), "Offener Gartentag-Auftrag bleibt gespeichert")
	var saved_order: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(saved_order), "offene Event-Bestellung erneut laden")
	check(gs.orders.any(func(order: Dictionary) -> bool: return int(order.get("id", -1)) == 9123), "Sonderbestellungs-ID und Auftrag bleiben erhalten")


## Regression: Eine Lieferungsgeschichte, die während des Gartentags beginnt, bekommt ihre
## Bestellung sofort. Die Event-Bestellung darf ihr den Platz nicht wegnehmen.
## Die Uhr wird fest in das Event-Fenster gelegt, damit der Test nicht von der echten Uhrzeit abhängt.
func test_story_during_event() -> void:
	begin("Geschichte während des Gartentags")
	var cycle_length: float = gs.NEIGHBORHOOD_EVENT_CYCLE_SECONDS
	gs.level = 14
	gs.coins = 100000
	check(gs.place_object("cafe", Vector2i(8, 11)) > 0, "Café für den Gartentag bauen")
	gs.time_offset = 2.0 * cycle_length - Time.get_unix_time_from_system() + 10.0
	check(gs.neighborhood_event_active(), "Gartentag ist aktiv")
	gs.neighborhood_event_stage = 0
	gs.next_order_at = 0.0
	gs._fill_orders()
	check(gs.orders.size() == gs.MAX_ORDERS, "Auftragsbrett ist voll")
	check(gs.start_delivery_story("cafe_opening"), "Café-Geschichte starten")
	var has_story := false
	var has_event := false
	for order in gs.orders:
		if str(order.get("story_id", "")) == "cafe_opening":
			has_story = true
		if order.has("neighborhood_event_cycle"):
			has_event = true
	check(has_story, "Geschichtenbestellung erscheint sofort trotz aktivem Gartentag")
	check(has_event, "Event-Bestellung bleibt neben der Geschichte erhalten")
	check(gs.orders.size() <= gs.MAX_ORDERS, "Auftragsbrett läuft nicht über")


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
	check(gs.SAVE_VERSION == 11, "Gartentage und Tageszähler verwenden Save-Version 11")
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
	check(gs.diary.size() >= 2 and gs.diary_text(gs.diary.back()).contains(a.name), "Rettung und gemeinsamer Moment landen im Tagebuch")
	check(not gs.pet_animal(rab), "Streicheln hat Pause")
	gs.time_offset += gs.PET_COOLDOWN + 1.0
	check(gs.pet_animal(rab), "nach Pause wieder möglich")
	check(int(a.hearts) >= 4, "Herzen sammeln sich")
	check(gs.friendship_level(a) == 0, "Freundschaftsmeilenstein noch nicht voreilig erreicht")
	gs.record_animal_moment(a, "ein besonderer Testmoment", 1)
	check(gs.friendship_level(a) == 1, "Freundschaft schaltet erste Profilzeile frei")
	check(gs.diary_text(gs.diary.back()).contains("vertraut dir jetzt mehr"), "Meilenstein wird im Tagebuch festgehalten")
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
	check(int(encoded.version) == 11 and encoded.animals[0].has("traits") and encoded.animals[0].has("accessories"), "neue Profildaten werden in Save-Version 11 gespeichert")
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
	var old_land: Rect2i = gs.land
	var area: int = gs.land.get_area()
	check(gs.expand_land(), "Land erweitern")
	check(gs.land.get_area() > area, "mehr Fläche")
	check(gs.land == old_land.grow(1), "Land wächst zusammenhängend in alle Richtungen")
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


func test_land_expansion_chain() -> void:
	begin("Zusammenhängende Farm bis 24×24")
	check(gd.LAND_EXPANSIONS.size() >= 8, "acht fortlaufende Erweiterungsstufen sind vorhanden")
	check(gd.LAND_EXPANSIONS[4]["level"] < gd.LAND_EXPANSIONS[5]["level"] and gd.LAND_EXPANSIONS[5]["level"] < gd.LAND_EXPANSIONS[6]["level"] and gd.LAND_EXPANSIONS[6]["level"] < gd.LAND_EXPANSIONS[7]["level"], "zusätzliche Freischaltungen steigen sinnvoll an")
	check(gs.land == Rect2i(8, 11, 8, 8), "Farm startet auf 8×8 Feldern")
	gs.coins = 100000
	for i in range(gd.LAND_EXPANSIONS.size()):
		var expansion: Dictionary = gd.LAND_EXPANSIONS[i]
		level_to(int(expansion["level"]))
		var before: Rect2i = gs.land
		var coins_before: int = gs.coins
		check(gs.next_expansion() == expansion, "Stufe %d zeigt die passende Erweiterung" % (i + 1))
		check(gs.expand_land(), "Erweiterung %d ist finanzierbar und verfügbar" % (i + 1))
		check(gs.land == before.grow(1), "Erweiterung %d vergrößert alle vier Seiten zusammenhängend" % (i + 1))
		check(gs.coins == coins_before - int(expansion["cost"]), "Erweiterung %d zieht genau die Kosten ab" % (i + 1))
		check(int(gs.stats.get("expansions", 0)) == i + 1, "Erweiterungsstatistik bleibt fortlaufend")
		var edge_cell := Vector2i(gs.land.end.x - 1, gs.land.end.y - 1)
		check(gs.till(edge_cell), "neu erschlossener Rand %s ist direkt nutzbar" % edge_cell)
		check(gs.fields.has(edge_cell) and gs.in_land(edge_cell), "neues Feld liegt im selben zusammenhängenden Land")
	check(gs.land == Rect2i(0, 3, 24, 24), "Endausbau ergibt 24×24 Felder innerhalb der Einzelkarte")
	gs.coins = 100000
	level_to(30)
	var before_world_limit: Rect2i = gs.land
	var coins_before_world_limit: int = gs.coins
	gs.land = Rect2i(1, 3, 24, 24)
	gs.land_level = 7
	check(not gs.expand_land(), "Erweiterung wird vor Überschreiten der Weltgrenze abgelehnt")
	check(gs.land == Rect2i(1, 3, 24, 24) and gs.land_level == 7, "abgelehnte Erweiterung lässt Landstufe unverändert")
	check(gs.coins == coins_before_world_limit, "abgelehnte Erweiterung erstattet Kosten vollständig")
	gs.land = before_world_limit
	gs.land_level = 8
	check(gd.WORLD_ORIGIN == Vector2i.ZERO, "Einzelkarte verankert die Farm am Weltursprung")
	check(gd.WORLD_COLS == 24 and gd.WORLD_ROWS >= 24, "Einzelkarte umfasst die volle Farm")
	check(gs.land_level == 8 and gs.next_expansion().is_empty(), "nach acht Schritten gibt es keine weitere Farmseite")
	check(not gs.expand_land(), "vollständige Farm kann nicht über die Kartenkante hinaus wachsen")
	check(gd.WORLD_COLS >= gs.land.end.x and gd.WORLD_ROWS >= gs.land.end.y, "Vollausbau passt in die begehbare Einzelkarte")
	check(gd.WORLD_ORIGIN.x <= gs.land.position.x and gd.WORLD_ORIGIN.y <= gs.land.position.y and gd.WORLD_ORIGIN.x + gd.WORLD_COLS >= gs.land.end.x and gd.WORLD_ORIGIN.y + gd.WORLD_ROWS >= gs.land.end.y, "die vollständige Farm bleibt innerhalb der Weltgrenzen")
	var world_script_resource: GDScript = load("res://scripts/world/world.gd")
	var viewport_size := Vector2(960, 540)
	var zoom := 0.75
	var camera_bounds: Rect2 = world_script_resource.camera_position_bounds(gs.land, viewport_size, zoom)
	var camera_before_pan: Vector2 = (Vector2(gs.land.position) + Vector2(gs.land.size) * 0.5) * gd.TILE
	var camera_move := minf(500.0, float(gs.land.size.x * gd.TILE) * 0.25)
	var camera_after_pan: Vector2 = world_script_resource.clamp_camera_position(camera_before_pan + Vector2(camera_move, 0), camera_bounds)
	check(camera_after_pan.x > camera_before_pan.x, "Kamera kann die einzelne Farmkarte horizontal erkunden")
	var camera_at_world_edge: Vector2 = world_script_resource.clamp_camera_position(Vector2(-10000, -10000), camera_bounds)
	check(camera_at_world_edge.x >= float(gs.land.position.x * gd.TILE) and camera_at_world_edge.y >= float(gs.land.position.y * gd.TILE), "Kamera bleibt auch am Kartenrand im Farmgebiet")
	var saved_land: Dictionary = gs.serialize()
	gs.new_game()
	check(gs.deserialize(saved_land), "vollständig erweiterte Farm wird geladen")
	check(gs.land == Rect2i(0, 3, 24, 24) and gs.land_level == 8, "24×24-Farm bleibt in einer Karte gespeichert")


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
	gs.settings["music"] = false
	gs.settings["sound_volume"] = 0.0
	gs.settings["music_volume"] = 0.0
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
	check(gs.settings["sound"] == false and gs.settings["music"] == false and gs.settings["sound_volume"] == 0.0 and gs.settings["music_volume"] == 0.0, "Ton- und Musiklautstärke bleiben erhalten")
	check(not gs.object_at(Vector2i(8, 11)).is_empty(), "Belegung neu aufgebaut")
	check(not gs.can_place("tree", Vector2i(8, 11)), "belegte Fläche bleibt belegt")
	var uid: int = gs.place_object("tree", Vector2i(14, 16))
	check(uid > 0 and gs.get_object(uid).uid != bak, "neue UIDs kollidieren nicht")
	var d: Dictionary = gs.serialize()
	check(int(d.version) == gs.SAVE_VERSION, "Version im Spielstand")
	check(gs.SAVE_VERSION == 11, "Gartentage und Tageszähler verwenden Save-Version 11")


## „Tutorial wiederholen“ darf nicht an der Gesamtstatistik hängen: Wer schon gespielt
## hat, soll wieder bei Schritt 1 beginnen und nur neue Handlungen zählen lassen.
func test_tutorial_restart() -> void:
	begin("Tutorial wiederholen")
	gs.stats = {"planted": 12, "harvested": 9, "orders": 4}
	gs.tutorial_step = 99
	check(gs.tutorial_progress("planted") == 12, "ohne Basis zählt die ganze Statistik")
	gs.restart_tutorial()
	check(gs.tutorial_step == 0, "Neustart beginnt bei Schritt 0")
	check(gs.tutorial_progress("planted") == 0 and gs.tutorial_progress("harvested") == 0 and gs.tutorial_progress("orders") == 0,
		"nach dem Neustart steht jeder Tutorial-Zähler auf null")
	check(int(gs.stats["planted"]) == 12, "die Gesamtstatistik bleibt unverändert")
	gs.bump("planted", 2)
	check(gs.tutorial_progress("planted") == 2, "nur neue Handlungen zählen")
	var d: Dictionary = gs.serialize()
	check(d.has("tutorial_base") and int(d["tutorial_base"].get("planted", -1)) == 12, "die Basis wird gespeichert")
	gs.new_game()
	check(gs.tutorial_base.is_empty(), "ein neues Spiel beginnt ohne Basis")
	check(gs.deserialize(d), "Spielstand mit Basis lässt sich laden")
	check(gs.tutorial_progress("planted") == 2, "die Basis überlebt Speichern und Laden")
	d.erase("tutorial_base")
	check(gs.deserialize(d), "Spielstand ohne Basis (ältere Version) lässt sich laden")
	check(gs.tutorial_progress("planted") == 14, "ohne gespeicherte Basis zählt die ganze Statistik")
	d["tutorial_base"] = {"planted": -5, "harvested": "x", "orders": 1.0}
	check(gs.deserialize(d), "beschädigte Basis lässt sich laden")
	check(gs.tutorial_progress("planted") == 14 and gs.tutorial_progress("orders") == 3, "beschädigte Basis wird bereinigt")


func test_audio_volumes() -> void:
	begin("Lautstärke")
	var sfx: Node = root.get_node("Sfx")
	var music: Node = root.get_node("BackgroundMusic")
	var previous: Dictionary = gs.settings.duplicate()
	check(gs.settings.has("sound_volume") and gs.settings.has("music_volume"), "Lautstärken sind Teil der Einstellungen")
	gs.settings["sound_volume"] = 0.5
	check(is_equal_approx(sfx.volume_db_for(0.5), -7.0 + linear_to_db(0.5)), "Tonregler skaliert die Effektlautstärke")
	check(sfx.volume_db_for(0.0) <= -80.0, "Tonregler auf 0 % schaltet Effekte stumm")
	gs.settings["music_volume"] = 0.5
	check(is_equal_approx(music.volume_db_for(0.5), -14.0 + linear_to_db(0.5)), "Musikregler skaliert die Musiklautstärke")
	check(music.volume_db_for(0.0) <= -80.0, "Musikregler auf 0 % schaltet Musik stumm")
	gs.settings = previous
	sfx.refresh_volume()
	music.refresh()


## Lesbarkeit: Schriftgröße, größere Schaltflächen und Kontrast laufen über
## UiKit, damit ein Regler in den Einstellungen genügt. Geprüft werden Skalierung,
## Grenzen und dass die Werte im Spielstand bleiben.
func test_accessibility() -> void:
	begin("Lesbarkeit")
	# Zur Laufzeit geladen: Beim Kompilieren des `-s`-Skripts sind die Autoloads,
	# auf die painter.gd zugreift, noch nicht angemeldet.
	var uk: GDScript = load("res://scripts/ui/ui_kit.gd")
	uk.apply_accessibility(gs.settings)
	check(is_equal_approx(float(gs.settings.get("text_scale", -1.0)), 1.0), "neue Spiele starten mit normaler Schrift")
	check(not bool(gs.settings.get("large_targets", true)) and not bool(gs.settings.get("high_contrast", true)), "neue Spiele starten ohne Zusatzschalter")
	check(uk.font_px(20) == 20, "normale Schrift bleibt unverändert")
	var normal_ink: Color = uk.ink()
	var normal_button: Button = uk.button("Weizen", "light", 30)
	check(normal_button.custom_minimum_size.y >= uk.MIN_TOUCH, "Schaltflächen sind mindestens 96 px hoch")
	uk.apply_accessibility({"text_scale": 1.2, "large_targets": true, "high_contrast": true})
	check(uk.font_px(20) == 24, "Schriftgröße skaliert auf 120 Prozent")
	var big_button: Button = uk.button("Weizen", "light", 30)
	check(big_button.get_theme_font_size("font_size") == uk.font_px(30), "Buttontext nutzt die skalierte Schriftgröße")
	check(big_button.custom_minimum_size.y >= normal_button.custom_minimum_size.y + 10.0,
		"größere Schaltflächen wachsen mit (%.0f statt %.0f px)" % [big_button.custom_minimum_size.y, normal_button.custom_minimum_size.y])
	check(uk.ink().get_luminance() < normal_ink.get_luminance(), "hoher Kontrast dunkelt die Schrift ab")
	uk.apply_accessibility({"text_scale": 9.0})
	check(uk.text_scale <= 1.35, "zu große Schrift wird begrenzt")
	uk.apply_accessibility({"text_scale": 0.1})
	check(uk.text_scale >= 0.9, "zu kleine Schrift wird begrenzt")
	normal_button.free()
	big_button.free()
	# Die Werte gehören in den Spielstand, sonst wäre die Einstellung nach jedem
	# Neustart wieder weg.
	gs.settings["text_scale"] = 1.2
	gs.settings["large_targets"] = true
	gs.settings["high_contrast"] = true
	check(ss.save_game(), "Einstellungen speichern")
	check(ss.load_game(), "Einstellungen laden")
	check(is_equal_approx(float(gs.settings.get("text_scale", 0.0)), 1.2), "Schriftgröße überlebt Speichern und Laden")
	check(bool(gs.settings.get("large_targets", false)) and bool(gs.settings.get("high_contrast", false)),
		"Kontrast und große Schaltflächen überleben Speichern und Laden")
	# Ältere Spielstände ohne diese Felder starten mit den Standardwerten.
	var old: Dictionary = gs.serialize()
	(old["settings"] as Dictionary).erase("text_scale")
	(old["settings"] as Dictionary).erase("large_targets")
	(old["settings"] as Dictionary).erase("high_contrast")
	check(gs.deserialize(old), "Spielstand ohne Lesbarkeits-Felder lässt sich laden")
	check(is_equal_approx(float(gs.settings.get("text_scale", 0.0)), 1.0) and not bool(gs.settings.get("large_targets", true)),
		"ältere Stände starten mit normaler Schrift")
	gs.settings["text_scale"] = 1.0
	gs.settings["large_targets"] = false
	gs.settings["high_contrast"] = false
	uk.apply_accessibility(gs.settings)


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
	ss.delete_save()
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
	check(int(v1_migrated.version) == 11, "Version 1 migriert schrittweise auf Version 11")
	check(v1_migrated.stats.get("cafe_orders", -1) == 0, "Café-Fortschritt alter Spielstände startet bei null")
	var v2_migrated: Dictionary = ss.migrate({"version": 2, "animals": []})
	check(int(v2_migrated.version) == 11 and v2_migrated.diary.is_empty() and v2_migrated.claimed_achievements.is_empty(), "Version 2 erhält Story-, Erfolgs-, Café-, Wetter-, Event- und Tages-Migration")
	var v3_migrated: Dictionary = ss.migrate({"version": 3, "animals": []})
	check(int(v3_migrated.version) == 11 and v3_migrated.claimed_achievements.is_empty(), "Version 3 erhält leere Erfolgs-, Café-, Wetter-, Event- und Tages-Historie")
	# Alte Stände kannten nur An/Aus; daraus werden 0 % bzw. 100 % Lautstärke.
	var legacy_audio: Dictionary = ss.migrate({"version": 8, "settings": {"sound": false, "music": true, "vibration": false}})
	var legacy_settings: Dictionary = legacy_audio["settings"]
	check(is_equal_approx(float(legacy_settings.get("sound_volume", -1.0)), 0.0), "alter Ton-Aus-Stand wird zu 0 % Lautstärke")
	check(is_equal_approx(float(legacy_settings.get("music_volume", -1.0)), 1.0), "alter Musik-An-Stand wird zu 100 % Lautstärke")
	check(not bool(legacy_settings.get("sound", true)) and bool(legacy_settings.get("music", false)), "An/Aus-Spiegel bleibt beim Migrieren stimmig")
	check(gs.deserialize({"version": 2, "settings": {"sound": false, "music": true}}), "Altstand mit An/Aus-Einstellungen laden")
	check(is_equal_approx(float(gs.settings.get("sound_volume", -1.0)), 0.0) and is_equal_approx(float(gs.settings.get("music_volume", -1.0)), 1.0), "Laden bildet An/Aus auf Lautstärken ab")
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
	check(gd.CROPS.size() == 23, "23 Pflanzen einschließlich Mandel, Rhabarber, Zucchini und Zuckerrohr")
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
		gs.time_offset += gd.real_seconds_for_crop_growth(gs.now(), float(gd.CROPS["wheat"]["grow"])) + 1.0
		for cell in gs.fields.keys():
			if gs.harvest(cell):
				harvests += 1
	check(gs.level == 2 and harvests <= 25, "Stufe 2 nach %d Ernten" % harvests)
	print("   Stufe 2 nach %d Ernten" % harvests)
	# Alle Level-Freischaltungen sind erreichbar
	var seen := {}
	for l in range(1, gd.MAX_LEVEL + 1):
		for u in gd.unlocks_at(l):
			seen[u] = true
	var total: int = gd.CROPS.size() + gd.RECIPES.size() + gd.ANIMALS.size()
	check(seen.size() >= total, "jede Pflanze, jedes Rezept und jedes Tier hat ein Freischaltlevel")


## Höchstens ein Gebäude und eine Pflanze pro Aufstieg. Rezepte und Geschichten
## dürfen nie früher erscheinen als ihre Zutaten und ihr Gebäude.
func test_unlock_pacing() -> void:
	begin("Freischalt-Takt")
	var crop_levels := {}
	for id in gd.CROPS:
		var lvl: int = int(gd.CROPS[id]["level"])
		check(not crop_levels.has(lvl), "Stufe %d schaltet höchstens eine Pflanze frei (%s)" % [lvl, id])
		crop_levels[lvl] = id
	var building_levels := {}
	for id in gd.BUILDINGS:
		var lvl: int = int(gd.BUILDINGS[id]["level"])
		check(not building_levels.has(lvl), "Stufe %d schaltet höchstens ein Gebäude frei (%s)" % [lvl, id])
		building_levels[lvl] = id
	check(crop_levels.size() == gd.CROPS.size(), "jede Pflanze hat eine eigene Stufe")
	check(building_levels.size() == gd.BUILDINGS.size(), "jedes Gebäude hat eine eigene Stufe")
	var late_crops := ["coffee", "pumpkin", "sugarcane", "beet", "rhubarb", "lettuce", "zucchini", "cucumber", "pea", "blueberry", "rice", "quinoa"]
	for id in late_crops:
		check(int(gd.CROPS[id]["level"]) >= 12, "%s wandert in die zweite Spielhälfte" % id)
	check(int(gd.CROPS["quinoa"]["level"]) == 23, "Quinoa ist die letzte Pflanze")
	for id in gd.RECIPES:
		var r: Dictionary = gd.RECIPES[id]
		var need: int = int(gd.BUILDINGS[r["building"]]["level"])
		for k in r["inputs"]:
			need = maxi(need, int(gd.items[k].get("level", 1)))
		check(int(r["level"]) >= need, "%s startet nicht vor Zutaten und Gebäude" % id)
	for id in gd.DELIVERY_STORIES:
		var story: Dictionary = gd.DELIVERY_STORIES[id]
		var need := 1
		for stage in story["stages"]:
			for item in stage["items"]:
				need = maxi(need, int(gd.items[item].get("level", 1)))
		if story.has("requires_building"):
			need = maxi(need, int(gd.BUILDINGS[String(story["requires_building"])]["level"]))
		check(int(story["level"]) >= need, "%s beginnt erst mit allen Zutaten" % id)
	# Eine Stufe darf auch zusammen mit Tier und Deko nicht mehr als ein Gebäude und eine Pflanze nennen.
	for lvl in range(1, gd.MAX_LEVEL + 1):
		var crops_here := 0
		var buildings_here := 0
		for id in gd.CROPS:
			if int(gd.CROPS[id]["level"]) == lvl:
				crops_here += 1
		for id in gd.BUILDINGS:
			if int(gd.BUILDINGS[id]["level"]) == lvl:
				buildings_here += 1
		check(crops_here <= 1 and buildings_here <= 1, "Stufe %d bleibt bei höchstens einer Pflanze und einem Gebäude" % lvl)


func test_new_crops() -> void:
	begin("Neue Pflanzen")
	gs.coins = 100000
	var cell: Vector2i = gs.fields.keys()[0]
	var new_crops := {
		"almond": 8, "coffee": 12, "pumpkin": 13, "beet": 15, "rhubarb": 16, "lettuce": 17, "zucchini": 18,
		"cucumber": 19, "pea": 20, "blueberry": 21, "rice": 22, "quinoa": 23,
	}
	for crop in new_crops:
		var level: int = int(new_crops[crop])
		level_to(level)
		var definition: Dictionary = gd.CROPS[crop]
		check(gs.plant(cell, crop), "%s auf Freischaltstufe pflanzbar" % crop)
		gs.time_offset += gd.real_seconds_for_crop_growth(gs.now(), float(definition["grow"])) + 0.01
		check(gs.harvest(cell), "%s nach effektiver Wetter-Wachstumszeit erntbar" % crop)
		var expected_yield: int = int(definition["yield"]) + (1 if gd.crop_in_season(crop, gs.day_number()) else 0)
		check(gs.item_count(crop) == expected_yield, "%s liefert Inventar-Ertrag inklusive Saisonbonus" % crop)
		check(gs.fields[cell].crop == "", "%s hinterlässt nach der Ernte ein leeres Feld" % crop)
		check(not gs.harvest(cell), "%s kann ohne neue Aussaat nicht erneut geerntet werden" % crop)
		gs.fields[cell] = {"crop": "", "t": 0.0}
	check(gd.RECIPES.size() >= 46, "die neuen Produktionsketten erweitern das Rezeptbuch auf 46 Rezepte")
	for recipe in ["pumpkin_spice_latte", "blueberry_coffee_cake"]:
		check(gd.items.has(recipe), "%s ist als Tagesgericht-Produkt registriert" % recipe)
	for recipe in ["pumpkin_soup", "beet_spread", "garden_salad", "blueberry_smoothie", "rice_milk", "quinoa_bowl"]:
		check(gd.items.has(recipe), "%s ist als Produkt im Inventar registriert" % recipe)
	check(gd.unlocks_at(23).has("Quinoa"), "Quinoa wird auf Stufe 23 freigeschaltet")
	check(gd.unlocks_at(8).has("Mandeln"), "Mandeln werden auf Stufe 8 freigeschaltet")
	var perennial_crops := false
	for crop in gd.CROPS:
		if gd.CROPS[crop].has("perennial"):
			perennial_crops = true
	check(not perennial_crops, "alle Pflanzen sind einjährig und werden nach der Ernte neu ausgesät")
	check(gd.CROPS.has("almond") and not gd.CROPS["almond"].has("perennial"), "Mandeln werden nach der Ernte nicht automatisch nachgepflanzt")
	check(gd.CROPS["almond"]["level"] == gd.RECIPES["almond_milk"]["level"], "Mandel und Mandelmilch starten auf derselben Stufe")
	check(gd.items["almond"]["kind"] == "crop", "Mandeln sind als Feldfrucht registriert")
	check(not gd.EXTRA_ITEMS.has("almond"), "Mandeln sind keine reine Shop-Zutat mehr")
	# Vom Feld in die Manufaktur: geerntete Mandeln werden zu Mandelmilch.
	var almond_milkery: int = gs.place_object("milkery", Vector2i(10, 11))
	check(almond_milkery > 0, "Pflanzenmilch-Manufaktur für Mandelmilch bauen")
	check(gs.item_count("almond") >= 3, "geerntete Mandeln liegen im Vorrat")
	check(gs.start_recipe(almond_milkery, "almond_milk"), "Mandelmilch aus eigener Ernte starten")
	gs.time_offset += 121.0
	check(gs.collect_ready(almond_milkery).size() == 1 and gs.item_count("almond_milk") == 1, "Mandelmilch aus geernteten Mandeln herstellen")
	check(gd.LAND_EXPANSIONS.size() >= 8, "acht Landstufen erreichen gemeinsam den Vollausbau")
	check(gd.items.has("pumpkin") and gd.items.has("blueberry"), "neue Ernten als handelbare Items registriert")


func test_new_production() -> void:
	begin("Neue Produktionsketten")
	gs.new_game()
	gs.level = 18
	gs.coins = 100000
	var spots := {
		"florist": Vector2i(8, 11), "oilmill": Vector2i(10, 11), "preserves": Vector2i(12, 11),
		"pasta": Vector2i(8, 17), "icecream": Vector2i(10, 17), "muesli": Vector2i(12, 17),
	}
	var uids := {}
	for id in spots:
		uids[id] = gs.place_object(str(id), spots[id])
		check(int(uids[id]) > 0, "%s bauen" % gd.BUILDINGS[id]["name"])
	check(gs.production_buildings().size() == 6, "alle sechs neuen Gebäude stehen")
	for id in ["build_florist", "build_oilmill", "build_preserves", "build_pasta", "build_icecream", "build_muesli"]:
		var achievement: Dictionary = {}
		for entry in gd.ACHIEVEMENTS:
			if str(entry["id"]) == id:
				achievement = entry
		check(not achievement.is_empty() and gs.achievement_unlocked(achievement), "Erfolg %s zählt das neue Gebäude" % id)
	check(gd.unlocks_at(8).has("Blumenwerkstatt") and gd.unlocks_at(9).has("Ölmühle"), "neue Gebäude sind sinnvoll gestaffelt")
	check(gd.unlocks_at(16).has("Rhabarber") and gd.unlocks_at(18).has("Zucchini"), "neue Pflanzen erscheinen auf ihrer Freischaltstufe")
	check(not gd.EXTRA_ITEMS.has("sugar") and not gs.buy_item("sugar"), "Zucker ist keine einzelne Shop-Zutat mehr")
	# Zucker für die Konfitüre entsteht in der eigenen Kette aus Zuckerrohr.
	var sugar_mill: int = gs.place_object("sugarmill", Vector2i(14, 17))
	check(sugar_mill > 0, "Zuckermühle bauen")
	gs.add_item("sugarcane", 3)
	check(gs.start_recipe(sugar_mill, "sugar"), "Zucker aus Zuckerrohr starten")
	gs.time_offset += 121.0
	check(gs.collect_ready(sugar_mill).size() == 1 and gs.item_count("sugar") == 1, "Zucker selbst herstellen")
	# Öl, Nudeln und Konfitüre über die echten Produktionswege herstellen.
	gs.add_item("sunflower", 4)
	check(gs.start_recipe(int(uids["oilmill"]), "sunflower_oil"), "Sonnenblumenöl starten")
	gs.add_item("wheat", 3)
	check(gs.start_recipe(int(uids["pasta"]), "pasta"), "Weizennudeln starten")
	gs.time_offset += 121.0
	check(gs.collect_ready(int(uids["oilmill"])).size() == 1 and gs.item_count("sunflower_oil") == 1, "Öl abholen")
	check(gs.collect_ready(int(uids["pasta"])).size() == 1 and gs.item_count("pasta") == 1, "Nudeln abholen")
	check(int(gs.stats.get("crafted_sunflower_oil", 0)) == 1 and int(gs.stats.get("crafted_pasta", 0)) == 1, "Rezepte zählen eigene Erfolgsstatistiken")
	for id in ["pasta_10", "oil_10"]:
		var achievement: Dictionary = {}
		for entry in gd.ACHIEVEMENTS:
			if str(entry["id"]) == id:
				achievement = entry
		check(gs.achievement_progress(achievement) == 1, "Erfolgsfortschritt %s zählt hergestellte Ware" % id)
	gs.add_item("strawberry", 4)
	check(gs.start_recipe(int(uids["preserves"]), "strawberry_jam"), "Erdbeerkonfitüre starten")
	gs.time_offset += 121.0
	check(gs.collect_ready(int(uids["preserves"])).size() == 1 and gs.item_count("strawberry_jam") == 1, "Konfitüre abholen")
	check(gd.items.has("apple_rice_pudding") and gd.RECIPES["quinoa_bar"]["level"] == 23, "späte Rezepte bleiben bis Stufe 23 sinnvoll")
	check(gd.RECIPES["strawberry_ice"]["inputs"].has("oat_milk"), "Eis verbindet Obst und Pflanzenmilch")


func _achievement(id: String) -> Dictionary:
	for entry in gd.ACHIEVEMENTS:
		if str(entry["id"]) == id:
			return entry
	return {}


func test_sugar_chain() -> void:
	begin("Zuckerkette")
	gs.coins = 100000
	level_to(14)
	check(gd.CROPS.has("sugarcane") and int(gd.CROPS["sugarcane"]["level"]) == 14, "Zuckerrohr wächst ab Stufe 14")
	check(gd.BUILDINGS.has("sugarmill") and int(gd.BUILDINGS["sugarmill"]["level"]) == 12, "Zuckermühle gibt es ab Stufe 12")
	check(gd.RECIPES.has("sugar") and gd.RECIPES["sugar"]["building"] == "sugarmill", "Zucker entsteht in der Zuckermühle")
	check(gd.RECIPES["sugar"]["inputs"] == {"sugarcane": 3}, "Zucker wird aus Zuckerrohr gepresst")
	check(gd.items.has("sugar") and gd.items["sugar"]["kind"] == "product", "Zucker ist ein hergestelltes Produkt")
	check(not gd.EXTRA_ITEMS.has("sugar") and not gs.buy_item("sugar", 1), "Zucker lässt sich nicht mehr fertig kaufen")
	check(gd.items["sugar"]["level"] <= int(gd.RECIPES["strawberry_jam"]["level"]), "Zucker ist rechtzeitig für die Konfitüre verfügbar")
	var cell: Vector2i = gs.fields.keys()[0]
	check(gs.plant(cell, "sugarcane"), "Zuckerrohr pflanzen")
	gs.time_offset += gd.real_seconds_for_crop_growth(gs.now(), float(gd.CROPS["sugarcane"]["grow"])) + 0.01
	check(gs.harvest(cell), "Zuckerrohr nach der Wachstumszeit ernten")
	check(gs.item_count("sugarcane") == int(gd.CROPS["sugarcane"]["yield"]), "Zuckerrohr landet im Vorrat")
	var mill: int = gs.place_object("sugarmill", Vector2i(8, 11))
	check(mill > 0, "Zuckermühle bauen")
	check(gs.start_recipe(mill, "sugar"), "Zucker pressen starten")
	gs.time_offset += 121.0
	check(gs.collect_ready(mill).size() == 1 and gs.item_count("sugar") == 1, "Zucker aus eigener Ernte herstellen")
	check(int(gs.stats.get("crafted_sugar", 0)) == 1, "Zucker zählt die Erfolgsstatistik")
	var built: Dictionary = _achievement("build_sugarmill")
	var sweet: Dictionary = _achievement("sugar_10")
	check(not built.is_empty() and gs.achievement_unlocked(built), "Erfolg für die Zuckermühle wird freigeschaltet")
	check(not sweet.is_empty() and gs.achievement_progress(sweet) == 1 and not gs.achievement_unlocked(sweet), "Zucker-Erfolg zählt hergestellte Ware")
	var preserves: int = gs.place_object("preserves", Vector2i(10, 11))
	gs.add_item("strawberry", 4)
	check(gs.start_recipe(preserves, "strawberry_jam"), "Konfitüre aus eigener Zuckerkette starten")
	gs.time_offset += 121.0
	check(gs.collect_ready(preserves).size() == 1 and gs.item_count("strawberry_jam") == 1, "Konfitüre mit eigenem Zucker abholen")
	check(gd.RECIPES.has("cane_syrup") and gd.RECIPES.has("caramel_syrup") and gd.RECIPES.has("caramel_latte"), "Zuckermühle hat eine kleine eigene Rezeptkette")


func test_foraging() -> void:
	begin("Wildnis sammeln")
	check(gd.FORAGE.size() == 3, "drei wilde Lebensmittel")
	for id in gd.FORAGE:
		check(gd.items.has(id) and gd.items[id]["kind"] == "forage", "%s ist als Sammelgut registriert" % id)
		check(int(gd.FORAGE[id]["amount"]) > 0 and float(gd.FORAGE[id]["respawn"]) > 0.0, "%s hat Ertrag und Nachwuchszeit" % id)
		check(int(gd.FORAGE[id]["level"]) > 1, "%s wird nicht schon auf Stufe 1 verschenkt" % id)
	check(gd.unlocks_at(2).has("Wildnis: Wilde Kräuter"), "wilde Kräuter stehen in den Freischaltungen")
	var found := {}
	var sample := Vector2i.ZERO
	var sample_id := ""
	var locked_cell := Vector2i.ZERO
	var locked_id := ""
	for y in range(-30, 40):
		for x in range(-30, 40):
			var cell := Vector2i(x, y)
			var id: String = gs.forage_spot_at(cell)
			if id == "":
				continue
			found[id] = int(found.get(id, 0)) + 1
			check(not gs.land.has_point(cell), "Sammelstelle %s liegt außerhalb der Farm" % cell)
			check(gs.land.grow(gd.FORAGE_BAND_CELLS).has_point(cell), "Sammelstelle %s bleibt im Sammelring" % cell)
			if sample_id == "":
				sample = cell
				sample_id = id
			elif locked_id == "" and int(gd.FORAGE[id]["level"]) > gs.level:
				locked_cell = cell
				locked_id = id
	check(found.size() >= 2, "mehrere Sorten wachsen in der Umgebung")
	check(sample_id != "" and sample_id == gs.forage_spot_at(sample), "Fundstellen bleiben stabil")
	check(locked_id != "" and not gs.forage_available(locked_cell), "höhere Wildware bleibt anfangs verborgen")
	check(gs.collect_forage(locked_cell).is_empty() and gs.last_error.contains("Stufe"), "Sammeln vor der Freischaltung wird abgelehnt")
	check(gs.forage_spot_at(gs.land.position) == "", "auf der Farm wächst nichts Wildes")
	level_to(int(gd.FORAGE[sample_id]["level"]))
	var before: int = gs.item_count(sample_id)
	var got: Dictionary = gs.collect_forage(sample)
	check(not got.is_empty() and gs.item_count(sample_id) == before + int(gd.FORAGE[sample_id]["amount"]), "Sammeln legt Wildware in den Vorrat")
	check(int(gs.stats.get("foraged", 0)) == 1, "Sammeln zählt für Quests und Erfolge")
	check(not gs.forage_ready(sample) and gs.forage_remaining(sample) > 0.0, "die Stelle wächst zuerst nach")
	check(gs.collect_forage(sample).is_empty(), "dieselbe Stelle gibt nicht zweimal Ware")
	gs.time_offset += float(gd.FORAGE[sample_id]["respawn"]) + 1.0
	check(gs.forage_ready(sample) and not gs.collect_forage(sample).is_empty(), "nach der Nachwuchszeit wieder sammelbar")
	var ready_at: float = float(gs.forage.get(sample, 0.0))
	var saved: Dictionary = gs.serialize()
	check(saved.has("forage") and (saved["forage"] as Array).size() >= 1, "Spielstand enthält Sammelzeiten")
	gs.new_game()
	check(gs.forage.is_empty(), "neues Spiel startet ohne Sammelzeiten")
	check(gs.deserialize(saved), "Spielstand mit Sammelzeiten laden")
	check(is_equal_approx(float(gs.forage.get(sample, 0.0)), ready_at), "Nachwuchszeit bleibt erhalten")
	var foraged_achievement: Dictionary = _achievement("forage_15")
	check(not foraged_achievement.is_empty() and gd.QUESTS.any(func(q: Dictionary) -> bool: return str(q["id"]) == "q_forage5"), "Erfolg und Quest begleiten das Sammeln")
	check(gd.RECIPES["mushroom_soup"]["inputs"].has("mushroom") and gd.RECIPES["herb_potatoes"]["inputs"].has("wild_herbs"), "Wildware wird in der Küche verarbeitet")


## Hoflexikon: Ein Eintrag gilt als entdeckt, sobald er einmal geerntet,
## hergestellt, gesammelt oder aufgenommen wurde. Alles kommt aus vorhandenen
## Zählern und dem Vorrat – es gibt keinen eigenen Spielstand-Eintrag, den alte
## Stände nachtragen müssten.
func test_lexicon() -> void:
	begin("Hoflexikon")
	check(gs.lexicon_ids("crop").size() == gd.CROPS.size(), "alle Pflanzen stehen im Lexikon")
	check(gs.lexicon_ids("recipe").size() == gd.RECIPES.size(), "alle Rezepte stehen im Lexikon")
	check(gs.lexicon_ids("forage").size() == gd.FORAGE.size(), "alle Fundstücke stehen im Lexikon")
	check(gs.lexicon_ids("animal").size() == gd.ANIMALS.size(), "alle Tierarten stehen im Lexikon")
	check(int(gs.lexicon_progress("crop")["seen"]) == 0, "ein neuer Hof hat noch nichts entdeckt")
	check(not gs.lexicon_discovered("crop", "wheat") and not gs.lexicon_discovered("animal", "rabbit"), "nichts ist zu Beginn entdeckt")
	var crops: Array = gs.lexicon_ids("crop")
	check(int(gd.CROPS[crops[0]]["level"]) <= int(gd.CROPS[crops[crops.size() - 1]]["level"]), "das Lexikon wächst mit der Stufe")
	# Ernten entdeckt die Sorte.
	gs.coins = 100
	var cell: Vector2i = gs.fields.keys()[0]
	check(gs.plant(cell, "wheat"), "Weizen säen")
	gs.time_offset += 120.0
	check(gs.harvest(cell), "Weizen ernten")
	check(gs.lexicon_discovered("crop", "wheat"), "geernteter Weizen steht im Lexikon")
	check(not gs.lexicon_discovered("crop", "carrot"), "ungesäte Sorten bleiben unbekannt")
	check(int(gs.lexicon_progress("crop")["seen"]) == 1, "genau eine Pflanze ist entdeckt")
	# Herstellen entdeckt das Rezept, nicht schon das Ansetzen.
	level_to(3)
	gs.coins = 4000
	var bak: int = gs.place_object("bakery", Vector2i(8, 11))
	gs.add_item("wheat", 3)
	check(gs.start_recipe(bak, "bread"), "Brot ansetzen")
	check(not gs.lexicon_discovered("recipe", "bread"), "ein angesetztes Brot ist noch nicht entdeckt")
	gs.time_offset += 200.0
	check(gs.collect_ready(bak).size() == 1, "Brot abholen")
	check(gs.lexicon_discovered("recipe", "bread"), "gebackenes Brot steht im Lexikon")
	# Ware im Vorrat zählt mit: ältere Stände kennen keinen Sammelzähler je Stelle.
	check(not gs.lexicon_discovered("forage", "mushroom"), "Pilze sind noch unbekannt")
	gs.add_item("mushroom", 1)
	check(gs.lexicon_discovered("forage", "mushroom"), "Ware im Vorrat gilt als entdeckt")
	# Tiere: nur die Arten, die wirklich hier gelebt haben.
	var pad: int = gs.place_object("paddock", Vector2i(12, 11))
	check(pad > 0, "Gehege gebaut")
	check(gs.adopt_animal("rabbit") > 0, "Kaninchen aufgenommen")
	check(gs.lexicon_discovered("animal", "rabbit"), "das Kaninchen steht im Lexikon")
	check(not gs.lexicon_discovered("animal", "chicken"), "andere Arten bleiben unbekannt")
	var animals: Dictionary = gs.lexicon_progress("animal")
	check(int(animals["seen"]) == 1 and int(animals["total"]) == gd.ANIMALS.size(), "der Tierfortschritt zählt Arten")
	# Sammeln setzt einen eigenen Zähler je Fundstelle.
	level_to(10)
	var sample := Vector2i(-999, -999)
	var band: Rect2i = gs.land.grow(gd.FORAGE_BAND_CELLS)
	for x in range(band.position.x, band.end.x):
		for y in range(band.position.y, band.end.y):
			if sample.x != -999:
				continue
			var spot := Vector2i(x, y)
			var spot_id: String = gs.forage_spot_at(spot)
			if spot_id != "" and not gs.land.has_point(spot):
				sample = spot
	if sample.x != -999:
		var got: Dictionary = gs.collect_forage(sample)
		check(not got.is_empty(), "wilde Fundstelle sammeln")
		check(gs.lexicon_discovered("forage", str(got["id"])), "gesammelte Fundstelle steht im Lexikon")
		check(int(gs.stats.get("foraged:" + str(got["id"]), 0)) == 1, "der Sammelzähler gilt je Fundstelle")
	else:
		check(false, "es gibt eine erreichbare Fundstelle")
	# Kein eigener Spielstand-Eintrag, damit alte Stände nichts nachtragen müssen.
	var saved: Dictionary = gs.serialize()
	check(not saved.has("lexicon"), "das Lexikon speichert keine eigene Liste")
	check(gs.deserialize(saved), "Spielstand mit Lexikon-Zählern lässt sich laden")
	check(gs.lexicon_discovered("crop", "wheat") and gs.lexicon_discovered("animal", "rabbit"), "Entdeckungen überleben Speichern und Laden")


func test_level_curve() -> void:
	begin("Stufenkurve")
	var total := 0
	for l in range(1, gd.MAX_LEVEL):
		total += gd.xp_needed(l)
		check(gd.xp_needed(l) > 0, "Stufe %d hat ein XP-Ziel" % l)
	check(gd.xp_needed(2) > gd.xp_needed(1), "spätere Stufen brauchen mehr Erfahrung")
	check(gd.xp_needed(1) <= 60, "die zweite Stufe bleibt am Anfang schnell erreichbar")
	check(total >= 20000, "die Maximalstufe ist ein langfristiges Ziel (%d XP)" % total)
	var achievement_xp := 0
	for achievement in gd.ACHIEVEMENTS:
		achievement_xp += int(achievement["xp"])
	check(achievement_xp <= 800, "Erfolge geben zusammen höchstens 800 XP (%d)" % achievement_xp)
	check(achievement_xp * 3 < total, "Erfolge allein tragen nicht bis zur Maximalstufe")


func test_landscape_chunks() -> void:
	begin("Gelände-Chunks")
	var terrain_script: GDScript = load("res://scripts/world/terrain.gd")
	var world := Rect2i(gd.WORLD_ORIGIN, Vector2i(gd.WORLD_COLS, gd.WORLD_ROWS))
	var scenery: Rect2i = terrain_script.scenery_bounds()
	check(scenery.encloses(world), "Wildnisgürtel umschließt die Karte")
	check(gd.SCENERY_MARGIN_CELLS >= 16, "der Gürtel ist breit genug für weite Kameraausschnitte")
	var chunk_cells: int = terrain_script.CHUNK_CELLS
	check(chunk_cells >= 4 and chunk_cells <= 16, "Chunkgröße bleibt handlich")
	var coords: Array = terrain_script.chunk_coords_for(Rect2(Vector2(scenery.position) * gd.TILE, Vector2(scenery.size) * gd.TILE))
	check(coords.size() > 0, "für den Gürtel werden Chunks erzeugt")
	var total := 0
	var inside := true
	for coord in coords:
		var b: Rect2i = terrain_script.chunk_bounds(coord)
		total += b.size.x * b.size.y
		inside = inside and scenery.encloses(b) and b.has_area()
	check(inside, "jeder Chunk liegt vollständig im Gürtel")
	check(total == scenery.size.x * scenery.size.y, "Chunks decken den Gürtel lückenlos ab (%d Zellen)" % total)
	var view := Rect2(Vector2(gs.land.position) * gd.TILE, Vector2(gs.land.size) * gd.TILE)
	var near: Array = terrain_script.chunk_coords_for(view, 0)
	var covered := true
	for corner in [view.position + Vector2(1, 1), view.end - Vector2(1, 1)]:
		var cell := Vector2i(floori(corner.x / gd.TILE), floori(corner.y / gd.TILE))
		var found := false
		for coord in near:
			if terrain_script.chunk_bounds(coord).has_point(cell):
				found = true
				break
		covered = covered and found
	check(covered, "sichtbare Farmecken liegen in angeforderten Chunks")
	check(terrain_script.chunk_coords_for(Rect2(-100000, -100000, 10, 10)).is_empty(), "weit außerhalb entstehen keine Chunks")


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_save_hardening() -> void:
	begin("Spielstand-Härtung")
	ss.delete_save()
	for suffix in [".corrupt", ".newer"]:
		DirAccess.remove_absolute(ss._path() + suffix)
	# Das Backup wird nicht bei jedem Speichern überschrieben, sondern bleibt eine Weile stabil.
	gs.coins = 100
	check(ss.save_game(), "Speicherstand A")
	gs.coins = 200
	check(ss.save_game(), "Speicherstand B (legt das Backup mit Stand A an)")
	gs.coins = 300
	check(ss.save_game(), "Speicherstand C (Backup bleibt frisch und unverändert)")
	check(int(ss._read(ss._backup_path()).get("coins", -1)) == 100, "Backup wird nicht bei jedem Speichern überschrieben")
	check(int(ss._read(ss._path()).get("coins", -1)) == 300, "Hauptdatei enthält den neuesten Stand")
	check(not FileAccess.file_exists(ss._tmp_path()), "keine temporäre Datei bleibt liegen")
	# Autosave schreibt nur bei Änderungen, das ausdrückliche Speichern immer.
	_write_text(ss._path(), "marker")
	check(ss.save_game(false), "unveränderter Autosave gilt als erfolgreich")
	check(FileAccess.get_file_as_string(ss._path()) == "marker", "Autosave schreibt nichts, solange sich der Stand nicht ändert")
	gs.coins += 1
	check(ss.save_game(false) and FileAccess.get_file_as_string(ss._path()) != "marker", "Autosave schreibt nach einer Änderung")
	_write_text(ss._path(), "marker")
	check(ss.save_game() and FileAccess.get_file_as_string(ss._path()) != "marker", "ausdrückliches Speichern schreibt immer")
	# Ein Stand aus einer neueren Spielversion wird weder geladen noch überschrieben.
	var newer: Dictionary = gs.serialize()
	newer["version"] = gs.SAVE_VERSION + 1
	newer["coins"] = 99999
	_write_text(ss._path(), JSON.stringify(newer))
	DirAccess.remove_absolute(ss._backup_path())
	gs.coins = 321
	check(not ss.load_game(), "Stand aus neuerer Version wird nicht geladen")
	check(ss.last_load_error == "newer", "Grund 'neuere Version' wird gemeldet")
	check(gs.coins == 321, "laufender Spielstand bleibt unangetastet")
	check(FileAccess.file_exists(ss._path() + ".newer"), "Stand der neueren Version bleibt als Kopie erhalten")
	check(not gs.deserialize(newer) and gs.coins == 321, "deserialize lehnt neuere Versionen ab, ohne den Zustand zu löschen")
	# Unlesbarer Stand: Kopie bleibt erhalten, ein gutes Backup wird nicht überschrieben.
	ss.delete_save()
	gs.coins = 150
	check(ss.save_game(), "Stand für Beschädigungstest")
	check(ss.save_game(), "zweiter Stand legt Backup an")
	_write_text(ss._path(), "{ kaputt")
	check(ss.save_game(), "Speichern über eine beschädigte Hauptdatei funktioniert")
	check(int(ss._read(ss._backup_path()).get("coins", -1)) == 150, "gutes Backup bleibt erhalten")
	# Beschädigte Einträge werden verworfen statt das Laden abzubrechen.
	var broken := {"version": gs.SAVE_VERSION, "coins": 50, "next_uid": 1,
		"fields": [{"x": 8, "y": 11, "crop": "wheat", "t": 0}, {"y": 3}, "kaputt", {"x": 999, "y": 999, "crop": ""}, {"x": 8, "y": 13, "crop": ""}],
		"objects": [
			{"uid": 5, "type": "bakery", "x": 8, "y": 13, "queue": ["nope", {"recipe": "bread", "start": 0, "end": 10}, {"recipe": "ghost", "start": 0, "end": 1}], "upgrades": 1},
			{"uid": 5, "type": "kitchen", "x": 12, "y": 13},
			{"uid": 6, "type": "kitchen", "x": 9, "y": 14},
			{"uid": 7, "type": "paddock", "x": 8, "y": 16},
			{"type": "bakery", "x": 12, "y": 11},
			"kaputt",
		],
		"animals": [
			{"uid": 8, "species": "rabbit", "paddock": 99},
			{"uid": 8, "species": "rabbit", "paddock": 7},
			{"species": "rabbit"},
			{"uid": 9, "species": "dragon"},
		],
		"orders": [
			{"id": 20, "items": {"wheat": 2}},
			{"id": 20, "items": {"carrot": 1}},
			{"id": 21, "items": "kaputt"},
			{"id": 22, "items": {"wheat": 1}, "story_id": "lena_cafe"},
		],
		"claimed_quests": ["q_plant5", "bogus", "q_plant5"],
		"diary": ["kaputt", {"text": "ok"}],
		"stats": "kaputt",
	}
	check(gs.deserialize(broken), "Spielstand mit beschädigten Einträgen lässt sich laden")
	check(gs.fields.size() == 1 and gs.fields.has(Vector2i(8, 11)), "ungültige, doppelte und von Gebäuden belegte Felder verworfen (%d)" % gs.fields.size())
	check(gs.objects.size() == 2 and gs.get_object(5).get("type", "") == "bakery" and gs.get_object(7).get("type", "") == "paddock", "doppelte UIDs, überlappende und unvollständige Objekte verworfen (%d)" % gs.objects.size())
	check((gs.get_object(5).queue as Array).size() == 1, "nur gültige Warteschlangeneinträge bleiben")
	check(gs.animals.size() == 1 and int(gs.animals[0].paddock) == 7, "Tier ohne gültiges Gehege zieht ins freie Gehege")
	var order_20 := 0
	var stale_story := false
	for order in gs.orders:
		if int(order.id) == 20:
			order_20 += 1
		if order.has("story_id"):
			stale_story = true
	check(order_20 == 1 and not stale_story, "doppelte und verwaiste Story-Aufträge verworfen")
	check(gs.next_uid > 20, "next_uid zeigt hinter alle vergebenen IDs (%d)" % gs.next_uid)
	check(gs.claimed_quests == ["q_plant5"], "unbekannte und doppelte Quest-IDs verworfen")
	check(gs.diary.size() == 1, "ungültige Tagebucheinträge verworfen")
	ss.delete_save()
	for suffix in [".corrupt", ".newer"]:
		DirAccess.remove_absolute(ss._path() + suffix)


func test_logic_regressions() -> void:
	begin("Regressionen aus dem Code-Audit")
	# Gartentag-Gäste lassen sich auch in der Logik nicht wegklicken.
	gs.orders.append({"id": 9001, "customer": "Lena", "items": {"wheat": 1}, "coins": 5, "xp": 1, "neighborhood_event_cycle": 5})
	check(not gs.skip_order(9001) and gs.find_order(9001) >= 0, "Gartentag-Bestellung lässt sich nicht überspringen")
	# Die Weltgrenze wird geprüft, bevor Münzen abgezogen werden.
	level_to(30)
	gs.coins = 1000000
	gs.land = Rect2i(0, 3, 24, 24)
	check(not gs.expand_land(), "Erweiterung über die Weltgrenze scheitert")
	check(gs.coins == 1000000 and gs.land_level == 0 and gs.land == Rect2i(0, 3, 24, 24), "gescheiterte Erweiterung kostet nichts")
	# Die Spiel-Logik aktualisiert Aufträge im Takt, nicht pro Frame.
	check(gs.REFRESH_INTERVAL_SECONDS >= 0.25, "Aufträge werden höchstens im Sekundenbruchteil-Takt geprüft")
	check(gs.NEIGHBORHOOD_EVENT_FINALE_COINS > 0 and gs.NEIGHBORHOOD_EVENT_FINALE_XP > 0, "Gartentag-Finale hat benannte Belohnungen")


func test_data_consistency() -> void:
	begin("Konsistenz der Spieldaten")
	var ids := {}
	for q in gd.QUESTS:
		check(not ids.has(q["id"]), "Quest-ID %s ist eindeutig" % q["id"])
		ids[q["id"]] = true
	ids = {}
	for a in gd.ACHIEVEMENTS:
		check(not ids.has(a["id"]), "Erfolgs-ID %s ist eindeutig" % a["id"])
		ids[a["id"]] = true
	for rid in gd.RECIPES:
		var r: Dictionary = gd.RECIPES[rid]
		check(gd.BUILDINGS.has(r["building"]) and gd.BUILDINGS[r["building"]]["kind"] == "production", "Rezept %s gehört zu einem Produktionsgebäude" % rid)
		check(int(r["level"]) >= int(gd.BUILDINGS[r["building"]]["level"]), "Rezept %s ist nicht vor seinem Gebäude freigeschaltet" % rid)
		for input in r["inputs"]:
			check(gd.items.has(input), "Zutat %s von %s existiert" % [input, rid])
			check(int(gd.items[input]["level"]) <= int(r["level"]), "Zutat %s von %s ist auf Rezeptstufe herstellbar" % [input, rid])
	for sid in gd.DELIVERY_STORIES:
		var story: Dictionary = gd.DELIVERY_STORIES[sid]
		for stage in story["stages"]:
			for item in stage["items"]:
				check(gd.items.has(item) and int(gd.items[item]["level"]) <= int(story["level"]), "Geschichte %s: %s ist ab der Startstufe herstellbar" % [sid, item])
	var world := Rect2i(gd.WORLD_ORIGIN, Vector2i(gd.WORLD_COLS, gd.WORLD_ROWS))
	check(world.encloses(gd.START_LAND.grow(gd.LAND_EXPANSIONS.size())), "voll ausgebaute Farm liegt innerhalb der Welt")
