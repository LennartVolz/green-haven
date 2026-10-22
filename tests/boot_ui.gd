extends SceneTree
## Prüft den Ladebildschirm und den Start über die echte Startszene:
## Spielstand wird hinter dem Bildschirm geladen, Fortschritt läuft, danach
## übernimmt die Hauptszene und der Ladebildschirm verschwindet.

var failures := 0
var save_system: Node
var gs: Node


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	printerr("FAIL: ", message)


func frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame


func wait_until(condition: Callable, timeout_msec: int = 6000) -> bool:
	var until := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func run() -> void:
	save_system = root.get_node("SaveSystem")
	gs = root.get_node("GameState")
	save_system.path_override = "user://boot_ui_save.json"
	save_system.delete_save()

	check(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/boot.tscn", "das Spiel startet über die Ladeszene")
	check(ProjectSettings.get_setting("application/boot_splash/image", "") == "res://assets/boot_splash.png", "der Godot-Start zeigt das eigene Bild statt des Godot-Logos")
	check(ResourceLoader.exists("res://assets/boot_splash.png"), "das Startbild ist im Projekt vorhanden")

	# Ein echter Spielstand, den der Ladebildschirm einsammeln muss. Die fest
	# gewählte Sprache gehört dazu: der Bildschirm soll sie schon vor dem
	# eigentlichen Laden anwenden.
	gs.new_game()
	gs.settings["language"] = "de"
	gs.coins = 4321
	gs.level = 7
	check(save_system.save_game(), "Testspielstand wird gespeichert")
	gs.new_game()
	check(gs.coins != 4321, "der Spielstand ist vor dem Start nicht im Speicher")

	# --- Start mit vorhandenem Spielstand ---
	check(change_scene_to_file("res://scenes/boot.tscn") == OK, "Ladeszene lässt sich starten")
	await frames(2)
	var boot := current_scene
	check(boot != null and boot.name == "Boot", "die Ladeszene ist die aktive Szene")
	var screen: Control = null
	if boot != null:
		screen = boot.get_node_or_null("Splash/Screen")
	check(screen != null, "der Ladebildschirm liegt über der Spielszene")
	if screen == null:
		quit(1)
		return
	check(boot.get_node("Splash").layer >= 100, "der Ladebildschirm liegt über allen Spielmenüs")
	check(screen.size.x > 1000.0 and screen.size.y > 500.0, "der Ladebildschirm deckt den Bildschirm ab: %s" % screen.size)
	check(screen.progress < 1.0, "der Fortschritt startet nicht bei 100 Prozent")
	var title_rect: Rect2 = screen.title_label.get_global_rect()
	var greeting_rect: Rect2 = screen.greeting_label.get_global_rect()
	var status_rect: Rect2 = screen.status_label.get_global_rect()
	var version_rect: Rect2 = screen.version_label.get_global_rect()
	check(title_rect.size.y > 80.0, "der Titel ist groß genug lesbar: %s" % title_rect.size)
	check(title_rect.position.y > screen.size.y * 0.2 and title_rect.end.y < screen.size.y * 0.45, "der Titel liegt im freien Himmel: %s" % title_rect)
	check(greeting_rect.position.y > title_rect.end.y, "die Begrüßung steht unter dem Titel")
	check(status_rect.position.y > screen.size.y * 0.68, "der Ladetext steht über dem Fortschrittsbalken")
	check(version_rect.position.y > status_rect.end.y, "die Version steht am unteren Rand")
	await frames(5)
	check(screen.greeting_label.text == "Willkommen zurück", "vorhandener Spielstand wird begrüßt: %s" % screen.greeting_label.text)
	var mid_progress: float = screen.progress

	var main_ready := await wait_until(func() -> bool: return root.get_node_or_null("Main") != null)
	check(main_ready, "die Hauptszene wird hinter dem Ladebildschirm aufgebaut")
	check(screen.progress >= mid_progress, "der Fortschritt läuft vorwärts")
	check(gs.coins == 4321, "der gespeicherte Spielstand wird beim Start geladen: %s" % gs.coins)
	check(gs.level == 7, "die Stufe kommt aus dem Spielstand")
	var main: Node = root.get_node_or_null("Main")
	check(main != null and main.get_node_or_null("World") != null and main.get_node_or_null("UI") != null, "Welt und Oberfläche sind nach dem Laden vorhanden")
	if main != null:
		check(main.get_node("World").is_inside_tree(), "die Welt hängt im Szenenbaum")
		check(current_scene == main, "nach dem Laden ist die Hauptszene die aktive Szene")
	await frames(3)
	check(screen.status_label.text != "", "der Ladebildschirm nennt den aktuellen Schritt")
	check(screen.skippable, "der Ladebildschirm erlaubt nach dem Laden das Überspringen")

	# Auf den Szenennamen prüfen: eine Lambda auf den später gelöschten
	# Bildschirm würde nach dem Freigeben ins Leere greifen.
	var boot_freed := await wait_until(func() -> bool: return root.get_node_or_null("Boot") == null)
	check(boot_freed, "der Ladebildschirm wird nach dem Ausblenden freigegeben")
	check(not is_instance_valid(screen), "der Ladebildschirm ist nach dem Ausblenden nicht mehr im Baum")
	check(root.get_node_or_null("Main") != null, "die Hauptszene bleibt nach dem Ladebildschirm bestehen")
	var old_main := root.get_node_or_null("Main")
	if old_main != null:
		old_main.queue_free()
	await frames(3)

	# --- Start ohne Spielstand: eigener Gruß, neuer Hof ---
	save_system.delete_save()
	check(change_scene_to_file("res://scenes/boot.tscn") == OK, "Ladeszene startet auch ohne Spielstand")
	await frames(6)
	var fresh_boot := current_scene
	var fresh_screen: Control = null
	if fresh_boot != null:
		fresh_screen = fresh_boot.get_node_or_null("Splash/Screen")
	# Ohne Spielstand gilt die Gerätesprache; die Begrüßung muss ihr folgen.
	check(fresh_screen != null and fresh_screen.greeting_label.text == I18n.t("Ein neuer Hof entsteht"),
		"ohne Spielstand wird ein neuer Hof angekündigt: %s" % (fresh_screen.greeting_label.text if fresh_screen != null else "-"))
	var fresh_main := await wait_until(func() -> bool: return root.get_node_or_null("Main") != null)
	check(fresh_main, "auch ohne Spielstand wird die Welt aufgebaut")
	check(gs.coins == 120 and gs.day_number() == 1, "ohne Spielstand beginnt ein frisches Spiel")
	var can_skip := await wait_until(func() -> bool:
		var live := root.get_node_or_null("Boot/Splash/Screen")
		return live != null and live.skippable
	, 2000)
	check(can_skip, "der zweite Ladebildschirm ist überspringbar")
	var skip_started := Time.get_ticks_msec()
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = fresh_screen.size * 0.5
	tap.pressed = true
	fresh_screen._gui_input(tap)
	var fresh_freed := await wait_until(func() -> bool: return root.get_node_or_null("Boot") == null, 2000)
	check(fresh_freed, "auch der zweite Ladebildschirm blendet sich aus")
	var skip_msec := Time.get_ticks_msec() - skip_started
	check(skip_msec < 900, "Tippen verkürzt die Wartezeit: %d ms" % skip_msec)
	print("boot UI checked")
	save_system.delete_save()
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	# Die Prüfungen vergleichen deutsche Texte; unabhängig von der Gerätesprache.
	I18n.apply("de")
	call_deferred("run")
