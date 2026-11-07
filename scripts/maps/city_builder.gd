class_name CityBuilder
extends Node3D
## Zabawkowe miasteczko dla Deathmatchu, budowane kodem przy starcie. Kolizja powstaje takze na
## serwerze bez ekranu, a wyglad tylko tam, gdzie jest ekran. Uklad (x w prawo, z w dol mapy):
## glowna ulica wzdluz z (dluga linia pod AWP), poprzeczna ulica wzdluz x, dwa zaulki przy
## zachodniej i wschodniej krawedzi, czyli trzy rownolegle trasy. W rogach: kamienica i sklep (NW),
## plac z fontanna (NE), plac kontenerow z przejsciem pod kontenerem (SW) i hotel z garazem (SE).

const HALF := 35.0
const BORDER_HEIGHT := 40.0
const FLOOR_HEIGHT := 3.2
const WALL := 0.3
const SLAB := 0.25
const DOOR_WIDTH := 1.8
const DOOR_HEIGHT := 2.5
## Niskie przejscia: tylko w kucki (kapsula kucajacego ma 1,2 m).
const CRAWL_HEIGHT := 1.32

const ASPHALT := Color("5d6170")
const ASPHALT_DARK := Color("4f5262")
const SIDEWALK := Color("c9c2b6")
const LINE := Color("f4efe1")
const CONCRETE := Color("b8b2a7")
const ROOF := Color("8a8f9e")
const WOOD := Color("a8784e")
const GLASS := Color("8fd3f0")
const FACADES: Array[Color] = [Color("f28b82"), Color("fbbc5d"), Color("7cc6a4"), Color("7fa7ef"), Color("c39bea"), Color("f7a6c7"), Color("ffd479"), Color("8fd1d8")]
const CARS: Array[Color] = [Color("ef6f6c"), Color("2ec4b6"), Color("ffcb47"), Color("5b8def"), Color("9b7bff"), Color("f9a03f")]
const CONTAINERS: Array[Color] = [Color("e4572e"), Color("2f8f83"), Color("3a6ea5"), Color("f2a541")]

## Punkty startu i skrzynki: x, z, wysokosc podlogi.
const SPAWNS: Array[Vector3] = [
	Vector3(0.0, -33.0, 0.0), Vector3(0.0, 33.0, 0.0), Vector3(-33.0, 0.0, 0.0), Vector3(33.0, 0.0, 0.0),
	Vector3(-30.0, -32.0, 0.0), Vector3(30.0, -32.0, 0.0), Vector3(-30.0, 32.0, 0.0), Vector3(30.0, 32.0, 0.0),
	Vector3(12.0, -12.0, 0.0), Vector3(-9.0, -26.0, 0.0), Vector3(-12.0, 9.0, 0.0), Vector3(9.0, 26.0, 0.0),
	Vector3(-19.0, -24.0, FLOOR_HEIGHT), Vector3(18.0, 22.0, FLOOR_HEIGHT),
]
const CHESTS: Array[Vector3] = [
	Vector3(-16.0, -27.0, 0.0), Vector3(-20.5, -21.0, FLOOR_HEIGHT), Vector3(-20.0, -27.5, FLOOR_HEIGHT * 2.0),
	Vector3(-8.5, -11.0, 0.0), Vector3(12.0, -27.0, 0.0), Vector3(21.0, -9.0, 0.0),
	Vector3(-21.0, 18.0, 0.0), Vector3(-17.0, 32.0, 0.0), Vector3(-16.0, 13.0, 2.6),
	Vector3(15.0, 19.0, 0.0), Vector3(21.0, 25.0, FLOOR_HEIGHT), Vector3(14.5, 26.5, FLOOR_HEIGHT * 2.0),
	Vector3(30.0, 18.0, 0.0), Vector3(-30.0, -10.0, 0.0), Vector3(7.0, 8.0, 0.0),
]

var _headless := false
var _body: StaticBody3D
var _visuals: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_rng.seed = 7
	CityMapInfo.metal_boxes.clear()
	CityMapInfo.ladder_boxes.clear()
	_body = StaticBody3D.new()
	_body.name = "Blocks"
	_body.collision_layer = Hitscan.WORLD_MASK
	add_child(_body)
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_build_ground()
	_build_border()
	_build_streets()
	_build_tenement(Rect2(-25.0, -31.0, 12.0, 12.0))
	_build_shop(Rect2(-12.0, -15.0, 6.0, 7.0))
	_build_plaza(Vector2(16.0, -20.0))
	_build_container_yard()
	_build_hotel(Rect2(12.0, 16.0, 12.0, 12.0))
	_build_garage(Rect2(25.0, 6.5, 2.0, 9.0))
	_build_street_props()
	_build_climbing()
	_build_markers()
	if not _headless:
		add_child(CityAmbience.new())


# --- Klocki ------------------------------------------------------------------

