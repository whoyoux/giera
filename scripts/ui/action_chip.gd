class_name ActionChip
extends PanelContainer
## Klawisz w podpowiedzi, ktory sam pokazuje aktualne przypisanie akcji z ustawien.

var action := ""
var _label: Label


static func create(action_name: String, chip_size: float, font_size: int) -> ActionChip:
	var chip := ActionChip.new()
	chip.action = action_name
	chip.custom_minimum_size = Vector2.ONE * chip_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.chip_box()
	style.content_margin_left = 8
	style.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", style)
	chip._label = UiStyle.label("", font_size, Color.WHITE)
	chip._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip._label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(chip._label)
	chip.refresh()
	return chip


func _enter_tree() -> void:
	if not Settings.changed.is_connected(refresh):
		Settings.changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if Settings.changed.is_connected(refresh):
		Settings.changed.disconnect(refresh)


func text() -> String:
	return _label.text


func refresh() -> void:
	if _label != null:
		_label.text = Keybinds.label_of(action)
