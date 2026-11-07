@tool
class_name ForestTerrain
extends StaticBody3D
## Ziemia lesnej mapy: plaska polana, wzgorze, strumien i wysokie zbocza na krawedzi.
## Wysokosc wynika ze wzoru, wiec serwer i klienci maja taka sama kolizje.
## Ten sam wzor jest w tools/generate_forest.py i obie wersje musza sie zgadzac.

## Rodzaj podloza pod stopami, od ktorego zalezy dzwiek kroku.
## Beton i metal wystepuja na innych mapach, np. w miasteczku.
enum Ground { GRASS, DIRT, STONE, WATER, CONCRETE, METAL }

const CELL := 2.5
const HALF_CELLS := 46
## Dalej kolizja nie jest potrzebna, bo gracza zatrzymuje wczesniej granica mapy.
const COLLISION_RADIUS := 62.0
const BORDER_RADIUS := 50.0
const BORDER_SEGMENTS := 20
const BORDER_HEIGHT := 60.0
const BORDER_THICKNESS := 2.0
const WATER_LEVEL := -0.75

const CLEARING_INNER := 26.0
const CLEARING_OUTER := 39.0
const RIM_INNER := 43.0
const RIM_OUTER := 57.0
const RIM_HEIGHT := 9.0
const HILL_CENTER := Vector2(24.0, -24.0)
const HILL_HEIGHT := 4.0
const HILL_WIDTH := 8.0
const CREEK_DEPTH := 1.2
const CREEK_INNER := 1.2
const CREEK_OUTER := 3.2
const CREEK_Z := 32.0
const CREEK_WAVE := 6.5
const CREEK_FREQUENCY := 0.1

const GRASS := Color("5f9438")
const GRASS_LIGHT := Color("6da342")
const FOREST_FLOOR := Color("4c7c2f")
const RIM_GRASS := Color("3f6a2a")
const DIRT := Color("94744a")
const CREEK_BED := Color("a3925f")
const WATER := Color(0.36, 0.66, 0.82, 0.72)
const PATH_WIDTH := 1.6
const PATH_RADIUS := 40.0
const FOREST_FLOOR_START := 29.0
const RUIN_DIRT_RADIUS := 9.5
## Wyzej nad ziemia gracz stoi juz na kamieniach ruin albo skalach.
const STANDING_ON_STONE_HEIGHT := 0.35
## Od tej glebokosci stopa jest w wodzie.
const WATER_STEP_MARGIN := 0.25


static func height(x: float, z: float) -> float:
	var distance := sqrt(x * x + z * z)
	var noise := sin(x * 0.21 + 1.3) * cos(z * 0.17 - 0.7) * 0.5 + sin(x * 0.07 - z * 0.11) * 0.6
	var y := noise * smoothstep(CLEARING_INNER, CLEARING_OUTER, distance)
	y += RIM_HEIGHT * smoothstep(RIM_INNER, RIM_OUTER, distance)
	var hill := Vector2(x, z).distance_to(HILL_CENTER) / HILL_WIDTH
	y += HILL_HEIGHT * exp(-hill * hill)
	y -= CREEK_DEPTH * (1.0 - smoothstep(CREEK_INNER, CREEK_OUTER, creek_distance(x, z))) * (1.0 - smoothstep(RIM_INNER, RIM_OUTER, distance))
	return y


static func creek_distance(x: float, z: float) -> float:
	return absf(z - creek_center_z(x))


static func creek_center_z(x: float) -> float:
	return CREEK_Z + CREEK_WAVE * sin(x * CREEK_FREQUENCY)


## Podloze pod stopami w danym miejscu.
static func ground_at(feet: Vector3) -> Ground:
	var floor_y := surface(feet.x, feet.z)
	if feet.y - floor_y > STANDING_ON_STONE_HEIGHT:
		return Ground.STONE
	if floor_y < WATER_LEVEL + WATER_STEP_MARGIN:
		return Ground.WATER
	if Vector2(feet.x, feet.z).length() < RUIN_DIRT_RADIUS or is_path(feet.x, feet.z):
		return Ground.DIRT
	return Ground.GRASS


