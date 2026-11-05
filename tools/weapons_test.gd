extends Node
## Test strzelby i noza w oknie gry, jako host.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/weapons_test.gd

const PORT := 8131
const SHOTGUN := &"shotgun"
const KNIFE := &"knife"
## Stad w strone -X jest ponad 40 m wolnej drogi.
const SHOOTING_SPOT := Vector3(22.0, 0.0, 1.0)

var _failures := 0
var _hits := 0
var _player: Player
var _target: Player
var _hud: Hud


func _ready() -> void:
	_check_pattern()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_player = get_node("/root/Main/Players/1") as Player
	_hud = get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(_hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.server_add_player(2, "Cel")
	await _wait(0.2)
	_target = get_node("/root/Main/Players/2") as Player
	GameState.hit_confirmed.connect(func(_killed: bool) -> void: _hits += 1)
	await _test_spread()
	await _test_shotgun()
	await _test_knife()
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_pattern() -> void:
	var dir := Vector3(0.3, 0.1, -0.9).normalized()
	var first := Hitscan.pellet_directions(dir, 8, 5.5, 120)
	_check("osiem srucin", first.size() == 8)
	_check("wzor jest powtarzalny", first == Hitscan.pellet_directions(dir, 8, 5.5, 120))
	_check("kolejny strzal ma inny wzor", first != Hitscan.pellet_directions(dir, 8, 5.5, 121))
	var widest := 0.0
	for pellet in first:
		widest = maxf(widest, rad_to_deg(pellet.angle_to(dir)))
	_check("sruciny nie wychodza poza rozrzut", widest <= 5.51 and widest > 5.0)
	_check("bez rozrzutu pocisk leci prosto", Hitscan.pellet_directions(dir, 1, 0.0, 3)[0].is_equal_approx(dir))
	var seen := {}
	var far_enough := false
	var total := Vector3.ZERO
	for tick in 300:
		var single: Vector3 = Hitscan.pellet_directions(dir, 1, 2.0, tick)[0]
		var off := rad_to_deg(single.angle_to(dir))
		_check_quiet("pojedynczy pocisk w granicach rozrzutu", off <= 2.01)
		far_enough = far_enough or off > 1.5
		seen[single] = true
		total += single - dir
	_check("pojedynczy pocisk siega krawedzi", far_enough)
	_check("kazdy tick ma inny kierunek", seen.size() == 300)
	_check("rozrzut nie ucieka w jedna strone", rad_to_deg((total / 300.0).length()) < 0.2)
	_check("ten sam tick to ten sam kierunek", Hitscan.pellet_directions(dir, 1, 2.0, 77) == Hitscan.pellet_directions(dir, 1, 2.0, 77))


## Rozrzut na prawdziwych klawiszach: serie, ruch, celowanie i powrot do minimum.
func _test_spread() -> void:
	var equipment := _player.equipment
	var stats := equipment.active_stats()
	await _wait(0.4)
	_check("w miejscu rozrzut jest najmniejszy", is_equal_approx(equipment.current_spread(), stats.spread_degrees))
	_check("zwykly celownik w miejscu", _hud._crosshair.spread_radius < 7.0)

	# Pierwszy strzal jest najcelniejszy, a seria powieksza rozrzut az do limitu.
	Input.action_press("fire")
	await _wait(0.1)
	_check("pierwszy strzal ma najmniejszy rozrzut", is_equal_approx(equipment.shot_spread, stats.spread_degrees))
	await _wait(0.5)
	_check("seria zwieksza rozrzut", equipment.spread_bloom > stats.shot_spread_degrees)
	var charges_left := equipment.active_charges()
	await _wait(1.6)
	_check("seria dalej strzela", equipment.active_charges() < charges_left or equipment.is_reloading())
	_check("seria ma limit", is_equal_approx(equipment.spread_bloom, stats.max_bloom_degrees) or equipment.is_reloading())
	Input.action_release("fire")
	await _wait(0.05)
	_check("celownik pokazuje serie", _hud._crosshair.spread_radius > 7.0)
	await _wait(stats.max_bloom_degrees / stats.bloom_recovery + float(stats.fire_interval_ticks + Equipment.SPREAD_HOLD_TICKS) / 30.0 + 0.2)
	_check("po przerwie rozrzut wraca", equipment.spread_bloom == 0.0)
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	await _wait(stats.reload_seconds + 0.2)
	_check("po przeladowaniu magazynek pelny", equipment.active_charges() == stats.magazine)

	# Ruch powieksza rozrzut, a celowanie go zmniejsza.
	Input.action_press("move_forward")
	await _wait(0.5)
	var moving := equipment.current_spread()
	print("[test] rozrzut: stoi %.2f, biegnie %.2f" % [stats.spread_degrees, moving])
	_check("ruch powieksza rozrzut", moving > stats.spread_degrees + stats.move_spread_degrees * 0.8)
	_check("celownik pokazuje ruch", _hud._crosshair.spread_radius > 7.0)
	Input.action_press("aim")
	await _wait(0.5)
	_check("celowanie zmniejsza rozrzut w ruchu", equipment.current_spread() < moving * 0.7)
	Input.action_release("aim")
	Input.action_release("move_forward")
	await _wait(0.5)

	# W powietrzu najgorzej.
	Input.action_press("jump")
	await _wait(0.2)
	Input.action_release("jump")
	_check("skok powieksza rozrzut", equipment.current_spread() > stats.spread_degrees + stats.move_spread_degrees)
	await _wait(1.0)


func _test_shotgun() -> void:
	var slot := GameState.server_give_item(1, SHOTGUN, Rarity.Tier.COMMON)
	await _wait(0.1)
	# Seria z blastera nie przechodzi na kolejna bron.
	Input.action_press("fire")
	await _wait(0.5)
	Input.action_release("fire")
	_check("blaster ma narosly rozrzut", _player.equipment.spread_bloom > 0.0)
	_player.input.select_slot(slot)
	await _wait(0.1)
	_check("zmiana broni czysci serie", _player.equipment.spread_bloom == 0.0)
	var stats := _player.equipment.active_stats()
	_check("strzelba w rece", _player.view_model.shown_visual() == stats.visual)
	_check("wyciaganie blokuje strzal", _player.equipment.draw_end > NetworkTime.tick)
	await _wait(stats.draw_seconds)
	_check("strzelba pokazuje naboje", _hud._ammo_panel.visible and _hud._ammo_label.text == str(stats.magazine))
	await _wait(0.3)
	_check("celownik pokazuje rozrzut", _hud._crosshair._shown_radius > 20.0)

	# Prawdziwy klawisz: jeden naboj na strzal i odstep miedzy strzalami.
	var interval := stats.fire_interval_ticks / 30.0
	Input.action_press("fire")
	await _wait(interval - 0.15)
	Input.action_release("fire")
	_check("trzymanie szanuje odstep", _player.equipment.active_charges() == stats.magazine - 1)
	await _wait(interval)

	# Z bliska trafiaja wszystkie sruciny, a to wciaz jedno trafienie.
	var close_damage := _attack_from(3.0)
	print("[test] strzelba z 3 m: %d" % close_damage)
	_check("z bliska prawie zabija", close_damage >= stats.damage * (stats.pellets - 1))
	_check("jedno trafienie na strzal", _hits == 1)

	# Z daleka trafia tylko czesc srucin, ale srodek wciaz leci prosto.
	for meters: float in [6.0, 10.0, 14.0, 18.0]:
		print("[test] strzelba z %d m: %d" % [meters, _attack_from(meters)])
	var far_damage := _attack_from(14.0)
	_check("z daleka duzo slabiej", far_damage > 0 and far_damage < close_damage / 2)

	# Mur ruin zatrzymuje caly srut.
	_check("mur zatrzymuje srut", _damage_behind_wall() == 0)

	# Przeladowanie uzupelnia caly magazynek.
	await _wait(interval)
	Input.action_press("reload")
	await _wait(0.2)
	Input.action_release("reload")
	_check("R przeladowuje strzelbe", _player.equipment.is_reloading())
	await _wait(stats.reload_seconds + 0.2)
	_check("magazynek jest pelny", _player.equipment.active_charges() == stats.magazine)

	# Celowanie zmniejsza rozrzut.
	var hip_radius: float = _hud._crosshair.spread_radius
	Input.action_press("aim")
	await _wait(0.7)
	_check("celowanie zaciska rozrzut", _hud._crosshair.spread_radius < hip_radius)
	Input.action_release("aim")
	await _wait(0.3)
	_player.input.select_slot(0)
	await _wait(0.3)
	_check("blaster ma waski celownik", _hud._crosshair.spread_radius < hip_radius / 3.0)


func _test_knife() -> void:
	var slot := GameState.server_give_item(1, KNIFE, Rarity.Tier.COMMON)
	var definition := ItemRegistry.get_definition(KNIFE) as MeleeDefinition
	await _wait(0.1)
	_player.input.select_slot(slot)
	await _wait(definition.draw_time + 0.2)
	_check("noz w rece", _player.view_model.shown_visual() == definition.item_visual)
	_check("nazwa bez klasy", ItemStack.display_name_of(_player.equipment.active_stack()) == "Nóż")
	_check("noz nie ma pola nabojow", not _hud._ammo_panel.visible)
	_check("noz pokazuje podpowiedz", _hud._use_panel.visible and _hud._use_label.text.contains("cios"))
	_check("celownik noza jest zwykly", _hud._crosshair.spread_radius == 0.0)
	Input.action_press("aim")
	await _wait(0.3)
	_check("nozem sie nie celuje", not _player.aiming)
	Input.action_release("aim")

	# Prawdziwy klawisz: trzymanie tnie, ale nie czesciej niz pozwala odstep.
	var interval := definition.swing_interval_ticks / 30.0
	var swings := 0
	var last := _player.equipment.last_fire
	Input.action_press("fire")
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < interval * 2500.0:
		await get_tree().process_frame
		if _player.equipment.last_fire != last:
			last = _player.equipment.last_fire
			swings += 1
	Input.action_release("fire")
	print("[test] ciosow w %.2f s: %d" % [interval * 2.5, swings])
	_check("trzymanie tnie w rownym tempie", swings == 3)
	_check("cios nie zuzywa przedmiotu", not ItemStack.is_empty(GameState.players[1].slots[slot]))
	await _wait(interval)

	# Obrazenia i zasieg.
	_hits = 0
	_check("cios zadaje obrazenia", _attack_from(1.8) == definition.damage)
	_check("cios daje znacznik trafienia", _hits == 1)
	_check("cel tuz przy graczu tez obrywa", _attack_from(0.4) == definition.damage)
	_check("poza zasiegiem nie trafia", _attack_from(definition.reach + 1.5) == 0)
	_check("lekko obok celownika trafia", _attack_from(1.8, 15.0) == definition.damage)
	_check("cel z boku jest bezpieczny", _attack_from(1.8, 100.0) == 0)
	_check("mur oslania przed ciosem", _damage_behind_wall() == 0)

	# Dwa ciosy zabijaja.
	var kills: int = GameState.players[1].kills
	_attack_from(1.8)
	_attack_from(1.8, 0.0, false)
	_check("dwa ciosy zabijaja", not GameState.players[2].alive)
	_check("zabojstwo daje punkt", GameState.players[1].kills == kills + 1)
	_revive_target()
	await _wait(0.2)

	# Bieg z nozem jest szybszy.
	Input.action_press("move_forward")
	await _wait(0.5)
	var knife_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_player.input.select_slot(0)
	await _wait(0.4)
	var blaster_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	Input.action_release("move_forward")
	print("[test] szybkosc: noz %.2f, blaster %.2f" % [knife_speed, blaster_speed])
	_check("z nozem biega sie szybciej", absf(knife_speed - Player.SPEED * definition.speed_scale) < 0.3)
	# Na pochylym terenie predkosc pozioma jest troche mniejsza.
	_check("z blasterem normalnie", absf(blaster_speed - Player.SPEED) < 0.6 and knife_speed > blaster_speed + 0.4)


## Rozlicza atak serwera od razu. Netfox przywraca pozycje z historii na poczatku kazdego
## ticku, wiec ustawienie graczy i atak musza zdarzyc sie w tej samej chwili.
func _attack_from(meters: float, side_degrees := 0.0, reset := true) -> int:
	var from := SHOOTING_SPOT
	from.y = ForestTerrain.surface(from.x, from.z) + 0.05
	var spot := from + Vector3.LEFT.rotated(Vector3.UP, deg_to_rad(side_degrees)) * meters
	spot.y = ForestTerrain.surface(spot.x, spot.z)
	return _attack(from, spot, spot + Vector3.UP * 0.9 if side_degrees == 0.0 else from + Vector3.LEFT + Vector3.UP * Player.EYE_HEIGHT, reset)


## Mur wiezy ruin stoi miedzy tymi punktami.
func _damage_behind_wall() -> int:
	var from := Vector3(-4.5, 0.0, -3.0)
	return _attack(from, Vector3(-4.5, 0.0, -9.0), Vector3(-4.5, 0.9, -9.0), true)


func _attack(from: Vector3, spot: Vector3, look_at_point: Vector3, reset: bool) -> int:
	if reset:
		_revive_target()
	_hits = 0 if reset else _hits
	var equipment := _player.equipment
	var stack := equipment.active_stack()
	var health_before: int = GameState.players[2].health
	_player.position = from
	_target.position = spot
	var aim := (look_at_point - _player.eye_position()).normalized()
	_player.yaw = atan2(-aim.x, -aim.z)
	_player.pitch = asin(clampf(aim.y, -1.0, 1.0))
	_player.aiming = false
	var tick := NetworkTime.tick
	equipment.spread_bloom = 0.0
	_player.velocity = Vector3.ZERO
	equipment.last_fire = -1000
	equipment._resolved_up_to = -1
	equipment.input.use_primary = true
	equipment.input.view_tick = -1
	if equipment.active_stats() != null:
		equipment.set_active_charges(1)
	ItemStack.behavior_of(stack).rollback_tick(equipment, stack, tick)
	equipment.input.use_primary = false
	return health_before - int(GameState.players[2].health)


func _revive_target() -> void:
	GameState.players[2].health = GameState.MAX_HEALTH
	GameState.players[2].alive = true


func _check_quiet(label: String, passed: bool) -> void:
	if not passed:
		_check(label, false)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
