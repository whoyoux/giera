extends Node
## Test skrzynek w oknie gry, jako host. Uruchamiaj z dodatkowymi skrzynkami przy punktach odrodzenia.
## Uzycie: godot --path . --resolution 1280x720 -- --debug-chests --tool=res://tools/chest_test.gd

const PORT := 8122

var _failures := 0
var _player: Player
var _chest: Dictionary


func _ready() -> void:
	_check_loot_table()
	await _check_map_spots()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_player = get_node("/root/Main/Players/1") as Player
	get_window().focus_exited.disconnect((get_node("/root/Main/Hud") as Hud)._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_chest = _nearest_chest()
	_check("skrzynka jest w zasiegu", _player.position.distance_to(_chest.position) < Chests.OPEN_RANGE)
	_look_at_chest()
	await _wait(0.2)
	_check("gracz celuje w skrzynke", Chests.focused_id == _chest.id)

	# Krotkie klikniecie nie otwiera.
	await _hold_key(0.25)
	_check("klikniecie nie otwiera", not _chest.open and WorldItems.items.is_empty())
	await _wait(1.2)
	_check("przerwane otwieranie nie konczy sie samo", not _chest.open)
	_check("skrzynka nie jest zajeta po przerwaniu", not _chest.busy)

	# Patrzenie w bok przerywa.
	_key(true)
	await _wait(0.3)
	_check("pasek rosnie", Chests.local_progress() > 0.1)
	_check("skrzynka jest zajeta", _chest.busy)
	_player.input.look_yaw += PI
	await _wait(0.2)
	_check("odwrocenie sie przerywa", not _chest.busy and Chests.local_progress() == 0.0)
	_look_at_chest()
	await _wait(0.2)
	_check("trzymany klawisz nie rusza drugi raz", Chests.local_progress() == 0.0)
	_key(false)
	await _wait(0.1)

	# Strzal przerywa.
	_key(true)
	await _wait(0.3)
	Input.action_press("fire")
	await _wait(0.1)
	Input.action_release("fire")
	_key(false)
	await _wait(0.1)
	_check("strzal przerywa", not _chest.busy and not _chest.open)

	# Pelne otwarcie trwa okolo sekundy i daje lup.
	await _wait(0.5)
	_key(true)
	var started := Time.get_ticks_msec()
	while not _chest.open and Time.get_ticks_msec() - started < 3000:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	_key(false)
	print("[test] otwieranie trwalo %.2f s" % elapsed)
	_check("otwarcie trwa okolo sekundy", elapsed > 0.8 and elapsed < 1.5)
	var dropped := WorldItems.items.size()
	_check("wypada bron i czasem apteczka", dropped == 1 or dropped == 2)
	var entry: Dictionary = WorldItems.items.values()[0]
	_check("lup wypada blisko gracza", _player.position.distance_to(entry.position) < 4.0)
	await _wait(0.1)
	_check("otwarta skrzynka nie jest celem", Chests.focused_id == 0)
	await _hold_key(1.3)
	_check("otwartej nie da sie otworzyc znowu", WorldItems.items.size() <= dropped)
	Chests._server_start.rpc_id(1, _chest.id)
	_check("serwer odrzuca otwarta skrzynke", not Chests._openings.has(1))

	# Serwer pilnuje zasiegu.
	var far := _farthest_chest()
	Chests._server_start.rpc_id(1, far.id)
	await _wait(1.3)
	_check("daleka skrzynka sie nie otwiera", not far.open and not Chests._openings.has(1))

	# Dwoch graczy przy jednej skrzynce: wygrywa pierwszy, a drugi przestaje otwierac.
	_chest.open = false
	Chests._openings[1] = { "chest": _chest.id, "end_tick": NetworkTime.tick }
	Chests._openings[777] = { "chest": _chest.id, "end_tick": NetworkTime.tick + 90 }
	await get_tree().process_frame
	await get_tree().process_frame
	_check("wspolne otwieranie konczy sie raz", _chest.open and Chests._openings.is_empty())

	# Smierc przerywa, a skrzynka wraca po czasie.
	var second := _second_nearest()
	Chests._openings[1] = { "chest": second.id, "end_tick": NetworkTime.tick + 90 }
	GameState.server_add_player(2, "Cel")
	await _wait(0.1)
	GameState.server_damage(1, 500, 2)
	await _wait(0.2)
	_check("smierc przerywa otwieranie", not Chests._openings.has(1))
	_chest.reopen_tick = NetworkTime.tick
	await _wait(Chests.RESPAWN_CHECK_SECONDS + 0.2)
	_check("skrzynka wraca po czasie", not _chest.open)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _look_at_chest() -> void:
	var aim: Vector3 = _chest.position + Vector3.UP * Chests.AIM_HEIGHT - _player.eye_position()
	_player.input.look_yaw = atan2(-aim.x, -aim.z)
	_player.input.look_pitch = asin(clampf(aim.normalized().y, -1.0, 1.0))


func _sorted_chests() -> Array:
	var list: Array = Chests.chests.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _player.position.distance_to(a.position) < _player.position.distance_to(b.position))
	return list


