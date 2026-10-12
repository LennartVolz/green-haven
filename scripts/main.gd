extends Node
## Einstiegspunkt. Der Spielstand wird in _enter_tree geladen, damit Welt und
## Oberfläche beim Start bereits den fertigen Zustand sehen (Eltern-_enter_tree
## läuft vor den _ready-Aufrufen der Kinder).


func _enter_tree() -> void:
	get_tree().auto_accept_quit = false
	if SaveSystem.has_save() and SaveSystem.load_game():
		return
	GameState.new_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android-Zurück-Taste: erst speichern, dann beenden.
		SaveSystem.save_game()
		get_tree().quit()
