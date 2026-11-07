extends Node
## Tryb i przebieg gry na tym serwerze. O etapach decyduje serwer, a klient dostaje je przez RPC,
## wiec zawsze gra w to, co serwer prowadzi, nawet gdy w menu wybral co innego.
## Deathmatch gra rundami: LIVE z limitem czasu i zabojstw, potem RESULTS i od razu nowa runda.

signal phase_changed

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
const ROUND_RESULTS_SECONDS := 12.0
const FINAL_WARNING_SECONDS := 30.0
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

## Gracze meczu, razem z tymi, ktorzy juz wyszli z gry: id -> { id, name, kills, place }.
var _ranking := {}
## Kto odpadl od ostatniego rozliczenia. Smierci z jednego wybuchu rozliczamy razem.
var _pending_out: Array[int] = []
var _settle_queued := false
var _zone_timer := 0.0


func _ready() -> void:
	GameState.player_added.connect(func(_id: int) -> void: _update_lobby())
	GameState.player_removed.connect(_on_player_removed)
	Net.session_ended.connect(func(_reason: String) -> void: _clear())


func is_elimination() -> bool:
	return mode == GameMode.Id.BATTLE_ROYALE


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
	kill_limit = int(Net.args.get("round-kill-limit", ROUND_KILL_LIMIT))
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
			if NetworkTime.tick >= phase_end_tick or (not rows.is_empty() and rows[0].kills >= kill_limit):
				_finish_round(rows)
		Phase.RESULTS:
			if NetworkTime.tick >= phase_end_tick:
				_start_next_round()


func _round_seconds() -> float:
	return float(Net.args.get("round-seconds", ROUND_SECONDS))


func _finish_round(rows: Array) -> void:
	results = rows.map(func(row: Dictionary) -> Dictionary:
		var info: Dictionary = GameState.players.get(row.id, {})
		return { "id": row.id, "name": row.name, "kills": row.kills, "place": row.place, "character": info.get("character", ""),
			"shots": info.get("shots", 0), "hits": info.get("hits", 0), "headshots": info.get("headshots", 0) })
	print("[serwer] koniec rundy %d, lider: %s" % [round_number, results[0].name if not results.is_empty() else "-"])
	_enter_phase(Phase.RESULTS, NetworkTime.tick + NetworkTime.seconds_to_ticks(ROUND_RESULTS_SECONDS))


## Nowa runda bez restartu serwera: czysty lup, skrzynki, wyniki, zdrowie i przedmioty.
func _start_next_round() -> void:
	var tick := NetworkTime.tick + NetworkTime.seconds_to_ticks(TELEPORT_LEAD_SECONDS)
	results = []
	round_number += 1
	# Chwila na rozejrzenie sie po przeniesieniu, zanim ktos zacznie strzelac. Zamrozenie rusza
	# od razu, bo do przeniesienia gracze stoja jeszcze tam, gdzie skonczyli runde.
	freeze_from_tick = NetworkTime.tick
	freeze_end_tick = tick + NetworkTime.seconds_to_ticks(FREEZE_SECONDS)
	_clear_world.rpc()
	for id: int in GameState.players:
		GameState.server_prepare_round(id, -1, tick)
	_enter_phase(Phase.LIVE, tick + NetworkTime.seconds_to_ticks(_round_seconds()))
	print("[serwer] runda %d do ticku %d" % [round_number, phase_end_tick])


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
	return { "map": Maps.current_id, "mode": mode, "round": round_number, "kill_limit": kill_limit, "phase": phase, "phase_end_tick": phase_end_tick, "freeze_from_tick": freeze_from_tick, "freeze_end_tick": freeze_end_tick, "results": results, "zone_seed": zone_seed, "zone_start_tick": zone_start_tick, "zone_speed": zone_speed }


func _clear() -> void:
	mode = GameMode.Id.DEATHMATCH
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


# --- RPC --------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _request_ready(value: bool) -> void:
	if not multiplayer.is_server() or not can_change_ready():
		return
	GameState.server_set_ready(multiplayer.get_remote_sender_id(), value)
	_update_lobby()


@rpc("authority", "call_remote", "reliable")
func _sync_state(state: Dictionary) -> void:
	# Mapa musi stac, zanim powstana postacie i skrzynki z nastepnych wiadomosci.
	Maps.select(state.map)
	mode = state.mode
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
	Grenades.clear()
	Chests.reset()
