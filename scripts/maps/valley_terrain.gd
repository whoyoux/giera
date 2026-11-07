class_name ValleyTerrain
extends RefCounted
## Wzor terenu duzej doliny dla Battle Royale. Wysokosc wynika tylko ze wspolrzednych, wiec
## serwer i klienci licza ten sam teren. Miejsca maja swoje splaszczenia, a jezioro i kamieniolom
## sa zaglebieniami.

## Promien grywalnego kola i rozmiar siatki terenu.
const RADIUS := 200.0
const HALF := 224.0
const CELL := 2.0
const WATER_LEVEL := -0.6
const RIM_START := 196.0
const RIM_HEIGHT := 18.0

## Miejsca z nazwami: srodek, promien splaszczenia i wysokosc, do ktorej teren sie wyrownuje.
const PLACES: Array[Dictionary] = [
	{ "key": "ruins", "name": "Stare ruiny", "at": Vector2(-12.0, -18.0), "radius": 26.0, "height": 1.5 },
	{ "key": "village", "name": "Wioska", "at": Vector2(-105.0, 70.0), "radius": 34.0, "height": 0.8 },
	{ "key": "farm", "name": "Gospodarstwo", "at": Vector2(110.0, 85.0), "radius": 36.0, "height": 1.2 },
	{ "key": "quarry", "name": "Kamieniołom", "at": Vector2(115.0, -95.0), "radius": 30.0, "height": -5.0 },
	{ "key": "lake", "name": "Jezioro", "at": Vector2(-95.0, -85.0), "radius": 34.0, "height": -2.2 },
	{ "key": "camp", "name": "Obóz na wzgórzu", "at": Vector2(10.0, 140.0), "radius": 20.0, "height": 11.0 },
]
## Drogi miedzy miejscami: pary kluczy miejsc.
const ROADS: Array[Array] = [
	["ruins", "village"], ["ruins", "farm"], ["ruins", "quarry"], ["ruins", "lake"], ["ruins", "camp"],
	["village", "lake"], ["farm", "camp"], ["quarry", "farm"],
]
const ROAD_WIDTH := 3.2


static func place(key: String) -> Dictionary:
	for entry in PLACES:
		if entry.key == key:
			return entry
	return {}


## Wysokosc terenu w dowolnym punkcie.
static func height(x: float, z: float) -> float:
	var y := sin(x * 0.031 + 0.4) * cos(z * 0.027 - 1.1) * 3.2
	y += sin(x * 0.011 - z * 0.013 + 2.0) * 4.0
	y += sin(x * 0.083 + z * 0.061) * 0.6
	# Wzgorze pod obozem na polnocy.
	var camp := Vector2(x, z).distance_to(place("camp").at)
	y += 10.0 * exp(-pow(camp / 38.0, 2.0))
	for entry in PLACES:
		var distance := Vector2(x, z).distance_to(entry.at)
		var blend := 1.0 - smoothstep(entry.radius * 0.7, entry.radius * 1.25, distance)
		if entry.key == "lake":
			# Jezioro jest plytkie, zeby przejsc je w brod, a gleboko robi sie tylko na srodku.
			var bowl := -1.0 - 1.6 * (1.0 - smoothstep(0.0, entry.radius, distance))
			y = lerpf(y, bowl, 1.0 - smoothstep(entry.radius * 0.9, entry.radius * 1.3, distance))
		elif entry.key == "quarry":
			# Kamieniolom to dol z lagodnymi scianami, zeby dalo sie wejsc i wyjsc.
			var pit := lerpf(entry.height, 2.0, smoothstep(entry.radius * 0.45, entry.radius * 1.05, distance))
			y = lerpf(y, pit, 1.0 - smoothstep(entry.radius * 0.95, entry.radius * 1.35, distance))
		else:
			y = lerpf(y, entry.height, blend)
	var road := road_distance(x, z)
	if road < ROAD_WIDTH * 2.0:
		y = lerpf(y, y * 0.85, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH * 2.0, road))
	var edge := Vector2(x, z).length()
	y += RIM_HEIGHT * smoothstep(RIM_START, HALF, edge)
	return y


## Odleglosc od najblizszej drogi.
static func road_distance(x: float, z: float) -> float:
	var best := INF
	var point := Vector2(x, z)
	for road in ROADS:
		var a: Vector2 = place(road[0]).at
		var b: Vector2 = place(road[1]).at
		var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		# Droga lekko sie wije, zeby nie wygladala jak od linijki.
		var bend := (b - a).orthogonal().normalized() * sin(t * PI * 2.0) * 6.0 * sin(t * PI)
		best = minf(best, point.distance_to(a.lerp(b, t) + bend))
	return best


static func is_road(x: float, z: float) -> bool:
	return road_distance(x, z) < ROAD_WIDTH


## Wysokosc na trojkatach siatki, tak samo jak w kolizji z HeightMapShape3D.
static func surface(x: float, z: float) -> float:
	var gx := (x + HALF) / CELL
	var gz := (z + HALF) / CELL
	var cx := floorf(gx)
	var cz := floorf(gz)
	var u := gx - cx
	var v := gz - cz
	var x0 := cx * CELL - HALF
	var z0 := cz * CELL - HALF
	var h00 := height(x0, z0)
	var h10 := height(x0 + CELL, z0)
	var h01 := height(x0, z0 + CELL)
	var h11 := height(x0 + CELL, z0 + CELL)
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)
