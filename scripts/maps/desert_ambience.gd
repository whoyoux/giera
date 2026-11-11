class_name DesertAmbience
extends Node3D
## Pustynia zyje: falujacy wiatr, piasek niesiony przy ziemi wokol gracza i krzaki-kulki toczace sie
## z wiatrem. Kazde miejsce brzmi inaczej: woda i palmy w Oazie, plotno i szyld na Targu, blacha
## i wieza na Stacji, wycie wiatru i liny mostu w Kanionie, syk piasku i cykady na Wydmach.
## Wszystko jest tylko u klienta, bez kolizji, i nie idzie przez siec.

const WIND_DB := -20.0
## Kierunek wiatru na plaszczyznie: wieje od zachodu na wschod, troche na poludnie.
const WIND := Vector3(1.0, 0.0, 0.35)
const TUMBLEWEEDS := 4
const TUMBLE_SPEED := 4.5
const TUMBLE_RANGE := 45.0
## Miejsca dzwiekow, zgodne z DesertBuilder i lista miejsc w DesertMapInfo.
const MARKET := Vector3(0.0, 3.0, 0.0)
const WAGONS := Vector3(-20.0, 2.0, -46.0)
const WATER_TOWER := Vector3(30.0, 8.0, -58.0)
const CANYON := Vector3(-42.0, 4.0, 0.0)
const DUNES := Vector3(24.0, 0.5, 30.0)
const CICADAS := Vector3(40.0, 1.0, 44.0)
## Pociag gwizdze daleko za stacja, poza mapa.
const TRAIN := Vector3(0.0, 5.0, -170.0)

var sounds: MapSounds
var _sand: GPUParticles3D
var _weeds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_sand()
	for i in TUMBLEWEEDS:
		_weeds.append(_build_tumbleweed())
	_build_sounds()


func _build_sounds() -> void:
	sounds = MapSounds.new()
	add_child(sounds)
	var oasis := Vector3(DesertBuilder.POND_CENTER.x, 0.3, DesertBuilder.POND_CENTER.y)
	sounds.bed(AmbienceSfx.desert_wind, WIND_DB)
	sounds.spot(AmbienceSfx.oasis_water, oasis, -11.0, 28.0)
	sounds.spot(AmbienceSfx.palm_rustle, oasis + Vector3.UP * 4.0, -15.0, 32.0)
	sounds.spot(AmbienceSfx.canyon_howl, CANYON, -10.0, 46.0, 10.0)
	sounds.spot(AmbienceSfx.sand_hiss, DUNES, -17.0, 30.0)
	sounds.spot(AmbienceSfx.cicadas, CICADAS, -16.0, 40.0, 8.0)
	for weed in _weeds:
		sounds.follow(AmbienceSfx.tumbleweed_rustle, weed, -12.0, 16.0)
	sounds.events([AmbienceSfx.canvas_flap, AmbienceSfx.canvas_flap, AmbienceSfx.sign_creak] as Array[Callable], MARKET, 12.0, Vector2(3.0, 8.0), -9.0, 30.0)
	sounds.events([AmbienceSfx.tin_clank] as Array[Callable], WAGONS, 14.0, Vector2(5.0, 13.0), -10.0, 32.0)
	sounds.events([AmbienceSfx.tower_creak] as Array[Callable], WATER_TOWER, 2.0, Vector2(7.0, 16.0), -8.0, 40.0, 0.0)
	sounds.events([AmbienceSfx.rope_creak] as Array[Callable], CANYON, 4.0, Vector2(4.0, 10.0), -10.0, 28.0, 1.0)
	sounds.events([AmbienceSfx.hawk_cry] as Array[Callable], Vector3.INF, 45.0, Vector2(25.0, 60.0), -12.0, 120.0, 30.0)
	sounds.events([AmbienceSfx.train_whistle] as Array[Callable], TRAIN, 10.0, Vector2(70.0, 160.0), -4.0, 420.0)
	sounds.start()


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
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
