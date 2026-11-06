extends Node
## Narzedzie: robi zrzuty kolejnych etapow Battle Royale w oknie gry.
## Uzycie: -- --connect=127.0.0.1 --port=7778 --tool=res://tools/br_shots.gd --dir=C:/folder
## Klika Gotowe prawdziwym klawiszem i przelacza widza przyciskiem strzalu.

var _dir := ""
var _taken := {}


func _ready() -> void:
	_dir = Net.args.get("dir", "user://")
	Match.phase_changed.connect(_on_phase_changed)
	GameState.player_added.connect(_on_player_added)


func _on_player_added(id: int) -> void:
	if id != multiplayer.get_unique_id():
		return
	var main := get_node("/root/Main")
	# Okno moze nie miec fokusu, a sterowanie dziala tylko z przechwycona mysza.
	get_window().focus_exited.disconnect((main.get_node("Hud") as Hud)._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(3.0)
	await _shot("lobby.png")
	_press("toggle_ready")
	await _wait(0.8)
	await _shot("lobby_ready.png")


func _on_phase_changed() -> void:
	match Match.phase:
		Match.Phase.COUNTDOWN:
			await _wait(1.5)
			await _shot("countdown.png")
		Match.Phase.STARTING:
			await _wait(1.5)
			await _shot("starting.png")
		Match.Phase.LIVE:
			await _wait(1.0)
			await _shot("live.png")
			_watch_and_shoot()
		Match.Phase.RESULTS:
			await _wait(1.5)
			await _shot("results.png")
			await _wait(10.0)
			await _shot("back_in_lobby.png")
			get_tree().quit()


## Czeka na widza, a potem na wyjscie poza strefe u dowolnego ogladanego gracza.
func _watch_and_shoot() -> void:
	var camera := get_tree().get_first_node_in_group(SpectatorCamera.GROUP) as SpectatorCamera
	var local := GameState.player_node(multiplayer.get_unique_id())
	while Match.phase == Match.Phase.LIVE:
		await get_tree().process_frame
		if local.is_alive() and Zone.is_outside(Match.zone_state(), local.position):
			await _shot("outside.png")
		if not local.is_alive() and not _taken.has("dead.png"):
			await _wait(0.8)
			await _shot("dead.png")
		if camera.current and not _taken.has("spectator.png"):
			await _wait(1.0)
			await _shot("spectator.png")
			var before := camera.target_name()
			_press("fire")
			await _wait(1.0)
			print("[zrzuty] widz: %s -> %s" % [before, camera.target_name()])
			await _shot("spectator_next.png")
		if _taken.has("zone_wall.png") or not _taken.has("spectator_next.png"):
			continue
		await _wait(2.0)
		await _shot("zone_wall.png")


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(0.1).timeout
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(file: String) -> void:
	if _taken.has(file):
		return
	_taken[file] = true
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_dir.path_join(file))
	print("[zrzuty] %s: %s" % [file, error_string(error)])