## Wysokosc na trojkatach siatki, czyli dokladnie tam, gdzie stoi gracz.
static func surface(x: float, z: float) -> float:
	var cell_x := floorf(x / CELL)
	var cell_z := floorf(z / CELL)
	var u := x / CELL - cell_x
	var v := z / CELL - cell_z
	var x0 := cell_x * CELL
	var z0 := cell_z * CELL
	var near := height(x0 + CELL, z0)
	var far := height(x0, z0 + CELL)
	if u + v <= 1.0:
		var origin := height(x0, z0)
		return origin + (near - origin) * u + (far - origin) * v
	var corner := height(x0 + CELL, z0 + CELL)
	return corner + (far - corner) * (1.0 - u) + (near - corner) * (1.0 - v)


## Sciezki biegna od ruin na polnoc, wschod i zachod.
static func is_path(x: float, z: float) -> bool:
	if Vector2(x, z).length() > PATH_RADIUS:
		return false
	if z < 0.0 and absf(x - 2.0 * sin(z * 0.2)) < PATH_WIDTH:
		return true
	if x > 0.0 and absf(z - 2.0 * sin(x * 0.17)) < PATH_WIDTH:
		return true
	return x < 0.0 and absf(z - 1.5 * sin(x * 0.23)) < PATH_WIDTH


func _ready() -> void:
	_build_ground()
	_build_border()
	if DisplayServer.get_name() == "headless" and not Engine.is_editor_hint():
		return
	_build_water()
	var scatter := ForestScatter.new()
	add_child(scatter)
	if not Engine.is_editor_hint():
		add_child(ForestAmbience.new())


func _build_ground() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var headless := DisplayServer.get_name() == "headless" and not Engine.is_editor_hint()
	for i in range(-HALF_CELLS, HALF_CELLS):
		for j in range(-HALF_CELLS, HALF_CELLS):
			var x0 := i * CELL
			var z0 := j * CELL
			var a := _vertex(x0, z0)
			var b := _vertex(x0 + CELL, z0)
			var c := _vertex(x0, z0 + CELL)
			var d := _vertex(x0 + CELL, z0 + CELL)
			var collides := Vector2(x0, z0).length() < COLLISION_RADIUS
			for triangle: Array in [[a, b, c], [b, d, c]]:
				if collides:
					faces.append_array(PackedVector3Array(triangle))
				if not headless:
					_add_face(surface_tool, triangle)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	if headless:
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	surface_tool.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface_tool.commit()
	add_child(mesh)


func _vertex(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


## Kazdy trojkat ma wlasny kolor i normalna, co daje kanciasty wyglad.
func _add_face(tool: SurfaceTool, triangle: Array) -> void:
	var center: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
	var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
	tool.set_color(_ground_color(center, normal))
	tool.set_normal(normal)
	for corner: Vector3 in triangle:
		tool.add_vertex(corner)


func _ground_color(center: Vector3, normal: Vector3) -> Color:
	var distance := Vector2(center.x, center.z).length()
	var color := GRASS.lerp(GRASS_LIGHT, (sin(center.x * 1.7) * cos(center.z * 1.3) + 1.0) * 0.5)
	color = color.lerp(FOREST_FLOOR, smoothstep(FOREST_FLOOR_START, CLEARING_OUTER, distance))
	color = color.lerp(RIM_GRASS, smoothstep(RIM_INNER, RIM_OUTER, distance))
	if distance < RUIN_DIRT_RADIUS or is_path(center.x, center.z):
		color = DIRT
	if creek_distance(center.x, center.z) < CREEK_OUTER - 0.4 and distance < RIM_OUTER:
		color = CREEK_BED
	return color.darkened(clampf((1.0 - normal.y) * 0.8, 0.0, 0.25))


## Niewidoczna granica, zeby nikt nie wszedl na zbocza poza mape.
func _build_border() -> void:
	var length := TAU * BORDER_RADIUS / BORDER_SEGMENTS * 1.1
	for index in BORDER_SEGMENTS:
		var angle := TAU * index / BORDER_SEGMENTS
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, BORDER_HEIGHT, BORDER_THICKNESS)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(sin(angle), 0.0, cos(angle)) * (BORDER_RADIUS + BORDER_THICKNESS * 0.5)
		collision.position.y = BORDER_HEIGHT * 0.5
		collision.rotation.y = angle
		add_child(collision)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(156.0, 52.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	material.metallic_specular = 0.7
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(0.0, WATER_LEVEL, CREEK_Z)
	add_child(water)
