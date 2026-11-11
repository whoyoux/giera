class_name MapSounds
extends Node3D
## Dzwieki otoczenia jednej mapy: tlo slyszalne wszedzie, petle przypiete do miejsc i pojedyncze
## odglosy, ktore co jakis czas odzywaja sie w okolicy miejsca albo gracza.
## Dzwieki licza sie w watku, zeby wejscie na mape nie przycinalo, i zaczynaja grac, gdy sa gotowe.
## Glosnosc idzie za suwakiem dzwiekow otoczenia.

const SILENT_DB := -60.0
## Tak szybko tlo dochodzi do swojej glosnosci po starcie i po zmianie suwaka.
const FADE_DB_PER_SECOND := 30.0
## Odglos przypiety do miejsca nie gra, gdy gracz jest dalej niz jego zasieg razy tyle.
const EVENT_HEARING := 1.2

## Wpisy: { player, db, maker } dla petli i { players, db, makers, streams, center, radius, gap, next,
## height, range } dla pojedynczych odglosow.
var _loops: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _task := -1
var _pending: Array[Callable] = []


func _ready() -> void:
	_rng.randomize()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)


## Petla slyszalna wszedzie. "maker" to funkcja z AmbienceSfx albo Sfx zwracajaca dzwiek.
func bed(maker: Callable, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = SILENT_DB
	add_child(player)
	_loops.append({ "player": player, "db": db, "maker": maker })
	return player


## Petla przypieta do miejsca, slyszalna do "reach" metrow.
func spot(maker: Callable, at: Vector3, db: float, reach: float, unit := 6.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.max_distance = reach
	player.unit_size = unit
	player.volume_db = SILENT_DB
	add_child(player)
	player.global_position = at
	_loops.append({ "player": player, "db": db, "maker": maker })
	return player


## Petla przypieta do ruchomego wezla, np. toczacego sie krzaka.
func follow(maker: Callable, node: Node3D, db: float, reach: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.max_distance = reach
	player.unit_size = reach * 0.25
	player.volume_db = SILENT_DB
	node.add_child(player)
	_loops.append({ "player": player, "db": db, "maker": maker })
	return player


## Zmienia docelowa glosnosc petli, np. gdy wiatr ma wiac mocniej wysoko nad ziemia.
func set_level(player: Node, db: float) -> void:
	for entry in _loops:
		if entry.player == player:
			entry.db = db
			return


## Gotowy dzwiek jako "maker". Dzwieki z Sfx powstaja w glownym watku, bo maja wspolny schowek.
static func ready_made(stream: AudioStream) -> Callable:
	return func() -> AudioStream: return stream


## Pojedyncze odglosy co "gap" sekund (od, do) w promieniu "radius" od "center".
## Z center rownym Vector3.INF odzywaja sie dookola gracza, w odleglosci "radius".
func events(makers: Array[Callable], center: Vector3, radius: float, gap: Vector2, db: float, reach: float, height := 2.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.max_distance = reach
	player.unit_size = reach * 0.25
	add_child(player)
	_events.append({
		"player": player, "db": db, "makers": makers, "streams": [], "center": center, "radius": radius,
		"gap": gap, "next": _rng.randf_range(gap.x, gap.y) * 0.5, "height": height, "reach": reach,
	})


## Wolane raz po dodaniu wszystkich dzwiekow.
func start() -> void:
	_pending.clear()
	for entry in _loops:
		_pending.append(entry.maker)
	for entry in _events:
		for maker: Callable in entry.makers:
			_pending.append(maker)
	_task = WorkerThreadPool.add_task(_make_all)


func _make_all() -> void:
	var made: Array[AudioStream] = []
	for maker in _pending:
		made.append(maker.call())
	_assign.call_deferred(made)


func _assign(made: Array[AudioStream]) -> void:
	var index := 0
	for entry in _loops:
		entry.player.stream = made[index]
		entry.player.play()
		index += 1
	for entry in _events:
		for maker in entry.makers:
			entry.streams.append(made[index])
			index += 1


func _process(delta: float) -> void:
	var volume: float = Settings.value("ambience")
	var audible := volume > 0.001
	var offset := linear_to_db(maxf(volume, 0.001))
	for entry in _loops:
		var target: float = float(entry.db) + offset if audible else SILENT_DB
		entry.player.volume_db = move_toward(entry.player.volume_db, target, FADE_DB_PER_SECOND * delta) if audible else SILENT_DB
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var listener := camera.global_position
	for entry in _events:
		entry.next -= delta
		if entry.next > 0.0 or entry.streams.is_empty():
			continue
		var gap: Vector2 = entry.gap
		entry.next = _rng.randf_range(gap.x, gap.y)
		var center: Vector3 = entry.center
		var around_listener := center == Vector3.INF
		if not audible or (not around_listener and listener.distance_to(center) > float(entry.reach) * EVENT_HEARING + float(entry.radius)):
			continue
		var angle := _rng.randf() * TAU
		var distance: float = float(entry.radius) if around_listener else _rng.randf() * float(entry.radius)
		var base := listener if around_listener else center
		var player: AudioStreamPlayer3D = entry.player
		player.global_position = base + Vector3(sin(angle) * distance, float(entry.height), cos(angle) * distance)
		player.stream = entry.streams[_rng.randi() % entry.streams.size()]
		player.pitch_scale = _rng.randf_range(0.9, 1.1)
		player.volume_db = float(entry.db) + offset
		player.play()
