class_name PlayerInput
extends Node
## Wejscie gracza. Ten wezel nalezy do klienta, a netfox przesyla jego wlasciwosci
## na serwer co tick.

const MOUSE_SENSITIVITY := 0.0025
const MAX_PITCH := 1.5
const LOOTER_STEP_SECONDS := 0.9
const OPENER_REACH := 2.2
## Szybciej gracz spada dopiero wtedy, gdy stracil grunt pod nogami.
const DANCE_FALL_SPEED := 2.0
const DANCE_START_MAX_FALL := 0.6
const DANCER_STEP_SECONDS := 6.0
const DANCER_MOVE_AFTER := 4.5
const DANCER_MOVE_UNTIL := 5.0
const OVERHEAD_AIM_HEIGHT := 1.5
## Kolysanie lunety: maly ruch celownika, ktory gracz musi poprawiac.
const SCOPE_SWAY := 0.0035
const SCOPE_SWAY_SPEED := 1.3

# Wysylane do serwera (input_properties w RollbackSynchronizer).
var move := Vector2.ZERO
var jump := false
var use_primary := false
var aim := false
## Slot, ktory gracz chce miec w reku.
var slot := 0
var sprint := false
var crouch := false
var reload := false
var yaw := 0.0
var pitch := 0.0
## Bot trzyma klawisz otwierania. Gracz ma go w Input.
var bot_interact := false
## Tick innych graczy widoczny teraz na ekranie. -1 oznacza stan biezacy.
var view_tick := -1
## Taniec, o ktory prosi gracz. Zero oznacza brak.
var dance := DanceCatalog.NONE
## Otwarte kolo tancow przejmuje mysz, wiec nie wolno strzelac ani celowac.
var wheel_open := false

# Biezace polozenie kamery aktualizowane co klatke. Rollback nadpisuje yaw i pitch
# wartosciami z historii, wiec akumulator musi byc osobno.
var look_yaw := 0.0
var look_pitch := 0.0

var _bot_time := 0.0
var _bot_step := 0
# Wybor gracza zmienia sie miedzy tickami, a rollback nadpisuje "slot" historia.
var _wanted_slot := 0
var _wanted_uid := 0
var _fire_blocked := false
var _wanted_dance := DanceCatalog.NONE
var _sway_time := 0.0
var _sway := Vector2.ZERO


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = MOUSE_SENSITIVITY * Settings.value("sensitivity") * (get_parent() as Player).aim_sensitivity_scale()
		var vertical: float = -1.0 if Settings.value("invert_y") else 1.0
		look_yaw -= event.relative.x * sensitivity
		look_pitch = clampf(look_pitch - event.relative.y * sensitivity * vertical, -MAX_PITCH, MAX_PITCH)
		(get_parent() as Player).view_model.add_look(event.relative * 0.02)
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_slot_input(event)


func selected_slot() -> int:
	return _wanted_slot


func select_slot(index: int) -> void:
	_wanted_slot = clampi(index, 0, Inventory.SLOTS - 1)
	_wanted_uid = ItemStack.uid_of((get_parent() as Player).info.slots[_wanted_slot])


func _handle_slot_input(event: InputEvent) -> void:
	for index in Inventory.SLOTS:
		if event.is_action_pressed("slot_%d" % (index + 1)):
			select_slot(index)
			stop_dance()
			return
	var me := get_parent() as Player
	if event.is_action_pressed("interact"):
		me.try_interact()
		stop_dance()
		return
	if event.is_action_pressed("drop_item"):
		me.try_drop()
		stop_dance()
		return
	var slots: Array = me.info.slots
	if event.is_action_pressed("next_slot"):
		select_slot(Inventory.next_occupied(slots, _wanted_slot, 1))
		stop_dance()
	elif event.is_action_pressed("prev_slot"):
		select_slot(Inventory.next_occupied(slots, _wanted_slot, -1))
		stop_dance()


## Zaczyna taniec, chyba ze gracz wlasnie idzie, skacze albo spada. Zwraca, czy sie udalo.
func request_dance(dance_id: int) -> bool:
	var me := get_parent() as Player
	if not DanceCatalog.is_valid(dance_id) or not me.info.alive or move != Vector2.ZERO or jump or absf(me.velocity.y) > DANCE_START_MAX_FALL:
		return false
	_wanted_dance = dance_id
	return true


func stop_dance() -> void:
	_wanted_dance = DanceCatalog.NONE


## Otwarcie i zamkniecie kola. Klikniecie w kole nie moze potem wystrzelic.
func set_wheel_open(open: bool) -> void:
	wheel_open = open
	_fire_blocked = true


