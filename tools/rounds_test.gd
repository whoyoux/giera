extends Node
## Test trybu Rundy jako host: rozgrzewka bez rywali, zestawy i ich zmiana w czasie wyboru,
## brak skrzynek i odradzania, wygrana rundy przez eliminacje i na czas, zabojstwa zachowane
## miedzy rundami, koniec meczu po komplecie wygranych i nowy mecz.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --round-seconds=6
##         --round-kill-limit=2 --tool=res://tools/rounds_test.gd [--shot-dir=C:/folder]

const PORT := 8149

var _failures := 0
var _hud: Hud
var _round_panel: RoundPanel
var _match_panel: MatchPanel


func _ready() -> void:
	_check("host startuje w trybie Rundy", Net.start_server(PORT, false, GameMode.Id.ROUNDS).is_empty())
	await _wait(1.5)
	_hud = get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(_hud._on_focus_lost)
	_round_panel = _hud.find_children("*", "RoundPanel", true, false)[0] as RoundPanel
	_match_panel = _hud.find_children("*", "MatchPanel", true, false)[0] as MatchPanel
	_check("mapa to Pustynia", Maps.current_id == "desert")
	_check("tryb druzynowy bez odradzania", Match.is_team_mode() and Match.is_rounds_mode() and not Match.has_respawn())
	_check("bez skrzynek i regeneracji", not Match.uses_chests() and not Match.uses_regen())
	_check("bez glosowania", not Match.can_vote())
	GameState.server_add_player(2, "Basia")
	GameState.server_add_player(3, "Cel")
	await _wait(0.3)
	_check("gracze bez druzyny ogladaja", not GameState.players[1].in_match and not GameState.players[2].in_match)
	_check("bez rywali to rozgrzewka", Match.duel_number == 0)

	# Druzyny: host i Basia w Alfie, Cel w Bravo. Druga druzyna rusza prawdziwa runde.
	GameState.server_set_team(1, 0)
	GameState.server_set_team(2, 0)
	await _wait(0.3)
	_check("jedna druzyna to dalej rozgrzewka", Match.duel_number == 0)
	GameState.server_set_team(3, 1)
	await _wait(0.6)
	_check("rywal zaczyna runde 1", Match.duel_number == 1 and Match.in_buy_time())
	_revive_fakes()
	_check("wynik 0:0", Match.team_scores == [0, 0])
	_check("zestaw domyslny: Szturm", _items_of(1) == _loadout(Loadouts.DEFAULT))
	var loadout_panel := _hud.find_children("*", "LoadoutPanel", true, false)[0] as LoadoutPanel
	await _wait(0.2)
	_check("panel zestawow widac w czasie wyboru", loadout_panel.visible)
	_check("napis pod zegarem mowi o rundzie", _round_panel.place_text().begins_with("Runda 1"))
	var chest_field := get_node("/root/Main").find_children("*", "ChestField", false, false)[0] as ChestField
	_check("skrzynki schowane", not chest_field.visible)
	await _shot("rounds_buy.png")

	GameState.server_set_loadout(1, 2)
	await _wait(0.3)
	_check("zmiana zestawu od razu w czasie wyboru", _items_of(1) == _loadout(2) and GameState.players[1].loadout == 2)

	# Po czasie wyboru: eliminacja jedynego gracza Bravo daje runde Alfie.
	while Match.in_buy_time():
		await _wait(0.2)
	await _wait(0.3)
	GameState.server_damage(3, 500, 1)
	await _wait(0.3)
	_check("eliminacja wygrywa runde", Match.team_scores == [1, 0])
	_check("wyeliminowany nie wraca w tej rundzie", not GameState.players[3].alive and GameState.players[3].respawn_tick == Match.NEVER_TICK)
	_check("baner zwyciezcy rundy", _round_panel._banner.visible and _round_panel._banner_label.text == "Rundę wygrywa Twoja drużyna")
	await _shot("rounds_win.png")
	GameState.server_set_loadout(1, 1)
	await _wait(0.2)
	_check("po starcie walki zestaw czeka na nastepna runde", _items_of(1) != _loadout(1))

	# Przerwa i runda 2: wszyscy zywi w bazach, zabojstwa zostaja.
	await _wait(Match.ROUNDS_BREAK_SECONDS + 1.0)
	_check("runda 2", Match.duel_number == 2 and Match.in_buy_time())
	_revive_fakes()
	_check("Cel znow zyje", GameState.players[3].alive)
	_check("zabojstwa zostaja miedzy rundami", GameState.players[1].kills == 1 and GameState.players[3].deaths == 1)
	_check("nowy zestaw na nowej rundzie", _items_of(1) == _loadout(1))

	# Druga wygrana konczy mecz (limit 2 z flagi testu).
	while Match.in_buy_time():
		await _wait(0.2)
	await _wait(0.3)
	Match.request_team(1)
	await _wait(0.2)
	_check("zmiana druzyny po starcie walki odrzucona", Teams.team_of(1) == 0 and GameState.players[1].alive)
	GameState.server_damage(3, 500, 2)
	await _wait(Match.ROUNDS_BREAK_SECONDS + 1.0)
	_check("komplet wygranych konczy mecz", Match.phase == Match.Phase.RESULTS and Match.winning_team == 0)
	_check("ekran zwyciezcy meczu", _match_panel._results_center.visible and _match_panel._results_title.text == "Wygrywacie jako Alfa!")
	_check("nadtytul z wynikiem rund", _match_panel._results_eyebrow.text == "Koniec meczu · Rundy 2:0")
	_check("odliczanie do nowego meczu", _match_panel._results_timer.text.begins_with("Nowy mecz za"))
	_check("bez kart glosowania", not _match_panel._vote_panel.visible)
	await _shot("rounds_results.png")

	# Nowy mecz: wynik i statystyki od zera, potem wygrana na czas (2 zywych Alfy na 1 Bravo).
	await _wait(Match.ROUND_RESULTS_SECONDS + 1.0)
	_check("nowy mecz od rundy 1", Match.phase == Match.Phase.LIVE and Match.round_number == 2 and Match.duel_number == 1)
	_check("wynik meczu od zera", Match.team_scores == [0, 0] and GameState.players[1].kills == 0)
	_revive_fakes()
	while Match.phase == Match.Phase.LIVE and Match.duel_number == 1 and Match.team_scores == [0, 0]:
		await _wait(0.3)
	_check("koniec czasu: wygrywa druzyna z wieksza liczba zywych", Match.team_scores == [1, 0])
	get_tree().quit(1 if _failures > 0 else 0)


## Sztuczni gracze nie maja klienta, ktory dokonczylby przeniesienie, wiec konczy je test.
func _revive_fakes() -> void:
	for id in [2, 3]:
		GameState.server_finish_respawn(id)


## Nazwy przedmiotow jako tekst, zeby porownanie nie zalezalo od String i StringName.
func _items_of(id: int) -> Array:
	var items := []
	for stack: Dictionary in GameState.players[id].slots:
		if not ItemStack.is_empty(stack):
			items.append(str(stack.item))
	return items


func _loadout(index: int) -> Array:
	return Loadouts.items_of(index).map(func(item: StringName) -> String: return str(item))


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
