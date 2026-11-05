extends Node
## Test postaci i wyboru w menu, jako host.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/character_test.gd

const PORT := 8128
const NEEDED_CLIPS: Array[String] = ["Idle", "Running_A", "Running_B", "Walking_Backwards", "Running_Strafe_Left",
		"Running_Strafe_Right", "Jump_Idle", "2H_Ranged_Aiming", "2H_Ranged_Shoot", "2H_Ranged_Reload", "Hit_A", "Death_A"]

var _failures := 0


func _ready() -> void:
	_check_roster()
	await _check_picker()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	var me := get_node("/root/Main/Players/1") as Player
	_check("host gra wybrana postacia", GameState.players[1].character == Net.player_character)

	# Kazda postac dziala jako inny gracz: animacje, bron w rece i lufa.
	var id := 2
	var reference := Vector2.ZERO
	for entry: Dictionary in CharacterAssets.ROSTER:
		GameState.server_add_player(id, "Test", entry.id)
		await _wait(0.1)
		var node := get_node("/root/Main/Players").get_node(str(id)) as Player
		_check("%s: zapis na serwerze" % entry.id, GameState.players[id].character == entry.id)
		node.model.play_shot()
		await _wait(0.2)
		var muzzle := node.model.muzzle_position()
		var height := muzzle.y - node.position.y
		var distance := Vector2(muzzle.x - node.position.x, muzzle.z - node.position.z).length()
		print("[test] %s: lufa na wysokosci %.2f, od srodka %.2f" % [entry.id, height, distance])
		# Wszystkie postacie maja trzymac bron tam, gdzie pierwsza z listy.
		if reference == Vector2.ZERO:
			reference = Vector2(height, distance)
		_check("%s: bron w dloni jak u innych" % entry.id, Vector2(height, distance).distance_to(reference) < 0.1)
		id += 1

	GameState.server_add_player(50, "Zly", "nie_ma_takiej")
	_check("nieznana postac dostaje domyslna", CharacterAssets.index_of(GameState.players[50].character) >= 0)
	GameState.server_add_player(51, "Pusty", "")
	_check("brak wyboru daje postac", CharacterAssets.index_of(GameState.players[51].character) >= 0)
	_check("rece w pierwszej osobie dzialaja", me.view_model.has_item())

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_roster() -> void:
	_check("jest wiecej postaci", CharacterAssets.ROSTER.size() >= 9)
	var names := {}
	for entry: Dictionary in CharacterAssets.ROSTER:
		names[entry.id] = true
		var character := CharacterAssets.character_for(entry.id)
		var player := CharacterAssets.player_of(character)
		var missing := NEEDED_CLIPS.filter(func(clip: String) -> bool: return not player.has_animation(clip))
		_check("%s: ma wszystkie animacje" % entry.id, missing.is_empty())
		var skeleton := CharacterAssets.skeleton_of(character)
		_check("%s: ma kosci do celowania" % entry.id, skeleton.find_bone("chest") >= 0 and skeleton.find_bone("head") >= 0)
		var animation := player.get_animation("Idle")
		var broken := 0
		for track in animation.get_track_count():
			if skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames()) < 0:
				broken += 1
		_check("%s: animacje trafiaja w kosci" % entry.id, broken == 0)
		_check("%s: uchwyt broni" % entry.id, CharacterAssets.prepare_hands(character).get_node_or_null("Muzzle") != null)
		character.free()
	_check("identyfikatory sa unikalne", names.size() == CharacterAssets.ROSTER.size())


func _check_picker() -> void:
	var picker := get_node("/root/Main/Menu")._picker as CharacterPicker
	var first := picker.selected_id()
	picker.step(1)
	var second := picker.selected_id()
	_check("strzalka zmienia postac", second != first)
	_check("wybor trafia do ustawien", Settings.player_value("character", "") == second)
	picker.step(-1)
	_check("strzalka wstecz wraca", picker.selected_id() == first)
	for i in CharacterAssets.ROSTER.size():
		picker.step(1)
		await get_tree().process_frame
	_check("lista zawija sie w kolko", picker.selected_id() == first)
	picker.select(second)
	await _wait(0.1)
	get_node("/root/Main/Menu")._apply_settings()
	_check("menu przekazuje wybor do gry", Net.player_character == second)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
