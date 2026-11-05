extends Node
## Test ekwipunku w oknie gry, jako host.
## Uzycie: godot --path . --resolution 1280x720 -- --tool=res://tools/inventory_test.gd --server-items

const PORT := 8120

var _failures := 0
var _pinned: Player
var _pinned_at := Vector3.ZERO


func _ready() -> void:
	_check_inventory_logic()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var player := get_node("/root/Main/Players/1") as Player
	# Okno testu moze nie miec fokusu, a sterowanie dziala tylko z przechwycona mysza.
	get_window().focus_exited.disconnect((get_node("/root/Main/Hud") as Hud)._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var equipment := player.equipment

	_check("start: blaster w slocie 1", ItemStack.tier_of(GameState.players[1].slots[0]) == Rarity.Tier.COMMON and equipment.active_slot == 0)
	_check("start: pelny magazynek", equipment.active_charges() == 12)
	_check("start: reszta pusta", ItemStack.is_empty(GameState.players[1].slots[1]) and ItemStack.is_empty(GameState.players[1].slots[3]))

	GameState.server_give_item(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.EPIC)
	GameState.server_give_item(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.LEGENDARY)
	await _wait(0.2)
	_check("nowe przedmioty maja wlasne naboje", equipment.charges(1) == 16 and equipment.charges(2) == 20)

	await _press_key("slot_2")
	_check("klawisz 2 wybiera slot", equipment.active_slot == 1)
	_check("epicki blaster ma swoje parametry", equipment.active_stats().damage == 24)
	_check("widok broni nadal jest", player.view_model.has_item())
	_check("model zgadza sie z klasa", player.view_model.shown_visual() == ItemStack.visual_of(equipment.active_stack()))
	var muzzle_local := player.view_model.overlay_camera().to_local(player.view_model.muzzle_position())
	_check("lufa jest przed kamera", muzzle_local.z < -0.3)

	await _hold("fire", 0.35)
	var epic_left := equipment.charges(1)
	_check("strzal zuzywa naboje aktywnego slotu", epic_left < 16 and equipment.charges(0) == 12 and equipment.charges(2) == 20)

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_check("scroll w dol idzie do nastepnego", equipment.active_slot == 2)
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_check("scroll pomija pusty slot i zawija", equipment.active_slot == 0)
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	_check("scroll w gore zawija i pomija pusty", equipment.active_slot == 2)
	await _press_key("slot_2")
	_check("slot pamieta naboje", equipment.charges(1) == epic_left)

	# Wyciaganie broni: strzal zaraz po zmianie jest zablokowany.
	await _press_key("slot_1")
	await _press_key("slot_2", 0.0)
	var before_draw := equipment.charges(1)
	Input.action_press("fire")
	await _wait(0.1)
	_check("wyciaganie broni blokuje strzal", equipment.charges(1) == before_draw)
	await _wait(0.5)
	Input.action_release("fire")
	_check("po wyciagnieciu mozna strzelac", equipment.charges(1) < before_draw)

	await _press_key("slot_4")
	_check("klawisz wybiera pusty slot", equipment.active_slot == 3 and ItemStack.is_empty(equipment.active_stack()))
	_check("pusty slot chowa bron", not player.view_model.has_item())
	var last_fire := equipment.last_fire
	await _hold("fire", 0.3)
	_check("z pustymi rekami nie ma strzalu", equipment.last_fire == last_fire)

	# Przeladowanie: zmiana slotu przerywa je razem z dzwiekiem, takze gdy nowy slot jest pelny.
	await _press_key("slot_2")
	await _wait(0.4)
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	_check("przeladowanie trwa", equipment.is_busy() and player.reload_audio.playing)
	var partly := equipment.charges(1)
	await _press_key("slot_3")
	_check("zmiana slotu przerywa przeladowanie", not equipment.is_busy())
	_check("zmiana slotu przerywa dzwiek", not player.reload_audio.playing)
	_check("przerwanie nie dodaje nabojow", equipment.charges(1) == partly)
	_check("przeladowanie epickiego trwa krocej", is_equal_approx(ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.EPIC).reload_seconds, 1.4))

	await _press_key("slot_2")
	await _wait(0.4)
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	await _wait(1.5)
	_check("pelne przeladowanie uzupelnia wlasciwy magazynek", equipment.charges(1) == 16)

	# Rzadkosc wplywa na obrazenia na serwerze.
	GameState.server_add_player(2, "Cel")
	await _wait(0.2)
	var target := get_node("/root/Main/Players/2") as Player
	target.interpolator.enabled = false
	var forward := Hitscan.direction(player.input.look_yaw, 0.0)
	_pinned = target
	_pinned_at = player.position + forward * 3.0
	target.position = _pinned_at
	player.input.look_pitch = asin(((_pinned_at + Vector3.UP * 0.6 - player.eye_position()).normalized()).y)
	await _wait(0.3)
	# Sztuczny cel nie jest cofany przez rollback, wiec strzal rozliczamy poza petla.
	var shooter_behavior := WeaponBehavior.new()
	for tier: int in [Rarity.Tier.COMMON, Rarity.Tier.EPIC, Rarity.Tier.LEGENDARY]:
		var stats := ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, tier)
		GameState.players[2].health = GameState.MAX_HEALTH
		target.position = _pinned_at
		shooter_behavior._resolve_shot(equipment, stats, NetworkTime.tick)
		var damage_dealt: int = GameState.MAX_HEALTH - GameState.players[2].health
		print("[test] %s zadaje %d" % [Rarity.display_name(tier), damage_dealt])
		if damage_dealt == 0:
			var aim := Hitscan.trace(player.get_world_3d(), player.eye_position(), Hitscan.direction(player.yaw, player.pitch), 1, get_tree())
			print("[test] diagnostyka: gracz=%s yaw=%.3f pitch=%.3f look_yaw=%.3f look_pitch=%.3f cel=%s trafienie=%s" % [player.position, player.yaw, player.pitch, player.input.look_yaw, player.input.look_pitch, target.position, aim])
		_check("%s zadaje obrazenia ze swoich danych" % Rarity.display_name(tier), damage_dealt == stats.damage)
	_pinned = null

	# Smierc: zdobyte przedmioty znikaja, zostaje startowy blaster, a wybor wraca na niego.
	GameState.server_damage(1, 500, 2)
	await _wait(0.2)
	_check("smierc zabiera zdobyte przedmioty", ItemStack.is_empty(GameState.players[1].slots[1]) and ItemStack.is_empty(GameState.players[1].slots[2]))
	_check("startowy blaster zostaje", not ItemStack.is_empty(GameState.players[1].slots[0]))
	await _wait(GameState.RESPAWN_SECONDS + 0.3)
	_check("po odrodzeniu aktywny jest blaster", equipment.active_slot == 0 and player.view_model.has_item())
	_check("po odrodzeniu magazynek jest pelny", equipment.charges(0) == 12)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## Sztuczny cel nie ma klienta, wiec trzymamy go w miejscu mimo przywracania stanu.
