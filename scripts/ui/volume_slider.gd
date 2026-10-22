class_name VolumeSlider
extends Control
## Selbst gezeichneter Lautstärkeregler: sichtbare Schiene, gefüllter Anteil und
## ein großer Griff. Funktioniert mit Maus, Finger-Tippen und Ziehen.
## Eigene Zeichnung statt Theme-Styleboxen, damit die Leiste auf jedem Gerät
## sichtbar bleibt und die Touchfläche groß genug ist.

signal value_changed(value: float)

const TRACK_HEIGHT := 18.0
const HANDLE_RADIUS := 26.0
const TOUCH_HEIGHT := 76.0

var _value := 1.0
var _editable := true
var _dragging := false
var step := 0.05

var value: float:
	get:
		return _value
	set(v):
		_apply_value(v)

var editable: bool:
	get:
		return _editable
	set(v):
		_editable = v
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(240, TOUCH_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = I18n.t("Ziehen oder tippen, um die Lautstärke zu ändern")


func _apply_value(raw: float) -> void:
	var snapped := clampf(roundf(raw / step) * step, 0.0, 1.0)
	if is_equal_approx(snapped, _value):
		return
	_value = snapped
	queue_redraw()
	value_changed.emit(_value)


## Anteil (0…1) an einer lokalen x-Position. Auch für Tests nutzbar.
func ratio_at(x: float) -> float:
	var usable := maxf(1.0, size.x - HANDLE_RADIUS * 2.0)
	return clampf((x - HANDLE_RADIUS) / usable, 0.0, 1.0)


func track_rect() -> Rect2:
	var left := HANDLE_RADIUS
	var right := maxf(left + 1.0, size.x - HANDLE_RADIUS)
	return Rect2(left, size.y * 0.5 - TRACK_HEIGHT * 0.5, right - left, TRACK_HEIGHT)


func handle_rect() -> Rect2:
	var center := Vector2(track_rect().position.x + track_rect().size.x * _value, size.y * 0.5)
	return Rect2(center - Vector2(HANDLE_RADIUS, HANDLE_RADIUS), Vector2(HANDLE_RADIUS * 2.0, HANDLE_RADIUS * 2.0))


func _draw() -> void:
	var track := track_rect()
	var cy := size.y * 0.5
	var radius := TRACK_HEIGHT * 0.5
	var track_color := Painter.col("#E8D9B8") if _editable else Painter.col("#D6CFBC")
	var fill_color := Painter.col("#8DB580") if _editable else Painter.col("#ADA694")
	# Schiene mit weichem Rand
	Painter.rrect(self, track.grow(3.0), Painter.col("#B8A98A").lightened(0.25), radius + 3.0)
	Painter.rrect(self, track, track_color, radius)
	var fill_width := track.size.x * _value
	if fill_width > 1.0:
		Painter.rrect(self, Rect2(track.position, Vector2(fill_width, track.size.y)), fill_color, radius)
	# Feine Markierungen in 25-%-Schritten
	for i in range(5):
		var x := track.position.x + track.size.x * float(i) / 4.0
		draw_line(Vector2(x, cy - 5.0), Vector2(x, cy + 5.0), Color(1, 1, 1, 0.45), 2.0, true)
	# Griff mit Schatten, Ring und Innenkreis
	var center := Vector2(track.position.x + track.size.x * _value, cy)
	draw_circle(center + Vector2(0, 4), HANDLE_RADIUS, Color(0, 0, 0, 0.18))
	draw_circle(center, HANDLE_RADIUS, Painter.col("#6F9A63") if _editable else Painter.col("#A9A28C"))
	draw_circle(center, HANDLE_RADIUS - 6.0, Painter.col("#FFF6E0"))
	draw_circle(center, HANDLE_RADIUS - 13.0, fill_color)


func _gui_input(event: InputEvent) -> void:
	if not _editable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_apply_value(ratio_at(event.position.x))
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_apply_value(ratio_at(event.position.x))
		accept_event()


## Touch läuft über die globale Ebene, damit der Regler auch ohne
## Maus-Emulation funktioniert und das Sheet dabei nicht mitscrollt.
func _input(event: InputEvent) -> void:
	if not _editable or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if not event.pressed:
			_dragging = false
			return
		if not get_global_rect().has_point(event.position):
			return
		_dragging = true
		_apply_screen_position(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _dragging:
		_apply_screen_position(event.position)
		get_viewport().set_input_as_handled()


func _apply_screen_position(screen_pos: Vector2) -> void:
	var local := get_global_transform().affine_inverse() * screen_pos
	_apply_value(ratio_at(local.x))
