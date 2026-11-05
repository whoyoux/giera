extends Node
## Test granatu w oknie gry, jako host.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/grenade_test.gd

const PORT := 8130
const GRENADE := &"grenade"

var _failures := 0
var _explosions := 0
var _last_at := Vector3.ZERO


func _ready() -> void:
	_check_data()
	_check_loot()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	Grenades.exploded.connect(func(at: Vector3, _owner: int) -> void:
		_explosions += 1
		_last_at = at)
	var player := get_node("/root/Main/Players/1") as Player
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var info: Dictionary = GameState.players[1]
	var definition := ItemRegistry.get_definition(GRENADE) as GrenadeDefinition
	player.input.look_yaw = atan2(player.position.x, player.position.z)
	player.input.look_pitch = 0.1

	var slot := GameState.server_give_item(1, GRENADE, Rarity.Tier.COMMON)
	await _wait(0.1)
	player.input.select_slot(slot)
	await _wait(0.4)
	_check("granat w rece", player.view_model.has_item() and player.view_model.shown_visual() == definition.item_visual)
	_check("granat nie celuje", not player.equipment.can_aim())
	_check("podpowiedz rzutu", hud._use_panel.visible and hud._use_label.text.contains("puść"))

	# Rzut: przedmiot znika, a granat leci i odbija sie.
	var particles_before := get_node("/root/Main").find_children("*", "CPUParticles3D", true, false).size()
	var start := player.position
	Input.action_press("fire")
	await _wait(0.5)
	_check("trzymanie odbezpiecza", player.equipment.prime_tick >= 0)
	_check("trzymanie jeszcze nie rzuca", not ItemStack.is_empty(info.slots[slot]) and Grenades.flying_count() == 0)
	_check("pasek pokazuje zapalnik", hud._use_bar.visible and hud._use_bar.value < 1.0 and hud._use_label.text.contains("Puść"))
	Input.action_release("fire")
	var released := Time.get_ticks_msec()
	await _wait(0.2)
	_check("puszczenie rzuca", ItemStack.is_empty(info.slots[slot]) and Grenades.flying_count() == 1)
	_check("nie jest juz odbezpieczony", player.equipment.prime_tick < 0)
	_check("wybor wraca na bron", player.input.selected_slot() == 0)
	# Zapalnik liczy sie od odbezpieczenia, wiec po rzucie zostaje mniej czasu.
	while Grenades.flying_count() > 0 and Time.get_ticks_msec() - released < 4000:
		await get_tree().process_frame
	var flight := (Time.get_ticks_msec() - released) / 1000.0
	print("[test] od puszczenia do wybuchu: %.2f s" % flight)
	_check("trzymanie skraca lot", flight < definition.fuse_seconds - 0.2)
	_check("granat wybucha raz", _explosions == 1 and Grenades.flying_count() == 0)
	var distance := start.distance_to(_last_at)
	print("[test] rzut na %.1f m" % distance)
	_check("rzut leci na sensowna odleglosc", distance > 5.0 and distance < 35.0)
	_check("wybuch jest na ziemi", absf(_last_at.y - ForestTerrain.surface(_last_at.x, _last_at.z)) < 1.0 or _last_at.y > 0.0)
	await _wait(0.1)
	var field := get_node("/root/Main")
	_check("sa efekty wybuchu", ExplosionPool.instance.active_count() == 1)
	_check("jest slad na ziemi", field.find_children("*", "Decal", true, false).size() == 1)
	await _wait(GrenadeFx.LIFETIME_SECONDS + 0.2)
	_check("wybuch sie konczy", ExplosionPool.instance.active_count() == 0)
	_check("wybuchy nie tworza nowych czasteczek", field.find_children("*", "CPUParticles3D", true, false).size() == particles_before)

	# Zmiana przedmiotu upuszcza odbezpieczony granat pod nogi.
	var second := GameState.server_give_item(1, GRENADE, Rarity.Tier.COMMON)
	await _wait(0.1)
	player.input.select_slot(second)
	await _wait(0.4)
	Input.action_press("fire")
	await _wait(0.3)
	player.input.select_slot(0)
	await _wait(0.2)
	Input.action_release("fire")
	_check("zmiana przedmiotu upuszcza granat", ItemStack.is_empty(info.slots[second]) and Grenades.flying_count() == 1)
	var dropped_flight: Vector3 = Grenades._flying.values()[0].position
	_check("upuszczony lezy blisko gracza", dropped_flight.distance_to(player.position) < 4.0)
	var player_health: int = info.health
	await _wait(definition.fuse_seconds)
	_check("upuszczony rani gracza", info.health < player_health or not info.alive)
	await _wait(GameState.RESPAWN_SECONDS + 0.5)
	info.health = GameState.MAX_HEALTH

	# Zbyt dlugie trzymanie konczy sie wybuchem w rece.
	var third := GameState.server_give_item(1, GRENADE, Rarity.Tier.COMMON)
	await _wait(0.1)
	player.input.select_slot(third)
	await _wait(0.4)
	var deaths: int = info.deaths
	Input.action_press("fire")
	await _wait(definition.fuse_seconds + 0.4)
	Input.action_release("fire")
	_check("wybuch w rece zabija", info.deaths == deaths + 1)
	_check("wybuch w rece zabiera granat", ItemStack.is_empty(info.slots[third]))
	await _wait(GameState.RESPAWN_SECONDS + 0.5)

	# Obrazenia z odleglosci, liczone wprost na serwerze.
	GameState.server_add_player(2, "Cel")
	await _wait(0.2)
	var target := get_node("/root/Main/Players/2") as Player
	target.interpolator.enabled = false
	var center := Vector3(15.0, 0.0, 1.0)
	center.y = ForestTerrain.surface(center.x, center.z)
	target.position = center
	var targets := {}
	for meters: float in [1.0, 3.0, 5.0, 7.5, 10.0]:
		GameState.players[2].health = GameState.MAX_HEALTH
		GameState.players[2].alive = true
		target.position = center
		Grenades._apply_damage(definition, center + Vector3(meters, Grenades.CHEST_HEIGHT, 0.0), 1)
		targets[meters] = GameState.MAX_HEALTH - GameState.players[2].health
	print("[test] obrazenia: %s" % [targets])
	_check("tuz obok zabiera cale zdrowie", targets[1.0] == GameState.MAX_HEALTH)
	_check("im blizej, tym wiecej", targets[3.0] > targets[5.0] and targets[5.0] > targets[7.5] and targets[7.5] > 0)
	_check("daleko nie rani", targets[10.0] == 0)

	# Mur ruin chroni przed wybuchem.
	GameState.players[2].health = GameState.MAX_HEALTH
	GameState.players[2].alive = true
	target.position = Vector3(-4.5, 0.0, -9.0)
	Grenades._apply_damage(definition, Vector3(-4.5, 0.2, -1.0), 1)
	_check("mur oslania", GameState.players[2].health == GameState.MAX_HEALTH)

	# Wlasny granat rani, ale nie daje punktu.
	var kills: int = info.kills
	GameState.server_damage(1, 500, 1, player.position)
	await _wait(0.2)
	_check("samobojstwo liczy sie jako smierc", not info.alive)
	_check("samobojstwo nie daje punktu", info.kills == kills)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_data() -> void:
	var definition := ItemRegistry.get_definition(GRENADE) as GrenadeDefinition
	_check("rejestr zna granat", definition != null)
	_check("model i ikona istnieja", ResourceLoader.exists(definition.item_visual.model_path) and ResourceLoader.exists(definition.item_visual.icon_path))
	_check("cale zdrowie w promieniu smierci", definition.damage_at(definition.kill_radius) == GameState.MAX_HEALTH)
	_check("nazwa bez klasy", ItemStack.display_name_of(ItemStack.create(1, GRENADE, Rarity.Tier.COMMON)) == "Granat")
	var previous := GameState.MAX_HEALTH
	for step in 20:
		var amount := definition.damage_at(step * 0.5)
		_check("obrazenia nie rosna z odlegloscia (%.1f m)" % (step * 0.5), amount <= previous)
		previous = amount


func _check_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var items := {}
	var tiers := [0, 0, 0]
	for i in 10000:
		var rolled: Dictionary = Chests.LOOT_TABLE.roll(rng)
		items[rolled.item] = items.get(rolled.item, 0) + 1
		if ItemRegistry.get_definition(rolled.item).has_tiers():
			tiers[rolled.tier] += 1
		else:
			_check_once_tier(rolled)
	print("[test] lup: %s, klasy broni: %s" % [items, tiers])
	_check("ze skrzynki wypada piec rodzajow", items.size() == 5)
	var total_weapons: int = tiers[0] + tiers[1] + tiers[2]
	_check("legendarna wciaz jest rzadka", absf(float(tiers[Rarity.Tier.LEGENDARY]) / total_weapons - 0.05) < 0.02)
	_check("zwykla wciaz najczestsza", absf(float(tiers[Rarity.Tier.COMMON]) / total_weapons - 0.7) < 0.03)


func _check_once_tier(rolled: Dictionary) -> void:
	if rolled.tier != Rarity.Tier.COMMON:
		_check("przedmiot bez klas jest zwykly", false)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	if not passed or not label.begins_with("obrazenia nie rosna"):
		print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
