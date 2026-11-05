@tool
class_name ForestProp
extends StaticBody3D
## Drzewo albo skala na mapie. Kolizja jest prostsza od modelu: drzewo zatrzymuje tylko pien,
## wiec przez korone mozna strzelac. Serwer bez ekranu nie wczytuje modelu.

const MODEL_FOLDER := "res://assets/forest/%s.gltf"

@export var model := "Tree_1_A_Color1"
## Rozmiar skrzynki kolizji. Pusty oznacza pien o podanym promieniu.
@export var box_size := Vector3.ZERO
@export var box_center := Vector3.ZERO
@export var trunk_radius := 0.3
@export var trunk_height := 4.0
## Skalujemy sam model, bo skalowanie wezla fizycznego psuje kolizje.
@export var scale_factor := 1.0


func _ready() -> void:
	var collision := CollisionShape3D.new()
	if box_size != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = box_size
		collision.shape = box
		collision.position = box_center
	else:
		var trunk := CylinderShape3D.new()
		trunk.radius = trunk_radius
		trunk.height = trunk_height
		collision.shape = trunk
		collision.position.y = trunk_height * 0.5
	add_child(collision)
	if DisplayServer.get_name() != "headless" or Engine.is_editor_hint():
		var visual := (load(MODEL_FOLDER % model) as PackedScene).instantiate() as Node3D
		visual.scale = Vector3.ONE * scale_factor
		add_child(visual)
