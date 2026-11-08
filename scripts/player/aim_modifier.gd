class_name AimModifier
extends SkeletonModifier3D
## Dopasowuje gorna czesc ciala do celowania, juz po zastosowaniu animacji.
## Animacja z paczki trzyma bron skosem, wiec obracamy tulow, by lufa patrzyla
## na wprost, a glowe obracamy z powrotem, by postac nadal patrzyla przed siebie.

const STANCE_TWIST := deg_to_rad(38.0)
## Szarpniecie po strzale: najwyzej tyle radianow i tak szybko wraca.
const KICK_LIMIT := 0.6
const KICK_RETURN := 11.0

var pitch := 0.0
## 1 podczas celowania, 0 np. w sprincie.
var aim_amount := 1.0

var _kick := 0.0
var _chest := -1
var _head := -1


func _ready() -> void:
	_chest = get_skeleton().find_bone("chest")
	_head = get_skeleton().find_bone("head")


## Rece i bron podskakuja do gory przy strzale, a potem wracaja.
func kick(amount: float) -> void:
	_kick = minf(_kick + amount * 1.4, KICK_LIMIT)


func _process_modification_with_delta(delta: float) -> void:
	if _chest < 0 or _head < 0:
		return
	_kick *= exp(-delta * KICK_RETURN)
	var skeleton := get_skeleton()
	var twist := STANCE_TWIST * aim_amount
	var head_pose := skeleton.get_bone_global_pose(_head)
	var chest_pose := skeleton.get_bone_global_pose(_chest)
	# Postac w pliku patrzy w +Z, wiec uniesienie to obrot wokol -X.
	chest_pose.basis = Basis(Vector3.RIGHT, -pitch - _kick * aim_amount) * Basis(Vector3.UP, twist) * chest_pose.basis
	skeleton.set_bone_global_pose(_chest, chest_pose)
	var moved_head := skeleton.get_bone_global_pose(_head)
	moved_head.basis = Basis(Vector3.RIGHT, -pitch * 0.6) * head_pose.basis
	skeleton.set_bone_global_pose(_head, moved_head)
