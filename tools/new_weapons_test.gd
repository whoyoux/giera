extends Node
## Test Desert Eagle i AWP w oknie gry, jako host: obrazenia, tempo, rozrzut, luneta, wypadanie.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/new_weapons_test.gd [--shot-dir=C:/folder]

const PORT := 8137
## Stad w strone -X jest ponad 40 m wolnej drogi.
const SHOOTING_SPOT := Vector3(22.0, 0.0, 1.0)

var _failures := 0
var _player: Player
var _target: Player
var _hud: Hud


func _ready() -> void:
	_check_definitions()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_player = get_node("/root/Main/Players/1") as Player
	_hud = get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(_hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.server_add_player(2, "Cel")
	await _wait(0.2)
	_target = get_node("/root/Main/Players/2") as Player
	var deagle_slot := GameState.server_give_item(1, &"deagle", Rarity.Tier.COMMON)
	var awp_slot := GameState.server_give_item(1, &"awp", Rarity.Tier.COMMON)
	_check("bronie trafiaja do slotow", deagle_slot >= 0 and awp_slot >= 0)
	await _wait(0.3)
	await _test_deagle(deagle_slot)
	await _test_awp(awp_slot)
	await _test_scope(awp_slot)
	await _test_drop(deagle_slot)
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_definitions() -> void:
	var deagle := ItemRegistry.get_definition(&"deagle") as WeaponDefinition
	var awp := ItemRegistry.get_definition(&"awp") as WeaponDefinition
	_check("definicje sa w spisie", deagle != null and awp != null)
	var stats := deagle.stats(Rarity.Tier.COMMON)
	_check("Deagle: 55 obrazen, 7 naboi", stats.damage == 55 and stats.magazine == 7)
	_check("Deagle: 0,65 s miedzy strzalami", absf(stats.fire_interval_ticks / float(NetworkTime.tickrate) - 0.65) < 0.03)
	for tier: int in [Rarity.Tier.COMMON, Rarity.Tier.EPIC, Rarity.Tier.LEGENDARY]:
		var deagle_tier := deagle.stats(tier)
		_check("Deagle %d: dwa trafienia zabijaja" % tier, deagle_tier.damage < GameState.MAX_HEALTH and deagle_tier.damage * 2 >= GameState.MAX_HEALTH)
		_check("AWP %d: jedno trafienie zabija" % tier, awp.stats(tier).damage >= GameState.MAX_HEALTH and awp.stats(tier).headshot_damage >= GameState.MAX_HEALTH)
	var awp_stats := awp.stats(Rarity.Tier.COMMON)
	_check("AWP: 5 naboi i 1,6 s", awp_stats.magazine == 5 and absf(awp_stats.fire_interval_ticks / float(NetworkTime.tickrate) - 1.6) < 0.03)
	_check("AWP: dlugie przeladowanie", awp_stats.reload_seconds >= 3.0)
	_check("AWP: luneta", awp_stats.scope and not stats.scope)
	_check("zasieg na cala duza mape", Hitscan.RANGE >= 450.0)
	_check("AWP: wolniejszy ruch", awp.move_speed_scale() < 1.0)
	for definition: WeaponDefinition in [deagle, awp]:
		var visual := definition.visual(Rarity.Tier.COMMON)
		_check("%s: model i ikona" % definition.display_name, ResourceLoader.exists(visual.model_path) and ResourceLoader.exists(visual.icon_path))
	var table := Chests.LOOT_TABLE
	var awp_weight: int = table.item_weights[table.item_ids.find(&"awp")] if table.item_ids.has(&"awp") else -1
	var lightest: int = table.item_weights.min()
	_check("obie w skrzynkach, AWP wsrod najrzadszych", table.item_ids.has(&"deagle") and awp_weight > 0 and awp_weight == lightest)


func _test_deagle(slot: int) -> void:
	await _select(slot)
	_player.teleport(_spot(SHOOTING_SPOT))
	await _wait(0.5)
	var first := _attack_from(14.0)
	var second := _attack_from(14.0, false)
	print("[test] Deagle: %d, potem %d" % [first, second])
	_check("Deagle: jedno trafienie nie zabija", first == 55)
	_check("Deagle: drugie trafienie zabija", not GameState.players[2].alive)
	_check("Deagle: pierwszy strzal celny", _player.equipment.active_stats().spread_at(0.0, 0.0, false) <= 0.1)
	_revive_target()
	# Kolejny strzal dopiero po 0,65 s.
	var equipment := _player.equipment
	var stack := equipment.active_stack()
	var tick := NetworkTime.tick
	equipment.last_fire = -1000
	equipment.set_active_charges(3)
	equipment.input.use_primary = true
	ItemStack.behavior_of(stack).rollback_tick(equipment, stack, tick)
	ItemStack.behavior_of(stack).rollback_tick(equipment, stack, tick + 20)
	var after_fast := equipment.active_charges()
	ItemStack.behavior_of(stack).rollback_tick(equipment, stack, tick + 40)
	equipment.input.use_primary = false
	_check("Deagle: rzadkie strzaly", after_fast == 2 and equipment.active_charges() == 1)
	_check("Deagle: mocny rozrzut po strzale", equipment.spread_bloom >= 3.0)
	await _wait(0.5)


func _test_awp(slot: int) -> void:
	await _select(slot)
	_player.teleport(_spot(SHOOTING_SPOT))
	await _wait(0.5)
	# Dalej na tej linii stoja ruiny. Strzal z drugiego konca duzej mapy sprawdza test mapy.
	var awp_damage := _attack_from(18.0)
	print("[test] AWP: obrazenia %d, rozrzut strzalu %.2f, slot %s" % [awp_damage, _player.equipment.shot_spread, _player.equipment.active_stack().get("item", "")])
	_check("AWP: zabija jednym trafieniem", awp_damage >= GameState.MAX_HEALTH - 1 and not GameState.players[2].alive)
	_revive_target()
	var equipment := _player.equipment
	equipment.spread_bloom = 0.0
	_check("AWP: ogromny rozrzut bez lunety", equipment.current_spread() >= 8.0)
	Input.action_press("move_forward")
	await _wait(0.6)
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	Input.action_release("move_forward")
	print("[test] szybkosc z AWP: %.2f" % speed)
	_check("AWP: wolniejszy bieg", speed < Player.SPEED * 0.92 and speed > Player.SPEED * 0.7)
	await _wait(0.4)


func _test_scope(slot: int) -> void:
	await _select(slot)
	_player.teleport(_spot(SHOOTING_SPOT))
	_player.input.look_yaw = PI * 0.5
	_player.input.look_pitch = 0.0
	_player.equipment.set_active_charges(5)
	await _wait(0.6)
	var base_fov: float = Settings.value("fov")
	var plain_scale := _player.aim_sensitivity_scale()
	Input.action_press("aim")
	await _wait(0.6)
	var overlay := _hud.find_children("*", "ScopeOverlay", true, false)[0] as ScopeOverlay
	_check("PPM daje lunete", _player.aiming and overlay.visible and overlay.amount > 0.9)
	_check("mocne przyblizenie", _player.camera.fov < base_fov * 0.3)
	_check("model broni ukryty", not _player.view_model.is_shown())
	_check("nizsza czulosc myszy", _player.aim_sensitivity_scale() < plain_scale * 0.4)
	_check("celownik zwykly schowany", not _hud._crosshair.visible)
	_check("w lunecie bez rozrzutu na stojaco", _player.equipment.current_spread() < 0.01)
	var yaw_before := _player.input.look_yaw
	await _wait(0.8)
	_check("lekkie kolysanie", absf(_player.input.look_yaw - yaw_before) > 0.0001 and absf(_player.input.look_yaw - yaw_before) < 0.02)
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("awp_scope.png"))
	Input.action_press("fire")
	await _wait(0.15)
	Input.action_release("fire")
	_check("strzal wyrzuca z lunety", not _player.aiming)
	await _wait(0.3)
	_check("nakladka znika po strzale", overlay.amount < 0.5 and _player.view_model.is_shown())
	await _wait(1.6)
	_check("po przeladowaniu zamka luneta wraca", _player.aiming)
	Input.action_release("aim")
	await _wait(0.3)
	# Podczas przeladowania nie da sie celowac.
	Input.action_press("reload")
	await _wait(0.1)
	Input.action_release("reload")
	Input.action_press("aim")
	await _wait(0.5)
	_check("przeladowanie blokuje lunete", _player.equipment.is_reloading() and not _player.aiming)
	Input.action_release("aim")
	await _wait(3.6)
	if not shot_dir.is_empty():
		Input.action_press("aim")
		await _wait(0.2)
		Input.action_release("aim")
		_player.equipment.set_active_charges(1)
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("awp_hands.png"))


