class_name Menu
extends CanvasLayer
## Ekran startowy: nick, adres serwera, dolaczanie i hostowanie.

signal settings_requested

const PICKER_LEFT := 520.0
const TITLE_COLORS: Array[Color] = [UiStyle.CORAL, UiStyle.SUN, UiStyle.TEAL, UiStyle.BLUE, Color("9b7bff")]
## Literki tytulu sa strojone pentatonicznie, wiec kazde przejechanie kursorem brzmi ladnie.
const TITLE_NOTES: Array[float] = [1.0, 1.122, 1.26, 1.498, 1.682]
const LETTER_POP_SCALE := 1.16
const LETTER_POP_SECONDS := 0.32
const INTRO_STAGGER_SECONDS := 0.05

var _name_field: LineEdit
var _address_field: LineEdit
var _status: Label
var _join_button: Button
var _host_button: Button
var _picker: CharacterPicker
var _letters: Array[Control] = []
var _card: PanelContainer
var _time := 0.0


func _ready() -> void:
	UiStyle.apply_font()
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 72)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 20)
	root.add_child(side)

	side.add_child(_build_title())

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(430, 0)
	_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	side.add_child(_card)

	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	_card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	column.add_child(UiStyle.label("Twój nick", 17, UiStyle.INK, false))
	_name_field = UiStyle.field(Settings.player_value("name", "Gracz"), "Nick")
	_name_field.max_length = GameState.MAX_NAME_LENGTH
	column.add_child(_name_field)

	column.add_child(UiStyle.label("Adres serwera", 17, UiStyle.INK, false))
	_address_field = UiStyle.field(Settings.player_value("address", ""), "np. 203.0.113.10")
	column.add_child(_address_field)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	column.add_child(gap)

	_join_button = UiStyle.button("Dołącz do gry", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.NONE)
	_join_button.pressed.connect(_on_join)
	column.add_child(_join_button)

	_host_button = UiStyle.button("Hostuj na tym komputerze", UiStyle.TEAL, Color.WHITE, Sfx.UiCue.NONE)
	_host_button.add_theme_font_size_override("font_size", 20)
	_host_button.pressed.connect(_on_host)
	column.add_child(_host_button)

	var settings_button := UiStyle.button("Ustawienia", UiStyle.BLUE, Color.WHITE, Sfx.UiCue.NONE)
	settings_button.add_theme_font_size_override("font_size", 20)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	column.add_child(settings_button)

	if not Net.is_headless:
		_build_picker()

	_status = UiStyle.label("", 17, UiStyle.CORAL, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	if not Net.is_headless:
		_play_intro.call_deferred()


## Postac stoi po prawej stronie, obok nicku i adresu.
func _build_picker() -> void:
	var anchor := CenterContainer.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.offset_left = PICKER_LEFT
	add_child(anchor)
	_picker = CharacterPicker.new()
	anchor.add_child(_picker)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in _letters.size():
		_letters[i].position.y = sin(_time * 2.2 + i * 0.8) * 5.0


func show_with_message(message: String) -> void:
	visible = true
	_status.text = message
	_set_busy(false)
	# Pusty powod to wlasne rozlaczenie, a tekst to np. utracone polaczenie.
	if not message.is_empty():
		UiSound.play(Sfx.UiCue.ERROR)
		UiStyle.shake(_card)


## Tytul wskakuje litera po literze, a reszta zaraz za nim. Czekamy na pierwsza klatke,
## bo po wczytaniu sceny animacja przeskoczylaby do konca.
func _play_intro() -> void:
	for tile in _letters:
		tile.modulate.a = 0.0
	_card.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	for i in _letters.size():
		UiStyle.pop_in(_letters[i], i * INTRO_STAGGER_SECONDS)
	UiStyle.pop_in(_card, _letters.size() * INTRO_STAGGER_SECONDS)


func _build_title() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var text := "GIERA"
	for i in text.length():
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76, 84)
		row.add_child(holder)
		var tile := PanelContainer.new()
		tile.size = Vector2(72, 80)
		tile.pivot_offset = tile.size * 0.5
		tile.rotation_degrees = [-5.0, 3.0, -2.0, 5.0, -4.0][i]
		tile.add_theme_stylebox_override("panel", UiStyle.sticker(TITLE_COLORS[i], 16, 5))
		var letter := UiStyle.label(text[i], 46, Color.WHITE)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(letter)
		holder.add_child(tile)
		_letters.append(tile)
		tile.mouse_entered.connect(_poke_letter.bind(tile, TITLE_NOTES[i]))
	return row


func _poke_letter(tile: Control, note: float) -> void:
	if UiSound.can_hover():
		UiSound.play(Sfx.UiCue.NOTE, note)
	tile.scale = Vector2.ONE * LETTER_POP_SCALE
	tile.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).tween_property(tile, "scale", Vector2.ONE, LETTER_POP_SECONDS)


func _on_join() -> void:
	var parts := _address_field.text.strip_edges().rsplit(":", true, 1)
	var address := parts[0]
	if address.is_empty():
		_fail("Wpisz adres serwera.", _address_field)
		return
	_apply_settings()
	var port := int(parts[1]) if parts.size() == 2 else Net.DEFAULT_PORT
	var error := Net.join(address, port)
	if not error.is_empty():
		_fail(error, _address_field)
		return
	_status.text = "Łączenie…"
	UiSound.play(Sfx.UiCue.CONFIRM)
	_set_busy(true)


func _on_host() -> void:
	_apply_settings()
	var error := Net.start_server()
	if not error.is_empty():
		_fail(error, _host_button)
		return
	_status.text = ""
	UiSound.play(Sfx.UiCue.CONFIRM)


## Mowi co poszlo nie tak, pokazuje gdzie i ustawia tam kursor, zeby od razu poprawic.
func _fail(message: String, culprit: Control) -> void:
	_status.text = message
	_set_busy(false)
	UiSound.play(Sfx.UiCue.ERROR)
	UiStyle.shake(culprit)
	if culprit is LineEdit:
		culprit.grab_focus()


func _apply_settings() -> void:
	Net.player_name = _name_field.text
	if _picker != null:
		Net.player_character = _picker.selected_id()
	Settings.set_player_value("name", _name_field.text)
	Settings.set_player_value("address", _address_field.text)


func _set_busy(busy: bool) -> void:
	_join_button.disabled = busy
	_host_button.disabled = busy
