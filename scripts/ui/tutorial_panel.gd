class_name TutorialPanel
extends PanelContainer
## Samouczek klawiszy przy pierwszym wejsciu do gry. Pokazuje klawisze z ustawien gracza, a nie
## domyslne, i znika po kilku sekundach albo po nacisnieciu Enter. Drugi raz sie nie pokazuje.

const SECONDS := 14.0
const KEY := "tutorial_done"
const STEPS: Array[Array] = [
	[["move_forward", "move_left", "move_back", "move_right"], "ruch"],
	[["jump"], "skok"], [["crouch"], "kucanie, a w sprincie ślizg"], [["sprint"], "sprint"],
	[["fire"], "strzał"], [["aim"], "celowanie i luneta"], [["reload"], "przeładowanie"],
	[["interact"], "podnieś albo otwórz skrzynkę"], [["dance"], "koło tańców"],
	[["scoreboard"], "wyniki"], [["map"], "duża mapa w Battle Royale"],
]

var _left := SECONDS


static func should_show() -> bool:
	# Narzedzia testowe i zrzuty do README graja bez samouczka.
	return Settings.player_value(KEY, "") != "1" and Net.bot_mode.is_empty() and not Net.args.has("tool")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 22, 6))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(UiStyle.label("Witaj w grze! Twoje klawisze:", 22, UiStyle.BLUE))
	for step in STEPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for action: String in step[0]:
			row.add_child(ActionChip.create(action, 30, 15))
		row.add_child(UiStyle.label(step[1], 17, UiStyle.INK, false))
		column.add_child(row)
	column.add_child(UiStyle.label("Zmienisz je w Esc → Ustawienia → Klawisze. Enter zamyka.", 15, Color(UiStyle.INK, 0.65), false))
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
