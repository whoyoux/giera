class_name ShotFx
extends RefCounted
## Krotkotrwale efekty strzalu. Czysto wizualne, nie wplywaja na rozgrywke.


static func tracer(parent: Node, from: Vector3, to: Vector3, color := Color("fff3a3"), width := 0.05) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var node := MeshInstance3D.new()
	node.mesh = LowPoly.box(Vector3(width, width, length))
	node.material_override = LowPoly.glow(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT
	node.look_at_from_position((from + to) * 0.5, to, up)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(0.0, 0.0, 1.0), 0.09)
	tween.tween_callback(node.queue_free)


## Najwiecej tylu sladow naraz. Najstarszy znika, gdy pojawia sie nowy.
const MAX_HOLES := 48
const HOLE_SECONDS := 20.0
const CHIP_COLORS := {
	ForestTerrain.Ground.GRASS: Color("5f9438"),
	ForestTerrain.Ground.DIRT: Color("94744a"),
	ForestTerrain.Ground.STONE: Color("b9b3a6"),
	ForestTerrain.Ground.WATER: Color("bfe3f0"),
	ForestTerrain.Ground.CONCRETE: Color("c9c2b6"),
	ForestTerrain.Ground.METAL: Color("ffcb47"),
	ForestTerrain.Ground.SAND: Color("f2c98a"),
}

static var _holes: Array[Node3D] = []


## Slad po kuli na powierzchni i odpryski w kolorze tego, w co trafiono. Metal sypie iskrami.
static func bullet_hole(parent: Node, at: Vector3, normal: Vector3, ground: int) -> void:
	var hole := MeshInstance3D.new()
	hole.mesh = LowPoly.cylinder(0.07, 0.07, 0.01, 6)
	hole.material_override = LowPoly.material(Color("2d2a36"), 0.9)
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(hole)
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	hole.global_transform = Transform3D(Basis(side, up, side.cross(up)), at + up * 0.01)
	_holes.append(hole)
	while _holes.size() > MAX_HOLES:
		var oldest := _holes.pop_front() as Node3D
		if is_instance_valid(oldest):
			oldest.queue_free()
	hole.create_tween().tween_interval(HOLE_SECONDS)
	hole.get_tree().create_timer(HOLE_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(hole):
			_holes.erase(hole)
			hole.queue_free())
	var color: Color = CHIP_COLORS.get(ground, Color("c9c2b6"))
	for i in 5:
		var chip := MeshInstance3D.new()
		chip.mesh = LowPoly.box(Vector3.ONE * randf_range(0.03, 0.06), 0.0)
		chip.material_override = LowPoly.glow(color) if ground == ForestTerrain.Ground.METAL else LowPoly.material(color)
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(chip)
		chip.global_position = at + up * 0.03
		var flight := (up + Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.6), randf_range(-0.7, 0.7))).normalized() * randf_range(0.3, 0.7)
		var tween := chip.create_tween().set_parallel()
		tween.tween_property(chip, "global_position", chip.global_position + flight + Vector3.DOWN * 0.25, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(chip, "scale", Vector3.ZERO, 0.35).set_delay(0.1)
		tween.chain().tween_callback(chip.queue_free)


static func impact(parent: Node, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.mesh = LowPoly.ball(0.16, 5, 2)
	node.material_override = LowPoly.glow(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = at
	node.scale = Vector3.ONE * 0.5
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.5, 0.07)
	tween.tween_property(node, "scale", Vector3.ZERO, 0.1)
	tween.tween_callback(node.queue_free)
