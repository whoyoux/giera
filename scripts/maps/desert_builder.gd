class_name DesertBuilder
extends CityBuilder
## Pustynia dla Deathmatchu i Team Deathmatchu, okolo 130 x 130 m, budowana kodem przy starcie.
## Korzysta z klockow miasteczka (sciany, plyty, pochylnie, drabiny), ale ma wlasny uklad.
## Uklad (x w prawo, z w dol mapy): na polnocy stacja kolejki z wagonami (baza Kaktusow), na poludniu
## gliniana twierdza (baza Zuczkow). Srodek przecinaja trzy trasy: na zachodzie kanion z mostem
## linowym miedzy dwoma plaskowyzami, posrodku targ z placiennymi daszkami, a na wschodzie oaza z palmami.
## Miedzy targiem a twierdza leza wydmy z wrakiem ciezarowki. Brzeg mapy to skaly kanionu.

const DESERT_HALF := 65.0
const SAND := Color("f0c07c")
const SAND_DARK := Color("e3b26f")
const SAND_LIGHT := Color("f8dca6")
const ROCK: Array[Color] = [Color("d9824f"), Color("c96f45"), Color("e79a62"), Color("b9603e")]
const MUD := Color("d9a46c")
const MUD_DARK := Color("b98552")
const CANVAS: Array[Color] = [Color("ef6f6c"), Color("2ec4b6"), Color("ffcb47"), Color("9b7bff"), Color("f78fb3"), Color("5b8def")]
const PALM_TRUNK := Color("a8784e")
const PALM_LEAF := Color("5fbf6a")
const WATER := Color("4fc3e8")
const RAIL := Color("6b6e7a")
const WAGONS: Array[Color] = [Color("e4572e"), Color("3a6ea5"), Color("2f8f83"), Color("f2a541")]
## Wysokosc plaskowyzow kanionu i mostu miedzy nimi.
const MESA_HEIGHT := 5.0
## Wieze twierdzy sa wyzsze od murow, zeby z tarasu bylo widac nad nimi.
const TOWER_HEIGHT := 5.0
## Oaza: srodek i promien sadzawki. Kroki w niej chlupia.
const POND_CENTER := Vector2(42.0, 2.0)
const POND_RADIUS := 6.5

## Punkty startu Team Deathmatchu: x, z, wysokosc podlogi. Kaktusy na stacji, Zuczki w twierdzy.
const TEAM_SPAWNS: Array[Array] = [
	[
		Vector3(-18.0, -52.0, 0.0), Vector3(-10.0, -51.0, 0.0), Vector3(-2.0, -52.0, 0.0), Vector3(6.0, -51.0, 0.0),
		Vector3(14.0, -52.0, 0.0), Vector3(22.0, -50.0, 0.0), Vector3(-26.0, -50.0, 0.0), Vector3(30.0, -51.0, 0.0),
		Vector3(-34.0, -52.0, 0.0), Vector3(38.0, -50.0, 0.0),
	],
	[
		Vector3(-14.0, 49.0, 0.0), Vector3(-6.0, 51.0, 0.0), Vector3(2.0, 49.0, 0.0), Vector3(10.0, 51.0, 0.0),
		Vector3(-10.0, 55.0, 0.0), Vector3(8.0, 55.0, 0.0), Vector3(-30.0, 50.0, 0.0), Vector3(30.0, 50.0, 0.0),
		Vector3(-38.0, 53.0, 0.0), Vector3(38.0, 54.0, 0.0),
	],
]
## Dodatkowe punkty Deathmatchu rozlozone po calej mapie. W Team Deathmatchu nie sa uzywane.
const FREE_SPAWNS: Array[Vector3] = [
	Vector3(-40.0, -16.0, 0.0), Vector3(-40.0, 16.0, 0.0), Vector3(34.0, -14.0, 0.0), Vector3(52.0, 14.0, 0.0),
	Vector3(-17.0, -9.0, 0.0), Vector3(17.0, 9.0, 0.0), Vector3(30.0, 36.0, 0.0), Vector3(-18.0, -30.0, 0.0),
	Vector3(18.0, -30.0, 0.0), Vector3(-20.0, 39.0, 0.0), Vector3(-54.0, 0.0, MESA_HEIGHT), Vector3(54.0, -36.0, 0.0),
]
const DESERT_CHESTS: Array[Vector3] = [
	Vector3(0.0, -58.0, 0.0), Vector3(30.0, -58.0, 6.0), Vector3(-24.0, -44.0, 0.0),
	Vector3(0.0, 58.0, 0.0), Vector3(-17.0, 45.0, 0.0), Vector3(21.0, 46.5, 5.13),
	Vector3(-6.0, 4.0, 0.0), Vector3(8.0, -4.0, 5.13), Vector3(-3.0, -10.0, 0.0),
	Vector3(-40.0, 0.0, 0.0), Vector3(-54.0, -18.0, MESA_HEIGHT), Vector3(-29.0, 18.0, MESA_HEIGHT),
	Vector3(46.0, -10.0, 0.0), Vector3(32.0, 12.0, 0.0), Vector3(22.0, 30.0, 0.0), Vector3(-30.0, 36.0, 0.0),
]

var _scatter_lists := {}


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_rng.seed = 23
	CityMapInfo.metal_boxes.clear()
	CityMapInfo.ladder_boxes.clear()
	_body = StaticBody3D.new()
	_body.name = "Blocks"
	_body.collision_layer = Hitscan.WORLD_MASK
	add_child(_body)
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_build_sand()
	_build_canyon_rim()
	_build_station()
	_build_fort()
	_build_market()
	_build_canyon()
	_build_oasis()
	_build_dunes()
	_build_cover()
	_build_scatter()
	_build_desert_markers()
	if not _headless:
		add_child(DesertAmbience.new())


# --- Piasek i brzeg ----------------------------------------------------------

func _build_sand() -> void:
	_box(Vector3(0.0, -0.5, 0.0), Vector3(DESERT_HALF * 2.0 + 40.0, 1.0, DESERT_HALF * 2.0 + 40.0), SAND, true, false, 0.0, 0.0)
	if _headless:
		return
	# Jasniejsze i ciemniejsze lachy piasku, zeby rownina nie byla jednolita.
	for i in 26:
		var at := Vector2(_rng.randf_range(-58.0, 58.0), _rng.randf_range(-58.0, 58.0))
		var size := Vector3(_rng.randf_range(6.0, 16.0), 0.02, _rng.randf_range(4.0, 12.0))
		_decal(Vector3(at.x, 0.01 + i * 0.0004, at.y), size, SAND_DARK if i % 2 == 0 else SAND_LIGHT, _rng.randf() * TAU)


