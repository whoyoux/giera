class_name ChestView
extends Node3D
## Zabawkowa skrzynia. Zamknieta swieci przez szpare, sypie iskrami i co chwile podskakuje,
## zeby zachecic do otwarcia. Przy otwieraniu drzy, a na koniec wieko odskakuje z wybuchem iskier.

const BODY_COLOR := Color("3d5af1")
const LID_COLOR := Color("4f6df5")
const TRIM_COLOR := Color("ffd24d")
const GLOW_COLOR := Color("ffe27a")
const LID_OPEN_ANGLE := -1.95
const LID_CRACK_ANGLE := -0.09
const INSIDE_COLOR := Color("17204d")
const INSIDE_FADE_SECONDS := 0.7
const LIGHT_IDLE := 0.7
const LIGHT_SHAKE := 2.2
const LIGHT_FLASH := 5.0
const HOP_MIN_SECONDS := 3.2
const HOP_MAX_SECONDS := 5.4
const SHAKE_SPEED := 42.0
const SHAKE_ANGLE := 0.045
const FOCUS_SCALE := 1.06
const BURST_PITCH := { Rarity.Tier.COMMON: 1.0, Rarity.Tier.EPIC: 1.15, Rarity.Tier.LEGENDARY: 1.35 }
const BURST_COUNT := { Rarity.Tier.COMMON: 24, Rarity.Tier.EPIC: 40, Rarity.Tier.LEGENDARY: 70 }

var _root: Node3D
var _lid: Node3D
var _glow_material: StandardMaterial3D
var _light: OmniLight3D
var _sparkles: CPUParticles3D
var _burst: CPUParticles3D
var _twinkle_audio: AudioStreamPlayer3D
var _rattle_audio: AudioStreamPlayer3D
var _open_audio: AudioStreamPlayer3D
var _lid_tween: Tween
var _hop_tween: Tween
var _glow_tween: Tween
var _time := 0.0
var _next_hop := 0.0
var _opened := false
var _shaking := false
var _focused := false
var _shake_amount := 0.0


func _ready() -> void:
	_time = randf() * TAU
	_next_hop = randf_range(0.5, HOP_MAX_SECONDS)
	_build()
	set_state(false)


func _process(delta: float) -> void:
	_time += delta
	var shake_target := 1.0 if _shaking and not _opened else 0.0
	_shake_amount = move_toward(_shake_amount, shake_target, delta * 6.0)
	_root.rotation.z = sin(_time * SHAKE_SPEED) * SHAKE_ANGLE * _shake_amount
	_root.position.x = sin(_time * SHAKE_SPEED * 0.73) * 0.02 * _shake_amount
	var target_scale := FOCUS_SCALE if _focused and not _opened else 1.0
	_root.scale = _root.scale.lerp(Vector3.ONE * target_scale, minf(delta * 12.0, 1.0))
	if _opened:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 8.0)
		return
	var pulse := 0.8 + sin(_time * 2.6) * 0.2
	_light.light_energy = lerpf(LIGHT_IDLE * pulse, LIGHT_SHAKE, _shake_amount)
	_glow_material.albedo_color = GLOW_COLOR.lerp(Color.WHITE, _shake_amount * 0.25) * lerpf(pulse, 1.0, _shake_amount)
	_lid.rotation.x = lerpf(0.0, LID_CRACK_ANGLE, _shake_amount)
	if _shaking:
		if not _rattle_audio.playing:
			_rattle_audio.play()
		return
	_next_hop -= delta
	if _next_hop <= 0.0:
		_next_hop = randf_range(HOP_MIN_SECONDS, HOP_MAX_SECONDS)
		_hop()


func set_focused(focused: bool) -> void:
	_focused = focused


func set_shaking(shaking: bool) -> void:
	_shaking = shaking
	if not shaking and _rattle_audio.playing:
		_rattle_audio.stop()


## Stan bez animacji, np. po dolaczeniu do trwajacej gry.
func set_state(opened: bool) -> void:
	_kill_tweens()
	_opened = opened
	_root.position = Vector3.ZERO
	_root.rotation = Vector3.ZERO
	_lid.rotation.x = LID_OPEN_ANGLE if opened else 0.0
	_sparkles.emitting = not opened
	_light.light_color = GLOW_COLOR
	_light.light_energy = 0.0 if opened else LIGHT_IDLE
	_glow_material.albedo_color = INSIDE_COLOR if opened else GLOW_COLOR


func open(tier: int) -> void:
	_kill_tweens()
	_opened = true
	_shaking = false
	_rattle_audio.stop()
	_sparkles.emitting = false
	var color := Rarity.color(tier)
	_light.light_color = color
	_light.light_energy = LIGHT_FLASH
	# Wnetrze rozblyskuje kolorem lupu i po chwili gasnie.
	_glow_material.albedo_color = Rarity.effect_color(tier)
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow_material, "albedo_color", INSIDE_COLOR, INSIDE_FADE_SECONDS)
	_burst.amount = BURST_COUNT.get(tier, BURST_COUNT[Rarity.Tier.COMMON])
	_burst.color = color
	_burst.restart()
	_open_audio.pitch_scale = BURST_PITCH.get(tier, 1.0)
	_open_audio.play()
	_root.scale = Vector3(1.18, 0.82, 1.18)
	_lid_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lid_tween.tween_property(_lid, "rotation:x", LID_OPEN_ANGLE, 0.32)


