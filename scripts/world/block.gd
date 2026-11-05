@tool
class_name Block
extends StaticBody3D
## Klocek mapy: siatka i kolizja powstaja z rozmiaru, wiec mozna go przesuwac
## i zmieniac wprost w edytorze przez pole "size".

@export var size := Vector3(2, 2, 2):
	set(value):
		size = value
		_rebuild()
@export var color := Color("c9a66b"):
	set(value):
		color = value
		_rebuild()
@export var outline := true:
	set(value):
		outline = value
		_rebuild()

var _mesh: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		_collision = CollisionShape3D.new()
		add_child(_collision)
	_mesh.mesh = LowPoly.box(size)
	_mesh.material_override = LowPoly.material(color, 0.035 if outline else 0.0)
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