## Prostopadloscian z kolizja i wygladem. "metal" daje metalowe kroki na jego dachu.
func _box(center: Vector3, size: Vector3, color: Color, collide := true, metal := false, rot_y := 0.0, bevel := 0.06) -> void:
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = center
		collision.rotation.y = rot_y
		_body.add_child(collision)
	if metal:
		CityMapInfo.metal_boxes.append(AABB(center - size * 0.5, size))
	if not _headless:
		var mesh := LowPoly.part(_visuals, LowPoly.box(size, bevel), color, center, Vector3(0.0, rad_to_deg(rot_y), 0.0))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size.y > 0.2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Sam wyglad, bez kolizji: pasy, okna, ozdoby.
func _decal(center: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> void:
	if not _headless:
		var mesh := LowPoly.part(_visuals, LowPoly.box(size, minf(0.02, size.y * 0.3)), color, center, Vector3(0.0, rad_to_deg(rot_y), 0.0))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Pochylnia od punktu "from" (dol) do "to" (gora). Gorna powierzchnia zaczyna sie na wysokosci "from.y".
func _ramp(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var run := Vector2(to.x - from.x, to.z - from.z)
	var rise := to.y - from.y
	var length := sqrt(run.length_squared() + rise * rise)
	var thickness := 0.3
	var angle := atan2(rise, run.length())
	var basis := Basis(Vector3.UP, atan2(-run.x, -run.y)) * Basis(Vector3.RIGHT, angle)
	var center := (from + to) * 0.5 + basis.y * (-thickness * 0.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, length)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(basis, center)
	_body.add_child(collision)
	if not _headless:
		var mesh := MeshInstance3D.new()
		mesh.mesh = LowPoly.box(shape.size, 0.04)
		mesh.material_override = LowPoly.material(color)
		mesh.transform = collision.transform
		_visuals.add_child(mesh)
		# Stopnie tylko jako wyglad, zeby kolizja zostala gladka.
		var steps := int(length / 0.35)
		for i in steps:
			var t := (i + 0.5) / steps
			var at := from.lerp(to, t) + Vector3.UP * 0.02
			var stripe := LowPoly.part(_visuals, LowPoly.box(Vector3(width * 0.96, 0.03, 0.06), 0.01), color.darkened(0.25), at)
			stripe.rotation = basis.get_euler()


## Sciana od a do b (w poziomie) z dziurami: kazda dziura to { at: odleglosc od a, width, bottom, top }.
func _wall(a: Vector2, b: Vector2, bottom: float, height: float, color: Color, holes: Array = []) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var rot := atan2(-dir.y, dir.x)
	var cuts := holes.duplicate()
	cuts.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.at < y.at)
	var start := 0.0
	for hole: Dictionary in cuts:
		var left: float = hole.at - hole.width * 0.5
		var right: float = hole.at + hole.width * 0.5
		_wall_piece(a, dir, rot, start, left, bottom, bottom + height, color)
		_wall_piece(a, dir, rot, left, right, bottom, bottom + hole.bottom, color)
		_wall_piece(a, dir, rot, left, right, bottom + hole.top, bottom + height, color)
		start = right
	_wall_piece(a, dir, rot, start, length, bottom, bottom + height, color)


func _wall_piece(a: Vector2, dir: Vector2, rot: float, from: float, to: float, y0: float, y1: float, color: Color) -> void:
	if to - from < 0.05 or y1 - y0 < 0.05:
		return
	var mid := a + dir * ((from + to) * 0.5)
	_box(Vector3(mid.x, (y0 + y1) * 0.5, mid.y), Vector3(to - from, y1 - y0, WALL), color, true, false, rot, 0.03)


## Plyta stropu z otworem na schody.
func _slab(rect: Rect2, y: float, hole: Rect2, color: Color) -> void:
	var parts: Array[Rect2] = []
	if hole.size == Vector2.ZERO:
		parts.append(rect)
	else:
		parts.append(Rect2(rect.position.x, rect.position.y, rect.size.x, hole.position.y - rect.position.y))
		parts.append(Rect2(rect.position.x, hole.end.y, rect.size.x, rect.end.y - hole.end.y))
		parts.append(Rect2(rect.position.x, hole.position.y, hole.position.x - rect.position.x, hole.size.y))
		parts.append(Rect2(hole.end.x, hole.position.y, rect.end.x - hole.end.x, hole.size.y))
	for part in parts:
		if part.size.x > 0.05 and part.size.y > 0.05:
			_box(Vector3(part.get_center().x, y - SLAB * 0.5, part.get_center().y), Vector3(part.size.x, SLAB, part.size.y), color, true, false, 0.0, 0.02)


## Swiecace okno albo neon: nie zalezy od swiatla, a na wysokiej jakosci lapie poswiate.
func _glow(center: Vector3, size: Vector3, color: Color) -> void:
	if not _headless:
		var mesh := MeshInstance3D.new()
		mesh.mesh = LowPoly.box(size, minf(0.02, size.y * 0.3))
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
		mesh.material_override = material
		mesh.position = center
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visuals.add_child(mesh)


func _window(at: Vector3, width: float, rot_y: float) -> void:
	_decal(at, Vector3(width, 1.0, 0.06), GLASS, rot_y)


# --- Teren i granice ---------------------------------------------------------

func _build_ground() -> void:
	_box(Vector3(0.0, -0.5, 0.0), Vector3(HALF * 2.0 + 20.0, 1.0, HALF * 2.0 + 20.0), ASPHALT, true, false, 0.0, 0.0)


## Niewidzialne sciany i kolorowe fasady tuz za nimi, wiec miasto wyglada na zamkniete.
func _build_border() -> void:
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var center := Vector3(side.x * (HALF + 0.5), BORDER_HEIGHT * 0.5, side.y * (HALF + 0.5))
		var size := Vector3(1.0 if side.x != 0.0 else HALF * 2.0 + 2.0, BORDER_HEIGHT, 1.0 if side.y != 0.0 else HALF * 2.0 + 2.0)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = center
		_body.add_child(collision)
	if _headless:
		return
	var index := 0
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var along := Vector2(-side.y, side.x)
		var at := -HALF - 2.0
		while at < HALF + 2.0:
			var width := _rng.randf_range(6.0, 9.0)
			var height := _rng.randf_range(8.0, 15.0)
			var depth := 6.0
			var mid := side * (HALF + 1.0 + depth * 0.5) + along * (at + width * 0.5)
			var color := FACADES[index % FACADES.size()]
			index += 1
			var size := Vector3(width if side.x == 0.0 else depth, height, depth if side.x == 0.0 else width)
			_decal(Vector3(mid.x, height * 0.5, mid.y), size, color)
			_decal(Vector3(mid.x, height + 0.25, mid.y), size * Vector3(1.04, 0.0, 1.04) + Vector3(0.0, 0.5, 0.0), color.darkened(0.2))
			# Okna na fasadzie od strony miasta.
			for floor_y in range(1, int(height / FLOOR_HEIGHT)):
				for w in range(1, int(width / 2.2)):
					var offset := -width * 0.5 + w * 2.2
					var front := side * (HALF + 0.98) + along * (at + width * 0.5 + offset)
					var window_size := Vector3(1.0 if side.x == 0.0 else 0.06, 1.1, 0.06 if side.x == 0.0 else 1.0)
					var window_at := Vector3(front.x, floor_y * FLOOR_HEIGHT - 0.4, front.y)
					# O zmierzchu czesc okien juz swieci.
					if _rng.randf() < 0.45:
						_glow(window_at, window_size, Color("ffd38a"))
					else:
						_decal(window_at, window_size, GLASS.darkened(0.25))
			at += width + 0.1


# --- Ulice -------------------------------------------------------------------

func _build_streets() -> void:
	# Chodniki jako malowane pasy, bez kraweznikow, o ktore gracz by sie potykal.
	for x: float in [-6.0, 6.0]:
		_decal(Vector3(x, 0.01, 0.0), Vector3(2.0, 0.02, HALF * 2.0), SIDEWALK)
	for z: float in [-6.0, 6.0]:
		_decal(Vector3(0.0, 0.012, z), Vector3(HALF * 2.0, 0.02, 2.0), SIDEWALK)
	for x: float in [-30.0, 30.0]:
		_decal(Vector3(x, 0.008, 0.0), Vector3(6.0, 0.02, HALF * 2.0), ASPHALT_DARK)
	for i in range(-16, 17):
		if absi(i) > 2:
			_decal(Vector3(0.0, 0.015, i * 2.0), Vector3(0.18, 0.02, 1.0), LINE)
			_decal(Vector3(i * 2.0, 0.015, 0.0), Vector3(1.0, 0.02, 0.18), LINE)
	# Przejscia dla pieszych przy skrzyzowaniu.
	for i in range(-4, 5):
		_decal(Vector3(i * 0.9, 0.016, -6.0), Vector3(0.5, 0.02, 2.4), LINE)
		_decal(Vector3(i * 0.9, 0.016, 6.0), Vector3(0.5, 0.02, 2.4), LINE)
		_decal(Vector3(-6.0, 0.016, i * 0.9), Vector3(2.4, 0.02, 0.5), LINE)
		_decal(Vector3(6.0, 0.016, i * 0.9), Vector3(2.4, 0.02, 0.5), LINE)


# --- Budynki -----------------------------------------------------------------

## Kamienica: dwa pietra, wejscia od ulicy i od podworza, schody w srodku i wyjscie na dach.
func _build_tenement(rect: Rect2) -> void:
	var color := FACADES[0]
	_building_shell(rect, color, 2, [
		{ "side": "east", "at": 4.0 }, { "side": "south", "at": 8.0 }, { "side": "north", "at": 3.0 },
	])
	# Schody na pietro wzdluz zachodniej sciany, a na dach wzdluz wschodniej.
	var x0 := rect.position.x
	var z0 := rect.position.y
	_ramp(Vector3(x0 + 1.2, 0.0, z0 + 10.6), Vector3(x0 + 1.2, FLOOR_HEIGHT, z0 + 4.8), 1.6, WOOD)
	_ramp(Vector3(rect.end.x - 1.2, FLOOR_HEIGHT, z0 + 10.6), Vector3(rect.end.x - 1.2, FLOOR_HEIGHT * 2.0, z0 + 4.8), 1.6, WOOD)
	_slab(rect.grow(-WALL * 0.5), FLOOR_HEIGHT, Rect2(x0 + 0.2, z0 + 4.6, 2.2, 6.2), CONCRETE.lightened(0.2))
	_slab(rect.grow(-WALL * 0.5), FLOOR_HEIGHT * 2.0, Rect2(rect.end.x - 2.4, z0 + 4.6, 2.2, 6.2), ROOF)
	# Barierka przy otworze schodow, zeby nie wpadac przypadkiem.
	_box(Vector3(x0 + 1.3, FLOOR_HEIGHT + 0.5, z0 + 11.0), Vector3(2.2, 1.0, 0.12), WOOD.darkened(0.2))
	_box(Vector3(rect.end.x - 1.3, FLOOR_HEIGHT * 2.0 + 0.5, z0 + 11.0), Vector3(2.2, 1.0, 0.12), WOOD.darkened(0.2))
	_parapet(rect, FLOOR_HEIGHT * 2.0, color)
	# Meble jako oslony w srodku.
	_box(Vector3(x0 + 7.0, 0.5, z0 + 7.0), Vector3(2.4, 1.0, 1.2), WOOD)
	_box(Vector3(x0 + 5.0, FLOOR_HEIGHT + 0.6, z0 + 3.0), Vector3(1.0, 1.2, 2.4), WOOD.lightened(0.1))
	_box(Vector3(x0 + 8.0, FLOOR_HEIGHT * 2.0 + 0.6, z0 + 8.0), Vector3(1.6, 1.2, 1.6), Color("7d8597"), true, true)
	_glow(Vector3(rect.get_center().x, FLOOR_HEIGHT * 2.0 + 1.6, z0 - 0.2), Vector3(5.0, 0.9, 0.1), Color("ff5fa2"))


## Sklep: jedno pietro, duza witryna, dach dostepny po schodach z tylu.
func _build_shop(rect: Rect2) -> void:
	var color := FACADES[1]
	_building_shell(rect, color, 1, [{ "side": "east", "at": 3.5 }, { "side": "west", "at": 3.5 }])
	_slab(rect.grow(-WALL * 0.5), FLOOR_HEIGHT, Rect2(), ROOF)
	_parapet(rect, FLOOR_HEIGHT, color, ["south"])
	_ramp(Vector3(rect.position.x + 1.0, 0.0, rect.end.y + 5.2), Vector3(rect.position.x + 1.0, FLOOR_HEIGHT, rect.end.y + 0.1), 1.4, CONCRETE)
	_box(Vector3(rect.position.x + 3.0, 0.5, rect.position.y + 2.0), Vector3(2.8, 1.0, 0.8), Color("e9edf3"))
	# Markiza nad wejsciem.
	_decal(Vector3(rect.end.x + 0.6, 2.7, rect.position.y + 3.5), Vector3(1.2, 0.15, 3.2), Color("ef6f6c"))
	_glow(Vector3(rect.end.x + 0.18, 2.3, rect.position.y + 3.5), Vector3(0.06, 0.5, 2.4), Color("a6ff6e"))


## Hotel: dwa pietra, wejscie od glownej ulicy, taras na dachu.
func _build_hotel(rect: Rect2) -> void:
	var color := FACADES[3]
	_building_shell(rect, color, 2, [
		{ "side": "west", "at": 6.0 }, { "side": "north", "at": 9.0 }, { "side": "south", "at": 2.5 },
	])
	var x0 := rect.position.x
	var z0 := rect.position.y
	_ramp(Vector3(rect.end.x - 1.2, 0.0, z0 + 1.4), Vector3(rect.end.x - 1.2, FLOOR_HEIGHT, z0 + 7.2), 1.6, WOOD)
	_ramp(Vector3(x0 + 1.2, FLOOR_HEIGHT, z0 + 1.4), Vector3(x0 + 1.2, FLOOR_HEIGHT * 2.0, z0 + 7.2), 1.6, WOOD)
	_slab(rect.grow(-WALL * 0.5), FLOOR_HEIGHT, Rect2(rect.end.x - 2.4, z0 + 1.2, 2.2, 6.2), CONCRETE.lightened(0.2))
	_slab(rect.grow(-WALL * 0.5), FLOOR_HEIGHT * 2.0, Rect2(x0 + 0.2, z0 + 1.2, 2.2, 6.2), ROOF)
	_box(Vector3(rect.end.x - 1.3, FLOOR_HEIGHT + 0.5, z0 + 1.0), Vector3(2.2, 1.0, 0.12), WOOD.darkened(0.2))
	_box(Vector3(x0 + 1.3, FLOOR_HEIGHT * 2.0 + 0.5, z0 + 1.0), Vector3(2.2, 1.0, 0.12), WOOD.darkened(0.2))
	_parapet(rect, FLOOR_HEIGHT * 2.0, color)
	_box(Vector3(x0 + 6.0, 0.55, z0 + 8.5), Vector3(3.0, 1.1, 1.0), Color("f3e9d2"))
	_box(Vector3(x0 + 5.0, FLOOR_HEIGHT + 0.5, z0 + 9.0), Vector3(2.0, 1.0, 2.0), Color("e8a0b4"))
	_box(Vector3(x0 + 5.0, FLOOR_HEIGHT * 2.0 + 0.7, z0 + 8.0), Vector3(1.2, 1.4, 1.2), Color("7d8597"), true, true)
	_glow(Vector3(x0 - 0.2, FLOOR_HEIGHT * 2.0 + 1.6, rect.get_center().y), Vector3(0.1, 0.9, 5.0), Color("4fe3ff"))


## Garaz z przymknieta brama: przejscie z ulicy do wschodniego zaulka tylko w kucki.
func _build_garage(rect: Rect2) -> void:
	var color := FACADES[6]
	var x0 := rect.position.x
	var z0 := rect.position.y
	_wall(Vector2(x0, z0), Vector2(rect.end.x, z0), 0.0, 3.0, color)
	_wall(Vector2(x0, rect.end.y), Vector2(rect.end.x, rect.end.y), 0.0, 3.0, color)
	_box(Vector3(rect.get_center().x, 3.1, rect.get_center().y), Vector3(rect.size.x + 0.4, 0.3, rect.size.y + 0.4), ROOF)
	# Brama od strony ulicy jest opuszczona do 1,32 m nad ziemia, a od zaulka otwarta.
	_box(Vector3(x0, (CRAWL_HEIGHT + 3.0) * 0.5, rect.get_center().y), Vector3(WALL, 3.0 - CRAWL_HEIGHT, rect.size.y), Color("9aa3b5"), true, true)
	for i in 5:
		_decal(Vector3(x0 - 0.17, CRAWL_HEIGHT + 0.2 + i * 0.32, rect.get_center().y), Vector3(0.04, 0.06, rect.size.y * 0.96), Color("7d8597"))


## Skorupa budynku: sciany z drzwiami na parterze i oknami na pietrach.
func _building_shell(rect: Rect2, color: Color, floors: int, doors: Array) -> void:
	var corners := {
		"north": [Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)],
		"south": [Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y)],
		"west": [Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.end.y)],
		"east": [Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y)],
	}
	for side: String in corners:
		var a: Vector2 = corners[side][0]
		var b: Vector2 = corners[side][1]
		var length := a.distance_to(b)
		for level in floors:
			var holes := []
			if level == 0:
				for door: Dictionary in doors:
					if door.side == side:
						holes.append({ "at": door.at, "width": DOOR_WIDTH, "bottom": 0.0, "top": DOOR_HEIGHT })
			else:
				var count := int(length / 3.0)
				for w in count:
					holes.append({ "at": (w + 0.5) * length / count, "width": 1.2, "bottom": 1.0, "top": 2.1 })
			_wall(a, b, level * FLOOR_HEIGHT, FLOOR_HEIGHT, color if level % 2 == 0 else color.lightened(0.1), holes)
		# Pas miedzy pietrami jako ozdoba.
		if floors > 1:
			var mid := (a + b) * 0.5
			var horizontal := side == "north" or side == "south"
			_decal(Vector3(mid.x, FLOOR_HEIGHT, mid.y), Vector3(length + 0.3 if horizontal else 0.45, 0.2, 0.45 if horizontal else length + 0.3), color.darkened(0.2))


