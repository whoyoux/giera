extends Node
## Test tancow jako host: klipy, muzyka, kolo wyboru, przerywanie, kamera i cudzy taniec.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/dance_test.gd [--dir=C:/zrzuty]

const PORT := 8133

var _failures := 0
var _me: Player
var _hud: Hud


func _ready() -> void:
	_check_catalog()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_me = get_node("/root/Main/Players/1") as Player
	_hud = get_tree().get_first_node_in_group(&"hud") as Hud
	_capture()
	await _wait(0.5)
	_check_character_clips()
	await _test_wheel()
	await _test_camera_and_music()
	await _test_interrupts()
	await _test_refusals()
	await _test_remote_dancers()
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_catalog() -> void:
	var library := DanceClips.library()
	for id in range(1, DanceCatalog.DANCES.size() + 1):
		var dance := DanceCatalog.entry(id)
		var clip := library.get_animation(dance.key)
		_check("%s: klip jest" % dance.key, clip != null)
		_check("%s: klip sie zapetla" % dance.key, clip.loop_mode == Animation.LOOP_LINEAR)
		var seconds_per_beat: float = 60.0 / dance.bpm
		_check("%s: dlugosc klipu pasuje do tempa" % dance.key, is_equal_approx(clip.length, dance.beats * seconds_per_beat))
		var music := DanceCatalog.music_of(id) as AudioStreamWAV
		_check("%s: muzyka sie zapetla" % dance.key, music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_end > 0)
		# Utwor ma 16 uderzen, a taniec miesci sie w nim pelna liczbe razy, wiec sie nie rozjezdzaja.
		_check("%s: muzyka ma 16 uderzen" % dance.key, absf(music.get_length() - 16.0 * seconds_per_beat) < 0.01)
		_check("%s: taniec miesci sie w utworze" % dance.key, 16 % int(dance.beats) == 0)
		_check("%s: ikona jest" % dance.key, ResourceLoader.exists("res://assets/icons/dance_%s.png" % dance.key))
		_check("%s: klip konczy sie tam, gdzie zaczyna" % dance.key, _loop_closes(clip))
	_check("nieznany taniec odrzucony", not DanceCatalog.is_valid(0) and not DanceCatalog.is_valid(99) and not DanceCatalog.is_valid(-1))


func _loop_closes(clip: Animation) -> bool:
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D or clip.track_get_key_count(track) < 2:
			continue
		var first: Quaternion = clip.track_get_key_value(track, 0)
		var last: Quaternion = clip.track_get_key_value(track, clip.track_get_key_count(track) - 1)
		if absf(first.dot(last)) < 0.999:
			return false
	return true


## Kazda postac, takze szkielety bez wlasnych animacji, musi miec wszystkie sciezki tanca.
func _check_character_clips() -> void:
	var library := DanceClips.library()
	for entry: Dictionary in CharacterAssets.ROSTER:
		var character := CharacterAssets.character_for(entry.id)
		add_child(character)
		var player := CharacterAssets.player_of(character)
		player.add_animation_library(DanceClips.LIBRARY, library)
		var clip := library.get_animation(DanceCatalog.DANCES[0].key)
		var missing := 0
		for track in clip.get_track_count():
			if player.get_node(player.root_node).get_node_or_null(NodePath(str(clip.track_get_path(track).get_concatenated_names()))) == null:
				missing += 1
			elif CharacterAssets.skeleton_of(character).find_bone(clip.track_get_path(track).get_concatenated_subnames()) < 0:
				missing += 1
		_check("%s: wszystkie sciezki tanca trafiaja w kosci" % entry.id, missing == 0)
		character.free()


