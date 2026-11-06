extends Node
## Test strefy bez sieci. Uzycie: godot --headless --path . -- --tool=res://tools/zone_test.gd

const SEEDS: Array[int] = [1, 42, 123456, 987654321]
const STEP := 0.25
const EPSILON := 0.01

var _failures := 0


func _ready() -> void:
	var total := 0.0
	for phase: Dictionary in Zone.PHASES:
		total += phase.wait + phase.shrink
	_check("caly przebieg trwa 4 min 40 s", is_equal_approx(total, 280.0))
	for seed_value in SEEDS:
		_check_seed(seed_value, total)
	var state := Zone.new(1).state_at(1.0)
	_check("na poczatku strefa czeka", not state.shrinking and is_equal_approx(state.seconds_left, 59.0) and state.damage == 2)
	_check("cel to pierwsze nastepne kolo", is_equal_approx(state.target_radius, 26.0))
	state = Zone.new(1).state_at(80.0)
	_check("potem sie zaciesnia", state.shrinking and is_equal_approx(state.seconds_left, 20.0))
	state = Zone.new(1).state_at(total + 100.0)
	_check("na koncu nie ma bezpiecznego miejsca", state.radius == 0.0 and state.damage == 12)
	_check("poza strefa", Zone.is_outside({ "center": Vector2.ZERO, "radius": 5.0 }, Vector3(6.0, 0.0, 0.0)))
	_check("w strefie", not Zone.is_outside({ "center": Vector2.ZERO, "radius": 5.0 }, Vector3(3.0, 100.0, 3.0)))
	print("[test] strefa: %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


## Kazda chwila musi zawierac sie w poprzedniej, wiec strefa nigdy nie wypycha gracza skokiem.
func _check_seed(seed_value: int, total: float) -> void:
	var zone := Zone.new(seed_value)
	var other := Zone.new(seed_value)
	var previous := zone.state_at(0.0)
	var contained := true
	var same := true
	var seconds := STEP
	while seconds <= total:
		var state := zone.state_at(seconds)
		var drift: float = (state.center as Vector2).distance_to(previous.center)
		contained = contained and drift + state.radius <= previous.radius + EPSILON
		same = same and other.state_at(seconds).radius == state.radius and other.state_at(seconds).center == state.center
		previous = state
		seconds += STEP
	_check("ziarno %d: kolejne kola leza w poprzednich" % seed_value, contained)
	_check("ziarno %d: to samo ziarno daje ten sam przebieg" % seed_value, same)


func _check(label: String, passed: bool) -> void:
	print("[test] %s %s" % ["ok" if passed else "BLAD", label])
	if not passed:
		_failures += 1
