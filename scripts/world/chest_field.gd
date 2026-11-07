class_name ChestField
extends Node3D
## Stawia skrzynki w miejscach z mapy. Kolizja musi byc na serwerze i u klientow tak samo,
## bo ruch jest przewidywany, a wyglad powstaje tylko tam, gdzie jest ekran.

const BODY_SIZE := Vector3(1.3, 0.95, 0.9)
## Otwarta skrzynka ma odchylone wieko, wiec zostaje tylko nizszy kufer.
const OPEN_SIZE := Vector3(1.24, 0.56, 0.84)
const DEBUG_DISTANCE := 2.2
const OPEN_SHAKE := 0.4

var _views := {}
var _shapes := {}


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
			var floor_y := at.y - 0.2
			var center := Maps.info().zone_center
			at.y = 0.0
			at = at + at.direction_to(Vector3(center.x, 0.0, center.y)) * DEBUG_DISTANCE
			at.y = maxf(Maps.info().surface(at.x, at.z), floor_y)
			_add_chest(id, at, atan2(at.x, at.z))
			id += 1
	# Kolizja zmienia sie takze na serwerze, bo ruch jest przewidywany.
	Chests.chest_opened.connect(func(chest_id: int, _opener: int, _tier: int) -> void: _set_open_shape(chest_id, true))
	Chests.chest_closed.connect(func(chest_id: int) -> void: _set_open_shape(chest_id, false))
	Chests.chests_reset.connect(func() -> void:
		for chest_id: int in _shapes:
			_set_open_shape(chest_id, Chests.chests[chest_id].open))
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
	_shapes[id] = collision
	add_child(body)
	Chests.register(id, at, rotation_y, body.get_rid())
	if not Net.is_headless:
		var view := ChestView.new()
		body.add_child(view)
		_views[id] = view


func _set_open_shape(id: int, opened: bool) -> void:
	var collision := _shapes.get(id) as CollisionShape3D
	if collision == null:
		return
	var size := OPEN_SIZE if opened else BODY_SIZE
	(collision.shape as BoxShape3D).size = size
	collision.position.y = size.y * 0.5


func _on_opened(id: int, opener_id: int, tier: int) -> void:
	(_views[id] as ChestView).open(tier)
	var opener := GameState.player_node(opener_id)
	if opener != null and opener.is_local():
		opener.shake_camera(OPEN_SHAKE)


func _on_reset() -> void:
	for id: int in _views:
		(_views[id] as ChestView).set_state(Chests.chests[id].open)
