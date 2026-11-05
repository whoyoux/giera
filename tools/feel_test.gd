extends Node
## Test reakcji gry: wstrzasy, dzwieki ciala i poczatek smugi.
## Uzycie: godot --path . --resolution 1280x720 -- --tool=res://tools/feel_test.gd

const PORT := 8123

var _failures := 0
var _player: Player
var _fired_at := Vector3.INF
var _lag := 0.0
var _shots := 0


func _ready() -> void:
	_check_shake_logic()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_player = get_node("/root/Main/Players/1") as Player
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.input.look_yaw = atan2(_player.position.x, _player.position.z)

	# Wstrzas dziala, a ustawienie go wylacza.
	_player.shake_camera(0.8)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("wstrzas obraca kamere", _player.camera.rotation.length() > 0.001)
	await _wait(0.6)
	_check("wstrzas wygasa", _player.camera.rotation.length() < 0.001)
	var saved: float = Settings.value("camera_shake")
	Settings.set_value("camera_shake", 0.0)
	_player.shake_camera(0.8)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("ustawienie wylacza wstrzasy", _player.camera.rotation.length() == 0.0)
	Settings.set_value("camera_shake", saved)
	await _wait(0.5)

	# Kroki, skok i ladowanie.
	var steps: int = _player._step_count
	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")
	_check("bieg daje kroki", _player._step_count >= steps + 3)
	await _wait(0.3)
	steps = _player._step_count
	await _wait(0.4)
	_check("stanie nie daje krokow", _player._step_count == steps)
	var jumps: int = _player._jump_count
	var landings: int = _player._landing_count
	Input.action_press("jump")
	await _wait(0.1)
	Input.action_release("jump")
	await _wait(1.2)
	_check("skok ma dzwiek raz", _player._jump_count == jumps + 1)
	_check("ladowanie ma dzwiek raz", _player._landing_count == landings + 1)

	# Smuga zaczyna sie tam, gdzie lufa jest na ekranie, nawet w ruchu na boki.
	_player.equipment.fired.connect(_on_fired)
	Input.action_press("move_right")
	Input.action_press("fire")
	for i in 60:
		await get_tree().process_frame
		if _fired_at != Vector3.INF:
			_lag = maxf(_lag, _fired_at.distance_to(_player.view_model.muzzle_position()))
			_fired_at = Vector3.INF
	Input.action_release("fire")
	Input.action_release("move_right")
	print("[test] strzaly=%d, przesuniecie lufy miedzy tickiem a klatka: %.3f m" % [_shots, _lag])
	_check("strzelal w ruchu", _shots > 0)
	# Skrypt testu dziala w klatce po broni, wiec widzi te sama poze, ktora trafia na ekran.
	process_priority = 1000
	var posed := [Vector3.INF]
	_player.view_model.on_next_pose(func(muzzle: Vector3) -> void: posed[0] = muzzle)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("efekt dostaje lufe z gotowej pozy", posed[0] != Vector3.INF)

	# Podpowiedz G znika z pusta reka.
	await _wait(0.2)
	_check("podpowiedz G przy broni", hud._drop_hint.visible)
	_player.input.select_slot(3)
	await _wait(0.2)
	_check("bez broni nie ma podpowiedzi G", not hud._drop_hint.visible)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _on_fired() -> void:
	_shots += 1
	_fired_at = _player.view_model.muzzle_position()


func _check_shake_logic() -> void:
	var shake := CameraShake.new()
	_check("bez uderzenia nie ma wstrzasu", shake.update(0.016) == Vector3.ZERO)
	shake.add(0.5)
	shake.add(0.8)
	_check("uderzenia maja limit", is_equal_approx(shake.trauma, 1.0))
	for i in 200:
		shake.update(0.016)
	_check("wstrzas wygasa do zera", shake.trauma == 0.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
