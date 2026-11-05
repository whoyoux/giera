@tool
class_name Block
extends StaticBody3D
## Klocek mapy: siatka i kolizja powstaja z rozmiaru, wiec mozna go przesuwac
## i zmieniac wprost w edytorze. Opcjonalna litera trafia na dwie sciany klocka.

@export var size := Vector3(2, 2, 2):
	set(value):
		size = value
		_rebuild()
@export var color := Color("e0a458"):
	set(value):
		color = value
		_rebuild()
@export_range(0.0, 0.5, 0.01) var bevel := 0.09:
	set(value):
		bevel = value
		_rebuild()
@export var letter := "":
	set(value):
		letter = value
		_rebuild()

var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _labels: Array[Label3D] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _collision == null:
		_collision = CollisionShape3D.new()
		add_child(_collision)
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	# Serwer bez ekranu potrzebuje tylko kolizji.
	if DisplayServer.get_name() == "headless" and not Engine.is_editor_hint():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	_mesh.mesh = LowPoly.box(size, bevel)
	_mesh.material_override = LowPoly.material(color)
	for label in _labels:
		label.free()
	_labels.clear()
	if not letter.is_empty():
		for side: float in [1.0, -1.0]:
			_add_letter(side)


func _add_letter(side: float) -> void:
	var label := Label3D.new()
	label.text = letter
	label.font_size = 256
	label.outline_size = 0
	label.pixel_size = minf(size.x, size.y) * 0.0034
	label.modulate = color.darkened(0.45)
	label.shaded = true
	label.position = Vector3(0.0, 0.0, side * (size.z * 0.5 + 0.012))
	label.rotation.y = 0.0 if side > 0.0 else PI
	add_child(label)
	_labels.append(label)
