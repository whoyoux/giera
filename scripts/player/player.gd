class_name Player
extends CharacterBody3D
## Postac gracza. Wezel nalezy do serwera, a wezel Input do klienta. Ruch dziala
## w petli rollbacku: klient przewiduje go od razu, a serwer ma ostatnie slowo.

## Nad nazwa gracza, liczone od jej srodka.
const AVATAR_TAG_GAP := 0.05
const NAME_LABEL_HEIGHT := 2.32
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
const AIM_ZOOM_SPEED := 12.0
## Odrzut w rekach i szarpniecie kamery sa mniejsze przy celowaniu.
const AIM_RECOIL_SCALE := 0.55
const STEP_DISTANCE := 2.3
const SPRINT_STEP_DISTANCE := 3.0
const MIN_STEP_SPEED := 1.2
## Slabsze upadki, np. szczyt skoku, nie licza sie jako ladowanie.
const LANDING_MIN_SPEED := 3.0
const LANDING_FULL_SPEED := 14.0
const JUMP_DETECT_SPEED := 3.0
const SHAKE_LANDING := 0.42
const SHAKE_DEATH := 0.8
const SHAKE_HIT_BASE := 0.25
const SHAKE_HIT_STRENGTH := 0.35
const STEP_VOLUME_LOCAL := -11.0
const STEP_VOLUME_REMOTE := -2.0
## Kucanie: nizsza kapsula, oczy i hitbox. Przejscie kamery trwa ulamek sekundy.
const CROUCH_EYE_HEIGHT := 0.95
const CROUCH_DROP := 0.55
const CROUCH_SPEED_SCALE := 0.5
const CROUCH_SECONDS := 0.18
## Slizg: kucniecie w sprincie popycha gracza do przodu, a predkosc szybko opada.
const SLIDE_SECONDS := 0.75
const SLIDE_SPEED := 11.0
const SLIDE_END_SPEED := 3.2
const SLIDE_STAMINA := 25.0
## Wspinanie po drabinie i rurze.
const CLIMB_SPEED := 3.6
## Kapsula sprawdzajaca, czy nad glowa kucajacego jest miejsce, zeby wstac. Waska, zeby nie lapala scian.
const STAND_CHECK_RADIUS := 0.36
const STAND_CHECK_HEIGHT := 0.9
const STAND_CHECK_CENTER := 1.36
## Tak dlugo cialo wyeliminowanego gracza lezy na mapie.
const CORPSE_SECONDS := 5.0

var peer_id := 0
## Bufor ruchu tego gracza, gdy klient oglada go z zewnatrz. Serwer ma stan od razu.
var remote_motion: RemoteMotion
## Referencja do wpisu w GameState (zdrowie, punkty, respawn).
var info: Dictionary

# Stan rollbacku (state_properties w RollbackSynchronizer).
var yaw := 0.0
var pitch := 0.0
var applied_respawn := 0
var stamina := STAMINA_MAX
var sprinting := false
var aiming := false
var exhausted := false
var sprint_stop_tick := -1000
## Numer tanca z DanceCatalog albo zero.
var dance_id := DanceCatalog.NONE
## Kucanie wybrane w tym ticku i plynne przejscie od 0 (stoi) do 1 (kuca).
var crouching := false
var crouch_amount := 0.0
## Tick konca slizgu albo -1 i kucanie z poprzedniego ticku, zeby wykryc samo nacisniecie.
var slide_end := -1
var crouch_was := false
## Czy poprzedni tick skonczyl sie na ziemi. Sam CharacterBody3D pamieta to tylko z ostatniej symulacji.
var on_ground := true

