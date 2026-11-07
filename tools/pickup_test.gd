extends Node
## Test podnoszenia i wyrzucania w oknie gry, jako host.
## Uzycie: godot --path . --resolution 1280x720 -- --tool=res://tools/pickup_test.gd

const PORT := 8121

var _failures := 0


func _ready() -> void:
	_check_slot_choice()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var player := get_node("/root/Main/Players/1") as Player
	get_window().focus_exited.disconnect((get_node("/root/Main/Hud") as Hud)._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Patrzymy poziomo, zeby rzucony przedmiot wyladowal przed graczem.
	player.input.look_pitch = 0.0
	var slots: Array = GameState.players[1].slots
	var equipment := player.equipment
	var field := get_node("/root/Main").find_children("*", "PickupField", false, false)[0] as PickupField

	await _hold("fire", 0.4)
	var ammo_left := equipment.charges(0)
	_check("strzal zuzyl naboje", ammo_left < 12)
	var starter_uid := ItemStack.uid_of(slots[0])
	await _press("drop_item")
	_check("G oproznia slot", ItemStack.is_empty(slots[0]))
	_check("przedmiot lezy na ziemi", WorldItems.items.size() == 1 and field.view_count() == 1)
	var entry: Dictionary = WorldItems.items.values()[0]
	_check("wyrzucony pamieta naboje", entry.stack.charges == ammo_left)
	_check("reka jest pusta", not player.view_model.has_item())
	_check("spada na podloge blisko gracza", absf(entry.position.y - player.position.y) < 0.6 and player.position.distance_to(entry.position) < 2.4)

	await _wait(0.2)
	_check("gracz celuje w przedmiot", WorldItems.focused_id == entry.id)
	await _press("interact")
	_check("E podnosi do pustej reki", ItemStack.uid_of(slots[0]) == starter_uid and WorldItems.items.is_empty())
	_check("po podniesieniu naboje wracaja", equipment.charges(0) == ammo_left)
	_check("bron znow jest w reku", player.view_model.has_item())
	await _wait(0.1)
	_check("nic juz nie jest celem", WorldItems.focused_id == 0)

	# Serwer pilnuje zasiegu i poprawnosci prosby.
	WorldItems._server_spawn(ItemStack.create(9001, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.EPIC), player.position, player.position + Vector3(20.0, 0.0, 0.0))
	await _wait(0.1)
	var far_id: int = WorldItems.items.keys()[0]
	WorldItems._server_pickup.rpc_id(1, far_id)
	await _wait(0.1)
	_check("za daleko sie nie podniesie", WorldItems.items.has(far_id) and ItemStack.is_empty(slots[1]))
	WorldItems._server_drop.rpc_id(1, 2, 12345)
	WorldItems._server_drop.rpc_id(1, 0, 12345)
	WorldItems._server_drop.rpc_id(1, 99, starter_uid)
	await _wait(0.1)
	_check("zla prosba o wyrzucenie nic nie robi", WorldItems.items.size() == 1 and ItemStack.uid_of(slots[0]) == starter_uid)
	WorldItems._remove_item.rpc(far_id, 0)

	# Podniesienie do wolnego slotu nie zmienia broni w reku.
	var next_uid := 9100
	for tier: int in [Rarity.Tier.EPIC, Rarity.Tier.LEGENDARY, Rarity.Tier.EPIC]:
		next_uid += 1
		await _spawn_and_take(player, ItemStack.create(next_uid, ItemRegistry.DEFAULT_WEAPON, tier))
	_check("wolne sloty zapelniaja sie po kolei", ItemStack.uid_of(slots[1]) == 9101 and ItemStack.uid_of(slots[2]) == 9102 and ItemStack.uid_of(slots[3]) == 9103)
	_check("podniesienie nie zmienia broni w reku", equipment.active_slot == 0)
	_check("nowy egzemplarz wnosi naboje", equipment.charges(2) == 20)

	# Pelny ekwipunek: podniesiony zamienia sie z tym w reku.
	await _press("slot_2", 0.3)
	await _spawn_and_take(player, ItemStack.create(9104, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.LEGENDARY))
	_check("przy pelnym zamienia z aktywnym", ItemStack.uid_of(slots[1]) == 9104)
	_check("zamieniony wypada na ziemie", WorldItems.items.size() == 1 and ItemStack.uid_of(WorldItems.items.values()[0].stack) == 9101)
	_check("po zamianie reka ma nowy model", player.view_model.shown_visual() == ItemStack.visual_of(slots[1]))

	# Wyrzucenie aktywnego przelacza na inny przedmiot.
	await _press("drop_item")
	_check("po wyrzuceniu wybor idzie na zajety slot", player.input.selected_slot() == 0 and equipment.active_slot == 0)
	for id: int in WorldItems.items.keys():
		WorldItems._remove_item.rpc(id, 0)
	await _wait(0.1)
	_check("widoki sprzatniete", field.view_count() == 0)

	# Dolaczajacy dostaje stan, a przedmiot sam znika po czasie.
	WorldItems._server_spawn(ItemStack.create(9200, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON), player.position, player.position + Vector3(1.0, 0.0, 0.0))
	await _wait(0.1)
	var expiring: int = WorldItems.items.keys()[0]
	WorldItems.items[expiring].expires_tick = NetworkTime.tick
	await _wait(WorldItems.EXPIRY_CHECK_SECONDS + 0.2)
	_check("przedmiot znika po czasie", WorldItems.items.is_empty())

	# Smierc: zdobyte wypadaja, a startowy zostaje.
	GameState.server_add_player(2, "Cel")
	await _wait(0.1)
	var death_spot := player.position
	GameState.server_damage(1, 500, 2)
	await _wait(0.2)
	_check("smierc zostawia startowy", ItemStack.uid_of(slots[0]) == starter_uid and ItemStack.is_empty(slots[2]) and ItemStack.is_empty(slots[3]))
	_check("zdobyte leza na ziemi", WorldItems.items.size() == 2)
	for id: int in WorldItems.items:
		_check("wypadly blisko miejsca smierci", WorldItems.items[id].position.distance_to(death_spot) < 3.0)
	await _press("drop_item", 0.1)
	_check("martwy nie wyrzuca", ItemStack.uid_of(slots[0]) == starter_uid)
	await _wait(GameState.RESPAWN_SECONDS + 0.3)
	_check("po odrodzeniu pelny magazynek", equipment.charges(0) == 12 and equipment.active_slot == 0)

	# Wyrzucony startowy nie wypada drugi raz, a gracz dostaje nowy.
	await _press("drop_item")
	var dropped_starter := _item_with_uid(starter_uid)
	_check("startowy mozna wyrzucic", dropped_starter != 0)
	# Po odrodzeniu w Deathmatchu gracz ma chwile ochrony.
	GameState.players[1].protected_until = -1
	GameState.server_damage(1, 500, 2)
	await _wait(0.2)
	_check("bez startowego dostaje nowy", not ItemStack.is_empty(slots[0]) and ItemStack.uid_of(slots[0]) != starter_uid and slots[0].get("starter", false))

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _spawn_and_take(player: Player, stack: Dictionary) -> void:
	WorldItems._server_spawn(stack, player.position, player.position + Vector3.UP * 0.1)
	await _wait(0.1)
	var id: int = WorldItems.items.keys().max()
	WorldItems._server_pickup.rpc_id(1, id)
	await _wait(0.2)


func _item_with_uid(uid: int) -> int:
	for id: int in WorldItems.items:
		if ItemStack.uid_of(WorldItems.items[id].stack) == uid:
			return id
	return 0


func _check_slot_choice() -> void:
	var slots := Inventory.empty_slots()
	_check("pusta reka ma pierwszenstwo", Inventory.slot_for_pickup(slots, 2) == 2)
	slots[2] = { "uid": 1 }
	_check("potem pierwszy wolny", Inventory.slot_for_pickup(slots, 2) == 0)
	slots[0] = { "uid": 2 }
	slots[1] = { "uid": 3 }
	slots[3] = { "uid": 4 }
	_check("pelny zamienia aktywny", Inventory.slot_for_pickup(slots, 1) == 1)


func _press(action: String, settle := 0.35) -> void:
	var event := InputEventAction.new()
	event.action = StringName(action)
	event.pressed = true
	Input.parse_input_event(event)
	await _wait(settle)


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)
	await _wait(0.1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
