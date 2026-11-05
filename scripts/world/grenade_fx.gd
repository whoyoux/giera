class_name GrenadeFx
extends RefCounted
## Wybuch w stylu reszty gry: kanciaste kule ognia i dymu zamiast rozmytych plam, do tego blysk,
## fala na ziemi, odlamki i slad na trawie. Czysto wizualne, nie wplywa na rozgrywke.

const FIRE_COLORS: Array[Color] = [Color("fffde8"), Color("ffe05a"), Color("ff9a1f"), Color("f0431c"), Color("4a3a36")]
const FIRE_STOPS: Array[float] = [0.0, 0.18, 0.5, 0.82, 1.0]
const SMOKE_COLORS: Array[Color] = [Color("6b6866"), Color("8d8a88"), Color("b5b3b0"), Color("d6d4d0")]
const SMOKE_STOPS: Array[float] = [0.0, 0.25, 0.65, 1.0]
const SPARK_COLORS: Array[Color] = [Color("fff6c2"), Color("ffc02e"), Color("ff5a1a")]
const SPARK_STOPS: Array[float] = [0.0, 0.5, 1.0]
const DEBRIS_COLORS: Array[Color] = [Color("5f9438"), Color("94744a"), Color("4c7c2f"), Color("6c6c78")]
const LIFETIME_SECONDS := 3.2
const GLOW_BOOST := 2.4
const SCORCH_SECONDS := 9.0
const SCORCH_SIZE := 6.5
const FLASH_ENERGY := 22.0
const FLASH_RANGE := 18.0
const FLASH_SCALE := 3.0
const RING_RADIUS := 7.0
const RING_COLOR := Color(1.0, 0.9, 0.7, 0.75)
## Wstrzas kamery slabnie z odlegloscia i konczy sie tutaj.
const SHAKE_RANGE := 32.0
const SHAKE_MAX := 0.95

static var _scorch_texture: Texture2D


static func shake_at(distance: float) -> float:
	var nearness := clampf(1.0 - distance / SHAKE_RANGE, 0.0, 1.0)
	return SHAKE_MAX * nearness * nearness


## Sklada wezly jednego wybuchu. Tworzenie czasteczek jest wolne, wiec robi to ExplosionPool przy starcie.
static func build(root: Node3D) -> Dictionary:
	var parts := {}
	parts.particles = [
		# Kanciaste, nieprzezroczyste kule jak w kreskowce. Znikaja, malejac do zera.
		_burst(34, 0.6, 0.62, FIRE_COLORS, FIRE_STOPS, Vector2(3.0, 10.0), 1.0, 7.0, 180.0, 1.5, 0.92, true, true),
		_burst(20, 1.9, 0.5, SMOKE_COLORS, SMOKE_STOPS, Vector2(1.2, 4.2), 2.6, 2.0, 70.0, 1.8, 0.55, true, false),
		_burst(54, 0.8, 0.045, SPARK_COLORS, SPARK_STOPS, Vector2(8.0, 20.0), -15.0, 0.8, 100.0, 1.0, 1.0, false, true),
	]
	for color in DEBRIS_COLORS:
		parts.particles.append(_debris(color))
	for particles: CPUParticles3D in parts.particles:
		root.add_child(particles)
	parts.light = OmniLight3D.new()
	parts.light.light_color = Color("ffc266")
	parts.light.light_energy = 0.0
	parts.light.omni_range = FLASH_RANGE
	parts.light.position.y = 0.8
	root.add_child(parts.light)
	parts.ball = MeshInstance3D.new()
	parts.ball.mesh = LowPoly.ball(1.0, 8, 4)
	parts.ball.material_override = LowPoly.glow(Color(2.6, 2.2, 1.3))
	parts.ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.ball.position.y = 0.5
	parts.ball.scale = Vector3.ZERO
	root.add_child(parts.ball)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 26
	torus.ring_segments = 4
	parts.ring_material = StandardMaterial3D.new()
	parts.ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	parts.ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	parts.ring_material.albedo_color = RING_COLOR
	parts.ring = MeshInstance3D.new()
	parts.ring.mesh = torus
	parts.ring.material_override = parts.ring_material
	parts.ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.ring.position.y = 0.15
	parts.ring.scale = Vector3.ZERO
	root.add_child(parts.ring)
	parts.boom = AudioStreamPlayer3D.new()
	parts.boom.stream = Sfx.explosion()
	parts.boom.max_distance = 130.0
	parts.boom.unit_size = 16.0
	root.add_child(parts.boom)
	return parts


