class_name UiKit
extends RefCounted
## Gemeinsame UI-Bausteine mit einheitlicher Designsprache:
## Salbeigrün, Cremeweiß, warmes Gelb und Erdtöne, große Touchflächen.

const MIN_TOUCH := 96
## Innenabstand eines Buttons links und rechts (siehe style_button: pad 14 + Rand).
const BUTTON_PAD_X := 18
const VolumeSliderScript := preload("res://scripts/ui/volume_slider.gd")

## Lesbarkeit: Die drei Stufen der Schriftgröße. `label` ist der deutsche Text,
## den I18n übersetzt.
const TEXT_SCALES := [
	{"label": "Klein", "factor": 0.9},
	{"label": "Normal", "factor": 1.0},
	{"label": "Groß", "factor": 1.2},
]
## Diese drei Werte kommen aus GameState.settings. Alle Texte, Mindesthöhen und
## Farben der Oberfläche laufen hier durch – deshalb genügt ein Regler in den
## Einstellungen, statt jede Ansicht doppelt zu bauen.
static var text_scale := 1.0
static var large_targets := false
static var high_contrast := false


## Übernimmt die gespeicherten Einstellungen. Muss vor dem Aufbau der Oberfläche
## laufen, damit schon das erste Sheet in der richtigen Größe entsteht.
static func apply_accessibility(settings: Dictionary) -> void:
	text_scale = clampf(float(settings.get("text_scale", 1.0)), TEXT_SCALES[0]["factor"], 1.35)
	large_targets = bool(settings.get("large_targets", false))
	high_contrast = bool(settings.get("high_contrast", false))


## Schriftgröße in Pixeln. Die Untergrenze hält auch kleine Nebentexte lesbar.
static func font_px(size: int) -> int:
	return maxi(11, roundi(float(size) * text_scale))


## Kantenlänge einer Schaltfläche. „Größere Schaltflächen“ wächst überall mit,
## damit die Mindesthöhe nicht nur auf dem Papier größer wird.
static func target_px(px: float) -> float:
	return px * (1.16 if large_targets else 1.0)


static func sage() -> Color: return Painter.col("#8DB580")
static func sage_dark() -> Color: return Painter.col("#3F6B38") if high_contrast else Painter.col("#6F9A63")
static func cream() -> Color: return Painter.col("#FFFDF6") if high_contrast else Painter.col("#FFF6E0")
static func cream_dark() -> Color: return Painter.col("#E0CFA4") if high_contrast else Painter.col("#F0E2BF")
static func yellow() -> Color: return Painter.col("#F4C95D")
static func yellow_dark() -> Color: return Painter.col("#C08F1F") if high_contrast else Painter.col("#D9A93A")
static func earth() -> Color: return Painter.col("#B58A5A")
static func earth_dark() -> Color: return Painter.col("#54351D") if high_contrast else Painter.col("#8E6240")
static func ink() -> Color: return Painter.col("#231910") if high_contrast else Painter.col("#4A3A2A")
static func red() -> Color: return Painter.col("#D9644A")


static func style(bg: Color, radius: int = 24, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 0, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0.2, 0.12, 0.05, 0.28)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.4)
	if pad > 0:
		s.set_content_margin_all(pad)
	return s


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = font_px(34)
	th.set_color("font_color", "Label", ink())
	th.set_color("font_color", "Button", ink())
	return th