## Trzymany przycisk strzalu nie zadziala, dopoki gracz go nie pusci.
func block_fire() -> void:
	_fire_blocked = true


func _keep_dance_valid() -> void:
	var me := get_parent() as Player
	if move != Vector2.ZERO or jump or use_primary or aim or reload or crouch or not me.info.alive or me.velocity.y < -DANCE_FALL_SPEED:
		_wanted_dance = DanceCatalog.NONE


## Gdy przedmiot z wybranego slotu zniknie, np. po smierci, wracamy do czegos w reku.
## Slot wybrany celowo jako pusty zostaje pusty.
func _keep_selection_valid() -> void:
	var slots: Array = (get_parent() as Player).info.slots
	var uid := ItemStack.uid_of(slots[_wanted_slot])
	if _wanted_uid != 0 and uid == 0:
		select_slot(maxi(Inventory.first_occupied(slots), 0))
		_fire_blocked = true
	else:
		_wanted_uid = uid if _wanted_uid != 0 else _wanted_uid


## Po odrodzeniu nikt nie powinien zaczynac z pustymi rekami.
func on_respawn() -> void:
	var slots: Array = (get_parent() as Player).info.slots
	if ItemStack.is_empty(slots[_wanted_slot]):
		select_slot(maxi(Inventory.first_occupied(slots), 0))


func _gather() -> void:
	if not is_multiplayer_authority():
		return
	_keep_selection_valid()
	if not Net.bot_mode.is_empty():
		_gather_bot()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump = Input.is_action_pressed("jump")
		# Po uzyciu przedmiotu trzymany przycisk nie strzela kolejna bronia, dopoki go nie pusci.
		_fire_blocked = _fire_blocked and Input.is_action_pressed("fire")
		use_primary = Input.is_action_pressed("fire") and not _fire_blocked and not wheel_open
		aim = Input.is_action_pressed("aim") and not wheel_open
		sprint = Input.is_action_pressed("sprint")
		crouch = Input.is_action_pressed("crouch")
		reload = Input.is_action_pressed("reload")
	else:
		move = Vector2.ZERO
		jump = false
		use_primary = false
		aim = false
		sprint = false
		crouch = false
		reload = false
	_update_scope_sway()
	_keep_dance_valid()
	dance = _wanted_dance
	slot = _wanted_slot
	yaw = look_yaw
	pitch = look_pitch
	view_tick = -1 if multiplayer.is_server() else RemoteMotion.view_tick()


## Luneta lekko plywa. Ruch trafia do wejscia, wiec serwer liczy strzal tam, gdzie gracz widzi celownik.
func _update_scope_sway() -> void:
	var scoped := (get_parent() as Player).is_scoped()
	_sway_time = _sway_time + NetworkTime.ticktime if scoped else 0.0
	var target := Vector2(sin(_sway_time * SCOPE_SWAY_SPEED), sin(_sway_time * SCOPE_SWAY_SPEED * 1.7 + 0.6) * 0.6) * SCOPE_SWAY if scoped else Vector2.ZERO
	look_yaw += target.x - _sway.x
	look_pitch = clampf(look_pitch + target.y - _sway.y, -MAX_PITCH, MAX_PITCH)
	_sway = target


