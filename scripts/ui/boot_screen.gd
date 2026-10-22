extends Control
## Handgezeichneter Ladebildschirm: Hügel, Hofhaus und Sprössling werden wie die
## Spielgrafik prozedural gezeichnet. Er zeigt den echten Ladefortschritt und
## blendet sich danach weich aus. Tippen verkürzt die Wartezeit, sobald der Hof
## bereitsteht.

signal skip_requested

const BASE_HEIGHT := 1080.0
const FADE_SECONDS := 0.42
const MIN_SKIP_AFTER := 0.45

var progress := 0.0
var target_progress := 0.0
var skippable := false

var title_label: Label
var greeting_label: Label
var status_label: Label
var version_label: Label

var _t := 0.0
var _fade_elapsed := 0.0
var _fading := false
var _bar_y := 0.805


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_build_labels()
	resized.connect(_layout)
	_layout()


func _build_labels() -> void:
	title_label = UiKit.label("Green Haven", 116, UiKit.ink())
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title_label)

	greeting_label = UiKit.label("Ein gemütlicher Hof", 38, UiKit.earth_dark())
	greeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greeting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(greeting_label)

	status_label = UiKit.label("Der Hof wacht auf …", 30, UiKit.earth_dark())
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(status_label)

	version_label = UiKit.label(I18n.t("Version %s") % ProjectSettings.get_setting("application/config/version", "0.1.0"), 20, Color(UiKit.earth_dark(), 0.7))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(version_label)


func _layout() -> void:
	if title_label == null:
		return
	var s := maxf(size.y / BASE_HEIGHT, 0.35)
	title_label.add_theme_font_size_override("font_size", int(116.0 * s))
	greeting_label.add_theme_font_size_override("font_size", int(38.0 * s))
	status_label.add_theme_font_size_override("font_size", int(30.0 * s))
	version_label.add_theme_font_size_override("font_size", int(20.0 * s))
	# Labels nie in feste Schlitze zwingen: Ihre Mindesthöhe hängt von Schrift und
	# Zeilenumbruch ab. Deshalb aus der Mindesthöhe heraus stapeln, statt zu raten.
	var gap := 0.012 * size.y
	var title_top := 0.235 * size.y
	var title_h := title_label.get_minimum_size().y
	_place(title_label, title_top, title_h)
	var greet_top := title_top + title_h + gap
	_place(greeting_label, greet_top, greeting_label.get_minimum_size().y)
	var status_top := 0.72 * size.y
	var status_h := status_label.get_minimum_size().y
	_place(status_label, status_top, status_h)
	_bar_y = status_top + status_h + 0.018 * size.y
	var version_h := version_label.get_minimum_size().y
	_place(version_label, size.y - version_h - 0.02 * size.y, version_h)


func _place(label: Label, top: float, height: float) -> void:
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = top
	label.offset_bottom = top + height


## Setzt die Begrüßung, sobald bekannt ist, ob ein Spielstand vorliegt.
func set_greeting(has_save: bool) -> void:
	greeting_label.text = I18n.t("Willkommen zurück") if has_save else I18n.t("Ein neuer Hof entsteht")


## Neuer Schritt: Text und Zielwert des Fortschritts.
func show_progress(value: float, text: String) -> void:
	target_progress = clampf(value, 0.0, 1.0)
	status_label.text = text


## Ab jetzt darf ein Tipp die restliche Wartezeit überspringen.
func allow_skip() -> void:
	skippable = true


## Blendet den Bildschirm aus und gibt danach Eingaben an das Spiel frei.
func fade_out(duration: float = FADE_SECONDS) -> void:
	_fading = true
	_fade_elapsed = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if not _fading:
		progress = lerpf(progress, target_progress, clampf(delta * 7.5, 0.0, 1.0))
		if absf(progress - target_progress) < 0.004:
			progress = target_progress
		queue_redraw()
	else:
		_fade_elapsed += delta


func _gui_input(event: InputEvent) -> void:
	if not skippable:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			skip_requested.emit()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			skip_requested.emit()


# ------------------------------------------------------------------ Zeichnung

func _draw() -> void:
	var w := size.x
	var h := size.y
	var s := h / BASE_HEIGHT
	draw_rect(Rect2(Vector2.ZERO, size), Painter.col("#FFF6E0"))
	_draw_sky(w, h)
	_draw_sun(Vector2(w * 0.77, h * 0.232), h * 0.081)
	_draw_clouds(w, h, s)
	_draw_birds(w, h, s)
	_draw_hills(w, h, s)
	_draw_trees(w, h, s)
	_draw_farmhouse(Vector2(w * 0.745, h * 0.683), s)
	_draw_meadow(w, h, s)
	_draw_sprout(Vector2(w * 0.165, h * 0.90), 1.25 * s)
	_draw_progress(w, h, s)


