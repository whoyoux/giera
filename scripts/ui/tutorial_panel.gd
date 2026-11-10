class_name TutorialPanel
extends PanelContainer
## Samouczek klawiszy przy pierwszym wejsciu do gry. Pokazuje klawisze z ustawien gracza, a nie
## domyslne. Stoi w lewej kolumnie HUD i znika po kilku sekundach, po nacisnieciu Enter albo przy
## pierwszych obrazeniach zadanych lub otrzymanych. Drugi raz sie nie pokazuje.

const SECONDS := 14.0
const KEY := "tutorial_done"
const GROUP := &"tutorial"
const CHIP_SIDE := 20.0
const CHIP_FONT := 12
const TEXT_SIZE := 13
## Jedna kolumna, najwyzej siedem wierszy. Wiersz to pary: klawisze i opis.
const STEPS: Array[Array] = [
	[[["move_forward", "move_left", "move_back", "move_right"], "ruch"]],
	[[["jump"], "skok"], [["sprint"], "sprint"]],
	[[["crouch"], "kucanie i ślizg"]],
	[[["fire"], "strzał"], [["aim"], "celowanie"]],
	[[["reload"], "przeładuj"], [["interact"], "podnieś"]],
	[[["dance"], "tańce"], [["scoreboard"], "wyniki"]],
	[[["map"], "mapa (Battle Royale)"]],
]

var _left := SECONDS


static func should_show() -> bool:
	# Narzedzia testowe i zrzuty do README graja bez samouczka.
	return Settings.player_value(KEY, "") != "1" and Net.bot_mode.is_empty() and not Net.args.has("tool")


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := UiStyle.sticker(UiStyle.PAPER, 16, 4)
	style.set_content_margin_all(4 + 8)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.add_child(UiStyle.label("Twoje klawisze", 14, UiStyle.BLUE))
	for step in STEPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for index in step.size():
			var pair: Array = step[index]
			if index > 0:
				row.add_child(UiStyle.label("·", TEXT_SIZE, Color(UiStyle.INK, 0.4)))
			for action: String in pair[0]:
				row.add_child(ActionChip.create(action, CHIP_SIDE, CHIP_FONT))
			row.add_child(UiStyle.label(pair[1], TEXT_SIZE, UiStyle.INK, false))
		column.add_child(row)
	column.add_child(UiStyle.label("Esc → Ustawienia · Enter zamyka", TEXT_SIZE, Color(UiStyle.INK, 0.65), false))
	# Pierwsza walka konczy nauke: samouczek nie moze przeszkadzac w strzelaniu.
	GameState.hit_details.connect(func(_details: Dictionary) -> void: queue_free())
	GameState.damaged.connect(func(_amount: int, _attacker: int, _source: Vector3) -> void: queue_free())
	UiStyle.pop_in(self)
	Settings.set_player_value(KEY, "1")


func _process(delta: float) -> void:
	_left -= delta
	if _left < 1.0:
		modulate.a = maxf(_left, 0.0)
	if _left <= 0.0:
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ENTER:
		queue_free()
