extends SceneTree
## Erzeugt assets/boot_splash.png aus assets/boot_splash.svg.
##
## Godot akzeptiert für den Engine-Startbildschirm nur PNG. Die SVG-Datei bleibt
## die bearbeitbare Quelle; nach einer Änderung:
##   godot --headless --path . -s res://tools/make_boot_splash.gd


func _initialize() -> void:
	var source := "res://assets/boot_splash.svg"
	var target := "res://assets/boot_splash.png"
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		printerr("Startbild-Quelle fehlt: %s" % source)
		quit(1)
		return
	var image := Image.new()
	var error := image.load_svg_from_string(file.get_as_text(), 1.0)
	file.close()
	if error != OK:
		printerr("SVG konnte nicht gerastert werden: %s" % error_string(error))
		quit(1)
		return
	error = image.save_png(target)
	if error != OK:
		printerr("PNG konnte nicht geschrieben werden: %s" % error_string(error))
		quit(1)
		return
	print("Startbild geschrieben: %s (%dx%d)" % [target, image.get_width(), image.get_height()])
	quit()
