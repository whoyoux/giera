class_name LoadoutPanel
extends Control
## Tryb Rundy: wybor zestawu broni w czasie, gdy gracze stoja w bazach. Cztery karty w siatce 2 x 2
## nad paskiem przedmiotow, wybor klawiszami slotow (domyslnie 1-4). Wybrany zestaw ma niebieska
## krawedz. Siatka jest waska, zeby nie nachodzila na czat po lewej.
## Panel znika, gdy rusza walka, wiec nie zaslania gry.

const CARD_SIZE := Vector2(172, 76)
const CARD_GAP := 8
## Dolna krawedz kart nad podpowiedzia i nazwa przedmiotu.
const BOTTOM := 186.0

var _row: GridContainer
var _cards: Array[PanelContainer] = []
var _keys: Array[Label] = []
var _shown_choice := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.position.y -= BOTTOM
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_row = GridContainer.new()
	_row.columns = 2
	_row.add_theme_constant_override("h_separation", CARD_GAP)
	_row.add_theme_constant_override("v_separation", CARD_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_row)
	for index in Loadouts.count():
		_row.add_child(_build_card(index))
	visible = false
	Settings.changed.connect(_refresh_keys)
	_refresh_keys()


func _process(_delta: float) -> void:
	var me: Dictionary = GameState.players.get(multiplayer.get_unique_id(), {})
	var showing: bool = Net.in_session and Match.in_buy_time() and not me.is_empty() and me.alive and me.get("team", Teams.NONE) != Teams.NONE
	if showing and not visible:
		UiStyle.pop_in(self)
	visible = showing
	if showing:
		_show_choice(me.get("loadout", Loadouts.DEFAULT))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for index in Loadouts.count():
		if event.is_action_pressed("slot_%d" % (index + 1)):
			choose(index)


## Wybor zestawu. Serwer podmienia bron od razu, bo trwa czas wyboru.
func choose(index: int) -> void:
	var me: Dictionary = GameState.players.get(multiplayer.get_unique_id(), {})
	if me.get("loadout", Loadouts.DEFAULT) == index:
		return
	Match.request_loadout(index)
	UiSound.play(Sfx.UiCue.CONFIRM)


func _show_choice(index: int) -> void:
	if index == _shown_choice:
		return
	_shown_choice = index
	for card_index in _cards.size():
		_cards[card_index].add_theme_stylebox_override("panel", _card_style(card_index == index))


func _refresh_keys() -> void:
	for index in _keys.size():
		_keys[index].text = Keybinds.label_of("slot_%d" % (index + 1))


func _build_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _card_style(false))
	_cards.append(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var chip := UiStyle.key_chip("", 22, 13)
	top.add_child(chip)
	_keys.append(chip.get_child(0) as Label)
	var name_label := UiStyle.label(Loadouts.name_of(index), 16, UiStyle.INK)
	UiStyle.fit_width(name_label, CARD_SIZE.x - 54.0)
	top.add_child(name_label)
	var hint := UiStyle.label(Loadouts.hint_of(index), 13, Color(UiStyle.INK, 0.65), false)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = CARD_SIZE.x - 24.0
	column.add_child(hint)
	return card


func _card_style(selected: bool) -> StyleBoxFlat:
	var style := UiStyle.sticker(Color(UiStyle.BLUE, 0.22) if selected else UiStyle.HUD_FILL, 14)
	style.border_color = UiStyle.BLUE if selected else UiStyle.LINE
	style.set_border_width_all(2 if selected else UiStyle.BORDER)
	style.set_content_margin_all(10)
	return style
