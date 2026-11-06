extends Node
## Test lesnej mapy: wzor terenu, miejsca na mapie i chodzenie po zboczach.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/map_test.gd

const WALK_SPEED := 6.5
const GRAVITY := 16.0

var _failures := 0


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world := (get_node("/root/Main") as Node3D).get_world_3d()
	var space := world.direct_space_state

	# Kolizja lezy dokladnie tam, gdzie liczy ja wzor.
	var worst := 0.0
	for spot: Vector2 in [Vector2(0, 0), Vector2(24, -24), Vector2(7.3, 34.1), Vector2(-36.7, 18.2), Vector2(41.1, -15.9), Vector2(-3.3, 46.0)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(spot.x, 30, spot.y), Vector3(spot.x, -10, spot.y), Hitscan.WORLD_MASK))
		if hit.collider is ForestTerrain:
			worst = maxf(worst, absf(hit.position.y - ForestTerrain.surface(spot.x, spot.y)))
	print("[test] najwiekszy blad wysokosci: %.4f" % worst)
	_check("wzor zgadza sie z kolizja", worst < 0.01)

	# Odrodzenie jest na ziemi i ma wolna droge w strone polany.
	for node in get_tree().get_nodes_in_group(&"spawn_points"):
		var spawn := (node as Node3D).global_position
		_check("%s tuz nad ziemia" % node.name, absf(spawn.y - 0.2 - ForestTerrain.surface(spawn.x, spawn.z)) < 0.02)
		var from := spawn + Vector3.UP
		var toward := Vector3(0, from.y, 0)
		var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from.move_toward(toward, 6.0), Hitscan.WORLD_MASK))
		_check("%s ma wolna droge" % node.name, clear.is_empty())

	# Prawdziwy ksztalt gracza idacy po terenie.
	await _walk("rampa na wieze", Vector3(5.0, 0.3, -4.5), Vector3(-3.0, 0.0, -4.5), func(body: CharacterBody3D) -> bool: return body.position.y > 3.4)
	await _walk("wejscie na wzgorze", Vector3(24.0, 1.0, -12.0), Vector3(24.0, 0.0, -24.0), func(body: CharacterBody3D) -> bool: return body.position.y > 3.4)
	await _walk("wyjscie ze strumienia", Vector3(-1.0, 0.0, ForestTerrain.creek_center_z(-1.0)), Vector3(-1.0, 0.0, 18.0), func(body: CharacterBody3D) -> bool: return body.position.z < 21.0)
	await _walk("granica zatrzymuje", Vector3(47.0, 3.0, 0.5), Vector3(75.0, 0.0, 0.5), func(body: CharacterBody3D) -> bool: return Vector2(body.position.x, body.position.z).length() < ForestTerrain.BORDER_RADIUS + 0.5, 2.0, true)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _walk(label: String, start: Vector3, target: Vector3, reached: Callable, seconds := 4.0, must_hold := false) -> void:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = Hitscan.WORLD_MASK
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	add_child(body)
	body.global_position = start
	body.global_position.y = maxf(start.y, ForestTerrain.surface(start.x, start.z) + 0.1)
	var elapsed := 0.0
	var ok := false
	var held := true
	while elapsed < seconds:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		var wish := (target - body.global_position) * Vector3(1, 0, 1)
		wish = wish.normalized() * WALK_SPEED
		body.velocity.x = wish.x
		body.velocity.z = wish.z
		body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - GRAVITY * delta
		body.move_and_slide()
		ok = ok or reached.call(body)
		held = held and reached.call(body)
	print("[test] %s: koniec %s" % [label, body.global_position])
	_check(label, held if must_hold else ok)
	body.queue_free()


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
