extends Node
## Einstiegspunkt. Der Spielstand wird in _enter_tree geladen, damit Welt und
## Oberfläche beim Start bereits den fertigen Zustand sehen (Eltern-_enter_tree
## läuft vor den _ready-Aufrufen der Kinder).

## Zweites Drücken der Zurück-Taste innerhalb dieser Zeit beendet die App.
const EXIT_CONFIRM_MSEC := 2000

var _exit_armed_until_msec := 0


func _enter_tree() -> void:
	get_tree().auto_accept_quit = false
	if SaveSystem.has_save() and SaveSystem.load_game():
		return
	GameState.new_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_and_quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


## Android-Zurück-Taste (project.godot: quit_on_go_back = false): erst Menü oder Werkzeug
## schließen, auf dem Hauptbildschirm erst nach einem zweiten Drücken beenden.
func _on_back_pressed() -> void:
	var ui := get_node_or_null("UI")
	if ui != null and ui.has_method("handle_back") and ui.handle_back():
		return
	if Time.get_ticks_msec() < _exit_armed_until_msec:
		_save_and_quit()
		return
	_exit_armed_until_msec = Time.get_ticks_msec() + EXIT_CONFIRM_MSEC
	if ui != null and ui.has_method("show_toast"):
		ui.show_toast("Nochmal zurück drücken zum Beenden", "info")


func _save_and_quit() -> void:
	SaveSystem.save_game()
	get_tree().quit()
