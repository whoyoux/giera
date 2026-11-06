extends Node
## Test czatu w oknie gry: T otwiera pole, pisanie nie steruje postacia, Enter wysyla, Esc zamyka.
## Uzycie: godot --path . --resolution 1280x720 -- --tool=res://tools/chat_test.gd [--shot=plik.png]

const PORT := 7815

var _failures := 0


func _ready() -> void:
	var main := get_node("/root/Main")
	var hud := main.get_node("Hud") as Hud
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var player := GameState.player_node(multiplayer.get_unique_id())
	# Okno testu moze nie miec fokusu, a sterowanie dziala tylko z przechwycona mysza.
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var chat := hud._chat

	await _tap(KEY_T, "t")
	_check("T otwiera czat", chat.is_open and chat._input.has_focus() and chat._input.is_editing())
	_check("T nie trafia do pola", chat._input.text.is_empty())
	_check("kursor jest wolny", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	var slot_before := player.input.selected_slot()
	for letter in "ewgb2":
		await _tap(OS.find_keycode_from_string(letter), letter)
	_check("litery trafiaja do pola", chat._input.text == "ewgb2")
	_check("pisanie nie zmienia slotu", player.input.selected_slot() == slot_before)
	_check("pisanie nie otwiera kola", not hud._dance_wheel.is_open)

	var start := player.position
	Input.action_press("move_forward")
	Input.action_press("interact")
	await _wait(0.4)
	_check("postac stoi podczas pisania", player.position.distance_to(start) < 0.05 and player.input.move == Vector2.ZERO)
	_check("skrzynka nie reaguje podczas pisania", not player._is_interact_held())
	Input.action_release("move_forward")
	Input.action_release("interact")

	await _tap(KEY_TAB)
	Input.action_press("scoreboard")
	await _wait(0.1)
	_check("Tab nie zamyka pisania", chat.is_open)
	_check("Tab nie pokazuje wynikow", not hud._score_center.visible)
	Input.action_release("scoreboard")

	await _tap(KEY_ESCAPE)
	await _wait(0.05)
	_check("Esc zamyka czat", not chat.is_open and not chat._input_panel.visible)
	_check("Esc nie otwiera pauzy", not hud._pause.visible)
	_check("mysz wraca do gry", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_check("nic nie wyslano", chat._rows.get_child_count() == 0)

	await _tap(KEY_T, "t")
	_check("po ponownym otwarciu pole jest puste", chat.is_open and chat._input.text.is_empty())
	await _tap(KEY_ENTER)
	await _wait(0.05)
	_check("Enter bez tekstu zamyka", not chat.is_open and chat._rows.get_child_count() == 0)

	await _say(chat, "[b]czesc[/b] zolc")
	await _wait(0.1)
	_check("Enter wysyla", chat._rows.get_child_count() == 1 and not chat.is_open)
	var line := chat._rows.get_child(0).get_child(0) as RichTextLabel
	_check("znaczniki sa zwyklym tekstem", line.get_parsed_text().ends_with("[b]czesc[/b] zolc"))

	# Klikniecie obok pola zamyka czat i nie strzela.
	await _tap(KEY_T, "t")
	var ammo_before := player.equipment.active_charges()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(900, 200)
	click.pressed = true
	Input.parse_input_event(click)
	Input.action_press("fire")
	await _wait(0.1)
	_check("klikniecie zamyka czat", not chat.is_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await _wait(0.3)
	_check("to klikniecie nie strzela", player.equipment.active_charges() == ammo_before)
	Input.action_release("fire")
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await _wait(0.1)

	# Limit: szosta wiadomosc z rzedu zostaje w polu.
	for index in Chat.BURST - 1:
		await _say(chat, "wiadomosc %d" % index)
	await _tap(KEY_T, "t")
	chat._input.text = "za szybko"
	await _tap(KEY_ENTER)
	await _wait(0.1)
	_check("za szybka wiadomosc czeka w polu", chat.is_open and chat._input.text == "za szybko" and chat._input.is_editing())
	_check("limit nie wyslal wiadomosci", chat._rows.get_child_count() == Chat.BURST)
	if Net.args.has("shot"):
		chat._input.text = ""
		Chat.message_received.emit(2, "Długa wiadomość, która na pewno nie zmieści się w jednej linijce czatu")
		await _wait(0.5)
		get_viewport().get_texture().get_image().save_png(Net.args.shot)
	await _tap(KEY_ESCAPE)
	await _wait(0.05)

	var fresh_row := chat._rows.get_child(chat._rows.get_child_count() - 1) as Control
	fresh_row.set_meta(&"visible_until_ms", 0)
	await _wait(ChatPanel.FADE_SECONDS + 0.2)
	_check("stara wiadomosc znika", fresh_row.modulate.a == 0.0)

	await _tap(KEY_T, "t")
	await _wait(ChatPanel.FADE_SECONDS + 0.1)
	_check("po otwarciu widac historie", fresh_row.modulate.a == 1.0)
	Net.leave()
	await _wait(0.2)
	_check("wyjscie z gry czysci historie", chat._rows.get_child_count() == 0 and not chat.is_open)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDOW: %d" % _failures))
	get_tree().quit(_failures)


func _say(chat: ChatPanel, text: String) -> void:
	await _tap(KEY_T, "t")
	chat._input.text = text
	await _tap(KEY_ENTER)
	await _wait(0.05)


func _tap(key: Key, character := "") -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.unicode = character.unicode_at(0) if pressed and not character.is_empty() else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(what: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK" if passed else "BLAD", what])
	if not passed:
		_failures += 1
