class_name ForestAmbience
extends Node3D
## Dzwieki lasu. Wiatr i liscie sa zapetlone, a ich glosnosc zmienia sie powoli i zalezy od miejsca:
## w lesie slychac wiecej lisci, a wysoko mocniej wieje. Strumien gra z punktu najblizszego gracza.

const WIND_DB := -21.0
const WIND_HIGH_BONUS_DB := 7.0
const LEAVES_DB := -24.0
const LEAVES_FOREST_BONUS_DB := 6.0
const CREEK_DB := -13.0
const BIRD_DB := -17.0
const SILENT_DB := -60.0
const GUST_SPEED := 0.31
const GUST_RANGE_DB := 4.0
const LEVEL_DB_PER_SECOND := 20.0
const HIGH_START := 2.0
const HIGH_FULL := 8.0
const BIRD_MIN_SECONDS := 2.5
const BIRD_MAX_SECONDS := 9.0
const BIRD_DISTANCE := Vector2(12.0, 30.0)
const BIRD_HEIGHT := 9.0
const CREEK_RANGE := 26.0

var sounds: MapSounds
var _wind: AudioStreamPlayer
var _leaves: AudioStreamPlayer
var _creek: AudioStreamPlayer3D
var _birds: Array[AudioStreamPlayer3D] = []
var _time := 0.0
var _next_bird := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Ciemny wiatr w koronach liczy sie w watku, a jego glosnosc prowadzi MapSounds.
	sounds = MapSounds.new()
	add_child(sounds)
	_wind = sounds.bed(AmbienceSfx.forest_wind, WIND_DB)
	sounds.start()
	_leaves = _looping_player(Sfx.leaves_loop())
	_creek = AudioStreamPlayer3D.new()
	_creek.stream = Sfx.creek_loop()
	_creek.max_distance = CREEK_RANGE
	_creek.unit_size = 5.0
	add_child(_creek)
	_creek.play()
	for i in 2:
		var bird := AudioStreamPlayer3D.new()
		bird.max_distance = 70.0
		bird.unit_size = 14.0
		add_child(bird)
		_birds.append(bird)


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := camera.global_position
	_update_levels(at)
	_creek.global_position = Vector3(at.x, ForestTerrain.WATER_LEVEL, ForestTerrain.creek_center_z(at.x))
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = _rng.randf_range(BIRD_MIN_SECONDS, BIRD_MAX_SECONDS)
		_sing(at)


func _update_levels(at: Vector3) -> void:
	var volume: float = Settings.value("ambience")
	var offset := linear_to_db(maxf(volume, 0.001))
	var gust := sin(_time * GUST_SPEED) * sin(_time * GUST_SPEED * 0.37 + 1.1) * GUST_RANGE_DB
	var height_above := at.y - ForestTerrain.surface(at.x, at.z)
	var high := smoothstep(HIGH_START, HIGH_FULL, height_above)
	var forest := smoothstep(ForestTerrain.CLEARING_INNER, ForestTerrain.CLEARING_OUTER, Vector2(at.x, at.z).length())
	sounds.set_level(_wind, WIND_DB + gust + high * WIND_HIGH_BONUS_DB)
	# Liscie szeleszcza mocniej, gdy zawieje.
	_set_level(_leaves, LEAVES_DB + gust * 1.3 + forest * LEAVES_FOREST_BONUS_DB + offset, volume)
	_creek.volume_db = CREEK_DB + offset if volume > 0.001 else SILENT_DB
	for bird in _birds:
		bird.volume_db = BIRD_DB + offset if volume > 0.001 else SILENT_DB


func _set_level(player: AudioStreamPlayer, target_db: float, volume: float) -> void:
	if volume <= 0.001:
		player.volume_db = SILENT_DB
		return
	player.volume_db = move_toward(player.volume_db, target_db, LEVEL_DB_PER_SECOND * get_process_delta_time())


## Ptak odzywa sie gdzies w koronach drzew, zawsze w innym miejscu.
func _sing(at: Vector3) -> void:
	var bird := _birds[0] if not _birds[0].playing else _birds[1]
	var angle := _rng.randf() * TAU
	var distance := _rng.randf_range(BIRD_DISTANCE.x, BIRD_DISTANCE.y)
	bird.stream = Sfx.bird(_rng.randi() % Sfx.BIRD_VARIANTS)
	bird.pitch_scale = _rng.randf_range(0.92, 1.1)
	bird.global_position = at + Vector3(sin(angle) * distance, BIRD_HEIGHT, cos(angle) * distance)
	bird.play()


func _looping_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	return player
