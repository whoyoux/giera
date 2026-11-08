extends Node
## Narzedzie: zrzuty Team Deathmatchu w 1280x720: wybor druzyny, HUD z wynikiem druzyn, tabela
## pod Tab, lista zabojstw, mapka i panel konca rundy. Gracze poza hostem sa sztuczni.
## Uzycie: -- --tool=res://tools/tdm_shots.gd --dir=C:/folder [--map=city]

const NAMES: Array[String] = ["Ziutek", "Basia", "Mietek", "Zosia", "Franek", "Jadzia", "Dlugi Nick Na Steamie"]

var _dir := ""


func _ready() -> void:
	_dir = Net.args.get("dir", OS.get_user_data_dir())
	Net.player_name = "Kapitan"
	Net.start_server(8043, false, GameMode.Id.TEAM_DEATHMATCH)
	await _wait(1.0)
	for index in NAMES.size():
		GameState.server_add_player(index + 2, NAMES[index])
	await _wait(0.2)
	for index in NAMES.size():
		if index < 5:
			GameState.server_set_team(index + 2, index % 2)
	await _wait(0.8)
	await _shot("tdm_lobby.png")

	GameState.server_set_team(1, 0)
	await _wait(1.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var kills := [[1, 3, &"shotgun"], [3, 2, &"blaster"], [4, 1, &"deagle"], [2, 5, &"awp"]]
	for kill: Array in kills:
		GameState.players[kill[0]].kills += 1
		GameState.players[kill[1]].deaths += 1
		GameState.players[kill[1]].death_weapon = { "item": kill[2], "tier": Rarity.Tier.EPIC }
		Match.server_on_team_kill(Teams.team_of(kill[0]))
		GameState.kill_announced.emit(kill[0], kill[1])
	Match.team_scores = [17, 14]
	Match.team_scores_changed.emit()
	GameState.player_changed.emit(1)
	await _wait(0.6)
	await _shot("tdm_hud.png")

	Input.action_press("scoreboard")
	await _wait(0.4)
	await _shot("tdm_scoreboard.png")
	Input.action_release("scoreboard")

	Input.action_press("map")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.4)
	await _shot("tdm_map.png")
	Input.action_release("map")

	Match.team_scores = [50, 38]
	Match._finish_round(Match.standings())
	await _wait(1.2)
	await _shot("tdm_results.png")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _dir.path_join(file_name)
	print("[zrzut] %s %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
