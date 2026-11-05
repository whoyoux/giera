extends Node
## Test celowania w oknie gry, jako host.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/aim_test.gd

const PORT := 8126

var _failures := 0


func _ready() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var player := get_node("/root/Main/Players/1") as Player
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.input.look_yaw = atan2(player.position.x, player.position.z)
	var base_fov: float = Settings.value("fov")
	var stats := player.equipment.active_stats()
	var overlay := player.view_model.overlay_camera()
	var hip_muzzle := overlay.to_local(player.view_model.muzzle_position())
	var hip_sensitivity := player.aim_sensitivity_scale()
	_check("bez celowania pelne pole widzenia", is_equal_approx(player.camera.fov, base_fov))

	Input.action_press("aim")
	await _wait(0.8)
	_check("PPM wlacza celowanie", player.aiming)
	_check("widok jest przyblizony", absf(player.camera.fov - base_fov * stats.aim_fov_scale) < 0.5)
	_check("bron jest uniesiona", player.view_model.aim_amount() == 1.0)
	var aim_muzzle := overlay.to_local(player.view_model.muzzle_position())
	print("[test] lufa: biodro %s, celowanie %s" % [hip_muzzle, aim_muzzle])
	_check("lufa jest na srodku", absf(aim_muzzle.x) < 0.01 and absf(hip_muzzle.x) > 0.1)
	_check("lufa jest pod celownikiem", aim_muzzle.y < -0.05 and aim_muzzle.y > -0.2)
	_check("nizsza czulosc", player.aim_sensitivity_scale() < hip_sensitivity * 0.85)
	Settings.set_value("aim_sensitivity", 0.5)
	_check("ustawienie zmienia czulosc", is_equal_approx(player.aim_sensitivity_scale(), player._view_zoom * 0.5))
	Settings.set_value("aim_sensitivity", 1.0)

	# Celowanie spowalnia i wylacza sprint.
	Input.action_press("move_forward")
	await _wait(0.5)
	var aim_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check("celowanie spowalnia", absf(aim_speed - Player.SPEED * stats.aim_move_scale) < 0.3)
	Input.action_press("sprint")
	await _wait(0.3)
	_check("celowanie blokuje sprint", not player.sprinting and player.aiming)
	Input.action_release("aim")
	await _wait(0.5)
	_check("puszczenie wraca do sprintu", player.sprinting and not player.aiming)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _wait(0.8)
	_check("pole widzenia wraca", absf(player.camera.fov - base_fov) < 0.5)
	_check("bron wraca na biodro", player.view_model.aim_amount() == 0.0)

	# Odrzut przy celowaniu jest mniejszy, a strzal dziala.
	Input.action_press("aim")
	await _wait(0.5)
	Input.action_press("fire")
	await _wait(0.4)
	Input.action_release("fire")
	var left := player.equipment.active_charges()
	_check("strzal przy celowaniu dziala", left < stats.magazine)

	# Przeladowanie przerywa, a po nim celowanie wraca, jesli przycisk dalej trzymany.
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	_check("przeladowanie przerywa celowanie", not player.aiming and player.equipment.is_reloading())
	await _wait(stats.reload_seconds + 0.2)
	_check("po przeladowaniu celowanie wraca", player.aiming)
	Input.action_release("aim")
	await _wait(0.3)

	# Apteczka nie celuje, a PPM nie przeszkadza w jej uzyciu.
	var slot := GameState.server_give_item(1, &"medkit", Rarity.Tier.COMMON)
	await _wait(0.1)
	player.input.select_slot(slot)
	await _wait(0.3)
	Input.action_press("aim")
	await _wait(0.3)
	_check("apteczka nie celuje", not player.aiming and absf(player.camera.fov - base_fov) < 0.5)
	Input.action_release("aim")
	player.input.select_slot(0)
	await _wait(0.3)

	# Smierc konczy celowanie.
	GameState.server_add_player(2, "Cel")
	await _wait(0.1)
	Input.action_press("aim")
	await _wait(0.4)
	GameState.server_damage(1, 500, 2)
	await _wait(0.2)
	_check("smierc konczy celowanie", not player.aiming)
	Input.action_release("aim")

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
