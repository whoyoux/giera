@tool
class_name Prop
extends StaticBody3D
## Wielka zabawka na mapie z prosta kolizja. Punkt zaczepienia lezy na podlodze.

enum Kind { BALL, RINGS, PENCIL, CONE, CRATE }

const CRATE_SCENE := "res://assets/weapons/crate-wide.glb"

@export var kind := Kind.BALL:
	set(value):
		kind = value
		_rebuild()
@export_range(0.3, 6.0, 0.05) var size := 1.0:
	set(value):
		size = value
		_rebuild()
@export var color := Color("ef6f6c"):
	set(value):
		color = value
		_rebuild()

var _visual: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.free()
	if _collision != null:
		_collision.free()
	_visual = Node3D.new()
	add_child(_visual)
	_collision = CollisionShape3D.new()
	add_child(_collision)
	match kind:
		Kind.BALL:
			_build_ball()
		Kind.RINGS:
			_build_rings()
		Kind.PENCIL:
			_build_pencil()
		Kind.CONE:
			_build_cone()
		Kind.CRATE:
			_build_crate()


func _set_cylinder(radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_collision.shape = shape
	_collision.position = Vector3(0, height * 0.5, 0)


func _build_ball() -> void:
	var radius := 1.2 * size
	LowPoly.part(_visual, LowPoly.ball(radius, 12, 7), color, Vector3(0, radius, 0), Vector3(0, 20, 18), 0.35)
	LowPoly.part(_visual, LowPoly.ball(radius * 0.42, 8, 4), Color("fff6e0"), Vector3(radius * 0.25, radius * 1.72, radius * 0.25), Vector3.ZERO, 0.35)
	var shape := SphereShape3D.new()
	shape.radius = radius
	_collision.shape = shape
	_collision.position = Vector3(0, radius, 0)


func _build_rings() -> void:
	var colors: Array[Color] = [Color("ef6f6c"), Color("f9a03f"), Color("f5d547"), Color("6fcf97"), Color("5b8def")]
	var height := 0.0
	for i in colors.size():
		var outer := (1.55 - i * 0.2) * size
		var thick := 0.34 * size
		LowPoly.part(_visual, LowPoly.ring(outer - thick * 1.25, outer, 12), colors[i], Vector3(0, height + thick * 0.62, 0), Vector3(0, i * 25, 0), 0.35)
		height += thick * 1.2
	LowPoly.part(_visual, LowPoly.cylinder(0.26 * size, 0.3 * size, height + 0.5 * size, 8), Color("c98b52"), Vector3(0, (height + 0.5 * size) * 0.5, 0))
	LowPoly.part(_visual, LowPoly.ball(0.42 * size, 8, 5), Color("7b61ff"), Vector3(0, height + 0.55 * size, 0), Vector3.ZERO, 0.35)
	_set_cylinder(1.3 * size, height + 0.6 * size)


func _build_pencil() -> void:
	var height := 7.0 * size
	var radius := 0.6 * size
	LowPoly.part(_visual, LowPoly.cylinder(radius, radius, height, 6), color, Vector3(0, height * 0.5, 0))
	LowPoly.part(_visual, LowPoly.cylinder(0.14 * size, radius, 1.4 * size, 6), Color("f3d9b1"), Vector3(0, height + 0.7 * size, 0))
	LowPoly.part(_visual, LowPoly.cylinder(0.0, 0.14 * size, 0.4 * size, 6), Color("2d2a3e"), Vector3(0, height + 1.6 * size, 0))
	LowPoly.part(_visual, LowPoly.cylinder(radius * 0.98, radius * 0.98, 0.5 * size, 6), Color("e8b4bc"), Vector3(0, 0.25 * size, 0))
	_set_cylinder(radius, height)


func _build_cone() -> void:
	var height := 2.3 * size
	LowPoly.part(_visual, LowPoly.box(Vector3(2.2, 0.22, 2.2) * size, 0.05), Color("f9a03f"), Vector3(0, 0.11 * size, 0))
	LowPoly.part(_visual, LowPoly.cylinder(0.12 * size, 0.85 * size, height, 10), Color("f9a03f"), Vector3(0, height * 0.5 + 0.2 * size, 0), Vector3.ZERO, 0.4)
	LowPoly.part(_visual, LowPoly.cylinder(0.42 * size, 0.56 * size, 0.42 * size, 10), Color("fff6e0"), Vector3(0, height * 0.52 + 0.2 * size, 0), Vector3.ZERO, 0.4)
	_set_cylinder(0.75 * size, height)


func _build_crate() -> void:
	var crate := (load(CRATE_SCENE) as PackedScene).instantiate() as Node3D
	crate.scale = Vector3.ONE * 2.2 * size
	_visual.add_child(crate)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.4, 1.8, 2.4) * size
	_collision.shape = shape
	_collision.position = Vector3(0, 0.9 * size, 0)
