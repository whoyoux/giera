extends Node
## Tryb i przebieg gry na tym serwerze. O etapach decyduje serwer, a klient dostaje je przez RPC,
## wiec zawsze gra w to, co serwer prowadzi, nawet gdy w menu wybral co innego.
## Deathmatch gra rundami: LIVE z limitem czasu i zabojstw, potem RESULTS i od razu nowa runda.

signal phase_changed
## Wynik druzyn Team Deathmatchu zmienil sie bez zmiany etapu.
signal team_scores_changed

enum Phase { LOBBY, COUNTDOWN, STARTING, LIVE, RESULTS }

const MIN_PLAYERS := 2
const COUNTDOWN_SECONDS := 5.0
## Tyle czasu klienci maja na odebranie wiadomosci o przeniesieniu, zanim do niego dojdzie.
const TELEPORT_LEAD_SECONDS := 0.5
const FREEZE_SECONDS := 3.0
const MAX_MATCH_PLAYERS := 10
const RESULTS_SECONDS := 10.0
const ZONE_DAMAGE_INTERVAL := 1.0
## Runda Deathmatchu: czas, limit zabojstw lidera i czas ekranu wynikow. Testy skracaja je flagami
## --round-seconds i --round-kill-limit.
const ROUND_SECONDS := 300.0
const ROUND_KILL_LIMIT := 25
## Team Deathmatch konczy sie, gdy jedna druzyna zbierze tyle zabojstw.
const TEAM_KILL_LIMIT := 50
const ROUND_RESULTS_SECONDS := 12.0
const FINAL_WARNING_SECONDS := 30.0
## Mapy do wyboru w glosowaniu miedzy rundami Deathmatchu.
const VOTE_MAPS: Array[String] = ["city", "desert", "forest"]
## Tick, ktory nigdy nie nadejdzie: wyeliminowany nie wraca sam do gry.
const NEVER_TICK := 1 << 62

var mode := GameMode.Id.DEATHMATCH
var phase := Phase.LIVE
## Tick konca etapu albo -1, gdy etap nie ma limitu czasu.
var phase_end_tick := -1
var freeze_from_tick := -1
var freeze_end_tick := -1
var zone: Zone
var zone_start_tick := -1
## Tylko do testow: przyspiesza strefe flaga --zone-speed.
var zone_speed := 1.0
var zone_seed := 0
## Wyniki ostatniego meczu: { id, name, kills, place } od zwyciezcy w dol.
var results: Array = []
## Numer rundy Deathmatchu od startu serwera i limit zabojstw, ktory ja konczy.
var round_number := 0
var kill_limit := ROUND_KILL_LIMIT
## Glosy na nastepna mape: numer gracza -> id mapy. Zbierane w czasie wynikow rundy.
var votes := {}
## Zabojstwa druzyn w tej rundzie Team Deathmatchu. Odejscie gracza ich nie zmniejsza.
var team_scores: Array = [0, 0]
## Druzyna, ktora wygrala ostatnia runde, albo -1 przy remisie i poza Team Deathmatchem.
var winning_team := -1

## Gracze meczu, razem z tymi, ktorzy juz wyszli z gry: id -> { id, name, kills, place }.
var _ranking := {}
## Kto odpadl od ostatniego rozliczenia. Smierci z jednego wybuchu rozliczamy razem.
var _pending_out: Array[int] = []
var _settle_queued := false
var _zone_timer := 0.0
var _team_retry_ms := 0


func _ready() -> void:
	GameState.player_added.connect(func(_id: int) -> void: _update_lobby())
	GameState.player_removed.connect(_on_player_removed)
	Net.session_ended.connect(func(_reason: String) -> void: _clear())
	GameState.player_changed.connect(_on_player_changed)


func is_elimination() -> bool:
	return mode == GameMode.Id.BATTLE_ROYALE


func is_team_mode() -> bool:
	return mode == GameMode.Id.TEAM_DEATHMATCH


## Obrazenia i skrzynki dzialaja tylko w trakcie meczu.
func allows_combat() -> bool:
	return phase == Phase.LIVE


func starts_armed() -> bool:
	return not is_elimination()