func _process(_delta: float) -> void:
	if _pinned != null:
		_pinned.position = _pinned_at


func _check_inventory_logic() -> void:
	var slots := Inventory.empty_slots()
	_check("cztery sloty", slots.size() == 4)
	_check("wolny slot na pustym", Inventory.first_free(slots) == 0)
	slots[0] = { "uid": 1 }
	slots[2] = { "uid": 2 }
	_check("pierwszy wolny pomija zajety", Inventory.first_free(slots) == 1)
	_check("scroll w przod", Inventory.next_occupied(slots, 0, 1) == 2)
	_check("scroll zawija", Inventory.next_occupied(slots, 2, 1) == 0)
	_check("scroll wstecz zawija", Inventory.next_occupied(slots, 0, -1) == 2)
	_check("z pustego slotu do zajetego", Inventory.next_occupied(slots, 3, 1) == 0)
	slots[1] = { "uid": 3 }
	slots[3] = { "uid": 4 }
	_check("pelny ekwipunek nie ma wolnego", Inventory.first_free(slots) == -1)


func _press_key(action: String, settle := 0.45) -> void:
	var event := InputEventAction.new()
	event.action = StringName(action)
	event.pressed = true
	Input.parse_input_event(event)
	await _wait(0.12 + settle * 0.0)
	if settle > 0.0:
		await _wait(settle)


func _wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _wait(0.25)


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
