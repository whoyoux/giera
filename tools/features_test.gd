extends Node
## Test zbiorczy pomyslow z grup A, B i C, jako host: trafienia w glowe, ekran smierci, bezpieczne
## odrodzenia z ochrona, serie, nagrody, liczby obrazen, slizg, apteczka, glosowanie na mape,
## drabiny, zrzuty, slady po kulach, statystyki i samouczek.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --map=forest --tool=res://tools/features_test.gd [--shot-dir=C:/folder]

const PORT := 8151

var _failures := 0
var _details: Array[Dictionary] = []
var _streaks: Array[String] = []


func _ready() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.hit_details.connect(func(details: Dictionary) -> void: _details.append(details))
	GameState.streak_announced.connect(func(kind: String, _k: int, _v: int, _c: int) -> void: _streaks.append(kind))
	GameState.server_add_player(2, "Cel")
	GameState.server_add_player(3, "Basia")
	await _wait(0.5)
	var me := GameState.player_node(1)

	# Trafienie w glowe, liczby obrazen i ekran smierci.
	var numbers := get_node("/root/Main").find_children("*", "DamageNumbers", false, false)[0] as DamageNumbers
	var labels_before := numbers.get_child_count()
	GameState.server_damage(2, 40, 1, Vector3.INF, {}, { "headshot": true, "position": Vector3(15.0, 1.4, 1.0) })
	await _wait(0.1)
	_check("szczegoly trafienia w glowe", not _details.is_empty() and _details[-1].headshot and _details[-1].amount == 40)
	_check("liczba obrazen nad celem", numbers.get_child_count() > labels_before)
	Settings.set_value("show_damage_numbers", false)
	var labels_off := numbers.get_child_count()
	GameState.server_damage(2, 10, 1)
	await _wait(0.05)
	_check("ustawienie wylacza liczby", numbers.get_child_count() <= labels_off)
	Settings.set_value("show_damage_numbers", true)
	GameState.server_damage(3, 100, 1)
	GameState.server_damage(2, 100, 1, Vector3.INF, { "item": "deagle", "tier": 0 }, { "headshot": true })
	_check("podwojne zabojstwo", _streaks.has("double"))
	var victim: Dictionary = GameState.players[2]
	_check("pierwsza krew", _streaks.has("first_blood"))
	_check("smierc pamieta zabojce i jego zdrowie", victim.killer_id == 1 and victim.killer_health == me.info.health and victim.death_headshot)
	_check("ekran smierci opisuje zabojce", hud._death_cause(victim, 2).contains("Gracz") and hud._death_cause(victim, 2).contains("HP"))

	# Bezpieczne odrodzenie: punkt jest najdalej od zywych przeciwnikow.
	var points := get_tree().get_nodes_in_group(&"spawn_points")
	var chosen: Vector3 = (points[victim.spawn_index] as Node3D).global_position
	var nearest_to_chosen := chosen.distance_to(me.position)
	var worse := 0
	for node in points:
		if (node as Node3D).global_position.distance_to(me.position) > nearest_to_chosen + 0.5:
			worse += 1
	_check("odrodzenie z dala od wroga", worse == 0)
	# Ochrona po odrodzeniu: sprawdzana na wlasnej postaci, bo tylko ona jest symulowana.
	GameState.server_damage(1, 200, 2)
	await _wait(GameState.RESPAWN_SECONDS + 0.4)
	var mine: Dictionary = GameState.players[1]
	print("[test] ochrona: zyje=%s do %d, teraz %d" % [mine.alive, mine.protected_until, NetworkTime.tick])
	_check("ochrona po odrodzeniu", mine.alive and NetworkTime.tick < mine.protected_until)
	GameState.server_damage(1, 30, 2)
	_check("ochrona blokuje obrazenia", mine.health == GameState.MAX_HEALTH)
	GameState.server_on_shot(1)
	GameState.server_damage(1, 30, 2)
	_check("strzal konczy ochrone", mine.health == 70)
	me = GameState.player_node(1)

	# Nagrody na podium.
	var awards := PodiumView.awards([
		{ "id": 1, "name": "A", "kills": 5, "place": 1, "shots": 10, "hits": 4, "headshots": 1 },
		{ "id": 2, "name": "B", "kills": 3, "place": 2, "shots": 6, "hits": 5, "headshots": 3 },
	])
	_check("nagrody: zabojstwa, celnosc, glowa", awards.size() == 3 and awards[1].contains("B") and awards[2].contains("B"))

	# Slizg: kucniecie w sprincie popycha i zabiera pasek sprintu.
	me.teleport(Vector3(22.0, ForestTerrain.surface(22.0, 1.0) + 0.1, 1.0))
	me.input.look_yaw = PI * 0.5
	await _wait(0.4)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(0.6)
	var stamina_before := me.stamina
	Input.action_press("crouch")
	await _wait(0.1)
	var slide_speed := Vector2(me.velocity.x, me.velocity.z).length()
	print("[test] slizg: %.2f m/s, pasek %.0f -> %.0f" % [slide_speed, stamina_before, me.stamina])
	_check("slizg rusza", me.is_sliding() and slide_speed > Player.SPEED * 1.4)
	_check("slizg zuzywa sprint", me.stamina < stamina_before - 15.0)
	await _wait(0.9)
	_check("slizg sie konczy", not me.is_sliding())
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Input.action_release("crouch")
	await _wait(0.4)

	# Apteczka przerwana trafieniem.
	var kit := GameState.server_give_item(1, &"medkit", Rarity.Tier.COMMON)
	GameState.players[1].health = 50
	me.input.select_slot(kit)
	await _wait(0.8)
	Input.action_press("fire")
	await _wait(0.5)
	var busy := me.equipment.is_busy()
	GameState.server_damage(1, 5, 2)
	await _wait(0.2)
	print("[test] apteczka: zajeta=%s potem=%s hit=%d koniec=%d zdrowie=%d" % [busy, me.equipment.is_busy(), me.info.hit_tick, me.equipment.action_end, me.info.health])
	_check("trafienie przerywa apteczke", busy and not me.equipment.is_busy())
	Input.action_release("fire")
	await _wait(0.3)

	# Slad po kuli i odpryski.
	var fx_root := me.get_parent()
	var children := fx_root.get_child_count()
	ShotFx.bullet_hole(fx_root, Vector3(0.0, 1.0, 0.0), Vector3.UP, ForestTerrain.Ground.STONE)
	_check("slad po kuli i odpryski", fx_root.get_child_count() >= children + 5)

	# Statystyki i samouczek.
	var stats := get_node("/root/Main/PlayerStats") as PlayerStats
	_check("statystyki licza zabojstwa", stats.value("kills") >= 2 and stats.summary().size() == 6)
	_check("samouczek nie przeszkadza testom", not TutorialPanel.should_show())

	# Zrzut zaopatrzenia w Battle Royale.
	SupplyDrops._server_drop({ "target_center": Vector2(15.0, 1.0), "target_radius": 2.0 })
	await _wait(0.1)
	_check("zrzut ogloszony", SupplyDrops.drops.size() == 1)
	var drop: Dictionary = SupplyDrops.drops.values()[0]
	drop.land_tick = NetworkTime.tick
	Match.mode = GameMode.Id.BATTLE_ROYALE
	Match.zone = Zone.new(5)
	Match.zone_start_tick = NetworkTime.tick
	var items_before := WorldItems.items.size()
	SupplyDrops._dropped_phases = [0, 1, 2]
	await _wait(0.3)
	_check("zrzut kladzie najlepszy lup", WorldItems.items.size() >= items_before + 4)
	Match.zone = null
	Match.mode = GameMode.Id.DEATHMATCH
	var maps := hud.find_children("*", "ZoneMap", true, false)
	_check("mala i duza mapa", maps.size() == 2 and maps.any(func(map: ZoneMap) -> bool: return map.big))

	# Poprawki: Desert Eagle w glowe, skala interfejsu, otwarta skrzynka, reset statystyk, granat.
	var deagle := ItemRegistry.get_definition(&"deagle") as WeaponDefinition
	_check("zwykly Deagle 90 w glowe, epicki zabija", deagle.stats(Rarity.Tier.COMMON).headshot_damage == 90 and deagle.stats(Rarity.Tier.EPIC).headshot_damage >= GameState.MAX_HEALTH)
	Settings.set_value("ui_size", 1.3)
	_check("interfejs nie rosnie ponad 100%", is_equal_approx(get_tree().root.content_scale_factor, 1.0))
	Settings.set_value("ui_size", 0.7)
	_check("maly interfejs", is_equal_approx(get_tree().root.content_scale_factor, 0.7))
	Settings.set_value("ui_size", 1.0)
	var field := get_node("/root/Main")._chest_field as ChestField
	var chest_id: int = Chests.chests.keys()[0]
	var closed_height: float = (field._shapes[chest_id].shape as BoxShape3D).size.y
	Chests._chest_opened.rpc(chest_id, 1, Rarity.Tier.COMMON)
	_check("otwarta skrzynka nizsza", (field._shapes[chest_id].shape as BoxShape3D).size.y < closed_height - 0.3)
	var stats_panel := get_node("/root/Main").find_children("*", "StatsPanel", false, false)[0] as StatsPanel
	stats_panel.open(stats)
	(stats_panel.find_child("reset_stats", true, false) as Button).pressed.emit()
	_check("reset statystyk pyta o potwierdzenie", stats_panel._confirm.visible and stats.value("kills") > 0)
	(stats_panel.find_child("confirm_reset", true, false) as Button).pressed.emit()
	_check("potwierdzenie usuwa statystyki", stats.value("kills") == 0 and not stats_panel._confirm.visible)
	stats_panel.visible = false
	var thrower := GameState.player_node(1)
	Grenades._thrown.rpc(900, "grenade", Vector3(15.0, 6.0, 1.0), Vector3.ZERO, 30.0, 2)
	await _wait(0.05)
	var grenade_at: Vector3 = (Grenades._flying[900] as Node3D).global_position
	_check("strzal w lecacy granat go odpala", Grenades.server_shoot(grenade_at + Vector3(0, 0, 5), grenade_at - Vector3(0, 0, 5), thrower.peer_id) and not Grenades._flying.has(900))

	# Glosowanie na mape i drabiny w miescie.
	Match.votes = { 1: "city", 2: "city", 3: "forest" }
	Match._apply_vote()
	await _wait(0.5)
	_check("glosowanie zmienia mape bez restartu", Maps.current_id == "city" and get_tree().get_nodes_in_group(&"spawn_points").size() >= 12)
	_check("w miescie sa drabiny", Maps.info().ladders().size() >= 4)
	var ladder: AABB = Maps.info().ladders()[0]
	var bottom := ladder.get_center()
	bottom.y = 0.05
	me.teleport(bottom)
	await _wait(0.3)
	me.input.look_yaw = -PI * 0.5
	Input.action_press("move_forward")
	await _wait(1.2)
	Input.action_release("move_forward")
	print("[test] drabina: wysokosc %.2f, bryla %s, gracz %s" % [me.position.y, str(ladder), str(me.position)])
	_check("wspinanie po drabinie", me.position.y > 2.5)
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("ladder.png"))
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
