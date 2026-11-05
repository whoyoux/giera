class_name DanceClips
extends RefCounted
## Buduje animacje tancow z pozycji opisanych w kodzie. Kazdy taniec to funkcja, ktora dla danego
## uderzenia muzyki ustawia poze. Katy sa liczone w ukladzie postaci stojacej w T: X w strone lewej
## reki, Y w gore, Z do przodu, a stopy same trzymaja sie ziemi dzieki odwrotnej kinematyce nog.

const LIBRARY := &"dance"
const SOURCE := "res://assets/characters/Knight.glb"
const SKELETON_PATH := "Rig/Skeleton3D:"
const SAMPLES_PER_BEAT := 8
## Kolana ida lekko na zewnatrz, jak u kogos, kto stoi na ugietych nogach.
const KNEE_OUTWARD := 0.3
const FK_BONES: Array[String] = ["hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "upperarm.r", "lowerarm.r"]
const STILL_BONES: Array[String] = ["wrist.l", "hand.l", "handslot.l", "wrist.r", "hand.r", "handslot.r", "toes.l", "toes.r"]
const LEG_BONES: Array[String] = ["upperleg.l", "lowerleg.l", "foot.l", "upperleg.r", "lowerleg.r", "foot.r"]
## Reka: podniesienie (0 wzdluz ciala, 90 w bok, 180 w gore), obrot do przodu, ugiecie lokcia, skrecenie przedramienia w gore.
const ARM_REST := Vector4(10.0, 0.0, 15.0, 0.0)
const ARM_ON_HIP := Vector4(32.0, -20.0, 118.0, -10.0)
const ARM_BENT := Vector4(0.0, 0.0, 95.0, 0.0)
const ARM_GOALPOST := Vector4(90.0, 0.0, 90.0, 90.0)
const ARM_FORWARD := Vector4(90.0, 88.0, 5.0, 0.0)
const ARM_OUT := Vector4(90.0, 0.0, 5.0, 0.0)
## Glowa jest duza, wiec reka wprost w gore bylaby za nia schowana.
const ARM_UP := Vector4(135.0, 0.0, 8.0, 0.0)
## Os kola reki (x w bok, y do przodu) i jego szerokosc w radianach.
const LASSO_AXIS := Vector2(0.77, 0.64)
const LASSO_CONE := 0.9
## Kolejne pozy robota: lewa reka, prawa reka, obrot klatki i glowy.
const ROBOT_POSES: Array[Array] = [
	[ARM_BENT, ARM_BENT, 0.0, 0.0],
	[ARM_GOALPOST, ARM_BENT, 22.0, 18.0],
	[ARM_BENT, ARM_GOALPOST, -22.0, -18.0],
	[ARM_GOALPOST, ARM_GOALPOST, 0.0, 0.0],
	[ARM_FORWARD, ARM_FORWARD, 0.0, 38.0],
	[ARM_FORWARD, ARM_FORWARD, 0.0, -38.0],
	[ARM_UP, ARM_OUT, -16.0, -20.0],
	[ARM_OUT, ARM_UP, 16.0, 20.0],
]

static var _library: AnimationLibrary


class Pose:
	var root_yaw := 0.0
	var hips_offset := Vector3.ZERO
	var hips := Vector3.ZERO
	var spine := Vector3.ZERO
	var chest := Vector3.ZERO
	var head := Vector3.ZERO
	var arm_l := ARM_REST
	var arm_r := ARM_REST
	var foot_l := Vector3.ZERO
	var foot_r := Vector3.ZERO
	var foot_yaw_l := 0.0
	var foot_yaw_r := 0.0


## Wspolna biblioteka klipow. Szkielety i ludzie maja te same kosci, wiec wystarczy jedna.
static func library() -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	var source := (load(SOURCE) as PackedScene).instantiate() as Node3D
	var skeleton := CharacterAssets.skeleton_of(source)
	for dance: Dictionary in DanceCatalog.DANCES:
		_library.add_animation(dance.key, _bake(dance, skeleton))
	source.free()
	return _library


static func _pose_at(key: String, beat: float) -> Pose:
	var pose := Pose.new()
	match key:
		"bujanka":
			_bujanka(pose, beat)
		"robot":
			_robot(pose, beat)
		"wiatrak":
			_wiatrak(pose, beat)
		"podskoki":
			_podskoki(pose, beat)
		"skretas":
			_skretas(pose, beat)
		"piruet":
			_piruet(pose, beat)
	return pose


## Fala o podanym okresie w uderzeniach.
static func _wave(beat: float, period: float, phase := 0.0) -> float:
	return sin(TAU * (beat / period + phase))


## Na kazde uderzenie opada do 1 i wraca do 0.
static func _dip(beat: float, period := 1.0) -> float:
	return 0.5 + 0.5 * cos(TAU * beat / period)


static func _bujanka(pose: Pose, beat: float) -> void:
	var sway := _wave(beat, 4.0)
	var dip := _dip(beat)
	pose.foot_l = Vector3(0.05, 0.0, 0.0)
	pose.foot_r = Vector3(-0.05, 0.0, 0.0)
	pose.hips_offset = Vector3(sway * 0.075, -0.035 - dip * 0.035, 0.0)
	pose.hips = Vector3(0.0, sway * 8.0, -sway * 7.0)
	pose.chest = Vector3(4.0, -sway * 8.0, sway * 11.0)
	pose.head = Vector3(dip * 9.0 - 3.0, sway * 6.0, -sway * 5.0)
	# Reka po stronie ciezaru ciala idzie w gore i strzela palcami na uderzenie.
	var left := smoothstep(-0.6, 0.8, sway)
	var right := smoothstep(-0.6, 0.8, -sway)
	pose.arm_l = Vector4(lerpf(14.0, 78.0, left) + dip * 9.0, 8.0, lerpf(70.0, 112.0, left), lerpf(0.0, 65.0, left))
	pose.arm_r = Vector4(lerpf(14.0, 78.0, right) + dip * 9.0, 8.0, lerpf(70.0, 112.0, right), lerpf(0.0, 65.0, right))


static func _robot(pose: Pose, beat: float) -> void:
	var index := int(beat) % ROBOT_POSES.size()
	var from: Array = ROBOT_POSES[index]
	var to: Array = ROBOT_POSES[(index + 1) % ROBOT_POSES.size()]
	# Ruch trwa ulamek uderzenia, a potem poza stoi, jak u maszyny.
	var move := smoothstep(0.72, 1.0, fposmod(beat, 1.0))
	pose.arm_l = (from[0] as Vector4).lerp(to[0], move)
	pose.arm_r = (from[1] as Vector4).lerp(to[1], move)
	pose.chest = Vector3(0.0, lerpf(from[2], to[2], move), 0.0)
	pose.head = Vector3(0.0, lerpf(from[3], to[3], move), 0.0)
	pose.foot_l = Vector3(0.03, 0.0, 0.0)
	pose.foot_r = Vector3(-0.03, 0.0, 0.0)
	var settle := 1.0 - smoothstep(0.0, 0.3, fposmod(beat, 1.0))
	pose.hips_offset = Vector3(0.0, -0.03 - settle * 0.03, 0.0)


static func _wiatrak(pose: Pose, beat: float) -> void:
	var dip := _dip(beat)
	var left_turn := beat >= 4.0
	# Kreci jedna reka przez 4 uderzenia, a potem zamienia je, gdy kreci sie w dole.
	var within := fposmod(beat, 4.0)
	var swap := 1.0 - smoothstep(0.0, 0.5, minf(within, 4.0 - within))
	var spinning := _lasso(within / 2.0).lerp(ARM_REST, swap)
	var resting := ARM_ON_HIP.lerp(ARM_REST, swap)
	pose.arm_l = spinning if left_turn else resting
	pose.arm_r = resting if left_turn else spinning
	var lean := (1.0 if left_turn else -1.0) * (1.0 - swap)
	pose.foot_l = Vector3(0.07, 0.0, 0.03)
	pose.foot_r = Vector3(-0.07, 0.0, -0.03)
	pose.hips_offset = Vector3(lean * 0.04, -0.06 - dip * 0.05, 0.0)
	pose.hips = Vector3(0.0, 0.0, lean * 4.0)
	pose.spine = Vector3(5.0, 0.0, lean * 6.0)
	pose.chest = Vector3(0.0, _wave(beat, 2.0) * 10.0, lean * 8.0)
	pose.head = Vector3(dip * 10.0 - 4.0, 0.0, -lean * 6.0)


## Reka zatacza szerokie kolo z boku i z przodu, zeby nie chowala sie za glowa. Zaczyna w dole.
static func _lasso(turns: float) -> Vector4:
	var angle := TAU * turns
	var outward := LASSO_AXIS * cos(LASSO_CONE) + Vector2(-LASSO_AXIS.y, LASSO_AXIS.x) * sin(LASSO_CONE) * sin(angle)
	var up := -cos(angle) * sin(LASSO_CONE)
	return Vector4(90.0 + rad_to_deg(asin(clampf(up, -1.0, 1.0))), rad_to_deg(atan2(outward.y, outward.x)), 6.0, 0.0)


static func _podskoki(pose: Pose, beat: float) -> void:
	var step := fposmod(beat, 2.0)
	var hop := sin(PI * fposmod(beat, 1.0))
	# Na zmiane wyrzuca noge i piesc po tej samej stronie.
	var side := 1.0 if fposmod(beat, 4.0) < 2.0 else -1.0
	var kick := sin(PI * step / 2.0)
	var kicked := Vector3(side * 0.05, 0.14 * kick + hop * 0.05, 0.2 * kick)
	var planted := Vector3(-side * 0.05, hop * 0.05, 0.0)
	pose.foot_l = kicked if side > 0.0 else planted
	pose.foot_r = planted if side > 0.0 else kicked
	pose.foot_yaw_l = -6.0
	pose.foot_yaw_r = 6.0
	pose.hips_offset = Vector3(-side * kick * 0.04, -0.05 + hop * 0.075, 0.0)
	pose.hips = Vector3(-kick * 5.0, side * kick * 10.0, side * kick * 4.0)
	pose.chest = Vector3(kick * 8.0, -side * kick * 14.0, -side * kick * 6.0)
	pose.head = Vector3(hop * 8.0, side * kick * 8.0, 0.0)
	var pump := kick * (0.75 + hop * 0.25)
	var raised := Vector4(lerpf(20.0, 132.0, pump), 8.0, lerpf(100.0, 12.0, pump), 0.0)
	var low := Vector4(22.0, -10.0, 105.0, 0.0)
	pose.arm_l = raised if side > 0.0 else low
	pose.arm_r = low if side > 0.0 else raised


static func _skretas(pose: Pose, beat: float) -> void:
	var turn := _wave(beat, 1.0)
	var low := 0.5 - 0.5 * cos(TAU * beat / 4.0)
	pose.foot_l = Vector3(0.05, 0.0, 0.0)
	pose.foot_r = Vector3(-0.05, 0.0, 0.0)
	pose.foot_yaw_l = turn * 26.0
	pose.foot_yaw_r = turn * 26.0
	pose.hips_offset = Vector3(0.0, -0.04 - low * 0.085, 0.015)
	pose.hips = Vector3(-low * 6.0, turn * 26.0, 0.0)
	pose.spine = Vector3(low * 8.0, -turn * 12.0, 0.0)
	pose.chest = Vector3(low * 8.0, -turn * 22.0, 0.0)
	pose.head = Vector3(-low * 6.0, turn * 6.0, 0.0)
	pose.arm_l = Vector4(66.0, 25.0 + turn * 32.0, 88.0, 20.0)
	pose.arm_r = Vector4(66.0, 25.0 - turn * 32.0, 88.0, 20.0)


static func _piruet(pose: Pose, beat: float) -> void:
	pose.foot_l = Vector3(0.0, 0.0, 0.03)
	pose.foot_r = Vector3(0.0, 0.0, -0.03)
	if beat < 4.0:
		# Obrot z rekami nad glowa, a na koncu rece opadaja do uklonu.
		var turn := smoothstep(0.0, 4.0, beat)
		pose.root_yaw = turn * 360.0
		var raised := smoothstep(0.0, 0.6, beat) * (1.0 - smoothstep(3.3, 4.0, beat))
		var up := Vector4(135.0 + _wave(beat, 2.0) * 10.0, 10.0, 20.0, 0.0)
		pose.arm_l = ARM_OUT.lerp(up, raised)
		pose.arm_r = ARM_OUT.lerp(up, raised)
		pose.hips_offset = Vector3(0.0, -0.05 + sin(PI * turn) * 0.06, 0.0)
		pose.head = Vector3(-sin(PI * turn) * 10.0, 0.0, 0.0)
		pose.foot_l.y = sin(PI * turn) * 0.05
		return
	# Uklon jak po wystepie.
	var bow := smoothstep(0.0, 0.7, sin(PI * (beat - 4.0) / 4.0))
	pose.hips_offset = Vector3(0.0, -0.05 - bow * 0.04, -bow * 0.05)
	pose.hips = Vector3(bow * 18.0, 0.0, 0.0)
	pose.spine = Vector3(bow * 20.0, 0.0, 0.0)
	pose.chest = Vector3(bow * 16.0, 0.0, 0.0)
	pose.head = Vector3(bow * 8.0, 0.0, 0.0)
	pose.arm_l = ARM_OUT.lerp(Vector4(40.0, 50.0, 112.0, 0.0), bow)
	pose.arm_r = ARM_OUT.lerp(Vector4(62.0, -35.0, 25.0, 0.0), bow)


static func _bake(dance: Dictionary, skeleton: Skeleton3D) -> Animation:
	var animation := Animation.new()
	var seconds_per_beat := 60.0 / float(dance.bpm)
	var beats: int = dance.beats
	animation.length = beats * seconds_per_beat
	animation.loop_mode = Animation.LOOP_LINEAR
	for bone: String in STILL_BONES:
		var still := _rotation_track(animation, bone)
		animation.rotation_track_insert_key(still, 0.0, skeleton.get_bone_rest(skeleton.find_bone(bone)).basis.get_rotation_quaternion())
	var hips_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hips_track, SKELETON_PATH + "hips")
	var tracks := {}
	for bone: String in ["root"] + FK_BONES + LEG_BONES:
		tracks[bone] = _rotation_track(animation, bone)
	for sample in beats * SAMPLES_PER_BEAT + 1:
		var beat := float(sample) / SAMPLES_PER_BEAT
		var time := minf(beat * seconds_per_beat, animation.length)
		var local := _solve(_pose_at(dance.key, fposmod(beat, float(beats))), skeleton)
		for bone: String in tracks:
			animation.rotation_track_insert_key(tracks[bone], time, local[bone])
		animation.position_track_insert_key(hips_track, time, local.hips_position)
	return animation