## Murek na krawedzi dachu. Zatrzymuje przed spadnieciem i daje oslone.
func _parapet(rect: Rect2, y: float, color: Color, skip: Array = []) -> void:
	var height := 0.9
	for side: String in ["north", "south", "west", "east"]:
		if skip.has(side):
			continue
		match side:
			"north":
				_box(Vector3(rect.get_center().x, y + height * 0.5, rect.position.y), Vector3(rect.size.x + WALL, height, WALL), color.darkened(0.15))
			"south":
				_box(Vector3(rect.get_center().x, y + height * 0.5, rect.end.y), Vector3(rect.size.x + WALL, height, WALL), color.darkened(0.15))
			"west":
				_box(Vector3(rect.position.x, y + height * 0.5, rect.get_center().y), Vector3(WALL, height, rect.size.y), color.darkened(0.15))
			"east":
				_box(Vector3(rect.end.x, y + height * 0.5, rect.get_center().y), Vector3(WALL, height, rect.size.y), color.darkened(0.15))


# --- Plac, kontenery i rekwizyty ---------------------------------------------

## Plac z fontanna, lawkami i murkami donic. Duzo oslon na srednim dystansie.
func _build_plaza(center: Vector2) -> void:
	_decal(Vector3(center.x, 0.02, center.y), Vector3(18.0, 0.02, 18.0), Color("e0d6c3"))
	for i in 8:
		var angle := TAU * i / 8.0
		var at := center + Vector2.from_angle(angle) * 2.8
		_box(Vector3(at.x, 0.45, at.y), Vector3(2.4, 0.9, 0.5), Color("d9d2c3"), true, false, -angle + PI * 0.5)
	_box(Vector3(center.x, 1.1, center.y), Vector3(1.0, 2.2, 1.0), Color("bfe3f0"))
	_decal(Vector3(center.x, 0.5, center.y), Vector3(4.6, 0.1, 4.6), Color("6fc3e8"))
	_decal(Vector3(center.x, 2.4, center.y), Vector3(1.8, 0.3, 1.8), Color("bfe3f0"))
	for offset: Vector2 in [Vector2(-7.0, -6.0), Vector2(7.0, -6.0), Vector2(-7.0, 6.0), Vector2(7.0, 6.0)]:
		var at := center + offset
		_box(Vector3(at.x, 0.5, at.y), Vector3(2.6, 1.0, 2.6), Color("c2a27c"))
		_tree(Vector3(at.x, 1.0, at.y))
	for offset: Vector2 in [Vector2(0.0, -7.5), Vector2(0.0, 7.5)]:
		var at := center + offset
		_box(Vector3(at.x, 0.35, at.y), Vector3(3.0, 0.7, 0.6), WOOD)
	# Kiosk na rogu placu.
	_box(Vector3(center.x + 7.5, 1.3, center.y + 0.5), Vector3(2.2, 2.6, 2.2), Color("ffcb47"))
	_box(Vector3(center.x + 7.5, 2.75, center.y + 0.5), Vector3(2.8, 0.3, 2.8), Color("ef6f6c"))