func _test_wheel() -> void:
	var wheel := _hud._dance_wheel
	_check("kolo na starcie zamkniete", not wheel.is_open)
	await _key(KEY_B, true)
	_check("przytrzymanie otwiera kolo", wheel.is_open and wheel.visible)
	_check("kolo zajmuje caly ekran", wheel.size == _hud.get_viewport().get_visible_rect().size)
	var yaw_before := _me.input.look_yaw
	await _motion(Vector2(0.0, -150.0))
	_check("kursor na gorze wskazuje pierwszy taniec", wheel.hovered() == 1)
	_check("ruch myszy nie obraca kamery", is_equal_approx(_me.input.look_yaw, yaw_before))
	await _motion(Vector2(300.0, 150.0))
	_check("kursor w prawo wskazuje inny taniec", wheel.hovered() == 2 or wheel.hovered() == 3)
	await _shot("dance_wheel.png")
	var wanted := wheel.hovered()
	await _key(KEY_B, false)
	await _wait(0.2)
	_check("puszczenie klawisza zamyka kolo", not wheel.is_open)
	_check("puszczenie wybiera taniec", _me.dance_id == wanted)
	await _stop_by_walking()

	await _key(KEY_B, true)
	await _key(KEY_B, false)
	await _wait(0.15)
	_check("puszczenie na srodku nic nie wybiera", _me.dance_id == DanceCatalog.NONE and not wheel.is_open)

	# Klikniecie wybiera, a przytrzymany przycisk nie moze potem strzelic.
	await _key(KEY_B, true)
	await _motion(Vector2(0.0, 150.0))
	var shots := _me.equipment.last_fire
	var clicked := wheel.hovered()
	await _mouse(true)
	await _wait(0.3)
	_check("klikniecie wybiera taniec", _me.dance_id == clicked and not wheel.is_open)
	_check("klikniecie nie strzela", _me.equipment.last_fire == shots)
	await _mouse(false)
	await _key(KEY_B, false)
	await _wait(0.15)
	_check("taniec trwa po puszczeniu przycisku", _me.dance_id == clicked)
	await _stop_by_walking()


func _test_camera_and_music() -> void:
	_check("bez tanca kamera w oczach", not _me.camera.top_level and _me.view_model.is_shown())
	_check("bez tanca wlasny model schowany", not _me.model.visible)
	_me.input.request_dance(1)
	await _wait(0.7)
	var yaw_before := _me.yaw
	_check("postac staje przodem do kamery", absf(angle_difference(_me.yaw, _me.input.look_yaw + PI)) < 0.1)
	_check("taniec wlacza stan", _me.dance_id == 1)
	_check("kamera odjezdza za postac", _me.camera.top_level and _me.camera.global_position.distance_to(_me.eye_position()) > 0.5)
	_check("widac wlasny model", _me.model.visible)
	_check("reki z bronia nie widac", not _me.view_model.is_shown())
	_check("celownik schowany", _hud._crosshair.hidden_for_sprint)
	_check("muzyka gra", _me._dance_music.is_playing() and _me._dance_music.stream() == DanceCatalog.music_of(1))
	_me.input.look_yaw += 1.0
	await _wait(0.3)
	_check("mysz nie przerywa tanca", _me.dance_id == 1)
	_check("mysz nie obraca postaci", absf(_me.yaw - yaw_before) < 0.01)
	await _shot("dance_third_person.png")
	var loud := _me._dance_music.volume_db()
	Settings.set_value("dance_music", 0.2)
	await _wait(0.05)
	_check("suwak zmienia glosnosc muzyki", _me._dance_music.volume_db() < loud - 5.0)
	Settings.set_value("dance_music", Settings.DEFAULTS.dance_music)
	# Inny taniec prosto po poprzednim.
	_me.input.request_dance(2)
	await _wait(0.2)
	_check("zmiana tanca zmienia muzyke", _me.dance_id == 2 and _me._dance_music.stream() == DanceCatalog.music_of(2))
	await _stop_by_walking()
	await _wait(0.6)
	_check("po tancu kamera wraca do oczu", not _me.camera.top_level and _me.camera.position == Vector3.ZERO)
	_check("po tancu widac bron w rekach", _me.view_model.is_shown() and not _me.model.visible)
	_check("po tancu postac patrzy jak kamera", absf(_me.rotation.y - _me.input.look_yaw) < 0.01)
	_check("muzyka wygasla", not _me._dance_music.is_playing())