static func _rotation_track(animation: Animation, bone: String) -> int:
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, SKELETON_PATH + bone)
	return track


## Zamienia poze na lokalne obroty kosci. Obrot podany w ukladzie postaci dziala na kosc tak,
## jakby stala w pozycji T, a kosci potomne go dziedzicza.
static func _solve(pose: Pose, skeleton: Skeleton3D) -> Dictionary:
	var deltas := {
		"hips": _euler(pose.hips),
		"spine": _euler(pose.spine),
		"chest": _euler(pose.chest),
		"head": _euler(pose.head),
		"upperarm.l": _upper_arm(pose.arm_l, 1.0),
		"lowerarm.l": _elbow(pose.arm_l, 1.0),
		"upperarm.r": _upper_arm(pose.arm_r, -1.0),
		"lowerarm.r": _elbow(pose.arm_r, -1.0),
	}
	var local := {}
	for bone: String in FK_BONES:
		var index := skeleton.find_bone(bone)
		var rest_global := _rest_rotation(skeleton, index)
		local[bone] = skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * rest_global.inverse() * (deltas[bone] as Quaternion) * rest_global
	var root_rest := skeleton.get_bone_rest(skeleton.find_bone("root")).basis.get_rotation_quaternion()
	local["root"] = Quaternion(Vector3.UP, deg_to_rad(pose.root_yaw)) * root_rest
	var hips_index := skeleton.find_bone("hips")
	var hips_rest := skeleton.get_bone_global_rest(hips_index).origin
	var hips_position := hips_rest + pose.hips_offset
	local["hips_position"] = root_rest.inverse() * hips_position
	var hips_delta: Quaternion = deltas.hips
	var hips_rotation := hips_delta * _rest_rotation(skeleton, hips_index)
	for side: String in ["l", "r"]:
		var left := side == "l"
		var upper_rest := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg." + side)).origin
		var hip := hips_position + hips_delta * (upper_rest - hips_rest)
		_solve_leg(local, skeleton, side, hip, hips_rotation, pose.foot_l if left else pose.foot_r, pose.foot_yaw_l if left else pose.foot_yaw_r)
	return local


