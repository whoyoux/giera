extends Node
## Test miasteczka: punkty startu i skrzynki, wejscia na pietra i dachy, niskie przejscia, granice
## i dluga linia pod AWP. Chodzi prawdziwym ksztaltem gracza.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --map=city --tool=res://tools/city_map_test.gd

const WALK_SPEED := 6.5
const GRAVITY := 16.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

var _failures := 0


func _ready() -> void:
	Maps.select("city")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world := (get_node("/root/Main") as Node3D).get_world_3d()
	var space := world.direct_space_state
	var spawns := get_tree().get_nodes_in_group(&"spawn_points")
	var chests := get_tree().get_nodes_in_group(&"chest_spots")
	_check("co najmniej 12 punktow startu", spawns.size() >= 12)
	_check("skrzynki na mapie", chests.size() >= 12)
	_check("skrzynki zarejestrowane", Chests.chests.size() == chests.size())

	for node in spawns:
		var spawn := (node as Node3D).global_position
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * 0.5, spawn + Vector3.DOWN * 2.0, Hitscan.WORLD_MASK))
		_check("%s stoi na podlodze" % node.name, not floor_hit.is_empty() and absf(floor_hit.position.y - (spawn.y - 0.2)) < 0.05)
		_check("%s nie jest w scianie" % node.name, _fits(space, spawn, STAND_HEIGHT))
		_check("%s pozwala odejsc" % node.name, await _can_leave(spawn))
	for node in chests:
		var at := (node as Node3D).global_position
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 1.0, Hitscan.WORLD_MASK))
		_check("%s stoi na podlodze" % node.name, not below.is_empty() and absf(below.position.y - at.y) < 0.1)

	# Wejscia na pietra i dachy po schodach.
	await _walk("kamienica: schody na pietro", Vector3(-23.8, 0.1, -19.6), Vector3(-23.8, 0.0, -30.0), func(body: CharacterBody3D) -> bool: return body.position.y > CityBuilder.FLOOR_HEIGHT - 0.2)
	await _walk("kamienica: schody na dach", Vector3(-14.2, CityBuilder.FLOOR_HEIGHT + 0.1, -19.6), Vector3(-14.2, 0.0, -30.0), func(body: CharacterBody3D) -> bool: return body.position.y > CityBuilder.FLOOR_HEIGHT * 2.0 - 0.2)
	await _walk("hotel: schody na pietro", Vector3(22.8, 0.1, 16.6), Vector3(22.8, 0.0, 26.0), func(body: CharacterBody3D) -> bool: return body.position.y > CityBuilder.FLOOR_HEIGHT - 0.2)
	await _walk("hotel: schody na dach", Vector3(13.2, CityBuilder.FLOOR_HEIGHT + 0.1, 16.6), Vector3(13.2, 0.0, 26.0), func(body: CharacterBody3D) -> bool: return body.position.y > CityBuilder.FLOOR_HEIGHT * 2.0 - 0.2)
	await _walk("sklep: schody na dach", Vector3(-11.0, 0.1, -1.6), Vector3(-11.0, 0.0, -12.0), func(body: CharacterBody3D) -> bool: return body.position.y > CityBuilder.FLOOR_HEIGHT - 0.2)
	await _walk("kontener: pochylnia na dach", Vector3(-16.0, 0.1, 19.4), Vector3(-16.0, 0.0, 12.0), func(body: CharacterBody3D) -> bool: return body.position.y > 2.4)
	await _walk("drzwi kamienicy od ulicy", Vector3(-9.0, 0.1, -27.0), Vector3(-18.0, 0.0, -27.0), func(body: CharacterBody3D) -> bool: return body.position.x < -14.0)
	await _walk("drzwi hotelu od ulicy", Vector3(8.0, 0.1, 22.0), Vector3(17.0, 0.0, 22.0), func(body: CharacterBody3D) -> bool: return body.position.x > 13.0)

	# Niskie przejscia: na stojaco zatrzymuja, w kucki da sie przejsc.
	await _walk("pod kontenerem na stojaco nie", Vector3(-19.0, 0.1, 26.0), Vector3(-19.0, 0.0, 17.0), func(body: CharacterBody3D) -> bool: return body.position.z > 23.0, 2.0, true)
	await _walk("pod kontenerem w kucki tak", Vector3(-19.0, 0.1, 26.0), Vector3(-19.0, 0.0, 17.0), func(body: CharacterBody3D) -> bool: return body.position.z < 20.0, 3.0, false, CROUCH_HEIGHT)
	await _walk("brama garazu na stojaco nie", Vector3(22.5, 0.1, 11.0), Vector3(29.0, 0.0, 11.0), func(body: CharacterBody3D) -> bool: return body.position.x < 25.0, 2.0, true)
	await _walk("brama garazu w kucki tak", Vector3(22.5, 0.1, 11.0), Vector3(29.0, 0.0, 11.0), func(body: CharacterBody3D) -> bool: return body.position.x > 26.5, 3.0, false, CROUCH_HEIGHT)

	# Trzy rownolegle trasy z polnocy na poludnie i granice mapy.
	for x: float in [-30.0, 0.0, 30.0]:
		await _walk("trasa x=%d z polnocy na poludnie" % x, Vector3(x + 1.5, 0.1, -32.0), Vector3(x + 1.5, 0.0, 33.0), func(body: CharacterBody3D) -> bool: return body.position.z > 30.0, 16.0, false, STAND_HEIGHT, true)
	await _walk("granica zatrzymuje", Vector3(30.0, 0.1, 1.0), Vector3(60.0, 0.0, 1.0), func(body: CharacterBody3D) -> bool: return body.position.x < CityBuilder.HALF, 2.5, true)
	var long_line := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.5, -34.0), Vector3(0.0, 1.5, 34.0), Hitscan.WORLD_MASK))
	_check("dluga linia pod AWP (68 m)", long_line.is_empty())
	_check("metalowe kroki na kontenerze", Maps.info().ground_at(Vector3(-16.0, 2.6, 13.0)) == ForestTerrain.Ground.METAL)
	_check("beton na ulicy", Maps.info().ground_at(Vector3(0.0, 0.0, 10.0)) == ForestTerrain.Ground.CONCRETE)
	get_tree().quit(1 if _failures > 0 else 0)


