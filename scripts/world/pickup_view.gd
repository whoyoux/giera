class_name PickupView
extends Node3D
## Przedmiot na ziemi: unosi sie i obraca nad pierscieniem, a smuga swiatla w kolorze klasy
## pozwala wypatrzyc lepszy loot z daleka.

const BEAM_SHADER := preload("res://shaders/loot_beam.gdshader")
const BEAM_HEIGHTS := { Rarity.Tier.COMMON: 0.9, Rarity.Tier.EPIC: 2.2, Rarity.Tier.LEGENDARY: 3.6 }
const LIGHT_ENERGY := { Rarity.Tier.EPIC: 0.8, Rarity.Tier.LEGENDARY: 1.4 }
const MODEL_SCALE := 1.3
const HOVER_HEIGHT := 0.5
const HOVER_RANGE := 0.06
const SPIN_SPEED := 1.1
const FOCUS_SCALE := 1.25
const THROW_SECONDS := 0.42
const THROW_ARC := 0.7
const LANDING_SCALE := 1.3
const COLLECT_SECONDS := 0.16
const COLLECT_LINGER_SECONDS := 0.4
## Ostatnie sekundy przed zniknieciem przedmiot miga.
const BLINK_SECONDS := 6.0

var _entry: Dictionary
var _pivot: Node3D
var _beam_anchor: Node3D
var _ring_material: StandardMaterial3D
var _land_audio: AudioStreamPlayer3D
var _time := 0.0
var _scale := 0.0
var _scale_target := 1.0
var _collecting := false
var _focused := false


func setup(entry: Dictionary) -> void:
	_entry = entry
	position = entry.position
	_time = randf() * TAU


func _ready() -> void:
	var tier := ItemStack.tier_of(_entry.stack)
	var color := Rarity.color(tier)
	_build_ring(color)
	_build_beam(tier, color)
	_pivot = Node3D.new()
	add_child(_pivot)
	_build_model()
	if LIGHT_ENERGY.has(tier):
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = LIGHT_ENERGY[tier]
		light.omni_range = 3.0
		light.position = Vector3.UP * 0.7
		add_child(light)
	_land_audio = AudioStreamPlayer3D.new()
	_land_audio.stream = Sfx.item_land()
	add_child(_land_audio)
	var from: Vector3 = _entry.from
	if from.is_equal_approx(position):
		_scale = 1.0
	else:
		_animate_throw(from)


func _process(delta: float) -> void:
	if _collecting:
		return
	_time += delta
	_scale = lerpf(_scale, _scale_target, minf(delta * 14.0, 1.0))
	_pivot.position.y = HOVER_HEIGHT + sin(_time * 2.2) * HOVER_RANGE
	_pivot.rotation.y = _time * SPIN_SPEED
	_pivot.scale = Vector3.ONE * _scale * MODEL_SCALE
	var left: float = (_entry.expires_tick - NetworkTime.tick) * NetworkTime.ticktime
	_pivot.visible = left > BLINK_SECONDS or fmod(_time, 0.4) < 0.26


func set_focused(focused: bool) -> void:
	if focused == _focused or _collecting:
		return
	_focused = focused
	_scale_target = FOCUS_SCALE if focused else 1.0
	_ring_material.albedo_color.a = 1.0 if focused else 0.65


## Przedmiot leci do gracza, ktory go podniosl. Bez gracza po prostu znika.
func collect(picker: Player) -> void:
	_collecting = true
	var tween := create_tween().set_parallel()
	_beam_anchor.visible = false
	tween.tween_property(_pivot, "scale", Vector3.ONE * 0.1, COLLECT_SECONDS)
	if picker != null:
		tween.tween_property(self, "global_position", picker.position + Vector3.UP * 0.9, COLLECT_SECONDS)
		if not picker.is_local():
			var audio := AudioStreamPlayer3D.new()
			audio.stream = Sfx.item_pickup()
			add_child(audio)
			audio.play()
	# Dzwiek innego gracza ma czas wybrzmiec, zanim wezel zniknie.
	tween.chain().tween_property(_pivot, "visible", false, 0.0)
	tween.chain().tween_interval(COLLECT_LINGER_SECONDS)
	tween.chain().tween_callback(queue_free)


func _animate_throw(from: Vector3) -> void:
	var landing := position
	position = from
	_beam_anchor.scale = Vector3(1.0, 0.01, 1.0)
	_beam_anchor.visible = false
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		position = from.lerp(landing, t) + Vector3.UP * sin(t * PI) * THROW_ARC
	, 0.0, 1.0, THROW_SECONDS)
	tween.tween_callback(_on_landed.bind(landing))


func _on_landed(landing: Vector3) -> void:
	position = landing
	_land_audio.play()
	_scale = LANDING_SCALE
	_beam_anchor.visible = true
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_beam_anchor, "scale", Vector3.ONE, 0.3)


func _build_model() -> void:
	var visual := ItemStack.visual_of(_entry.stack)
	if visual == null or not ResourceLoader.exists(visual.model_path):
		return
	var model := (load(visual.model_path) as PackedScene).instantiate() as Node3D
	model.position = -(visual.grip + visual.muzzle) * 0.5
	_pivot.add_child(model)


func _build_ring(color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	torus.rings = 20
	torus.ring_segments = 6
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(color, 0.65)
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.04
	ring.scale.y = 0.3
	add_child(ring)


func _build_beam(tier: int, color: Color) -> void:
	var height: float = BEAM_HEIGHTS.get(tier, BEAM_HEIGHTS[Rarity.Tier.COMMON])
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.4
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("height", height)
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Smuga rosnie od ziemi, wiec skalujemy kotwice lezaca pod siatka.
	beam.position.y = height * 0.5
	_beam_anchor = Node3D.new()
	_beam_anchor.add_child(beam)
	add_child(_beam_anchor)
