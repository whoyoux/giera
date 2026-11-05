class_name Player
extends CharacterBody3D
## Postac gracza. Wezel nalezy do serwera, a wezel Input do klienta. Ruch dziala
## w petli rollbacku: klient przewiduje go od razu, a serwer ma ostatnie slowo.

const SPEED := 6.5
const GROUND_ACCEL := 70.0
const AIR_ACCEL := 18.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 16.0
const EYE_HEIGHT := 1.6

var peer_id := 0
## Referencja do wpisu w GameState (zdrowie, punkty, respawn).
var info: Dictionary

# Stan rollbacku (state_properties w RollbackSynchronizer).
var yaw := 0.0
var pitch := 0.0
var applied_respawn := 0

var _seen_respawn := 0
var _last_position := Vector3.ZERO
var _speed_smoothed := 0.0

@onready var input := $Input as PlayerInput
@onready var weapon := $Weapon as Weapon
@onready var interpolator := $TickInterpolator as TickInterpolator
@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var view_model := $Head/Camera3D/ViewModel as ViewModel
@onready var model := $Model as PlayerModel
@onready var name_label := $NameLabel as Label3D
@onready var shot_audio := $ShotAudio as AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"players")
	info = GameState.players[peer_id]
	_last_position = position
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	weapon.fired.connect(_on_weapon_fired)

	var local := is_local()
	camera.current = local
	view_model.visible = local
	model.visible = not local
	name_label.visible = not local
	name_label.text = info.name
	model.set_color(PlayerModel.color_for(peer_id))
	shot_audio.stream = Sfx.shot()
	if local:
		# Na start patrzymy w strone srodka mapy.
		input.look_yaw = atan2(position.x, position.z)
		input.yaw = input.look_yaw


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func is_alive() -> bool:
	return info.alive


func is_dead_at(tick: int) -> bool:
	return applied_respawn != info.respawn_id and tick >= info.death_tick


func eye_position() -> Vector3:
	return position + Vector3.UP * EYE_HEIGHT


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	if applied_respawn != info.respawn_id and tick >= info.respawn_tick:
		applied_respawn = info.respawn_id
		position = get_parent().spawn_point(peer_id, applied_respawn)
		velocity = Vector3.ZERO

	var dead := is_dead_at(tick)
	if not dead:
		yaw = input.yaw
		pitch = input.pitch

	_update_floor_state()
	var on_floor := is_on_floor()
	if on_floor:
		velocity.y = maxf(velocity.y, 0.0)
		if input.jump and not dead:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta

	var wish := Vector3.ZERO
	if not dead:
		wish = Vector3(input.move.x, 0.0, input.move.y).limit_length(1.0).rotated(Vector3.UP, yaw) * SPEED
	var accel := (GROUND_ACCEL if on_floor else AIR_ACCEL) * delta
	velocity.x = move_toward(velocity.x, wish.x, accel)
	velocity.z = move_toward(velocity.z, wish.z, accel)

	# move_and_slide zaklada krok fizyki, a netfox ma wlasny krok ticku.
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor


## Po przywroceniu stanu is_on_floor bywa nieaktualne, wiec odswiezamy je pustym ruchem.
func _update_floor_state() -> void:
	var saved := velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = saved


func _after_tick_loop() -> void:
	if applied_respawn != _seen_respawn:
		_seen_respawn = applied_respawn
		interpolator.teleport()
	if multiplayer.is_server() and not info.alive and applied_respawn == info.respawn_id:
		GameState.server_finish_respawn(peer_id)


func _process(delta: float) -> void:
	if is_local():
		rotation.y = input.look_yaw
		head.rotation.x = input.look_pitch
		var dead_drop := -1.1 if not info.alive else 0.0
		head.position.y = move_toward(head.position.y, EYE_HEIGHT + dead_drop, delta * 3.0)
	else:
		rotation.y = yaw
		head.rotation.x = pitch

	var moved := position - _last_position
	moved.y = 0.0
	_last_position = position
	if delta > 0.0:
		_speed_smoothed = lerpf(_speed_smoothed, minf(moved.length() / delta, SPEED * 1.5), minf(delta * 12.0, 1.0))
	var speed_ratio := _speed_smoothed / SPEED
	if is_local():
		view_model.update_pose(delta, speed_ratio, is_on_floor(), not info.alive)
	else:
		model.update_pose(delta, speed_ratio, is_on_floor(), pitch, not info.alive)


func _on_weapon_fired() -> void:
	if Net.is_headless:
		return
	shot_audio.pitch_scale = randf_range(0.94, 1.06)
	shot_audio.play()
	var aim_yaw := input.look_yaw if is_local() else yaw
	var aim_pitch := input.look_pitch if is_local() else pitch
	var muzzle: Vector3
	if is_local():
		view_model.kick()
		muzzle = view_model.muzzle_position()
	else:
		model.kick()
		muzzle = model.muzzle_position()
	var hit := Hitscan.trace(get_world_3d(), eye_position(), Hitscan.direction(aim_yaw, aim_pitch), peer_id, get_tree())
	var fx_root := get_parent()
	ShotFx.tracer(fx_root, muzzle, hit.position)
	if hit.player != null or hit.hit_world:
		ShotFx.impact(fx_root, hit.position, Color("ff5d5d") if hit.player != null else Color("fff3a3"))