func _draw_sky(w: float, h: float) -> void:
	var top := Painter.col("#FFFBEF")
	var horizon := Painter.col("#F5E6C6")
	var bands := 18
	for i in range(bands):
		var k := float(i) / float(bands - 1)
		var y := h * 0.62 * float(i) / float(bands)
		draw_rect(Rect2(0, y, w, h * 0.62 / float(bands) + 2.0), top.lerp(horizon, k))


func _draw_sun(center: Vector2, radius: float) -> void:
	var pulse := 1.0 + sin(_t * 0.8) * 0.02
	var glow: Color = Painter.col("#F4C95D")
	glow.a = 0.10
	draw_circle(center, radius * 1.7 * pulse, glow)
	glow.a = 0.14
	draw_circle(center, radius * 1.28 * pulse, glow)
	draw_circle(center, radius * pulse, Painter.col("#F4C95D"))
	draw_circle(center + Vector2(-radius * 0.2, -radius * 0.22), radius * 0.22, Color(1, 1, 1, 0.2))


func _draw_clouds(w: float, h: float, s: float) -> void:
	for i in range(3):
		var span := w + 560.0 * s
		var x := fposmod(w * 0.15 + float(i) * w * 0.36 + _t * (7.0 + float(i) * 3.0) * s, span) - 280.0 * s
		var y := h * (0.13 + 0.055 * float(i))
		var cs := (0.85 + 0.2 * float(i)) * s
		_cloud(Vector2(x, y), cs)


func _cloud(center: Vector2, s: float) -> void:
	var shade := Color(0.91, 0.86, 0.75, 0.32)
	var cream := Color(1.0, 0.985, 0.93, 0.95)
	Painter.ellipse(self, center + Vector2(0, 9.0 * s), 140.0 * s, 34.0 * s, shade)
	Painter.ellipse(self, center, 132.0 * s, 40.0 * s, cream)
	Painter.ellipse(self, center + Vector2(-62.0 * s, 12.0 * s), 62.0 * s, 30.0 * s, cream)
	Painter.ellipse(self, center + Vector2(66.0 * s, 14.0 * s), 70.0 * s, 28.0 * s, cream)
	Painter.ellipse(self, center + Vector2(8.0 * s, -20.0 * s), 66.0 * s, 34.0 * s, cream)


func _draw_birds(w: float, h: float, s: float) -> void:
	var ink := Color(0.36, 0.30, 0.23, 0.55)
	for i in range(2):
		var x := fposmod(w * 0.26 + _t * (18.0 + float(i) * 8.0) * s + float(i) * w * 0.3, w + 220.0 * s) - 110.0 * s
		var y := h * (0.11 + 0.06 * float(i)) + sin(_t * 1.2 + float(i)) * 5.0 * s
		var r := 13.0 * s
		draw_polyline(PackedVector2Array([Vector2(x - r, y), Vector2(x - r * 0.35, y - r * 0.6), Vector2(x, y)]), ink, 3.0 * s, true)
		draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + r * 0.35, y - r * 0.6), Vector2(x + r, y)]), ink, 3.0 * s, true)


func _draw_hills(w: float, h: float, s: float) -> void:
	_hill(h * 0.615, 24.0 * s, 0.4, "#D9E7C4")
	_hill(h * 0.665, 32.0 * s, 1.7, "#C4DCA9")
	_hill(h * 0.715, 28.0 * s, 3.1, "#AFCF94")


