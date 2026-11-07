class_name ValleyMapInfo
extends MapInfo
## Duza dolina dla Battle Royale: okolo 200 m promienia i szesc miejsc z nazwami.


func _init() -> void:
	id = "valley"
	title = "Dolina"
	scene_path = "res://scenes/maps/valley.tscn"
	zone_radius = ValleyTerrain.RADIUS - 8.0
	menu_orbit = Vector3(70.0, 48.0, 4.0)
	podium = Vector3(-12.0, ValleyTerrain.surface(-12.0, -18.0), -18.0)
	# Strefa zamyka sie w okolo 9 minut, a pierwsze kolo zostawia czas na przejscie przez mape.
	zone_phases = [
		{ "wait": 90.0, "shrink": 60.0, "radius": 120.0, "damage": 2 },
		{ "wait": 70.0, "shrink": 50.0, "radius": 70.0, "damage": 3 },
		{ "wait": 55.0, "shrink": 40.0, "radius": 35.0, "damage": 5 },
		{ "wait": 40.0, "shrink": 35.0, "radius": 14.0, "damage": 8 },
		{ "wait": 25.0, "shrink": 30.0, "radius": 0.0, "damage": 12 },
	]
	places = []
	for entry in ValleyTerrain.PLACES:
		places.append({ "name": entry.name, "at": entry.at })


func surface(x: float, z: float) -> float:
	return ValleyTerrain.surface(x, z)


func ground_at(feet: Vector3) -> int:
	var floor_y := ValleyTerrain.surface(feet.x, feet.z)
	if feet.y - floor_y > 0.35:
		return ForestTerrain.Ground.STONE
	if floor_y < ValleyTerrain.WATER_LEVEL + 0.2:
		return ForestTerrain.Ground.WATER
	var quarry := ValleyTerrain.place("quarry")
	if ValleyTerrain.is_road(feet.x, feet.z) or Vector2(feet.x, feet.z).distance_to(quarry.at) < quarry.radius:
		return ForestTerrain.Ground.DIRT
	return ForestTerrain.Ground.GRASS
