extends Node
## Test zmiany klawiszy: zapis, konflikty, reset, panel w menu i w pauzie, podpowiedzi w HUD.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://keys_test.cfg --tool=res://tools/keybinds_test.gd

const PORT := 8141

var _failures := 0


func _ready() -> void:
	_check("test uzywa osobnego pliku", Settings.path != Settings.DEFAULT_PATH)
	Settings.reset_keybinds()
	_check("domyslny skok to Spacja", Keybinds.label_of("jump") == "Spacja")
	_check("domyslne kucanie to Ctrl", Keybinds.label_of("crouch") == "Ctrl")
	_check("domyslny strzal to LPM", Keybinds.label_of("fire") == "LPM")
	_check("kazda akcja gry jest w panelu", _all_actions_listed())
	_check("domyslnie bez konfliktow", Keybinds.conflicts().is_empty())

	# Zajety klawisz: druga akcja dostaje poprzedni klawisz, wiec nic nie zostaje bez przycisku.
	var swapped := Settings.assign_keybind("jump", _key(KEY_W))
	_check("konflikt zamienia klawisze", swapped == "Do przodu" and Keybinds.label_of("jump") == "W" and Keybinds.label_of("move_forward") == "Spacja")
	_check("po zamianie bez konfliktow", Keybinds.conflicts().is_empty())
	Settings.assign_keybind("aim", _mouse(MOUSE_BUTTON_XBUTTON1))
	_check("przycisk myszy jako klawisz", Keybinds.label_of("aim") == "Mysz 4")
	var saved := ConfigFile.new()
	saved.load(Settings.path)
	_check("zapis w pliku ustawien", saved.get_value(Keybinds.SECTION, "jump", "") == "key:%d" % KEY_W and saved.get_value(Keybinds.SECTION, "aim", "") == "mouse:%d" % MOUSE_BUTTON_XBUTTON1)

	# Ponowny start gry czyta zapisane klawisze.
	Keybinds.reset(ConfigFile.new())
	_check("reset w pamieci", Keybinds.label_of("jump") == "Spacja")
	Keybinds.load_from(saved)
	_check("odczyt po restarcie", Keybinds.label_of("jump") == "W" and Keybinds.label_of("aim") == "Mysz 4")

	# Recznie popsuty plik: dwie akcje na jednym klawiszu sa oznaczone.
	var broken := ConfigFile.new()
	broken.set_value(Keybinds.SECTION, "reload", "key:%d" % KEY_E)
	Keybinds.load_from(broken)
	_check("wykrywa konflikt z pliku", Keybinds.conflicts().has("reload") and Keybinds.conflicts().has("interact"))
	broken.set_value(Keybinds.SECTION, "chat", "smieci")
	Keybinds.load_from(broken)
	_check("zly wpis wraca do domyslnego", Keybinds.label_of("chat") == "T")
	Settings.reset_keybinds()
	_check("reset do domyslnych", Keybinds.label_of("jump") == "Spacja" and Keybinds.label_of("aim") == "PPM" and Keybinds.conflicts().is_empty())

	await _test_menu_panel()
	await _test_pause_and_hud()
	Settings.reset_keybinds()
	DirAccess.remove_absolute(Settings.path)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_menu_panel() -> void:
	var main := get_node("/root/Main")
	var panel := main.get_node("SettingsPanel") as SettingsPanel
	(main.get_node("Menu") as Menu).settings_requested.emit()
	await _wait(0.2)
	_check("menu otwiera ustawienia", panel.visible)
	(panel.find_child("keys_tab", true, false) as Button).pressed.emit()
	await _wait(0.1)
	var page := panel.find_child("*", true, false) as Node
	page = panel._keys
	_check("strona klawiszy widoczna", page.is_visible_in_tree())
	var reload := page.find_child("bind_reload", true, false) as Button
	reload.pressed.emit()
	_check("wiersz czeka na klawisz", reload.text == KeybindPage.WAITING)
	Input.parse_input_event(_key(KEY_ESCAPE, true))
	await _wait(0.1)
	_check("Esc anuluje, a okno zostaje", panel.visible and not page.is_waiting() and Keybinds.label_of("reload") == "R")
	reload.pressed.emit()
	Input.parse_input_event(_key(KEY_V, true))
	await _wait(0.1)
	_check("nowy klawisz z panelu", Keybinds.label_of("reload") == "V" and reload.text == "V")
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("keybinds.png"))
		panel._scroll.scroll_vertical = 100000
		await _wait(0.2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("keybinds_bottom.png"))
	(page.find_child("reset_keys", true, false) as Button).pressed.emit()
	await _wait(0.1)
	_check("przycisk resetu", Keybinds.label_of("reload") == "R" and reload.text == "R")
	panel.close()
	await _wait(0.2)


func _test_pause_and_hud() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var player := get_node("/root/Main/Players/1") as Player
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var panel := get_node("/root/Main/SettingsPanel") as SettingsPanel
	hud._set_paused(true)
	hud.settings_requested.emit()
	await _wait(0.2)
	_check("pauza otwiera ustawienia", panel.visible)
	Settings.assign_keybind("drop_item", _key(KEY_H))
	Settings.assign_keybind("jump", _key(KEY_J))
	panel.close()
	hud._set_paused(false)
	await _wait(0.2)
	var chips := hud.find_children("*", "ActionChip", true, false)
	var drop_chip := chips.filter(func(chip: Node) -> bool: return (chip as ActionChip).action == "drop_item")
	_check("podpowiedz w HUD pokazuje nowy klawisz", not drop_chip.is_empty() and (drop_chip[0] as ActionChip).text() == "H")
	_check("podpowiedz broni uzywa przypisania", (ItemRegistry.get_definition(&"knife").behavior() as MeleeBehavior).idle_hint(player.equipment, {}).begins_with("LPM"))
	var hotbar := hud.find_children("*", "Hotbar", true, false)[0] as Hotbar
	Settings.assign_keybind("slot_1", _key(KEY_Z))
	_check("numer slotu to klawisz", _has_label(hotbar, "Z"))
	# Nowy klawisz naprawde steruje postacia.
	var height := player.position.y
	Input.parse_input_event(_key(KEY_J, true))
	await _wait(0.25)
	Input.parse_input_event(_key(KEY_J, false))
	_check("nowy klawisz skacze", player.position.y > height + 0.3)
	await _wait(1.0)
	height = player.position.y
	Input.parse_input_event(_key(KEY_SPACE, true))
	await _wait(0.25)
	Input.parse_input_event(_key(KEY_SPACE, false))
	_check("stary klawisz juz nie skacze", player.position.y < height + 0.05)
	await _wait(0.5)


func _all_actions_listed() -> bool:
	var listed := Keybinds.ACTIONS.map(func(entry: Dictionary) -> String: return entry.action)
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not listed.has(String(action)):
			print("[test] brak akcji w panelu: ", action)
			return false
	return true


func _has_label(root: Node, text: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false


func _key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
