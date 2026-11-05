extends Node
## Skrzynki na mapie. Otwieranie trwa chwile: klient trzyma klawisz, a serwer sam odlicza czas,
## losuje lup i rozsyla wynik. Wyglad jest w ChestField i ChestView.

signal chest_opened(id: int, opener_id: int, tier: int)
signal chest_closed(id: int)
signal chest_busy_changed(id: int, busy: bool)
signal chests_reset

const LOOT_TABLE := preload("res://data/loot/chest.tres")
const OPEN_SECONDS := 1.0
const RESPAWN_SECONDS := 60.0
const OPEN_RANGE := 2.8
const SERVER_RANGE_MARGIN := 1.5
const FAR_MIN_DOT := 0.6
## Patrzac na otwierana skrzynke, mozna troche zjechac celownikiem.
const OPENING_MIN_DOT := 0.3
const AIM_HEIGHT := 0.5
const LOOT_START_HEIGHT := 1.1
const LOOT_THROW_DISTANCE := 1.7
## Tyle po zakonczeniu paska czekamy na serwer, zanim uznamy, ze odmowil.
const ANSWER_TIMEOUT := 1.5
const RESPAWN_CHECK_SECONDS := 1.0

## id -> { id, position, rotation_y, open, busy, reopen_tick, body }
var chests := {}
## Skrzynka, na ktora patrzy lokalny gracz. 0 oznacza brak.
var focused_id := 0

var _local_id := 0
var _local_time := 0.0
var _armed := false
var _openings := {}
var _rng := RandomNumberGenerator.new()
var _respawn_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	GameState.player_added.connect(_on_player_added)
	Net.session_started.connect(reset)
	Net.session_ended.connect(func(_reason: String) -> void: reset())


## Numery wynikaja z kolejnosci miejsc na mapie, wiec sa takie same u wszystkich.
func register(id: int, at: Vector3, rotation_y: float, body: RID) -> void:
	chests[id] = { "id": id, "position": at, "rotation_y": rotation_y, "open": false, "busy": false, "reopen_tick": 0, "body": body }


func reset() -> void:
	_openings.clear()
	_cancel_local(false)
	focused_id = 0
	for id: int in chests:
		chests[id].open = false
		chests[id].busy = false
	chests_reset.emit()


## Postep paska lokalnego gracza od 0 do 1.
func local_progress() -> float:
	return minf(_local_time / OPEN_SECONDS, 1.0) if _local_id != 0 else 0.0


func is_locally_opening(id: int) -> bool:
	return _local_id == id


## Gracz wcisnal klawisz. Otwieranie ruszy, gdy tylko patrzy na skrzynke.
func arm() -> void:
	_armed = true


## Wolane co klatke dla lokalnego gracza.
func update_local(player: Player, delta: float, held: bool) -> void:
	_update_focus(player)
	if not held:
		_armed = false
	if _local_id != 0:
		_update_opening(player, delta, held)
	elif held and _armed and focused_id != 0:
		_armed = false
		_local_id = focused_id
		_local_time = 0.0
		_server_start.rpc_id(1, _local_id)


func _update_focus(player: Player) -> void:
	if not player.is_alive():
		focused_id = 0
	elif _local_id != 0 and _is_in_reach(player, _local_id, OPENING_MIN_DOT):
		focused_id = _local_id
	elif WorldItems.focused_id != 0:
		focused_id = 0
	else:
		focused_id = _find_target(player)


func _update_opening(player: Player, delta: float, held: bool) -> void:
	if chests[_local_id].open:
		_cancel_local(false)
	elif not held or focused_id != _local_id or player.input.use_primary:
		_cancel_local(true)
	else:
		_local_time += delta
		if _local_time > OPEN_SECONDS + ANSWER_TIMEOUT:
			_cancel_local(true)


func _cancel_local(tell_server: bool) -> void:
	if _local_id != 0 and tell_server:
		_server_cancel.rpc_id(1)
	_local_id = 0
	_local_time = 0.0


func _find_target(player: Player) -> int:
	var best := 0
	var best_distance := INF
	for id: int in chests:
		if chests[id].open or not _is_in_reach(player, id, FAR_MIN_DOT):
			continue
		var distance: float = player.position.distance_to(chests[id].position)
		if distance < best_distance:
			best = id
			best_distance = distance
	return best