func _nearest_chest() -> Dictionary:
	return _sorted_chests()[0]


func _second_nearest() -> Dictionary:
	return _sorted_chests()[1]


func _farthest_chest() -> Dictionary:
	return _sorted_chests()[-1]


func _check_loot_table() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var counts := [0, 0, 0]
	for i in 10000:
		counts[Chests.LOOT_TABLE.roll(rng).tier] += 1
	print("[test] losowanie: %s" % [counts])
	_check("zwykle okolo 70%", absi(counts[Rarity.Tier.COMMON] - 7000) < 300)
	_check("epickie okolo 25%", absi(counts[Rarity.Tier.EPIC] - 2500) < 300)
	_check("legendarne okolo 5%", absi(counts[Rarity.Tier.LEGENDARY] - 500) < 150)
	_check("wypada istniejacy przedmiot", ItemRegistry.get_definition(Chests.LOOT_TABLE.roll(rng).item) != null)


## Kazda skrzynka ma stac na podlodze, nie w scianie i nie na punkcie odrodzenia.
func _check_map_spots() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var world := (get_node("/root/Main") as Node3D).get_world_3d()
	var space := world.direct_space_state
	var spawns := get_tree().get_nodes_in_group(&"spawn_points")
	for spot in get_tree().get_nodes_in_group(&"chest_spots"):
		var marker := spot as Marker3D
		var at := marker.global_position
		var above := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.3, Hitscan.WORLD_MASK)
		var surface := space.intersect_ray(above)
		_check("%s stoi na podlodze" % marker.name, not surface.is_empty() and absf(surface.position.y - at.y) < 0.02)
		var box := BoxShape3D.new()
		box.size = ChestField.BODY_SIZE * Vector3(1.4, 0.8, 1.4)
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = box
		shape.collision_mask = Hitscan.WORLD_MASK
		shape.transform = Transform3D(marker.global_basis, at + Vector3.UP * (ChestField.BODY_SIZE.y * 0.5 + 0.15))
		var bodies := space.intersect_shape(shape, 8)
		var solid := bodies.filter(func(hit: Dictionary) -> bool: return not (hit.collider is StaticBody3D and hit.collider.get_parent() is ChestField))
		_check("%s nie wchodzi w obiekty" % marker.name, solid.is_empty())
		if not solid.is_empty():
			print("[test] koliduje z ", solid.map(func(hit: Dictionary) -> String: return hit.collider.name))
		for point in spawns:
			_check("%s nie stoi na odrodzeniu" % marker.name, (point as Node3D).global_position.distance_to(at) > 3.0)


## Prawdziwe zdarzenie klawisza, bo otwieranie zaczyna sie od wcisniecia.
func _key(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = pressed
	Input.parse_input_event(event)


func _hold_key(seconds: float) -> void:
	_key(true)
	await _wait(seconds)
	_key(false)
	await _wait(0.1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
