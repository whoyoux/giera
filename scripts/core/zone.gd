class_name Zone
extends RefCounted
## Zacieśniajaca sie strefa. Przebieg wynika tylko z ziarna, wiec serwer wysyla je raz, a kazdy
## liczy to samo. Obrazenia zadaje wylacznie serwer. Kazde kolejne kolo lezy w poprzednim.

const PHASES: Array[Dictionary] = [
	{ "wait": 60.0, "shrink": 40.0, "radius": 34.0, "damage": 2 },
	{ "wait": 45.0, "shrink": 30.0, "radius": 20.0, "damage": 4 },
	{ "wait": 35.0, "shrink": 25.0, "radius": 9.0, "damage": 7 },
	{ "wait": 20.0, "shrink": 25.0, "radius": 0.0, "damage": 12 },
]

## Kola przed i po kazdej fazie: { center: Vector2, radius: float }.
var _circles: Array[Dictionary] = []
var _phases: Array[Dictionary] = []


func _init(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := Maps.info()
	_phases = map.zone_phases
	var center := map.zone_center
	var radius := map.zone_radius
	_circles.append({ "center": center, "radius": radius })
	for phase: Dictionary in _phases:
		var next_radius: float = phase.radius
		center += Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, radius - next_radius)
		radius = next_radius
		_circles.append({ "center": center, "radius": radius })


## Stan w danej chwili meczu: { center, radius, target_center, target_radius, damage, shrinking, seconds_left }.
## "seconds_left" to czas do konca oczekiwania albo zawezania, a po wszystkim zero.
func state_at(seconds: float) -> Dictionary:
	var phase_start := 0.0
	for index in _phases.size():
		var phase: Dictionary = _phases[index]
		var wait_end: float = phase_start + phase.wait
		var shrink_end: float = wait_end + phase.shrink
		if seconds < shrink_end:
			var progress := clampf((seconds - wait_end) / phase.shrink, 0.0, 1.0)
			var shrinking := seconds >= wait_end
			return {
				"center": (_circles[index].center as Vector2).lerp(_circles[index + 1].center, progress),
				"radius": lerpf(_circles[index].radius, _circles[index + 1].radius, progress),
				"target_center": _circles[index + 1].center,
				"target_radius": _circles[index + 1].radius,
				"damage": phase.damage,
				"shrinking": shrinking,
				"seconds_left": shrink_end - seconds if shrinking else wait_end - seconds,
			}
		phase_start = shrink_end
	var last: Dictionary = _circles[-1]
	return { "center": last.center, "radius": last.radius, "target_center": last.center, "target_radius": last.radius, "damage": _phases[-1].damage, "shrinking": false, "seconds_left": 0.0 }


## Czy miejsce lezy poza strefa z podanego stanu.
static func is_outside(state: Dictionary, at: Vector3) -> bool:
	return Vector2(at.x, at.z).distance_to(state.center) > state.radius
