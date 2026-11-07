class_name MapInfo
extends RefCounted
## Opis mapy: scena, granice, strefa, podloze pod stopami i miejsca z nazwami. Scena mapy ma wezly
## WorldEnvironment i Sun oraz punkty w grupach spawn_points i chest_spots. Nowa mape wystarczy
## opisac podklasa i dopisac w Maps.

## Trwaly identyfikator wysylany przez siec.
var id := ""
var title := ""
var scene_path := ""
## Strefa Battle Royale zaczyna sie od tego kola.
var zone_radius := 50.0
var zone_center := Vector2.ZERO
## Kamera menu krazy wokol srodka: promien, wysokosc i wysokosc punktu, na ktory patrzy.
var menu_orbit := Vector3(30.0, 22.0, 2.0)
## Miejsca z nazwami do mapki: { name, at: Vector2 }.
var places: Array[Dictionary] = []
## Fazy strefy: { wait, shrink, radius, damage }. Kazde kolo lezy w poprzednim.
var zone_phases: Array[Dictionary] = Zone.PHASES


## Wysokosc ziemi w danym miejscu, np. do stawiania skrzynek.
func surface(_x: float, _z: float) -> float:
	return 0.0


## Rodzaj podloza pod stopami, od ktorego zalezy dzwiek kroku.
func ground_at(_feet: Vector3) -> int:
	return ForestTerrain.Ground.CONCRETE