## Pozycje z ostatnich tickow, potrzebne serwerowi do cofania czasu przy strzale.
var _position_history := {}
var _crouch_history := {}
## Tylko do testow na serwerze: miejsce, w ktore postac przeniesie sie w najblizszym ticku.
var _teleport_to := Vector3.INF
var _stand_check: PhysicsShapeQueryParameters3D
var _seen_respawn := 0
var _last_position := Vector3.ZERO
var _velocity_smoothed := Vector3.ZERO
var _seen_health := 0
var _punch := Vector3.ZERO
var _view_speed := 0.0
var _switch_audio: AudioStreamPlayer
var _item_audio: AudioStreamPlayer
var _drop_requested_uid := 0
var _shake := CameraShake.new()
var _body_audio: AudioStreamPlayer
var _body_audio_3d: AudioStreamPlayer3D
var _step_distance := 0.0
var _step_count := 0
var _jump_count := 0
var _landing_count := 0
var _was_grounded := true
var _fall_speed := 0.0
var _seen_alive := true
var _seen_exhausted := false
var _seen_aiming := false
var _view_zoom := 1.0
var _prime_audio: AudioStreamPlayer3D
var _next_prime_beep := 0.0
var _seen_dance := DanceCatalog.NONE
var _dance_music: DanceMusic
var _dance_camera := DanceCamera.new()
var _tag_root: Node3D
var _seen_present := true
var _seen_crouching := false
var _seen_sliding := false

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
@onready var standing_shape := $Standing as CollisionShape3D
@onready var crouched_shape := $Crouched as CollisionShape3D


func _ready() -> void:
	add_to_group(&"players")
	info = GameState.players[peer_id]
	_last_position = position
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	equipment.fired.connect(_on_item_fired)
	equipment.thrown.connect(_on_item_thrown)
	equipment.priming_changed.connect(_on_priming_changed)
	equipment.action_started.connect(_on_action_started)
	equipment.action_cancelled.connect(_on_action_cancelled)
	equipment.active_item_changed.connect(_on_active_item_changed)
	_seen_health = info.health
	_seen_alive = info.alive
	equipment.initialize()

	var local := is_local()
	if not local and not multiplayer.is_server():
		remote_motion = RemoteMotion.new()
		interpolator.enabled = false
		interpolator.enable_recording = false
	camera.current = local
	view_model.visible = local
	model.visible = not local
	name_label.visible = not local
	name_label.text = info.name
	if not local and not Net.is_headless:
		var tag := AvatarTag.new(info.get("steam_id", 0))
		tag.position = name_label.position
		# Zdjecie samo decyduje o swojej widocznosci, wiec ukrywamy je przez rodzica.
		_tag_root = Node3D.new()
		add_child(_tag_root)
		_tag_root.add_child(tag)
		_place_avatar_tag.call_deferred(tag)
	if not Net.is_headless:
		_switch_audio = AudioStreamPlayer.new()
		_switch_audio.stream = Sfx.switch_item()
		add_child(_switch_audio)
		_item_audio = AudioStreamPlayer.new()
		add_child(_item_audio)
		_body_audio = AudioStreamPlayer.new()
		add_child(_body_audio)
		_prime_audio = AudioStreamPlayer3D.new()
		_prime_audio.stream = Sfx.grenade_beep()
		_prime_audio.max_distance = 26.0
		add_child(_prime_audio)
		_body_audio_3d = AudioStreamPlayer3D.new()
		_body_audio_3d.max_distance = 28.0
		add_child(_body_audio_3d)
		_dance_music = DanceMusic.new()
		_dance_music.setup(local)
		add_child(_dance_music)
	if not Net.is_headless:
		# Wlasny model widac tylko w czasie tanca, wiec do tej pory nic nie liczy.
		model.setup(info.character)
		if local:
			view_model.setup(info.character)
			model.set_animating(false)
	if local:
		# Na start patrzymy w strone srodka mapy.
		input.look_yaw = atan2(position.x, position.z)
		input.yaw = input.look_yaw


## Szarpniecie kamery po trafieniu. Strzal liczy sie z kierunku wejscia, a nie z kamery.
func punch_camera(strength: float) -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	_punch = Vector3(0.05 * strength, 0.0, 0.09 * strength * side)
	view_model.add_look(Vector2(14.0 * side, -18.0) * strength)
	shake_camera(SHAKE_HIT_BASE + SHAKE_HIT_STRENGTH * strength)


## Przy przyblizeniu ten sam ruch myszy obraca widok wolniej, zeby celowanie bylo rownie wygodne.
func aim_sensitivity_scale() -> float:
	if not aiming:
		return _view_zoom
	return _view_zoom * float(Settings.value("aim_sensitivity"))


## Celowanie przez lunete snajperki.
func is_scoped() -> bool:
	var stats := equipment.active_stats()
	return aiming and stats != null and stats.scope


