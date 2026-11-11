class_name ForestAmbienceValley
extends Node3D
## Dzwieki doliny: jasny wiatr, ktory wieje mocniej wysoko, szelest lisci, ptaki, fale jeziora
## przy jego brzegu oraz skrzypienie drewna i stukanie w Wiosce i Gospodarstwie.

const WIND_DB := -21.0
const WIND_HIGH_BONUS_DB := 6.0
const LEAVES_DB := -25.0
const LAKE_DB := -14.0
const BIRD_DB := -17.0
const SILENT_DB := -60.0
const LAKE_RANGE := 40.0
const YARD_DB := -11.0
const YARD_RANGE := 36.0
const YARD_RADIUS := 20.0
const YARD_GAP := Vector2(4.0, 11.0)

var sounds: MapSounds
var _wind: AudioStreamPlayer
var _leaves: AudioStreamPlayer
var _lake: AudioStreamPlayer3D
var _bird: AudioStreamPlayer3D
var _next_bird := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	sounds = MapSounds.new()
	add_child(sounds)
	_wind = sounds.bed(AmbienceSfx.valley_wind, WIND_DB)
	_leaves = sounds.bed(MapSounds.ready_made(Sfx.leaves_loop()), LEAVES_DB)
	_lake = sounds.spot(AmbienceSfx.lake_lap, Vector3.ZERO, LAKE_DB, LAKE_RANGE, 8.0)
	for key: String in ["village", "farm"]:
		var place := ValleyTerrain.place(key)
		var at := Vector3(place.at.x, ValleyTerrain.surface(place.at.x, place.at.y) + 2.0, place.at.y)
		sounds.events([AmbienceSfx.wood_creak, AmbienceSfx.wood_knock] as Array[Callable], at, YARD_RADIUS, YARD_GAP, YARD_DB, YARD_RANGE, 0.0)
	sounds.start()
	_bird = AudioStreamPlayer3D.new()
	_bird.max_distance = 70.0
	_bird.unit_size = 14.0
	add_child(_bird)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var volume: float = Settings.value("ambience")
	var offset := linear_to_db(maxf(volume, 0.001))
	var at := camera.global_position
	var high := smoothstep(2.0, 10.0, at.y - ValleyTerrain.surface(at.x, at.z))
	sounds.set_level(_wind, WIND_DB + high * WIND_HIGH_BONUS_DB)
	_bird.volume_db = BIRD_DB + offset if volume > 0.001 else SILENT_DB
	# Fale jeziora graja z punktu brzegu najblizszego graczowi.
	var lake := ValleyTerrain.place("lake")
	var center: Vector2 = lake.at
	var toward := (Vector2(at.x, at.z) - center).limit_length(lake.radius)
	_lake.global_position = Vector3(center.x + toward.x, ValleyTerrain.WATER_LEVEL, center.y + toward.y)
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = _rng.randf_range(2.5, 8.0)
		var angle := _rng.randf() * TAU
		_bird.stream = Sfx.bird(_rng.randi() % Sfx.BIRD_VARIANTS)
		_bird.global_position = at + Vector3(sin(angle) * 20.0, 9.0, cos(angle) * 20.0)
		_bird.play()
