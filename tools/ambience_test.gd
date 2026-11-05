extends Node
## Test dzwiekow lasu: czy petle sa czyste, czy tlo reaguje na miejsce i czy kroki zaleza od podloza.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/ambience_test.gd

const PORT := 8129

var _failures := 0


func _ready() -> void:
	_check_sounds()
	_check_ground()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var ambience := get_node("/root/Main/World/Terrain").find_children("*", "ForestAmbience", false, false)[0] as ForestAmbience
	_check("wiatr gra", ambience._wind.playing)
	_check("liscie graja", ambience._leaves.playing)
	_check("strumien gra", ambience._creek.playing)
	var camera := get_viewport().get_camera_3d()
	_check("strumien jest na swoim korycie", is_equal_approx(ambience._creek.global_position.z, ForestTerrain.creek_center_z(camera.global_position.x)))
	await _wait(1.0)
	var heard := ambience._wind.volume_db
	_check("wiatr jest cichy, ale slyszalny", heard > ForestAmbience.SILENT_DB + 10.0 and heard < -8.0)

	Settings.set_value("ambience", 0.0)
	await _wait(1.0)
	_check("suwak wycisza tlo", ambience._wind.volume_db <= ForestAmbience.SILENT_DB + 1.0 and ambience._creek.volume_db <= ForestAmbience.SILENT_DB + 1.0)
	Settings.set_value("ambience", 1.0)

	# Ptaki odzywaja sie same.
	ambience._next_bird = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_check("ptak spiewa", ambience._birds[0].playing or ambience._birds[1].playing)

	var player := get_node("/root/Main/Players/1") as Player
	get_window().focus_exited.disconnect((get_node("/root/Main/Hud") as Hud)._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var steps := player._step_count
	Input.action_press("move_forward")
	await _wait(1.2)
	Input.action_release("move_forward")
	_check("kroki dalej graja", player._step_count > steps)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_sounds() -> void:
	for pair: Array in [["wiatr", Sfx.wind_loop()], ["liscie", Sfx.leaves_loop()], ["strumien", Sfx.creek_loop()]]:
		var stream: AudioStreamWAV = pair[1]
		_check("%s jest petla" % pair[0], stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0)
		var data := stream.data
		var peak := 0
		for i in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		# Skok miedzy koncem a poczatkiem petli slychac jako trzask.
		var seam := absi(data.decode_s16(data.size() - 2) - data.decode_s16(0))
		print("[test] %s: szczyt %d, skok na laczeniu %d" % [pair[0], peak, seam])
		_check("%s nie jest cisza ani przesterem" % pair[0], peak > 2000 and peak < 32000)
		_check("%s laczy sie bez trzasku" % pair[0], seam < 3000)
	for variant in Sfx.BIRD_VARIANTS:
		_check("ptak %d ma dzwiek" % variant, Sfx.bird(variant).get_length() > 0.1)
	var sounds := {}
	for kind: int in ForestTerrain.Ground.values():
		sounds[Sfx.footstep_on(kind)] = true
	_check("kazde podloze brzmi inaczej", sounds.size() == ForestTerrain.Ground.size())


func _check_ground() -> void:
	var kind := func(x: float, z: float, above := 0.0) -> int:
		return ForestTerrain.ground_at(Vector3(x, ForestTerrain.surface(x, z) + above, z))
	_check("trawa na polanie", kind.call(-16.0, -6.0) == ForestTerrain.Ground.GRASS)
	_check("ziemia w ruinach", kind.call(3.0, 3.0) == ForestTerrain.Ground.DIRT)
	_check("ziemia na sciezce", kind.call(15.0, 2.0 * sin(15.0 * 0.17)) == ForestTerrain.Ground.DIRT)
	_check("woda w strumieniu", kind.call(4.0, ForestTerrain.creek_center_z(4.0)) == ForestTerrain.Ground.WATER)
	_check("kamien na wiezy", ForestTerrain.ground_at(Vector3(-4.5, 3.5, -4.5)) == ForestTerrain.Ground.STONE)
	_check("skok nad trawa nie zmienia sie w kamien", kind.call(-16.0, -6.0, 0.1) == ForestTerrain.Ground.GRASS)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
