class_name LowPoly
extends RefCounted
## Fabryka prostych, kreskowkowych siatek i materialow.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

static var _materials := {}


static func material(color: Color, outline_width := 0.02) -> ShaderMaterial:
	var key := "%s/%f" % [color.to_html(), outline_width]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", color)
	if outline_width > 0.0:
		var hull := ShaderMaterial.new()
		hull.shader = OUTLINE
		hull.set_shader_parameter("width", outline_width)
		mat.next_pass = hull
	_materials[key] = mat
	return mat


static func glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cylinder(top: float, bottom: float, height: float, sides := 7) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func ball(radius: float, sides := 7, rings := 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = rings
	return mesh


## Dodaje wycentrowana siatke jako dziecko wezla.
static func part(parent: Node3D, mesh: Mesh, color: Color, at := Vector3.ZERO, rot_deg := Vector3.ZERO, outline_width := 0.02) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, outline_width)
	node.position = at
	node.rotation_degrees = rot_deg
	parent.add_child(node)
	return node


## Buduje kreskowkowy blaster skierowany w -Z. Zwraca wezel wylotu lufy.
static func build_gun(parent: Node3D) -> Node3D:
	var w := 0.012
	part(parent, box(Vector3(0.1, 0.13, 0.34)), Color("f2994a"), Vector3.ZERO, Vector3.ZERO, w)
	part(parent, box(Vector3(0.06, 0.06, 0.2)), Color("3d3a50"), Vector3(0, 0.01, -0.26), Vector3.ZERO, w)
	part(parent, box(Vector3(0.095, 0.095, 0.05)), Color("2ec4b6"), Vector3(0, 0.01, -0.35), Vector3.ZERO, w)
	part(parent, box(Vector3(0.07, 0.15, 0.08)), Color("3d3a50"), Vector3(0, -0.12, 0.1), Vector3(18, 0, 0), w)
	part(parent, box(Vector3(0.05, 0.05, 0.12)), Color("2ec4b6"), Vector3(0, 0.09, -0.02), Vector3.ZERO, w)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.01, -0.4)
	parent.add_child(muzzle)
	return muzzle
