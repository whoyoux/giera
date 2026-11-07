class_name ForestAmbienceValley
extends Node
## Dzwieki doliny: wiatr, ktory wieje mocniej wysoko, szelest lisci, ptaki i szum jeziora z jego brzegu.

const WIND_DB := -21.0
const WIND_HIGH_BONUS_DB := 6.0
const LEAVES_DB := -25.0
const LAKE_DB := -14.0
const BIRD_DB := -17.0
const SILENT_DB := -60.0
const LAKE_RANGE := 40.0

var _wind: AudioStreamPlayer
var _leaves: AudioStreamPlayer
var _lake: AudioStreamPlayer3D
var _bird: AudioStreamPlayer3D
var _next_bird := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wind = _loop(Sfx.wind_loop())
	_leaves = _loop(Sfx.leaves_loop())
	_lake = AudioStreamPlayer3D.new()
	_lake.stream = Sfx.creek_loop()
	_lake.max_distance = LAKE_RANGE
	_lake.unit_size = 8.0
	add_child(_lake)
	_lake.play()
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
	_wind.volume_db = WIND_DB + high * WIND_HIGH_BONUS_DB + offset if volume > 0.001 else SILENT_DB
	_leaves.volume_db = LEAVES_DB + offset if volume > 0.001 else SILENT_DB
	_lake.volume_db = LAKE_DB + offset if volume > 0.001 else SILENT_DB
	_bird.volume_db = BIRD_DB + offset if volume > 0.001 else SILENT_DB
	# Szum jeziora gra z punktu brzegu najblizszego graczowi.
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


func _loop(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	return player
