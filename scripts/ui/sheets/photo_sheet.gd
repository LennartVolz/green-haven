extends RefCounted
## Fotos vom Hof: die gewählte Aufnahme groß, die letzten als Streifen darunter.
## Die Bilder liegen als PNG in user://photos und gehören nicht in den Spielstand.
## Deshalb gibt es hier nichts abzuholen – nur anzusehen.

## Höhe der großen Aufnahme und der Vorschaubilder. Die Breite folgt dem Bild,
## damit ein Querformat-Foto nicht in einem Quadrat verschwindet.
const PREVIEW_HEIGHT := 320
const THUMB_HEIGHT := 100
## So viele Vorschaubilder zeigt der Streifen. Acht Fotos in einer Zeile wären
## auf schmalen Bildschirmen schon wieder eine zweite Reihe.
const STRIP := 6


static func build(ui, args: Dictionary) -> void:
	ui.set_title("Fotos")
	var c: VBoxContainer = ui.content
	var all := Photos.photos()
	var path := str(args.get("path", ""))
	if path == "" and not all.is_empty():
		path = str(all[0])
	var image := _load(path)
	if image == null:
		c.add_child(UiKit.wrap_label("Noch kein Foto aufgenommen. Tippe oben auf die Kamera, um deinen Hof zu fotografieren.", 26, UiKit.earth_dark()))
		if not all.is_empty():
			c.add_child(UiKit.wrap_label("Diese Aufnahmen lassen sich gerade nicht lesen. Neue Fotos ersetzen sie nach und nach.", 22, UiKit.earth_dark()))
		var shoot := UiKit.button("Foto aufnehmen", "primary", 30)
		shoot.pressed.connect(ui.act_photo)
		c.add_child(shoot)
		return
	c.add_child(_preview(image))
	var caption := UiKit.label(I18n.t("Aufgenommen am %s") % _date_text(path), 24, UiKit.earth_dark())
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(caption)
	c.add_child(UiKit.wrap_label(I18n.t("Fotos bleiben auf diesem Gerät. Gespeichert als %s.") % path.get_file(), 22, UiKit.earth_dark()))
	if OS.has_feature("android"):
		c.add_child(UiKit.wrap_label("Auf Android bleiben die Fotos im App-Ordner. Sie verlassen das Gerät nicht.", 22, UiKit.earth_dark()))
	else:
		var open := UiKit.button("Ordner öffnen", "light", 26)
		open.pressed.connect(_open_folder)
		c.add_child(open)
	if all.size() > 1:
		c.add_child(UiKit.label("Zuletzt aufgenommen", 30, UiKit.earth_dark()))
		var strip := HFlowContainer.new()
		strip.add_theme_constant_override("h_separation", 10)
		strip.add_theme_constant_override("v_separation", 10)
		for index in range(mini(all.size(), STRIP)):
			var other := str(all[index])
			var thumb := _thumb(other)
			thumb.name = "PhotoThumb%d" % index
			thumb.pressed.connect(ui.open_sheet.bind("photo", {"path": other}))
			strip.add_child(thumb)
		c.add_child(strip)


## Das große Bild im Rahmen – wie das Ausflugsfoto im Tagebuch.
static func _preview(image: Image) -> Control:
	var frame := UiKit.panel(UiKit.cream(), 24, 8, UiKit.cream_dark(), 5)
	frame.name = "PhotoPreview"
	var pic := TextureRect.new()
	pic.name = "PhotoImage"
	pic.texture = _texture(image, PREVIEW_HEIGHT)
	pic.custom_minimum_size = (pic.texture as Texture2D).get_size()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	return frame


static func _thumb(path: String) -> Button:
	var button := UiKit.button("", "light", 24)
	button.custom_minimum_size = Vector2(THUMB_HEIGHT, THUMB_HEIGHT)
	var image := _load(path)
	if image != null:
		var texture := _texture(image, THUMB_HEIGHT)
		button.icon = texture
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Die Schaltfläche bekommt das Seitenverhältnis des Fotos, damit das Bild
		# im Streifen nicht verzerrt wird.
		button.custom_minimum_size = Vector2(texture.get_width(), THUMB_HEIGHT)
	button.tooltip_text = _date_text(path)
	return button


static func _load(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK or image.is_empty():
		return null
	return image


## Verkleinert nur nach unten: Ein Foto in Bildschirmgröße braucht keinen
## Speicher in voller Auflösung, ein kleines wird nicht hochgerechnet.
static func _texture(image: Image, height: int) -> ImageTexture:
	var shown := image
	if image.get_height() > height:
		var width := maxi(1, roundi(float(image.get_width()) * float(height) / float(image.get_height())))
		shown = image.duplicate()
		shown.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(shown)


## Datum und Uhrzeit der Datei. Der Name trägt dieselbe Angabe, aber die
## Dateizeit bleibt richtig, wenn jemand ein Foto umbenennt.
static func _date_text(path: String) -> String:
	var moment := FileAccess.get_modified_time(path)
	if moment <= 0:
		return ""
	var t := Photos.local_datetime(moment)
	return "%02d.%02d.%04d · %02d:%02d" % [int(t.day), int(t.month), int(t.year), int(t.hour), int(t.minute)]


static func _open_folder() -> void:
	OS.shell_open(Photos.folder())
