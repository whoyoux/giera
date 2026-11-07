class_name ChatPanel
extends Control
## Czat nad paskiem zdrowia: nowe wiadomosci znikaja po chwili, a po otwarciu widac cala historie.

signal closed

const WIDTH := 340.0
const LOG_HEIGHT := 190.0
## Nad naklejka ze zdrowiem, takze gdy rosnie o napis o leczeniu.
const BOTTOM_OFFSET := 168.0
const LEFT_OFFSET := 28.0
const MAX_ROWS := 50
const MESSAGE_SECONDS := 8.0
const FADE_SECONDS := 0.4
const FONT_SIZE := 17
const NAME_LENGTH := 18
const ROW_PADDING := 24.0
## Bez zapasu zmierzona linijka potrafi zawinac sie o jeden znak za wczesnie.
const WIDTH_SLACK := 3.0

var is_open := false

var _column: VBoxContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _input_panel: PanelContainer
var _input: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Chat.message_received.connect(_on_message)
	Chat.cleared.connect(_on_cleared)


func open() -> void:
	is_open = true
	_input.text = ""
	_input_panel.visible = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_input.edit()
	UiStyle.pop_in(_input_panel)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_input_panel.visible = false
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for row: Control in _rows.get_children():
		var shown: bool = is_open or now < int(row.get_meta(&"visible_until_ms"))
		row.modulate.a = move_toward(row.modulate.a, 1.0 if shown else 0.0, delta / FADE_SECONDS)


func _on_message(sender_id: int, text: String) -> void:
	var mine := sender_id == multiplayer.get_unique_id()
	_rows.add_child(_message_row(_short_name(sender_id), text, UiStyle.CORAL if mine else UiStyle.BLUE))
	if _rows.get_child_count() > MAX_ROWS:
		_rows.get_child(0).free()
	if not mine:
		UiSound.play(Sfx.UiCue.NOTE)


func _on_cleared() -> void:
	close()
	for row in _rows.get_children():
		row.free()


func _on_submitted(text: String) -> void:
	if Chat.send(text):
		close()
		return
	# Za szybko: tekst zostaje w polu, zeby mozna go bylo wyslac za chwile.
	UiSound.play(Sfx.UiCue.ERROR)
	UiStyle.shake(_input_panel)
	_input.edit()


## Esc konczy pisanie w samym polu tekstowym, a Enter obsluguje _on_submitted.
func _on_editing_toggled(editing: bool) -> void:
	if not editing and is_open:
		close.call_deferred()


func _short_name(id: int) -> String:
	var full := GameState.display_name(id)
	return full if full.length() <= NAME_LENGTH else full.left(NAME_LENGTH - 1) + "…"


func _message_row(sender: String, text: String, name_color: Color) -> PanelContainer:
	var row := PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 14, 3)
	style.set_content_margin_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta(&"visible_until_ms", Time.get_ticks_msec() + int(MESSAGE_SECONDS * 1000.0))
	var line := UiStyle.rich_label(FONT_SIZE)
	# add_text nie czyta znacznikow, wiec tresc od gracza nie moze niczego sformatowac.
	line.push_color(name_color)
	line.push_bold()
	line.add_text(sender + ": ")
	line.pop_all()
	line.add_text(text)
	var width := UiStyle.text_width(sender + ": ", FONT_SIZE, true) + UiStyle.text_width(text, FONT_SIZE, false)
	line.custom_minimum_size.x = minf(width + WIDTH_SLACK, WIDTH - ROW_PADDING)
	row.add_child(line)
	return row


func _build() -> void:
	_column = VBoxContainer.new()
	_column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_column.position += Vector2(LEFT_OFFSET, -BOTTOM_OFFSET)
	_column.grow_horizontal = Control.GROW_DIRECTION_END
	_column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_column.custom_minimum_size.x = WIDTH
	_column.add_theme_constant_override("separation", 8)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = LOG_HEIGHT
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.alignment = BoxContainer.ALIGNMENT_END
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 5)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_rows)
	# Najnowsza wiadomosc zawsze jest na dole, tuz nad polem do pisania.
	var bar := _scroll.get_v_scroll_bar()
	bar.changed.connect(func() -> void: bar.value = bar.max_value)

	_input_panel = PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 16, 4)
	style.set_content_margin_all(5)
	_input_panel.add_theme_stylebox_override("panel", style)
	_input_panel.visible = false
	_column.add_child(_input_panel)
	_input = UiStyle.field("", "Enter wysyła, Esc zamyka")
	_input.custom_minimum_size.y = 40.0
	_input.add_theme_font_size_override("font_size", FONT_SIZE)
	_input.max_length = Chat.MAX_LENGTH
	_input.context_menu_enabled = false
	_input.keep_editing_on_text_submit = true
	_input.text_submitted.connect(_on_submitted)
	_input.editing_toggled.connect(_on_editing_toggled)
	_input_panel.add_child(_input)
