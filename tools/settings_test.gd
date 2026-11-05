extends Node
## Test ustawien i dzwieku przeladowania na osobnym pliku, bez ruszania prawdziwych ustawien.
## Pierwsze uruchomienie: -- --tool=res://tools/settings_test.gd --settings-path=user://test.cfg
## Drugie, sprawdzajace zapis: to samo z dodatkowym --verify-saved

var _failures := 0


func _ready() -> void:
	_check("test uzywa osobnego pliku", Settings.path != Settings.DEFAULT_PATH)
	if Net.args.has("verify-saved"):
		_check("glosnosc po restarcie", is_equal_approx(Settings.value("volume"), 0.35))
		_check("czulosc po restarcie", is_equal_approx(Settings.value("sensitivity"), 1.75))
		_check("odwrocenie po restarcie", Settings.value("invert_y") == true)
		_check("pole widzenia po restarcie", is_equal_approx(Settings.value("fov"), 95.0))
		_check("licznik FPS po restarcie", Settings.value("show_fps") == false)
		_check("nick po restarcie", Settings.player_value("name", "") == "TestNick")
		_check("glosnosc dziala po starcie", is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35))
		DirAccess.remove_absolute(Settings.path)
		_finish()
		return

	_check("domyslna glosnosc", is_equal_approx(Settings.value("volume"), Settings.DEFAULTS.volume))
	await _test_panel()
	await _test_reload_sound()
	Settings.set_value("volume", 0.0)
	_check("glosnosc 0 wycisza", AudioServer.is_bus_mute(0))
	Settings.set_value("volume", 0.35)
	_check("glosnosc zmienia magistrale", not AudioServer.is_bus_mute(0) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35))
	Settings.set_value("sensitivity", 1.75)
	Settings.set_value("invert_y", true)
	Settings.set_value("fov", 95.0)
	Settings.set_value("show_fps", false)
	Settings.set_player_value("name", "TestNick")
	await _wait(0.6)
	_check("plik ustawien powstal", FileAccess.file_exists(Settings.path))
	_finish()


func _test_panel() -> void:
	var main := get_node("/root/Main")
	var panel := main.get_node("SettingsPanel") as SettingsPanel
	var menu := main.get_node("Menu") as Menu
	menu.settings_requested.emit()
	await _wait(0.1)
	_check("menu otwiera ustawienia", panel.visible)
	var slider := panel.find_child("sensitivity", true, false) as HSlider
	slider.value = 2.0
	_check("suwak zmienia ustawienie", is_equal_approx(Settings.value("sensitivity"), 2.0))
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("settings.png"))
	var pause := InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	Input.parse_input_event(pause)
	await _wait(0.1)
	_check("Esc zamyka ustawienia", not panel.visible)
	_check("menu nadal widoczne", menu.visible)


func _test_reload_sound() -> void:
	_check("host startuje", Net.start_server(int(Net.args.get("port", 8050))).is_empty())
	await _wait(1.5)
	var player := get_node("/root/Main/Players/1") as Player
	# Okno testu moze nie miec fokusu, a sterowanie dziala tylko z przechwycona mysza.
	get_window().focus_exited.disconnect((get_node("/root/Main/Hud") as Hud)._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, 100)
	var pitch_before := player.input.look_pitch
	Settings.set_value("sensitivity", 2.0)
	Settings.set_value("invert_y", false)
	Input.parse_input_event(motion)
	await _wait(0.1)
	var plain_pitch := player.input.look_pitch - pitch_before
	_check("czulosc mnozy ruch myszy", is_equal_approx(plain_pitch, -100.0 * PlayerInput.MOUSE_SENSITIVITY * 2.0))
	Settings.set_value("invert_y", true)
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check("odwrocenie zmienia kierunek", player.input.look_pitch > pitch_before + plain_pitch)
	Settings.set_value("invert_y", false)
	Settings.set_value("fov", 100.0)
	await _wait(0.6)
	_check("pole widzenia dziala", absf(player.camera.fov - 100.0) < 1.0)

	var clip := Sfx.reload_sound()
	var peak := 0
	for i in range(0, clip.data.size(), 2):
		peak = maxi(peak, absi(clip.data.decode_s16(i)))
	print("[test] dlugosc dzwieku %.2f s, szczyt %d" % [clip.get_length(), peak])
	_check("dzwiek przeladowania nie jest cichy", peak > 5000)
	_check("dzwiek trwa tyle co przeladowanie", absf(clip.get_length() - Weapon.RELOAD_SECONDS) < 0.05)

	var hud := get_node("/root/Main/Hud") as Hud
	await _wait(0.1)
	_check("licznik FPS jest domyslnie widoczny", hud._fps_panel.visible)
	_check("licznik pokazuje wartosc", hud._fps_label.text.ends_with(" FPS"))
	var fps_toggle := get_node("/root/Main/SettingsPanel").find_child("show_fps", true, false) as Button
	fps_toggle.button_pressed = false
	await _wait(0.1)
	_check("przelacznik wylacza licznik FPS", not hud._fps_panel.visible and Settings.value("show_fps") == false)
	fps_toggle.button_pressed = true
	await _wait(0.1)
	_check("przelacznik wlacza licznik FPS", hud._fps_panel.visible)

	# Pelne przeladowanie: dzwiek gra i konczy sie razem z nim.
	Input.action_press("fire")
	await _wait(0.5)
	Input.action_release("fire")
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	print("[test] stan: kursor=%d amunicja=%d laduje=%s gra=%s" % [Input.mouse_mode, player.weapon.ammo, player.weapon.is_reloading(), player.reload_audio.playing])
	_check("dzwiek przeladowania gra", player.reload_audio.playing)
	await _wait(Weapon.RELOAD_SECONDS + 0.2)
	_check("przeladowanie uzupelnia magazynek", player.weapon.ammo == Weapon.MAGAZINE)

	# Sprint przerywa przeladowanie i dzwiek.
	Input.action_press("fire")
	await _wait(0.5)
	Input.action_release("fire")
	var ammo_left := player.weapon.ammo
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	_check("przeladowanie trwa przed sprintem", player.weapon.is_reloading() and player.reload_audio.playing)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(0.2)
	_check("sprint przerywa przeladowanie", not player.weapon.is_reloading())
	_check("sprint przerywa dzwiek", not player.reload_audio.playing)
	_check("przerwanie nie daje amunicji", player.weapon.ammo == ammo_left)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _wait(1.0)

	# Smierc tez przerywa przeladowanie i dzwiek.
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	_check("przeladowanie trwa przed smiercia", player.reload_audio.playing)
	GameState.server_damage(1, 500, 1)
	await _wait(0.2)
	_check("smierc przerywa przeladowanie", not player.weapon.is_reloading())
	_check("smierc przerywa dzwiek", not player.reload_audio.playing)
	await _wait(GameState.RESPAWN_SECONDS + 0.3)
	_check("po odrodzeniu magazynek jest pelny", player.weapon.ammo == Weapon.MAGAZINE)
	Net.leave()
	await _wait(0.3)


func _finish() -> void:
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
