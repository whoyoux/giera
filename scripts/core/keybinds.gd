class_name Keybinds
extends RefCounted
## Klawisze gracza. Kazda akcja ma jeden klawisz albo przycisk myszy, a zapis trafia do settings.cfg.
## Domyslne wartosci pochodza z project.godot, wiec nowa akcje wystarczy dopisac do ACTIONS.

const SECTION := "bindings"
## Kolejnosc jak w panelu ustawien.
const ACTIONS: Array[Dictionary] = [
	{ "action": "move_forward", "label": "Do przodu" },
	{ "action": "move_back", "label": "Do tyłu" },
	{ "action": "move_left", "label": "W lewo" },
	{ "action": "move_right", "label": "W prawo" },
	{ "action": "jump", "label": "Skok" },
	{ "action": "crouch", "label": "Kucanie" },
	{ "action": "sprint", "label": "Sprint" },
	{ "action": "fire", "label": "Strzał" },
	{ "action": "aim", "label": "Celowanie" },
	{ "action": "reload", "label": "Przeładowanie" },
	{ "action": "slot_1", "label": "Slot 1" },
	{ "action": "slot_2", "label": "Slot 2" },
	{ "action": "slot_3", "label": "Slot 3" },
	{ "action": "slot_4", "label": "Slot 4" },
	{ "action": "next_slot", "label": "Następny przedmiot" },
	{ "action": "prev_slot", "label": "Poprzedni przedmiot" },
	{ "action": "interact", "label": "Podnieś i otwórz" },
	{ "action": "drop_item", "label": "Wyrzuć przedmiot" },
	{ "action": "toggle_ready", "label": "Gotowość w lobby" },
	{ "action": "dance", "label": "Koło tańców" },
	{ "action": "chat", "label": "Czat" },
	{ "action": "team_chat", "label": "Czat drużyny" },
	{ "action": "team_select", "label": "Wybór drużyny" },
	{ "action": "scoreboard", "label": "Tabela wyników" },
	{ "action": "map", "label": "Duża mapa" },
	{ "action": "pause", "label": "Pauza" },
]
const KEY_NAMES := {
	KEY_SPACE: "Spacja", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab",
	KEY_ESCAPE: "Esc", KEY_ENTER: "Enter", KEY_BACKSPACE: "Backspace", KEY_CAPSLOCK: "Caps",
	KEY_UP: "Góra", KEY_DOWN: "Dół", KEY_LEFT: "Lewo", KEY_RIGHT: "Prawo",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "LPM", MOUSE_BUTTON_RIGHT: "PPM", MOUSE_BUTTON_MIDDLE: "ŚPM",
	MOUSE_BUTTON_WHEEL_UP: "Kółko w górę", MOUSE_BUTTON_WHEEL_DOWN: "Kółko w dół",
	MOUSE_BUTTON_XBUTTON1: "Mysz 4", MOUSE_BUTTON_XBUTTON2: "Mysz 5",
}

static var _defaults := {}


## Zapamietuje domyslne klawisze i naklada na nie te zapisane. Wolane na starcie gry.
static func load_from(config: ConfigFile) -> void:
	for entry: Dictionary in ACTIONS:
		var action: String = entry.action
		if not _defaults.has(action):
			_defaults[action] = code_of(action)
		var saved: String = config.get_value(SECTION, action, "")
		_apply(action, saved if decode(saved) != null else _defaults[action])


## Przypisuje klawisz. Gdy zajmuje go inna akcja, dostaje ona poprzedni klawisz tej akcji,
## wiec zadna nie zostaje bez przycisku. Zwraca nazwe tej drugiej akcji albo pusty tekst.
static func assign(config: ConfigFile, action: String, event: InputEvent) -> String:
	var code := encode(event)
	if code.is_empty() or code == code_of(action):
		return ""
	var previous := code_of(action)
	var swapped := ""
	for entry: Dictionary in ACTIONS:
		if entry.action != action and code_of(entry.action) == code:
			swapped = entry.label
			_store(config, entry.action, previous)
	_store(config, action, code)
	return swapped


static func reset(config: ConfigFile) -> void:
	if config.has_section(SECTION):
		config.erase_section(SECTION)
	for action: String in _defaults:
		_apply(action, _defaults[action])


## Akcje, ktore dziela klawisz z inna. Zdarza sie tylko po recznej edycji pliku ustawien.
static func conflicts() -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for entry: Dictionary in ACTIONS:
		var code := code_of(entry.action)
		if seen.has(code):
			result.append(entry.action)
			if not result.has(seen[code]):
				result.append(seen[code])
		seen[code] = entry.action
	return result


static func default_code(action: String) -> String:
	return _defaults.get(action, "")


static func code_of(action: String) -> String:
	return encode(_first_event(action))


## Nazwa klawisza do pokazania w grze, np. "E" albo "LPM".
static func label_of(action: String) -> String:
	return name_of(_first_event(action))


static func name_of(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var button: int = (event as InputEventMouseButton).button_index
		return MOUSE_NAMES.get(button, "Mysz %d" % button)
	if event is InputEventKey:
		var physical: Key = (event as InputEventKey).physical_keycode
		if KEY_NAMES.has(physical):
			return KEY_NAMES[physical]
		# Na innym ukladzie klawiatury ten sam fizyczny klawisz ma inny napis.
		var shown := physical if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(physical)
		return OS.get_keycode_string(shown)
	return "—"


## Napis do pliku: "key:87" albo "mouse:1". Pusty, gdy nie mozna przypisac takiego zdarzenia.
static func encode(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventKey:
		var key := event as InputEventKey
		var physical: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % physical if physical != KEY_NONE else ""
	return ""


static func decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int() or int(parts[1]) <= 0:
		return null
	if parts[0] == "mouse":
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(parts[1]) as MouseButton
		return mouse
	if parts[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = int(parts[1]) as Key
		return key
	return null


static func _store(config: ConfigFile, action: String, code: String) -> void:
	config.set_value(SECTION, action, code)
	_apply(action, code)


static func _apply(action: String, code: String) -> void:
	var event := decode(code)
	if event == null or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


static func _first_event(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var events := InputMap.action_get_events(action)
	return events[0] if not events.is_empty() else null
