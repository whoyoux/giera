class_name ScopeOverlay
extends Control
## Nakladka lunety na caly ekran: czarne tlo z okraglym okienkiem, cienki krzyz i punkt.

const CIRCLE_RATIO := 0.47
const POINTS := 96
const RING := Color(0.05, 0.05, 0.08)
const LINE := Color(0.05, 0.05, 0.08, 0.9)
const SEGMENTS := 48

## 0 bez lunety, 1 w pelni widoczna. Ustawia HUD.
var amount := 0.0:
	set(value):
		amount = value
		visible = value > 0.01
		modulate.a = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func radius() -> float:
	return minf(_area().x, _area().y) * CIRCLE_RATIO


## Pod CanvasLayer kotwice nie zawsze zdaza ustawic rozmiar, wiec bierzemy go z widoku.
func _area() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func _draw() -> void:
	var size := _area()
	var center := size * 0.5
	var r := radius()
	# Wszystko poza kolem jest czarne: gruby pierscien siegajacy za rogi ekranu.
	var far := size.length()
	for i in POINTS:
		var a := Vector2.from_angle(TAU * i / POINTS)
		var b := Vector2.from_angle(TAU * (i + 1) / POINTS)
		draw_colored_polygon(PackedVector2Array([center + a * (r - 1.0), center + a * far, center + b * far, center + b * (r - 1.0)]), Color.BLACK)
	draw_arc(center, r, 0.0, TAU, POINTS, RING, 10.0, true)
	draw_arc(center, r - 9.0, 0.0, TAU, POINTS, Color(1, 1, 1, 0.08), 3.0, true)
	# Krzyz: grube konce przy krawedzi, cienki srodek.
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + dir * r * 0.55, center + dir * r, LINE, 5.0, true)
		draw_line(center + dir * 6.0, center + dir * r * 0.55, LINE, 1.6, true)
	for i in range(1, 4):
		var tick := center + Vector2.DOWN * r * 0.1 * i
		draw_line(tick + Vector2.LEFT * 7.0, tick + Vector2.RIGHT * 7.0, LINE, 1.4, true)
	draw_circle(center, 2.2, CORAL_DOT)


const CORAL_DOT := Color("ef6f6c")
