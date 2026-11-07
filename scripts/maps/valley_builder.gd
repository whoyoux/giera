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
	_build_ruins(ValleyTerrain.place("ruins"))
	_build_village(ValleyTerrain.place("village"))
	_build_farm(ValleyTerrain.place("farm"))
	_build_quarry(ValleyTerrain.place("quarry"))
	_build_lake(ValleyTerrain.place("lake"))
	_build_camp(ValleyTerrain.place("camp"))
	_build_road_chests()
	_build_spawns()
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
func _scatter(transforms: Array[Transform3D], parts: Array, visible_range: float) -> void:
	var cells := {}
	var size := 64.0
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
