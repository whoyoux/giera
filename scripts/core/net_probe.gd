extends Node
## Mierzy straty pakietow, odsylajac male numerowane pakiety. Statystyka ENet tego nie pokaze,
## bo pomija zawodne pakiety, a nimi idzie prawie caly ruch gry. Dziala tylko przy wlaczonym wykresie.
## Wynik dotyczy drogi w obie strony: pakiet moze zginac w drodze tam albo z powrotem.

const SEND_SECONDS := 0.1
const ANSWER_SECONDS := 1.0
const WINDOW := 50

var enabled := false:
	set(value):
		enabled = value
		_peers.clear()

var _peers := {}
var _next_id := 0
var _timer := 0.0


## Procent zgubionych pakietow u najgorszego z polaczonych graczy.
func worst_loss() -> float:
	var worst := 0.0
	for state: Dictionary in _peers.values():
		var results: Array = state.results
		if not results.is_empty():
			worst = maxf(worst, results.count(false) * 100.0 / results.size())
	return worst


func _process(delta: float) -> void:
	if not enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for state: Dictionary in _peers.values():
		_expire(state, now)
	_timer += delta
	if _timer < SEND_SECONDS:
		return
	_timer = 0.0
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_peers.clear()
		return
	var targets: Array = Array(multiplayer.get_peers()) if multiplayer.is_server() else [1]
	for id: int in _peers.keys():
		if not targets.has(id):
			_peers.erase(id)
	for id: int in targets:
		var state: Dictionary = _peers.get_or_add(id, {"waiting": {}, "results": []})
		state.waiting[_next_id] = now
		_receive_probe.rpc_id(id, _next_id)
	_next_id += 1


func _expire(state: Dictionary, now: float) -> void:
	for probe_id: int in state.waiting.keys():
		if now - state.waiting[probe_id] > ANSWER_SECONDS:
			state.waiting.erase(probe_id)
			_add_result(state, false)


func _add_result(state: Dictionary, arrived: bool) -> void:
	state.results.append(arrived)
	if state.results.size() > WINDOW:
		state.results.pop_front()


@rpc("any_peer", "call_remote", "unreliable")
func _receive_probe(probe_id: int) -> void:
	_receive_answer.rpc_id(multiplayer.get_remote_sender_id(), probe_id)


@rpc("any_peer", "call_remote", "unreliable")
func _receive_answer(probe_id: int) -> void:
	var state: Dictionary = _peers.get(multiplayer.get_remote_sender_id(), {})
	if state.has("waiting") and state.waiting.erase(probe_id):
		_add_result(state, true)
