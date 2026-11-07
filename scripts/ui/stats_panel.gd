class_name StatsPanel
extends CanvasLayer
## Okno z osobistymi statystykami, otwierane z menu glownego.

var _card: PanelContainer
var _rows: VBoxContainer
var _confirm: VBoxContainer
var _buttons: HBoxContainer
var _stats: PlayerStats


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
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_buttons)
	var reset := UiStyle.button("Wyczyść", UiStyle.TEAL, Color.WHITE, Sfx.UiCue.PRESS)
	reset.name = "reset_stats"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_ask_reset)
	_buttons.add_child(reset)
	var close := UiStyle.button("Gotowe", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.CLOSE)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: visible = false)
	_buttons.add_child(close)
	# Potwierdzenie: statystyki znikaja dopiero po drugim kliknieciu.
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 10)
	_confirm.visible = false
	column.add_child(_confirm)
	var question := UiStyle.label("Na pewno usunąć wszystkie statystyki? Tego nie da się cofnąć.", 18, UiStyle.CORAL, false)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(question)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 10)
	_confirm.add_child(answers)
	var yes := UiStyle.button("Usuń", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.CONFIRM)
	yes.name = "confirm_reset"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_confirm_reset)
	answers.add_child(yes)
	var no := UiStyle.button("Anuluj", UiStyle.BLUE, Color.WHITE, Sfx.UiCue.BACK)
	no.name = "cancel_reset"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_show_confirm.bind(false))
	answers.add_child(no)


func open(stats: PlayerStats) -> void:
	_stats = stats
	_fill()
	_show_confirm(false)
	visible = true
	UiStyle.pop_in(_card)


func _fill() -> void:
	for child in _rows.get_children():
		child.free()
	for line in _stats.summary():
		_rows.add_child(UiStyle.label(line, 20, UiStyle.INK, false))


func _ask_reset() -> void:
	_show_confirm(true)


func _show_confirm(shown: bool) -> void:
	_confirm.visible = shown
	_buttons.visible = not shown
	if shown:
		UiStyle.pop_in(_confirm)


func _confirm_reset() -> void:
	_stats.reset()
	_fill()
	_show_confirm(false)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		visible = false
		get_viewport().set_input_as_handled()
