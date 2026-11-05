extends Node
## Test sterowania i przebiegu sesji w oknie gry: hostowanie, ruch, strzal, pauza,
## wyjscie i ponowne hostowanie.
## Uzycie: godot --path . --resolution 1280x720 -- --tool=res://tools/flow_test.gd [--rejoin-port=7811]

const PORT := 7810

var _failures := 0


func _ready() -> void:
	var main := get_node("/root/Main")
	var menu := main.get_node("Menu") as Menu
	menu._address_field.text = ""
	menu._on_join()
	_check("puste pole adresu nie laczy", not Net.in_session and menu._status.text == "Wpisz adres serwera.")
	menu._status.text = ""
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var player := _local_player()
	_check("lokalny gracz istnieje", player != null)
	if player == null:
		_finish()
		return
	_check("menu jest ukryte", not (main.get_node("Menu") as CanvasLayer).visible)
	_check("kursor jest przechwycony", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	var yaw_before := player.input.look_yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 40)
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check("mysz obraca kamere", absf(player.input.look_yaw - yaw_before + 0.25) < 0.001)
	_check("mysz porusza widok w pionie", player.input.look_pitch < -0.05)

	var start := player.position
	var forward := Hitscan.direction(player.input.look_yaw, 0.0)
	Input.action_press("move_forward")
	await _wait(1.0)
	Input.action_release("move_forward")
	var moved := (player.position - start)
	print("[test] przesuniecie po sekundzie: %.2f m" % moved.length())
	_check("W prowadzi do przodu", moved.normalized().dot(forward) > 0.9 and moved.length() > 3.0)

	var shot_before := player.weapon.last_fire
	Input.action_press("fire")
	await _wait(0.5)
	Input.action_release("fire")
	_check("LPM strzela", player.weapon.last_fire > shot_before)

	var jump_start := player.position.y
	Input.action_press("jump")
	await _wait(0.25)
	Input.action_release("jump")
	_check("spacja podskakuje", player.position.y > jump_start + 0.3)
	await _wait(1.0)

	var pause := InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	Input.parse_input_event(pause)
	await _wait(0.2)
	_check("Esc uwalnia kursor", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	Input.action_press("move_forward")
	var paused_at := player.position
	await _wait(0.4)
	Input.action_release("move_forward")
	_check("pauza blokuje ruch", player.position.distance_to(paused_at) < 0.2)

	Net.leave()
	await _wait(0.5)
	_check("wyjscie czysci graczy", GameState.players.is_empty())
	_check("wyjscie pokazuje menu", (main.get_node("Menu") as CanvasLayer).visible)
	_check("wyjscie wlacza kamere menu", (main.get_node("MenuCamera") as Camera3D).current)

	_check("ponowny host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var second := _local_player()
	_check("gracz wraca po ponownym starcie", second != null)
	if second != null:
		var again := second.position
		Input.action_press("move_forward")
		await _wait(0.6)
		Input.action_release("move_forward")
		_check("ruch dziala po ponownym starcie", second.position.distance_to(again) > 1.5)
	Net.leave()
	await _wait(0.5)
	if Net.args.has("rejoin-port"):
		await _test_rejoin(int(Net.args["rejoin-port"]))
	_finish()


## Wymaga dzialajacego serwera dedykowanego na podanym porcie.
func _test_rejoin(port: int) -> void:
	for attempt in 2:
		_check("dolaczanie %d startuje" % (attempt + 1), Net.join("127.0.0.1", port).is_empty())
		await _wait(3.0)
		var player := _local_player()
		_check("gracz po dolaczeniu %d istnieje" % (attempt + 1), player != null)
		if player == null:
			return
		var start := player.position
		Input.action_press("move_forward")
		await _wait(0.7)
		Input.action_release("move_forward")
		_check("ruch po dolaczeniu %d" % (attempt + 1), player.position.distance_to(start) > 2.0)
		Net.leave()
		await _wait(1.0)


func _finish() -> void:
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if player.is_local() and not player.is_queued_for_deletion():
			return player
	return null


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