## Alle Texte laufen hier durch I18n: Ein Aufruf mit deutschem Text zeigt in jeder
## Sprache den passenden Eintrag. Bereits zusammengesetzte Texte ("Stufe 3")
## haben keinen Eintrag und bleiben unverändert.
## Ohne Farbe gilt die Tintenfarbe der Palette – so folgt jeder Standardtext dem
## Kontrastschalter, ohne dass jede Aufrufstelle ihn kennen muss.
static func label(text: String, size: int = 34, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = I18n.t(text)
	l.add_theme_font_size_override("font_size", font_px(size))
	l.add_theme_color_override("font_color", ink() if color.a == 0.0 else color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size: int = 30, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func hbox(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_constant_override("separation", sep)
	return b


static func vbox(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_constant_override("separation", sep)
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(child)
	return m


static func panel(bg: Color, radius: int = 24, pad: int = 16, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", style(bg, radius, border, border_w, shadow, pad))
	return p


static func card(pad: int = 16) -> PanelContainer:
	var p := panel(cream(), 26, pad, cream_dark(), 3)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


static func icon(icon_name: String, px: int = 48) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Icons.tex(icon_name, px * 2)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func item_icon(id: String, px: int = 72) -> ItemIcon:
	var c := ItemIcon.new()
	c.item_id = id
	c.custom_minimum_size = Vector2(px, px)
	return c


## kind: primary (salbei), warm (gelb), danger (rot), light (creme), ghost
static func button(text: String, kind: String = "primary", font_size: int = 34) -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = I18n.t(text)
	# Übersetzungen sind oft länger als das Deutsche („Alle" → „Tout vendre").
	# Statt den Text abzuschneiden, bricht der Button um und wächst in die Höhe.
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Ein umbrechender Button hat von sich aus fast keine Mindestbreite. Steht
	# neben ihm ein spacer(), schrumpft er deshalb auf die Innenabstände und
	# bricht Buchstabe für Buchstabe – der Text verschwindet. Die Mindestbreite
	# ist darum das längste Wort: Umbruch bleibt erlaubt, aber nur an Wortgrenzen.
	var px := font_px(font_size)
	b.custom_minimum_size = Vector2(_widest_word(b.get_theme_font("font"), b.text, px) + BUTTON_PAD_X * 2.0, target_px(MIN_TOUCH))
	b.add_theme_font_size_override("font_size", px)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_button(b, kind)
	return b


## Breite des längsten Wortes in der Schrift, in der der Text erscheint.
static func _widest_word(font: Font, text: String, size: int) -> float:
	if font == null or text.is_empty():
		return 0.0
	var widest := 0.0
	for word in text.split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest


static func style_button(b: Button, kind: String) -> void:
	var bg: Color
	var dark: Color
	var fg: Color = cream()
	match kind:
		"warm":
			bg = yellow()
			dark = yellow_dark()
			fg = ink()
		"danger":
			bg = red()
			dark = red().darkened(0.2)
		"light":
			bg = cream()
			dark = cream_dark()
			fg = ink()
		"ghost":
			bg = Color(1, 1, 1, 0.0)
			dark = Color(1, 1, 1, 0.0)
			fg = ink()
		_:
			bg = sage()
			dark = sage_dark()
	var normal := style(bg, 26, dark, 0, 0, 14)
	normal.border_width_bottom = 8 if kind != "ghost" else 0
	normal.border_color = dark
	var pressed := style(bg.darkened(0.08), 26, dark, 0, 0, 14)
	pressed.border_width_bottom = 2 if kind != "ghost" else 0
	pressed.border_color = dark
	pressed.content_margin_top = 20
	var disabled := style(Painter.col("#D9D2BF"), 26, Painter.col("#BDB59F"), 0, 0, 14)
	disabled.border_width_bottom = 8
	disabled.border_color = Painter.col("#BDB59F")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Painter.col("#8F8873"))


static func icon_button(icon_name: String, kind: String = "primary", px: int = 88) -> Button:
	var b := button("", kind)
	px = roundi(target_px(float(px)))
	b.custom_minimum_size = Vector2(px, px)
	b.icon = Icons.tex(icon_name, 96)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Navigations-Button mit Symbol über dem Text.
static func nav_button(icon_name: String, text: String, w: int = 150, h: int = 124) -> Button:
	var b := button("", "light")
	b.custom_minimum_size = Vector2(w, h)
	var v := vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(icon_name, 48)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	# Die Beschriftung darf zweizeilig werden und die Mindestbreite des Buttons
	# nur noch vom längsten Wort bestimmen – sonst sprengen „Commandes" oder
	# „Obiettivi" die Navigationsleiste.
	var l := label(text, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(l)
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


static func badge(b: Button, count: int) -> void:
	var existing := b.get_node_or_null("Badge")
	if existing != null:
		existing.queue_free()
	if count <= 0:
		return
	var p := PanelContainer.new()
	p.name = "Badge"
	p.add_theme_stylebox_override("panel", style(red(), 20, cream(), 3, 0, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(str(mini(count, 99)), 24, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(26, 0)
	p.add_child(l)
	b.add_child(p)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.position += Vector2(-4, -12)


## Touch-freundlicher Lautstärkeregler von 0 bis 1 mit sichtbarer Schiene.
static func volume_slider(value: float, step: float = 0.05):
	var s = VolumeSliderScript.new()
	s.step = step
	s.value = clampf(value, 0.0, 1.0)
	return s


static func progress(ratio: float, fill: Color, height: int = 22) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = ratio
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("background", style(Color(0, 0, 0, 0.16), height / 2))
	p.add_theme_stylebox_override("fill", style(fill, height / 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Zeile aus Symbol + Text, z. B. Münzen oder Stufe.
static func icon_text(icon_name: String, text: String, size: int = 30, color: Color = Color(0, 0, 0, 0)) -> HBoxContainer:
	var h := hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(icon_name, int(font_px(size) * 1.1))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	# Einzeilig und ohne EXPAND_FILL: Zahlen wie „+18" sind kurz. Mit Umbruch
	# hatte der Text in einer schmalen Zeile 1 px Breite und stapelte sich
	# senkrecht (ein Belohnungswert je Zeichen in einer eigenen Zeile).
	var l := label(text, size, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## Belohnung als einzeilige Pille: Symbol + Wert, überall gleich breit und hoch.
static func reward_chip(icon_name: String, text: String, size: int = 26) -> PanelContainer:
	var p := panel(cream_dark(), 18, 6)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := hbox(4)
	h.add_child(icon(icon_name, int(font_px(size) * 1.25)))
	var l := label(text, size, ink())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.add_child(h)
	return p


static func item_chip(id: String, have: int, need: int) -> HBoxContainer:
	var h := hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(item_icon(id, 52))
	var ok := have >= need
	var l := label("%d/%d" % [have, need], 28, sage_dark() if ok else red())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h
