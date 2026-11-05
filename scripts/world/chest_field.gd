class_name ChestField
extends Node3D
## Stawia skrzynki w miejscach z mapy. Kolizja musi byc na serwerze i u klientow tak samo,
## bo ruch jest przewidywany, a wyglad powstaje tylko tam, gdzie jest ekran.

const BODY_SIZE := Vector3(1.3, 0.95, 0.9)
const DEBUG_DISTANCE := 2.2
const OPEN_SHAKE := 0.4

var _views := {}


func _ready() -> void:
	var id := 1
	for spot in get_tree().get_nodes_in_group(&"chest_spots"):
		var marker := spot as Node3D
		_add_chest(id, marker.global_position, marker.global_rotation.y)
		id += 1
	# Do testow: skrzynka tuz obok kazdego punktu odrodzenia.
	if Net.args.has("debug-chests"):
		for spot in get_tree().get_nodes_in_group(&"spawn_points"):
			var at := (spot as Node3D).global_position
			at.y = 0.0
			var center := at.direction_to(Vector3.ZERO)
			_add_chest(id, at + center * DEBUG_DISTANCE, atan2(-center.x, -center.z))
			id += 1
	if Net.is_headless:
		return
	Chests.chest_opened.connect(_on_opened)
	Chests.chest_closed.connect(func(chest_id: int) -> void: _views[chest_id].close())
	Chests.chests_reset.connect(_on_reset)


func _process(_delta: float) -> void:
	for id: int in _views:
		var chest: Dictionary = Chests.chests[id]
		var view := _views[id] as ChestView
		view.set_shaking(chest.busy or Chests.is_locally_opening(id))
		view.set_focused(id == Chests.focused_id)


func _add_chest(id: int, at: Vector3, rotation_y: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Hitscan.WORLD_MASK
	body.position = at
	body.rotation.y = rotation_y
	var shape := BoxShape3D.new()
	shape.size = BODY_SIZE
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = BODY_SIZE.y * 0.5
	body.add_child(collision)
	add_child(body)
	Chests.register(id, at, rotation_y, body.get_rid())
	if not Net.is_headless:
		var view := ChestView.new()
		body.add_child(view)
		_views[id] = view


func _on_opened(id: int, opener_id: int, tier: int) -> void:
	(_views[id] as ChestView).open(tier)
	var opener := GameState.player_node(opener_id)
	if opener != null and opener.is_local():
		opener.shake_camera(OPEN_SHAKE)


func _on_reset() -> void:
	for id: int in _views:
		(_views[id] as ChestView).set_state(Chests.chests[id].open)
