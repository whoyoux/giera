class_name ValleyBuilder
extends Node3D
## Duza dolina dla Battle Royale, okolo 200 m promienia, budowana kodem przy starcie.
## Teren ma kolizje z HeightMapShape3D i wyglad w kawalkach, a roslinnosc to MultiMesh z zasiegiem
## widocznosci, wiec mapa jest lekka takze na slabszym komputerze. Miejsca opisuje ValleyTerrain.

const CHUNK_CELLS := 28
const TREE_COLLISION_RADIUS := 0.35
const TREE_VISIBLE := 190.0
const BUSH_VISIBLE := 110.0
const GRASS_VISIBLE := 45.0
const CLUTTER_VISIBLE := 40.0
## Drobnica ma wieksze kawalki niz drzewa, zeby bylo mniej wezlow do sprawdzania.
const CLUTTER_CELL := 96.0
## Rekwizyty laczone w jedna siatke na kawalek mapy i widoczne do tej odleglosci.
const PROP_CELL := 64.0
const PROP_VISIBLE := 150.0
const SHADOW_MIN_SIZE := 1.6
const BORDER_SEGMENTS := 64
const BORDER_HEIGHT := 60.0

const GRASS := Color("6aa84a")
const GRASS_DARK := Color("4f8a3a")
const MEADOW := Color("8cc25a")
const DIRT := Color("a8834f")
const SAND := Color("d8c58c")
const ROCK := Color("9a958c")
const RIM := Color("4a7a36")
const STONE := Color("b9b3a6")
const STONE_DARK := Color("8f897e")
const WOOD := Color("a8784e")
const WOOD_DARK := Color("7a5236")
const ROOF_RED := Color("d9604f")
const WALLS: Array[Color] = [Color("f6e3c3"), Color("f2c38b"), Color("cfe3b4"), Color("f3d1d8"), Color("cfdcf2")]
const WATER := Color(0.34, 0.66, 0.86, 0.75)
## Male punkty miedzy miejscami z jedna skrzynka: miejsce i rodzaj.
const OUTPOSTS: Array[Array] = [
	[Vector2(-55.0, 20.0), "camp"], [Vector2(60.0, 35.0), "hut"], [Vector2(-40.0, -55.0), "ruin"],
	[Vector2(70.0, -40.0), "rocks"], [Vector2(-130.0, -10.0), "hut"], [Vector2(40.0, 95.0), "camp"],
	[Vector2(-60.0, 120.0), "ruin"], [Vector2(140.0, 20.0), "rocks"], [Vector2(-20.0, 70.0), "tower"],
	[Vector2(30.0, -120.0), "camp"], [Vector2(-150.0, 60.0), "rocks"], [Vector2(95.0, -150.0), "ruin"],
]

var _headless := false
var _body: StaticBody3D
var _visuals: Node3D
var _rng := RandomNumberGenerator.new()
var _spawns: Array[Vector3] = []
var _chests: Array[Vector3] = []
## Miejsca bez drzew: { at, radius }.
var _clear: Array[Dictionary] = []


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_headless = DisplayServer.get_name() == "headless"
	_rng.seed = 1337
	_body = StaticBody3D.new()
	_body.name = "Ground"
	_body.collision_layer = Hitscan.WORLD_MASK
	add_child(_body)
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	for entry in ValleyTerrain.PLACES:
		_clear.append({ "at": entry.at, "radius": entry.radius * 1.05 })
	_build_terrain()
	_build_border()
	# Punkty startu powstaja najpierw, zeby nowe rekwizyty mogly je omijac.
	_build_spawns()
	_build_ruins(ValleyTerrain.place("ruins"))
	_build_village(ValleyTerrain.place("village"))
	_build_farm(ValleyTerrain.place("farm"))
	_build_quarry(ValleyTerrain.place("quarry"))
	_build_lake(ValleyTerrain.place("lake"))
	_build_camp(ValleyTerrain.place("camp"))
	_build_road_chests()
	var props_from := _visuals.get_child_count()
	_build_place_props()
	_build_roadside()
	_build_outposts()
	_merge_visuals(props_from)
	_build_vegetation()
	_build_markers()
	if not _headless:
		add_child(ForestAmbienceValley.new())
	print("[mapa] dolina zbudowana w %d ms" % (Time.get_ticks_msec() - started))


# --- Teren -------------------------------------------------------------------

func _build_terrain() -> void:
	var size := int(ValleyTerrain.HALF * 2.0 / ValleyTerrain.CELL) + 1
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	for j in size:
		for i in size:
			heights[j * size + i] = ValleyTerrain.height(i * ValleyTerrain.CELL - ValleyTerrain.HALF, j * ValleyTerrain.CELL - ValleyTerrain.HALF)
	var shape := HeightMapShape3D.new()
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3(ValleyTerrain.CELL, 1.0, ValleyTerrain.CELL)
	_body.add_child(collision)
	if _headless:
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var cells := size - 1
	for cz in range(0, cells, CHUNK_CELLS):
		for cx in range(0, cells, CHUNK_CELLS):
			var mesh := _chunk_mesh(heights, size, cx, cz, mini(CHUNK_CELLS, cells - cx), mini(CHUNK_CELLS, cells - cz))
			if mesh == null:
				continue
			mesh.surface_set_material(0, material)
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			_visuals.add_child(instance)