## Niewidzialne sciany na granicy i skaly kanionu tuz za nia, wiec koniec mapy wyglada naturalnie.
func _build_canyon_rim() -> void:
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var center := Vector3(side.x * (DESERT_HALF + 0.5), BORDER_HEIGHT * 0.5, side.y * (DESERT_HALF + 0.5))
		var size := Vector3(1.0 if side.x != 0.0 else DESERT_HALF * 2.0 + 2.0, BORDER_HEIGHT, 1.0 if side.y != 0.0 else DESERT_HALF * 2.0 + 2.0)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = center
		_body.add_child(collision)
	if _headless:
		return
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var along := Vector2(-side.y, side.x)
		var at := -DESERT_HALF - 10.0
		while at < DESERT_HALF + 10.0:
			var width := _rng.randf_range(7.0, 13.0)
			var height := _rng.randf_range(7.0, 17.0)
			var depth := _rng.randf_range(7.0, 11.0)
			var mid := side * (DESERT_HALF + 0.8 + depth * 0.5) + along * (at + width * 0.5)
			var color := ROCK[_rng.randi() % ROCK.size()]
			var size := Vector3(width if side.x == 0.0 else depth, height, depth if side.x == 0.0 else width)
			var tilt := _rng.randf_range(-0.12, 0.12)
			_rock(Vector3(mid.x, height * 0.5 - 0.5, mid.y), size, color, tilt, false)
			# Warstwy skaly: jasniejszy pas w polowie wysokosci.
			_decal(Vector3(mid.x, height * 0.55, mid.y), size * Vector3(1.03, 0.0, 1.03) + Vector3(0.0, 0.6, 0.0), color.lightened(0.18), tilt)
			at += width * _rng.randf_range(0.7, 0.95)


## Pochylnia na podest: konczy sie rowno z jego krawedzia, wiec nie ma progu ani przy wchodzeniu,
## ani przy schodzeniu. Pochylnia konczaca sie wewnatrz podestu bylaby tam nizej i zatrzymywala gracza.
func _ramp_onto(bottom: Vector3, edge: Vector3, top: float, width: float, color: Color) -> void:
	_ramp(bottom, Vector3(edge.x, top + 0.02, edge.z), width, color)


## Skala: bryla z fazowaniem i lekkim obrotem. Kolizja jest prostym pudelkiem.
func _rock(center: Vector3, size: Vector3, color: Color, rot_y := 0.0, collide := true) -> void:
	_box(center, size, color, collide, false, rot_y, minf(0.6, size.y * 0.15))


# --- Stacja kolejki (baza Kaktusow) -------------------------------------------

## Tory wzdluz calej polnocy, peron z budynkiem stacji, wagony do oslony i wieza cisnien z drabina.
func _build_station() -> void:
	# Tory: dwie szyny i podklady przez cala szerokosc mapy.
	for rail_z: float in [-44.7, -43.3]:
		_decal(Vector3(0.0, 0.12, rail_z), Vector3(DESERT_HALF * 2.0, 0.12, 0.12), RAIL)
	if not _headless:
		var sleeper := -DESERT_HALF + 1.0
		while sleeper < DESERT_HALF:
			_decal(Vector3(sleeper, 0.04, -44.0), Vector3(0.5, 0.08, 2.6), Color("8a6446"))
			sleeper += 1.6
	# Peron z dwiema pochylniami.
	_box(Vector3(0.0, 0.3, -48.5), Vector3(36.0, 0.6, 4.0), Color("cbb79a"))
	_ramp(Vector3(-20.5, 0.0, -48.5), Vector3(-18.0, 0.6, -48.5), 4.0, Color("cbb79a"))
	_ramp(Vector3(20.5, 0.0, -48.5), Vector3(18.0, 0.6, -48.5), 4.0, Color("cbb79a"))
	_decal(Vector3(0.0, 0.62, -46.65), Vector3(36.0, 0.03, 0.3), Color("ffcb47"))
	# Budynek stacji: parter z drzwiami w obie strony, dach z murkiem i drabina.
	var rect := Rect2(-9.0, -62.0, 18.0, 8.0)
	_building_shell(rect, Color("f2a65a"), 1, [
		{ "side": "south", "at": 4.0 }, { "side": "south", "at": 14.0 }, { "side": "north", "at": 9.0 },
		{ "side": "west", "at": 4.0 }, { "side": "east", "at": 4.0 },
	])
	_slab(rect.grow(0.15), FLOOR_HEIGHT + SLAB, Rect2(), Color("c2754a"))
	_parapet(rect, FLOOR_HEIGHT + SLAB, Color("f2a65a"))
	_ladder(Vector3(-9.3, 0.0, -56.0), Vector3.LEFT, FLOOR_HEIGHT + 1.2)
	# Szyld i zegar na frontonie.
	_decal(Vector3(0.0, 2.9, -53.85), Vector3(6.0, 0.7, 0.1), Color("fff1d6"))
	_decal(Vector3(0.0, 2.9, -53.8), Vector3(5.4, 0.4, 0.1), Color("3a6ea5"))
	_decal(Vector3(0.0, FLOOR_HEIGHT + 1.6, -54.0), Vector3(1.2, 1.2, 0.15), Color("fff1d6"))
	# Daszek nad peronem na slupach.
	for x: float in [-14.0, -7.0, 0.0, 7.0, 14.0]:
		_box(Vector3(x, 2.0, -50.0), Vector3(0.25, 2.8, 0.25), Color("6b6e7a"))
	_decal(Vector3(0.0, 3.45, -49.5), Vector3(32.0, 0.15, 3.6), Color("2ec4b6"))
	# Lawki i walizki na peronie.
	for x: float in [-11.0, 4.0]:
		_box(Vector3(x, 0.9, -49.5), Vector3(2.4, 0.6, 0.6), WOOD)
	_box(Vector3(9.5, 0.9, -48.0), Vector3(0.9, 0.6, 0.5), Color("9b7bff"))
	_box(Vector3(10.2, 0.85, -48.4), Vector3(0.6, 0.5, 0.4), Color("ffcb47"))
	# Wagony na torach: oslona przy wyjsciu z bazy. Jeden jest otwarty i da sie przez niego przejsc.
	_wagon(Vector3(-30.0, 0.0, -44.0), WAGONS[0], false)
	_wagon(Vector3(-14.0, 0.0, -44.0), WAGONS[1], true)
	_wagon(Vector3(10.0, 0.0, -44.0), WAGONS[2], false)
	_wagon(Vector3(32.0, 0.0, -44.0), WAGONS[3], true)
	_wagon(Vector3(48.0, 0.0, -44.0), WAGONS[0], false)
	# Wieza cisnien: wysoki punkt z dluga linia strzalu wzdluz wschodu.
	_water_tower(Vector3(30.0, 0.0, -58.0))
	# Beczki i skrzynie przy wejsciu na peron.
	for at: Vector3 in [Vector3(-24.0, 0.5, -51.0), Vector3(-25.0, 0.5, -52.4), Vector3(25.0, 0.5, -52.0)]:
		_barrel(at)
	_box(Vector3(-23.0, 0.6, -53.0), Vector3(1.2, 1.2, 1.2), WOOD)


