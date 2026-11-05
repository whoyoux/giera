class_name Player
extends CharacterBody3D
## Postac gracza. Wezel nalezy do serwera, a wezel Input do klienta. Ruch dziala
## w petli rollbacku: klient przewiduje go od razu, a serwer ma ostatnie slowo.

const SPEED := 6.5
const GROUND_ACCEL := 70.0
const AIR_ACCEL := 18.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 16.0
const EYE_HEIGHT := 1.5
const SPRINT_MULTIPLIER := 1.5
const STAMINA_MAX := 100.0
## Pelny pasek starcza na 4 s sprintu i odnawia sie w 5 s, po 1 s przerwy.
const STAMINA_DRAIN := 25.0
const STAMINA_REGEN := 20.0
const STAMINA_REGEN_DELAY := 1.0
## Po calkowitym wyczerpaniu sprint wraca dopiero od tego poziomu.
const STAMINA_UNLOCK := 20.0
## O tyle kamera poszerza widok w sprincie.
const SPRINT_FOV_BONUS := 10.0
const POSITION_HISTORY_TICKS := 30

var peer_id := 0
## Referencja do wpisu w GameState (zdrowie, punkty, respawn).
var info: Dictionary

# Stan rollbacku (state_properties w RollbackSynchronizer).
var yaw := 0.0
var pitch := 0.0
var applied_respawn := 0
var stamina := STAMINA_MAX
var sprinting := false
var exhausted := false
var sprint_stop_tick := -1000

## Pozycje z ostatnich tickow, potrzebne serwerowi do cofania czasu przy strzale.
var _position_history := {}
var _seen_respawn := 0
var _last_position := Vector3.ZERO
var _velocity_smoothed := Vector3.ZERO
var _seen_health := 0
var _punch := Vector3.ZERO
var _view_speed := 0.0
var _switch_audio: AudioStreamPlayer
var _item_audio: AudioStreamPlayer
var _drop_requested_uid := 0

@onready var input := $Input as PlayerInput
@onready var sync := $RollbackSynchronizer as RollbackSynchronizer
@onready var equipment := $Equipment as Equipment
@onready var interpolator := $TickInterpolator as TickInterpolator
@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var view_model := $Head/Camera3D/ViewModel as ViewModel
@onready var model := $Model as CharacterRig
@onready var name_label := $NameLabel as Label3D
@onready var shot_audio := $ShotAudio as AudioStreamPlayer3D
@onready var reload_audio := $ReloadAudio as AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"players")
	info = GameState.players[peer_id]
	_last_position = position
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	equipment.fired.connect(_on_item_fired)
	equipment.action_started.connect(_on_action_started)
	equipment.action_cancelled.connect(_on_action_cancelled)
	equipment.active_item_changed.connect(_on_active_item_changed)
	_seen_health = info.health
	equipment.initialize()

	var local := is_local()
	camera.current = local
	view_model.visible = local
	model.visible = not local
	name_label.visible = not local
	name_label.text = info.name
	if not Net.is_headless:
		reload_audio.stream = Sfx.reload_sound()
		_switch_audio = AudioStreamPlayer.new()
		_switch_audio.stream = Sfx.switch_item()
		add_child(_switch_audio)
		_item_audio = AudioStreamPlayer.new()
		add_child(_item_audio)
	if not Net.is_headless:
		if local:
			view_model.setup(peer_id)
		else:
			model.setup(peer_id)
	if local:
		# Na start patrzymy w strone srodka mapy.
		input.look_yaw = atan2(position.x, position.z)
		input.yaw = input.look_yaw


## Szarpniecie kamery po trafieniu. Strzal liczy sie z kierunku wejscia, a nie z kamery.
func punch_camera(strength: float) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	_punch = Vector3(0.05 * strength, 0.0, 0.09 * strength * side)
	view_model.add_look(Vector2(14.0 * side, -18.0) * strength)


## Dzwiek gra od razu, a o samym podniesieniu decyduje serwer.
func try_pickup() -> void:
	if WorldItems.focused_id == 0 or not info.alive:
		return
	WorldItems.request_pickup(WorldItems.focused_id)
	_play_item_sound(Sfx.item_pickup())


func try_drop() -> void:
	var slot := input.selected_slot()
	var uid := ItemStack.uid_of(info.slots[slot])
	if uid == 0 or uid == _drop_requested_uid or not info.alive:
		return
	_drop_requested_uid = uid
	WorldItems.request_drop(slot, uid)
	_play_item_sound(Sfx.item_drop())


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
		stamina = STAMINA_MAX
		exhausted = false
		equipment.on_respawn()

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

	_update_sprint(tick, delta, dead)
	var wish := Vector3.ZERO
	if not dead:
		var top_speed := SPEED * SPRINT_MULTIPLIER if sprinting else SPEED
		wish = Vector3(input.move.x, 0.0, input.move.y).limit_length(1.0).rotated(Vector3.UP, yaw) * top_speed
	var accel := (GROUND_ACCEL if on_floor else AIR_ACCEL) * delta
	velocity.x = move_toward(velocity.x, wish.x, accel)
	velocity.z = move_toward(velocity.z, wish.z, accel)

	# move_and_slide zaklada krok fizyki, a netfox ma wlasny krok ticku.
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	if multiplayer.is_server():
		_remember_position(tick + 1)


