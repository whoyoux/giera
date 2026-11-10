extends Node
## Narzedzie: tabela pod Tab ze sztucznymi graczami i karta wynikow Battle Royale. Wypisuje prostokat
## tabeli i karty oraz ich odstep od krawedzi ekranu, a z --dir zapisuje zrzuty.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://scoreboard_shots.cfg
##         --tool=res://tools/scoreboard_shots.gd [--mode=team_deathmatch|battle_royale] [--dir=C:/folder]
## Deathmatch: tabela z 8, 16 i 32 graczami, a potem 32 graczy po rundzie (z sekcja "Twoja runda").
## Team Deathmatch: tabela z 16 graczami. Battle Royale: karta wynikow z 10 graczami.

const PORT := 8045
const COUNTS: Array[int] = [8, 16, 32]
const NAMES: Array[String] = ["Ziutek", "Basia", "Dlugi Nick Na Steamie Ktory Sie Nie Miesci", "Zosia", "Franek", "Jadzia", "Mietek"]

var _dir := ""
var _hud: Hud
var _added := 1


func _ready() -> void:
	_dir = Net.args.get("dir", "")
	Net.player_name = "Kapitan"
	var mode := GameMode.from_key(Net.args.get("mode", "deathmatch"))
	Net.start_server(PORT, false, mode)
	await _wait(1.0)
	_hud = get_node("/root/Main/Hud") as Hud
	if get_window().focus_exited.is_connected(_hud._on_focus_lost):
		get_window().focus_exited.disconnect(_hud._on_focus_lost)
	if Match.is_elimination():
		await _battle_royale()
	elif Match.is_team_mode():
		await _team_deathmatch()
	else:
		await _deathmatch()
	get_tree().quit()


func _deathmatch() -> void:
	for count in COUNTS:
		_fill_to(count)
		await _scoreboard("scoreboard_%d.png" % count)
	Match._finish_round(Match.standings())
	await _wait(1.2)
	await _scoreboard("scoreboard_results_32.png")


func _team_deathmatch() -> void:
	_fill_to(16)
	for id: int in GameState.players:
		GameState.server_set_team(id, id % 2)
	await _wait(1.0)
	Match.team_scores = [31, 27]
	Match.team_scores_changed.emit()
	await _scoreboard("tdm_scoreboard_16.png")


func _battle_royale() -> void:
	_fill_to(10)
	var results := []
	var place := 1
	for id: int in GameState.players:
		results.append({ "id": id, "name": GameState.players[id].name, "kills": 10 - place, "place": place })
		place += 1
	# Gracz na 7. miejscu, zeby karta pokazala trzech najlepszych i wlasne miejsce.
	results[0].place = 7
	results[6].place = 1
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.place < b.place)
	Match.results = results
	Match._enter_phase(Match.Phase.RESULTS, NetworkTime.tick + NetworkTime.seconds_to_ticks(Match.RESULTS_SECONDS))
	await _wait(1.2)
	_report("karta BR", _hud._match_panel._results_card)
	await _shot("br_results.png")


func _fill_to(count: int) -> void:
	while _added < count:
		_added += 1
		var player_name := NAMES[_added % NAMES.size()] + (" %d" % _added if _added > NAMES.size() else "")
		GameState.server_add_player(_added, player_name)
		GameState.players[_added].kills = (_added * 7) % 23
		GameState.players[_added].deaths = (_added * 5) % 11


func _scoreboard(file_name: String) -> void:
	Input.action_press("scoreboard")
	await _wait(0.5)
	_report("tabela %s" % file_name, _hud._score_card)
	await _shot(file_name)
	Input.action_release("scoreboard")
	await _wait(0.2)


func _report(what: String, control: Control) -> void:
	var rect := control.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	var margin := minf(minf(rect.position.x, rect.position.y), minf(screen.x - rect.end.x, screen.y - rect.end.y))
	print("[tabela] %s: x %d..%d  y %d..%d, wysokosc %.1f%% ekranu, najmniejszy odstep od krawedzi %d px" % [what, rect.position.x, rect.end.x, rect.position.y, rect.end.y, rect.size.y * 100.0 / screen.y, margin])


func _shot(file_name: String) -> void:
	if _dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file_name))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
