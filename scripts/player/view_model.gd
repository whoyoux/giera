class_name ViewModel
extends Node3D
## Bron widoczna w pierwszej osobie: odrzut, kolysanie w marszu i blysk z lufy.

const BASE_POSITION := Vector3(0.27, -0.25, -0.56)

var _gun: Node3D
var _muzzle: Node3D
var _flash: MeshInstance3D
var _time := 0.0
var _recoil := 0.0
var _flash_time := 0.0
var _death := 0.0


func _ready() -> void:
	_gun = Node3D.new()
	add_child(_gun)
	_muzzle = LowPoly.build_gun(_gun)
	LowPoly.part(_gun, LowPoly.box(Vector3(0.1, 0.1, 0.1)), PlayerModel.SKIN, Vector3(0, -0.14, 0.11), Vector3(18, 0, 0), 0.012)
	LowPoly.part(_gun, LowPoly.box(Vector3(0.1, 0.1, 0.3)), Color("3a86ff"), Vector3(0.015, -0.21, 0.27), Vector3(-24, 0, 0), 0.012)
	_flash = MeshInstance3D.new()
	_flash.mesh = LowPoly.ball(0.09, 5, 2)
	_flash.material_override = LowPoly.glow(Color("fff3a3"))
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_muzzle.add_child(_flash)


func kick() -> void:
	_recoil = 1.0
	_flash_time = 0.05
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.9, 1.5)


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func update_pose(delta: float, speed_ratio: float, on_floor: bool, dead: bool) -> void:
	_time += delta * 10.0
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)
	_death = move_toward(_death, 1.0 if dead else 0.0, delta * 3.0)
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false

	var bob := speed_ratio if on_floor else 0.0
	var offset := Vector3(sin(_time) * 0.012 * bob, absf(cos(_time)) * 0.012 * bob, 0.0)
	var recoil_curve := _recoil * _recoil
	_gun.position = BASE_POSITION + offset + Vector3(0.0, 0.0, recoil_curve * 0.08) + Vector3.DOWN * _death * 0.5
	_gun.rotation.x = recoil_curve * 0.22
