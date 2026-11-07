class_name ForestMapInfo
extends MapInfo
## Lesna polana z ruinami. Scena jest edytowana recznie, a teren liczy ForestTerrain.


func _init() -> void:
	id = "forest"
	title = "Leśna polana"
	scene_path = "res://scenes/world.tscn"
	zone_radius = ForestTerrain.BORDER_RADIUS
	menu_orbit = Vector3(30.0, 22.0, 2.0)
	podium = Vector3(16.0, ForestTerrain.surface(16.0, 1.0), 1.0)
	podium_yaw = PI * 0.5
	places = [
		{ "name": "Ruiny", "at": Vector2(0.0, 0.0) },
		{ "name": "Wzgórze", "at": ForestTerrain.HILL_CENTER },
		{ "name": "Strumień", "at": Vector2(0.0, ForestTerrain.CREEK_Z) },
	]


func surface(x: float, z: float) -> float:
	return ForestTerrain.surface(x, z)


func ground_at(feet: Vector3) -> int:
	return ForestTerrain.ground_at(feet)