## Skrzynka wraca do gry: wieko opada i znow zacheca do otwarcia.
func close() -> void:
	_kill_tweens()
	_opened = false
	_sparkles.emitting = true
	_light.light_color = GLOW_COLOR
	_twinkle_audio.play()
	_root.scale = Vector3(0.82, 1.15, 0.82)
	_lid_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_lid_tween.tween_property(_lid, "rotation:x", 0.0, 0.4)


func _hop() -> void:
	_twinkle_audio.play()
	_hop_tween = create_tween()
	_hop_tween.tween_property(_root, "position:y", 0.14, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_root, "position:y", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tween.tween_property(_root, "position:y", 0.04, 0.06)
	_hop_tween.tween_property(_root, "position:y", 0.0, 0.06)


func _kill_tweens() -> void:
	if _lid_tween != null:
		_lid_tween.kill()
	if _hop_tween != null:
		_hop_tween.kill()
	if _glow_tween != null:
		_glow_tween.kill()


func _build() -> void:
	_root = Node3D.new()
	add_child(_root)
	_add_box(_root, Vector3(1.24, 0.52, 0.84), Vector3(0, 0.26, 0), BODY_COLOR)
	_add_box(_root, Vector3(1.3, 0.08, 0.9), Vector3(0, 0.05, 0), TRIM_COLOR)
	for x: float in [-0.42, 0.42]:
		_add_box(_root, Vector3(0.1, 0.5, 0.88), Vector3(x, 0.27, 0), TRIM_COLOR)
	_add_box(_root, Vector3(1.04, 0.05, 0.64), Vector3(0, 0.5, 0), Color("17204d"))

	_glow_material = LowPoly.glow(GLOW_COLOR)
	var glow := MeshInstance3D.new()
	glow.mesh = LowPoly.box(Vector3(1.14, 0.06, 0.74), 0.0)
	glow.material_override = _glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.y = 0.55
	_root.add_child(glow)

	# Zawias lezy na tylnej gornej krawedzi, wiec wieko buduje sie od niego do przodu.
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.56, -0.42)
	_root.add_child(_lid)
	_add_box(_lid, Vector3(1.26, 0.2, 0.86), Vector3(0, 0.1, 0.43), LID_COLOR)
	_add_box(_lid, Vector3(1.02, 0.14, 0.62), Vector3(0, 0.26, 0.43), LID_COLOR)
	for x: float in [-0.42, 0.42]:
		_add_box(_lid, Vector3(0.1, 0.36, 0.88), Vector3(x, 0.16, 0.43), TRIM_COLOR)
	_add_box(_lid, Vector3(0.24, 0.26, 0.08), Vector3(0, 0.02, 0.88), TRIM_COLOR)

	_light = OmniLight3D.new()
	_light.light_color = GLOW_COLOR
	_light.omni_range = 3.5
	_light.position = Vector3(0, 1.0, 0.2)
	add_child(_light)

	_sparkles = _particles(10, 1.5, GLOW_COLOR, 0.045)
	_sparkles.position.y = 0.7
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparkles.emission_box_extents = Vector3(0.65, 0.1, 0.45)
	_sparkles.direction = Vector3.UP
	_sparkles.spread = 12.0
	_sparkles.gravity = Vector3.ZERO
	_sparkles.initial_velocity_min = 0.25
	_sparkles.initial_velocity_max = 0.6
	add_child(_sparkles)

	_burst = _particles(24, 0.7, TRIM_COLOR, 0.05)
	_burst.position.y = 0.7
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.emitting = false
	_burst.direction = Vector3.UP
	_burst.spread = 40.0
	_burst.gravity = Vector3(0, -7.0, 0)
	_burst.initial_velocity_min = 2.0
	_burst.initial_velocity_max = 4.5
	_burst.angular_velocity_min = -360.0
	_burst.angular_velocity_max = 360.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.6, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	_burst.scale_amount_curve = shrink
	add_child(_burst)

	_twinkle_audio = _audio(Sfx.chest_twinkle(), 16.0, -6.0)
	_rattle_audio = _audio(Sfx.chest_rattle(), 22.0, -3.0)
	_open_audio = _audio(Sfx.chest_open(), 40.0, 0.0)


func _add_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = LowPoly.box(size, 0.04)
	mesh.material_override = LowPoly.material(color, 0.35)
	mesh.position = at
	parent.add_child(mesh)


func _particles(amount: int, lifetime: float, color: Color, particle_size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.color = color
	particles.mesh = LowPoly.box(Vector3.ONE * particle_size, 0.0)
	particles.material_override = LowPoly.glow(Color.WHITE)
	(particles.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _audio(stream: AudioStreamWAV, max_distance: float, volume_db: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.max_distance = max_distance
	audio.volume_db = volume_db
	audio.position.y = 0.5
	add_child(audio)
	return audio