## Prosty bot do testow i cwiczen w pojedynke.
func _gather_bot() -> void:
	_bot_time += NetworkTime.ticktime
	var me := get_parent() as Player
	match Net.bot_mode:
		"runner":
			move = Vector2(sin(_bot_time * 0.9), -0.8).normalized()
			look_yaw += 0.02
			jump = fmod(_bot_time, 4.0) < 0.1
			sprint = fmod(_bot_time, 9.0) < 3.0
		"shooter":
			var target := _nearest_enemy(me)
			use_primary = target != null
			if target != null:
				var to_target := target.position + Vector3.UP * 0.9 - me.eye_position()
				look_yaw = atan2(-to_target.x, -to_target.z)
				look_pitch = asin(clampf(to_target.normalized().y, -1.0, 1.0))
			move = Vector2(sin(_bot_time * 0.7), 0.0)
		"switcher":
			# Test sieci: zmienia sloty, strzela i przeladowuje, a potem przestaje.
			var active := _bot_time < float(Net.args.get("bot-seconds", 18.0))
			use_primary = active and fmod(_bot_time, 2.0) < 1.2
			reload = active and fmod(_bot_time, 5.0) < 0.1
			aim = active and fmod(_bot_time, 3.0) < 1.5
			move = Vector2(sin(_bot_time * 0.8), cos(_bot_time * 0.6)) if active else Vector2.ZERO
			if active and fmod(_bot_time, 1.5) < NetworkTime.ticktime:
				select_slot(Inventory.next_occupied(me.info.slots, _wanted_slot, 1))
		"looter":
			# Test sieci: na zmiane wyrzuca i podnosi przedmiot, strzelajac miedzy tym.
			var step := int(_bot_time / LOOTER_STEP_SECONDS)
			var looting := _bot_time < float(Net.args.get("bot-seconds", 18.0))
			use_primary = looting and fmod(_bot_time, 3.0) < 0.4
			if looting and step != _bot_step:
				_bot_step = step
				if step % 2 == 0:
					me.try_drop()
				else:
					me.try_pickup()
		"opener":
			# Test sieci: idzie do najblizszej zamknietej skrzynki i otwiera ja.
			var opening_time := _bot_time < float(Net.args.get("bot-seconds", 18.0))
			var chest := _nearest_closed_chest(me)
			move = Vector2.ZERO
			bot_interact = false
			if opening_time and not chest.is_empty():
				var to_chest: Vector3 = chest.position + Vector3.UP * Chests.AIM_HEIGHT - me.eye_position()
				look_yaw = atan2(-to_chest.x, -to_chest.z)
				look_pitch = asin(clampf(to_chest.normalized().y, -1.0, 1.0))
				if me.position.distance_to(chest.position) > OPENER_REACH:
					move = Vector2(0.0, -1.0)
				else:
					Chests.arm()
					bot_interact = true
		"medic":
			# Test sieci: trzyma apteczke i leczy sie, gdy jest ranny. Sloty dostaje z --debug-items.
			var kit := _find_item(me, &"medkit")
			if kit >= 0 and _wanted_slot != kit:
				select_slot(kit)
			use_primary = kit >= 0 and me.info.health < GameState.MAX_HEALTH
		"grenadier":
			# Test sieci: co kilka sekund rzuca granat, gdy jakis ma.
			var grenade := _find_item(me, &"grenade")
			var throwing := fmod(_bot_time, 3.0) < 0.4 and grenade >= 0
			if grenade >= 0 and _wanted_slot != grenade:
				select_slot(grenade)
			look_pitch = 0.25
			look_yaw += 0.01
			use_primary = throwing
		"brawler":
			# Test sieci: z nozem biegnie do najblizszego gracza i tnie, gdy jest blisko.
			var knife := _find_item(me, &"knife")
			var enemy := _nearest_enemy(me) if _bot_time < float(Net.args.get("bot-seconds", 3600.0)) else null
			if knife >= 0 and _wanted_slot != knife:
				select_slot(knife)
			move = Vector2.ZERO
			use_primary = false
			if enemy != null:
				_look_at(me, enemy.position + Vector3.UP * 0.9)
				var distance := me.position.distance_to(enemy.position)
				move = Vector2(0.0, -1.0) if distance > 1.6 else Vector2.ZERO
				use_primary = knife >= 0 and distance < 2.6
		"pumper":
			# Test sieci: strzela ze strzelby do najblizszego gracza. Przeladowuje sam, gdy brak naboi.
			var shotgun := _find_item(me, &"shotgun")
			var prey := _nearest_enemy(me) if _bot_time < float(Net.args.get("bot-seconds", 3600.0)) else null
			if shotgun >= 0 and _wanted_slot != shotgun:
				select_slot(shotgun)
			use_primary = shotgun >= 0 and prey != null
			if prey != null:
				_look_at(me, prey.position + Vector3.UP * 0.9)
				move = Vector2(0.0, -1.0) if me.position.distance_to(prey.position) > 6.0 else Vector2.ZERO
			else:
				move = Vector2.ZERO
		"dancer":
			# Test sieci: tanczy po kolei wszystkie tance i co chwile sie rusza, co musi je przerwac.
			var dancing_time := _bot_time < float(Net.args.get("bot-seconds", 3600.0))
			var phase := fmod(_bot_time, DANCER_STEP_SECONDS)
			move = Vector2.RIGHT if dancing_time and phase >= DANCER_MOVE_AFTER and phase < DANCER_MOVE_UNTIL else Vector2.ZERO
			if dancing_time and phase >= 1.0 and phase < DANCER_MOVE_AFTER and _wanted_dance == DanceCatalog.NONE:
				request_dance(1 + int(_bot_time / DANCER_STEP_SECONDS) % DanceCatalog.DANCES.size())
		"ducker":
			# Test sieci: stoi w miejscu i na zmiane kuca i wstaje co 4 s.
			move = Vector2.ZERO
			crouch = fmod(_bot_time, 8.0) < 4.0
		"overhead":
			# Test sieci: podchodzi do celu i strzela w gorna czesc glowy stojacego, 25 cm nad glowa kucajacego.
			# Strzela tylko, gdy cel na ekranie kuca (--aim-when=crouched) albo stoi (standing).
			var victim := _named_player(Net.args.get("bot-target", ""))
			use_primary = false
			aim = false
			move = Vector2.ZERO
			if victim != null:
				var head := victim.shown_position() + Vector3.UP * OVERHEAD_AIM_HEIGHT
				_look_at(me, head)
				# Widocznosc sprawdzamy na wysokosci tulowia, bo strzal nad kucajacym i tak trafia w cos za nim.
				var chest := victim.shown_position() + Vector3.UP * 0.35
				var clear: bool = Hitscan.trace(me.get_world_3d(), me.eye_position(), me.eye_position().direction_to(chest), me.peer_id, get_tree()).player == victim
				# Strzal w stojacego ma sens tylko wtedy, gdy nic nie zaslania tez jego glowy.
				if Net.args.get("aim-when", "crouched") != "crouched" and victim.shown_crouch() == 0.0:
					clear = clear and Hitscan.trace(me.get_world_3d(), me.eye_position(), me.eye_position().direction_to(head), me.peer_id, get_tree()).player == victim
				var distance := me.position.distance_to(victim.position)
				if not clear or distance > 18.0:
					# Prosto do celu, a co kilka sekund w bok, zeby obejsc przeszkode.
					move = Vector2(1.0 if fmod(_bot_time, 6.0) < 1.5 else 0.0, -1.0).normalized()
				else:
					var wanted := 1.0 if Net.args.get("aim-when", "crouched") == "crouched" else 0.0
					aim = true
					use_primary = victim.shown_crouch() == wanted and fmod(_bot_time, 0.5) < NetworkTime.ticktime * 2.0 and me.equipment.spread_bloom == 0.0 and me.is_on_floor() and Vector2(me.velocity.x, me.velocity.z).length() < 0.1
		"sniper":
			# Test sieci: z AWP w lunecie strzela w tulow wskazanego gracza, gdy widac go w calosci.
			var awp := _find_item(me, &"awp")
			var mark := _named_player(Net.args.get("bot-target", ""))
			if awp >= 0 and _wanted_slot != awp:
				select_slot(awp)
			move = Vector2.ZERO
			use_primary = false
			aim = mark != null and awp >= 0
			if mark != null:
				var body := mark.shown_position() + Vector3.UP * 0.35
				_look_at(me, body)
				var seen := Hitscan.trace(me.get_world_3d(), me.eye_position(), me.eye_position().direction_to(body), me.peer_id, get_tree())
				if seen.player != mark:
					move = Vector2(1.0 if fmod(_bot_time, 6.0) < 1.5 else 0.0, -1.0).normalized()
					aim = false
				else:
					use_primary = me.is_scoped() and me.camera_zoomed_in() and fmod(_bot_time, 0.5) < NetworkTime.ticktime * 2.0
		"headhunter":
			# Strzela tylko, gdy na ekranie ma dokladnie glowe celu w celowniku.
			var target := _nearest_enemy(me)
			use_primary = false
			move = Vector2.ZERO
			if target != null:
				var to_head := target.position + Vector3.UP * Hitscan.HEAD_CENTER - me.eye_position()
				look_yaw = atan2(-to_head.x, -to_head.z)
				look_pitch = asin(clampf(to_head.normalized().y, -1.0, 1.0))
				var seen := Hitscan.trace(me.get_world_3d(), me.eye_position(), to_head.normalized(), me.peer_id, get_tree())
				use_primary = seen.player == target and to_head.length() > 2.0 and me.equipment.spread_bloom == 0.0 and me.is_on_floor()


func _look_at(me: Player, point: Vector3) -> void:
	var to_point := point - me.eye_position()
	look_yaw = atan2(-to_point.x, -to_point.z)
	look_pitch = asin(clampf(to_point.normalized().y, -1.0, 1.0))


func _find_item(me: Player, item_id: StringName) -> int:
	for index in Inventory.SLOTS:
		if StringName(me.info.slots[index].get("item", "")) == item_id:
			return index
	return -1


func _nearest_closed_chest(me: Player) -> Dictionary:
	var best := {}
	var best_distance := INF
	for id: int in Chests.chests:
		var chest: Dictionary = Chests.chests[id]
		var distance := me.position.distance_squared_to(chest.position)
		if not chest.open and distance < best_distance:
			best_distance = distance
			best = chest
	return best


func _named_player(player_name: String) -> Player:
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if other.info.name == player_name and other.is_alive():
			return other
	return null


func _nearest_enemy(me: Player) -> Player:
	var best: Player = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if other == me or not other.is_alive():
			continue
		var distance := me.position.distance_squared_to(other.position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best