func _chunk_mesh(heights: PackedFloat32Array, size: int, cx: int, cz: int, w: int, d: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for j in range(cz, cz + d):
		for i in range(cx, cx + w):
			var x0 := i * ValleyTerrain.CELL - ValleyTerrain.HALF
			var z0 := j * ValleyTerrain.CELL - ValleyTerrain.HALF
			if Vector2(x0, z0).length() > ValleyTerrain.HALF + 4.0:
				continue
			any = true
			var a := Vector3(x0, heights[j * size + i], z0)
			var b := Vector3(x0 + ValleyTerrain.CELL, heights[j * size + i + 1], z0)
			var c := Vector3(x0, heights[(j + 1) * size + i], z0 + ValleyTerrain.CELL)
			var e := Vector3(x0 + ValleyTerrain.CELL, heights[(j + 1) * size + i + 1], z0 + ValleyTerrain.CELL)
			for triangle: Array in [[a, b, c], [b, e, c]]:
				_face(tool, triangle)
	return tool.commit() if any else null


func _face(tool: SurfaceTool, triangle: Array) -> void:
	var center: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
	var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
	tool.set_color(_ground_color(center, normal))
	tool.set_normal(normal)
	for corner: Vector3 in triangle:
		tool.add_vertex(corner)


func _ground_color(center: Vector3, normal: Vector3) -> Color:
	var x := center.x
	var z := center.z
	var color := GRASS.lerp(GRASS_DARK, (sin(x * 0.07) * cos(z * 0.05) + 1.0) * 0.5)
	color = color.lerp(MEADOW, clampf(sin(x * 0.019 + 1.0) * sin(z * 0.023) * 1.5, 0.0, 0.6))
	if ValleyTerrain.is_road(x, z):
		color = DIRT
	var quarry := ValleyTerrain.place("quarry")
	if Vector2(x, z).distance_to(quarry.at) < quarry.radius * 1.05:
		color = ROCK.lerp(DIRT, 0.25)
	var lake := ValleyTerrain.place("lake")
	if Vector2(x, z).distance_to(lake.at) < lake.radius * 1.15 and center.y < ValleyTerrain.WATER_LEVEL + 0.8:
		color = SAND
	color = color.lerp(RIM, smoothstep(ValleyTerrain.RIM_START - 8.0, ValleyTerrain.HALF, Vector2(x, z).length()))
	return color.darkened(clampf((1.0 - normal.y) * 0.9, 0.0, 0.3))


## Niewidzialna sciana na krawedzi doliny.
func _build_border() -> void:
	var length := TAU * ValleyTerrain.RADIUS / BORDER_SEGMENTS * 1.1
	for index in BORDER_SEGMENTS:
		var angle := TAU * index / BORDER_SEGMENTS
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, BORDER_HEIGHT, 2.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(sin(angle), 0.0, cos(angle)) * (ValleyTerrain.RADIUS + 1.0)
		collision.position.y = BORDER_HEIGHT * 0.3
		collision.rotation.y = angle
		_body.add_child(collision)


# --- Klocki ------------------------------------------------------------------

func _ground(x: float, z: float) -> float:
	return ValleyTerrain.surface(x, z)


## Prostopadloscian stojacy na ziemi: "base" ma wysokosc podstawy wzgledem terenu w srodku.
func _block(at: Vector2, size: Vector3, color: Color, rot_y := 0.0, lift := 0.0, collide := true) -> Vector3:
	var floor_y := _ground(at.x, at.y)
	var center := Vector3(at.x, floor_y + lift + size.y * 0.5, at.y)
	_box(center, size, color, rot_y, collide)
	return center


func _box(center: Vector3, size: Vector3, color: Color, rot_y := 0.0, collide := true) -> void:
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = center
		collision.rotation.y = rot_y
		_body.add_child(collision)
	if not _headless:
		LowPoly.part(_visuals, LowPoly.box(size, minf(0.08, size.y * 0.3)), color, center, Vector3(0.0, rad_to_deg(rot_y), 0.0))


func _decal_box(center: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	if not _headless:
		var mesh := LowPoly.part(_visuals, LowPoly.box(size, minf(0.05, size.y * 0.3)), color, center, rot)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ramp(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var run := Vector2(to.x - from.x, to.z - from.z)
	var rise := to.y - from.y
	var length := sqrt(run.length_squared() + rise * rise)
	var basis := Basis(Vector3.UP, atan2(-run.x, -run.y)) * Basis(Vector3.RIGHT, atan2(rise, run.length()))
	var center := (from + to) * 0.5 + basis.y * -0.15
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.3, length)
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


## Domek z drzwiami: sciany z otworem, dach dwuspadowy jako wyglad, plaski strop jako kolizja.
func _house(at: Vector2, size: Vector2, rot_y: float, wall_color: Color, door_side := 0) -> void:
	var floor_y := _ground(at.x, at.y)
	var height := 3.0
	var basis := Basis(Vector3.UP, rot_y)
	var half := size * 0.5
	# Podloga, zeby nie stac w trawie, i fundament na zboczu.
	_box(Vector3(at.x, floor_y - 0.25, at.y), Vector3(size.x + 0.4, 0.9, size.y + 0.4), STONE_DARK, rot_y)
	var walls := [
		[Vector3(0, 0, -half.y), size.x, 0.0], [Vector3(0, 0, half.y), size.x, 0.0],
		[Vector3(-half.x, 0, 0), size.y, PI * 0.5], [Vector3(half.x, 0, 0), size.y, PI * 0.5],
	]
	for index in walls.size():
		var wall: Array = walls[index]
		var local: Vector3 = wall[0]
		var length: float = wall[1]
		var wall_rot: float = rot_y + wall[2]
		var dir := Basis(Vector3.UP, wall_rot) * Vector3.RIGHT
		var base := Vector3(at.x, floor_y + 0.2, at.y) + basis * local
		if index == door_side:
			var side := (length - 1.6) * 0.5
			for sign_x: float in [-1.0, 1.0]:
				_box(base + dir * sign_x * (0.8 + side * 0.5) + Vector3.UP * height * 0.5, Vector3(side, height, 0.3), wall_color, wall_rot)
			_box(base + Vector3.UP * (2.4 + (height - 2.4) * 0.5), Vector3(1.6, height - 2.4, 0.3), wall_color, wall_rot)
		else:
			# Okno jako dziura do strzelania.
			var side := (length - 1.2) * 0.5
			for sign_x: float in [-1.0, 1.0]:
				_box(base + dir * sign_x * (0.6 + side * 0.5) + Vector3.UP * height * 0.5, Vector3(side, height, 0.3), wall_color, wall_rot)
			_box(base + Vector3.UP * 0.5, Vector3(1.2, 1.0, 0.3), wall_color, wall_rot)
			_box(base + Vector3.UP * (2.1 + (height - 2.1) * 0.5), Vector3(1.2, height - 2.1, 0.3), wall_color, wall_rot)
	_box(Vector3(at.x, floor_y + 0.2 + height + 0.1, at.y), Vector3(size.x + 0.3, 0.2, size.y + 0.3), WOOD_DARK, rot_y)
	if not _headless:
		var roof_height := 1.6
		for sign_z: float in [-1.0, 1.0]:
			var slope := atan2(roof_height, half.y + 0.4)
			var panel_length := sqrt(pow(half.y + 0.4, 2.0) + roof_height * roof_height)
			var center := Vector3(at.x, floor_y + 0.2 + height + 0.2 + roof_height * 0.5, at.y) + basis * Vector3(0.0, 0.0, sign_z * (half.y + 0.4) * 0.5)
			var panel := LowPoly.part(_visuals, LowPoly.box(Vector3(size.x + 0.8, 0.18, panel_length), 0.04), ROOF_RED, center)
			panel.basis = basis * Basis(Vector3.RIGHT, sign_z * slope)


func _fence(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / length
	var rot := atan2(-dir.y, dir.x)
	var mid := (from + to) * 0.5
	var y := _ground(mid.x, mid.y)
	_box(Vector3(mid.x, y + 0.55, mid.y), Vector3(length, 0.12, 0.1), WOOD, rot)
	_box(Vector3(mid.x, y + 0.9, mid.y), Vector3(length, 0.12, 0.1), WOOD, rot, false)
	var posts := int(length / 2.0)
	for i in posts + 1:
		var at := from.lerp(to, float(i) / maxi(posts, 1))
		_box(Vector3(at.x, _ground(at.x, at.y) + 0.55, at.y), Vector3(0.16, 1.1, 0.16), WOOD_DARK, rot)


func _chest_at(at: Vector2, lift := 0.0) -> void:
	_chests.append(Vector3(at.x, _ground(at.x, at.y) + lift, at.y))


# --- Miejsca -----------------------------------------------------------------

## Stare ruiny na srodku: kamienne mury, kolumny i wieza z pochylnia.
func _build_ruins(place: Dictionary) -> void:
	var c: Vector2 = place.at
	for wall: Array in [[Vector2(-9, -6), Vector3(8, 3.2, 1.0), 0.0], [Vector2(8, -7), Vector3(6, 2.4, 1.0), 0.3], [Vector2(-10, 7), Vector3(1.0, 2.8, 7)], [Vector2(9, 8), Vector3(7, 1.6, 1.0), -0.2], [Vector2(0, 12), Vector3(5, 3.0, 1.0)], [Vector2(-2, -12), Vector3(4, 1.4, 1.0)]]:
		_block(c + wall[0], wall[1], STONE, wall[2] if wall.size() > 2 else 0.0)
	for column: Vector2 in [Vector2(-4, 3), Vector2(4, 3), Vector2(-4, -2), Vector2(4, -2)]:
		_block(c + column, Vector3(0.9, 4.0, 0.9), STONE_DARK)
	var tower := c + Vector2(14, -14)
	var base := _block(tower, Vector3(5, 5, 5), STONE)
	_ramp(Vector3(tower.x - 2.0, _ground(tower.x - 2.0, tower.y + 9.5), tower.y + 9.5), Vector3(tower.x - 2.0, base.y + 2.5, tower.y + 2.6), 1.6, WOOD)
	for offset: Vector2 in [Vector2(-2.2, -2.2), Vector2(2.2, -2.2), Vector2(2.2, 2.2)]:
		_box(Vector3(tower.x + offset.x, base.y + 3.0, tower.y + offset.y), Vector3(0.8, 1.0, 0.8), STONE_DARK)
	for at: Vector2 in [Vector2(0, 0), Vector2(-7, 0), Vector2(6, 5), Vector2(-6, 10), Vector2(10, -2), Vector2(-12, -10), Vector2(2, -9), Vector2(-16, 2), Vector2(14, 12)]:
		_chest_at(c + at)
	_chests.append(Vector3(tower.x, base.y + 2.5, tower.y))


## Wioska: domki wokol placyku ze studnia, plotki i ogrodki.
func _build_village(place: Dictionary) -> void:
	var c: Vector2 = place.at
	var houses: Array[Array] = [
		[Vector2(-14, -12), 0.0, 0], [Vector2(2, -16), 0.2, 1], [Vector2(16, -8), -0.4, 2],
		[Vector2(-16, 8), 0.5, 3], [Vector2(0, 16), 0.0, 2], [Vector2(16, 12), -0.2, 1],
	]
	var index := 0
	for house: Array in houses:
		var at: Vector2 = c + house[0]
		var door := 1 if house[0].y < 0 else 0
		_house(at, Vector2(6.0, 5.0), house[1], WALLS[index % WALLS.size()], door)
		_chest_at(at)
		index += 1
	_block(c, Vector3(2.0, 0.9, 2.0), STONE)
	_block(c + Vector2(0, 0.0), Vector3(0.2, 2.2, 0.2), WOOD_DARK, 0.0, 0.0, false)
	for side: Array in [[Vector2(-24, -4), Vector2(-24, 4)], [Vector2(24, -2), Vector2(24, 6)], [Vector2(-6, 24), Vector2(6, 24)]]:
		_fence(c + side[0], c + side[1])
	for at: Vector2 in [Vector2(5, 3), Vector2(-6, -3), Vector2(9, -1), Vector2(-22, 0), Vector2(22, 2)]:
		_chest_at(c + at)
	_block(c + Vector2(-4, 4), Vector3(1.0, 1.0, 1.0), WOOD)
	_block(c + Vector2(7, 6), Vector3(2.6, 1.1, 1.0), WOOD_DARK)


## Gospodarstwo: duza stodola z pietrem na siano, silos, belki siana, traktor i ogrodzenia.
func _build_farm(place: Dictionary) -> void:
	var c: Vector2 = place.at
	var barn := c + Vector2(-6, -4)
	var y := _ground(barn.x, barn.y)
	var color := Color("c8553d")
	_box(Vector3(barn.x, y - 0.2, barn.y), Vector3(14.4, 0.8, 10.4), STONE_DARK)
	for wall: Array in [[Vector2(0, -5), Vector3(14, 6, 0.3)], [Vector2(-7, 0), Vector3(0.3, 6, 10)], [Vector2(7, 0), Vector3(0.3, 6, 10)]]:
		_box(Vector3(barn.x + wall[0].x, y + 0.2 + 3.0, barn.y + wall[0].y), wall[1], color)
	# Przod stodoly z wielkimi wrotami.
	for x: float in [-5.0, 5.0]:
		_box(Vector3(barn.x + x, y + 3.2, barn.y + 5.0), Vector3(4.0, 6.0, 0.3), color)
	_box(Vector3(barn.x, y + 5.2, barn.y + 5.0), Vector3(6.0, 2.0, 0.3), color)
	_box(Vector3(barn.x, y + 6.3, barn.y), Vector3(14.6, 0.25, 10.6), WOOD_DARK)
	# Pietro na siano z pochylnia.
	_box(Vector3(barn.x - 3.5, y + 3.2, barn.y - 1.5), Vector3(7.0, 0.25, 7.0), WOOD)
	_ramp(Vector3(barn.x + 2.5, y + 0.2, barn.y + 3.8), Vector3(barn.x + 2.5, y + 3.3, barn.y - 2.0), 1.6, WOOD)
	_chests.append(Vector3(barn.x - 4.0, y + 3.32, barn.y - 2.0))
	_chests.append(Vector3(barn.x + 4.0, y + 0.2, barn.y - 2.5))
	var silo := c + Vector2(10, -10)
	_block(silo, Vector3(4.0, 9.0, 4.0), Color("d9d4c7"))
	_block(silo, Vector3(4.6, 0.6, 4.6), Color("7d8597"), 0.0, 9.0)
	for at: Vector2 in [Vector2(4, 8), Vector2(6, 9.5), Vector2(-2, 11), Vector2(12, 6)]:
		_block(c + at, Vector3(1.6, 1.3, 1.6), Color("e6c35c"))
	# Traktor jako oslona.
	_block(c + Vector2(12, 1), Vector3(2.0, 1.4, 3.2), Color("2ec4b6"))
	_block(c + Vector2(12, 0.4), Vector3(1.6, 1.0, 1.4), Color("2ec4b6").lightened(0.2), 0.0, 1.4)
	for side: Array in [[Vector2(-20, -16), Vector2(-20, 16)], [Vector2(-20, 16), Vector2(0, 20)], [Vector2(20, -18), Vector2(20, 14)]]:
		_fence(c + side[0], c + side[1])
	for at: Vector2 in [Vector2(5, 3), Vector2(14, -4), Vector2(-14, 12), Vector2(0, 15), Vector2(16, 12), Vector2(-16, -14), Vector2(-10, 16)]:
		_chest_at(c + at)


## Kamieniolom: dol z blokami skal, rusztowanie i pochylnie z dna na krawedz.
func _build_quarry(place: Dictionary) -> void:
	var c: Vector2 = place.at
	for rock: Array in [[Vector2(-8, -6), Vector3(4, 3, 3), 0.3], [Vector2(6, -9), Vector3(3, 4, 3), -0.5], [Vector2(9, 5), Vector3(5, 2.5, 3), 0.1], [Vector2(-6, 8), Vector3(3, 2, 4), 0.8], [Vector2(0, 0), Vector3(2.5, 1.5, 2.5), 0.0], [Vector2(-14, 2), Vector3(3, 5, 3), 0.2]]:
		_block(c + rock[0], rock[1], ROCK, rock[2], -0.3)
	# Rusztowanie z pomostem na krawedzi dolu.
	var deck := c + Vector2(12, 14)
	var top := _ground(deck.x, deck.y) + 3.0
	for offset: Vector2 in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		_block(deck + offset, Vector3(0.3, 3.0, 0.3), Color("ffcb47"))
	_box(Vector3(deck.x, top, deck.y), Vector3(5.0, 0.25, 5.0), WOOD)
	_ramp(Vector3(deck.x - 8.0, _ground(deck.x - 8.0, deck.y), deck.y), Vector3(deck.x - 2.4, top + 0.12, deck.y), 1.6, WOOD)
	_chests.append(Vector3(deck.x, top + 0.12, deck.y))
	for at: Vector2 in [Vector2(-3, -3), Vector2(4, 2), Vector2(-10, -12), Vector2(2, 12), Vector2(14, -6), Vector2(-12, 10), Vector2(10, -14)]:
		_chest_at(c + at)
	_block(c + Vector2(4, -2), Vector3(3.2, 1.6, 1.8), Color("f9a03f"))


## Jezioro z mostem, pomostem i lodka. Woda jest plytka, wiec da sie ja przejsc w brod.
func _build_lake(place: Dictionary) -> void:
	var c: Vector2 = place.at
	if not _headless:
		var plane := PlaneMesh.new()
		plane.size = Vector2(place.radius * 2.8, place.radius * 2.8)
		var material := StandardMaterial3D.new()
		material.albedo_color = WATER
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.12
		material.metallic_specular = 0.7
		var water := MeshInstance3D.new()
		water.mesh = plane
		water.material_override = material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.position = Vector3(c.x, ValleyTerrain.WATER_LEVEL, c.y)
		_visuals.add_child(water)
	# Most przez srodek jeziora z barierkami.
	var deck_y := 0.6
	var length: float = place.radius * 2.4
	_box(Vector3(c.x, deck_y, c.y), Vector3(3.2, 0.3, length), WOOD)
	for sign_x: float in [-1.0, 1.0]:
		_box(Vector3(c.x + sign_x * 1.55, deck_y + 0.55, c.y), Vector3(0.12, 0.9, length), WOOD_DARK)
	for sign_z: float in [-1.0, 1.0]:
		var end := Vector2(c.x, c.y + sign_z * length * 0.5)
		_ramp(Vector3(end.x, _ground(end.x, end.y + sign_z * 4.0), end.y + sign_z * 4.0), Vector3(end.x, deck_y + 0.15, end.y), 3.2, WOOD)
	var pier := c + Vector2(-place.radius * 0.6, -6.0)
	_box(Vector3(pier.x, deck_y, pier.y), Vector3(8.0, 0.3, 2.4), WOOD)
	_box(Vector3(pier.x + 6.0, -0.2, pier.y + 3.0), Vector3(1.4, 0.7, 3.2), Color("ef6f6c"))
	_chests.append(Vector3(c.x, deck_y + 0.15, c.y))
	_chests.append(Vector3(pier.x - 2.0, deck_y + 0.15, pier.y))
	for at: Vector2 in [Vector2(28, 10), Vector2(-26, 18), Vector2(20, -26), Vector2(-24, -22), Vector2(32, -8), Vector2(6, 30)]:
		_chest_at(c + at)
	# Szuwary i kamienie na brzegu.
	for i in 10:
		var angle := TAU * i / 10.0 + 0.3
		var at: Vector2 = c + Vector2.from_angle(angle) * (place.radius * 1.12)
		_block(at, Vector3(1.6, 0.9, 1.4), ROCK, angle)


## Oboz na wzgorzu: namioty, wieza obserwacyjna i ognisko. Stad widac pol mapy.
func _build_camp(place: Dictionary) -> void:
	var c: Vector2 = place.at
	for tent: Array in [[Vector2(-8, -4), 0.3, Color("2f8f83")], [Vector2(6, -7), -0.4, Color("f2a541")], [Vector2(-5, 8), 1.2, Color("5b8def")], [Vector2(9, 6), -1.0, Color("ef6f6c")]]:
		var at: Vector2 = c + tent[0]
		_block(at, Vector3(3.0, 1.6, 3.6), tent[2], tent[1])
		if not _headless:
			var y := _ground(at.x, at.y)
			var peak := LowPoly.part(_visuals, LowPoly.box(Vector3(2.4, 0.2, 3.7), 0.04), tent[2].darkened(0.15), Vector3(at.x, y + 2.0, at.y))
			peak.rotation.y = tent[1]
		_chest_at(at + Vector2(0.0, 2.6).rotated(-tent[1]))
	var tower := c + Vector2(0, -14)
	var top := _ground(tower.x, tower.y) + 5.0
	for offset: Vector2 in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		_block(tower + offset, Vector3(0.3, 5.0, 0.3), WOOD_DARK)
	_box(Vector3(tower.x, top, tower.y), Vector3(4.0, 0.25, 4.0), WOOD)
	for side: Array in [[Vector2(0, -2), Vector3(4.0, 1.0, 0.12)], [Vector2(-2, 0), Vector3(0.12, 1.0, 4.0)], [Vector2(2, 0), Vector3(0.12, 1.0, 4.0)]]:
		_box(Vector3(tower.x + side[0].x, top + 0.6, tower.y + side[0].y), side[1], WOOD_DARK)
	_ramp(Vector3(tower.x, _ground(tower.x, tower.y + 10.0), tower.y + 10.0), Vector3(tower.x, top + 0.12, tower.y + 2.0), 1.4, WOOD)
	_chests.append(Vector3(tower.x, top + 0.12, tower.y))
	_block(c, Vector3(1.4, 0.4, 1.4), STONE_DARK)
	for at: Vector2 in [Vector2(2, 2), Vector2(-12, 2)]:
		_chest_at(c + at)


## Pojedyncze skrzynki przy drogach, miedzy miejscami.
func _build_road_chests() -> void:
	for road in ValleyTerrain.ROADS:
		var a: Vector2 = ValleyTerrain.place(road[0]).at
		var b: Vector2 = ValleyTerrain.place(road[1]).at
		var at := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * 6.0
		_chest_at(at)
		_block(at + Vector2(2.0, 0.0), Vector3(1.2, 0.9, 1.2), WOOD)


## Punkty startu rozlozone po mapie: na pierscieniu i miedzy miejscami, z dala od siebie.
func _build_spawns() -> void:
	for i in 16:
		var angle := TAU * i / 16.0 + 0.2
		var at := Vector2.from_angle(angle) * 165.0
		_spawns.append(Vector3(at.x, _ground(at.x, at.y) + 0.2, at.y))
	for road in ValleyTerrain.ROADS:
		var a: Vector2 = ValleyTerrain.place(road[0]).at
		var b: Vector2 = ValleyTerrain.place(road[1]).at
		var at := a.lerp(b, 0.3)
		_spawns.append(Vector3(at.x, _ground(at.x, at.y) + 0.2, at.y))
	for spawn in _spawns:
		_clear.append({ "at": Vector2(spawn.x, spawn.z), "radius": 4.0 })


# --- Rekwizyty -------------------------------------------------------------------

## Laczy siatki rekwizytow w jedna siatke na kawalek mapy i material. Setki malych czesci
## (slupy, kola, kamienie ognisk) kosztowalyby inaczej osobne wywolanie rysowania kazda.
func _merge_visuals(from_index: int) -> void:
	if _headless:
		return
	var groups := {}
	var children := _visuals.get_children()
	for index in range(from_index, children.size()):
		var node := children[index] as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		var cell := Vector2i(floori(node.position.x / PROP_CELL), floori(node.position.z / PROP_CELL))
		# Drobne czesci, np. kola, kamyki i slupki barierek, nie rzucaja cienia.
		var large := node.mesh.get_aabb().get_longest_axis_size() > SHADOW_MIN_SIZE
		var key := [cell, node.material_override, large]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	var meshes := {}
	for key: Array in groups:
		var cell: Vector2i = key[0]
		var bucket := [cell, key[2]]
		var center := Vector3((cell.x + 0.5) * PROP_CELL, 0.0, (cell.y + 0.5) * PROP_CELL)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node: MeshInstance3D in groups[key]:
			tool.append_from(node.mesh, 0, node.transform.translated(-center))
			node.free()
		if not meshes.has(bucket):
			meshes[bucket] = ArrayMesh.new()
		var mesh: ArrayMesh = meshes[bucket]
		tool.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, key[1])
	for bucket: Array in meshes:
		var cell: Vector2i = bucket[0]
		var merged := MeshInstance3D.new()
		merged.mesh = meshes[bucket]
		merged.position = Vector3((cell.x + 0.5) * PROP_CELL, 0.0, (cell.y + 0.5) * PROP_CELL)
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bucket[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		merged.visibility_range_end = PROP_VISIBLE if bucket[1] else PROP_VISIBLE * 0.6
		merged.visibility_range_end_margin = 12.0
		merged.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_visuals.add_child(merged)


## Czy w tym miejscu mozna cos postawic: z dala od punktow startu, skrzynek i drog.
func _is_free(at: Vector2, radius: float, off_road := true) -> bool:
	for spawn in _spawns:
		if at.distance_to(Vector2(spawn.x, spawn.z)) < radius + 3.0:
			return false
	for chest in _chests:
		if at.distance_to(Vector2(chest.x, chest.z)) < radius + 1.2:
			return false
	if off_road and ValleyTerrain.road_distance(at.x, at.y) < ValleyTerrain.ROAD_WIDTH + radius:
		return false
	return at.length() < ValleyTerrain.RIM_START - radius


func _haystack(at: Vector2, rot := 0.0) -> void:
	if not _is_free(at, 1.2):
		return
	_block(at, Vector3(1.8, 1.3, 1.4), Color("e6c35c"), rot)
	_block(at, Vector3(1.6, 0.6, 1.2), Color("f0d77a"), rot, 1.3)


## Woz z drabinami: skrzynia na kolach i dyszel. Skrzynia ma kolizje, kola tylko wyglad.
func _cart(at: Vector2, rot: float, load_color := Color("e6c35c")) -> void:
	if not _is_free(at, 2.2):
		return
	var center := _block(at, Vector3(1.8, 0.9, 3.2), WOOD, rot, 0.55)
	var basis := Basis(Vector3.UP, rot)
	_box(center + Vector3.UP * 0.6, Vector3(1.5, 0.4, 2.8), load_color, rot, false)
	if _headless:
		return
	for wheel: Vector3 in [Vector3(-1.0, -0.15, -0.9), Vector3(1.0, -0.15, -0.9), Vector3(-1.0, -0.15, 0.9), Vector3(1.0, -0.15, 0.9)]:
		var mesh := LowPoly.part(_visuals, LowPoly.cylinder(0.55, 0.55, 0.15, 10), WOOD_DARK, center + basis * wheel)
		mesh.basis = basis * Basis(Vector3.FORWARD, PI * 0.5)
	var shaft := LowPoly.part(_visuals, LowPoly.box(Vector3(0.12, 0.12, 2.4), 0.03), WOOD_DARK, center + basis * Vector3(0.0, -0.3, -2.6))
	shaft.basis = basis * Basis(Vector3.RIGHT, 0.25)


func _barrel(at: Vector2, color := Color("a8784e")) -> void:
	if not _is_free(at, 0.6):
		return
	var y := _ground(at.x, at.y)
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(at.x, y + 0.5, at.y)
	_body.add_child(collision)
	if not _headless:
		LowPoly.part(_visuals, LowPoly.cylinder(0.45, 0.42, 1.0, 9), color, Vector3(at.x, y + 0.5, at.y))
		for ring_y: float in [0.2, 0.8]:
			LowPoly.part(_visuals, LowPoly.cylinder(0.47, 0.47, 0.07, 9), Color("5f5a54"), Vector3(at.x, y + ring_y, at.y))


func _crates(at: Vector2, rot := 0.0) -> void:
	if not _is_free(at, 1.4):
		return
	_block(at, Vector3(1.2, 1.2, 1.2), WOOD, rot)
	_block(at + Vector2(1.3, 0.2).rotated(-rot), Vector3(1.0, 1.0, 1.0), WOOD.lightened(0.1), rot + 0.2)
	_block(at + Vector2(0.4, 0.0).rotated(-rot), Vector3(0.9, 0.8, 0.9), WOOD_DARK, rot - 0.3, 1.2)


func _well(at: Vector2) -> void:
	if not _is_free(at, 1.8):
		return
	var y := _ground(at.x, at.y)
	for i in 8:
		var angle := TAU * i / 8.0
		var spot := at + Vector2.from_angle(angle) * 1.2
		_box(Vector3(spot.x, y + 0.45, spot.y), Vector3(1.0, 0.9, 0.4), STONE, -angle + PI * 0.5)
	_decal_box(Vector3(at.x, y + 0.6, at.y), Vector3(1.8, 0.05, 1.8), Color("2f6f8f"))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(at.x + side * 1.2, y + 1.4, at.y), Vector3(0.18, 2.8, 0.18), WOOD_DARK)
	if not _headless:
		var roof := LowPoly.part(_visuals, LowPoly.cylinder(0.0, 1.9, 0.9, 4), ROOF_RED, Vector3(at.x, y + 3.2, at.y))
		roof.rotation.y = PI * 0.25


## Wieza obserwacyjna z pomostem, barierka z trzech stron i pochylnia od strony "facing".
func _watchtower(at: Vector2, height: float, facing: float) -> void:
	if not _is_free(at, 3.0):
		return
	var y := _ground(at.x, at.y)
	var top := y + height
	for offset: Vector2 in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(-1.4, 1.4), Vector2(1.4, 1.4)]:
		var leg := at + offset.rotated(-facing)
		_block(leg, Vector3(0.3, height + (y - _ground(leg.x, leg.y)), 0.3), WOOD_DARK, facing)
	_box(Vector3(at.x, top, at.y), Vector3(3.6, 0.25, 3.6), WOOD, facing)
	var basis := Basis(Vector3.UP, facing)
	for side: Array in [[Vector3(0, 0, -1.8), Vector3(3.6, 1.0, 0.12)], [Vector3(-1.8, 0, 0), Vector3(0.12, 1.0, 3.6)], [Vector3(1.8, 0, 0), Vector3(0.12, 1.0, 3.6)]]:
		_box(Vector3(at.x, top + 0.6, at.y) + basis * (side[0] as Vector3), side[1], WOOD_DARK, facing)
	if not _headless:
		var roof := LowPoly.part(_visuals, LowPoly.cylinder(0.0, 2.8, 1.2, 4), ROOF_RED, Vector3(at.x, top + 2.6, at.y))
		roof.rotation.y = facing + PI * 0.25
		for offset: Vector2 in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(-1.4, 1.4), Vector2(1.4, 1.4)]:
			var post := at + offset.rotated(-facing)
			LowPoly.part(_visuals, LowPoly.box(Vector3(0.15, 2.0, 0.15), 0.03), WOOD_DARK, Vector3(post.x, top + 1.1, post.y))
	var foot := at + Vector2(0.0, height * 2.0 + 1.8).rotated(-facing)
	_ramp(Vector3(foot.x, _ground(foot.x, foot.y), foot.y), Vector3(at.x, top + 0.12, at.y) + basis * Vector3(0.0, 0.0, 1.6), 1.3, WOOD)