## Dolaczajacy po starcie meczu oglada go do konca.
func accepts_new_players() -> bool:
	return not is_elimination() or can_change_ready()


func respawn_tick_after_death(tick: int, respawn_seconds: float) -> int:
	return NEVER_TICK if is_elimination() else tick + NetworkTime.seconds_to_ticks(respawn_seconds)


## Zywi uczestnicy meczu. Wiadomosc o zabojstwie przychodzi przed nowym stanem ofiary,
## wiec lista zabojstw pomija ja przez "excluded".
func alive_count(excluded := 0) -> int:
	var count := 0
	for id: int in GameState.players:
		var info: Dictionary = GameState.players[id]
		count += 1 if info.alive and info.in_match and id != excluded else 0
	return count


## Czas tuz po przeniesieniu, gdy gracze stoja na swoich miejscach.
func is_frozen_at(tick: int) -> bool:
	return tick >= freeze_from_tick and tick < freeze_end_tick


## Bron i przedmioty nie dzialaja w chwili po przeniesieniu i na ekranie wynikow.
## Serwer i tak nie zada wtedy obrazen, ale bez tej blokady u gracza lecialyby strzaly i ubywala amunicja.
func blocks_items_at(tick: int) -> bool:
	return is_frozen_at(tick) or phase == Phase.RESULTS


func can_change_ready() -> bool:
	return is_elimination() and (phase == Phase.LOBBY or phase == Phase.COUNTDOWN)


## Stan strefy albo pusty slownik, gdy mecz nie trwa.
func zone_state() -> Dictionary:
	if zone == null or phase != Phase.LIVE:
		return {}
	return zone.state_at(maxf(0.0, (NetworkTime.tick - zone_start_tick) * NetworkTime.ticktime * zone_speed))


## Sekundy do konca etapu.
func seconds_left() -> float:
	return maxf(0.0, (phase_end_tick - NetworkTime.tick) * NetworkTime.ticktime) if phase_end_tick >= 0 else 0.0


## Boty same wybieraja druzyne, zeby dalo sie testowac Team Deathmatch bez klikania.
## --team=0 albo --team=1 wskazuje druzyne, a bez tego bot idzie do mniejszej.
## Serwer odmawia, gdy wybrana druzyna jest za duza, wiec bot ponawia prosbe co chwile.
func _on_player_changed(id: int) -> void:
	if Net.bot_mode.is_empty() or not is_team_mode() or id != multiplayer.get_unique_id():
		return
	var now := Time.get_ticks_msec()
	if Teams.team_of(id) == Teams.NONE and now >= _team_retry_ms:
		_team_retry_ms = now + 2000
		request_team(int(Net.args.get("team", Teams.NONE)))


func toggle_ready() -> void:
	var info: Dictionary = GameState.players.get(multiplayer.get_unique_id(), {})
	if can_change_ready() and not info.is_empty():
		_request_ready.rpc_id(1, not info.ready)


# --- Serwer -----------------------------------------------------------------

## Wolane przed startem nasluchu, wiec pierwszy gracz zastaje juz wlasciwy tryb.
func server_begin(new_mode: int) -> void:
	mode = new_mode
	phase = Phase.LOBBY if is_elimination() else Phase.LIVE
	phase_end_tick = -1
	round_number = 0 if is_elimination() else 1
	kill_limit = int(Net.args.get("round-kill-limit", TEAM_KILL_LIMIT if is_team_mode() else ROUND_KILL_LIMIT))
	team_scores = [0, 0]
	winning_team = -1
	freeze_from_tick = -1
	freeze_end_tick = -1
	phase_changed.emit()


## Gracz odpadl przez smierc albo wyjscie z gry. Wynik sprawdzamy dopiero pod koniec klatki,
## bo granat zabija po kolei, a jednoczesna smierc ostatnich graczy to remis.
## Po ostatnim rozliczeniu nic juz nie liczymy, bo wyjscie w czasie wynikow nie zmienia wyniku.
func server_on_player_out(id: int) -> void:
	if not is_elimination() or (phase != Phase.STARTING and phase != Phase.LIVE):
		return
	_pending_out.append(id)
	_remember_result(id)
	if not _settle_queued:
		_settle_queued = true
		_settle.call_deferred()


