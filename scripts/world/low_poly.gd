class_name LowPoly
extends RefCounted
## Fabryka siatek i materialow w stylu plastikowych zabawek: scianki sa plaskie,
## krawedzie klockow fazowane, a powierzchnia lekko sie blyszczy.

static var _materials := {}


static func material(color: Color, roughness := 0.5) -> StandardMaterial3D:
	var key := "%s/%f" % [color.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = 0.45
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	_materials[key] = mat
	return mat


static func glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


## Prostopadloscian ze sfazowanymi krawedziami, ktore lapia swiatlo jak zabawka.
static func box(size: Vector3, bevel := 0.07) -> ArrayMesh:
	var half := size * 0.5
	var b := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.8)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var corner := func(sx: float, sy: float, sz: float, axis: int) -> Vector3:
		var p := Vector3(sx * (half.x - b), sy * (half.y - b), sz * (half.z - b))
		p[axis] = [sx, sy, sz][axis] * half[axis]
		return p
	var signs: Array[float] = [-1.0, 1.0]

	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for s in signs:
			var quad: Array[Vector3] = []
			for pair: Array in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var sv := Vector3.ZERO
				sv[axis] = s
				sv[u] = pair[0]
				sv[v] = pair[1]
				quad.append(corner.call(sv.x, sv.y, sv.z, axis))
			_add_polygon(verts, normals, quad)

	for along in 3:
		var a1 := (along + 1) % 3
		var a2 := (along + 2) % 3
		for s1 in signs:
			for s2 in signs:
				var quad: Array[Vector3] = []
				for step: Array in [[-1.0, a1], [1.0, a1], [1.0, a2], [-1.0, a2]]:
					var sv := Vector3.ZERO
					sv[along] = step[0]
					sv[a1] = s1
					sv[a2] = s2
					quad.append(corner.call(sv.x, sv.y, sv.z, step[1]))
				_add_polygon(verts, normals, quad)

	for sx in signs:
		for sy in signs:
			for sz in signs:
				var tri: Array[Vector3] = [corner.call(sx, sy, sz, 0), corner.call(sx, sy, sz, 1), corner.call(sx, sy, sz, 2)]
				_add_polygon(verts, normals, tri)

	return _mesh_from(verts, normals)


static func cylinder(top: float, bottom: float, height: float, sides := 8) -> ArrayMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return faceted(mesh)


static func ball(radius: float, sides := 10, rings := 6) -> ArrayMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = rings
	return faceted(mesh)


static func ring(inner: float, outer: float, sides := 12) -> ArrayMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = sides
	mesh.ring_segments = 6
	return faceted(mesh)


## Zamienia wygladzona bryle na plaskie scianki.
static func faceted(source: PrimitiveMesh) -> ArrayMesh:
	var arrays := source.get_mesh_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		var a := positions[indices[i]]
		var b := positions[indices[i + 1]]
		var c := positions[indices[i + 2]]
		var normal := (c - a).cross(b - a)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		verts.append_array([a, b, c])
		normals.append_array([normal, normal, normal])
	return _mesh_from(verts, normals)


## Dodaje siatke jako dziecko wezla.
static func part(parent: Node3D, mesh: Mesh, color: Color, at := Vector3.ZERO, rot_deg := Vector3.ZERO, roughness := 0.5) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, roughness)
	node.position = at
	node.rotation_degrees = rot_deg
	parent.add_child(node)
	return node


static func _add_polygon(verts: PackedVector3Array, normals: PackedVector3Array, points: Array[Vector3]) -> void:
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= points.size()
	for i in range(1, points.size() - 1):
		var a := points[0]
		var b := points[i]
		var c := points[i + 1]
		var normal := (b - a).cross(c - a).normalized()
		# Godot traktuje trojkaty zgodne ze wskazowkami zegara jako przednie.
		if normal.dot(center) > 0.0:
			var swap := b
			b = c
			c = swap
		else:
			normal = -normal
		verts.append_array([a, b, c])
		normals.append_array([normal, normal, normal])


static func _mesh_from(verts: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