func _tent(at: Vector2, rot: float, color: Color) -> void:
	if not _is_free(at, 2.2):
		return
	_block(at, Vector3(2.6, 1.4, 3.2), color, rot)
	if not _headless:
		var y := _ground(at.x, at.y)
		var peak := LowPoly.part(_visuals, LowPoly.box(Vector3(2.1, 0.18, 3.3), 0.04), color.darkened(0.15), Vector3(at.x, y + 1.75, at.y))
		peak.rotation.y = rot
		var flap := LowPoly.part(_visuals, LowPoly.box(Vector3(0.9, 1.1, 0.05), 0.02), color.darkened(0.35), Vector3(at.x, y + 0.6, at.y) + Basis(Vector3.UP, rot) * Vector3(0.0, 0.0, 1.62))
		flap.rotation.y = rot


## Ognisko: krag kamieni, polana i zarzace sie wegle. Kolizje maja tylko klody do siedzenia.
func _campfire(at: Vector2) -> void:
	if not _is_free(at, 1.2):
		return
	var y := _ground(at.x, at.y)
	# Dwie klody do siedzenia, ktore sa tez niska oslona.
	for side: float in [-1.0, 1.0]:
		_block(at + Vector2(side * 2.0, 0.6), Vector3(0.5, 0.5, 2.0), WOOD_DARK, side * 0.3)
	if _headless:
		return
	for i in 7:
		var angle := TAU * i / 7.0
		LowPoly.part(_visuals, LowPoly.ball(0.22, 5, 3), STONE_DARK, Vector3(at.x, y + 0.1, at.y) + Vector3(cos(angle), 0.0, sin(angle)) * 0.7)
	for i in 3:
		var log_mesh := LowPoly.part(_visuals, LowPoly.box(Vector3(0.9, 0.15, 0.15), 0.03), WOOD_DARK, Vector3(at.x, y + 0.2, at.y))
		log_mesh.rotation = Vector3(0.0, TAU * i / 3.0, 0.35)
	var ember := MeshInstance3D.new()
	ember.mesh = LowPoly.ball(0.25, 6, 3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ff8a3d")
	glow.emission_enabled = true
	glow.emission = Color("ff8a3d")
	glow.emission_energy_multiplier = 2.5
	ember.material_override = glow
	ember.position = Vector3(at.x, y + 0.2, at.y)
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(ember)


func _signpost(at: Vector2, rot: float) -> void:
	if not _is_free(at, 0.5, false):
		return
	var y := _ground(at.x, at.y)
	_box(Vector3(at.x, y + 1.2, at.y), Vector3(0.18, 2.4, 0.18), WOOD_DARK, rot)
	if not _headless:
		for i in 2:
			var board := LowPoly.part(_visuals, LowPoly.box(Vector3(1.2, 0.28, 0.06), 0.02), Color("f6e3c3") if i == 0 else Color("e6c35c"), Vector3(at.x, y + 1.9 - i * 0.4, at.y))
			board.rotation.y = rot + (0.0 if i == 0 else 1.2)
			board.translate_object_local(Vector3(0.45, 0.0, 0.0))


## Slup z drewna przy drodze, jak dawna linia telegrafu.
func _pole(at: Vector2) -> void:
	if not _is_free(at, 0.4, false):
		return
	var y := _ground(at.x, at.y)
	_box(Vector3(at.x, y + 2.5, at.y), Vector3(0.22, 5.0, 0.22), WOOD_DARK)
	_decal_box(Vector3(at.x, y + 4.6, at.y), Vector3(1.4, 0.12, 0.12), WOOD_DARK)


## Chata: maly domek z drzwiami i oknem, do ktorego da sie wejsc.
func _hut(at: Vector2, rot: float, color: Color) -> void:
	if not _is_free(at, 3.5):
		return
	_house(at, Vector2(4.6, 4.0), rot, color, 0)


func _ruin_corner(at: Vector2, rot: float) -> void:
	if not _is_free(at, 3.0):
		return
	_block(at, Vector3(4.0, 2.6, 0.8), STONE, rot)
	_block(at + Vector2(-1.6, 1.6).rotated(-rot), Vector3(0.8, 1.8, 3.2), STONE_DARK, rot)
	_block(at + Vector2(1.5, 1.2).rotated(-rot), Vector3(1.0, 0.6, 1.0), STONE, rot + 0.4)


func _rock_cluster(at: Vector2) -> void:
	if not _is_free(at, 2.4):
		return
	for i in 3:
		var offset := Vector2(_rng.randf_range(-1.6, 1.6), _rng.randf_range(-1.6, 1.6))
		var size := Vector3(_rng.randf_range(1.2, 2.4), _rng.randf_range(0.9, 2.0), _rng.randf_range(1.2, 2.2))
		_block(at + offset, size, ROCK.lerp(STONE, _rng.randf()), _rng.randf() * TAU, -0.2)


func _pier(at: Vector2, rot: float, length: float) -> void:
	var basis := Basis(Vector3.UP, rot)
	var center := Vector3(at.x, 0.6, at.y) + basis * Vector3(0.0, 0.0, -length * 0.5)
	_box(center, Vector3(2.2, 0.25, length), WOOD, rot)
	for i in int(length / 2.0) + 1:
		var post := Vector3(at.x, -0.6, at.y) + basis * Vector3(0.0, 0.0, -i * 2.0)
		for side: float in [-1.0, 1.0]:
			_box(post + basis * Vector3(side * 1.0, 0.0, 0.0), Vector3(0.2, 2.2, 0.2), WOOD_DARK, rot, false)


## Wiecej zabudowy w kazdym z nazwanych miejsc: domy, wozy, stogi, wieze, namioty i ogniska.
func _build_place_props() -> void:
	var village: Vector2 = ValleyTerrain.place("village").at
	if _is_free(village + Vector2(-26.0, -18.0), 3.5):
		_house(village + Vector2(-26.0, -18.0), Vector2(5.0, 4.6), 0.4, WALLS[2], 1)
	if _is_free(village + Vector2(26.0, -20.0), 3.5):
		_house(village + Vector2(26.0, -20.0), Vector2(5.6, 4.6), -0.3, WALLS[4], 1)
	_well(village + Vector2(-8.0, 3.0))
	_cart(village + Vector2(10.0, 4.0), 0.6)
	for at: Vector2 in [Vector2(-20.0, -4.0), Vector2(-21.0, 3.0), Vector2(20.0, 22.0)]:
		_haystack(village + at, at.x * 0.1)
	for at: Vector2 in [Vector2(-10.0, -18.0), Vector2(7.0, -10.0), Vector2(-11.0, 14.0), Vector2(10.0, 18.0)]:
		_barrel(village + at)
	_crates(village + Vector2(4.0, -6.0), 0.3)
	_watchtower(village + Vector2(-28.0, 24.0), 4.5, 0.6)
	_campfire(village + Vector2(4.0, 9.0))

	var farm: Vector2 = ValleyTerrain.place("farm").at
	if _is_free(farm + Vector2(14.0, -22.0), 3.5):
		_house(farm + Vector2(14.0, -22.0), Vector2(6.0, 5.0), 0.0, WALLS[0], 0)
	_cart(farm + Vector2(-2.0, 6.0), -0.4, Color("e6c35c"))
	_cart(farm + Vector2(-14.0, 4.0), 1.2, Color("7a5236"))
	for at: Vector2 in [Vector2(2.0, -12.0), Vector2(-12.0, -14.0), Vector2(8.0, 14.0), Vector2(-8.0, 10.0)]:
		_haystack(farm + at, at.y * 0.05)
	_well(farm + Vector2(6.0, -2.0))
	_watchtower(farm + Vector2(-24.0, -24.0), 5.0, -0.8)
	for at: Vector2 in [Vector2(16.0, -12.0), Vector2(17.0, -10.8)]:
		_barrel(farm + at, Color("3a6ea5"))

	var quarry: Vector2 = ValleyTerrain.place("quarry").at
	_hut(quarry + Vector2(-20.0, -18.0), 0.5, Color("cfdcf2"))
	_watchtower(quarry + Vector2(22.0, -16.0), 5.0, 2.2)
	for at: Vector2 in [Vector2(-4.0, 10.0), Vector2(10.0, -2.0)]:
		_cart(quarry + at, at.x * 0.2, ROCK)
	_crates(quarry + Vector2(-12.0, -4.0), 0.8)
	for at: Vector2 in [Vector2(6.0, 8.0), Vector2(7.2, 8.6), Vector2(-16.0, 12.0)]:
		_barrel(quarry + at, Color("e4572e"))
	# Podklady torow wagonikow przez dno kamieniolomu.
	for i in 12:
		var spot := quarry + Vector2(-16.0 + i * 2.6, -12.0 + i * 0.9)
		_decal_box(Vector3(spot.x, _ground(spot.x, spot.y) + 0.05, spot.y), Vector3(0.4, 0.1, 1.8), WOOD_DARK, Vector3(0.0, -19.0, 0.0))

	var lake: Vector2 = ValleyTerrain.place("lake").at
	var radius: float = ValleyTerrain.place("lake").radius
	_pier(lake + Vector2(radius * 0.95, 4.0), PI * 0.5, 10.0)
	_hut(lake + Vector2(radius * 1.35, -12.0), -0.6, Color("f3d1d8"))
	for tent: Array in [[Vector2(-radius * 1.3, 8.0), 0.4, Color("f2a541")], [Vector2(-radius * 1.25, 16.0), -0.2, Color("2f8f83")]]:
		_tent(lake + tent[0], tent[1], tent[2])
	_campfire(lake + Vector2(-radius * 1.35, 0.0))
	if not _headless:
		for boat: Array in [[Vector2(10.0, -12.0), 0.7, Color("5b8def")], [Vector2(-14.0, 6.0), -0.4, Color("ffcb47")]]:
			var at: Vector2 = lake + boat[0]
			var hull := LowPoly.part(_visuals, LowPoly.box(Vector3(1.4, 0.5, 3.4), 0.12), boat[2], Vector3(at.x, ValleyTerrain.WATER_LEVEL + 0.15, at.y))
			hull.rotation.y = boat[1]

	var camp: Vector2 = ValleyTerrain.place("camp").at
	_campfire(camp + Vector2(-3.0, 1.0))
	for at: Vector2 in [Vector2(14.0, -2.0), Vector2(-14.0, -8.0)]:
		_crates(camp + at, at.x * 0.1)
	_cart(camp + Vector2(-2.0, 15.0), 1.4, Color("2f8f83"))
	for i in 9:
		# Palisada z pali od strony stoku.
		var angle := -0.6 + i * 0.16
		var spot := camp + Vector2.from_angle(angle) * 18.0
		if _is_free(spot, 0.3, false):
			_block(spot, Vector3(0.4, 2.4, 0.4), WOOD_DARK, angle)

	var ruins: Vector2 = ValleyTerrain.place("ruins").at
	for corner: Array in [[Vector2(-20.0, -18.0), 0.3], [Vector2(20.0, 6.0), -0.6], [Vector2(-22.0, 16.0), 1.1]]:
		_ruin_corner(ruins + corner[0], corner[1])
	# Luk z dwoch filarow i nadprozu.
	var arch := ruins + Vector2(0.0, -18.0)
	if _is_free(arch, 3.0):
		for side: float in [-1.6, 1.6]:
			_block(arch + Vector2(side, 0.0), Vector3(0.9, 3.4, 0.9), STONE)
		_box(Vector3(arch.x, _ground(arch.x, arch.y) + 3.7, arch.y), Vector3(4.2, 0.6, 1.0), STONE_DARK)
	for at: Vector2 in [Vector2(-14.0, -2.0), Vector2(16.0, -4.0)]:
		_rock_cluster(ruins + at)


## Przy drogach: slupy, drogowskazy na rozstajach i porzucone wozy albo skalki w polowie drogi.
func _build_roadside() -> void:
	var index := 0
	for road in ValleyTerrain.ROADS:
		var a: Vector2 = ValleyTerrain.place(road[0]).at
		var b: Vector2 = ValleyTerrain.place(road[1]).at
		var along := (b - a).normalized()
		var side := along.orthogonal()
		var length := a.distance_to(b)
		var start: float = ValleyTerrain.place(road[0]).radius + 6.0
		var finish: float = length - ValleyTerrain.place(road[1]).radius - 6.0
		var distance := start
		while distance < finish:
			_pole(a + along * distance + side * (ValleyTerrain.ROAD_WIDTH + 1.2))
			distance += 16.0
		_signpost(a + along * (start - 2.0) - side * (ValleyTerrain.ROAD_WIDTH + 1.0), atan2(-along.y, along.x))
		var middle := a.lerp(b, 0.62) - side * (ValleyTerrain.ROAD_WIDTH + 3.5)
		if index % 2 == 0:
			_cart(middle, atan2(-along.y, along.x) + 0.4, Color("7a5236"))
		else:
			_rock_cluster(middle)
		index += 1


## Male punkty miedzy miejscami: obozowisko, chata, ruina, skalki albo wieza z jedna albo dwiema
## skrzynkami. Kazdy daje oslone na otwartym polu.
func _build_outposts() -> void:
	for outpost: Array in OUTPOSTS:
		var at: Vector2 = outpost[0]
		if not _is_free(at, 5.0):
			continue
		_clear.append({ "at": at, "radius": 7.0 })
		match outpost[1]:
			"camp":
				_tent(at + Vector2(-2.5, 0.0), 0.3, Color("ef6f6c"))
				_campfire(at + Vector2(2.5, 1.5))
				_chest_at(at + Vector2(0.5, -3.0))
			"hut":
				_hut(at, at.x * 0.01, WALLS[absi(int(at.y)) % WALLS.size()])
				_chest_at(at, 0.2)
				_barrel(at + Vector2(3.6, 1.0))
			"ruin":
				_ruin_corner(at, at.y * 0.02)
				_chest_at(at + Vector2(0.6, 3.0))
			"rocks":
				_rock_cluster(at)
				_chest_at(at + Vector2(3.4, 0.0))
			"tower":
				_watchtower(at, 4.0, 0.0)
				_chest_at(at + Vector2(3.0, -3.0))


# --- Roslinnosc --------------------------------------------------------------

## Drzewa, krzaki i kepy trawy jako MultiMesh w kawalkach mapy. Pnie maja kolizje.
func _build_vegetation() -> void:
	var trees: Array[Transform3D] = []
	var pines: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 14000:
		var at := Vector2(rng.randf_range(-ValleyTerrain.RADIUS, ValleyTerrain.RADIUS), rng.randf_range(-ValleyTerrain.RADIUS, ValleyTerrain.RADIUS))
		var roll := rng.randf()
		var distance := at.length()
		if distance > ValleyTerrain.RADIUS + 18.0 or _is_cleared(at, 0.0) or ValleyTerrain.road_distance(at.x, at.y) < ValleyTerrain.ROAD_WIDTH + 1.5:
			continue
		var y := _ground(at.x, at.y)
		if y < ValleyTerrain.WATER_LEVEL + 0.3:
			continue
		# Las gestnieje w pasach miedzy miejscami, a polany zostaja puste.
		var forest := sin(at.x * 0.018 + 0.7) * cos(at.y * 0.021 - 0.3) + 0.25
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		var scale := rng.randf_range(0.8, 1.35)
		var transform := Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(at.x, y, at.y))
		if roll < 0.4 and forest > -0.15:
			(pines if rng.randf() < 0.5 else trees).append(transform)
			if distance < ValleyTerrain.RADIUS:
				_tree_collision(Vector3(at.x, y, at.y))
		elif roll < 0.55:
			bushes.append(transform)
		else:
			grass.append(transform)
	if _headless:
		return
	_scatter(trees, _round_tree_parts(), TREE_VISIBLE)
	_scatter(pines, _pine_parts(), TREE_VISIBLE)
	_scatter(bushes, [[LowPoly.ball(0.8, 7, 4), Color("5a9a3e"), Vector3(0, 0.45, 0)]], BUSH_VISIBLE)
	_scatter(grass, [[LowPoly.cylinder(0.0, 0.18, 0.7, 4), Color("7cbf52"), Vector3(0, 0.3, 0)]], GRASS_VISIBLE)
	_build_ground_clutter()


