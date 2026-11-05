class_name Hitscan
extends RefCounted
## Sprawdzanie trafien liczone matematycznie.
##
## Podczas rollbacku pozycje graczy sa cofane wiele razy na klatke, a silnik
## fizyki aktualizuje ich kolizje dopiero w swoim kroku, wiec zwykly raycast
## widzialby nieaktualne polozenia. Fizyki uzywamy tylko dla statycznej mapy.

const RANGE := 250.0
const WORLD_MASK := 1
const BODY_RADIUS := 0.36
const BODY_BOTTOM := 0.2
const BODY_TOP := 0.95
const HEAD_RADIUS := 0.42
const HEAD_CENTER := 1.38
## Kat zlotego podzialu rownomiernie rozklada sruciny, a kolejne strzaly obracaja wzor.
const GOLDEN_ANGLE := 2.39996
## Te mnozniki daja niepowtarzalne punkty, ktore nie uciekaja w jedna strone kola.
const SEQUENCE_A := 0.7548776662
const SEQUENCE_B := 0.5698402910


static func direction(yaw: float, pitch: float) -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


## Zwraca { position, player, headshot, hit_world }. "player" jest null przy pudle.
## Z view_tick >= 0 cele sa ustawiane tam, gdzie strzelec widzial je w tym ticku.
static func trace(world: World3D, from: Vector3, dir: Vector3, shooter_id: int, tree: SceneTree, view_tick := -1) -> Dictionary:
	var to := from + dir * RANGE
	var result := { "position": to, "player": null, "headshot": false, "hit_world": false }
	var nearest := RANGE

	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	var world_hit := world.direct_space_state.intersect_ray(query)
	if not world_hit.is_empty():
		nearest = from.distance_to(world_hit.position)
		result.position = world_hit.position
		result.hit_world = true

	for node in tree.get_nodes_in_group(&"players"):
		var player := node as Player
		if player.peer_id == shooter_id or not player.is_alive():
			continue
		var feet := player.position if view_tick < 0 else player.position_at(view_tick)
		var head := Geometry3D.segment_intersects_sphere(from, to, feet + Vector3.UP * HEAD_CENTER, HEAD_RADIUS)
		if not head.is_empty() and from.distance_to(head[0]) < nearest:
			nearest = from.distance_to(head[0])
			result = { "position": head[0], "player": player, "headshot": true, "hit_world": false }
			continue
		var points := Geometry3D.get_closest_points_between_segments(from, to, feet + Vector3.UP * BODY_BOTTOM, feet + Vector3.UP * BODY_TOP)
		if points[0].distance_to(points[1]) <= BODY_RADIUS and from.distance_to(points[0]) < nearest:
			nearest = from.distance_to(points[0])
			result = { "position": points[0], "player": player, "headshot": false, "hit_world": false }
	return result


## Kierunki pociskow wokol "dir". Wzor wynika tylko z "pattern", czyli numeru ticku strzalu,
## wiec serwer i kazdy klient licza dokladnie to samo bez przesylania losowania.
## Pojedynczy pocisk trafia w losowo wygladajacy punkt kola, a srut wypelnia je rowno.
static func pellet_directions(dir: Vector3, count: int, spread_degrees: float, pattern: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var right := dir.cross(Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT).normalized()
	var top := right.cross(dir)
	var widest := tan(deg_to_rad(spread_degrees))
	if count <= 1:
		var angle := fposmod(pattern * SEQUENCE_A, 1.0) * TAU
		var radius := widest * sqrt(fposmod(pattern * SEQUENCE_B, 1.0))
		result.append((dir + (right * cos(angle) + top * sin(angle)) * radius).normalized())
		return result
	for index in count:
		var angle := (pattern + index) * GOLDEN_ANGLE
		var radius := widest * sqrt(float(index) / (count - 1))
		result.append((dir + (right * cos(angle) + top * sin(angle)) * radius).normalized())
	return result


## Cios z bliska: wystarczy, ze cel jest w zasiegu i w stozku przed graczem. Liczy sie ten
## najblizej srodka celownika. Zwraca { position, player, hit_world }.
static func melee(world: World3D, from: Vector3, dir: Vector3, reach: float, cone_degrees: float, attacker_id: int, tree: SceneTree, view_tick := -1) -> Dictionary:
	var end := from + dir * reach
	var result := { "position": end, "player": null, "hit_world": false }
	var space := world.direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, end, WORLD_MASK))
	if not wall.is_empty():
		result.position = wall.position
		result.hit_world = true
	var best := cos(deg_to_rad(cone_degrees))
	for node in tree.get_nodes_in_group(&"players"):
		var player := node as Player
		if player.peer_id == attacker_id or not player.is_alive():
			continue
		var feet := player.position if view_tick < 0 else player.position_at(view_tick)
		var points := Geometry3D.get_closest_points_between_segments(from, end, feet + Vector3.UP * BODY_BOTTOM, feet + Vector3.UP * HEAD_CENTER)
		var target: Vector3 = points[1]
		var distance := from.distance_to(target)
		if distance > reach + BODY_RADIUS:
			continue
		var facing := dir.dot((target - from) / distance) if distance > 0.01 else 1.0
		if facing < best:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, target, WORLD_MASK)).is_empty():
			continue
		best = facing
		result = { "position": target, "player": player, "hit_world": false }
	return result