## Luneta przyblizyla juz widok. Bot bez ekranu przyblizenia nie liczy, wiec od razu jest gotowy.
func camera_zoomed_in() -> bool:
	return Net.is_headless or _view_zoom < 0.5


## W pelni przyblizona luneta zaslania bron, wiec jej nie rysujemy.
## Na podium po rundzie kamera patrzy z boku, wiec broni w rekach tez nie widac.
func hides_weapon() -> bool:
	var podium := not Match.is_elimination() and Match.phase == Match.Phase.RESULTS
	return podium or (is_scoped() and _view_zoom < 0.5)


func shake_camera(amount: float) -> void:
	_shake.add(amount)


## Klawisz E: przedmiot podnosi od razu, a skrzynke trzeba chwile przytrzymac.
func try_interact() -> void:
	if WorldItems.focused_id != 0:
		try_pickup()
	else:
		Chests.arm()


## Dzwiek gra od razu, a o samym podniesieniu decyduje serwer.
func try_pickup() -> void:
	if WorldItems.focused_id == 0 or not info.alive:
		return
	WorldItems.request_pickup(WorldItems.focused_id)
	_play_item_sound(Sfx.item_pickup())
	if not Net.is_headless:
		view_model.nudge()


func try_drop() -> void:
	var slot := input.selected_slot()
	var uid := ItemStack.uid_of(info.slots[slot])
	if uid == 0 or uid == _drop_requested_uid or not info.alive:
		return
	_drop_requested_uid = uid
	WorldItems.request_drop(slot, uid)
	_play_item_sound(Sfx.item_drop())
	if not Net.is_headless:
		view_model.nudge()


## Do testow: przenosi postac przez symulacje, wiec rollback nie cofnie zmiany. Tylko serwer.
func teleport(at: Vector3) -> void:
	_teleport_to = at


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func is_alive() -> bool:
	return info.alive


func is_dead_at(tick: int) -> bool:
	return applied_respawn != info.respawn_id and tick >= info.death_tick


## Tam klient widzi gracza. W czasie rollbacku "position" trzyma inny, nowszy stan.
func shown_position() -> Vector3:
	return remote_motion.shown_position if remote_motion != null and remote_motion.has_samples() else position


func eye_position() -> Vector3:
	return position + Vector3.UP * eye_height()


func eye_height(amount := crouch_amount) -> float:
	return lerpf(EYE_HEIGHT, CROUCH_EYE_HEIGHT, amount)


## Kucanie widoczne na ekranie tego klienta. Inni gracze sa pokazywani z bufora ruchu.
## Nie wpisujemy go do crouch_amount, bo netfox zapisalby te wartosc w historii stanow.
func shown_crouch() -> float:
	return remote_motion.shown_crouch if remote_motion != null and remote_motion.has_samples() else crouch_amount


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	if applied_respawn != info.respawn_id and tick >= info.respawn_tick:
		applied_respawn = info.respawn_id
		position = get_parent().spawn_point(peer_id, applied_respawn)
		velocity = Vector3.ZERO
		on_ground = false
		stamina = STAMINA_MAX
		exhausted = false
		crouching = false
		crouch_amount = 0.0
		slide_end = -1
		equipment.on_respawn()

	if _teleport_to != Vector3.INF and multiplayer.is_server():
		position = _teleport_to
		velocity = Vector3.ZERO
		_teleport_to = Vector3.INF
	var dead := is_dead_at(tick)
	var locked := dead or Match.is_frozen_at(tick)
	_update_crouch(delta, dead)
	_update_dance(dead)
	# Tancerz stoi w miejscu, a mysz obraca tylko kamere wokol niego.
	if not dead and dance_id == DanceCatalog.NONE:
		yaw = input.yaw
		pitch = input.pitch

	_update_floor_state()
	var on_floor := is_on_floor()
	var climbing := not locked and _on_ladder() and not input.jump
	if climbing:
		# Na drabinie przod to gora, tyl to dol, a bez klawisza gracz wisi w miejscu.
		velocity.y = CLIMB_SPEED if input.move.y < -0.1 else (-CLIMB_SPEED if input.move.y > 0.1 and not on_floor else 0.0)
	elif on_floor:
		velocity.y = maxf(velocity.y, 0.0)
		if input.jump and not locked:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta

	aiming = input.aim and not dead and equipment.can_aim(tick)
	_start_slide(tick, on_floor, locked)
	_update_sprint(tick, delta, locked)
	var wish := Vector3.ZERO
	var sliding := is_sliding(tick)
	if sliding:
		# W slizgu sterowanie nie dziala, a predkosc opada do tempa kucania.
		var flat := Vector2(velocity.x, velocity.z)
		flat = flat.move_toward(flat.normalized() * SLIDE_END_SPEED, (SLIDE_SPEED - SLIDE_END_SPEED) / SLIDE_SECONDS * delta)
		velocity.x = flat.x
		velocity.z = flat.y
	elif not locked:
		var top_speed := SPEED * SPRINT_MULTIPLIER if sprinting else SPEED
		if crouching:
			top_speed *= CROUCH_SPEED_SCALE
		if aiming:
			top_speed *= equipment.active_stats().aim_move_scale
		top_speed *= equipment.move_speed_scale()
		wish = Vector3(input.move.x, 0.0, input.move.y).limit_length(1.0).rotated(Vector3.UP, yaw) * top_speed
	var accel := (GROUND_ACCEL if on_floor else AIR_ACCEL) * delta
	if not sliding:
		velocity.x = move_toward(velocity.x, wish.x, accel)
		velocity.z = move_toward(velocity.z, wish.z, accel)

	# move_and_slide zaklada krok fizyki, a netfox ma wlasny krok ticku.
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	on_ground = is_on_floor()
	if multiplayer.is_server():
		_remember_motion(tick + 1, position, crouch_amount)