## Plac kontenerow: stosy, wozek i kontener na podporach, pod ktorym przejdzie sie tylko w kucki.
func _build_container_yard() -> void:
	_decal(Vector3(-16.0, 0.02, 21.0), Vector3(21.0, 0.02, 29.0), Color("8a8577"))
	_container(Vector3(-23.0, 0.0, 12.0), 0.0, 0)
	_container(Vector3(-23.0, 2.6, 12.0), 0.0, 1)
	_container(Vector3(-16.0, 0.0, 13.0), 0.0, 2)
	_container(Vector3(-22.0, 0.0, 28.0), PI * 0.5, 3)
	_container(Vector3(-10.0, 0.0, 30.0), 0.0, 1)
	_container(Vector3(-9.0, 0.0, 20.0), PI * 0.5, 0)
	# Pochylnia ze skrzyn na dach kontenera, skad widac caly plac.
	_ramp(Vector3(-16.0, 0.0, 18.4), Vector3(-16.0, 2.6, 14.3), 1.4, WOOD)
	# Kontener na podporach: przerwa 1,32 m nad ziemia, a z bokow murki, zeby przejscie bylo tylko pod nim.
	var bridge := Vector3(-19.0, CRAWL_HEIGHT, 22.0)
	_container(bridge, 0.0, 2)
	for x: float in [-21.7, -16.3]:
		for z: float in [21.0, 23.0]:
			_box(Vector3(x, CRAWL_HEIGHT * 0.5, z), Vector3(0.3, CRAWL_HEIGHT, 0.3), Color("4a4f5c"), true, true)
	_box(Vector3(-25.5, 0.6, 22.0), Vector3(7.0, 1.2, 0.4), CONCRETE)
	_box(Vector3(-12.6, 0.6, 22.0), Vector3(7.0, 1.2, 0.4), CONCRETE)
	_box(Vector3(-25.5, 2.0, 22.0), Vector3(7.0, 1.6, 0.25), Color("9aa3b5"), true, true)
	_box(Vector3(-12.6, 2.0, 22.0), Vector3(7.0, 1.6, 0.25), Color("9aa3b5"), true, true)
	for z: float in [16.5, 26.0, 33.0]:
		_box(Vector3(-13.0, 0.5, z), Vector3(1.0, 1.0, 1.0), WOOD)
	_box(Vector3(-13.0, 1.5, 16.5), Vector3(1.0, 1.0, 1.0), WOOD.lightened(0.1))


