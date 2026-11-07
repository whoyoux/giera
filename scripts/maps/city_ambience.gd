class_name CityAmbience
extends Node
## Odglosy miasteczka: staly szum ruchu w tle, a co chwile golebie, klakson albo dzwonek roweru
## gdzies dookola gracza. Glosnosc idzie za suwakiem dzwiekow otoczenia.

const HUM_DB := -22.0
const EVENT_DB := -16.0
const SILENT_DB := -60.0
const MIN_GAP := 3.0
const MAX_GAP := 9.0
const EVENT_DISTANCE := Vector2(10.0, 28.0)

var _hum: AudioStreamPlayer
var _event: AudioStreamPlayer3D
var _next := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_hum = AudioStreamPlayer.new()
	_hum.stream = Sfx.city_hum_loop()
	_hum.volume_db = SILENT_DB
	add_child(_hum)
	_hum.play()
	_event = AudioStreamPlayer3D.new()
	_event.max_distance = 60.0
	_event.unit_size = 12.0
	add_child(_event)


func _process(delta: float) -> void:
	var volume: float = Settings.value("ambience")
	var offset := linear_to_db(maxf(volume, 0.001))
	_hum.volume_db = HUM_DB + offset if volume > 0.001 else SILENT_DB
	_event.volume_db = EVENT_DB + offset if volume > 0.001 else SILENT_DB
	_next -= delta
	var camera := get_viewport().get_camera_3d()
	if _next > 0.0 or camera == null:
		return
	_next = _rng.randf_range(MIN_GAP, MAX_GAP)
	var angle := _rng.randf() * TAU
	var distance := _rng.randf_range(EVENT_DISTANCE.x, EVENT_DISTANCE.y)
	_event.global_position = camera.global_position + Vector3(sin(angle) * distance, 3.0, cos(angle) * distance)
	_event.stream = [Sfx.pigeons(), Sfx.car_horn(), Sfx.bike_bell()][_rng.randi() % 3]
	_event.pitch_scale = _rng.randf_range(0.92, 1.08)
	_event.play()
