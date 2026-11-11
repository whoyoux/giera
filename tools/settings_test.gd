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
	await _test_graphics()
	await _check_window_stays()
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


func _test_graphics() -> void:
	var root := get_tree().root
	var environment := (get_node("/root/Main/World/WorldEnvironment") as WorldEnvironment).environment
	var sun := get_node("/root/Main/World/Sun") as DirectionalLight3D
	Settings.set_value("graphics", float(Settings.Graphics.LOW))
	_check("niska: bez SSAO i glow", not environment.ssao_enabled and not environment.glow_enabled)
	_check("niska: 2 podzialy cieni", sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	_check("niska: FXAA zamiast MSAA", root.msaa_3d == Viewport.MSAA_DISABLED and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA)
	var full_range: float = sun.get_meta(&"full_shadow_range")
	_check("niska: krotsze cienie", is_equal_approx(sun.directional_shadow_max_distance, full_range * 0.6))
	Settings.set_value("graphics", float(Settings.Graphics.MEDIUM))
	_check("srednia: SSAO wraca", environment.ssao_enabled and environment.glow_enabled)
	_check("srednia: MSAA 2x bez FXAA", root.msaa_3d == Viewport.MSAA_2X and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED)
	_check("srednia: 2 podzialy cieni", sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	Settings.set_value("graphics", float(Settings.Graphics.HIGH))
	_check("wysoka: MSAA 4x", root.msaa_3d == Viewport.MSAA_4X)
	_check("wysoka: 4 podzialy i pelny zasieg cieni", sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and is_equal_approx(sun.directional_shadow_max_distance, full_range))
	await _test_auto_resolution(root)
	Settings.set_value("render_scale", 0.75)
	_check("skala 75% przez FSR", root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR and is_equal_approx(root.scaling_3d_scale, 0.75))
	Settings.set_value("render_scale", 1.0)
	_check("skala 100% bez skalowania", root.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR)
	Settings._config.set_value(Settings.SECTION, "high_quality", false)
	Settings._migrate_old_quality()
	_check("stary przelacznik przechodzi na niska", Settings.graphics() == Settings.Graphics.LOW and not Settings._config.has_section_key(Settings.SECTION, "high_quality"))
	Settings.set_value("graphics", float(Settings.Graphics.HIGH))


## Automat trzyma limit pikseli, a przy wolnym GPU schodzi nizej. Karta testowa jest szybka,
## wiec progi obnizamy tak, zeby kazda klatka byla "za wolna", a potem podnosimy.
func _test_auto_resolution(root: Window) -> void:
	_check("automat: skala dla 4K", is_equal_approx(Settings.auto_render_scale(Vector2i(3840, 2160)), 0.4))
	_check("automat: male okno w pelnej rozdzielczosci", is_equal_approx(Settings.auto_render_scale(Vector2i(1280, 720)), 1.0))
	Settings.set_value("render_auto", true)
	var cap := Settings.auto_render_scale(root.size)
	_check("automat: zaczyna od limitu pikseli", root.scaling_3d_scale <= cap + 0.001)
	Settings.auto_gpu_slow_ms = 0.0
	Settings.auto_gpu_fast_ms = -1.0
	await _wait(1.8)
	_check("automat: wolne GPU obniza rozdzielczosc", root.scaling_3d_scale < cap - 0.01)
	_check("automat: nie schodzi ponizej minimum", root.scaling_3d_scale >= Settings.AUTO_RENDER_MIN - 0.001)
	var lowered := root.scaling_3d_scale
	Settings.auto_gpu_slow_ms = 1000.0
	Settings.auto_gpu_fast_ms = 999.0
	await _wait(1.8)
	_check("automat: szybkie GPU podnosi rozdzielczosc", root.scaling_3d_scale > lowered + 0.01 and root.scaling_3d_scale <= cap + 0.001)
	Settings.auto_gpu_slow_ms = Settings.AUTO_GPU_SLOW_MS
	Settings.auto_gpu_fast_ms = Settings.AUTO_GPU_FAST_MS
	Settings.set_value("render_auto", false)
	_check("bez automatu wraca skala z suwaka", is_equal_approx(root.scaling_3d_scale, float(Settings.value("render_scale"))))


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
	_check("dzwiek trwa tyle co przeladowanie", absf(clip.get_length() - player.equipment.active_stats().reload_seconds) < 0.05)

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
	print("[test] stan: kursor=%d amunicja=%d laduje=%s gra=%s" % [Input.mouse_mode, player.equipment.active_charges(), player.equipment.is_reloading(), player.reload_audio.playing])
	_check("dzwiek przeladowania gra", player.reload_audio.playing)
	await _wait(player.equipment.active_stats().reload_seconds + 0.2)
	_check("przeladowanie uzupelnia magazynek", player.equipment.active_charges() == player.equipment.active_stats().magazine)

	# Sprint przerywa przeladowanie i dzwiek.
	Input.action_press("fire")
	await _wait(0.5)
	Input.action_release("fire")
	var ammo_left := player.equipment.active_charges()
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	_check("przeladowanie trwa przed sprintem", player.equipment.is_reloading() and player.reload_audio.playing)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(0.2)
	_check("sprint przerywa przeladowanie", not player.equipment.is_reloading())
	_check("sprint przerywa dzwiek", not player.reload_audio.playing)
	_check("przerwanie nie daje amunicji", player.equipment.active_charges() == ammo_left)
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
	_check("smierc przerywa przeladowanie", not player.equipment.is_reloading())
	_check("smierc przerywa dzwiek", not player.reload_audio.playing)
	await _wait(GameState.RESPAWN_SECONDS + 0.3)
	_check("po odrodzeniu magazynek jest pelny", player.equipment.active_charges() == player.equipment.active_stats().magazine)
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


## Suwak dzwieku nie moze zmieniac okna: to byl zgloszony blad.
func _check_window_stays() -> void:
	var window := get_window()
	window.mode = Window.MODE_MAXIMIZED
	await get_tree().create_timer(0.3).timeout
	var before := window.mode
	Settings.set_value("ambience", 0.5)
	Settings.set_value("volume", Settings.value("volume"))
	await get_tree().create_timer(0.3).timeout
	_check("suwak nie zmienia trybu okna", window.mode == before)
	Settings.reset_to_defaults()
	window.mode = Window.MODE_WINDOWED
	await get_tree().create_timer(0.3).timeout
