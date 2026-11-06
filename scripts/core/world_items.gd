extends Node
## Przedmioty lezace na ziemi. O wszystkim decyduje serwer: klient prosi o podniesienie
## albo wyrzucenie, a stan dostaje przez niezawodne RPC. Wyglad jest w PickupField.

signal item_added(entry: Dictionary)
signal item_removed(id: int, picker_id: int)
signal items_cleared

## Z takiej odleglosci gracz moze podniesc przedmiot.
const PICKUP_RANGE := 2.6
## Serwer widzi klienta z opoznieniem, wiec jest troche lagodniejszy.
const SERVER_RANGE_MARGIN := 1.5
## Blizej mozna podniesc przedmiot bez patrzenia wprost na niego.
const NEAR_RANGE := 1.2
const NEAR_MIN_DOT := -0.2
const FAR_MIN_DOT := 0.6
const LIFETIME_SECONDS := 60.0
## Starsze przedmioty ustepuja nowym, zeby mapa i siec sie nie zapchaly.
const MAX_ITEMS := 48
const THROW_DISTANCE := 1.6
const THROW_SCATTER := 0.25
const WALL_MARGIN := 0.35
const SCATTER_RADIUS := 1.2
const FLOOR_RAY_LENGTH := 40.0
const TARGET_HEIGHT := 0.35
## Tak dlugo po prosbie przedmiot nie jest celem, bo odpowiedz serwera jest w drodze.
const PENDING_MSEC := 700
const EXPIRY_CHECK_SECONDS := 1.0

## id -> { id, stack, position, from, expires_tick }
var items := {}
## Przedmiot, na ktory patrzy lokalny gracz. 0 oznacza brak.
var focused_id := 0

var _next_id := 1
var _pending := {}
var _expiry_timer := 0.0


func _ready() -> void:
	GameState.player_added.connect(_on_player_added)
	Net.session_started.connect(clear)
	Net.session_ended.connect(func(_reason: String) -> void: clear())


func _process(delta: float) -> void:
	_expiry_timer += delta
	if _expiry_timer < EXPIRY_CHECK_SECONDS:
		return
	_expiry_timer = 0.0
	if items.is_empty() or not multiplayer.is_server():
		return
	for id: int in items.keys():
		if NetworkTime.tick >= items[id].expires_tick:
			_remove_item.rpc(id, 0)


func clear() -> void:
	items.clear()
	_pending.clear()
	focused_id = 0
	items_cleared.emit()


## Najlepszy przedmiot do podniesienia z tego miejsca albo 0.
func find_target(world: World3D, feet: Vector3, eye: Vector3, look: Vector3) -> int:
	var best := 0
	var best_score := -INF
	var now := Time.get_ticks_msec()
	for id: int in items:
		if _pending.get(id, 0) > now:
			continue
		var spot: Vector3 = items[id].position
		var distance := feet.distance_to(spot)
		if distance > PICKUP_RANGE:
			continue
		var aim := spot + Vector3.UP * TARGET_HEIGHT
		var dot := look.dot(eye.direction_to(aim))
		if dot < (NEAR_MIN_DOT if distance < NEAR_RANGE else FAR_MIN_DOT):
			continue
		var score := dot - distance * 0.1
		if score <= best_score or not _is_visible(world, eye, aim):
			continue
		best = id
		best_score = score
	return best


func request_pickup(id: int) -> void:
	_pending[id] = Time.get_ticks_msec() + PENDING_MSEC
	_server_pickup.rpc_id(1, id)


func request_drop(slot: int, uid: int) -> void:
	_server_drop.rpc_id(1, slot, uid)


# --- Serwer -----------------------------------------------------------------

## Rzuca przedmiot przed gracza.
func server_throw(stack: Dictionary, player: Player) -> void:
	var from := player.eye_position() + Vector3.DOWN * 0.4
	var forward := Hitscan.direction(player.yaw, 0.0)
	var side := forward.cross(Vector3.UP) * randf_range(-THROW_SCATTER, THROW_SCATTER)
	_server_spawn(stack, from, _landing(player.get_world_3d(), from, from + forward * THROW_DISTANCE + side, player.position))