## Wagon towarowy. Otwarty ma drzwi z obu stron i podloge, na ktora wskakuje sie z ziemi.
func _wagon(base: Vector3, color: Color, open: bool) -> void:
	var length := 9.0
	var floor_y := 0.0
	var height := 2.6
	for x: float in [-3.0, 3.0]:
		_decal(base + Vector3(x, 0.45, 1.0), Vector3(1.4, 0.9, 0.2), Color("3b3d46"))
		_decal(base + Vector3(x, 0.45, -1.0), Vector3(1.4, 0.9, 0.2), Color("3b3d46"))
	if not open:
		_box(base + Vector3(0.0, floor_y + height * 0.5 - 0.3, 0.0), Vector3(length, height + 0.6, 2.8), color, true, true)
		_decal(base + Vector3(0.0, floor_y + height + 0.05, 0.0), Vector3(length + 0.2, 0.15, 3.0), color.darkened(0.25))
		return
	_decal(base + Vector3(0.0, 0.03, 0.0), Vector3(length, 0.04, 2.8), color.darkened(0.3))
	var a := Vector2(base.x - length * 0.5, base.z)
	var b := Vector2(base.x + length * 0.5, base.z)
	var door := [{ "at": length * 0.5, "width": 2.4, "bottom": 0.0, "top": height }]
	_wall(a + Vector2(0.0, -1.4), b + Vector2(0.0, -1.4), floor_y, height, color, door)
	_wall(a + Vector2(0.0, 1.4), b + Vector2(0.0, 1.4), floor_y, height, color, door)
	_wall(a + Vector2(0.0, -1.4), a + Vector2(0.0, 1.4), floor_y, height, color)
	_wall(b + Vector2(0.0, -1.4), b + Vector2(0.0, 1.4), floor_y, height, color)
	_box(base + Vector3(0.0, floor_y + height + 0.1, 0.0), Vector3(length + 0.2, 0.2, 3.0), color.darkened(0.25), true, true)



func _water_tower(base: Vector3) -> void:
	var top := 6.0
	for corner: Vector2 in [Vector2(-1.6, -1.6), Vector2(1.6, -1.6), Vector2(-1.6, 1.6), Vector2(1.6, 1.6)]:
		_box(base + Vector3(corner.x, top * 0.5, corner.y), Vector3(0.3, top, 0.3), Color("8a6446"))
	_box(base + Vector3(0.0, top - 0.15, 0.0), Vector3(4.6, 0.3, 4.6), WOOD)
	# Barierka wokol pomostu, z przerwa na drabine.
	_box(base + Vector3(0.0, top + 0.5, -2.2), Vector3(4.6, 1.0, 0.15), WOOD.darkened(0.15))
	_box(base + Vector3(-2.2, top + 0.5, 0.0), Vector3(0.15, 1.0, 4.6), WOOD.darkened(0.15))
	_box(base + Vector3(2.2, top + 0.5, 0.0), Vector3(0.15, 1.0, 4.6), WOOD.darkened(0.15))
	_box(base + Vector3(-1.4, top + 0.5, 2.2), Vector3(1.8, 1.0, 0.15), WOOD.darkened(0.15))
	_box(base + Vector3(1.4, top + 0.5, 2.2), Vector3(1.8, 1.0, 0.15), WOOD.darkened(0.15))
	# Zbiornik na wysokich nogach z tylu pomostu, zeby nie zaslanial strzelajacego.
	_box(base + Vector3(0.0, top + 2.6, -1.0), Vector3(3.0, 2.6, 2.0), Color("5b8def"), true, true)
	_decal(base + Vector3(0.0, top + 4.0, -1.0), Vector3(3.3, 0.25, 2.3), Color("3a6ea5"))
	_ladder(base + Vector3(0.0, 0.0, 2.3), Vector3.BACK, top + 1.0)


