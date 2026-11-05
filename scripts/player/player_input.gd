class_name PlayerInput
extends Node
## Wejscie gracza. Ten wezel nalezy do klienta, a netfox przesyla jego wlasciwosci
## na serwer co tick.

const MOUSE_SENSITIVITY := 0.0025
const MAX_PITCH := 1.5
const LOOTER_STEP_SECONDS := 0.9
const OPENER_REACH := 2.2

# Wysylane do serwera (input_properties w RollbackSynchronizer).
var move := Vector2.ZERO
var jump := false
var use_primary := false
## Slot, ktory gracz chce miec w reku.
var slot := 0
var sprint := false
var reload := false
var yaw := 0.0
var pitch := 0.0
## Bot trzyma klawisz otwierania. Gracz ma go w Input.
var bot_interact := false
## Tick stanu innych graczy widoczny teraz na ekranie. -1 oznacza stan biezacy.
var view_tick := -1

# Biezace polozenie kamery aktualizowane co klatke. Rollback nadpisuje yaw i pitch
# wartosciami z historii, wiec akumulator musi byc osobno.
var look_yaw := 0.0
var look_pitch := 0.0

var _bot_time := 0.0
var _bot_step := 0
# Wybor gracza zmienia sie miedzy tickami, a rollback nadpisuje "slot" historia.
var _wanted_slot := 0
var _wanted_uid := 0
var _displayed_state_tick := -1


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)
	NetworkTime.after_tick_loop.connect(_on_after_tick_loop)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = MOUSE_SENSITIVITY * Settings.value("sensitivity")
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
			return
	var me := get_parent() as Player
	if event.is_action_pressed("interact"):
		me.try_interact()
		return
	if event.is_action_pressed("drop_item"):
		me.try_drop()
		return
	var slots: Array = me.info.slots
	if event.is_action_pressed("next_slot"):
		select_slot(Inventory.next_occupied(slots, _wanted_slot, 1))
	elif event.is_action_pressed("prev_slot"):
		select_slot(Inventory.next_occupied(slots, _wanted_slot, -1))


## Gdy przedmiot z wybranego slotu zniknie, np. po smierci, wracamy do czegos w reku.
## Slot wybrany celowo jako pusty zostaje pusty.
func _keep_selection_valid() -> void:
	var slots: Array = (get_parent() as Player).info.slots
	var uid := ItemStack.uid_of(slots[_wanted_slot])
	if _wanted_uid != 0 and uid == 0:
		select_slot(maxi(Inventory.first_occupied(slots), 0))
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
		use_primary = Input.is_action_pressed("fire")
		sprint = Input.is_action_pressed("sprint")
		reload = Input.is_action_pressed("reload")
	else:
		move = Vector2.ZERO
		jump = false
		use_primary = false
		sprint = false
		reload = false
	slot = _wanted_slot
	yaw = look_yaw
	pitch = look_pitch
	view_tick = _displayed_state_tick


## Stan odebrany w trakcie ticku trafia na ekran dopiero po kolejnej petli, wiec gracz
## celuje w ten, ktory byl najnowszy pod koniec poprzedniej.
func _on_after_tick_loop() -> void:
	if is_multiplayer_authority():
		_displayed_state_tick = _newest_state_tick()


func _newest_state_tick() -> int:
	if multiplayer.is_server():
		return -1
	var newest := -1
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if not other.is_local():
			newest = maxi(newest, other.sync.get_last_known_state())
	return newest


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
				use_primary = seen.player == target and to_head.length() > 2.0


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