## Dolaczajacy gracz musi znac etap, zanim powstanie jego postac.
func server_send_state(id: int) -> void:
	_sync_state.rpc_id(id, _state())


func _process(delta: float) -> void:
	if Net.in_session and not multiplayer.is_server() and not Net.bot_mode.is_empty() and Engine.get_process_frames() % 30 == 0:
		_on_player_changed(multiplayer.get_unique_id())
	if not Net.in_session or not multiplayer.is_server():
		return
	if not is_elimination():
		_update_round()
		return
	_update_zone_damage(delta)
	if phase_end_tick < 0 or NetworkTime.tick < phase_end_tick:
		return
	match phase:
		Phase.COUNTDOWN:
			_start_match()
		Phase.STARTING:
			_enter_phase(Phase.LIVE, -1)
			_settle()
		Phase.RESULTS:
			_return_to_lobby()


## Ranking Deathmatchu: wiecej zabojstw wyzej, a rowna liczba to to samo miejsce.
## Zwraca { id, name, kills, deaths, place } od lidera w dol.
static func standings() -> Array:
	var rows := []
	for id: int in GameState.players:
		var info: Dictionary = GameState.players[id]
		rows.append({ "id": id, "name": info.name, "kills": info.kills, "deaths": info.deaths, "place": 0 })
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.kills > b.kills or (a.kills == b.kills and (a.deaths < b.deaths or (a.deaths == b.deaths and a.id < b.id))))
	for row: Dictionary in rows:
		row.place = 1 + rows.filter(func(other: Dictionary) -> bool: return other.kills > row.kills).size()
	return rows


## Pusty serwer czeka z zegarem na pierwszego gracza, zeby nikt nie trafil na koncowke rundy.
func _update_round() -> void:
	match phase:
		Phase.LIVE:
			if GameState.players.is_empty():
				if phase_end_tick >= 0:
					phase_end_tick = -1
				return
			if phase_end_tick < 0:
				_enter_phase(Phase.LIVE, NetworkTime.tick + NetworkTime.seconds_to_ticks(_round_seconds()))
				print("[serwer] runda %d do ticku %d" % [round_number, phase_end_tick])
				return
			var rows := standings()
			var best: int = maxi(team_scores[0], team_scores[1]) if is_team_mode() else (rows[0].kills if not rows.is_empty() else 0)
			if NetworkTime.tick >= phase_end_tick or best >= kill_limit:
				_finish_round(rows)
		Phase.RESULTS:
			if NetworkTime.tick >= phase_end_tick:
				_start_next_round()


func _round_seconds() -> float:
	return float(Net.args.get("round-seconds", ROUND_SECONDS))


func _finish_round(rows: Array) -> void:
	results = rows.map(func(row: Dictionary) -> Dictionary:
		var info: Dictionary = GameState.players.get(row.id, {})
		return { "id": row.id, "name": row.name, "kills": row.kills, "deaths": row.deaths, "place": row.place, "character": info.get("character", ""),
			"shots": info.get("shots", 0), "hits": info.get("hits", 0), "headshots": info.get("headshots", 0), "team": info.get("team", Teams.NONE) })
	if is_team_mode():
		winning_team = -1 if team_scores[0] == team_scores[1] else (0 if team_scores[0] > team_scores[1] else 1)
		results = team_results(results, winning_team)
	print("[serwer] koniec rundy %d, lider: %s" % [round_number, results[0].name if not results.is_empty() else "-"])
	_enter_phase(Phase.RESULTS, NetworkTime.tick + NetworkTime.seconds_to_ticks(ROUND_RESULTS_SECONDS))


