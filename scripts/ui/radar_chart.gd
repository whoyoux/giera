class_name RadarChart
extends Control
## Szesciokatny wykres dwoch broni nalozonych na siebie. Wartosci sa od 0 do 1.

const RINGS: Array[float] = [0.25, 0.5, 0.75, 1.0]
const GRID_COLOR := Color("e6dbc6")
const FILL_ALPHA := 0.32
const LINE_WIDTH := 4.0
const LABEL_SIZE := 15
## Ile miejsca na podpisy zostaje wokol wykresu.
const LABEL_ROOM := 46.0
const LABEL_OFFSET := 1.18

var labels: PackedStringArray = []
var _series: Array[PackedFloat32Array] = []
var _colors: Array[Color] = []


func set_series(values: Array[PackedFloat32Array], colors: Array[Color]) -> void:
	_series = values
	_colors = colors
	queue_redraw()


func _draw() -> void:
	var count := labels.size()
	if count < 3:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - LABEL_ROOM
	for ring in RINGS:
		var ring_values := PackedFloat32Array()
		ring_values.resize(count)
		ring_values.fill(ring)
		var points := _polygon(center, radius, ring_values)
		points.append(points[0])
		draw_polyline(points, GRID_COLOR, 2.0, true)
	for index in count:
		draw_line(center, center + _direction(index, count) * radius, GRID_COLOR, 2.0, true)
	for series_index in _series.size():
		var points := _polygon(center, radius, _series[series_index])
		var color := _colors[series_index]
		draw_colored_polygon(points, Color(color, FILL_ALPHA))
		points.append(points[0])
		draw_polyline(points, color, LINE_WIDTH, true)
	var font := UiStyle.font()
	for index in count:
		var anchor := center + _direction(index, count) * radius * LABEL_OFFSET
		var text := labels[index]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		draw_string(font, anchor + Vector2(-text_size.x * 0.5, LABEL_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, UiStyle.INK)


## Pierwsza os patrzy w gore, kolejne ida zgodnie z zegarem.
func _direction(index: int, count: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * index / count
	return Vector2(cos(angle), sin(angle))


func _polygon(center: Vector2, radius: float, values: PackedFloat32Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in values.size():
		points.append(center + _direction(index, values.size()) * radius * clampf(values[index], 0.05, 1.0))
	return points
