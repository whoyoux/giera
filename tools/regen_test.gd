extends Node
## Test regeneracji w Deathmatchu: opoznienie, tempo, przerwanie trafieniem, smierc, HUD i tabela lupu.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/regen_test.gd [--shot-dir=C:/folder]

const PORT := 8143

var _failures := 0


func _ready() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	var me: Dictionary = GameState.players[1]

	# Lup Deathmatchu nie ma apteczek, a Battle Royale je zachowuje.
	_check("Deathmatch bez apteczek", not Chests.loot_table().item_ids.has(&"medkit"))
	_check("Battle Royale z apteczkami", Chests.LOOT_TABLE.item_ids.has(&"medkit"))
	var rng := RandomNumberGenerator.new()
	var rolled_medkit := false
	for i in 3000:
		rolled_medkit = rolled_medkit or Chests.loot_table().roll(rng).item == &"medkit"
	_check("skrzynka w Deathmatchu nie daje apteczki", not rolled_medkit)
	_check("start bez apteczki", not _has_medkit(me.slots))

	GameState.server_damage(1, 50, 0)
	_check("trafienie odlicza 6 s", me.regen_tick == NetworkTime.tick + NetworkTime.seconds_to_ticks(GameState.REGEN_DELAY_SECONDS))
	await _wait(1.0)
	_check("HUD pokazuje odliczanie", hud._regen_label.visible and hud._regen_label.text.begins_with("Leczenie za"))
	await _wait(4.6)
	_check("przed 6 s bez leczenia", me.health == 50)
	await _wait(1.4)
	_check("po 6 s leczy", me.health > 50)
	_check("HUD pokazuje leczenie", hud._regen_label.visible and hud._regen_label.text.begins_with("+ Leczenie"))
	var shot_dir: String = Net.args.get("shot-dir", "")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("regen.png"))
	var before: int = me.health
	await _wait(1.0)
	var rate: int = me.health - before
	print("[test] leczenie przez 1 s: %d" % rate)
	_check("okolo 8 HP na sekunde", rate >= 6 and rate <= 10)

	# Trafienie w trakcie leczenia przerywa je od razu i odlicza 6 s od nowa.
	GameState.server_damage(1, 10, 0)
	var after_hit: int = me.health
	await _wait(0.1)
	_check("HUD pokazuje przerwanie", hud._regen_label.text == "Leczenie przerwane!")
	if not shot_dir.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("regen_stop.png"))
	await _wait(5.5)
	_check("po przerwaniu HP nie rosnie przez 6 s", me.health == after_hit)
	await _wait(1.2)
	_check("potem leczy dalej", me.health > after_hit)
	await _wait(12.0)
	_check("leczy do pelna i konczy", me.health == GameState.MAX_HEALTH and me.regen_tick == -1)
	_check("HUD chowa napis", not hud._regen_label.visible)

	# Smierc zeruje regeneracje.
	GameState.server_damage(1, 30, 0)
	GameState.server_damage(1, 200, 0)
	_check("smierc zeruje leczenie", me.regen_tick == -1 and not me.alive)
	await _wait(4.0)
	_check("po odrodzeniu pelne zdrowie bez leczenia", me.alive and me.health == GameState.MAX_HEALTH and me.regen_tick == -1)

	# W Battle Royale zdrowie nie wraca samo.
	GameState.server_add_player(5, "Krolik")
	Match.mode = GameMode.Id.BATTLE_ROYALE
	var bunny: Dictionary = GameState.players[5]
	var saved_phase := Match.phase
	Match.phase = Match.Phase.LIVE
	GameState.server_damage(5, 40, 0)
	_check("Battle Royale: trafienie nie wlacza leczenia", bunny.regen_tick == -1)
	await _wait(0.6)
	_check("Battle Royale: zdrowie stoi", bunny.health == 60)
	Match.phase = saved_phase
	Match.mode = GameMode.Id.DEATHMATCH
	get_tree().quit(1 if _failures > 0 else 0)


func _has_medkit(slots: Array) -> bool:
	for stack: Dictionary in slots:
		if stack.get("item", "") == "medkit":
			return true
	return false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
