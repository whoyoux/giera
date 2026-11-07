class_name KeybindPage
extends VBoxContainer
## Strona ustawien ze zmiana klawiszy: klikniecie w wiersz czeka na nastepny klawisz albo przycisk myszy.

const ROW_HEIGHT := 36.0
const BUTTON_WIDTH := 170.0
const WAITING := "Naciśnij…"

var _buttons := {}
var _notice: Label
var _waiting_for := ""


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_notice = UiStyle.label("Kliknij wiersz i naciśnij nowy klawisz. Esc anuluje.", 16, Color(UiStyle.INK, 0.7), false)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_notice)
	for entry: Dictionary in Keybinds.ACTIONS:
		add_child(_row(entry))
	var reset := UiStyle.button("Domyślne klawisze", UiStyle.TEAL)
	reset.name = "reset_keys"
	reset.pressed.connect(reset_all)
	# Przycisk lekko sie przechyla i ma cien, wiec potrzebuje miejsca, zeby lista go nie ucinala.
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_child(reset)
	add_child(margin)
	refresh()


## Czy strona czeka na klawisz. Wtedy Esc nie zamyka okna ustawien.
func is_waiting() -> bool:
	return not _waiting_for.is_empty()


func cancel() -> void:
	_waiting_for = ""
	refresh()


func begin_capture(action: String) -> void:
	_waiting_for = action
	refresh()
	(_buttons[action] as Button).text = WAITING


func reset_all() -> void:
	_waiting_for = ""
	Settings.reset_keybinds()
	refresh()
	_notice.text = "Przywrócono domyślne klawisze."


func refresh() -> void:
	var conflicting := Keybinds.conflicts()
	for action: String in _buttons:
		var button := _buttons[action] as Button
		button.text = Keybinds.label_of(action)
		button.modulate = UiStyle.CORAL if conflicting.has(action) else Color.WHITE


func _input(event: InputEvent) -> void:
	if not is_waiting() or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if (key == null or not key.pressed or key.echo) and (mouse == null or not mouse.pressed):
		return
	get_viewport().set_input_as_handled()
	# Esc anuluje, ale sama pauze wolno ustawic z powrotem na Esc.
	if key != null and key.physical_keycode == KEY_ESCAPE and _waiting_for != "pause":
		cancel()
		return
	var action := _waiting_for
	_waiting_for = ""
	var swapped := Settings.assign_keybind(action, event)
	refresh()
	_notice.text = "Klawisz był zajęty, więc „%s” dostaje poprzedni." % swapped if not swapped.is_empty() else "Zapisano."


func _row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var caption := UiStyle.label(entry.label, 19, UiStyle.INK, false)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var button := UiStyle.button("", UiStyle.BLUE, Color.WHITE, Sfx.UiCue.PRESS)
	button.name = "bind_%s" % entry.action
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, ROW_HEIGHT)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(begin_capture.bind(entry.action))
	row.add_child(button)
	_buttons[entry.action] = button
	return row