func _container(base: Vector3, rot_y: float, color_index: int) -> void:
	var size := Vector3(6.0, 2.6, 2.4)
	var center := base + Vector3.UP * size.y * 0.5
	var color := CONTAINERS[color_index % CONTAINERS.size()]
	var shape_size := size if is_zero_approx(fmod(rot_y, PI)) else Vector3(size.z, size.y, size.x)
	_box(center, shape_size, color, true, true, 0.0, 0.05)
	if _headless:
		return
	var long_axis := Vector3.RIGHT if is_zero_approx(fmod(rot_y, PI)) else Vector3.BACK
	for i in range(-5, 6):
		var rib := center + long_axis * (i * 0.52)
		var rib_size := Vector3(0.08, size.y * 0.92, shape_size.z + 0.04) if long_axis == Vector3.RIGHT else Vector3(shape_size.x + 0.04, size.y * 0.92, 0.08)
		_decal(rib, rib_size, color.darkened(0.18))


func _tree(base: Vector3) -> void:
	if _headless:
		return
	LowPoly.part(_visuals, LowPoly.cylinder(0.12, 0.16, 1.6, 6), Color("8b5a3c"), base + Vector3.UP * 0.8)
	LowPoly.part(_visuals, LowPoly.ball(1.0, 7, 5), Color("6fbf5f"), base + Vector3.UP * 2.1)