func _barrel(at: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	_body.add_child(collision)
	CityMapInfo.metal_boxes.append(AABB(at - Vector3(0.45, 0.5, 0.45), Vector3(0.9, 1.0, 0.9)))
	if not _headless:
		LowPoly.part(_visuals, LowPoly.cylinder(0.45, 0.45, 1.0, 10), Color("e4572e"), at)
		LowPoly.part(_visuals, LowPoly.cylinder(0.47, 0.47, 0.08, 10), Color("3b3d46"), at + Vector3.UP * 0.3)


# --- Gliniana twierdza (baza Zuczkow) ----------------------------------------

## Ruiny glinianego fortu: mury z wyrwami, dwie wieze z pochylniami na szczyt i studnia na dziedzincu.
func _build_fort() -> void:
	var outer := Rect2(-26.0, 42.0, 52.0, 18.0)
	var height := 3.6
	# Polnocny mur ma brame i dwie wyrwy, a pozostale po jednej wyrwie.
	_wall(Vector2(outer.position.x, outer.position.y), Vector2(outer.end.x, outer.position.y), 0.0, height, MUD, [
		{ "at": 26.0, "width": 6.0, "bottom": 0.0, "top": height },
		{ "at": 10.0, "width": 3.0, "bottom": 0.0, "top": 2.2 },
		{ "at": 42.0, "width": 3.0, "bottom": 1.0, "top": height },
	])
	_wall(Vector2(outer.position.x, outer.end.y), Vector2(outer.end.x, outer.end.y), 0.0, height, MUD, [
		{ "at": 14.0, "width": 3.0, "bottom": 0.0, "top": 2.4 }, { "at": 38.0, "width": 3.0, "bottom": 0.0, "top": 2.4 },
	])
	_wall(Vector2(outer.position.x, outer.position.y), Vector2(outer.position.x, outer.end.y), 0.0, height, MUD, [
		{ "at": 9.0, "width": 3.0, "bottom": 0.0, "top": 2.4 },
	])
	_wall(Vector2(outer.end.x, outer.position.y), Vector2(outer.end.x, outer.end.y), 0.0, height, MUD, [
		{ "at": 9.0, "width": 3.0, "bottom": 0.0, "top": 2.4 },
	])
	# Zeby na murach, bo to gliniany fort.
	if not _headless:
		var x := outer.position.x + 1.0
		while x < outer.end.x:
			if absf(x) > 4.0:
				_decal(Vector3(x, height + 0.3, outer.position.y), Vector3(0.9, 0.6, WALL + 0.05), MUD_DARK)
			x += 2.0
	# Brama: belka nad przejsciem.
	_decal(Vector3(0.0, height + 0.4, outer.position.y), Vector3(7.0, 0.5, 0.6), WOOD)
	# Dwie wieze na rogach od strony mapy: z pochylnia na pietro i drabina na dach.
	_fort_tower(Rect2(-24.0, 43.5, 6.0, 6.0), true)
	_fort_tower(Rect2(18.0, 43.5, 6.0, 6.0), false)
	# Dziedziniec: studnia, wozy z sianem i skrzynie jako oslona.
	_well(Vector3(0.0, 0.0, 52.0))
	_box(Vector3(-12.0, 0.6, 53.0), Vector3(3.0, 1.2, 1.6), WOOD.lightened(0.1))
	_box(Vector3(12.0, 0.6, 53.0), Vector3(1.6, 1.2, 3.0), WOOD.lightened(0.1))
	_box(Vector3(-5.0, 0.5, 46.5), Vector3(1.0, 1.0, 1.0), WOOD)
	_box(Vector3(6.0, 0.5, 47.0), Vector3(1.0, 1.0, 1.0), WOOD)
	for at: Vector3 in [Vector3(-20.0, 0.5, 57.0), Vector3(21.0, 0.5, 57.5)]:
		_barrel(at)
	# Gliniane dzbany przy murze.
	if not _headless:
		for i in 6:
			var at := Vector3(-22.0 + i * 1.1, 0.35, 58.8)
			LowPoly.part(_visuals, LowPoly.ball(0.4, 8, 5), Color("c96f45"), at)


## Kwadratowa wieza: izba na parterze z wejsciem od dziedzinca i taras na dachu z murkiem.
## Na taras prowadzi drewniana pochylnia po zewnetrznej scianie. Z tarasu widac caly srodek mapy.
func _fort_tower(rect: Rect2, west: bool) -> void:
	_tower_block(rect, TOWER_HEIGHT, MUD.lightened(0.05), "south", "")
	_parapet(rect, TOWER_HEIGHT + SLAB * 0.5, MUD, ["east" if west else "west"])
	var x0 := rect.end.x + 0.9 if west else rect.position.x - 0.9
	_ramp_onto(Vector3(x0, 0.0, rect.end.y + 7.5), Vector3(x0, 0.0, rect.end.y - 0.2), TOWER_HEIGHT, 1.6, WOOD)
	_box(Vector3(x0, TOWER_HEIGHT - 0.15, rect.end.y - 1.0), Vector3(1.6, 0.3, 1.6), WOOD)
	# Pomost z konca pochylni na taras przez przerwe w murku.
	var bridge_x := (x0 + (rect.end.x if west else rect.position.x)) * 0.5
	_box(Vector3(bridge_x, TOWER_HEIGHT - 0.15, rect.end.y - 1.0), Vector3(1.0, 0.3, 1.6), WOOD)


## Budynek z jedna wysoka izba, drzwiami i tarasem na dachu. "open_side" to strona tarasu bez murka,
## od ktorej dochodzi pochylnia.
func _tower_block(rect: Rect2, height: float, color: Color, door_side: String, _unused: String) -> void:
	var corners := {
		"north": [Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)],
		"south": [Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y)],
		"west": [Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.end.y)],
		"east": [Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y)],
	}
	for side: String in corners:
		var a: Vector2 = corners[side][0]
		var b: Vector2 = corners[side][1]
		var holes := [{ "at": a.distance_to(b) * 0.5, "width": 1.2, "bottom": 2.6, "top": 3.4 }]
		if side == door_side:
			holes = [{ "at": a.distance_to(b) * 0.5, "width": DOOR_WIDTH, "bottom": 0.0, "top": DOOR_HEIGHT }]
		_wall(a, b, 0.0, height, color, holes)
	_slab(rect.grow(0.15), height + SLAB * 0.5, Rect2(), MUD_DARK)


func _well(base: Vector3) -> void:
	for i in 8:
		var angle := TAU * i / 8.0
		var at := Vector2(base.x, base.z) + Vector2.from_angle(angle) * 1.4
		_box(Vector3(at.x, 0.45, at.y), Vector3(1.2, 0.9, 0.45), Color("cbb79a"), true, false, -angle + PI * 0.5)
	_decal(base + Vector3(0.0, 0.7, 0.0), Vector3(2.2, 0.05, 2.2), Color("2f6f8f"))
	for side: float in [-1.0, 1.0]:
		_box(base + Vector3(side * 1.4, 1.5, 0.0), Vector3(0.2, 3.0, 0.2), WOOD)
	_decal(base + Vector3(0.0, 2.9, 0.0), Vector3(3.2, 0.2, 0.2), WOOD)
	_decal(base + Vector3(0.0, 3.3, 0.0), Vector3(3.4, 0.15, 2.0), Color("ef6f6c"))