## Kucnac mozna od razu, ale wstac tylko wtedy, gdy nad glowa jest miejsce.
## Ksztalt kolizji zalezy od stanu ticku, wiec ustawiamy go przed ruchem takze przy rollbacku.
func _update_crouch(delta: float, dead: bool) -> void:
	if input.crouch and not dead:
		crouching = true
	elif crouching and (dead or _can_stand()):
		crouching = false
	crouch_amount = move_toward(crouch_amount, 1.0 if crouching else 0.0, delta / CROUCH_SECONDS)
	_apply_crouch_shape()


## Czy gracz stoi w bryle drabiny. Mapa jest ta sama u wszystkich, wiec wynik tez.
func _on_ladder() -> bool:
	var feet := position + Vector3.UP * 0.5
	for box in Maps.info().ladders():
		if box.has_point(feet):
			return true
	return false


func is_sliding(tick := NetworkTime.tick) -> bool:
	return slide_end >= 0 and tick < slide_end


## Nacisniecie kucania w pelnym sprincie na ziemi zaczyna slizg i zabiera czesc paska sprintu.
func _start_slide(tick: int, on_floor: bool, locked: bool) -> void:
	var pressed := input.crouch and not crouch_was
	crouch_was = input.crouch
	if not pressed or locked or not on_floor or not sprinting or stamina < SLIDE_STAMINA or is_sliding(tick):
		return
	slide_end = tick + NetworkTime.seconds_to_ticks(SLIDE_SECONDS)
	stamina -= SLIDE_STAMINA
	var forward := Vector3(velocity.x, 0.0, velocity.z).normalized()
	velocity.x = forward.x * SLIDE_SPEED
	velocity.z = forward.z * SLIDE_SPEED


func _apply_crouch_shape() -> void:
	if standing_shape.disabled != crouching:
		standing_shape.disabled = crouching
		crouched_shape.disabled = not crouching


func _can_stand() -> bool:
	if _stand_check == null:
		var shape := CapsuleShape3D.new()
		shape.radius = STAND_CHECK_RADIUS
		shape.height = STAND_CHECK_HEIGHT
		_stand_check = PhysicsShapeQueryParameters3D.new()
		_stand_check.shape = shape
		_stand_check.collision_mask = Hitscan.WORLD_MASK
	_stand_check.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * STAND_CHECK_CENTER)
	return get_world_3d().direct_space_state.intersect_shape(_stand_check, 1).is_empty()


