class_name TutorialPanel
extends PanelContainer
## Samouczek klawiszy przy pierwszym wejsciu do gry. Pokazuje klawisze z ustawien gracza, a nie
## domyslne, i znika po kilku sekundach albo po nacisnieciu Enter. Drugi raz sie nie pokazuje.

const SECONDS := 14.0
const KEY := "tutorial_done"
const STEPS: Array[Array] = [
	[["move_forward", "move_left", "move_back", "move_right"], "ruch"],
	[["jump"], "skok"], [["crouch"], "kucanie i ślizg"], [["sprint"], "sprint"],
	[["fire"], "strzał"], [["aim"], "celowanie i luneta"], [["reload"], "przeładowanie"],
	[["interact"], "podnieś, otwórz"], [["dance"], "koło tańców"],
	[["scoreboard"], "wyniki"], [["map"], "mapa (Battle Royale)"],
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
	column.add_child(UiStyle.label("Twoje klawisze:", 19, UiStyle.BLUE))
	# Dwie kolumny, zeby samouczek miescil sie pod lista zabojstw.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for step in STEPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for action: String in step[0]:
			row.add_child(ActionChip.create(action, 24, 13))
		row.add_child(UiStyle.label(step[1], 14, UiStyle.INK, false))
		grid.add_child(row)
	column.add_child(UiStyle.label("Zmiana: Esc → Ustawienia. Enter zamyka.", 13, Color(UiStyle.INK, 0.65), false))
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
