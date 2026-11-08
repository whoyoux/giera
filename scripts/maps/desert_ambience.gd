class_name DesertAmbience
extends Node3D
## Pustynia zyje: staly wiatr z porywami, piasek niesiony przy ziemi wokol gracza i krzaki-kulki
## toczace sie z wiatrem. Wszystko jest tylko u klienta, bez kolizji, i nie idzie przez siec.

const WIND_DB := -18.0
const GUST_DB := -14.0
const SILENT_DB := -60.0
## Kierunek wiatru na plaszczyznie: wieje od zachodu na wschod, troche na poludnie.
const WIND := Vector3(1.0, 0.0, 0.35)
const TUMBLEWEEDS := 4
const TUMBLE_SPEED := 4.5
const TUMBLE_RANGE := 45.0

var _wind: AudioStreamPlayer
var _gust: AudioStreamPlayer
var _next_gust := 4.0
var _sand: GPUParticles3D
var _weeds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.wind_loop()
	_wind.volume_db = SILENT_DB
	add_child(_wind)
	_wind.play()
	_gust = AudioStreamPlayer.new()
	_gust.volume_db = SILENT_DB
	add_child(_gust)
	_build_sand()
	for i in TUMBLEWEEDS:
		_weeds.append(_build_tumbleweed())


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var volume: float = Settings.value("ambience")
	var offset := linear_to_db(maxf(volume, 0.001))
	_wind.volume_db = WIND_DB + offset if volume > 0.001 else SILENT_DB
	_next_gust -= delta
	if _next_gust <= 0.0:
		_next_gust = _rng.randf_range(6.0, 14.0)
		_gust.stream = Sfx.desert_gust()
		_gust.pitch_scale = _rng.randf_range(0.85, 1.15)
		_gust.volume_db = GUST_DB + offset if volume > 0.001 else SILENT_DB
		_gust.play()
	var at := camera.global_position
	_sand.global_position = Vector3(at.x, 0.0, at.z) - WIND.normalized() * 8.0
	for weed in _weeds:
		_roll(weed, at, delta)


## Smugi piasku tuz nad ziemia, w prostopadloscianie wokol kamery. Wieja z wiatrem.
func _build_sand() -> void:
	_sand = GPUParticles3D.new()
	_sand.amount = 160
	_sand.lifetime = 2.6
	_sand.preprocess = 2.6
	_sand.visibility_aabb = AABB(Vector3(-30.0, -1.0, -30.0), Vector3(60.0, 6.0, 60.0))
	_sand.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(22.0, 0.6, 22.0)
	process.direction = WIND.normalized() + Vector3.UP * 0.05
	process.spread = 8.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 9.0
	process.gravity = Vector3(0.0, -0.4, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	_sand.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.9, 0.04)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.9, 0.7, 0.55)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	streak.material = material
	_sand.draw_pass_1 = streak
	_sand.position.y = 0.4
	add_child(_sand)


## Krzak-kulka z kilku skrzyzowanych galazek. Toczy sie z wiatrem i podskakuje na nierownosciach.
func _build_tumbleweed() -> Node3D:
	var weed := Node3D.new()
	add_child(weed)
	var color := Color("b88a52")
	for i in 5:
		var twig := LowPoly.part(weed, LowPoly.box(Vector3(0.9, 0.05, 0.05), 0.01), color if i % 2 == 0 else color.darkened(0.2))
		twig.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		twig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core := LowPoly.part(weed, LowPoly.ball(0.32, 6, 4), color.darkened(0.1))
	core.transparency = 0.35
	weed.set_meta(&"speed", _rng.randf_range(0.7, 1.3))
	weed.set_meta(&"phase", _rng.randf() * TAU)
	# Daleko poza mapa, wiec pierwsza klatka od razu ustawi ja pod wiatrem.
	weed.position = Vector3(10000.0, 0.0, 0.0)
	return weed


## Kulka, ktora odjechala za daleko, wraca po stronie, z ktorej wieje.
func _roll(weed: Node3D, center: Vector3, delta: float) -> void:
	var flat := Vector3(weed.position.x - center.x, 0.0, weed.position.z - center.z)
	if flat.length() > TUMBLE_RANGE:
		var side := WIND.normalized().cross(Vector3.UP)
		var start := center - WIND.normalized() * TUMBLE_RANGE * _rng.randf_range(0.5, 0.95) + side * _rng.randf_range(-25.0, 25.0)
		weed.position = Vector3(clampf(start.x, -60.0, 60.0), 0.0, clampf(start.z, -60.0, 60.0))
	var speed: float = TUMBLE_SPEED * float(weed.get_meta(&"speed"))
	var phase: float = weed.get_meta(&"phase")
	weed.set_meta(&"phase", phase + delta * speed * 1.4)
	weed.position += WIND.normalized() * speed * delta
	weed.position.y = 0.45 + absf(sin(phase)) * 0.5
	weed.rotate(WIND.normalized().cross(Vector3.DOWN).normalized(), speed * delta / 0.45)