## Auta, latarnie, murki i lawki przy ulicach. Auta stoja przy krawedziach, zeby ulica zostala otwarta.
func _build_street_props() -> void:
	var cars: Array[Array] = [
		[Vector3(-3.6, 0.0, -24.0), 0.0], [Vector3(3.6, 0.0, -14.0), PI], [Vector3(-3.6, 0.0, 15.0), 0.0],
		[Vector3(3.6, 0.0, 27.0), PI], [Vector3(-16.0, 0.0, 3.6), PI * 0.5], [Vector3(14.0, 0.0, -3.6), -PI * 0.5],
		[Vector3(25.0, 0.0, 3.4), PI * 0.5], [Vector3(-30.5, 0.0, -20.0), 0.2], [Vector3(30.0, 0.0, -24.0), -0.15],
		[Vector3(-30.0, 0.0, 6.0), 0.0],
	]
	var index := 0
	for car: Array in cars:
		_car(car[0], car[1], CARS[index % CARS.size()])
		index += 1
	# Murki i barierki jako niskie oslony.
	for wall: Array in [
		[Vector3(-30.0, 0.5, -3.0), Vector3(4.0, 1.0, 0.4)], [Vector3(30.0, 0.5, 12.0), Vector3(4.0, 1.0, 0.4)],
		[Vector3(9.0, 0.5, -9.0), Vector3(0.4, 1.0, 4.0)], [Vector3(-9.0, 0.5, 9.0), Vector3(0.4, 1.0, 4.0)],
		[Vector3(9.0, 0.5, 33.0), Vector3(4.0, 1.0, 0.4)], [Vector3(-26.5, 0.5, -12.0), Vector3(0.4, 1.0, 5.0)],
		[Vector3(26.5, 0.5, -10.0), Vector3(0.4, 1.0, 6.0)],
	]:
		_box(wall[0], wall[1], CONCRETE)
	# Zaulki: smietniki i skrzynie.
	for at: Vector3 in [Vector3(-32.0, 0.6, -14.0), Vector3(-28.0, 0.6, 26.0), Vector3(32.0, 0.6, -6.0), Vector3(28.5, 0.6, 30.0)]:
		_box(at, Vector3(1.6, 1.2, 1.0), Color("3f8f5a"), true, true)
	for z in range(-30, 31, 12):
		_lamp(Vector3(-5.6, 0.0, z))
		_lamp(Vector3(5.6, 0.0, z + 6))
	# Przystanek autobusowy przy glownej ulicy.
	_box(Vector3(6.4, 1.2, -26.0), Vector3(0.12, 2.4, 3.0), GLASS)
	_box(Vector3(5.9, 2.45, -26.0), Vector3(1.4, 0.12, 3.2), Color("5b8def"))
	_box(Vector3(6.1, 0.25, -26.0), Vector3(0.5, 0.5, 2.6), WOOD)


