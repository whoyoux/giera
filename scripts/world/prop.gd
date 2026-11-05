@tool
class_name Prop
extends StaticBody3D
## Dekoracja low-poly z prosta kolizja. Punkt zaczepienia lezy na ziemi.

enum Kind { TREE, PINE, ROCK, BUSH }

@export var kind := Kind.TREE:
	set(value):
		kind = value
		_rebuild()
@export_range(0.3, 4.0, 0.05) var size := 1.0:
	set(value):
		size = value
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
		Kind.TREE:
			_build_tree()
		Kind.PINE:
			_build_pine()
		Kind.ROCK:
			_build_rock()
		Kind.BUSH:
			_build_bush()


func _set_cylinder(radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_collision.shape = shape
	_collision.position = Vector3(0, height * 0.5, 0)


func _build_tree() -> void:
	var trunk := Color("8d5a3b")
	var leaves := Color("6fbf4f")
	LowPoly.part(_visual, LowPoly.cylinder(0.22 * size, 0.32 * size, 2.0 * size, 6), trunk, Vector3(0, 1.0 * size, 0))
	LowPoly.part(_visual, LowPoly.ball(1.25 * size, 6, 3), leaves, Vector3(0, 2.9 * size, 0), Vector3(0, 20, 0), 0.04)
	LowPoly.part(_visual, LowPoly.ball(0.8 * size, 6, 3), leaves.lightened(0.12), Vector3(0.6 * size, 3.5 * size, 0.2 * size), Vector3(0, 50, 0), 0.03)
	_set_cylinder(0.35 * size, 2.5 * size)


func _build_pine() -> void:
	var trunk := Color("7a4e36")
	var leaves := Color("2f9e6e")
	LowPoly.part(_visual, LowPoly.cylinder(0.18 * size, 0.28 * size, 1.2 * size, 6), trunk, Vector3(0, 0.6 * size, 0))
	LowPoly.part(_visual, LowPoly.cylinder(0.0, 1.35 * size, 1.9 * size, 7), leaves, Vector3(0, 2.0 * size, 0), Vector3.ZERO, 0.04)
	LowPoly.part(_visual, LowPoly.cylinder(0.0, 1.05 * size, 1.6 * size, 7), leaves.lightened(0.08), Vector3(0, 3.0 * size, 0), Vector3(0, 25, 0), 0.04)
	LowPoly.part(_visual, LowPoly.cylinder(0.0, 0.72 * size, 1.3 * size, 7), leaves.lightened(0.16), Vector3(0, 3.9 * size, 0), Vector3(0, 50, 0), 0.03)
	_set_cylinder(0.32 * size, 3.0 * size)


func _build_rock() -> void:
	var stone := Color("9aa0b5")
	LowPoly.part(_visual, LowPoly.ball(1.0 * size, 5, 2), stone, Vector3(0, 0.55 * size, 0), Vector3(0, 15, 0), 0.04)
	LowPoly.part(_visual, LowPoly.ball(0.55 * size, 5, 2), stone.lightened(0.15), Vector3(0.75 * size, 0.3 * size, 0.25 * size), Vector3(0, 40, 0), 0.03)
	var shape := SphereShape3D.new()
	shape.radius = 0.95 * size
	_collision.shape = shape
	_collision.position = Vector3(0, 0.5 * size, 0)


func _build_bush() -> void:
	var leaves := Color("8bd450")
	LowPoly.part(_visual, LowPoly.ball(0.6 * size, 6, 3), leaves, Vector3(0, 0.45 * size, 0), Vector3.ZERO, 0.025)
	LowPoly.part(_visual, LowPoly.ball(0.4 * size, 6, 3), leaves.darkened(0.12), Vector3(0.45 * size, 0.3 * size, 0.15 * size), Vector3(0, 30, 0), 0.02)
	_set_cylinder(0.5 * size, 0.8 * size)
