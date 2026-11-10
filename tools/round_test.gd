extends Node
## Test rund Deathmatchu jako host: zegar, ranking w HUD, ostatnie 30 s, limit zabojstw, wyniki,
## pelny reset i remis.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --round-seconds=40
##         --round-kill-limit=3 --tool=res://tools/round_test.gd [--shot-dir=C:/folder]

const PORT := 8147

var _failures := 0
var _panel: RoundPanel
var _match_panel: MatchPanel


func _ready() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	_panel = hud.find_children("*", "RoundPanel", true, false)[0] as RoundPanel
	_match_panel = hud.find_children("*", "MatchPanel", true, false)[0] as MatchPanel
	GameState.server_add_player(2, "Cel")
	GameState.server_add_player(3, "Basia")
	await _wait(0.5)
	_check("runda 1 trwa", Match.phase == Match.Phase.LIVE and Match.round_number == 1 and Match.phase_end_tick > NetworkTime.tick)
	_check("zegar liczy w tickach serwera", absf(Match.seconds_left() - 40.0) < 3.0)
	_check("HUD pokazuje zegar", _panel.clock_text().begins_with("0:3") or _panel.clock_text() == "0:40")
	_set_kills(2, 2)
	_set_kills(3, 1)
	await _wait(0.2)
	print("[test] HUD: %s | %s | %s | %s" % [_panel.clock_text(), _panel.leader_text(), _panel.place_text(), _panel.top_names()])
	_check("HUD pokazuje lidera", _panel.leader_text() == "Prowadzi Cel · 2")
	_check("HUD pokazuje miejsce gracza", _panel.place_text().begins_with("Twoje miejsce: 3 z 3"))
	_check("trzech najlepszych", _panel.top_names() == ["Cel", "Basia", "Gracz"])
	_check("pelna lista pod Tab ma miejsca", _has_label(hud, "1. Cel"))
	_check("bez sygnalu konca na poczatku", not _panel.is_final_warning())
	# Baner trwa RoundPanel.BANNER_SECONDS, wiec sprawdzamy go zaraz po progu 30 s.
	while Match.seconds_left() > 29.0:
		await _wait(0.2)
	await _wait(0.3)
	_check("ostatnie 30 s: sygnal", _panel.is_final_warning() and _panel._banner.visible)
	await _shot("round_hud.png")

	# Smiec po rundzie: przedmiot na ziemi, otwarta skrzynka, rany i dodatkowa bron.
	GameState.server_give_item(1, &"knife", Rarity.Tier.COMMON)
	var me := GameState.player_node(1)
	WorldItems.server_scatter([GameState.server_new_stack(&"shotgun", Rarity.Tier.EPIC)], me.position, me.get_world_3d())
	Chests._chest_opened.rpc(1, 1, Rarity.Tier.COMMON)
	GameState.server_damage(1, 30, 2)
	await _wait(0.3)
	_check("jest co sprzatac", not WorldItems.items.is_empty() and Chests.chests[1].open)

	# Limit zabojstw lidera konczy runde od razu.
	_set_kills(2, 3)
	await _wait(0.3)
	_check("limit konczy runde", Match.phase == Match.Phase.RESULTS)
	_check("wyniki od lidera", not Match.results.is_empty() and Match.results[0].name == "Cel" and Match.results[0].place == 1)
	_check("ekran zwyciezcy", _match_panel._results_center.visible and _match_panel._results_title.text == "Wygrywa Cel")
	_check("odliczanie do nowej rundy", _match_panel._results_timer.text.begins_with("Nowa runda za"))
	_check("w czasie wynikow nie ma walki", not Match.allows_combat())
	await _shot("round_results.png")
	_check("karty glosowania widac", _match_panel._vote_panel.visible and _match_panel._vote_cards.size() == Match.VOTE_MAPS.size())
	if get_window().has_focus():
		_check("kursor widac w czasie glosowania", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	Match.votes = { 2: Match.VOTE_MAPS[0], 3: Match.VOTE_MAPS[0] }
	_match_panel._cast_vote(1)
	await _wait(0.5)
	_check("wlasny glos zaznaczony", Match.votes.get(1, "") == Match.VOTE_MAPS[1] and _match_panel._vote_cards[1].badge.visible)
	_check("liczba glosow na karcie", _match_panel._vote_cards[0].count.text == "2 głosy" and _match_panel._vote_cards[1].count.text == "1 głos")
	_check("odmiana glosow", MatchPanel.votes_text(0) == "0 głosów" and MatchPanel.votes_text(13) == "13 głosów" and MatchPanel.votes_text(22) == "22 głosy")
	await _shot("map_vote.png")
	Match.votes.clear()
	await _wait(Match.ROUND_RESULTS_SECONDS + 1.0)
	# Bez fokusu okno nie lapie kursora, wiec sprawdzamy to tylko, gdy test ma fokus.
	if get_window().has_focus():
		_check("po glosowaniu kursor znika", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_check("nowa runda bez restartu", Match.phase == Match.Phase.LIVE and Match.round_number == 2)
	_check("wyniki wyzerowane", _all_zero())
	_check("lup sprzatniety", WorldItems.items.is_empty())
	_check("skrzynki zamkniete", not Chests.chests[1].open)
	_check("pelne zdrowie", GameState.players[1].health == GameState.MAX_HEALTH)
	_check("tylko bron startowa", _items_of(1) == 1)
	_check("zegar od nowa", absf(Match.seconds_left() - 40.0) < 2.0)

	# Remis: dwoch graczy na tym samym miejscu.
	_set_kills(1, 3)
	_set_kills(3, 3)
	await _wait(0.3)
	_check("remis konczy runde", Match.phase == Match.Phase.RESULTS)
	var winners := Match.results.filter(func(entry: Dictionary) -> bool: return entry.place == 1)
	_check("remis: dwa pierwsze miejsca", winners.size() == 2)
	_check("remis na ekranie", _match_panel._results_title.text == "Remis")
	await _wait(Match.ROUND_RESULTS_SECONDS + 1.0)
	_check("runda 3", Match.phase == Match.Phase.LIVE and Match.round_number == 3)

	# Koniec czasu tez konczy runde.
	while Match.phase == Match.Phase.LIVE:
		await _wait(0.5)
	_check("koniec czasu konczy runde", Match.phase == Match.Phase.RESULTS and Match.round_number == 3)
	get_tree().quit(1 if _failures > 0 else 0)


func _set_kills(id: int, kills: int) -> void:
	GameState.players[id].kills = kills
	GameState._broadcast(id)


func _all_zero() -> bool:
	for id: int in GameState.players:
		if GameState.players[id].kills != 0 or GameState.players[id].deaths != 0:
			return false
	return true


func _items_of(id: int) -> int:
	var count := 0
	for stack: Dictionary in GameState.players[id].slots:
		count += 0 if ItemStack.is_empty(stack) else 1
	return count


func _has_label(root: Node, text: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false


func _shot(file: String) -> void:
	var shot_dir: String = Net.args.get("shot-dir", "")
	if shot_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(file))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