func _test_interrupts() -> void:
	for action: String in ["move_forward", "move_left", "jump", "fire", "aim", "reload"]:
		_me.input.request_dance(3)
		await _wait(0.2)
		_check("%s: taniec trwa przed akcja" % action, _me.dance_id == 3)
		Input.action_press(action)
		await _wait(0.25)
		_check("%s przerywa taniec" % action, _me.dance_id == DanceCatalog.NONE)
		Input.action_release(action)
		await _wait(0.9)
	for key: int in [KEY_2, KEY_1]:
		_capture()
		_me.input.request_dance(4)
		await _wait(0.2)
		await _key(key, true)
		await _key(key, false)
		await _wait(0.25)
		_check("zmiana slotu przerywa taniec", _me.dance_id == DanceCatalog.NONE)
	# Trafienie nie przerywa, a smierc tak.
	_me.input.request_dance(5)
	await _wait(0.2)
	GameState.server_damage(1, 10, 1)
	await _wait(0.1)
	_check("drobne obrazenia nie przerywaja tanca", _me.dance_id == 5)
	GameState.server_damage(1, GameState.MAX_HEALTH, 1)
	await _wait(0.25)
	_check("smierc przerywa taniec", _me.dance_id == DanceCatalog.NONE and _me.input.dance == DanceCatalog.NONE)
	_check("martwy nie otworzy kola", not _try_open_wheel())
	_check("martwy nie zacznie tanca", not _me.input.request_dance(1))
	while not _me.is_alive():
		await _wait(0.2)
	await _wait(0.5)


func _try_open_wheel() -> bool:
	Input.action_press("dance")
	var event := InputEventAction.new()
	event.action = "dance"
	event.pressed = true
	_hud._unhandled_input(event)
	Input.action_release("dance")
	var opened := _hud._dance_wheel.is_open
	_hud._close_dance_wheel()
	return opened


func _test_refusals() -> void:
	_capture()
	Input.action_press("move_forward")
	await _wait(0.25)
	_check("w biegu nie mozna zaczac tanca", not _me.input.request_dance(1))
	Input.action_release("move_forward")
	await _wait(0.3)
	_check("nieznany taniec odrzucony przy prosbie", not _me.input.request_dance(99))
	_capture()
	Input.action_press("jump")
	await _wait(0.15)
	Input.action_release("jump")
	await _wait(0.05)
	_check("w locie nie mozna zaczac tanca", not _me.input.request_dance(1))
	await _wait(1.2)
	# Pauza zamyka kolo i oddaje kursor.
	await _key(KEY_B, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(0.1)
	_check("utrata myszy zamyka kolo", not _hud._dance_wheel.is_open)
	_check("po zamknieciu mozna strzelac", not _me.input.wheel_open)
	await _key(KEY_B, false)
	_capture()
	await _wait(0.1)


## Taniec w sieci sprawdza tools/dance_net_test.sh, a tu kazda postac z osobna.
func _test_remote_dancers() -> void:
	var dance_id := 1
	for entry: Dictionary in CharacterAssets.ROSTER:
		var rig := CharacterRig.new()
		add_child(rig)
		rig.setup(entry.id)
		rig.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, 0))
		rig.set_dance(dance_id)
		await _wait(0.1)
		var state: String = rig._tree.get("parameters/state/current_state")
		_check("%s: drzewo animacji tanczy" % entry.id, state == "dance_%d" % dance_id)
		_check("%s: bron schowana" % entry.id, not rig._gun_holder.visible)
		rig.update_pose(0.5, Vector2.ZERO, true, 0.0, false, true)
		await _wait(0.05)
		_check("%s: smierc wygrywa z tancem" % entry.id, rig._tree.get("parameters/state/current_state") == "dead")
		rig.update_pose(0.5, Vector2.ZERO, true, 0.0, false, false)
		rig.set_dance(DanceCatalog.NONE)
		await _wait(0.05)
		_check("%s: po tancu bron wraca" % entry.id, rig._gun_holder.visible and rig._tree.get("parameters/state/current_state") == "alive")
		rig.queue_free()
		dance_id = dance_id % DanceCatalog.DANCES.size() + 1
	var remote := DanceMusic.new()
	add_child(remote)
	remote.setup(false)
	remote.play(DanceCatalog.music_of(1))
	_check("cudza muzyka gra z pozycji gracza", remote.is_playing() and remote._audio is AudioStreamPlayer3D)
	remote.stop()
	await _wait(0.5)
	_check("cudza muzyka cichnie", not remote.is_playing())
	remote.queue_free()


func _stop_by_walking() -> void:
	Input.action_press("move_forward")
	await _wait(0.12)
	Input.action_release("move_forward")
	await _wait(0.4)
	_check("ruch przerywa taniec", _me.dance_id == DanceCatalog.NONE)


## Inne okno na tym komputerze moze zabrac fokus, a gra wtedy oddaje mysz.
func _capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _key(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key as Key
	event.keycode = key as Key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(file: String) -> void:
	if not Net.args.has("dir"):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s" % [Net.args.dir, file])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[test] %s: %s" % ["OK" if ok else "BLAD", what])