## Uruchamia zlozony wczesniej wybuch.
static func fire(parts: Dictionary) -> void:
	for particles: CPUParticles3D in parts.particles:
		particles.restart()
	parts.boom.play()
	parts.light.light_energy = FLASH_ENERGY
	parts.light.create_tween().tween_property(parts.light, "light_energy", 0.0, 0.34).set_ease(Tween.EASE_OUT)
	var ball: MeshInstance3D = parts.ball
	ball.scale = Vector3.ONE * 0.4
	var flash := ball.create_tween()
	flash.tween_property(ball, "scale", Vector3.ONE * FLASH_SCALE, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(ball, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Fala rozchodzaca sie po ziemi pokazuje zasieg wybuchu.
	var ring: MeshInstance3D = parts.ring
	ring.scale = Vector3(0.3, 0.2, 0.3)
	parts.ring_material.albedo_color = RING_COLOR
	var wave := ring.create_tween().set_parallel()
	wave.tween_property(ring, "scale", Vector3(RING_RADIUS, 0.2, RING_RADIUS), 0.34).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	wave.tween_property(parts.ring_material, "albedo_color:a", 0.0, 0.34)


## Smuzka za lecacym granatem.
static func trail() -> CPUParticles3D:
	var particles := _particles(16, 0.42, LowPoly.ball(0.07, 5, 2))
	particles.color_ramp = _ramp([Color(1.0, 0.75, 0.4, 0.8), Color(0.6, 0.6, 0.6, 0.45), Color(0.7, 0.7, 0.7, 0.0)], [0.0, 0.3, 1.0])
	particles.local_coords = false
	particles.spread = 180.0
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.3
	particles.gravity = Vector3(0.0, 0.5, 0.0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.2
	return particles


## Ciemny slad na ziemi zostaje jeszcze chwile po wybuchu.
static func add_scorch(parent: Node, at: Vector3) -> void:
	var decal := Decal.new()
	decal.size = Vector3(SCORCH_SIZE, 3.0, SCORCH_SIZE)
	decal.texture_albedo = _scorch()
	decal.cull_mask = 1
	parent.add_child(decal)
	decal.global_position = at + Vector3.UP * 0.5
	decal.rotation.y = randf() * TAU
	var tween := decal.create_tween()
	tween.tween_interval(SCORCH_SECONDS * 0.7)
	tween.tween_property(decal, "albedo_mix", 0.0, SCORCH_SECONDS * 0.3)
	tween.tween_callback(decal.queue_free)


static func _scorch() -> Texture2D:
	if _scorch_texture != null:
		return _scorch_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.08, 0.07, 0.06, 0.9))
	gradient.set_color(1, Color(0.1, 0.09, 0.07, 0.0))
	gradient.add_point(0.55, Color(0.09, 0.08, 0.06, 0.7))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	_scorch_texture = texture
	return texture


static func _burst(amount: int, lifetime: float, radius: float, colors: Array[Color], stops: Array[float], speed: Vector2, gravity_y: float, damping: float, spread: float, grow: float, explosiveness: float, round_mesh: bool, glowing: bool) -> CPUParticles3D:
	var mesh: Mesh = LowPoly.ball(radius, 6, 3) if round_mesh else LowPoly.box(Vector3.ONE * radius * 2.0, 0.0)
	var particles := _particles(amount, lifetime, mesh)
	particles.material_override = _vertex_material(glowing, false)
	particles.color_ramp = _ramp(colors, stops)
	particles.one_shot = true
	particles.explosiveness = explosiveness
	particles.direction = Vector3.UP
	particles.spread = spread
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	particles.gravity = Vector3(0.0, gravity_y, 0.0)
	particles.damping_min = damping
	particles.damping_max = damping
	particles.position.y = 0.4
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.max_value = maxf(grow, 1.0)
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.3, grow))
	curve.add_point(Vector2(0.75, grow * 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	particles.emitting = false
	return particles


static func _debris(color: Color) -> CPUParticles3D:
	var particles := _particles(6, 1.15, LowPoly.box(Vector3(0.13, 0.09, 0.11), 0.0))
	particles.color = color
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 62.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 11.0
	particles.gravity = Vector3(0.0, -18.0, 0.0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.7
	particles.position.y = 0.2
	particles.material_override = _vertex_material(false, false)
	particles.emitting = false
	return particles


static func _particles(amount: int, lifetime: float, mesh: Mesh) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.mesh = mesh
	particles.material_override = _vertex_material(true, true)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


static func _vertex_material(unshaded: bool, see_through: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Kolory czasteczek sa w sRGB, inaczej wygladaja na wyblakle.
	material.vertex_color_is_srgb = true
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		# Ogien i iskry sa jasniejsze niz biel, wiec filtr obrazu ich nie przygasza, a poswiata lapie blask.
		material.albedo_color = Color(GLOW_BOOST, GLOW_BOOST, GLOW_BOOST)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _ramp(colors: Array[Color], stops: Array[float]) -> Gradient:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(stops)
	return gradient
