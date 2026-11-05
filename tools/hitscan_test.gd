extends Node
## Test logiki trafien na prawdziwej mapie.
## Uzycie: godot --headless --path . -- --tool=res://tools/hitscan_test.gd

var _failures := 0


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	GameState.server_add_player(2, "Strzelec")
	GameState.server_add_player(3, "Cel")
	await get_tree().physics_frame
	var players := get_node("/root/Main/Players")
	var target := players.get_node("3") as Player
	var world := target.get_world_3d()

	# Z kazdego punktu odrodzenia mozna wyjsc w strone srodka mapy.
	for node in get_tree().get_nodes_in_group(&"spawn_points"):
		var spawn := (node as Node3D).global_position
		var chest := spawn + Vector3.UP * 0.9
		var toward_center := (Vector3(0, chest.y, 0) - chest).normalized()
		var query := PhysicsRayQueryParameters3D.create(chest, chest + toward_center * 4.0, Hitscan.WORLD_MASK)
		_check("droga wolna z %s" % node.name, world.direct_space_state.intersect_ray(query).is_empty())

	# Otwarta sciezka na wschod od ruin.
	target.position = Vector3(15, 0, 1)
	var eye := Vector3(22, 1.6, 1)
	_expect("trafienie w tulow", _trace(world, eye, target.position + Vector3.UP * 0.9), target, false)
	_expect("trafienie w glowe", _trace(world, eye, target.position + Vector3.UP * Hitscan.HEAD_CENTER), target, true)
	var miss := Hitscan.trace(world, eye, Vector3.FORWARD.rotated(Vector3.UP, 0.3), 2, get_tree())
	_expect("pudlo obok celu", miss, null, false)

	# Wieza ruin zaslania cel.
	target.position = Vector3(-4.5, 0, -9)
	var blocked := _trace(world, Vector3(-4.5, 1.6, -1), target.position + Vector3.UP * 0.9)
	_expect("cel za wieza jest zasloniety", blocked, null, false)
	_check("pocisk zatrzymal sie na wiezy", blocked.hit_world)

	# Strzelec nie moze trafic sam siebie.
	var shooter := players.get_node("2") as Player
	shooter.position = Vector3(22, 0, 1)
	target.position = Vector3(15, 0, 1)
	_expect("wlasne cialo nie blokuje strzalu", _trace(world, shooter.eye_position(), target.position + Vector3.UP * 0.9), target, false)

	# Martwy gracz nie przyjmuje trafien.
	GameState.players[3].alive = false
	_expect("martwy cel jest pomijany", _trace(world, eye, target.position + Vector3.UP * 0.9), null, false)

	# Cios z bliska: zasieg, stozek i oslona.
	GameState.players[3].alive = true
	var melee_eye := Vector3(22, 1.6, 1)
	target.position = Vector3(20, 0, 1)
	var swing := Hitscan.melee(world, melee_eye, Vector3.LEFT, 2.6, 25.0, 2, get_tree())
	_check("cios siega celu", swing.player == target)
	swing = Hitscan.melee(world, melee_eye, Vector3.RIGHT, 2.6, 25.0, 2, get_tree())
	_check("cios nie trafia za plecy", swing.player == null)
	target.position = Vector3(15, 0, 1)
	swing = Hitscan.melee(world, melee_eye, Vector3.LEFT, 2.6, 25.0, 2, get_tree())
	_check("cios ma ograniczony zasieg", swing.player == null)
	target.position = Vector3(20, 0, 1)
	GameState.players[3].alive = false
	swing = Hitscan.melee(world, melee_eye, Vector3.LEFT, 2.6, 25.0, 2, get_tree())
	_check("martwy nie obrywa ciosem", swing.player == null)
	GameState.players[3].alive = true
	swing = Hitscan.melee(world, melee_eye, Vector3.LEFT, 2.6, 25.0, 3, get_tree())
	_check("sam siebie nie mozna ciac", swing.player != target)
	target.position = Vector3(-4.5, 0, -9)
	swing = Hitscan.melee(world, Vector3(-4.5, 1.6, -1), Vector3.FORWARD, 9.0, 25.0, 2, get_tree())
	_check("mur oslania przed ciosem", swing.player == null)

	# Sruciny: kazda sprawdzana osobno, a mur zatrzymuje wszystkie.
	target.position = Vector3(15, 0, 1)
	var pellets_on_target := 0
	for pellet in Hitscan.pellet_directions((target.position + Vector3.UP * 0.9 - eye).normalized(), 8, 5.5, 42):
		if Hitscan.trace(world, eye, pellet, 2, get_tree()).player == target:
			pellets_on_target += 1
	print("[test] sruciny na celu z 7 m: %d" % pellets_on_target)
	_check("z bliska trafia wiele srucin", pellets_on_target >= 3)
	target.position = Vector3(-4.5, 0, -9)
	pellets_on_target = 0
	for pellet in Hitscan.pellet_directions(Vector3.FORWARD, 8, 5.5, 42):
		if Hitscan.trace(world, Vector3(-4.5, 1.6, -1), pellet, 2, get_tree()).player == target:
			pellets_on_target += 1
	_check("mur zatrzymuje srut", pellets_on_target == 0)

	# Respawn: obrazenia, smierc i liczniki.
	GameState.players[3].alive = true
	GameState.players[3].health = GameState.MAX_HEALTH
	for i in 4:
		GameState.server_damage(3, ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON).damage, 2)
	_check("po 4 trafieniach gracz zyje", GameState.players[3].alive and GameState.players[3].health == 20)
	GameState.server_damage(3, ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON).damage, 2)
	_check("piate trafienie zabija", not GameState.players[3].alive)
	_check("zabojstwo jest policzone", GameState.players[2].kills == 1 and GameState.players[3].deaths == 1)
	_check("respawn jest zaplanowany", GameState.players[3].respawn_id == 1)
	GameState.server_damage(3, ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON).damage, 2)
	_check("trafienie w martwego nic nie zmienia", GameState.players[2].kills == 1)

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _trace(world: World3D, from: Vector3, to: Vector3) -> Dictionary:
	return Hitscan.trace(world, from, (to - from).normalized(), 2, get_tree())


func _expect(label: String, hit: Dictionary, player: Player, headshot: bool) -> void:
	_check(label, hit.player == player and hit.headshot == headshot)


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