## Rozrzuca przedmioty wokol miejsca smierci.
func server_scatter(stacks: Array, center: Vector3, world: World3D) -> void:
	var from := center + Vector3.UP
	var angle := randf() * TAU
	for stack: Dictionary in stacks:
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * SCATTER_RADIUS
		_server_spawn(stack, from, _landing(world, from, from + offset, center))
		angle += TAU / stacks.size()


## Wyrzuca przedmiot z dowolnego miejsca, np. ze skrzynki.
func server_launch(stack: Dictionary, from: Vector3, toward: Vector3, fallback: Vector3, world: World3D) -> void:
	_server_spawn(stack, from, _landing(world, from, toward, fallback))


func _server_spawn(stack: Dictionary, from: Vector3, landing: Vector3) -> void:
	if items.size() >= MAX_ITEMS:
		_remove_item.rpc(items.keys().min(), 0)
	var entry := {
		"id": _next_id,
		"stack": stack,
		"position": landing,
		"from": from,
		"expires_tick": Match.respawn_tick_after_death(NetworkTime.tick, LIFETIME_SECONDS),
	}
	_next_id += 1
	_add_item.rpc(entry)


## Miejsce upadku: przed sciana i na podlodze. Bez podlogi przedmiot zostaje przy graczu.
func _landing(world: World3D, from: Vector3, toward: Vector3, fallback: Vector3) -> Vector3:
	var space := world.direct_space_state
	var target := toward
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, toward, Hitscan.WORLD_MASK))
	if not wall.is_empty():
		target = wall.position + from.direction_to(toward) * -WALL_MARGIN
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, target + Vector3.DOWN * FLOOR_RAY_LENGTH, Hitscan.WORLD_MASK))
	return floor_hit.position if not floor_hit.is_empty() else fallback


func _is_visible(world: World3D, eye: Vector3, spot: Vector3) -> bool:
	return world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, spot, Hitscan.WORLD_MASK)).is_empty()


func _on_player_added(id: int) -> void:
	if id != 1 and multiplayer.is_server() and not items.is_empty():
		_sync_items.rpc_id(id, items)


# --- RPC --------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func _server_pickup(id: int) -> void:
	if not multiplayer.is_server() or not items.has(id):
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := GameState.player_node(sender)
	if player == null or not player.is_alive():
		return
	if player.position.distance_to(items[id].position) > PICKUP_RANGE + SERVER_RANGE_MARGIN:
		return
	var stack: Dictionary = items[id].stack
	# Najpierw znika z ziemi, zeby zaden klient nie zobaczyl tego egzemplarza w dwoch miejscach.
	_remove_item.rpc(id, sender)
	var replaced := GameState.server_store_stack(sender, stack, player.equipment.active_slot)
	if not replaced.is_empty():
		server_throw(replaced, player)


@rpc("any_peer", "call_local", "reliable")
func _server_drop(slot: int, uid: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := GameState.player_node(sender)
	if player == null or not player.is_alive():
		return
	var stack := GameState.server_take_stack(sender, slot, uid)
	if not stack.is_empty():
		server_throw(stack, player)


@rpc("authority", "call_local", "reliable")
func _add_item(entry: Dictionary) -> void:
	_store(entry)


@rpc("authority", "call_local", "reliable")
func _remove_item(id: int, picker_id: int) -> void:
	_pending.erase(id)
	if items.erase(id):
		item_removed.emit(id, picker_id)


## Dolaczajacy gracz dostaje to, co juz lezy. Przedmioty nie sa wtedy rzucane.
@rpc("authority", "call_remote", "reliable")
func _sync_items(snapshot: Dictionary) -> void:
	for id: int in snapshot:
		var entry: Dictionary = snapshot[id]
		entry.from = entry.position
		_store(entry)


func _store(entry: Dictionary) -> void:
	if items.has(entry.id):
		return
	items[entry.id] = entry
	item_added.emit(entry)