func _hill(base_y: float, amp: float, phase: float, color: String) -> void:
	var pts := PackedVector2Array()
	var steps := 44
	for i in range(steps + 1):
		var x := size.x * float(i) / float(steps)
		var y := base_y + sin(float(i) * 0.34 + phase) * amp + sin(float(i) * 0.12 + phase * 1.7) * amp * 0.55
		pts.append(Vector2(x, y))
	pts.append(Vector2(size.x, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, Painter.col(color))


func _draw_trees(w: float, h: float, s: float) -> void:
	Painter.tree(self, Vector2(w * 0.15, h * 0.683), 0.55 * s, _t)
	Painter.tree(self, Vector2(w * 0.32, h * 0.683), 0.4 * s, _t)
	Painter.tree(self, Vector2(w * 0.60, h * 0.698), 0.5 * s, _t)


func _draw_farmhouse(base: Vector2, s: float) -> void:
	draw_set_transform(base, 0.0, Vector2(s, s))
	Painter.shadow(self, Vector2(0, 0), 150, 26)
	Painter.rrect(self, Rect2(-110, -142, 220, 142), Painter.col("#FFF9EA"), 12)
	Painter.rrect(self, Rect2(-110, -30, 220, 30), Painter.col("#F0E2BF"), 10)
	Painter.poly(self, [Vector2(-134, -132), Vector2(-12, -234), Vector2(12, -234), Vector2(134, -132)], Painter.col("#C97A55"))
	Painter.poly(self, [Vector2(-134, -132), Vector2(-12, -234), Vector2(-2, -222), Vector2(-122, -132)], Painter.col("#D98A5F"))
	Painter.rrect(self, Rect2(-138, -140, 276, 16), Painter.col("#B5654A"), 7)
	Painter.rrect(self, Rect2(52, -216, 26, 60), Painter.col("#B58A5A"), 6)
	for i in range(3):
		var k := fposmod(_t * 0.22 + float(i) * 0.33, 1.0)
		draw_circle(Vector2(65, -222 - k * 56.0), 6.0 + k * 10.0, Color(1, 1, 1, 0.42 * (1.0 - k)))
	Painter.rrect(self, Rect2(-38, -94, 76, 94), Painter.col("#8E6240"), 9)
	draw_circle(Vector2(20, -48), 4.0, Painter.col("#F6D870"))
	for x in [-94.0, 46.0]:
		Painter.rrect(self, Rect2(x, -112, 48, 42), Painter.col("#FFE79A"), 7)
		draw_line(Vector2(x + 24, -112), Vector2(x + 24, -70), Painter.col("#8E6240"), 3.0, true)
		draw_line(Vector2(x, -91), Vector2(x + 48, -91), Painter.col("#8E6240"), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_meadow(w: float, h: float, s: float) -> void:
	_hill(h * 0.82, 18.0 * s, 2.2, "#9CC47E")
	_hill(h * 0.915, 14.0 * s, 4.4, "#8DB580")
	var row := Color(0.66, 0.79, 0.55, 0.85)
	for i in range(2):
		var y := h * (0.952 + 0.028 * float(i))
		draw_arc(Vector2(w * 0.46, y - h * 0.03), w * 0.30, PI * 0.18, PI * 0.82, 32, row, 5.0 * s, true)
	var flowers := [
		[Vector2(w * 0.34, h * 0.932), "#F28BB0"],
		[Vector2(w * 0.41, h * 0.972), "#FFFFFF"],
		[Vector2(w * 0.55, h * 0.952), "#F6D84A"],
		[Vector2(w * 0.66, h * 0.986), "#B79AE8"],
		[Vector2(w * 0.74, h * 0.942), "#F28BB0"],
	]
	for f in flowers:
		Painter.flower_dot(self, f[0], 0.7 * s, Painter.col(f[1]))


func _draw_sprout(base: Vector2, s: float) -> void:
	var sway := sin(_t * 1.3) * 5.0 * s
	Painter.ellipse(self, base + Vector2(0, -4.0 * s), 70.0 * s, 18.0 * s, Color(0, 0, 0, 0.1))
	Painter.ellipse(self, base + Vector2(0, -10.0 * s), 58.0 * s, 16.0 * s, Painter.col("#8C5C3A"))
	var tip := base + Vector2(sway, -128.0 * s)
	draw_line(base + Vector2(0, -16.0 * s), tip, Painter.col("#6F9A63"), 11.0 * s, true)
	_leaf(tip + Vector2(-4.0 * s, 8.0 * s), Vector2(-1.0, -0.35), 64.0 * s, 26.0 * s, Painter.col("#8DB580"))
	_leaf(tip + Vector2(2.0 * s, -10.0 * s), Vector2(1.0, -0.5), 60.0 * s, 24.0 * s, Painter.col("#6F9A63"))
	draw_circle(base + Vector2(0, 30.0 * s), 9.0 * s, Painter.col("#F4C95D"))


func _leaf(anchor: Vector2, direction: Vector2, length: float, width: float, color: Color) -> void:
	var dir := direction.normalized()
	var normal := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for i in range(9):
		var k := float(i) / 8.0
		pts.append(anchor + dir * (length * k) + normal * (sin(k * PI) * width))
	for i in range(8, -1, -1):
		var k := float(i) / 8.0
		pts.append(anchor + dir * (length * k) - normal * (sin(k * PI) * width))
	draw_colored_polygon(pts, color)
	draw_line(anchor, anchor + dir * length, color.darkened(0.12), 3.0, true)


func _draw_progress(w: float, h: float, s: float) -> void:
	var bar_w := minf(w * 0.30, 640.0 * s)
	var bar_h := 16.0 * s
	var bar := Rect2(Vector2((w - bar_w) * 0.5, _bar_y), Vector2(bar_w, bar_h))
	Painter.rrect(self, bar.grow(4.0 * s), Color(1.0, 1.0, 1.0, 0.55), (bar_h + 8.0 * s) * 0.5)
	Painter.rrect(self, bar, Painter.col("#E7D9B8"), bar_h * 0.5)
	var fill_w := maxf(bar_h, bar_w * clampf(progress, 0.0, 1.0))
	Painter.rrect(self, Rect2(bar.position, Vector2(fill_w, bar_h)), Painter.col("#8DB580"), bar_h * 0.5)
	if progress > 0.02:
		draw_circle(Vector2(bar.position.x + fill_w - bar_h * 0.5, bar.position.y + bar_h * 0.5), bar_h * 0.28, Color(1, 1, 1, 0.35))
