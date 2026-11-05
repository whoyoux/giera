class_name Menu
extends CanvasLayer
## Ekran startowy: nick, adres serwera, dolaczanie i hostowanie.

const SETTINGS_PATH := "user://settings.cfg"

var _name_field: LineEdit
var _address_field: LineEdit
var _status: Label
var _join_button: Button
var _host_button: Button


func _ready() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)

	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PAPER, 5, 20))
	root.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	box.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := UiStyle.label("GIERA", 58, UiStyle.ACCENT, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	column.add_child(_caption("Twój nick"))
	_name_field = UiStyle.field(settings.get_value("player", "name", "Gracz"), "Nick")
	_name_field.max_length = GameState.MAX_NAME_LENGTH
	column.add_child(_name_field)

	column.add_child(_caption("Adres serwera"))
	_address_field = UiStyle.field(settings.get_value("player", "address", ""), "np. 203.0.113.10")
	column.add_child(_address_field)

	_join_button = UiStyle.button("Dołącz", UiStyle.ACCENT)
	_join_button.pressed.connect(_on_join)
	column.add_child(_join_button)

	_host_button = UiStyle.button("Hostuj grę na tym komputerze", UiStyle.TEAL)
	_host_button.pressed.connect(_on_host)
	column.add_child(_host_button)

	_status = Label.new()
	_status.add_theme_color_override("font_color", UiStyle.DANGER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)


func show_with_message(message: String) -> void:
	visible = true
	_status.text = message
	_set_busy(false)


func _caption(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_color_override("font_color", UiStyle.INK)
	node.add_theme_font_size_override("font_size", 16)
	return node


func _on_join() -> void:
	var parts := _address_field.text.strip_edges().rsplit(":", true, 1)
	var address := parts[0]
	if address.is_empty():
		_status.text = "Wpisz adres serwera."
		return
	_apply_settings()
	var port := int(parts[1]) if parts.size() == 2 else Net.DEFAULT_PORT
	var error := Net.join(address, port)
	_status.text = error if not error.is_empty() else "Łączenie…"
	_set_busy(error.is_empty())


func _on_host() -> void:
	_apply_settings()
	_status.text = Net.start_server()


func _apply_settings() -> void:
	Net.player_name = _name_field.text
	var settings := ConfigFile.new()
	settings.set_value("player", "name", _name_field.text)
	settings.set_value("player", "address", _address_field.text)
	settings.save(SETTINGS_PATH)


func _set_busy(busy: bool) -> void:
	_join_button.disabled = busy
	_host_button.disabled = busy
