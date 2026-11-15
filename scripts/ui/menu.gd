class_name Menu
extends CanvasLayer
## Ekran startowy: konto gracza, tryb gry, adres serwera, dolaczanie i hostowanie.
## Ze Steamem nazwy nie da sie zmienic, a bez niego gracz wpisuje nick.

signal settings_requested
signal stats_requested
signal arsenal_requested

const PICKER_LEFT := 520.0
const ACCOUNT_AVATAR_SIDE := 56.0
const INTRO_STAGGER_SECONDS := 0.06
## Kolejnosc kart trybow: Team Deathmatch stoi przy zwyklym Deathmatchu.
const MODE_ORDER: Array[int] = [GameMode.Id.DEATHMATCH, GameMode.Id.TEAM_DEATHMATCH, GameMode.Id.ROUNDS, GameMode.Id.BATTLE_ROYALE]
## Wybrany tryb jest jasny z ciemnym tekstem, pozostale neutralne.
const MODE_ON_FILL := UiStyle.INK
const MODE_ON_TEXT := UiStyle.DEEP
const VERSION_MARGIN := 16.0
## Przyciemnienie od lewej krawedzi, zeby panel i tytul czytaly sie na kazdym tle.
const SHADE_WIDTH := 0.62
const SHADE_ALPHA := 0.82

var _name_field: LineEdit
var _account_name: Label
var _address_field: LineEdit
var _status: Label
var _mode := GameMode.Id.DEATHMATCH
var _mode_buttons := {}
var _mode_hint: Label
var _join_button: Button
var _host_button: Button
var _picker: CharacterPicker
var _title: Control
var _card: PanelContainer
var _version_label: Label


func _ready() -> void:
	UiStyle.apply_font()
	_build_shade()
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 72)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)
	_build_version_label()
	add_child(UpdateNotice.new())

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 20)
	root.add_child(side)

	_title = _build_title()
	side.add_child(_title)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(430, 0)
	var card_style := UiStyle.sticker(UiStyle.PAPER, 18)
	card_style.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", card_style)
	side.add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_card.add_child(column)

	if SteamAccount.active:
		column.add_child(_build_account_card())
	else:
		column.add_child(UiStyle.eyebrow("Twój nick"))
		_name_field = UiStyle.field(Settings.player_value("name", "Gracz"), "Nick")
		_name_field.max_length = GameState.MAX_NAME_LENGTH
		column.add_child(_name_field)

	column.add_child(_gap(4))
	column.add_child(UiStyle.eyebrow("Tryb gry"))
	column.add_child(_build_mode_picker())

	column.add_child(_gap(4))
	column.add_child(UiStyle.eyebrow("Adres serwera"))
	_address_field = UiStyle.field(Settings.player_value("address", ""), "np. 203.0.113.10")
	column.add_child(_address_field)

	column.add_child(_gap(8))

	_join_button = UiStyle.button("Dołącz do gry", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.NONE)
	_join_button.custom_minimum_size.y = 50
	_join_button.add_theme_font_size_override("font_size", 22)
	_join_button.pressed.connect(_on_join)
	column.add_child(_join_button)

	_host_button = UiStyle.secondary_button("Hostuj na tym komputerze", Sfx.UiCue.NONE)
	_host_button.add_theme_font_size_override("font_size", 18)
	_host_button.pressed.connect(_on_host)
	column.add_child(_host_button)

	var settings_button := UiStyle.secondary_button("Ustawienia", Sfx.UiCue.NONE)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	var stats_button := UiStyle.secondary_button("Statystyki", Sfx.UiCue.NONE)
	stats_button.pressed.connect(func() -> void: stats_requested.emit())
	var arsenal_button := UiStyle.secondary_button("Zbrojownia", Sfx.UiCue.NONE)
	arsenal_button.name = "arsenal_button"
	arsenal_button.pressed.connect(func() -> void: arsenal_requested.emit())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for button: Button in [settings_button, stats_button, arsenal_button]:
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	column.add_child(row)

	if not Net.is_headless:
		_build_picker()

	_status = UiStyle.label("", 17, UiStyle.CORAL, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	if not Net.is_headless:
		_play_intro.call_deferred()


## Numer wpisuje CI z tagu wydania. Bez tego gra uruchomiona z edytora pokazuje "dev".
func _build_version_label() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	_version_label = UiStyle.label("dev" if version == "dev" else "v" + version, 14, Color(UiStyle.INK, 0.7), false)
	_version_label.add_theme_color_override("font_outline_color", UiStyle.DEEP)
	_version_label.add_theme_constant_override("outline_size", 4)
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(VERSION_MARGIN))
	_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_version_label)


