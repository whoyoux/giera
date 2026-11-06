class_name ZoneView
extends MeshInstance3D
## Polprzezroczysta sciana strefy. Promien i srodek liczy Match, wiec tu jest tylko wyglad.

const WALL_HEIGHT := 60.0
const WALL_BOTTOM := -6.0
const SEGMENTS := 96
const MIN_RADIUS := 0.05
const SHADER := preload("res://shaders/zone_wall.gdshader")


func _ready() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = WALL_HEIGHT
	cylinder.radial_segments = SEGMENTS
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	mesh = cylinder
	var wall := ShaderMaterial.new()
	wall.shader = SHADER
	material_override = wall
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(_delta: float) -> void:
	var state := Match.zone_state()
	visible = not state.is_empty() and state.radius > MIN_RADIUS
	if not visible:
		return
	var center: Vector2 = state.center
	position = Vector3(center.x, WALL_BOTTOM + WALL_HEIGHT * 0.5, center.y)
	scale = Vector3(state.radius, 1.0, state.radius)