func _fits(space: PhysicsDirectSpaceState3D, feet: Vector3, height: float) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = height - 0.15
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = Hitscan.WORLD_MASK
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + 0.08))
	return space.intersect_shape(query, 1).is_empty()


## Z punktu startu da sie odejsc co najmniej 3 m w ktoras strone.
func _can_leave(spawn: Vector3) -> bool:
	for i in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
		var moved := await _walk_body(spawn + Vector3.UP * 0.1, spawn + dir * 10.0, 0.8, STAND_HEIGHT)
		if Vector2(moved.x - spawn.x, moved.z - spawn.z).length() > 3.0:
			return true
	return false


## "steer" omija przeszkody jak gracz: gdy stoi w miejscu, przez chwile idzie w bok.
func _walk(label: String, start: Vector3, target: Vector3, passed: Callable, seconds := 4.0, expect_stop := false, height := STAND_HEIGHT, steer := false) -> void:
	var body := _make_body(start, height)
	var ok := false
	var time := 0.0
	var stuck := 0.0
	var detour := 0.0
	var side := 1.0
	var last := body.position
	while time < seconds:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		var goal := target
		if steer and detour > 0.0:
			var ahead := Vector3(target.x - body.position.x, 0.0, target.z - body.position.z).normalized()
			goal = body.position + ahead.cross(Vector3.UP) * side * 3.0 + ahead * 0.5
			detour -= delta
		_step(body, goal, delta)
		if steer:
			stuck = stuck + delta if body.position.distance_to(last) < WALK_SPEED * delta * 0.3 else 0.0
			last = body.position
			if stuck > 0.25 and detour <= 0.0:
				detour = 0.6
				side = -side
				stuck = 0.0
		time += get_physics_process_delta_time()
		if not expect_stop and passed.call(body):
			ok = true
			break
	if expect_stop:
		ok = passed.call(body)
	print("[test] %s: koniec %s" % [label, str(body.position.snapped(Vector3.ONE * 0.1))])
	_check(label, ok)
	body.queue_free()


func _walk_body(start: Vector3, target: Vector3, seconds: float, height: float) -> Vector3:
	var body := _make_body(start, height)
	var time := 0.0
	while time < seconds:
		await get_tree().physics_frame
		_step(body, target, get_physics_process_delta_time())
		time += get_physics_process_delta_time()
	var at := body.position
	body.queue_free()
	return at


func _make_body(start: Vector3, height: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = Hitscan.WORLD_MASK
	body.floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	add_child(body)
	body.global_position = start
	return body


func _step(body: CharacterBody3D, target: Vector3, delta: float) -> void:
	var flat := Vector3(target.x - body.position.x, 0.0, target.z - body.position.z)
	var wish := flat.normalized() * WALK_SPEED if flat.length() > 0.3 else Vector3.ZERO
	body.velocity.x = wish.x
	body.velocity.z = wish.z
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - GRAVITY * delta
	body.move_and_slide()


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