## Taniec jest tylko wygladem, wiec nie zatrzymuje gracza. Kazda akcja go przerywa.
func _update_dance(dead: bool) -> void:
	var busy := dead or input.move != Vector2.ZERO or input.jump or input.use_primary or input.aim or input.reload or input.crouch
	var wanted := input.dance if not busy and DanceCatalog.is_valid(input.dance) else DanceCatalog.NONE
	# Na poczatku kazdego tanca postac patrzy tam, gdzie kamera, takze gdy gracz obrocil kamere w poprzednim.
	# Dzieki temu pokazuje przod tym, na ktorych gracz patrzy.
	if wanted != DanceCatalog.NONE and wanted != dance_id:
		yaw = input.yaw
		pitch = 0.0
	dance_id = wanted


func _update_sprint(tick: int, delta: float, dead: bool) -> void:
	if exhausted and stamina >= STAMINA_UNLOCK:
		exhausted = false
	# Sprint dziala tylko przy biegu do przodu.
	var wants_sprint := input.sprint and input.move.y < -0.1 and not dead and not aiming and not crouching
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


## Kucanie z danego ticku. Hitbox przy cofaniu czasu musi miec te sama wysokosc co wtedy.
func crouch_at(tick: int) -> float:
	for past in range(tick, tick - POSITION_HISTORY_TICKS, -1):
		if _crouch_history.has(past):
			return _crouch_history[past]
	return crouch_amount


func _remember_motion(tick: int, at: Vector3, crouch: float) -> void:
	_position_history[tick] = at
	_position_history.erase(tick - POSITION_HISTORY_TICKS)
	_crouch_history[tick] = crouch
	_crouch_history.erase(tick - POSITION_HISTORY_TICKS)


## Po przywroceniu stanu is_on_floor bywa nieaktualne, wiec odswiezamy je pustym ruchem.
func _update_floor_state() -> void:
	var saved := velocity
	var saved_snap := floor_snap_length
	velocity = Vector3.ZERO
	floor_snap_length = 0.0
	move_and_slide()
	floor_snap_length = saved_snap
	velocity = saved
	if on_ground and not is_on_floor():
		apply_floor_snap()


func _after_tick_loop() -> void:
	if applied_respawn != _seen_respawn:
		_seen_respawn = applied_respawn
		interpolator.teleport()
		if is_local():
			input.on_respawn()
			# Na starcie meczu gracz patrzy w strone srodka mapy, gdzie toczy sie gra.
			if Match.is_elimination():
				input.look_yaw = atan2(position.x, position.z)
	if multiplayer.is_server() and not info.alive and applied_respawn == info.respawn_id:
		GameState.server_finish_respawn(peer_id)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		RemoteMotion.advance_clock(delta, get_tree())
	if remote_motion != null:
		_show_remote_motion(delta)
	if is_local():
		rotation.y = yaw if dance_id != DanceCatalog.NONE else input.look_yaw
		head.rotation.x = input.look_pitch
		var dead_drop := -1.1 if not info.alive else 0.0
		head.position.y = move_toward(head.position.y, eye_height() + dead_drop, delta * 3.0)
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
	_update_presence()
	_update_crouch_view()
	_update_body_feedback(delta, grounded)
	_update_prime_beep(delta)
	_update_dance_view()
	if is_local():
		# Predkosc z symulacji jest rowna, a ta liczona z pozycji miedzy klatkami drzy.
		_view_speed = lerpf(_view_speed, Vector2(velocity.x, velocity.z).length() / SPEED, minf(delta * 10.0, 1.0))
		view_model.update_pose(delta, _view_speed, grounded, velocity.y, sprinting, equipment.is_reloading(), not info.alive)
		_update_aim_view(delta)
		var base_fov: float = Settings.value("fov")
		var sprint_fov := lerpf(camera.fov / maxf(_view_zoom, 0.01), base_fov + SPRINT_FOV_BONUS if sprinting else base_fov, minf(delta * 8.0, 1.0))
		camera.fov = sprint_fov * _view_zoom
		_punch = _punch.lerp(Vector3.ZERO, minf(delta * 9.0, 1.0))
		var kick := (_punch + _shake.update(delta)) * float(Settings.value("camera_shake"))
		_dance_camera.update(self, delta)
		if _dance_camera.is_active():
			model.update_pose(delta, Vector2.ZERO, true, 0.0, false, not info.alive)
		else:
			camera.rotation = kick
	else:
		var local_velocity := _velocity_smoothed.rotated(Vector3.UP, -rotation.y)
		model.update_pose(delta, Vector2(local_velocity.x, -local_velocity.z), grounded, pitch, sprinting, not info.alive)


