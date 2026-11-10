class_name RemoteMotion
extends RefCounted
## Bufor ruchu innego gracza u klienta. Stany przychodza nierowno, bo gracz wysyla ruch co
## klatke, a przycinka albo Wi-Fi zatrzymuje je na chwile. Pokazujemy wiec gracza troche
## w przeszlosci i plynnie przechodzimy miedzy stanami, ktore juz dotarly.
## Stale w tickach sa dobrane do 60 tickow na sekunde.

## Zapas ponad najkrotsza droge stanu do klienta. Najnowszy stan starzeje sie, zanim dojdzie nastepny,
## wiec zapas pokrywa najwiekszy odstep miedzy stanami z okna (1 tick, po zgubionym pakiecie wiecej),
## rozrzut wieku stanow (95. centyl minus minimum) i margines na klatki, w tych granicach.
const MIN_BUFFER_TICKS := 1.5
const MAX_BUFFER_TICKS := 6.0
const JITTER_PERCENTILE := 0.95
## Zegar gracza idzie klatkami, wiec bywa o ulamek ticku przed wspolnym zegarem.
const CLOCK_MARGIN_TICKS := 1.0
## Do pomiarow: tak daleko zegar gracza musi wyprzedzic dane, zeby liczyc to jako zaciecie.
const STARVE_TICKS := 0.5
## Najwolniejszy gracz opoznia wspolny zegar najwyzej o tyle tickow ponad mediane graczy.
## Wolniejszy od zegara stoi na swoim najnowszym stanie i porusza sie skokami tylko on.
const LAG_SPREAD_TICKS := 2.0
## Z tylu ostatnich stanow, czyli okolo 2 s, liczymy najkrotsza droge.
const AGE_WINDOW := 120
## Tak szybko wspolny zegar zmienia opoznienie, w tickach na sekunde.
const LAG_ADAPT_SPEED := 4.0
## Przy wiekszej roznicy dalsze doganianie nie ma sensu i przeskakujemy od razu.
const SNAP_TICKS := 30.0
const CATCH_UP_GAIN := 0.125
const MIN_RATE := 0.8
const MAX_RATE := 1.6
## Taki ruch na tick nie jest bieganiem, tylko odrodzeniem, wiec go nie wygladzamy.
const TELEPORT_METERS_PER_TICK := 0.75

## Tick, ktory klient pokazuje na ekranie. Wspolny dla wszystkich graczy, bo strzal
## podaje serwerowi jeden tick. Ujemny, gdy nie ma kogo pokazywac.
static var shown_tick := -1.0
static var _lag := -1.0
static var _clock_frame := -1
## Do pomiarow: ile razy gracz stal na najnowszym stanie, bo zegar wyprzedzil dane.
static var starved_frames := 0

var shown_position := Vector3.ZERO
var shown_yaw := 0.0
var shown_pitch := 0.0
var shown_crouch := 0.0
var newest_tick := -1

var _samples: Array[Dictionary] = []
var _ages: Array[float] = []
var _tick := -1.0
## Odstepy w tickach miedzy kolejnymi stanami z okna AGE_WINDOW.
var _gaps: Array[int] = []
## Zapas potrzebny temu graczowi, liczony przy kazdym nowym stanie.
var _buffer := MIN_BUFFER_TICKS


## Tick z ulamkiem przekazywany serwerowi przy strzale albo -1, gdy nie ma innych graczy.
## Ulamek pozwala serwerowi ustawic cel miedzy tickami, tak jak widzial go strzelec.
static func view_tick() -> float:
	return shown_tick if shown_tick >= 0.0 else -1.0


## Przesuwa wspolny zegar. Opoznienie dobiera najwolniejszy gracz, zeby nikt nie stal bez danych,
## ale najwyzej LAG_SPREAD_TICKS ponad mediane, zeby jeden slaby lacznik nie opoznial obrazu wszystkim.
static func advance_clock(delta: float, tree: SceneTree) -> void:
	var frame := Engine.get_process_frames()
	if frame == _clock_frame:
		return
	_clock_frame = frame
	var target := target_lag(tree)
	if target < 0.0:
		shown_tick = -1.0
		_lag = -1.0
		return
	_lag = target if _lag < 0.0 or absf(target - _lag) > SNAP_TICKS else move_toward(_lag, target, delta * LAG_ADAPT_SPEED)
	shown_tick = _now() - _lag


## Docelowe opoznienie wspolnego zegara w tickach albo -1, gdy nie ma kogo pokazywac.
static func target_lag(tree: SceneTree) -> float:
	var motions: Array[RemoteMotion] = []
	for node in tree.get_nodes_in_group(&"players"):
		var motion: RemoteMotion = (node as Player).remote_motion
		if motion != null and not motion._ages.is_empty():
			motions.append(motion)
	return lag_for(motions)


