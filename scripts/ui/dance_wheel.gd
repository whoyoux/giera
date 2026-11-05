class_name DanceWheel
extends Control
## Kolo wyboru tanca. Mysz jest zlapana przez gre, wiec kursor kola jest wirtualny: gracz moze
## dalej chodzic, a ruch myszy zamiast obracac kamere przesuwa kursor. Puszczenie klawisza
## albo klikniecie wybiera taniec pod kursorem, a puszczenie na srodku niczego nie wybiera.

signal chosen(dance_id: int)

const INNER_RADIUS := 74.0
const OUTER_RADIUS := 214.0
const HOVER_GROW := 16.0
const CURSOR_REACH := 170.0
const DEAD_ZONE := 42.0
const ICON_SIDE := 88.0
const ICON_RADIUS := 134.0
const NAME_RADIUS := 190.0
const NAME_FONT_SIZE := 18
const ARC_STEPS := 18
const SEGMENT_GAP := 0.025
const POP_FROM := 0.86
const POP_SECONDS := 0.14
const CENTER_HINT := "Wybierz taniec"

var is_open := false
var _cursor := Vector2.ZERO
var _hovered := DanceCatalog.NONE
var _icons: Array[TextureRect] = []
var _names: Array[Label] = []
var _center_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	for dance: Dictionary in DanceCatalog.DANCES:
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/dance_%s.png" % dance.key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2.ONE * ICON_SIDE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_icons.append(icon)
		var dance_name := UiStyle.label(dance.name, NAME_FONT_SIZE, UiStyle.INK)
		dance_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dance_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(dance_name)
		_names.append(dance_name)
	_center_label = UiStyle.label(CENTER_HINT, 17, UiStyle.INK)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center_label.size = Vector2(INNER_RADIUS * 1.7, INNER_RADIUS * 1.2)
	add_child(_center_label)
	resized.connect(_layout)
	_layout()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_cursor = Vector2.ZERO
	_set_hovered(DanceCatalog.NONE)
	_layout()
	pivot_offset = size * 0.5
	scale = Vector2.ONE * POP_FROM
	modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS)
	tween.tween_property(self, "modulate:a", 1.0, POP_SECONDS)
	UiSound.play(Sfx.UiCue.OPEN)


## Zamyka kolo bez wyboru.
func cancel() -> void:
	if is_open:
		_close()
		UiSound.play(Sfx.UiCue.CLOSE)


func hovered() -> int:
	return _hovered


func _close() -> void:
	is_open = false
	visible = false


func _pick() -> void:
	var dance_id := _hovered
	if dance_id == DanceCatalog.NONE:
		cancel()
		return
	_close()
	chosen.emit(dance_id)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		_cursor = (_cursor + (event as InputEventMouseMotion).relative).limit_length(CURSOR_REACH)
		_set_hovered(_segment_at(_cursor))
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("dance"):
		_pick()
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_pick()
		elif event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			cancel()


func _segment_at(point: Vector2) -> int:
	if point.length() < DEAD_ZONE:
		return DanceCatalog.NONE
	var count := DanceCatalog.DANCES.size()
	var from_top := fposmod(point.angle() + PI * 0.5 + PI / count, TAU)
	return int(from_top / TAU * count) % count + 1


func _set_hovered(dance_id: int) -> void:
	if dance_id == _hovered:
		return
	_hovered = dance_id
	if dance_id != DanceCatalog.NONE:
		UiSound.hover()
	_center_label.text = CENTER_HINT if dance_id == DanceCatalog.NONE else DanceCatalog.entry(dance_id).name
	_layout()
	queue_redraw()


func _segment_angle(index: int) -> float:
	return -PI * 0.5 + TAU * index / DanceCatalog.DANCES.size()


func _layout() -> void:
	var center := size * 0.5
	for index in _icons.size():
		var grow := HOVER_GROW if index + 1 == _hovered else 0.0
		var direction := Vector2.from_angle(_segment_angle(index))
		_icons[index].position = center + direction * (ICON_RADIUS + grow) - _icons[index].size * 0.5 - Vector2(0.0, 10.0)
		_names[index].size = Vector2(130.0, 24.0)
		_names[index].position = center + direction * (ICON_RADIUS + grow) + Vector2(-65.0, ICON_SIDE * 0.5 - 16.0)
	_center_label.position = center - _center_label.size * 0.5


func _draw() -> void:
	var center := size * 0.5
	for index in DanceCatalog.DANCES.size():
		var dance: Dictionary = DanceCatalog.DANCES[index]
		var selected := index + 1 == _hovered
		var outline := _segment_outline(center, index, OUTER_RADIUS + (HOVER_GROW if selected else 0.0))
		draw_colored_polygon(outline, Color(dance.color, 0.95) if selected else Color(UiStyle.PAPER, 0.92))
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, Color.WHITE, 5.0, true)
	draw_circle(center, INNER_RADIUS - 8.0, Color(UiStyle.PAPER, 0.96), true, -1.0, true)
	draw_circle(center, INNER_RADIUS - 8.0, Color.WHITE, false, 5.0, true)
	# Kursor kola. Gra trzyma prawdziwy kursor ukryty.
	var tip := center + _cursor
	draw_circle(tip, 10.0, Color(UiStyle.INK, 0.8), true, -1.0, true)
	draw_circle(tip, 6.5, Color.WHITE, true, -1.0, true)


func _segment_outline(center: Vector2, index: int, outer: float) -> PackedVector2Array:
	var half := PI / DanceCatalog.DANCES.size() - SEGMENT_GAP
	var middle := _segment_angle(index)
	var points := PackedVector2Array()
	for step in ARC_STEPS + 1:
		points.append(center + Vector2.from_angle(middle - half + 2.0 * half * step / ARC_STEPS) * outer)
	for step in range(ARC_STEPS, -1, -1):
		points.append(center + Vector2.from_angle(middle - half + 2.0 * half * step / ARC_STEPS) * INNER_RADIUS)
	return points