# --- Targ (srodek) -----------------------------------------------------------

## Targ z placiennymi daszkami: rzedy straganow tworza waskie uliczki, a dom kupca ma taras
## na dachu, z ktorego widac obie bazy.
func _build_market() -> void:
	_decal(Vector3(0.0, 0.015, 0.0), Vector3(30.0, 0.02, 30.0), Color("e8c48f"))
	# Dom kupca: wysoka izba i taras na dachu, na ktory prowadzi pochylnia od poludnia.
	var house := Rect2(4.0, -8.0, 8.0, 8.0)
	_tower_block(house, TOWER_HEIGHT, Color("f7d08a"), "west", "")
	var roof := TOWER_HEIGHT + SLAB * 0.5
	for side: Array in [[Vector3(house.get_center().x, roof + 0.45, house.position.y), Vector3(house.size.x + WALL, 0.9, WALL)], [Vector3(house.position.x, roof + 0.45, house.get_center().y), Vector3(WALL, 0.9, house.size.y)], [Vector3(house.end.x, roof + 0.45, house.get_center().y), Vector3(WALL, 0.9, house.size.y)], [Vector3(house.position.x + 2.5, roof + 0.45, house.end.y), Vector3(5.0, 0.9, WALL)]]:
		_box(side[0], side[1], Color("f7d08a").darkened(0.15))
	_ramp_onto(Vector3(house.end.x - 1.0, 0.0, house.end.y + 9.0), Vector3(house.end.x - 1.0, 0.0, house.end.y + 0.15), roof, 1.8, WOOD)
	# Kolorowe markizy na scianach domu.
	_decal(Vector3(house.get_center().x, 2.7, house.end.y + 0.5), Vector3(6.0, 0.12, 1.2), CANVAS[0])
	# Rzedy straganow.
	var stall_spots: Array[Vector2] = [
		Vector2(-10.0, -10.0), Vector2(-4.0, -10.0), Vector2(-10.0, -3.0), Vector2(-10.0, 4.0),
		Vector2(-4.0, 6.0), Vector2(3.0, 6.0), Vector2(10.0, 6.0), Vector2(-4.0, 12.0), Vector2(8.0, 12.0),
	]
	for i in stall_spots.size():
		_stall(stall_spots[i], CANVAS[i % CANVAS.size()], i % 2 == 0)
	# Wielki parasol na srodku targu nad stertami skrzyn.
	_box(Vector3(-3.0, 0.6, 0.0), Vector3(1.2, 1.2, 1.2), WOOD)
	_box(Vector3(-1.8, 0.45, 0.6), Vector3(0.9, 0.9, 0.9), WOOD.lightened(0.1))
	_box(Vector3(-3.0, 1.5, 0.0), Vector3(0.9, 0.6, 0.9), Color("ffcb47"))
	_box(Vector3(-2.0, 2.2, -0.2), Vector3(0.15, 4.4, 0.15), Color("8a6446"))
	if not _headless:
		var umbrella := LowPoly.part(_visuals, LowPoly.cylinder(0.0, 3.2, 1.0, 8), CANVAS[3], Vector3(-2.0, 4.6, -0.2))
		umbrella.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Stragan: lada z towarem, cztery slupki i placienny daszek. Daszek jest nad glowa, wiec nie ma kolizji.
func _stall(at: Vector2, color: Color, along_x: bool) -> void:
	var size := Vector2(4.0, 2.2) if along_x else Vector2(2.2, 4.0)
	_box(Vector3(at.x, 0.5, at.y), Vector3(size.x, 1.0, size.y) * Vector3(0.9, 1.0, 0.45 if along_x else 0.9) + Vector3(0.0, 0.0, 0.0), WOOD)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(at.x + sx * size.x * 0.48, 1.3, at.y + sz * size.y * 0.48), Vector3(0.12, 2.6, 0.12), Color("8a6446"))
	if _headless:
		return
	var roof := LowPoly.part(_visuals, LowPoly.box(Vector3(size.x + 0.5, 0.08, size.y + 0.5), 0.02), color, Vector3(at.x, 2.7, at.y), Vector3(0.0 if along_x else 6.0, 0.0, 6.0 if along_x else 0.0))
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Pasy na placienie.
	_decal(Vector3(at.x, 2.76, at.y), Vector3(size.x * 0.25 if along_x else size.x + 0.5, 0.05, size.y + 0.5 if along_x else size.y * 0.25), Color.WHITE)
	# Towar na ladzie: owoce, dzbany i tkaniny.
	for i in 3:
		var offset := (i - 1) * (size.x * 0.28 if along_x else size.y * 0.28)
		var spot := Vector3(at.x + (offset if along_x else 0.0), 1.15, at.y + (0.0 if along_x else offset))
		LowPoly.part(_visuals, LowPoly.ball(0.28, 7, 4), [Color("ffcb47"), Color("ef6f6c"), Color("7cc6a4")][i], spot)


# --- Kanion z mostem linowym (zachod) ----------------------------------------