## Szerokosc nazwy znamy dopiero po jej ulozeniu, a to Label3D robi z opoznieniem.
func _place_avatar_tag(tag: AvatarTag) -> void:
	tag.set_side_offset(name_label.get_aabb().position.x - AVATAR_TAG_GAP - AvatarTag.SIDE / 2.0)


## Widz patrzy z bliska, wiec nazwa ogladanego gracza zaslanialaby mu pol ekranu.
func set_name_tag_visible(shown: bool) -> void:
	name_label.visible = shown and _seen_present
	if _tag_root != null:
		_tag_root.visible = shown and _seen_present


## Widzowie i ciala starsze niz kilka sekund znikaja z mapy, ale ich wezly zostaja do konca meczu.
func _update_presence() -> void:
	if is_local():
		return
	var present: bool = info.alive or (info.in_match and NetworkTime.tick < info.death_tick + NetworkTime.seconds_to_ticks(CORPSE_SECONDS)) or not Match.is_elimination()
	if present == _seen_present:
		return
	_seen_present = present
	model.visible = present
	name_label.visible = present
	if _tag_root != null:
		_tag_root.visible = present


## Inni widza poze kucania, a nazwa nad glowa opada razem z nia.
func _update_crouch_view() -> void:
	var crouched := shown_crouch() > 0.5
	if crouched != _seen_crouching:
		_seen_crouching = crouched
		if crouched:
			_play_body_sound(Sfx.crouch(), -10.0)
	if is_sliding() != _seen_sliding:
		_seen_sliding = is_sliding()
		if _seen_sliding:
			_play_body_sound(Sfx.slide(), -4.0)
	if is_local():
		return
	var amount := shown_crouch()
	model.set_crouch(amount)
	# Gracz pod ochrona po odrodzeniu jest polprzezroczysty dla innych.
	var protected: bool = NetworkTime.tick < info.get("protected_until", -1)
	name_label.modulate = Color(0.55, 1.0, 0.95) if protected else Color.WHITE
	var drop := Vector3.DOWN * CROUCH_DROP * amount
	name_label.position.y = NAME_LABEL_HEIGHT + drop.y
	if _tag_root != null:
		_tag_root.position = drop


func _show_remote_motion(delta: float) -> void:
	var tick := sync.get_last_known_state()
	if tick > remote_motion.newest_tick and sync._states.has(tick):
		var state := sync._states.get_snapshot(tick)
		# Stan bywa niepelny, gdy serwer wyslal tylko to, co sie zmienilo. Reszta zostaje z poprzedniego.
		remote_motion.add_sample(tick, _snapshot_value(state, ":position", remote_motion.newest_position(position)), _snapshot_value(state, ":yaw", yaw), _snapshot_value(state, ":pitch", pitch), _snapshot_value(state, ":crouch_amount", remote_motion.newest_crouch()))
	if not remote_motion.has_samples():
		return
	remote_motion.advance(delta, RemoteMotion.shown_tick)
	position = remote_motion.shown_position
	yaw = remote_motion.shown_yaw
	pitch = remote_motion.shown_pitch


func _snapshot_value(state: Variant, property: String, fallback: Variant) -> Variant:
	var value: Variant = state.get_value(property)
	return fallback if value == null else value


## Kazdy klient sam wlacza animacje i muzyke, gdy zobaczy zmiane stanu tanca.
func _update_dance_view() -> void:
	if dance_id == _seen_dance:
		return
	_seen_dance = dance_id
	model.set_dance(dance_id)
	if dance_id == DanceCatalog.NONE:
		_dance_music.stop()
	else:
		_dance_music.play(DanceCatalog.music_of(dance_id))