## Przelacznik: wybrany tryb jest jasny, pozostale neutralne. Wszystkie zawsze widac.
func _build_mode_picker() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	# Cztery tryby w siatce 2 x 2, zeby kazda nazwa miescila sie w jednej linii.
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	box.add_child(row)
	for id: int in MODE_ORDER:
		var button := UiStyle.secondary_button(GameMode.title_of(id), Sfx.UiCue.PRESS)
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size = Vector2(0.0, 38.0)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 4
			style.content_margin_bottom = 4
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_mode.bind(id))
		row.add_child(button)
		_mode_buttons[id] = button
	_mode_hint = UiStyle.label("", 14, Color(UiStyle.INK, 0.6), false)
	_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mode_hint)
	var saved := GameMode.from_key(Settings.player_value("mode", GameMode.key_of(GameMode.Id.DEATHMATCH)))
	_select_mode(saved if saved >= 0 else GameMode.Id.DEATHMATCH)
	return box


func _select_mode(id: int) -> void:
	_mode = id
	_mode_hint.text = GameMode.hint_of(id)
	for other: int in _mode_buttons:
		var on := other == id
		UiStyle.paint_button(_mode_buttons[other], MODE_ON_FILL if on else UiStyle.NEUTRAL, MODE_ON_TEXT if on else UiStyle.INK)


## Awatar konta Steam, a obok nazwa.
func _build_account_card() -> Control:
	var card := PanelContainer.new()
	var style := UiStyle.flat(UiStyle.PANEL_2, 4)
	style.set_content_margin_all(10)
	style.content_margin_right = 16
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * ACCOUNT_AVATAR_SIDE
	row.add_child(holder)
	var avatar := AvatarView.new(SteamAccount.steam_id, SteamAccount.persona_name, ACCOUNT_AVATAR_SIDE)
	holder.add_child(avatar)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	texts.add_child(UiStyle.eyebrow("Grasz jako"))
	_account_name = UiStyle.label(SteamAccount.persona_name, 24)
	_account_name.clip_text = true
	_account_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_account_name)
	return card


## Postac stoi po prawej stronie, obok nicku i adresu.
func _build_picker() -> void:
	var anchor := CenterContainer.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.offset_left = PICKER_LEFT
	add_child(anchor)
	_picker = CharacterPicker.new()
	anchor.add_child(_picker)


func show_with_message(message: String) -> void:
	visible = true
	_status.text = message
	_set_busy(false)
	# Pusty powod to wlasne rozlaczenie, a tekst to np. utracone polaczenie.
	if not message.is_empty():
		UiSound.play(Sfx.UiCue.ERROR)
		UiStyle.shake(_card)


## Tytul i panel wchodza po kolei. Czekamy na pierwsza klatke, bo po wczytaniu sceny
## animacja przeskoczylaby do konca.
func _play_intro() -> void:
	_title.modulate.a = 0.0
	_card.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	UiStyle.pop_in(_title)
	UiStyle.pop_in(_card, INTRO_STAGGER_SECONDS)


## Napis gry: waska, gruba czcionka i cienka kreska w kolorze akcentu.
func _build_title() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var accent := ColorRect.new()
	accent.color = UiStyle.CORAL
	accent.custom_minimum_size = Vector2(44, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(accent)
	var title := UiStyle.display_label("GIERA", 64)
	title.add_theme_constant_override("line_spacing", -12)
	column.add_child(title)
	column.add_child(UiStyle.eyebrow("Multiplayer FPS", 14, Color(UiStyle.INK, 0.7)))
	return column


## Ciemny gradient od lewej krawedzi pod tytulem i panelem.
func _build_shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiStyle.DEEP, SHADE_ALPHA))
	gradient.set_color(1, Color(UiStyle.DEEP, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(1.0, 0.0)
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.anchor_right = SHADE_WIDTH
	add_child(shade)


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _on_join() -> void:
	var parts := _address_field.text.strip_edges().rsplit(":", true, 1)
	var address := parts[0]
	if address.is_empty():
		_fail("Wpisz adres serwera.", _address_field)
		return
	_apply_settings()
	var port := GameMode.port_for_address(int(parts[1]) if parts.size() == 2 else 0, _mode)
	var error := Net.join(address, port)
	if not error.is_empty():
		_fail(error, _address_field)
		return
	_status.text = "Łączenie…"
	UiSound.play(Sfx.UiCue.CONFIRM)
	_set_busy(true)


func _on_host() -> void:
	_apply_settings()
	var error := Net.start_server(GameMode.port_of(_mode), false, _mode)
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
	if _name_field != null:
		Net.player_name = _name_field.text
		Settings.set_player_value("name", _name_field.text)
	if _picker != null:
		Net.player_character = _picker.selected_id()
	Settings.set_player_value("address", _address_field.text)
	Settings.set_player_value("mode", GameMode.key_of(_mode))


func _set_busy(busy: bool) -> void:
	_join_button.disabled = busy
	_host_button.disabled = busy