## Dwa plaskowyze z waskim kanionem miedzy nimi. Dolem idzie oslonieta trasa, a gora most linowy
## i dlugie linie strzalu. Na plaskowyze prowadza kamienne pochylnie na ich koncach.
func _build_canyon() -> void:
	var west := Rect2(-62.0, -26.0, 16.0, 52.0)
	var east := Rect2(-34.0, -22.0, 9.0, 44.0)
	for mesa: Rect2 in [west, east]:
		_rock(Vector3(mesa.get_center().x, MESA_HEIGHT * 0.5, mesa.get_center().y), Vector3(mesa.size.x, MESA_HEIGHT, mesa.size.y), ROCK[1])
		_decal(Vector3(mesa.get_center().x, MESA_HEIGHT + 0.02, mesa.get_center().y), Vector3(mesa.size.x - 0.6, 0.04, mesa.size.y - 0.6), Color("e9a774"))
		# Pasy skaly na scianach.
		_decal(Vector3(mesa.get_center().x, MESA_HEIGHT * 0.45, mesa.get_center().y), Vector3(mesa.size.x + 0.1, 0.5, mesa.size.y + 0.1), ROCK[2])
	# Pochylnie na plaskowyze: na zachodni z poludnia i polnocy, na wschodni od strony srodka mapy.
	_ramp_onto(Vector3(-54.0, 0.0, 35.0), Vector3(-54.0, 0.0, west.end.y), MESA_HEIGHT, 4.0, ROCK[2])
	_ramp_onto(Vector3(-54.0, 0.0, -35.0), Vector3(-54.0, 0.0, west.position.y), MESA_HEIGHT, 4.0, ROCK[2])
	_ramp_onto(Vector3(-15.0, 0.0, -14.0), Vector3(east.end.x, 0.0, -14.0), MESA_HEIGHT, 3.0, ROCK[2])
	_ramp_onto(Vector3(-15.0, 0.0, 14.0), Vector3(east.end.x, 0.0, 14.0), MESA_HEIGHT, 3.0, ROCK[2])
	# Most linowy nad kanionem: deski z kolizja, liny i slupki tylko dla oka.
	var from := west.end.x
	var to := east.position.x
	_box(Vector3((from + to) * 0.5, MESA_HEIGHT - 0.1, 0.0), Vector3(to - from + 1.0, 0.2, 1.8), WOOD)
	if not _headless:
		var plank := from
		while plank < to:
			_decal(Vector3(plank + 0.3, MESA_HEIGHT + 0.02, 0.0), Vector3(0.45, 0.06, 1.9), WOOD.darkened(0.15))
			plank += 0.6
		for side: float in [-0.95, 0.95]:
			_decal(Vector3((from + to) * 0.5, MESA_HEIGHT + 0.9, side), Vector3(to - from + 1.0, 0.06, 0.06), Color("e8d3a6"))
			for x: float in [from - 0.3, to + 0.3]:
				LowPoly.part(_visuals, LowPoly.cylinder(0.1, 0.1, 1.4, 6), Color("8a6446"), Vector3(x, MESA_HEIGHT + 0.7, side))
	# Oslony na dnie kanionu: glazy i powalony slup.
	for spot: Vector3 in [Vector3(-40.0, 0.0, -18.0), Vector3(-39.0, 0.0, 8.0), Vector3(-42.0, 0.0, 20.0)]:
		_rock(spot + Vector3(0.0, 0.8, 0.0), Vector3(2.2, 1.6, 1.8), ROCK[3], _rng.randf() * TAU)
	_box(Vector3(-38.0, 0.35, -4.0), Vector3(0.7, 0.7, 5.0), WOOD.darkened(0.2), true, false, 0.3)
	# Oslony na plaskowyzach: niskie skalki.
	for spot: Vector3 in [Vector3(-52.0, 0.0, -8.0), Vector3(-57.0, 0.0, 12.0), Vector3(-30.0, 0.0, -4.0), Vector3(-29.0, 0.0, 10.0)]:
		_rock(spot + Vector3(0.0, MESA_HEIGHT + 0.55, 0.0), Vector3(1.8, 1.1, 1.4), ROCK[0], _rng.randf() * TAU)


# --- Oaza (wschod) -----------------------------------------------------------

## Sadzawka z palmami, chata z dachem dostepnym po drabinie i namioty. Palmy maja kolizje pni.
func _build_oasis() -> void:
	_decal(Vector3(POND_CENTER.x, 0.03, POND_CENTER.y), Vector3(POND_RADIUS * 2.0 + 3.0, 0.02, POND_RADIUS * 2.0 + 3.0), Color("cfe8b8"))
	if not _headless:
		var pond := LowPoly.part(_visuals, LowPoly.cylinder(POND_RADIUS, POND_RADIUS, 0.06, 18), WATER, Vector3(POND_CENTER.x, 0.05, POND_CENTER.y))
		pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		LowPoly.part(_visuals, LowPoly.ring(POND_RADIUS, POND_RADIUS + 0.8, 18), Color("b8d99a"), Vector3(POND_CENTER.x, 0.07, POND_CENTER.y))
	for i in 9:
		var angle := TAU * i / 9.0 + 0.3
		var at := POND_CENTER + Vector2.from_angle(angle) * (POND_RADIUS + _rng.randf_range(2.0, 5.0))
		_palm(Vector3(at.x, 0.0, at.y))
	for at: Vector2 in [Vector2(30.0, -12.0), Vector2(54.0, 20.0), Vector2(56.0, -18.0)]:
		_palm(Vector3(at.x, 0.0, at.y))
	# Chata z plaskim dachem i drabina.
	var hut := Rect2(28.0, 8.0, 6.0, 6.0)
	_building_shell(hut, Color("e8b57d"), 1, [{ "side": "west", "at": 3.0 }, { "side": "south", "at": 3.0 }])
	_slab(hut.grow(0.15), FLOOR_HEIGHT + SLAB * 0.5, Rect2(), Color("a8784e"))
	_parapet(hut, FLOOR_HEIGHT + SLAB * 0.5, Color("e8b57d"))
	_ladder(Vector3(hut.end.x + 0.3, 0.0, hut.get_center().y), Vector3.RIGHT, FLOOR_HEIGHT + 1.2)
	# Namioty beduinskie: niska oslona, przez ktora nie widac.
	_tent(Vector3(50.0, 0.0, -6.0), CANVAS[4])
	_tent(Vector3(52.0, 0.0, 8.0), CANVAS[1])
	# Pomost nad sadzawka i lodka.
	_box(Vector3(POND_CENTER.x - POND_RADIUS + 2.0, 0.25, POND_CENTER.y), Vector3(4.0, 0.2, 1.4), WOOD)
	_decal(Vector3(POND_CENTER.x + 2.0, 0.2, POND_CENTER.y + 2.0), Vector3(2.4, 0.35, 1.0), Color("ef6f6c"), 0.5)


