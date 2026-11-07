extends Node
## Zrzuty zaopatrzenia w Battle Royale. Serwer na poczatku drugiej i trzeciej fazy strefy wybiera
## miejsce w nastepnym bezpiecznym kole i oglasza zrzut. Skrzynia opada na spadochronie z dymem,
## a gdy dotknie ziemi, serwer kladzie obok najlepszy lup. Wyglad jest w DropView.

signal drop_announced(id: int)
signal drop_landed(id: int)

const FALL_SECONDS := 14.0
const START_HEIGHT := 45.0
## Fazy strefy, na poczatku ktorych spada zrzut (liczone od zera).
const DROP_PHASES: Array[int] = [1, 2]
const LOOT: Array[StringName] = [&"awp", &"deagle", &"shotgun", &"medkit"]

## id -> { id, position: Vector3, land_tick, landed }
var drops := {}

var _next_id := 1
var _dropped_phases: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Match.phase_changed.connect(_on_phase_changed)
	Net.session_ended.connect(func(_reason: String) -> void: clear())


func clear() -> void:
	drops.clear()
	_dropped_phases.clear()


func _process(_delta: float) -> void:
	if not Net.in_session or not multiplayer.is_server() or not Match.is_elimination() or Match.zone == null:
		return
	var state := Match.zone_state()
	if state.is_empty():
		return
	var phase := _phase_index()
	if DROP_PHASES.has(phase) and not _dropped_phases.has(phase):
		_dropped_phases.append(phase)
		_server_drop(state)
	for id: int in drops:
		var drop: Dictionary = drops[id]
		if not drop.landed and NetworkTime.tick >= drop.land_tick:
			drop.landed = true
			_land.rpc(id)
			var stacks := []
			for item in LOOT:
				stacks.append(GameState.server_new_stack(item, Rarity.Tier.LEGENDARY))
			var world := get_viewport().get_world_3d()
			WorldItems.server_scatter(stacks, drop.position, world)
			print("[serwer] zrzut %d wyladowal" % id)


## Numer fazy strefy, ktora teraz trwa.
func _phase_index() -> int:
	var seconds := (NetworkTime.tick - Match.zone_start_tick) * NetworkTime.ticktime * Match.zone_speed
	var start := 0.0
	var phases := Maps.info().zone_phases
	for index in phases.size():
		start += phases[index].wait + phases[index].shrink
		if seconds < start:
			return index
	return phases.size()


func _server_drop(state: Dictionary) -> void:
	var center: Vector2 = state.target_center
	var radius: float = state.target_radius * 0.7
	var flat := center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, radius)
	var at := Vector3(flat.x, Maps.info().surface(flat.x, flat.y), flat.y)
	var id := _next_id
	_next_id += 1
	var land_tick := NetworkTime.tick + NetworkTime.seconds_to_ticks(FALL_SECONDS / Match.zone_speed)
	print("[serwer] zrzut %d nad %s" % [id, str(at.snapped(Vector3.ONE))])
	_announce.rpc(id, at, land_tick)


func _on_phase_changed() -> void:
	if Match.phase != Match.Phase.LIVE:
		clear()


@rpc("authority", "call_local", "reliable")
func _announce(id: int, at: Vector3, land_tick: int) -> void:
	drops[id] = { "id": id, "position": at, "land_tick": land_tick, "landed": false }
	drop_announced.emit(id)


@rpc("authority", "call_local", "reliable")
func _land(id: int) -> void:
	if drops.has(id):
		drops[id].landed = true
		drop_landed.emit(id)
