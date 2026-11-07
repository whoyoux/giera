extends Node
## Test zywego interfejsu: prawdziwe zdarzenia myszy i klawiatury, dzwieki i ruch przyciskow.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://test_ui.cfg --tool=res://tools/ui_feel_test.gd

const PORT := 8131
const HOVER_WAIT := 0.06

var _failures := 0
var _main: Node
var _menu: Menu
var _panel: SettingsPanel
var _played: Array[Sfx.UiCue] = []


func _ready() -> void:
	_main = get_node("/root/Main")
	_menu = _main.get_node("Menu") as Menu
	_panel = _main.get_node("SettingsPanel") as SettingsPanel
	UiSound.played.connect(_played.append)
	_check_sounds()
	await _wait(0.6)
	await _test_hover_and_click()
	await _test_guards()
	await _test_errors()
	await _test_letters()
	await _test_settings()
	await _test_pause()
	DirAccess.remove_absolute(Settings.path)
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_sounds() -> void:
	var loudest := {}
	for cue: Sfx.UiCue in UiSound.LEVELS_DB:
		var clip: AudioStreamWAV = UiSound._players[cue].stream
		var peak := 0
		for i in range(0, clip.data.size(), 2):
			peak = maxi(peak, absi(clip.data.decode_s16(i)))
		loudest[cue] = peak
		_check("dzwiek %s nie jest pusty" % Sfx.UiCue.find_key(cue), peak > 3000)
		var last := absi(clip.data.decode_s16(clip.data.size() - 2))
		_check("dzwiek %s nie urywa sie trzaskiem" % Sfx.UiCue.find_key(cue), last < 6000)
	_check("najechanie jest najkrotsze", Sfx.ui_hover().get_length() < 0.05)
	_check("najechanie jest ciszej niz klikniecie", UiSound.LEVELS_DB[Sfx.UiCue.HOVER] < UiSound.LEVELS_DB[Sfx.UiCue.PRESS])


func _test_hover_and_click() -> void:
	var button := _button(_menu, "Ustawienia")
	_silence()
	await _move_to(button)
	_check("najechanie tyka", _playing(Sfx.UiCue.HOVER))
	await _wait(0.2)
	_check("przycisk rosnie pod kursorem", button.scale.x > 1.01)
	_check("przycisk sie przechyla", button.rotation_degrees < -0.5)
	_silence()
	await _mouse_button(button, true)
	_check("wcisniecie gra od razu, przed puszczeniem", _playing(Sfx.UiCue.PRESS))
	await _wait(0.08)
	_check("wcisniety przycisk sie kurczy", button.scale.x < 1.0)
	await _mouse_button(button, false)
	await _wait(0.05)
	_check("klikniecie otwiera ustawienia", _panel.visible)
	_check("otwarcie ma swoj dzwiek", _playing(Sfx.UiCue.OPEN))
	_check("jedno klikniecie nie gra dwoch znaczen", not _playing(Sfx.UiCue.CONFIRM))
	_silence()
	_panel.close()
	_check("zamkniecie ma swoj dzwiek", _playing(Sfx.UiCue.CLOSE))
	await _wait(0.3)
	# Klikniecie mysza nie moze zostawic obwodki ani powiekszenia po zjechaniu kursorem.
	await _move_to(_button(_menu, "Hostuj na tym komputerze"))
	await _wait(0.2)
	_check("po kliknieciu mysza nie zostaje powiekszenie", button.scale.x < 1.01 and is_zero_approx(button.rotation_degrees))


func _test_guards() -> void:
	var first := _button(_menu, "Dołącz do gry")
	var second := _button(_menu, "Ustawienia")
	await _away()
	await _wait(0.1)
	_silence()
	UiSound.play(Sfx.UiCue.OPEN)
	_silence()
	await _move_to(first)
	_check("okno, ktore sie otwiera, nie tyka pod kursorem", not _playing(Sfx.UiCue.HOVER))
	await _wait(0.2)
	await _away()
	_silence()
	UiSound.hover()
	UiSound.hover()
	_check("tykniecia sie nie zlewaja", _played.count(Sfx.UiCue.HOVER) == 1)
	await _wait(0.1)
	first.disabled = true
	_silence()
	await _move_to(first)
	await _wait(0.2)
	_check("wylaczony przycisk milczy", not _playing(Sfx.UiCue.HOVER))
	_check("wylaczony przycisk nie reaguje ruchem", first.scale.x < 1.01)
	first.disabled = false
	await _away()
	await _wait(0.1)
	_silence()
	Settings.set_value("ui_sounds", 0.0)
	await _move_to(second)
	_check("suwak na zero wycisza interfejs", not _playing(Sfx.UiCue.HOVER))
	Settings.set_value("ui_sounds", 0.5)
	await _away()
	await _wait(0.1)
	_silence()
	await _move_to(second)
	_check("glosnosc idzie za suwakiem", _playing(Sfx.UiCue.HOVER) and is_equal_approx(UiSound._players[Sfx.UiCue.HOVER].volume_db, UiSound.LEVELS_DB[Sfx.UiCue.HOVER] + linear_to_db(0.5)))
	Settings.set_value("ui_sounds", 1.0)
	await _away()


func _test_errors() -> void:
	_menu._address_field.text = ""
	var home := _menu._address_field.position.x
	_silence()
	_menu._on_join()
	_check("pusty adres gra blad", _playing(Sfx.UiCue.ERROR))
	_check("pusty adres nie potwierdza", not _playing(Sfx.UiCue.CONFIRM))
	_check("kursor przechodzi do pola", _menu._address_field.has_focus())
	await _wait(0.5)
	_check("pole wraca na miejsce po potrzasnieciu", is_equal_approx(_menu._address_field.position.x, home))
	_menu._address_field.release_focus()
	_silence()
	_menu.show_with_message("Polaczenie z serwerem zostalo zerwane.")
	_check("utrata polaczenia gra blad", _playing(Sfx.UiCue.ERROR))
	await _wait(0.5)
	_silence()
	_menu.show_with_message("")
	_check("wlasne rozlaczenie nie gra bledu", not _playing(Sfx.UiCue.ERROR))


