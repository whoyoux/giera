class_name AvatarTag
extends MeshInstance3D
## Zdjecie gracza nad jego nazwa. Bez zdjecia jest ukryte, bo sama nazwa wystarczy.

const SHADER := preload("res://shaders/avatar_tag.gdshader")
const SIDE := 0.36

var _steam_id := 0
var _material: ShaderMaterial


func _init(steam_id: int) -> void:
	_steam_id = steam_id
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIDE
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _ready() -> void:
	SteamAccount.avatar_ready.connect(_on_avatar_ready)
	_show_picture()


func _on_avatar_ready(id: int) -> void:
	if id == _steam_id:
		_show_picture()


func _show_picture() -> void:
	var texture := SteamAccount.avatar(_steam_id)
	_material.set_shader_parameter("picture", texture)
	visible = texture != null