func _car(base: Vector3, rot_y: float, color: Color) -> void:
	var forward := Vector3(-sin(rot_y), 0.0, -cos(rot_y))
	_box(base + Vector3.UP * 0.6, Vector3(1.8, 0.8, 4.0), color, true, true, rot_y, 0.14)
	_box(base + Vector3.UP * 1.3 - forward * 0.2, Vector3(1.6, 0.65, 2.2), color.lightened(0.15), true, true, rot_y, 0.12)
	if _headless:
		return
	_decal(base + Vector3.UP * 1.32 - forward * 0.2, Vector3(1.64, 0.4, 2.0), GLASS, rot_y)
	var side := forward.cross(Vector3.UP)
	for f: float in [-1.3, 1.3]:
		for s: float in [-0.85, 0.85]:
			var wheel := LowPoly.part(_visuals, LowPoly.cylinder(0.33, 0.33, 0.25, 8), Color("2d2a36"), base + forward * f + side * s + Vector3.UP * 0.33)
			wheel.rotation = Vector3(0.0, rot_y, PI * 0.5)
	_decal(base + Vector3.UP * 0.75 + forward * 2.0, Vector3(1.2, 0.18, 0.05), Color("fff3a3"), rot_y)


func _lamp(base: Vector3) -> void:
	_box(base + Vector3.UP * 2.2, Vector3(0.16, 4.4, 0.16), Color("4a4f5c"), true, false, 0.0, 0.03)
	_glow(base + Vector3.UP * 4.45, Vector3(0.7, 0.18, 0.35), Color("ffe9a8"))


