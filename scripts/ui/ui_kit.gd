class_name UiKit
extends RefCounted
## Gemeinsame UI-Bausteine mit einheitlicher Designsprache:
## Salbeigrün, Cremeweiß, warmes Gelb und Erdtöne, große Touchflächen.

const MIN_TOUCH := 96

static func sage() -> Color: return Painter.col("#8DB580")
static func sage_dark() -> Color: return Painter.col("#6F9A63")
static func cream() -> Color: return Painter.col("#FFF6E0")
static func cream_dark() -> Color: return Painter.col("#F0E2BF")
static func yellow() -> Color: return Painter.col("#F4C95D")
static func yellow_dark() -> Color: return Painter.col("#D9A93A")
static func earth() -> Color: return Painter.col("#B58A5A")
static func earth_dark() -> Color: return Painter.col("#8E6240")
static func ink() -> Color: return Painter.col("#4A3A2A")
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
	th.default_font_size = 34
	th.set_color("font_color", "Label", ink())
	th.set_color("font_color", "Button", ink())
	return th


static func label(text: String, size: int = 34, color: Color = Color(0.29, 0.23, 0.16)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, size: int = 30, color: Color = Color(0.29, 0.23, 0.16)) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func hbox(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func vbox(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
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
	b.text = text
	b.custom_minimum_size = Vector2(0, MIN_TOUCH)
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_button(b, kind)
	return b


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
	var ic := icon(icon_name, 56)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := label(text, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
static func icon_text(icon_name: String, text: String, size: int = 30, color: Color = Color(0.29, 0.23, 0.16)) -> HBoxContainer:
	var h := hbox(6)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(icon_name, int(size * 1.1))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(label(text, size, color))
	return h


static func item_chip(id: String, have: int, need: int) -> HBoxContainer:
	var h := hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(item_icon(id, 52))
	var ok := have >= need
	var l := label("%d/%d" % [have, need], 28, sage_dark() if ok else red())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h
