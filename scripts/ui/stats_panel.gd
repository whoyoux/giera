class_name StatsPanel
extends CanvasLayer
## Okno z osobistymi statystykami, otwierane z menu glownego.

var _card: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	layer = 5
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(UiStyle.INK, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(420, 0)
	_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	var title := UiStyle.label("Twoje statystyki", 32, UiStyle.BLUE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	column.add_child(_rows)
	column.add_child(UiStyle.label("Zapisane tylko na tym komputerze.", 15, Color(UiStyle.INK, 0.6), false))
	var close := UiStyle.button("Gotowe", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.CLOSE)
	close.pressed.connect(func() -> void: visible = false)
	column.add_child(close)


func open(stats: PlayerStats) -> void:
	for child in _rows.get_children():
		child.free()
	for line in stats.summary():
		_rows.add_child(UiStyle.label(line, 20, UiStyle.INK, false))
	visible = true
	UiStyle.pop_in(_card)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		visible = false
		get_viewport().set_input_as_handled()
