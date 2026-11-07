extends Node
## Test duzej doliny: wielkosc, miejsca, punkty startu i skrzynki, zgodnosc kolizji ze wzorem,
## granica, czas strefy i linia strzalu pod AWP. Mierzy tez czas budowy mapy.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --map=valley --tool=res://tools/valley_map_test.gd

var _failures := 0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	Maps.select("valley")
	print("[test] przelaczenie na doline: %d ms" % (Time.get_ticks_msec() - started))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := (get_node("/root/Main") as Node3D).get_world_3d().direct_space_state
	var info := Maps.info()
	_check("promien okolo 200 m", absf(ValleyTerrain.RADIUS - 200.0) < 1.0)
	_check("co najmniej 6 miejsc", info.places.size() >= 6)
	var spawns := get_tree().get_nodes_in_group(&"spawn_points")
	var chests := get_tree().get_nodes_in_group(&"chest_spots")
	print("[test] punkty startu: %d, skrzynki: %d" % [spawns.size(), chests.size()])
	_check("punkty startu dla 10 graczy z zapasem", spawns.size() >= 16)
	_check("co najmniej 60 skrzynek", chests.size() >= 60)
	var near_places := 0
	for node in chests:
		var at := (node as Node3D).global_position
		for place: Dictionary in info.places:
			if Vector2(at.x, at.z).distance_to(place.at) < 45.0:
				near_places += 1
				break
	_check("skrzynki skupione w miejscach", near_places >= chests.size() * 0.8)
	var closest_spawns := INF
	for a in spawns:
		for b in spawns:
			if a != b:
				closest_spawns = minf(closest_spawns, (a as Node3D).global_position.distance_to((b as Node3D).global_position))
	print("[test] najblizsze punkty startu: %.1f m" % closest_spawns)
	_check("punkty startu rozlozone", closest_spawns > 20.0)

	var worst := 0.0
	for spot: Vector2 in [Vector2(0, 0), Vector2(55.3, -71.1), Vector2(-120.7, 33.9), Vector2(101.1, 94.2), Vector2(-95.0, -85.0), Vector2(10.0, 140.0), Vector2(150.5, -20.3)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(spot.x, 80.0, spot.y), Vector3(spot.x, -40.0, spot.y), Hitscan.WORLD_MASK))
		if not hit.is_empty() and hit.collider.name == "Ground" and hit.shape == 0:
			worst = maxf(worst, absf(hit.position.y - ValleyTerrain.surface(spot.x, spot.y)))
	print("[test] najwiekszy blad wysokosci: %.3f" % worst)
	_check("wzor zgadza sie z kolizja", worst < 0.05)
	for node in spawns:
		var at := (node as Node3D).global_position
		_check("%s nad ziemia" % node.name, absf(at.y - 0.2 - ValleyTerrain.surface(at.x, at.z)) < 0.05)
	var border := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 8.0, 150.0), Vector3(0.0, 8.0, 260.0), Hitscan.WORLD_MASK))
	_check("granica mapy", not border.is_empty() and border.position.z < ValleyTerrain.RADIUS + 3.0)
	var total := 0.0
	for phase: Dictionary in info.zone_phases:
		total += phase.wait + phase.shrink
	print("[test] strefa: %.0f s" % total)
	_check("strefa okolo 8-10 min", total >= 480.0 and total <= 600.0)
	var line := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(10.0, ValleyTerrain.surface(10.0, 132.0) + 1.6, 132.0), Vector3(-10.0, ValleyTerrain.surface(-10.0, -10.0) + 1.6, -10.0), Hitscan.WORLD_MASK))
	var distance: float = Vector3(10.0, 0.0, 132.0).distance_to(line.position) if not line.is_empty() else 140.0
	print("[test] widok z obozu w strone ruin: %.0f m" % distance)
	_check("dluga linia pod AWP z obozu", distance > 60.0)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
