class_name CameraShake
extends RefCounted
## Wstrzasy kamery. Kazde zdarzenie dodaje "uderzenie", ktore szybko wygasa, a sila rosnie
## z jego kwadratem: drobne akcje ledwo drgaja, a mocne naprawde trzesa. Kierunek strzalu
## liczy sie z wejscia gracza, wiec wstrzasy nie wplywaja na celnosc.

const DECAY := 1.9
const MAX_ROTATION := Vector3(0.035, 0.035, 0.06)
const SPEED := 26.0

var trauma := 0.0

var _time := randf() * 100.0


func add(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Zwraca obrot kamery w tej klatce.
func update(delta: float) -> Vector3:
	_time += delta * SPEED
	trauma = move_toward(trauma, 0.0, delta * DECAY)
	var strength := trauma * trauma
	return Vector3(
		sin(_time) * cos(_time * 0.37) * MAX_ROTATION.x,
		sin(_time * 0.83 + 1.7) * cos(_time * 0.29) * MAX_ROTATION.y,
		sin(_time * 0.61 + 3.1) * cos(_time * 0.47) * MAX_ROTATION.z) * strength
