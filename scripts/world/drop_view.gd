class_name DropView
extends Node3D
## Wyglad zrzutow: skrzynia na kolorowym spadochronie i slup dymu w miejscu ladowania.

const CRATE := Color("2f8f83")
const TRIM := Color("ffcb47")
const CANOPY: Array[Color] = [Color("ef6f6c"), Color("fff3e0")]

var _views := {}


func _ready() -> void:
	SupplyDrops.drop_announced.connect(_on_announced)
	SupplyDrops.drop_landed.connect(_on_landed)
	Match.phase_changed.connect(func() -> void:
		if Match.phase != Match.Phase.LIVE:
			_clear())
	Net.session_ended.connect(func(_reason: String) -> void: _clear())


func _process(_delta: float) -> void:
	for id: int in _views:
		if not SupplyDrops.drops.has(id):
			continue
		var drop: Dictionary = SupplyDrops.drops[id]
		var view: Dictionary = _views[id]
		var left := maxf(0.0, (drop.land_tick - NetworkTime.tick - NetworkTime.tick_factor) * NetworkTime.ticktime * Match.zone_speed)
		var height := SupplyDrops.START_HEIGHT * left / SupplyDrops.FALL_SECONDS
		var crate: Node3D = view.crate
		crate.position = drop.position + Vector3.UP * height
		crate.rotation.y += 0.01
		(view.canopy as Node3D).visible = height > 0.05


func _on_announced(id: int) -> void:
	var drop: Dictionary = SupplyDrops.drops[id]
	var crate := Node3D.new()
	add_child(crate)
	LowPoly.part(crate, LowPoly.box(Vector3(1.4, 1.0, 1.4), 0.08), CRATE, Vector3.UP * 0.5)
	LowPoly.part(crate, LowPoly.box(Vector3(1.5, 0.18, 1.5), 0.04), TRIM, Vector3.UP * 0.5)
	var canopy := Node3D.new()
	canopy.position = Vector3.UP * 4.0
	crate.add_child(canopy)
	for i in 8:
		var angle := TAU * i / 8.0
		var panel := LowPoly.part(canopy, LowPoly.box(Vector3(1.4, 0.12, 2.6), 0.03), CANOPY[i % 2], Vector3(sin(angle), 0.0, cos(angle)) * 1.1)
		panel.rotation = Vector3(0.35, angle, 0.0)
	for i in 4:
		var angle := TAU * i / 4.0 + PI * 0.25
		var line := LowPoly.part(crate, LowPoly.box(Vector3(0.03, 3.4, 0.03), 0.0), Color("3b3552"), Vector3(sin(angle) * 0.9, 2.5, cos(angle) * 0.9))
		line.rotation.z = 0.2 * sin(angle)
	var smoke := _smoke(drop.position)
	_views[id] = { "crate": crate, "canopy": canopy, "smoke": smoke }


func _on_landed(id: int) -> void:
	if _views.has(id):
		(_views[id].crate as Node3D).queue_free()
		_views[id].crate = Node3D.new()
		add_child(_views[id].crate)
		_views[id].canopy = Node3D.new()


## Kolorowy dym widoczny z daleka, zeby latwo bylo trafic do zrzutu.
func _smoke(at: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 6.0
	particles.position = at + Vector3.UP * 0.3
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 12.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 3.5
	material.gravity = Vector3(0.4, 0.3, 0.0)
	material.scale_min = 1.5
	material.scale_max = 3.0
	material.color = Color(1.0, 0.45, 0.4, 0.55)
	particles.process_material = material
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var smoke_material := StandardMaterial3D.new()
	smoke_material.albedo_color = Color(1.0, 0.55, 0.5, 0.45)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.vertex_color_use_as_albedo = true
	mesh.material = smoke_material
	particles.draw_pass_1 = mesh
	add_child(particles)
	return particles


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_views.clear()
