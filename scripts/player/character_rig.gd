class_name CharacterRig
extends Node3D
## Postac widziana przez innych graczy. Kazdy klient wylicza animacje z ruchu,
## wiec nie trzeba ich przesylac przez siec.

const UPPER_BONES: Array[String] = [
	"spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "elbowIK.l", "handIK.l", "elbowIK.r", "handIK.r",
]
const LOOPED: Array[String] = [
	"Idle", "Running_A", "Running_B", "Walking_Backwards", "Running_Strafe_Left",
	"Running_Strafe_Right", "Jump_Idle", "2H_Ranged_Aiming",
]

var _tree: AnimationTree
var _muzzle: Node3D
var _aim: AimModifier
var _move := Vector2.ZERO
var _air := 0.0
var _aim_blend := 1.0
var _dead := false


func setup(peer_id: int) -> void:
	var character := CharacterAssets.character_for(peer_id)
	character.scale = Vector3.ONE * CharacterAssets.MODEL_SCALE
	character.rotation.y = PI
	add_child(character)
	_muzzle = CharacterAssets.equip_gun(character)
	var skeleton := CharacterAssets.skeleton_of(character)
	_aim = AimModifier.new()
	skeleton.add_child(_aim)
	_build_tree(character)


func play_shot() -> void:
	_fire("shoot")


func play_reload() -> void:
	_fire("reload")


func stop_reload() -> void:
	if _tree != null:
		_tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func play_hit() -> void:
	_fire("hit")


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position + Vector3.UP


## local_velocity: x w prawo, y do przodu, w metrach na sekunde.
func update_pose(delta: float, local_velocity: Vector2, on_floor: bool, pitch: float, sprinting: bool, dead: bool) -> void:
	if _tree == null:
		return
	var target := local_velocity / Player.SPEED
	_move = _move.lerp(target, minf(delta * 12.0, 1.0))
	_tree.set("parameters/loco/blend_position", _move)
	_air = move_toward(_air, 0.0 if on_floor else 1.0, delta * 8.0)
	_tree.set("parameters/air/blend_amount", _air)
	_aim_blend = move_toward(_aim_blend, 0.0 if sprinting else 1.0, delta * 8.0)
	_tree.set("parameters/aim/blend_amount", _aim_blend)
	_aim.pitch = pitch * _aim_blend
	_aim.aim_amount = _aim_blend
	if dead != _dead:
		_dead = dead
		_tree.set("parameters/state/transition_request", "dead" if dead else "alive")


func _fire(shot_name: String) -> void:
	if _tree != null and not _dead:
		_tree.set("parameters/%s/request" % shot_name, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _build_tree(character: Node3D) -> void:
	var player := CharacterAssets.player_of(character)
	for animation_name in LOOPED:
		player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR

	var loco := AnimationNodeBlendSpace2D.new()
	loco.min_space = Vector2(-1.0, -1.0)
	loco.max_space = Vector2(1.0, Player.SPRINT_MULTIPLIER)
	loco.add_blend_point(_animation("Idle"), Vector2.ZERO, -1, "Idle")
	loco.add_blend_point(_animation("Running_A"), Vector2(0.0, 1.0), -1, "Running_A")
	loco.add_blend_point(_animation("Running_B"), Vector2(0.0, Player.SPRINT_MULTIPLIER), -1, "Running_B")
	loco.add_blend_point(_animation("Walking_Backwards"), Vector2(0.0, -1.0), -1, "Walking_Backwards")
	loco.add_blend_point(_animation("Running_Strafe_Left"), Vector2(-1.0, 0.0), -1, "Running_Strafe_Left")
	loco.add_blend_point(_animation("Running_Strafe_Right"), Vector2(1.0, 0.0), -1, "Running_Strafe_Right")

	var graph := AnimationNodeBlendTree.new()
	graph.add_node("loco", loco)
	graph.add_node("jump", _animation("Jump_Idle"))
	graph.add_node("air", AnimationNodeBlend2.new())
	graph.connect_node("air", 0, "loco")
	graph.connect_node("air", 1, "jump")

	var aim_blend := AnimationNodeBlend2.new()
	_filter_upper_body(aim_blend)
	graph.add_node("aim_pose", _animation("2H_Ranged_Aiming"))
	graph.add_node("aim", aim_blend)
	graph.connect_node("aim", 0, "air")
	graph.connect_node("aim", 1, "aim_pose")

	var previous := "aim"
	for shot: Array in [["shoot", "2H_Ranged_Shoot"], ["reload", "2H_Ranged_Reload"], ["hit", "Hit_A"]]:
		var one_shot := AnimationNodeOneShot.new()
		one_shot.fadein_time = 0.04
		one_shot.fadeout_time = 0.12
		_filter_upper_body(one_shot)
		graph.add_node(shot[0], one_shot)
		graph.add_node(shot[0] + "_clip", _animation(shot[1]))
		graph.connect_node(shot[0], 0, previous)
		graph.connect_node(shot[0], 1, shot[0] + "_clip")
		previous = shot[0]

	var state := AnimationNodeTransition.new()
	state.add_input("alive")
	state.add_input("dead")
	state.xfade_time = 0.12
	graph.add_node("state", state)
	graph.add_node("death", _animation("Death_A"))
	graph.connect_node("state", 0, previous)
	graph.connect_node("state", 1, "death")
	graph.connect_node("output", 0, "state")

	_tree = AnimationTree.new()
	_tree.tree_root = graph
	character.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.active = true
	_tree.set("parameters/state/transition_request", "alive")


func _animation(animation_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


func _filter_upper_body(node: AnimationNode) -> void:
	node.filter_enabled = true
	for bone in UPPER_BONES:
		node.set_filter_path(NodePath("Rig/Skeleton3D:" + bone), true)