func _is_in_reach(player: Player, id: int, min_dot: float) -> bool:
	var chest: Dictionary = chests[id]
	if chest.open or player.position.distance_to(chest.position) > OPEN_RANGE:
		return false
	var eye := player.eye_position()
	var aim: Vector3 = chest.position + Vector3.UP * AIM_HEIGHT
	if Hitscan.direction(player.input.look_yaw, player.input.look_pitch).dot(eye.direction_to(aim)) < min_dot:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, aim, Hitscan.WORLD_MASK)
	query.exclude = [chest.body]
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Serwer -----------------------------------------------------------------

func _process(delta: float) -> void:
	if chests.is_empty() or not multiplayer.is_server():
		return
	for peer: int in _openings.keys():
		_advance_opening(peer)
	_respawn_timer += delta
	if _respawn_timer < RESPAWN_CHECK_SECONDS:
		return
	_respawn_timer = 0.0
	for id: int in chests:
		if chests[id].open and NetworkTime.tick >= chests[id].reopen_tick:
			_chest_closed.rpc(id)


func _advance_opening(peer: int) -> void:
	var opening: Dictionary = _openings[peer]
	var chest: Dictionary = chests[opening.chest]
	var player := GameState.player_node(peer)
	if player == null or not player.is_alive() or player.position.distance_to(chest.position) > OPEN_RANGE + SERVER_RANGE_MARGIN:
		_stop_opening(peer)
	elif NetworkTime.tick >= opening.end_tick:
		_finish_opening(chest, player)


func _stop_opening(peer: int) -> void:
	var id: int = _openings[peer].chest
	_openings.erase(peer)
	_update_busy(id)


func _update_busy(id: int) -> void:
	var busy := false
	for peer: int in _openings:
		busy = busy or _openings[peer].chest == id
	if busy != chests[id].busy:
		_chest_busy.rpc(id, busy)


func _finish_opening(chest: Dictionary, player: Player) -> void:
	for peer: int in _openings.keys():
		if _openings[peer].chest == chest.id:
			_openings.erase(peer)
	chest.reopen_tick = NetworkTime.tick + NetworkTime.seconds_to_ticks(RESPAWN_SECONDS)
	var loot: Dictionary = LOOT_TABLE.roll(_rng)
	print("[serwer] %s otworzyl skrzynke %d: %s" % [player.info.name, chest.id, Rarity.display_name(loot.tier)])
	_chest_opened.rpc(chest.id, player.peer_id, loot.tier)
	if chest.busy:
		_chest_busy.rpc(chest.id, false)
	var from: Vector3 = chest.position + Vector3.UP * LOOT_START_HEIGHT
	var to_player: Vector3 = (player.position - chest.position) * Vector3(1.0, 0.0, 1.0)
	var toward := from + to_player.normalized() * LOOT_THROW_DISTANCE
	WorldItems.server_launch(GameState.server_new_stack(loot.item, loot.tier), from, toward, player.position, player.get_world_3d())


func _on_player_added(id: int) -> void:
	if id == 1 or not multiplayer.is_server():
		return
	var open := []
	var busy := []
	for chest_id: int in chests:
		if chests[chest_id].open:
			open.append(chest_id)
		if chests[chest_id].busy:
			busy.append(chest_id)
	_sync_chests.rpc_id(id, open, busy)


# --- RPC --------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _server_start(id: int) -> void:
	if not multiplayer.is_server() or not chests.has(id) or chests[id].open:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := GameState.player_node(sender)
	if player == null or not player.is_alive():
		return
	if player.position.distance_to(chests[id].position) > OPEN_RANGE + SERVER_RANGE_MARGIN:
		return
	if _openings.has(sender):
		_stop_opening(sender)
	_openings[sender] = { "chest": id, "end_tick": NetworkTime.tick + NetworkTime.seconds_to_ticks(OPEN_SECONDS) }
	_update_busy(id)


@rpc("any_peer", "call_local", "reliable")
func _server_cancel() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and _openings.has(sender):
		_stop_opening(sender)


@rpc("authority", "call_local", "reliable")
func _chest_opened(id: int, opener_id: int, tier: int) -> void:
	chests[id].open = true
	chest_opened.emit(id, opener_id, tier)


@rpc("authority", "call_local", "reliable")
func _chest_closed(id: int) -> void:
	chests[id].open = false
	chest_closed.emit(id)


@rpc("authority", "call_local", "reliable")
func _chest_busy(id: int, busy: bool) -> void:
	chests[id].busy = busy
	chest_busy_changed.emit(id, busy)


## Dolaczajacy gracz dostaje stan skrzynek bez animacji.
@rpc("authority", "call_remote", "reliable")
func _sync_chests(open: Array, busy: Array) -> void:
	for id: int in chests:
		chests[id].open = open.has(id)
		chests[id].busy = busy.has(id)
	chests_reset.emit()
