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
var _crouch: CrouchModifier
var _move := Vector2.ZERO
var _air := 0.0
var _aim_blend := 1.0
var _dead := false
var _armed := true
var _gun_holder: Node3D
var _visual: ItemVisual
var _dance := DanceCatalog.NONE


func setup(character_id: String) -> void:
	var character := CharacterAssets.character_for(character_id)
	character.scale = Vector3.ONE * CharacterAssets.MODEL_SCALE
	character.rotation.y = PI
	add_child(character)
	_gun_holder = CharacterAssets.prepare_hands(character)
	_muzzle = _gun_holder.get_node("Muzzle") as Node3D
	var skeleton := CharacterAssets.skeleton_of(character)
	_aim = AimModifier.new()
	skeleton.add_child(_aim)
	_crouch = CrouchModifier.new()
	skeleton.add_child(_crouch)
	_build_tree(character)


## Pokazuje w dloni przedmiot albo puste rece.
func set_item(stack: Dictionary) -> void:
	if _gun_holder == null:
		return
	_armed = not ItemStack.is_empty(stack)
	_gun_holder.visible = _armed and _dance == DanceCatalog.NONE
	if _armed:
		var visual := ItemStack.visual_of(stack)
		if visual != _visual:
			_visual = visual
			CharacterAssets.set_gun_model(_gun_holder, visual)


## Poza kucania od 0 do 1, liczona po animacji biegu.
func set_crouch(amount: float) -> void:
	if _crouch != null:
		_crouch.amount = 0.0 if _dead else amount


func play_shot() -> void:
	_fire("shoot")


func play_melee() -> void:
	_fire("melee")


func play_reload() -> void:
	_fire("reload")


func stop_reload() -> void:
	if _tree != null:
		_tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func play_hit() -> void:
	_fire("hit")


## Taniec zastepuje cale cialo, a bron znika na jego czas. Zero oznacza koniec tanca.
func set_dance(dance_id: int) -> void:
	_dance = dance_id
	if _gun_holder != null:
		_gun_holder.visible = _armed and _dance == DanceCatalog.NONE
	_apply_state()


## Wlasna postac liczy animacje tylko wtedy, gdy ja widac, czyli w czasie tanca.
func set_animating(on: bool) -> void:
	if _tree != null:
		_tree.active = on


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
	_aim_blend = move_toward(_aim_blend, 0.0 if sprinting or not _armed or _dance != DanceCatalog.NONE else 1.0, delta * 8.0)
	_tree.set("parameters/aim/blend_amount", _aim_blend)
	_aim.pitch = pitch * _aim_blend
	_aim.aim_amount = _aim_blend
	if dead != _dead:
		_dead = dead
		_apply_state()


func _apply_state() -> void:
	if _tree == null:
		return
	var state := "alive"
	if _dead:
		state = "dead"
	elif _dance != DanceCatalog.NONE:
		state = "dance_%d" % _dance
	_tree.set("parameters/state/transition_request", state)


func _fire(shot_name: String) -> void:
	if _tree != null and not _dead:
		_tree.set("parameters/%s/request" % shot_name, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _build_tree(character: Node3D) -> void:
	var player := CharacterAssets.player_of(character)
	player.add_animation_library(DanceClips.LIBRARY, DanceClips.library())
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
	for shot: Array in [["shoot", "2H_Ranged_Shoot"], ["melee", "1H_Melee_Attack_Slice_Horizontal"], ["reload", "2H_Ranged_Reload"], ["hit", "Hit_A"]]:
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
	for dance_id in range(1, DanceCatalog.DANCES.size() + 1):
		var input_name := "dance_%d" % dance_id
		state.add_input(input_name)
		graph.add_node(input_name, _animation(DanceCatalog.clip_of(dance_id)))
		graph.connect_node("state", 1 + dance_id, input_name)
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
