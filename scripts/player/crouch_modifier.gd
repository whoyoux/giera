class_name CrouchModifier
extends SkeletonModifier3D
## Poza kucania liczona kodem, juz po zastosowaniu animacji: biodra opadaja, tulow lekko sie
## pochyla, a nogi ugina odwrotna kinematyka, wiec stopy zostaja tam, gdzie ustawil je bieg.

## O tyle opadaja biodra w jednostkach szkieletu. Postac jest skalowana, wiec to okolo 0,45 m.
const DROP := 0.58
const LEAN := deg_to_rad(14.0)
## Kolana ida do przodu i troche na zewnatrz.
const KNEE_OUTWARD := 0.35

## 0 na stojaco, 1 w pelnym kucnieciu.
var amount := 0.0

var _hips := -1
var _legs: Array[Array] = []


func _ready() -> void:
	var skeleton := get_skeleton()
	_hips = skeleton.find_bone("hips")
	for side: String in ["l", "r"]:
		_legs.append([skeleton.find_bone("upperleg." + side), skeleton.find_bone("lowerleg." + side), skeleton.find_bone("foot." + side), 1.0 if side == "l" else -1.0])


func _process_modification_with_delta(_delta: float) -> void:
	if amount <= 0.001 or _hips < 0:
		return
	var skeleton := get_skeleton()
	var feet: Array[Transform3D] = []
	for leg: Array in _legs:
		feet.append(skeleton.get_bone_global_pose(leg[2]))
	var hips_pose := skeleton.get_bone_global_pose(_hips)
	hips_pose.origin += Vector3.DOWN * DROP * amount
	hips_pose.basis = Basis(Vector3.RIGHT, LEAN * amount) * hips_pose.basis
	skeleton.set_bone_global_pose(_hips, hips_pose)
	for index in _legs.size():
		_solve_leg(skeleton, _legs[index], feet[index])


## Dwie kosci nogi tak, zeby kostka wrocila na swoje miejsce, a stopa zachowala obrot.
func _solve_leg(skeleton: Skeleton3D, leg: Array, foot: Transform3D) -> void:
	var upper_pose := skeleton.get_bone_global_pose(leg[0])
	var lower_pose := skeleton.get_bone_global_pose(leg[1])
	var ankle_pose := skeleton.get_bone_global_pose(leg[2])
	var hip := upper_pose.origin
	var thigh := hip.distance_to(lower_pose.origin)
	var shin := lower_pose.origin.distance_to(ankle_pose.origin)
	var to_target := foot.origin - hip
	var distance := clampf(to_target.length(), absf(thigh - shin) + 0.001, thigh + shin - 0.001)
	var aim := to_target.normalized()
	var along := (thigh * thigh - shin * shin + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(thigh * thigh - along * along, 0.0))
	var pole := Vector3(leg[3] * KNEE_OUTWARD, 0.0, 1.0)
	var knee := hip + aim * along + (pole - aim * pole.dot(aim)).normalized() * height
	upper_pose.basis = Basis(_arc(lower_pose.origin - hip, knee - hip)) * upper_pose.basis
	skeleton.set_bone_global_pose(leg[0], upper_pose)
	lower_pose = skeleton.get_bone_global_pose(leg[1])
	ankle_pose = skeleton.get_bone_global_pose(leg[2])
	lower_pose.basis = Basis(_arc(ankle_pose.origin - lower_pose.origin, hip + aim * distance - lower_pose.origin)) * lower_pose.basis
	skeleton.set_bone_global_pose(leg[1], lower_pose)
	ankle_pose = skeleton.get_bone_global_pose(leg[2])
	ankle_pose.basis = foot.basis
	skeleton.set_bone_global_pose(leg[2], ankle_pose)


func _arc(from: Vector3, to: Vector3) -> Quaternion:
	return Quaternion(from.normalized(), to.normalized())
