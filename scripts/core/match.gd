extends Node
## Tryb i przebieg gry na tym serwerze. O etapach decyduje serwer, a klient dostaje je przez RPC,
## wiec zawsze gra w to, co serwer prowadzi, nawet gdy w menu wybral co innego.
## Deathmatch ma stale etap LIVE, wiec reguly walki sa wspolne dla obu trybow.

signal phase_changed

enum Phase { LOBBY, COUNTDOWN, STARTING, LIVE }

const MIN_PLAYERS := 2
const COUNTDOWN_SECONDS := 5.0
## Tyle czasu klienci maja na odebranie wiadomosci o przeniesieniu, zanim do niego dojdzie.
const TELEPORT_LEAD_SECONDS := 0.5
const FREEZE_SECONDS := 3.0

var mode := GameMode.Id.DEATHMATCH
var phase := Phase.LIVE
## Tick konca etapu albo -1, gdy etap nie ma limitu czasu.
var phase_end_tick := -1
var freeze_from_tick := -1
var freeze_end_tick := -1


func _ready() -> void:
	GameState.player_added.connect(func(_id: int) -> void: _update_lobby())
	GameState.player_removed.connect(func(_id: int) -> void: _update_lobby())
	Net.session_ended.connect(func(_reason: String) -> void: _clear())


func is_elimination() -> bool:
	return mode == GameMode.Id.BATTLE_ROYALE


## Obrazenia i skrzynki dzialaja tylko w trakcie meczu.
func allows_combat() -> bool:
	return phase == Phase.LIVE


func starts_armed() -> bool:
	return not is_elimination()


## Czas tuz po przeniesieniu, gdy gracze stoja na swoich miejscach.
func is_frozen_at(tick: int) -> bool:
	return tick >= freeze_from_tick and tick < freeze_end_tick


func can_change_ready() -> bool:
	return is_elimination() and (phase == Phase.LOBBY or phase == Phase.COUNTDOWN)


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
	freeze_from_tick = -1
	freeze_end_tick = -1
	phase_changed.emit()


## Dolaczajacy gracz musi znac etap, zanim powstanie jego postac.
func server_send_state(id: int) -> void:
	_sync_state.rpc_id(id, _state())


func _process(_delta: float) -> void:
	if not Net.in_session or not is_elimination() or not multiplayer.is_server():
		return
	if phase_end_tick < 0 or NetworkTime.tick < phase_end_tick:
		return
	match phase:
		Phase.COUNTDOWN:
			_start_match()
		Phase.STARTING:
			_enter_phase(Phase.LIVE, -1)


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
	_clear_world.rpc()
	_enter_phase(Phase.STARTING, freeze_end_tick)
	var index := 0
	for id: int in GameState.players:
		GameState.server_prepare_round(id, spots[index % spots.size()], start_tick)
		index += 1
	print("[serwer] start meczu, graczy: %d" % index)


func _enter_phase(new_phase: int, end_tick: int) -> void:
	phase = new_phase
	phase_end_tick = end_tick
	print("[serwer] etap %s" % Phase.find_key(new_phase))
	phase_changed.emit()
	_sync_state.rpc(_state())


func _state() -> Dictionary:
	return { "mode": mode, "phase": phase, "phase_end_tick": phase_end_tick, "freeze_from_tick": freeze_from_tick, "freeze_end_tick": freeze_end_tick }


func _clear() -> void:
	mode = GameMode.Id.DEATHMATCH
	phase = Phase.LIVE
	phase_end_tick = -1
	freeze_from_tick = -1
	freeze_end_tick = -1
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
	mode = state.mode
	phase = state.phase
	phase_end_tick = state.phase_end_tick
	freeze_from_tick = state.freeze_from_tick
	freeze_end_tick = state.freeze_end_tick
	phase_changed.emit()


## Nic z poprzedniej rundy nie moze przejsc do nastepnej.
@rpc("authority", "call_local", "reliable")
func _clear_world() -> void:
	WorldItems.clear()
	Grenades.clear()
	Chests.reset()