func _update_sprint(tick: int, delta: float, dead: bool) -> void:
	if exhausted and stamina >= STAMINA_UNLOCK:
		exhausted = false
	# Sprint dziala tylko przy biegu do przodu.
	var wants_sprint := input.sprint and input.move.y < -0.1 and not dead
	sprinting = wants_sprint and not exhausted and stamina > 0.0
	# Odnawianie rusza dopiero po puszczeniu klawisza i krotkiej przerwie.
	if wants_sprint:
		sprint_stop_tick = tick
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		exhausted = stamina <= 0.0
	elif tick - sprint_stop_tick >= NetworkTime.seconds_to_ticks(STAMINA_REGEN_DELAY):
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)


## Zwraca pozycje z danego ticku albo najblizsza wczesniejsza, jesli jej nie ma.
func position_at(tick: int) -> Vector3:
	for past in range(tick, tick - POSITION_HISTORY_TICKS, -1):
		if _position_history.has(past):
			return _position_history[past]
	return position


func _remember_position(tick: int) -> void:
	_position_history[tick] = position
	_position_history.erase(tick - POSITION_HISTORY_TICKS)


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
		if is_local():
			input.on_respawn()
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

	if is_local():
		_update_focus()
	if delta <= 0.0 or Net.is_headless:
		return
	var moved := (position - _last_position) / delta
	_last_position = position
	_velocity_smoothed = _velocity_smoothed.lerp(moved, minf(delta * 14.0, 1.0))
	# Inni gracze nie sa symulowani u klienta, wiec is_on_floor by dla nich klamalo.
	var grounded := absf(velocity.y) < 0.6
	var health: int = info.health
	if health < _seen_health and health > 0 and not is_local():
		model.play_hit()
	_seen_health = health
	if is_local():
		# Predkosc z symulacji jest rowna, a ta liczona z pozycji miedzy klatkami drzy.
		_view_speed = lerpf(_view_speed, Vector2(velocity.x, velocity.z).length() / SPEED, minf(delta * 10.0, 1.0))
		view_model.update_pose(delta, _view_speed, grounded, velocity.y, sprinting, equipment.is_reloading(), not info.alive)
		var base_fov: float = Settings.value("fov")
		camera.fov = lerpf(camera.fov, base_fov + SPRINT_FOV_BONUS if sprinting else base_fov, minf(delta * 8.0, 1.0))
		_punch = _punch.lerp(Vector3.ZERO, minf(delta * 9.0, 1.0))
		camera.rotation = _punch
	else:
		var local_velocity := _velocity_smoothed.rotated(Vector3.UP, -rotation.y)
		model.update_pose(delta, Vector2(local_velocity.x, -local_velocity.z), grounded, pitch, sprinting, not info.alive)


func _update_focus() -> void:
	WorldItems.focused_id = WorldItems.find_target(get_world_3d(), position, eye_position(), Hitscan.direction(input.look_yaw, input.look_pitch)) if info.alive else 0
	# Wyrzucony egzemplarz moze wrocic do tego samego gracza i znow da sie go wyrzucic.
	if _drop_requested_uid != 0 and ItemStack.uid_of(info.slots[input.selected_slot()]) != _drop_requested_uid:
		_drop_requested_uid = 0


func _play_item_sound(stream: AudioStreamWAV) -> void:
	if Net.is_headless:
		return
	_item_audio.stream = stream
	_item_audio.play()


func _on_item_fired() -> void:
	if Net.is_headless:
		return
	var stack := equipment.active_stack()
	var stats := ItemStack.weapon_stats_of(stack)
	if stats == null:
		return
	var tier := ItemStack.tier_of(stack)
	shot_audio.stream = Sfx.shot(stats)
	shot_audio.pitch_scale = randf_range(0.96, 1.04)
	shot_audio.play()
	var aim_yaw := input.look_yaw if is_local() else yaw
	var aim_pitch := input.look_pitch if is_local() else pitch
	var muzzle: Vector3
	if is_local():
		view_model.kick(stats.recoil)
		muzzle = view_model.muzzle_position()
		_punch.x += stats.camera_kick
	else:
		model.play_shot()
		muzzle = model.muzzle_position()
	var hit := Hitscan.trace(get_world_3d(), eye_position(), Hitscan.direction(aim_yaw, aim_pitch), peer_id, get_tree())
	var fx_root := get_parent()
	var effect_color := Rarity.effect_color(tier)
	ShotFx.tracer(fx_root, muzzle, hit.position, effect_color, stats.tracer_width)
	if hit.player != null or hit.hit_world:
		ShotFx.impact(fx_root, hit.position, Color("ff5d5d") if hit.player != null else effect_color)


func _on_action_started() -> void:
	if Net.is_headless:
		return
	# Dzwiek ma stala dlugosc, wiec krotsze przeladowanie odtwarzamy szybciej.
	var seconds := ItemStack.behavior_of(equipment.active_stack()).timed_action_seconds(equipment.active_stack())
	reload_audio.pitch_scale = Sfx.RELOAD_SOUND_SECONDS / maxf(seconds, 0.1)
	reload_audio.play()
	if is_local():
		view_model.set_reload_seconds(seconds)
	else:
		model.play_reload()


func _on_action_cancelled() -> void:
	if Net.is_headless:
		return
	reload_audio.stop()
	if not is_local():
		model.stop_reload()


func _on_active_item_changed() -> void:
	if Net.is_headless:
		return
	var stack := equipment.active_stack()
	if is_local():
		view_model.set_item(stack)
		_switch_audio.play()
	else:
		model.set_item(stack)
