extends RefCounted
## Kosmetische Tierreaktionen auf Wetter und Nacht; alle Zustände sind flüchtig.

var _tests
var _root: Window
var _world_script: GDScript
var _game_state: Node
var _game_data: Node


func run(test_runner, world_script: GDScript, game_state: Node, game_data: Node) -> void:
	_tests = test_runner
	_root = test_runner.root
	_world_script = world_script
	_game_state = game_state
	_game_data = game_data
	test_time_helpers()
	test_animal_ambience()


func _check(condition: bool, message: String) -> void:
	_tests.check(condition, message)


func _near(a: Vector2, b: Vector2, tolerance: float = 0.01) -> bool:
	return a.distance_to(b) <= tolerance


func test_time_helpers() -> void:
	_check(not _world_script.is_night_at(6.0 * 3600.0), "06:00 ist Tageszeit")
	_check(_world_script.is_night_at(18.0 * 3600.0), "18:00 beginnt die Nacht")
	_check(_world_script.is_night_at(5.999 * 3600.0), "05:59 liegt in der Nacht")
	_check(not _world_script.is_night_at(6.001 * 3600.0), "06:01 liegt am Tag")
	_check(_game_data.seconds_into_weather(365.0) == 5.0, "Phasenzeit zählt ab dem Wetterwechsel")
	_check(_game_data.rainbow_strength_at(359.0) == 0.0, "Regen erzeugt keinen Regenbogen")
	_check(_game_data.rainbow_strength_at(360.0) == 0.0, "Regenbogen startet am Nebelbeginn unsichtbar")
	_check(_game_data.rainbow_strength_at(362.0) == 1.0, "Regenbogen blendet in zwei Sekunden ein")
	_check(_game_data.rainbow_strength_at(370.0) == 1.0, "Regenbogen bleibt während der Nebelphase sichtbar")
	_check(_game_data.rainbow_strength_at(373.0) == 1.0, "Regenbogen blendet in der Schlussphase aus")
	_check(_game_data.rainbow_strength_at(375.0) == 0.0, "Regenbogen ist nach 15 Sekunden verschwunden")
	_check(_game_data.rainbow_strength_at(362.0, true) == 0.0, "Regenbogen bleibt nachts unsichtbar")


func test_animal_ambience() -> void:
	var original_offset: float = _game_state.time_offset
	_game_state.new_game()
	_game_state.level = 8
	_game_state.coins = 5000
	var paddock_uid: int = _game_state.place_object("paddock", Vector2i(8, 11))
	_check(paddock_uid > 0, "Testgehege wird angelegt")
	var animal_uids: Array[int] = []
	for species in ["rabbit", "chicken", "cow"]:
		var uid: int = _game_state.adopt_animal(species)
		animal_uids.append(uid)
	_check(animal_uids.all(func(uid: int) -> bool: return uid > 0), "drei Tiere für alle Gehegeplätze werden aufgenommen")
	var animal_nodes: Array[Node2D] = []
	var paddock: Dictionary = _game_state.get_object(paddock_uid)
	for uid in animal_uids:
		var animal := load("res://scenes/animal.tscn").instantiate() as Node2D
		_root.add_child(animal)
		animal.setup(_game_state.get_animal(uid), paddock)
		animal.set_ambient("Sonnig", false, 12.0 * 3600.0)
		animal.position = Vector2(animal.bounds.position.x + 20.0, animal.bounds.end.y - 15.0)
		animal.set_ambient("Regen", false, 12.0 * 3600.0)
		animal_nodes.append(animal)
	_check(_game_state.SAVE_VERSION == 9, "Save-Version 9 bleibt unverändert")
	var all_in_shelter := true
	var shelter_slots: Array[int] = []
	for animal in animal_nodes:
		all_in_shelter = all_in_shelter and bool(animal.get("sheltering"))
		shelter_slots.append(int(animal.get("shelter_slot")))
	_check(all_in_shelter, "Tiere erhalten bei Regen einen Unterstandsplatz")
	_check(shelter_slots.size() == 3 and shelter_slots[0] != shelter_slots[1] and shelter_slots[0] != shelter_slots[2] and shelter_slots[1] != shelter_slots[2], "Unterstandsplätze sind pro Gehege eindeutig")
	for animal in animal_nodes:
		var bounds: Rect2 = animal.get("bounds")
		var target: Vector2 = animal.get("ambient_target")
		_check(bounds.has_point(target), "Unterstandsplatz liegt innerhalb des Geheges")
		for other in animal_nodes:
			if animal != other:
				_check(target.distance_to(other.get("ambient_target")) >= 1.0, "Unterstandsplätze überlappen nicht")
	var save_before: Dictionary = _game_state.serialize()
	for animal in animal_nodes:
		_check(not save_before.has("ambient_state") and not save_before.has("sleeping") and not save_before.has("sheltering"), "Ambient-Status wird nicht gespeichert")
		for i in range(600):
			animal._process(0.05)
		_check(_near(animal.position, animal.get("ambient_target"), 0.1), "Tier erreicht den Unterstand bei Regen")
	var before_night: Dictionary = _game_state.serialize()
	var night_day_seconds := 18.0 * 3600.0
	var sleepers: Array[Node2D] = []
	var awake_animals: Array[Node2D] = []
	for animal in animal_nodes:
		animal.set_ambient("Sonnig", true, night_day_seconds)
		_check(bool(animal.get("sheltering")), "nachts gehen alle Tiere in den Unterstand")
		_check(not bool(animal.get("walking")), "Unterstandsplätze sind erreicht, bevor das Tier ruht")
		if bool(animal.get("sleeping")):
			sleepers.append(animal)
		else:
			awake_animals.append(animal)
	_check(sleepers.size() == 2 and awake_animals.size() == 1, "versetzte Schlafzeiten lassen nachts mindestens ein Tier wach")
	var animal_to_wake := sleepers[0]
	var uid_to_wake := int(animal_to_wake.get("uid"))
	var stats_before: Dictionary = _game_state.stats.duplicate(true)
	var coins_before: int = _game_state.coins
	var inventory_before: Dictionary = _game_state.inventory.duplicate(true)
	var hearts_before: int = int(_game_state.get_animal(uid_to_wake).hearts)
	animal_to_wake.petted()
	_check(not bool(animal_to_wake.get("sleeping")), "Streicheln weckt das Tier")
	_check(float(animal_to_wake.get("sleep_wake_timer")) > 0.0, "Aufwachen ist ein kurzer visueller Zustand")
	_check(_game_state.stats == stats_before and _game_state.coins == coins_before and _game_state.inventory == inventory_before and int(_game_state.get_animal(uid_to_wake).hearts) == hearts_before, "kosmetisches Wecken ändert keine Werte oder Belohnungen")
	_game_state.time_offset = 120.0 - Time.get_unix_time_from_system()
	for animal in animal_nodes:
		animal.set_ambient("Sonnig", false, 12.0 * 3600.0)
		_check(not bool(animal.get("sleeping")) and not bool(animal.get("sheltering")), "am Tag bei Sonne kehrt normales Umherlaufen zurück")
	var save_after: Dictionary = _game_state.serialize()
	_check(int(save_after["version"]) == 9 and save_before["stats"] == save_after["stats"], "Ambient-Zustände ändern weder Save-Version noch Statistiken")
	_check(before_night["coins"] == save_after["coins"] and before_night["inventory"] == save_after["inventory"], "kosmetisches Verhalten beeinflusst keine Wirtschaftsdaten")
	_game_state.new_game()
	_game_state.time_offset = original_offset
	for animal in animal_nodes:
		animal.free()