## Nowa runda bez restartu serwera: czysty lup, skrzynki, wyniki, zdrowie i przedmioty.
func _start_next_round() -> void:
	_apply_vote()
	var tick := NetworkTime.tick + NetworkTime.seconds_to_ticks(TELEPORT_LEAD_SECONDS)
	results = []
	team_scores = [0, 0]
	winning_team = -1
	round_number += 1
	# Chwila na rozejrzenie sie po przeniesieniu, zanim ktos zacznie strzelac. Zamrozenie rusza
	# od razu, bo do przeniesienia gracze stoja jeszcze tam, gdzie skonczyli runde.
	freeze_from_tick = NetworkTime.tick
	freeze_end_tick = tick + NetworkTime.seconds_to_ticks(FREEZE_SECONDS)
	_clear_world.rpc()
	for id: int in GameState.players:
		if is_team_mode() and Teams.team_of(id) == Teams.NONE:
			GameState.server_make_spectator(id, tick)
		else:
			GameState.server_prepare_round(id, -1, tick)
	_enter_phase(Phase.LIVE, tick + NetworkTime.seconds_to_ticks(_round_seconds()))
	print("[serwer] runda %d do ticku %d" % [round_number, phase_end_tick])


## Najwiecej glosow wygrywa, a remis zostawia obecna mape. Swiat podmienia sie bez restartu serwera.
func _apply_vote() -> void:
	var counts := vote_counts()
	var best := Maps.current_id
	for map_id: String in counts:
		if counts[map_id] > counts.get(best, 0):
			best = map_id
	votes.clear()
	if best != Maps.current_id:
		print("[serwer] glosowanie wybralo mape %s" % best)
		Maps.select(best)


func vote_counts() -> Dictionary:
	var counts := {}
	for id: int in votes:
		if GameState.players.has(id):
			counts[votes[id]] = counts.get(votes[id], 0) + 1
	return counts


func can_vote() -> bool:
	return not is_elimination() and phase == Phase.RESULTS


func vote(map_id: String) -> void:
	if can_vote():
		_request_vote.rpc_id(1, map_id)


## Raz na sekunde bije wszystkich zywych poza strefa. Atakujacym jest sama strefa.
func _update_zone_damage(delta: float) -> void:
	var state := zone_state()
	if state.is_empty():
		_zone_timer = 0.0
		return
	_zone_timer += delta
	if _zone_timer < ZONE_DAMAGE_INTERVAL:
		return
	_zone_timer -= ZONE_DAMAGE_INTERVAL
	for id: int in GameState.players.keys():
		var node := GameState.player_node(id)
		if node != null and node.is_alive() and node.info.in_match and Zone.is_outside(state, node.position):
			GameState.server_damage(id, state.damage, GameState.ZONE_ATTACKER)


## Pusty serwer od razu czeka na nowy mecz, zeby nikt nie trafil na koncowke starego.
func _on_player_removed(_id: int) -> void:
	if Net.in_session and multiplayer.is_server() and is_elimination() and GameState.players.is_empty() and phase != Phase.LOBBY:
		_return_to_lobby()
	else:
		_update_lobby()


## Start wymaga co najmniej 2 graczy i gotowosci wszystkich. Nowy gracz nie jest gotowy,
## wiec jego dolaczenie przerywa odliczanie.
func _update_lobby() -> void:
	if not Net.in_session or not multiplayer.is_server() or not can_change_ready():
		return
	var everyone_ready := GameState.players.size() >= MIN_PLAYERS
	for id: int in GameState.players:
		everyone_ready = everyone_ready and GameState.players[id].ready
	if phase == Phase.LOBBY and everyone_ready:
		_enter_phase(Phase.COUNTDOWN, NetworkTime.tick + NetworkTime.seconds_to_ticks(COUNTDOWN_SECONDS))
	elif phase == Phase.COUNTDOWN and not everyone_ready:
		_enter_phase(Phase.LOBBY, -1)


## Kazdy dostaje inne miejsce, a przeniesienie korzysta z mechanizmu odrodzenia.
func _start_match() -> void:
	var spots := range(get_tree().get_nodes_in_group(&"spawn_points").size())
	spots.shuffle()
	var start_tick := NetworkTime.tick + NetworkTime.seconds_to_ticks(TELEPORT_LEAD_SECONDS)
	freeze_from_tick = start_tick
	freeze_end_tick = start_tick + NetworkTime.seconds_to_ticks(FREEZE_SECONDS)
	# Zero oznacza brak strefy, wiec ziarno jest zawsze nieparzyste.
	zone_seed = randi() | 1
	zone_start_tick = freeze_end_tick
	zone_speed = float(Net.args.get("zone-speed", 1.0))
	zone = Zone.new(zone_seed)
	_clear_world.rpc()
	_enter_phase(Phase.STARTING, freeze_end_tick)
	var index := 0
	_ranking.clear()
	for id: int in GameState.players:
		if index < MAX_MATCH_PLAYERS:
			GameState.server_prepare_round(id, spots[index % spots.size()], start_tick)
			_remember_result(id)
		else:
			GameState.server_make_spectator(id, start_tick)
		index += 1
	print("[serwer] start meczu, graczy: %d" % mini(index, MAX_MATCH_PLAYERS))