func _palm(base: Vector3) -> void:
	var height := _rng.randf_range(5.0, 7.0)
	var lean := Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.8, 0.8))
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * height * 0.5
	_body.add_child(collision)
	if _headless:
		return
	var trunk := LowPoly.part(_visuals, LowPoly.cylinder(0.18, 0.32, height, 7), PALM_TRUNK, base + Vector3.UP * height * 0.5 + lean * 0.5)
	trunk.look_at_from_position(trunk.position, base + Vector3.UP * height + lean, Vector3.FORWARD)
	trunk.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var crown := base + Vector3.UP * height + lean
	for i in 6:
		var angle := TAU * i / 6.0 + _rng.randf() * 0.4
		var leaf := LowPoly.part(_visuals, LowPoly.box(Vector3(0.7, 0.08, 2.6), 0.03), PALM_LEAF if i % 2 == 0 else PALM_LEAF.darkened(0.15), crown)
		leaf.rotation = Vector3(0.0, angle, 0.0)
		leaf.rotate_object_local(Vector3.RIGHT, -0.45)
		leaf.translate_object_local(Vector3(0.0, 0.0, -1.2))
	LowPoly.part(_visuals, LowPoly.ball(0.4, 7, 4), Color("8a6446"), crown)


func _tent(base: Vector3, color: Color) -> void:
	_box(base + Vector3(0.0, 1.0, 0.0), Vector3(4.0, 2.0, 3.0), color.lightened(0.15))
	if not _headless:
		var roof := LowPoly.part(_visuals, LowPoly.cylinder(0.0, 2.9, 1.2, 4), color, base + Vector3(0.0, 2.6, 0.0), Vector3(0.0, 45.0, 0.0))
		roof.scale = Vector3(1.0, 1.0, 0.75)
		_decal(base + Vector3(0.0, 0.8, 1.52), Vector3(1.2, 1.6, 0.05), color.darkened(0.35))


# --- Wydmy z wrakiem ---------------------------------------------------------

## Lagodne wydmy, na ktore da sie wejsc, i wrak ciezarowki jako oslona na otwartej przestrzeni.
func _build_dunes() -> void:
	for dune: Array in [[Vector3(16.0, 0.0, 30.0), 9.0, 1.8], [Vector3(30.0, 0.0, 26.0), 7.0, 1.4], [Vector3(-22.0, 0.0, 30.0), 8.0, 1.6], [Vector3(36.0, 0.0, 40.0), 6.0, 1.2], [Vector3(-46.0, 0.0, 40.0), 7.0, 1.5]]:
		_dune(dune[0], dune[1], dune[2])
	_truck(Vector3(22.0, 0.0, 33.0), 0.5)


## Wydma to sciety stozek: zbocze ma kilkanascie stopni, wiec wchodzi sie bez skakania.
func _dune(base: Vector3, radius: float, height: float) -> void:
	var mesh := LowPoly.cylinder(radius * 0.35, radius, height, 10)
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for i in 10:
		var angle := TAU * i / 10.0
		points.append(Vector3(cos(angle) * radius, -height * 0.5, sin(angle) * radius))
		points.append(Vector3(cos(angle) * radius * 0.35, height * 0.5, sin(angle) * radius * 0.35))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * (height * 0.5 - 0.05)
	_body.add_child(collision)
	if not _headless:
		var dune := LowPoly.part(_visuals, mesh, SAND_LIGHT, base + Vector3.UP * (height * 0.5 - 0.05))
		dune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _truck(base: Vector3, rot_y: float) -> void:
	var basis := Basis(Vector3.UP, rot_y)
	var parts: Array[Array] = [
		[Vector3(0.0, 1.2, -2.6), Vector3(2.4, 2.0, 2.2), Color("5b8def").darkened(0.2)],
		[Vector3(0.0, 1.0, 1.0), Vector3(2.5, 1.2, 5.0), Color("8a6446")],
		[Vector3(0.0, 2.0, 1.0), Vector3(2.5, 0.8, 0.2), Color("8a6446")],
	]
	for part: Array in parts:
		_box(base + basis * (part[0] as Vector3), part[1], part[2], true, true, rot_y)
	_decal(base + basis * Vector3(0.0, 1.7, -3.72), Vector3(2.0, 0.7, 0.05), GLASS.darkened(0.3), rot_y)
	if not _headless:
		for wheel: Vector3 in [Vector3(-1.3, 0.45, -2.5), Vector3(1.3, 0.45, -2.5), Vector3(-1.3, 0.45, 2.2), Vector3(1.3, 0.45, 2.2)]:
			var mesh := LowPoly.part(_visuals, LowPoly.cylinder(0.45, 0.45, 0.35, 8), Color("3b3d46"), base + basis * wheel)
			mesh.rotation = Vector3(0.0, rot_y, PI * 0.5)
		# Piasek nawiany na wrak.
		LowPoly.part(_visuals, LowPoly.cylinder(0.6, 2.4, 0.9, 8), SAND_LIGHT, base + basis * Vector3(1.6, 0.4, 1.5))


# --- Oslony na otwartej przestrzeni ------------------------------------------

## Skalki, murki, beczki i kaktusy miedzy miejscami, zeby przejscie przez otwarty piasek nie bylo
## strzelnica. Dlugie linie zostaja wzdluz torow, kanionu i glownej drogi.
func _build_cover() -> void:
	var rocks: Array[Vector3] = [
		Vector3(-18.0, 0.0, -24.0), Vector3(18.0, 0.0, -24.0), Vector3(-24.0, 0.0, -36.0), Vector3(26.0, 0.0, -34.0),
		Vector3(-6.0, 0.0, -30.0), Vector3(8.0, 0.0, -36.0), Vector3(-10.0, 0.0, 26.0), Vector3(4.0, 0.0, 24.0),
		Vector3(-34.0, 0.0, 30.0), Vector3(46.0, 0.0, 30.0), Vector3(56.0, 0.0, -30.0), Vector3(-14.0, 0.0, 36.0),
		Vector3(42.0, 0.0, -26.0), Vector3(-48.0, 0.0, -34.0),
	]
	for spot in rocks:
		var size := Vector3(_rng.randf_range(1.8, 3.2), _rng.randf_range(1.2, 2.2), _rng.randf_range(1.6, 2.8))
		_rock(spot + Vector3(0.0, size.y * 0.5, 0.0), size, ROCK[_rng.randi() % ROCK.size()], _rng.randf() * TAU)
	# Murki z cegly mulowej z wyrwami, dobre do kucania.
	for wall: Array in [[Vector2(-14.0, -18.0), Vector2(-6.0, -18.0)], [Vector2(6.0, -18.0), Vector2(14.0, -18.0)], [Vector2(-12.0, 19.0), Vector2(-4.0, 19.0)], [Vector2(6.0, 19.0), Vector2(14.0, 19.0)], [Vector2(22.0, -6.0), Vector2(22.0, 6.0)]]:
		_wall(wall[0], wall[1], 0.0, 1.15, MUD, [{ "at": 4.0, "width": 1.2, "bottom": 0.7, "top": 1.15 }])
	# Kaktusy jako oslony z kolizja.
	for spot: Vector3 in [Vector3(-26.0, 0.0, -10.0), Vector3(26.0, 0.0, 18.0), Vector3(-8.0, 0.0, -34.0), Vector3(12.0, 0.0, 40.0), Vector3(-30.0, 0.0, 44.0), Vector3(48.0, 0.0, -35.0), Vector3(-20.0, 0.0, 12.0)]:
		_cactus(spot)
	# Ruina luku przy drodze ze stacji na targ.
	_box(Vector3(-3.0, 1.8, -24.0), Vector3(1.0, 3.6, 1.0), MUD)
	_box(Vector3(3.0, 1.8, -24.0), Vector3(1.0, 3.6, 1.0), MUD)
	_box(Vector3(0.0, 3.9, -24.0), Vector3(7.0, 0.8, 1.0), MUD_DARK)
	for at: Vector3 in [Vector3(-16.0, 0.5, 14.0), Vector3(16.0, 0.5, -12.0), Vector3(38.0, 0.5, 20.0)]:
		_barrel(at)


