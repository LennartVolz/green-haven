extends Node
## Startet das Spiel hinter dem handgezeichneten Ladebildschirm.
##
## Der Bildschirm wird zuerst gezeichnet, danach werden Spielstand und Welt
## geladen. So sieht man beim Start nie das Godot-Logo oder eine leere Fläche,
## und der Fortschritt beschreibt echte Schritte. Die Hauptszene wird als
## Geschwister der Ladeszene in die Wurzel gehängt, damit sie beim Ausblenden
## nicht mitgelöscht wird.

const MAIN_SCENE := "res://scenes/main.tscn"
const MIN_DISPLAY_MSEC := 900

@onready var screen: Control = $Splash/Screen

var _started_msec := 0
var _skip_requested := false


## Vor dem Aufbau der Oberfläche: Die gespeicherte Sprache gilt schon für den
## Ladebildschirm, nicht erst für die Welt dahinter.
func _enter_tree() -> void:
	I18n.apply(SaveSystem.peek_language())


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	screen.skip_requested.connect(_on_skip_requested)
	_load_game()


func _load_game() -> void:
	# Erst ein Bild zeichnen lassen, dann arbeiten: Der Ladebildschirm steht,
	# bevor Spielstand und Welt die erste Frame blockieren.
	await get_tree().process_frame
	var has_save := SaveSystem.has_save()
	screen.set_greeting(has_save)
	screen.show_progress(0.16, I18n.t("Spielstand wird gelesen …"))
	await _wait(0.12)

	screen.show_progress(0.44, I18n.t("Der Hof wird aufgebaut …"))
	await get_tree().process_frame
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		push_error("Hauptszene konnte nicht geladen werden: %s" % MAIN_SCENE)
		screen.show_progress(1.0, I18n.t("Der Hof konnte nicht geladen werden."))
		return
	var main := packed.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main

	screen.show_progress(0.80, I18n.t("Beete werden vorbereitet …"))
	await get_tree().process_frame
	await get_tree().process_frame
	screen.show_progress(1.0, I18n.t("Fast fertig …"))
	screen.allow_skip()

	while not _skip_requested and Time.get_ticks_msec() - _started_msec < MIN_DISPLAY_MSEC:
		await get_tree().process_frame

	await screen.fade_out()
	queue_free()


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not _skip_requested and Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _on_skip_requested() -> void:
	_skip_requested = true