## Drobnica bez kolizji: kwiaty, kamyki i male krzaczki, takze w miejscach, gdzie nie rosna drzewa.
## Kwiaty w trzech kolorach to jeden MultiMesh z kolorem egzemplarza, a calosc ma wieksze kawalki
## i krotki zasieg widocznosci, wiec dodaje tylko kilka wywolan rysowania.
func _build_ground_clutter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var pebbles: Array[Transform3D] = []
	var shrubs: Array[Transform3D] = []
	var palette: Array[Color] = [Color("f7d154"), Color("f78fb3"), Color("f4f1ea")]
	for i in 7000:
		var at := Vector2(rng.randf_range(-ValleyTerrain.RIM_START, ValleyTerrain.RIM_START), rng.randf_range(-ValleyTerrain.RIM_START, ValleyTerrain.RIM_START))
		if at.length() > ValleyTerrain.RIM_START or ValleyTerrain.road_distance(at.x, at.y) < ValleyTerrain.ROAD_WIDTH:
			continue
		var y := _ground(at.x, at.y)
		if y < ValleyTerrain.WATER_LEVEL + 0.2:
			continue
		var transform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(at.x, y, at.y))
		var roll := rng.randf()
		# Kwiaty rosna kepami na lakach, a kamyki i krzaczki wszedzie.
		var meadow := sin(at.x * 0.05) * cos(at.y * 0.04)
		if roll < 0.55 and meadow > 0.1:
			var color := palette[i % palette.size()]
			for j in 3:
				var offset := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
				flowers.append(Transform3D(transform.basis, transform.origin + offset))
				flower_colors.append(color)
		elif roll < 0.8:
			pebbles.append(transform)
		else:
			shrubs.append(transform)
	_scatter_colored(flowers, flower_colors, LowPoly.ball(0.1, 5, 3), Vector3(0, 0.22, 0), CLUTTER_VISIBLE)
	_scatter(pebbles, [[LowPoly.box(Vector3(0.4, 0.22, 0.32), 0.08), STONE, Vector3(0, 0.08, 0)]], CLUTTER_VISIBLE, CLUTTER_CELL)
	_scatter(shrubs, [[LowPoly.ball(0.45, 6, 4), Color("6fae4a"), Vector3(0, 0.25, 0)]], CLUTTER_VISIBLE + 15.0, CLUTTER_CELL)


