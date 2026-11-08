class_name CityMapInfo
extends MapInfo
## Zabawkowe miasteczko dla Deathmatchu, okolo 70 x 70 m. Buduje je CityBuilder.

## Metalowe bryly, np. kontenery i auta. Na ich dachu kroki brzmia jak po blasze.
static var metal_boxes: Array[AABB] = []
## Drabiny i rury, ktore buduje CityBuilder.
static var ladder_boxes: Array[AABB] = []


func _init() -> void:
	id = "city"
	title = "Miasteczko"
	scene_path = "res://scenes/maps/city.tscn"
	thumbnail = "res://assets/maps/city.png"
	zone_radius = CityBuilder.HALF
	menu_orbit = Vector3(34.0, 24.0, 2.0)
	podium = Vector3(0.0, 0.0, 0.0)
	places = [
		{ "name": "Skrzyżowanie", "at": Vector2(0.0, 0.0) },
		{ "name": "Kamienica", "at": Vector2(-19.0, -25.0) },
		{ "name": "Plac", "at": Vector2(16.0, -20.0) },
		{ "name": "Kontenery", "at": Vector2(-17.0, 21.0) },
		{ "name": "Hotel", "at": Vector2(18.0, 22.0) },
	]


func ladders() -> Array[AABB]:
	return ladder_boxes


func ground_at(feet: Vector3) -> int:
	for box in metal_boxes:
		var top := box.end.y
		if absf(feet.y - top) < 0.35 and feet.x > box.position.x - 0.3 and feet.x < box.end.x + 0.3 and feet.z > box.position.z - 0.3 and feet.z < box.end.z + 0.3:
			return ForestTerrain.Ground.METAL
	return ForestTerrain.Ground.CONCRETE