## Miejsce to liczba zywych plus jeden, wiec gracze zabici w tej samej chwili maja to samo.
func _settle() -> void:
	_settle_queued = false
	if phase != Phase.LIVE:
		return
	var alive := alive_count()
	for id: int in _pending_out:
		GameState.server_set_place(id, alive + 1)
		_ranking[id].place = alive + 1
	_pending_out.clear()
	if alive > 1:
		return
	print("[serwer] koniec meczu, zywych: %d" % alive)
	_finish_match()


## Zapamietuje wynik, zanim gracz zniknie z listy. Zabojstwa zwyciezcy dochodza na koncu.
func _remember_result(id: int) -> void:
	var info: Dictionary = GameState.players[id]
	var place: int = _ranking[id].place if _ranking.has(id) else 0
	_ranking[id] = { "id": id, "name": info.name, "kills": info.kills, "place": place }


func _finish_match() -> void:
	for id: int in _ranking:
		var info: Dictionary = GameState.players.get(id, {})
		if info.is_empty():
			continue
		_ranking[id].kills = info.kills
		if info.alive:
			_ranking[id].place = 1
			GameState.server_set_place(id, 1)
	results = _ranking.values()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.place < b.place or (a.place == b.place and a.kills > b.kills))
	_enter_phase(Phase.RESULTS, NetworkTime.tick + NetworkTime.seconds_to_ticks(RESULTS_SECONDS))


## Reset bez restartu serwera: wszyscy, takze widzowie, wracaja do lobby z czystym stanem.
func _return_to_lobby() -> void:
	var tick := NetworkTime.tick + NetworkTime.seconds_to_ticks(TELEPORT_LEAD_SECONDS)
	freeze_from_tick = -1
	freeze_end_tick = -1
	results = []
	zone = null
	zone_seed = 0
	_ranking.clear()
	_pending_out.clear()
	_clear_world.rpc()
	_enter_phase(Phase.LOBBY, -1)
	for id: int in GameState.players:
		GameState.server_prepare_round(id, -1, tick)
	print("[serwer] powrot do lobby")


func _enter_phase(new_phase: int, end_tick: int) -> void:
	phase = new_phase
	phase_end_tick = end_tick
	print("[serwer] etap %s" % Phase.find_key(new_phase))
	phase_changed.emit()
	_sync_state.rpc(_state())


func _state() -> Dictionary:
	return { "map": Maps.current_id, "votes": votes, "mode": mode, "team_scores": team_scores, "winning_team": winning_team, "round": round_number, "kill_limit": kill_limit, "phase": phase, "phase_end_tick": phase_end_tick, "freeze_from_tick": freeze_from_tick, "freeze_end_tick": freeze_end_tick, "results": results, "zone_seed": zone_seed, "zone_start_tick": zone_start_tick, "zone_speed": zone_speed }


func _clear() -> void:
	_team_retry_ms = 0
	mode = GameMode.Id.DEATHMATCH
	team_scores = [0, 0]
	winning_team = -1
	round_number = 0
	kill_limit = ROUND_KILL_LIMIT
	phase = Phase.LIVE
	phase_end_tick = -1
	freeze_from_tick = -1
	freeze_end_tick = -1
	results = []
	zone = null
	zone_seed = 0
	_ranking.clear()
	_pending_out.clear()
	phase_changed.emit()


