class_name DesertMapInfo
extends MapInfo
## Pustynia dla Deathmatchu i Team Deathmatchu, okolo 130 x 130 m. Buduje ja DesertBuilder.


func _init() -> void:
	id = "desert"
	title = "Pustynia"
	scene_path = "res://scenes/maps/desert.tscn"
	thumbnail = "res://assets/maps/desert.png"
	zone_radius = DesertBuilder.DESERT_HALF
	menu_orbit = Vector3(72.0, 46.0, 0.0)
	podium = Vector3(0.0, 0.0, 33.0)
	places = [
		{ "name": "Stacja", "at": Vector2(0.0, -52.0) },
		{ "name": "Twierdza", "at": Vector2(0.0, 51.0) },
		{ "name": "Targ", "at": Vector2(0.0, 0.0) },
		{ "name": "Kanion", "at": Vector2(-42.0, 0.0) },
		{ "name": "Oaza", "at": DesertBuilder.POND_CENTER },
		{ "name": "Wydmy", "at": Vector2(24.0, 30.0) },
	]


func ladders() -> Array[AABB]:
	return CityMapInfo.ladder_boxes


## Piasek na ziemi, woda w oazie, blacha na wagonach i beczkach, a reszta to glina i kamien.
func ground_at(feet: Vector3) -> int:
	for box in CityMapInfo.metal_boxes:
		var top := box.end.y
		if absf(feet.y - top) < 0.35 and feet.x > box.position.x - 0.3 and feet.x < box.end.x + 0.3 and feet.z > box.position.z - 0.3 and feet.z < box.end.z + 0.3:
			return ForestTerrain.Ground.METAL
	if feet.y < 0.4 and Vector2(feet.x, feet.z).distance_to(DesertBuilder.POND_CENTER) < DesertBuilder.POND_RADIUS:
		return ForestTerrain.Ground.WATER
	if feet.y < 0.3 or (feet.y < 2.2 and absf(feet.x) > 8.0 and absf(feet.z) < 42.0):
		return ForestTerrain.Ground.SAND
	return ForestTerrain.Ground.STONE