func _cactus(base: Vector3) -> void:
	var height := _rng.randf_range(2.2, 3.2)
	_box(base + Vector3.UP * height * 0.5, Vector3(0.6, height, 0.6), Color("4f9a57"), true, false, 0.0, 0.2)
	if _headless:
		return
	for side: float in [-1.0, 1.0]:
		var arm_y := height * _rng.randf_range(0.45, 0.65)
		LowPoly.part(_visuals, LowPoly.box(Vector3(0.6, 0.4, 0.4), 0.12), Color("4f9a57"), base + Vector3(side * 0.55, arm_y, 0.0))
		LowPoly.part(_visuals, LowPoly.box(Vector3(0.4, 1.0, 0.4), 0.12), Color("5aa862"), base + Vector3(side * 0.75, arm_y + 0.6, 0.0))
	LowPoly.part(_visuals, LowPoly.ball(0.18, 6, 4), Color("f78fb3"), base + Vector3.UP * (height + 0.05))


# --- Drobnica ------------------------------------------------------------------

## Krzaczki, kamyki i suche kepki jako MultiMesh w kawalkach mapy, bez kolizji i z zasiegiem widocznosci.
func _build_scatter() -> void:
	if _headless:
		return
	var shrubs: Array[Transform3D] = []
	var pebbles: Array[Transform3D] = []
	var tufts: Array[Transform3D] = []
	for i in 260:
		var at := Vector3(_rng.randf_range(-62.0, 62.0), 0.0, _rng.randf_range(-62.0, 62.0))
		if absf(at.x) < 15.0 and absf(at.z) < 15.0:
			continue
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.3))
		match i % 3:
			0:
				shrubs.append(Transform3D(basis, at))
			1:
				pebbles.append(Transform3D(basis, at))
			_:
				tufts.append(Transform3D(basis, at))
	_scatter(shrubs, [[LowPoly.ball(0.45, 6, 4), Color("9aa356"), Vector3(0.0, 0.25, 0.0)]], 70.0)
	_scatter(pebbles, [[LowPoly.box(Vector3(0.5, 0.3, 0.4), 0.1), ROCK[2], Vector3(0.0, 0.12, 0.0)]], 45.0)
	_scatter(tufts, [[LowPoly.cylinder(0.0, 0.25, 0.6, 5), Color("c9b25e"), Vector3(0.0, 0.3, 0.0)]], 45.0)


## Rozdziela egzemplarze na kawalki mapy, zeby dalekie kawalki mozna bylo pomijac w rysowaniu.
func _scatter(transforms: Array[Transform3D], parts: Array, visible_range: float) -> void:
	var cells := {}
	var size := 32.0
	for transform in transforms:
		var key := Vector2i(floori(transform.origin.x / size), floori(transform.origin.z / size))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(transform)
	for key: Vector2i in cells:
		var list: Array = cells[key]
		var center := Vector3((key.x + 0.5) * size, 0.0, (key.y + 0.5) * size)
		for part: Array in parts:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part[0]
			multimesh.instance_count = list.size()
			for index in list.size():
				var transform: Transform3D = list[index]
				multimesh.set_instance_transform(index, Transform3D(transform.basis, transform.origin - center + transform.basis * part[2]))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.material_override = LowPoly.material(part[1], 0.8)
			instance.position = center
			instance.visibility_range_end = visible_range * Settings.view_range()
			instance.visibility_range_end_margin = 8.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_visuals.add_child(instance)


# --- Punkty ------------------------------------------------------------------

## Punkty baz maja metadana "team", wiec Team Deathmatch startuje kazda druzyne u siebie.
## Punkty srodka maja "team" = -1 i sluza tylko Deathmatchowi, w ktorym startuje sie wszedzie.
func _build_desert_markers() -> void:
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	add_child(spawns)
	var index := 0
	for team in TEAM_SPAWNS.size():
		for spot: Vector3 in TEAM_SPAWNS[team]:
			spawns.add_child(_spawn_marker(spot, team, index))
			index += 1
	for spot in FREE_SPAWNS:
		spawns.add_child(_spawn_marker(spot, Teams.NONE, index))
		index += 1
	var chests := Node3D.new()
	chests.name = "ChestSpots"
	add_child(chests)
	for i in DESERT_CHESTS.size():
		var marker := Marker3D.new()
		marker.name = "Chest%d" % (i + 1)
		marker.position = Vector3(DESERT_CHESTS[i].x, DESERT_CHESTS[i].z, DESERT_CHESTS[i].y)
		marker.rotation.y = atan2(-DESERT_CHESTS[i].x, -DESERT_CHESTS[i].y)
		marker.add_to_group(&"chest_spots")
		chests.add_child(marker)


func _spawn_marker(spot: Vector3, team: int, index: int) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = "Spawn%d" % (index + 1)
	marker.position = Vector3(spot.x, spot.z + 0.2, spot.y)
	marker.set_meta(&"team", team)
	marker.add_to_group(&"spawn_points")
	return marker