# --- Drabiny, rury i skoki -----------------------------------------------------

## Dodatkowe trasy na dachy: drabiny na scianach, rura na sklepie i skrzynie do wskoczenia na kontener.
func _build_climbing() -> void:
	_ladder(Vector3(-25.3, 0.0, -24.0), Vector3.LEFT, FLOOR_HEIGHT * 2.0 + 1.0)
	_ladder(Vector3(20.0, 0.0, 28.3), Vector3.BACK, FLOOR_HEIGHT * 2.0 + 1.0)
	_ladder(Vector3(-23.0, 0.0, 13.3), Vector3.BACK, 5.2)
	_pipe(Vector3(-5.85, 0.0, -14.2), FLOOR_HEIGHT + 1.0)
	_box(Vector3(-11.2, 0.5, 21.6), Vector3(1.0, 1.0, 1.0), WOOD)
	_box(Vector3(-11.2, 1.0, 20.4), Vector3(1.0, 2.0, 1.0), WOOD.lightened(0.1))


## Drabina przy scianie. "facing" wskazuje od sciany na zewnatrz, a bryla wspinaczki lezy przed nia.
func _ladder(base: Vector3, facing: Vector3, height: float) -> void:
	var side := facing.cross(Vector3.UP)
	var volume_center := base + facing * 0.35 + Vector3.UP * (height * 0.5 + 0.2)
	var extent := side.abs() * 0.9 + facing.abs() * 0.7 + Vector3.UP * (height + 0.4)
	CityMapInfo.ladder_boxes.append(AABB(volume_center - extent * 0.5, extent))
	if _headless:
		return
	for sign_s: float in [-1.0, 1.0]:
		_decal(base + side * sign_s * 0.32 + facing * 0.08 + Vector3.UP * height * 0.5, Vector3(0.07, height, 0.07) if side.x == 0.0 else Vector3(0.07, height, 0.07), Color("e4572e"))
	var rungs := int(height / 0.35)
	for i in rungs:
		var rung := LowPoly.part(_visuals, LowPoly.box(Vector3(0.64, 0.05, 0.05) if absf(side.x) > 0.5 else Vector3(0.05, 0.05, 0.64), 0.01), Color("ffcb47"), base + facing * 0.08 + Vector3.UP * (0.3 + i * 0.35))
		rung.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Rura spustowa, po ktorej tez da sie wejsc.
func _pipe(base: Vector3, height: float) -> void:
	CityMapInfo.ladder_boxes.append(AABB(base + Vector3(-0.45, 0.2, -0.45), Vector3(0.9, height + 0.4, 0.9)))
	if not _headless:
		LowPoly.part(_visuals, LowPoly.cylinder(0.09, 0.09, height, 8), Color("9aa3b5"), base + Vector3.UP * height * 0.5)


# --- Punkty ------------------------------------------------------------------

func _build_markers() -> void:
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	add_child(spawns)
	for i in SPAWNS.size():
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = Vector3(SPAWNS[i].x, SPAWNS[i].z + 0.2, SPAWNS[i].y)
		marker.add_to_group(&"spawn_points")
		spawns.add_child(marker)
	var chests := Node3D.new()
	chests.name = "ChestSpots"
	add_child(chests)
	for i in CHESTS.size():
		var marker := Marker3D.new()
		marker.name = "Chest%d" % (i + 1)
		marker.position = Vector3(CHESTS[i].x, CHESTS[i].z, CHESTS[i].y)
		# Skrzynka stoi bokiem do najblizszej ulicy, zeby bylo widac jej front.
		marker.rotation.y = atan2(-CHESTS[i].x, -CHESTS[i].y)
		marker.add_to_group(&"chest_spots")
		chests.add_child(marker)