## Jak _scatter, ale kazdy egzemplarz ma wlasny kolor, np. kwiaty roznych barw w jednym MultiMesh.
func _scatter_colored(transforms: Array[Transform3D], colors: Array[Color], mesh: Mesh, offset: Vector3, visible_range: float) -> void:
	var cells := {}
	for index in transforms.size():
		var origin := transforms[index].origin
		var key := Vector2i(floori(origin.x / CLUTTER_CELL), floori(origin.z / CLUTTER_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(index)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	for key: Vector2i in cells:
		var list: Array = cells[key]
		var center := Vector3((key.x + 0.5) * CLUTTER_CELL, 0.0, (key.y + 0.5) * CLUTTER_CELL)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = list.size()
		for slot in list.size():
			var transform: Transform3D = transforms[list[slot]]
			multimesh.set_instance_transform(slot, Transform3D(transform.basis, transform.origin - center + transform.basis * offset))
			multimesh.set_instance_color(slot, colors[list[slot]])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.position = center
		instance.visibility_range_end = visible_range
		instance.visibility_range_end_margin = 8.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visuals.add_child(instance)


func _is_cleared(at: Vector2, margin: float) -> bool:
	for area in _clear:
		if at.distance_to(area.at) < area.radius + margin:
			return true
	return false


func _tree_collision(base: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = TREE_COLLISION_RADIUS
	shape.height = 5.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * 2.5
	_body.add_child(collision)


func _round_tree_parts() -> Array:
	return [
		[LowPoly.cylinder(0.2, 0.32, 3.0, 6), Color("8b5a3c"), Vector3(0, 1.5, 0)],
		[LowPoly.ball(1.8, 8, 5), Color("5fae4a"), Vector3(0, 3.8, 0)],
	]


func _pine_parts() -> Array:
	return [
		[LowPoly.cylinder(0.16, 0.26, 2.0, 6), Color("7a4e34"), Vector3(0, 1.0, 0)],
		[LowPoly.cylinder(0.0, 1.8, 3.2, 7), Color("3f8a4a"), Vector3(0, 3.3, 0)],
		[LowPoly.cylinder(0.0, 1.3, 2.4, 7), Color("4a9a52"), Vector3(0, 4.9, 0)],
	]


## Rozdziela egzemplarze na kawalki mapy, zeby dalekie kawalki mozna bylo pomijac w rysowaniu.
func _scatter(transforms: Array[Transform3D], parts: Array, visible_range: float, size := 64.0) -> void:
	var cells := {}
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
			instance.visibility_range_end = visible_range
			instance.visibility_range_end_margin = 12.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if visible_range < 60.0:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_visuals.add_child(instance)


# --- Punkty ------------------------------------------------------------------

func _build_markers() -> void:
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	add_child(spawns)
	for i in _spawns.size():
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = _spawns[i]
		marker.add_to_group(&"spawn_points")
		spawns.add_child(marker)
	var chests := Node3D.new()
	chests.name = "ChestSpots"
	add_child(chests)
	for i in _chests.size():
		var marker := Marker3D.new()
		marker.name = "Chest%d" % (i + 1)
		marker.position = _chests[i]
		marker.rotation.y = _rng.randf() * TAU
		marker.add_to_group(&"chest_spots")
		chests.add_child(marker)
