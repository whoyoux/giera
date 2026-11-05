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