func _update_aim_view(delta: float) -> void:
	var stats := equipment.active_stats()
	var zoom := stats.aim_fov_scale if aiming and stats != null else 1.0
	var previous := _view_zoom
	_view_zoom = lerpf(_view_zoom, zoom, minf(delta * AIM_ZOOM_SPEED, 1.0))
	# Pole widzenia z poprzedniej klatki jest juz przyblizone, wiec przeliczamy je na nowe.
	camera.fov *= _view_zoom / maxf(previous, 0.01)
	view_model.set_aiming(aiming)
	if aiming != _seen_aiming:
		_seen_aiming = aiming
		_play_item_sound(Sfx.aim())


## Kroki, skok i ladowanie slychac u kazdego gracza, a reszta dotyczy tylko wlasnej postaci.
func _update_body_feedback(delta: float, grounded: bool) -> void:
	var alive: bool = info.alive
	if alive != _seen_alive:
		_seen_alive = alive
		_on_alive_changed(alive)
	if is_local() and exhausted != _seen_exhausted:
		_seen_exhausted = exhausted
		if exhausted:
			_play_body_sound(Sfx.exhausted(), -4.0)
	if not alive:
		_was_grounded = grounded
		_fall_speed = 0.0
		return
	if _was_grounded and velocity.y > JUMP_DETECT_SPEED:
		_jump_count += 1
		_play_body_sound(Sfx.jump(), -8.0)
	if not grounded:
		_fall_speed = minf(_fall_speed, velocity.y)
	elif not _was_grounded and _fall_speed <= -LANDING_MIN_SPEED:
		_on_landed()
	if grounded:
		_fall_speed = 0.0
	_was_grounded = grounded
	var moving := Vector2(velocity.x, velocity.z) if is_local() else Vector2(_velocity_smoothed.x, _velocity_smoothed.z)
	if not grounded or moving.length() < MIN_STEP_SPEED:
		return
	_step_distance += moving.length() * delta
	if _step_distance >= (SPRINT_STEP_DISTANCE if sprinting else STEP_DISTANCE):
		_step_distance = 0.0
		_step_count += 1
		_play_body_sound(Sfx.footstep_on(Maps.info().ground_at(position)), STEP_VOLUME_LOCAL if is_local() else STEP_VOLUME_REMOTE, randf_range(0.88, 1.15))


func _on_landed() -> void:
	_landing_count += 1
	var power := clampf(-_fall_speed / LANDING_FULL_SPEED, 0.2, 1.0)
	_play_body_sound(Sfx.land(), lerpf(-9.0, 0.0, power))
	if is_local():
		shake_camera(SHAKE_LANDING * power)


func _on_alive_changed(alive: bool) -> void:
	_play_body_sound(Sfx.respawn() if alive else Sfx.death(), -3.0)
	if is_local() and not alive:
		shake_camera(SHAKE_DEATH)


func _play_body_sound(stream: AudioStreamWAV, volume_db: float, pitch := 1.0) -> void:
	if is_local():
		_body_audio.stream = stream
		_body_audio.volume_db = volume_db
		_body_audio.pitch_scale = pitch
		_body_audio.play()
	else:
		_body_audio_3d.stream = stream
		_body_audio_3d.volume_db = volume_db
		_body_audio_3d.pitch_scale = pitch
		_body_audio_3d.play()


func _update_focus() -> void:
	WorldItems.focused_id = WorldItems.find_target(get_world_3d(), position, eye_position(), Hitscan.direction(input.look_yaw, input.look_pitch)) if info.alive else 0
	Chests.update_local(self, get_process_delta_time(), _is_interact_held())
	# Wyrzucony egzemplarz moze wrocic do tego samego gracza i znow da sie go wyrzucic.
	if _drop_requested_uid != 0 and ItemStack.uid_of(info.slots[input.selected_slot()]) != _drop_requested_uid:
		_drop_requested_uid = 0


func _is_interact_held() -> bool:
	if not Net.bot_mode.is_empty():
		return input.bot_interact
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("interact")


func _play_item_sound(stream: AudioStreamWAV) -> void:
	if Net.is_headless:
		return
	if is_local():
		_item_audio.stream = stream
		_item_audio.play()
	else:
		_body_audio_3d.stream = stream
		_body_audio_3d.volume_db = 0.0
		_body_audio_3d.pitch_scale = 1.0
		_body_audio_3d.play()