func _test_letters() -> void:
	_silence()
	await _away()
	await _wait(0.1)
	var tile := _menu._letters[2]
	await _move_to(tile)
	_check("literka gra nute", _playing(Sfx.UiCue.NOTE))
	_check("literka gra swoja wysokosc", is_equal_approx(UiSound._players[Sfx.UiCue.NOTE].pitch_scale, Menu.TITLE_NOTES[2]))
	await _wait(0.6)
	_check("literka wraca do rozmiaru", tile.scale.is_equal_approx(Vector2.ONE))
	await _away()


func _test_settings() -> void:
	_menu.settings_requested.emit()
	await _wait(0.3)
	_check("okno ustawien sie miesci", _panel._card.get_global_rect().size.y <= 720.0)
	print("[test] wysokosc okna ustawien: %d" % _panel._card.size.y)
	_check("fokus startowy jest ukryty", _panel._done.has_focus() and not _panel._done.has_focus(true))
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("settings_feel.png"))

	var toggle := _panel.find_child("invert_y", true, false) as Button
	# Przelacznik lezy nizej na przewijanej liscie, wiec najpierw trzeba go pokazac.
	_panel._scroll.ensure_control_visible(toggle)
	await _wait(0.2)
	await _move_to(toggle)
	_silence()
	await _mouse_button(toggle, true)
	await _mouse_button(toggle, false)
	_check("wlaczenie gra swoj dzwiek", _playing(Sfx.UiCue.TOGGLE_ON) and Settings.value("invert_y") == true)
	_silence()
	await _mouse_button(toggle, true)
	await _mouse_button(toggle, false)
	_check("wylaczenie gra swoj dzwiek", _playing(Sfx.UiCue.TOGGLE_OFF) and Settings.value("invert_y") == false)
	await _away()

	var slider := _panel.find_child("ui_sounds", true, false) as HSlider
	_check("suwak dzwiekow interfejsu istnieje", slider != null)
	await _wait(0.1)
	_silence()
	slider.value = 0.6
	_check("suwak tyka", _playing(Sfx.UiCue.SLIDER))
	var low: float = UiSound._players[Sfx.UiCue.SLIDER].pitch_scale
	await _wait(0.1)
	slider.value = 0.9
	_check("wyzsza wartosc brzmi wyzej", UiSound._players[Sfx.UiCue.SLIDER].pitch_scale > low)
	_silence()
	slider.value = 0.5
	_check("suwak nie terkocze", not _playing(Sfx.UiCue.SLIDER))
	_silence()
	await _wait(0.1)
	Settings.reset_to_defaults()
	_check("domyslne nie tykaja kazdym suwakiem", not _playing(Sfx.UiCue.SLIDER))
	_panel.close()

	# Fokus wraca tam, skad otwarto ustawienia.
	var opener := _button(_menu, "Ustawienia")
	opener.grab_focus()
	_silence()
	_panel.open()
	_panel.close()
	_check("fokus wraca do przycisku", opener.has_focus())
	opener.release_focus()
	await _wait(0.2)


func _test_pause() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var hud := _main.get_node("Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	_silence()
	hud._set_paused(true)
	_check("pauza ma dzwiek", _playing(Sfx.UiCue.OPEN))
	_check("Wroc do gry ma fokus", hud._resume_button.has_focus())
	await _wait(0.3)
	_check("okno pauzy doszlo do konca", hud._pause_card.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(hud._pause_card.modulate.a, 1.0))

	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	_silence()
	UiSound._next_hover_ms = 0
	Input.parse_input_event(down)
	await _wait(0.05)
	var focused := get_viewport().gui_get_focus_owner() as Button
	_check("strzalka przechodzi dalej", focused != null and focused != hud._resume_button)
	_check("strzalka tyka", _playing(Sfx.UiCue.HOVER))
	await _wait(0.25)
	_check("fokus z klawiatury powieksza", focused.scale.x > 1.01)
	var up := down.duplicate() as InputEventAction
	up.pressed = false
	Input.parse_input_event(up)

	# Ukrycie pod kursorem nie moze zostawic powiekszonego przycisku na nastepny raz.
	_silence()
	hud._set_paused(false)
	_check("wyjscie z pauzy ma dzwiek", _playing(Sfx.UiCue.CLOSE))
	await _wait(0.05)
	_check("ukryty przycisk wraca do rozmiaru", focused.scale.is_equal_approx(Vector2.ONE))

	Input.action_press("scoreboard")
	await _wait(0.3)
	_check("tabela wynikow jest w pelni widoczna", is_equal_approx(hud._score_card.modulate.a, 1.0))
	Input.action_release("scoreboard")
	await _wait(0.05)
	_check("tabela wynikow znika", not hud._score_center.visible)


func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	push_error("Brak przycisku " + text)
	return null


func _playing(cue: Sfx.UiCue) -> bool:
	return _played.has(cue)


## Zapomina zagrane dzwieki, ale zostawia blokady, ktore sa tu sprawdzane.
func _silence() -> void:
	_played.clear()


func _move_to(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _wait(HOVER_WAIT)


func _away() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1270, 10)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _wait(HOVER_WAIT)


func _mouse_button(control: Control, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.position = control.get_global_rect().get_center()
	click.global_position = click.position
	Input.parse_input_event(click)
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
