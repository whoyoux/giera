class_name GrenadeProjectile
extends Node3D
## Lecacy granat: leci po luku, odbija sie od mapy, a przed wybuchem miga i pika coraz szybciej.

const GRAVITY := 17.0
const BOUNCE := 0.42
const GROUND_FRICTION := 0.72
const SURFACE_GAP := 0.08
const REST_SPEED := 1.1
const BOUNCE_SOUND_SPEED := 2.2
const MAX_STEP := 0.05
const TUMBLE_SPEED := 9.0
## Ostatnie sekundy migania. Odstep miedzy sygnalami maleje do zera.
const WARNING_MIN_GAP := 0.09
const WARNING_MAX_GAP := 0.5
const WARNING_COLOR := Color("ff4a3d")
const RING_RADIUS := 0.55

var grenade_id := 0
var definition: GrenadeDefinition
var velocity := Vector3.ZERO
var fuse := 2.0
var owner_id := 0

var _time := 0.0
var _resting := false
var _visual: Node3D
var _next_beep := 0.0
var _light: OmniLight3D
var _bulb: MeshInstance3D
var _ring: MeshInstance3D
var _trail: CPUParticles3D
var _bounce_audio: AudioStreamPlayer3D
var _beep_audio: AudioStreamPlayer3D
var _flash := 0.0


func _ready() -> void:
	if Net.is_headless:
		return
	_build_visual()


func _process(delta: float) -> void:
	_time += delta
	var left := delta
	while left > 0.0 and not _resting:
		var step := minf(left, MAX_STEP)
		_advance(step)
		left -= step
	if multiplayer.is_server() and _time >= fuse:
		Grenades.server_explode(grenade_id)
		set_process(false)
		return
	if not Net.is_headless:
		_update_visual(delta)


func _advance(step: float) -> void:
	velocity.y -= GRAVITY * step
	var world := get_world_3d()
	var next := position + velocity * step
	var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position, next, Hitscan.WORLD_MASK))
	if hit.is_empty():
		position = next
		return
	var speed := velocity.length()
	position = hit.position + hit.normal * SURFACE_GAP
	velocity = velocity.bounce(hit.normal) * BOUNCE
	if hit.normal.y > 0.6:
		velocity.x *= GROUND_FRICTION
		velocity.z *= GROUND_FRICTION
		if velocity.length() < REST_SPEED:
			velocity = Vector3.ZERO
			_resting = true
	if speed > BOUNCE_SOUND_SPEED and _bounce_audio != null:
		_bounce_audio.pitch_scale = randf_range(0.9, 1.15)
		_bounce_audio.play()


func _update_visual(delta: float) -> void:
	if not _resting:
		_visual.rotation += Vector3(1.0, 0.6, 0.3) * TUMBLE_SPEED * delta
	else:
		_trail.emitting = false
	var remaining := maxf(fuse - _time, 0.0)
	_next_beep -= delta
	if _next_beep <= 0.0:
		_next_beep = lerpf(WARNING_MIN_GAP, WARNING_MAX_GAP, clampf(remaining / fuse, 0.0, 1.0))
		_flash = 1.0
		_beep_audio.play()
	_flash = move_toward(_flash, 0.0, delta * 9.0)
	_light.light_energy = _flash * 2.6
	_bulb.scale = Vector3.ONE * (0.7 + _flash * 0.8)
	# Pierscien na ziemi pokazuje niebezpieczne miejsce, gdy granat juz lezy.
	_ring.visible = _resting
	var pulse := 1.0 + (1.0 - remaining / fuse) * 0.8 + _flash * 0.2
	_ring.scale = Vector3(pulse, 0.25, pulse)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var item_visual := definition.item_visual
	var model := (load(item_visual.model_path) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * item_visual.model_scale
	model.position = Vector3.DOWN * 0.2
	_visual.add_child(model)

	var glow := LowPoly.glow(WARNING_COLOR)
	_bulb = MeshInstance3D.new()
	_bulb.mesh = LowPoly.ball(0.07, 6, 3)
	_bulb.material_override = glow
	_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bulb.position = Vector3.UP * 0.28
	_visual.add_child(_bulb)
	_light = OmniLight3D.new()
	_light.light_color = WARNING_COLOR
	_light.omni_range = 3.5
	_light.light_energy = 0.0
	add_child(_light)

	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS * 0.85
	torus.outer_radius = RING_RADIUS
	torus.rings = 18
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = glow
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_ring.position = Vector3.DOWN * 0.06
	add_child(_ring)

	_trail = GrenadeFx.trail()
	add_child(_trail)
	_bounce_audio = _audio(Sfx.grenade_bounce(), 30.0)
	_beep_audio = _audio(Sfx.grenade_beep(), 26.0)


func _audio(stream: AudioStreamWAV, range_end: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.max_distance = range_end
	add_child(audio)
	return audio
