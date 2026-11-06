extends Node
## Czat tekstowy. Serwer tylko przekazuje wiadomosci dalej, a historia jest w pamieci klienta
## do konca sesji. Tresci nie wolno wypisywac do logu ani nigdzie zapisywac.

signal message_received(sender_id: int, text: String)
signal cleared

const MAX_LENGTH := 120
const BURST := 5
const BURST_SECONDS := 5.0
## Pakiety potrafia dojsc zbite w kupe, a uczciwy klient nie moze przez to tracic wiadomosci.
const SERVER_SLACK := 1

var _sent_ms: Array[int] = []
var _received_ms := {}


func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id: int) -> void: _received_ms.erase(id))
	Net.session_ended.connect(func(_reason: String) -> void: _clear())


## Wysyla wiadomosc. Zwraca false, gdy gracz pisze za szybko. Pusty tekst nie idzie nigdzie.
func send(raw: String) -> bool:
	var text := GameState.clean_text(raw, MAX_LENGTH)
	if text.is_empty():
		return true
	if not _within_limit(_sent_ms, BURST):
		return false
	_submit.rpc_id(1, text)
	return true


## Trzyma czasy z ostatniego okna i dopisuje biezacy, o ile jest jeszcze miejsce.
static func _within_limit(times: Array[int], limit: int) -> bool:
	var now := Time.get_ticks_msec()
	var oldest := now - int(BURST_SECONDS * 1000.0)
	while not times.is_empty() and times[0] <= oldest:
		times.pop_front()
	if times.size() >= limit:
		return false
	times.append(now)
	return true


func _clear() -> void:
	_sent_ms.clear()
	_received_ms.clear()
	cleared.emit()


@rpc("any_peer", "call_local", "reliable")
func _submit(raw: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var text := GameState.clean_text(raw, MAX_LENGTH)
	if text.is_empty() or not GameState.is_player(sender):
		return
	if not _received_ms.has(sender):
		_received_ms[sender] = [] as Array[int]
	if _within_limit(_received_ms[sender], BURST + SERVER_SLACK):
		_deliver.rpc(sender, text)


@rpc("authority", "call_local", "reliable")
func _deliver(sender_id: int, text: String) -> void:
	message_received.emit(sender_id, text)
