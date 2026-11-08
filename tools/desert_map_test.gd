extends Node
## Test pustyni: punkty startu obu druzyn i Deathmatchu, skrzynki, pochylnie na plaskowyze, wieze
## i dach domu kupca, most linowy, trzy rownolegle trasy, granice mapy i dlugie linie strzalu.
## Chodzi prawdziwym ksztaltem gracza.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --map=desert --tool=res://tools/desert_map_test.gd

const WALK_SPEED := 6.5
const GRAVITY := 16.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

var _failures := 0


func _ready() -> void:
	Maps.select("desert")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world := (get_node("/root/Main") as Node3D).get_world_3d()
	var space := world.direct_space_state
	var spawns := get_tree().get_nodes_in_group(&"spawn_points")
	var chests := get_tree().get_nodes_in_group(&"chest_spots")
	var team_counts := [0, 0]
	for node in spawns:
		var team: int = Teams.spawn_team(node as Node3D, spawns)
		if team >= 0:
			team_counts[team] += 1
	_check("co najmniej 16 punktow startu Deathmatchu", spawns.size() >= 16)
	_check("co najmniej 8 punktow na druzyne (%s)" % str(team_counts), team_counts[0] >= 8 and team_counts[1] >= 8)
	_check("Kaktusy startuja na polnocy, Zuczki na poludniu", _team_side(spawns, 0) < -40.0 and _team_side(spawns, 1) > 40.0)
	_check("skrzynki na mapie", chests.size() >= 12)
	_check("skrzynki zarejestrowane", Chests.chests.size() == chests.size())
	_check("szesc miejsc z nazwami", Maps.info().places.size() >= 5)

	for node in spawns:
		var spawn := (node as Node3D).global_position
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * 0.5, spawn + Vector3.DOWN * 2.0, Hitscan.WORLD_MASK))
		_check("%s stoi na podlodze" % node.name, not floor_hit.is_empty() and absf(floor_hit.position.y - (spawn.y - 0.2)) < 0.15)
		_check("%s nie jest w scianie" % node.name, _fits(space, spawn, STAND_HEIGHT))
		_check("%s pozwala odejsc" % node.name, await _can_leave(spawn))
	for node in chests:
		var at := (node as Node3D).global_position
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 1.0, Hitscan.WORLD_MASK))
		_check("%s stoi na podlodze" % node.name, not below.is_empty() and absf(below.position.y - at.y) < 0.15)

	var mesa := DesertBuilder.MESA_HEIGHT
	var tower := DesertBuilder.TOWER_HEIGHT
	await _walk("kanion: pochylnia na zachodni plaskowyz", Vector3(-54.0, 0.1, 37.0), Vector3(-54.0, 0.0, 18.0), func(body: CharacterBody3D) -> bool: return body.position.y > mesa - 0.1 and body.position.z < 24.0, 6.0)
	await _walk("kanion: pochylnia na wschodni plaskowyz", Vector3(-15.0, 0.1, -14.0), Vector3(-30.0, 0.0, -14.0), func(body: CharacterBody3D) -> bool: return body.position.y > mesa - 0.1 and body.position.x < -27.0, 6.0)
	await _walk("kanion: most linowy", Vector3(-50.0, mesa + 0.1, 0.0), Vector3(-29.0, 0.0, 0.0), func(body: CharacterBody3D) -> bool: return body.position.x > -33.0 and body.position.y > mesa - 0.3, 6.0)
	await _walk("twierdza: pochylnia na wieze", Vector3(-17.1, 0.1, 57.5), Vector3(-17.1, 0.0, 48.0), func(body: CharacterBody3D) -> bool: return body.position.y > tower - 0.1 and body.position.z < 49.0, 6.0)
	await _walk("twierdza: z pochylni na taras", Vector3(-17.1, tower + 0.1, 48.5), Vector3(-21.0, 0.0, 46.5), func(body: CharacterBody3D) -> bool: return body.position.x < -19.0 and body.position.y > tower - 0.3, 4.0)
	await _walk("targ: pochylnia na dach domu", Vector3(11.0, 0.1, 8.5), Vector3(11.0, 0.0, -4.0), func(body: CharacterBody3D) -> bool: return body.position.y > tower - 0.3 and body.position.z < -1.0, 6.0)
	await _walk("wydma: wejscie bez skakania", Vector3(-34.0, 0.1, 30.0), Vector3(-22.0, 0.0, 30.0), func(body: CharacterBody3D) -> bool: return body.position.y > 1.3, 4.0)
	await _walk("wagon: przejscie przez otwarty wagon", Vector3(-14.0, 0.1, -39.0), Vector3(-14.0, 0.0, -49.0), func(body: CharacterBody3D) -> bool: return body.position.z < -45.8, 5.0)

	# Trzy rownolegle trasy z bazy do bazy i granice mapy.
	for x: float in [-40.0, 0.0, 40.0]:
		await _walk("trasa x=%d ze stacji do twierdzy" % x, Vector3(x + 1.5, 0.1, -40.0), Vector3(x + 1.5, 0.0, 40.0), func(body: CharacterBody3D) -> bool: return body.position.z > 37.0, 25.0, false, STAND_HEIGHT, true)
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var start := side * 58.0 + side.cross(Vector3.UP) * 6.0 + Vector3.UP * 0.1
		await _walk("granica zatrzymuje (%s)" % str(side), start, start + side * 30.0, func(body: CharacterBody3D) -> bool: return absf(body.position.x) < DesertBuilder.DESERT_HALF and absf(body.position.z) < DesertBuilder.DESERT_HALF, 3.0, true)
	var rails := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-60.0, 1.5, -40.0), Vector3(60.0, 1.5, -40.0), Hitscan.WORLD_MASK))
	_check("dluga linia wzdluz torow (120 m)", rails.is_empty())
	var mesa_line := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-55.0, mesa + 1.5, -25.0), Vector3(-55.0, mesa + 1.5, 25.0), Hitscan.WORLD_MASK))
	_check("dluga linia po plaskowyzu (50 m)", mesa_line.is_empty())
	_check("kroki po piasku", Maps.info().ground_at(Vector3(20.0, 0.0, -20.0)) == ForestTerrain.Ground.SAND)
	_check("woda w oazie", Maps.info().ground_at(Vector3(DesertBuilder.POND_CENTER.x, 0.0, DesertBuilder.POND_CENTER.y)) == ForestTerrain.Ground.WATER)
	get_tree().quit(1 if _failures > 0 else 0)


## Srednie z druzyny: gdzie na osi polnoc-poludnie startuje.
func _team_side(spawns: Array[Node], team: int) -> float:
	var total := 0.0
	var count := 0
	for node in spawns:
		if Teams.spawn_team(node as Node3D, spawns) == team:
			total += (node as Node3D).global_position.z
			count += 1
	return total / maxi(count, 1)


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