func _test_drop(slot: int) -> void:
	await _select(slot)
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("deagle_hands.png"))
	var before := WorldItems.items.size()
	_player.try_drop()
	await _wait(0.6)
	var dropped := WorldItems.items.values().filter(func(item: Dictionary) -> bool: return item.stack.item == "deagle")
	_check("Deagle wypada na ziemie", WorldItems.items.size() == before + 1 and dropped.size() == 1)
	if dropped.is_empty():
		return
	WorldItems.focused_id = dropped[0].id
	_player.try_pickup()
	await _wait(0.6)
	_check("Deagle wraca do reki", ItemStack.definition_of(_player.info.slots[slot]) != null and _player.info.slots[slot].item == "deagle")


func _select(slot: int) -> void:
	_player.input.select_slot(slot)
	await _wait(0.8)


func _spot(at: Vector3) -> Vector3:
	at.y = ForestTerrain.surface(at.x, at.z) + 0.05
	return at


## Rozlicza atak serwera od razu, jak w weapons_test.
func _attack_from(meters: float, reset := true) -> int:
	if reset:
		_revive_target()
	var from := _spot(SHOOTING_SPOT)
	var spot := from + Vector3.LEFT * meters
	spot.y = ForestTerrain.surface(spot.x, spot.z)
	var equipment := _player.equipment
	var stack := equipment.active_stack()
	var health_before: int = GameState.players[2].health
	_player.position = from
	_target.position = spot
	var aim := (spot + Vector3.UP * 0.6 - _player.eye_position()).normalized()
	_player.yaw = atan2(-aim.x, -aim.z)
	_player.pitch = asin(clampf(aim.y, -1.0, 1.0))
	_player.aiming = true
	_player.velocity = Vector3.ZERO
	equipment.spread_bloom = 0.0
	equipment.last_fire = -1000
	equipment._resolved_up_to = -1
	equipment.input.use_primary = true
	equipment.input.view_tick = -1
	equipment.set_active_charges(1)
	ItemStack.behavior_of(stack).rollback_tick(equipment, stack, NetworkTime.tick)
	equipment.input.use_primary = false
	_player.aiming = false
	return health_before - int(GameState.players[2].health)


func _revive_target() -> void:
	GameState.players[2].health = GameState.MAX_HEALTH
	GameState.players[2].alive = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