## Dwie kosci nogi tak, zeby kostka trafila w cel, a stopa zostala plasko.
static func _solve_leg(local: Dictionary, skeleton: Skeleton3D, side: String, hip: Vector3, hips_rotation: Quaternion, foot_offset: Vector3, foot_yaw: float) -> void:
	var upper_index := skeleton.find_bone("upperleg." + side)
	var lower_index := skeleton.find_bone("lowerleg." + side)
	var foot_index := skeleton.find_bone("foot." + side)
	var hip_rest := skeleton.get_bone_global_rest(upper_index).origin
	var knee_rest := skeleton.get_bone_global_rest(lower_index).origin
	var ankle_rest := skeleton.get_bone_global_rest(foot_index).origin
	var thigh := hip_rest.distance_to(knee_rest)
	var shin := knee_rest.distance_to(ankle_rest)
	var to_target := ankle_rest + foot_offset - hip
	var distance := clampf(to_target.length(), absf(thigh - shin) + 0.001, thigh + shin - 0.001)
	var aim := to_target.normalized()
	var ankle := hip + aim * distance
	var along := (thigh * thigh - shin * shin + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(thigh * thigh - along * along, 0.0))
	var sign_x := 1.0 if side == "l" else -1.0
	var pole := Vector3(sign_x * KNEE_OUTWARD, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(foot_yaw))
	var knee := hip + aim * along + (pole - aim * pole.dot(aim)).normalized() * height
	var upper_rotation := _arc(knee_rest - hip_rest, knee - hip) * _rest_rotation(skeleton, upper_index)
	var lower_rotation := _arc(ankle_rest - knee_rest, ankle - knee) * _rest_rotation(skeleton, lower_index)
	var foot_rotation := Quaternion(Vector3.UP, deg_to_rad(foot_yaw)) * _rest_rotation(skeleton, foot_index)
	local["upperleg." + side] = hips_rotation.inverse() * upper_rotation
	local["lowerleg." + side] = upper_rotation.inverse() * lower_rotation
	local["foot." + side] = lower_rotation.inverse() * foot_rotation


static func _upper_arm(arm: Vector4, sign_x: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(-sign_x * arm.y)) * Quaternion(Vector3.BACK, deg_to_rad(sign_x * (arm.x - 90.0))) * Quaternion(Vector3.RIGHT, deg_to_rad(-arm.w))


static func _elbow(arm: Vector4, sign_x: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(-sign_x * arm.z))


static func _euler(degrees: Vector3) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(degrees.y)) * Quaternion(Vector3.RIGHT, deg_to_rad(degrees.x)) * Quaternion(Vector3.BACK, deg_to_rad(degrees.z))


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	return Quaternion(from.normalized(), to.normalized())


static func _rest_rotation(skeleton: Skeleton3D, index: int) -> Quaternion:
	return skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