## Wyniki Team Deathmatchu: najpierw wygrana druzyna, w niej od najlepszego. Podium bierze
## trzech pierwszych, czyli najlepszych zwyciezcow. Przy remisie kolejnosc daja same zabojstwa.
static func team_results(rows: Array, winner: int) -> Array:
	var sorted := rows.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_won: bool = winner >= 0 and a.get("team", -1) == winner
		var b_won: bool = winner >= 0 and b.get("team", -1) == winner
		if a_won != b_won:
			return a_won
		if a.kills != b.kills:
			return a.kills > b.kills
		return a.get("deaths", 0) < b.get("deaths", 0) or (a.get("deaths", 0) == b.get("deaths", 0) and a.id < b.id))
	for index in sorted.size():
		sorted[index].place = index + 1
	return sorted


## Najlepszy gracz druzyny w wynikach: najwiecej zabojstw, potem najmniej smierci. Pusty, gdy nikogo nie ma.
static func team_mvp(rows: Array, team: int) -> Dictionary:
	var best := {}
	for row: Dictionary in rows:
		if row.get("team", -1) != team:
			continue
		if best.is_empty() or row.kills > best.kills or (row.kills == best.kills and row.get("deaths", 0) < best.get("deaths", 0)):
			best = row
	return best


## Druzyna, ktora teraz prowadzi, albo -1 przy remisie.
func leading_team() -> int:
	if team_scores[0] == team_scores[1]:
		return -1
	return 0 if team_scores[0] > team_scores[1] else 1


## -1 wybiera mniejsza druzyne.
func request_team(team: int) -> void:
	if is_team_mode():
		_request_team.rpc_id(1, team)


## Punkt dla druzyny zabojcy. Wolane przez serwer przy kazdym zabojstwie wroga.
func server_on_team_kill(team: int) -> void:
	if not is_team_mode() or team < 0 or team >= Teams.COUNT or phase != Phase.LIVE:
		return
	team_scores[team] += 1
	team_scores_changed.emit()
	_sync_team_scores.rpc(team_scores)


# --- RPC --------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _request_ready(value: bool) -> void:
	if not multiplayer.is_server() or not can_change_ready():
		return
	GameState.server_set_ready(multiplayer.get_remote_sender_id(), value)
	_update_lobby()


@rpc("any_peer", "call_local", "reliable")
func _request_vote(map_id: String) -> void:
	if not multiplayer.is_server() or not can_vote() or not VOTE_MAPS.has(map_id):
		return
	votes[multiplayer.get_remote_sender_id()] = map_id
	phase_changed.emit()
	_sync_state.rpc(_state())


## Serwer pilnuje rownowagi, a odmowa po prostu nic nie zmienia.
@rpc("any_peer", "call_local", "reliable")
func _request_team(team: int) -> void:
	if not multiplayer.is_server() or not is_team_mode():
		return
	var id := multiplayer.get_remote_sender_id()
	if not GameState.players.has(id):
		return
	var chosen := Teams.smaller_team(id) if team == Teams.NONE else team
	if chosen == Teams.team_of(id):
		return
	if not Teams.can_join(id, chosen):
		print("[serwer] %s nie moze dolaczyc do druzyny %d" % [GameState.display_name(id), chosen])
		return
	GameState.server_set_team(id, chosen)


@rpc("authority", "call_remote", "reliable")
func _sync_team_scores(scores: Array) -> void:
	team_scores = scores
	team_scores_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync_state(state: Dictionary) -> void:
	# Mapa musi stac, zanim powstana postacie i skrzynki z nastepnych wiadomosci.
	Maps.select(state.map)
	votes = state.votes
	mode = state.mode
	team_scores = state.team_scores
	winning_team = state.winning_team
	round_number = state.round
	kill_limit = state.kill_limit
	phase = state.phase
	phase_end_tick = state.phase_end_tick
	freeze_from_tick = state.freeze_from_tick
	freeze_end_tick = state.freeze_end_tick
	results = state.results
	zone_start_tick = state.zone_start_tick
	zone_speed = state.zone_speed
	if state.zone_seed != zone_seed:
		zone_seed = state.zone_seed
		zone = Zone.new(zone_seed) if zone_seed != 0 else null
	phase_changed.emit()


## Nic z poprzedniej rundy nie moze przejsc do nastepnej.
@rpc("authority", "call_local", "reliable")
func _clear_world() -> void:
	WorldItems.clear()
	SupplyDrops.clear()
	Grenades.clear()
	Chests.reset()