static func lag_for(motions: Array[RemoteMotion]) -> float:
	if motions.is_empty():
		return -1.0
	# Kazdy gracz potrzebuje swojej najkrotszej drogi i swojego zapasu. Zegar spelnia najwieksza
	# potrzebe, ale najwyzej LAG_SPREAD_TICKS ponad mediane potrzeb.
	var needs: Array[float] = []
	for motion in motions:
		needs.append(motion._shortest_age() + motion._buffer)
	needs.sort()
	var middle := needs.size() / 2
	var median: float = needs[middle] if needs.size() % 2 == 1 else (needs[middle - 1] + needs[middle]) / 2.0
	return minf(needs[-1], median + LAG_SPREAD_TICKS)


## O tyle milisekund obraz innych graczy jest opozniony wzgledem teraz. -1, gdy nie ma kogo pokazywac.
static func view_delay_ms() -> float:
	if shown_tick < 0.0:
		return -1.0
	return (_now() - shown_tick) * NetworkTime.ticktime * 1000.0


static func _now() -> float:
	return NetworkTime.tick + NetworkTime.tick_factor


func has_samples() -> bool:
	return not _samples.is_empty()


## Pozycja z ostatniego stanu albo podana, gdy zadnego jeszcze nie ma.
func newest_position(fallback: Vector3) -> Vector3:
	return _samples[-1].position if not _samples.is_empty() else fallback


func newest_crouch() -> float:
	return _samples[-1].crouch if not _samples.is_empty() else 0.0


func add_sample(tick: int, at: Vector3, yaw: float, pitch: float, crouch := 0.0) -> void:
	if tick <= newest_tick:
		return
	if newest_tick >= 0:
		_gaps.append(tick - newest_tick)
		if _gaps.size() > AGE_WINDOW:
			_gaps.pop_front()
	newest_tick = tick
	_samples.append({"tick": tick, "position": at, "yaw": yaw, "pitch": pitch, "crouch": crouch})
	_ages.append(_now() - tick)
	if _ages.size() > AGE_WINDOW:
		_ages.pop_front()
	_buffer = needed_buffer()


## Ten gracz idzie za zegarem wlasnym tempem. Po przerwie w danych stoi na ostatnim
## stanie, a potem chwile biegnie szybciej, zamiast przeskoczyc.
func advance(delta: float, target_tick: float) -> void:
	if _samples.is_empty():
		return
	if _tick < 0.0 or absf(target_tick - _tick) > SNAP_TICKS:
		_tick = target_tick
	else:
		var rate := clampf(1.0 + (target_tick - _tick) * CATCH_UP_GAIN, MIN_RATE, MAX_RATE)
		_tick += delta * NetworkTime.tickrate * rate
	if _tick > newest_tick + STARVE_TICKS:
		starved_frames += 1
	_tick = minf(_tick, newest_tick)
	while _samples.size() > 2 and _samples[1].tick <= _tick:
		_samples.pop_front()
	_show()


func _show() -> void:
	var from: Dictionary = _samples[0]
	var to: Dictionary = _samples[mini(1, _samples.size() - 1)]
	var span: int = to.tick - from.tick
	var weight := clampf((_tick - from.tick) / span, 0.0, 1.0) if span > 0 else 1.0
	if from.position.distance_to(to.position) > TELEPORT_METERS_PER_TICK * span:
		weight = 1.0 if weight >= 1.0 else 0.0
	shown_position = from.position.lerp(to.position, weight)
	shown_yaw = lerp_angle(from.yaw, to.yaw, weight)
	shown_pitch = lerpf(from.pitch, to.pitch, weight)
	shown_crouch = lerpf(from.crouch, to.crouch, weight)


func _shortest_age() -> float:
	return _ages.min()


## Zapas potrzebny temu graczowi, w granicach MIN_BUFFER_TICKS..MAX_BUFFER_TICKS.
func needed_buffer() -> float:
	var largest_gap: int = _gaps.max() if not _gaps.is_empty() else 1
	return clampf(largest_gap + _age_spread() + CLOCK_MARGIN_TICKS, MIN_BUFFER_TICKS, MAX_BUFFER_TICKS)


## Roznica miedzy 95. centylem a minimum wieku stanow, czyli jak nierowno przychodza.
func _age_spread() -> float:
	var sorted := _ages.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * JITTER_PERCENTILE), sorted.size() - 1)] - sorted[0]
