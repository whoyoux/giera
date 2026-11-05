@tool
class_name PlayerModel
extends Node3D
## Kreskowkowa postac dla innych graczy. Animacje sa proceduralne i kazdy klient
## wylicza je z predkosci, wiec nie trzeba ich przesylac przez siec.

const PALETTE: Array[Color] = [
	Color("e8505b"), Color("3a86ff"), Color("f9a03f"), Color("7bc950"),
	Color("b56dff"), Color("2ec4b6"), Color("ff7eb6"), Color("f5d547"),
]
const SKIN := Color("ffd9b3")
const DARK := Color("3d3a50")

var _color := PALETTE[0]
var _time := 0.0
var _recoil := 0.0
var _death := 0.0
var _body: Node3D
var _head: Node3D
var _arm_right: Node3D
var _arm_left: Node3D
var _leg_right: Node3D
var _leg_left: Node3D
var _muzzle: Node3D


static func color_for(peer_id: int) -> Color:
	return PALETTE[absi(hash(peer_id)) % PALETTE.size()]


func _ready() -> void:
	_build()


func set_color(color: Color) -> void:
	_color = color
	_build()


func kick() -> void:
	_recoil = 1.0


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position


func update_pose(delta: float, speed_ratio: float, on_floor: bool, pitch: float, dead: bool) -> void:
	if _body == null:
		return
	_time += delta * lerpf(4.0, 12.0, clampf(speed_ratio, 0.0, 1.0))
	_recoil = move_toward(_recoil, 0.0, delta * 7.0)
	_death = move_toward(_death, 1.0 if dead else 0.0, delta * 4.0)

	var swing := sin(_time) * 0.8 * clampf(speed_ratio, 0.0, 1.0)
	if on_floor:
		_leg_right.rotation.x = swing
		_leg_left.rotation.x = -swing
		_arm_left.rotation.x = 1.1 - swing * 0.2
	else:
		_leg_right.rotation.x = 0.5
		_leg_left.rotation.x = -0.35
		_arm_left.rotation.x = 1.4

	_body.position.y = absf(sin(_time)) * 0.05 * speed_ratio + sin(_time * 0.5) * 0.015
	_head.rotation.x = pitch * 0.7
	_arm_right.rotation.x = PI * 0.5 + pitch + _recoil * 0.35
	rotation.x = _death * PI * 0.5
	position.y = _death * 0.3


func _build() -> void:
	for child in get_children():
		child.free()
	_body = Node3D.new()
	add_child(_body)

	_leg_right = _limb(Vector3(0.14, 0.8, 0), Vector3(0.2, 0.8, 0.24), DARK)
	_leg_left = _limb(Vector3(-0.14, 0.8, 0), Vector3(0.2, 0.8, 0.24), DARK)
	_arm_right = _limb(Vector3(0.38, 1.32, 0), Vector3(0.16, 0.62, 0.18), _color)
	_arm_left = _limb(Vector3(-0.38, 1.32, 0), Vector3(0.16, 0.62, 0.18), _color)
	LowPoly.part(_body, LowPoly.box(Vector3(0.58, 0.68, 0.34)), _color, Vector3(0, 1.08, 0), Vector3.ZERO, 0.025)

	_head = Node3D.new()
	_head.position = Vector3(0, 1.45, 0)
	_body.add_child(_head)
	LowPoly.part(_head, LowPoly.ball(0.3, 7, 4), SKIN, Vector3(0, 0.12, 0), Vector3.ZERO, 0.02)
	LowPoly.part(_head, LowPoly.box(Vector3(0.09, 0.13, 0.04)), DARK, Vector3(0.11, 0.15, -0.27), Vector3.ZERO, 0.0)
	LowPoly.part(_head, LowPoly.box(Vector3(0.09, 0.13, 0.04)), DARK, Vector3(-0.11, 0.15, -0.27), Vector3.ZERO, 0.0)
	LowPoly.part(_head, LowPoly.cylinder(0.32, 0.34, 0.1, 7), _color.darkened(0.2), Vector3(0, 0.3, 0), Vector3.ZERO, 0.015)

	var gun := Node3D.new()
	gun.position = Vector3(0, -0.62, -0.05)
	gun.rotation.x = -PI * 0.5
	gun.scale = Vector3.ONE * 0.9
	_arm_right.add_child(gun)
	_muzzle = LowPoly.build_gun(gun)


func _limb(pivot: Vector3, size: Vector3, color: Color) -> Node3D:
	var limb := Node3D.new()
	limb.position = pivot
	_body.add_child(limb)
	LowPoly.part(limb, LowPoly.box(size), color, Vector3(0, -size.y * 0.5, 0), Vector3.ZERO, 0.02)
	return limb