func _on_item_fired() -> void:
	if Net.is_headless:
		return
	var stack := equipment.active_stack()
	var behavior := ItemStack.behavior_of(stack)
	if behavior != null:
		behavior.show_fired(self, stack)


## Kierunek patrzenia do efektow. Wlasna kamera wyprzedza symulacje o ulamek ticku.
func look_direction() -> Vector3:
	return Hitscan.direction(input.look_yaw, input.look_pitch) if is_local() else Hitscan.direction(yaw, pitch)


## Dzwiek przedmiotu z opoznieniem, np. zamek snajperki po strzale.
func play_after(stream: AudioStreamWAV, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_inside_tree():
			_play_item_sound(stream))


func play_shot_sound(stream: AudioStreamWAV) -> void:
	shot_audio.stream = stream
	shot_audio.pitch_scale = randf_range(0.96, 1.04)
	shot_audio.play()


## Smugi strzalu i odrzut. Kazdy pocisk ma wlasna smuge, ale blysk i odrzut sa jeden na strzal.
func show_shots(hits: Array[Dictionary], stats: WeaponStats, tier: int) -> void:
	var effect_color := Rarity.effect_color(tier)
	if is_local():
		var steady := AIM_RECOIL_SCALE if aiming else 1.0
		view_model.kick(stats.recoil * steady)
		_punch.x += stats.camera_kick * steady
		view_model.on_next_pose(_show_shot.bind(hits, effect_color, stats.tracer_width))
	else:
		model.play_shot()
		_show_shot(model.muzzle_position(), hits, effect_color, stats.tracer_width)


## Cios widac w rekach, a u innych graczy w animacji postaci.
func show_swing(hit: Dictionary) -> void:
	if is_local():
		view_model.play_slash()
	else:
		model.play_melee()
	if hit.player != null or hit.hit_world:
		ShotFx.impact(get_parent(), hit.position, Color("ff5d5d") if hit.player != null else Color("fff3a3"))


func _on_priming_changed(primed: bool) -> void:
	if Net.is_headless:
		return
	if primed:
		_next_prime_beep = 0.0
		_play_item_sound(Sfx.grenade_pin())
	if is_local():
		view_model.set_priming(primed)


## Odbezpieczony granat pika coraz szybciej, takze w cudzej rece.
func _update_prime_beep(delta: float) -> void:
	if equipment.prime_tick < 0:
		return
	var stack := equipment.active_stack()
	var definition := ItemStack.definition_of(stack) as GrenadeDefinition
	if definition == null:
		return
	_next_prime_beep -= delta
	if _next_prime_beep <= 0.0:
		var left := definition.fuse_seconds - (NetworkTime.tick - equipment.prime_tick) * NetworkTime.ticktime
		_next_prime_beep = lerpf(GrenadeProjectile.WARNING_MIN_GAP, GrenadeProjectile.WARNING_MAX_GAP, clampf(left / definition.fuse_seconds, 0.0, 1.0))
		_prime_audio.play()


func _on_item_thrown() -> void:
	if Net.is_headless:
		return
	_play_item_sound(Sfx.grenade_throw())
	if is_local():
		view_model.play_throw()
	else:
		model.play_shot()


func _show_shot(muzzle: Vector3, hits: Array[Dictionary], color: Color, width: float) -> void:
	var fx_root := get_parent()
	for hit in hits:
		ShotFx.tracer(fx_root, muzzle, hit.position, color, width)
		if hit.player != null or hit.hit_world:
			ShotFx.impact(fx_root, hit.position, Color("ff5d5d") if hit.player != null else color)
		if hit.player == null and hit.hit_world:
			ShotFx.bullet_hole(fx_root, hit.position, hit.get("normal", Vector3.UP), Maps.info().ground_at(hit.position - hit.get("normal", Vector3.UP) * 0.1))


func _on_action_started() -> void:
	if Net.is_headless:
		return
	var behavior := ItemStack.behavior_of(equipment.active_stack())
	var seconds := behavior.timed_action_seconds(equipment.active_stack())
	# Dzwiek ma stala dlugosc, wiec krotsze dzialanie odtwarzamy szybciej.
	var sound := behavior.action_sound()
	reload_audio.stream = sound
	reload_audio.pitch_scale = sound.get_length() / maxf(seconds, 0.1)
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
