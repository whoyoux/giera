extends Node
## Test kucania: kapsula, kamera, szybkosc, sufit, rozrzut, taniec i hitbox w cofaniu czasu.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://t.cfg --tool=res://tools/crouch_test.gd

const PORT := 8135
const TEST_SPOT := Vector3(15.0, 0.0, 1.0)

var _failures := 0
var _player: Player


func _ready() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_player = get_node("/root/Main/Players/1") as Player
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _move_to(TEST_SPOT)

	var standing_eye := _player.eye_position().y - _player.position.y
	_check("domyslny klawisz to Ctrl", Keybinds.label_of("crouch") == "Ctrl")
	var standing_height: float = (_player.get_node("Standing") as CollisionShape3D).shape.height
	Input.action_press("crouch")
	await _wait(0.1)
	_check("kapsula maleje od razu", _player.crouching and not (_player.get_node("Crouched") as CollisionShape3D).disabled and (_player.get_node("Standing") as CollisionShape3D).disabled)
	_check("kamera opada plynnie", _player.crouch_amount > 0.0 and _player.crouch_amount < 1.0)
	await _wait(0.5)
	var crouched_eye := _player.eye_position().y - _player.position.y
	_check("oczy sa nizej", crouched_eye < standing_eye - 0.4)
	_check("kamera dochodzi do oczu", absf(_player.head.position.y - crouched_eye) < 0.02)
	_check("kapsula niska", (_player.get_node("Crouched") as CollisionShape3D).shape.height < standing_height - 0.4)

	# Wolniejszy ruch i brak sprintu.
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(0.6)
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	print("[test] szybkosc w kucki: %.2f" % speed)
	_check("wolniejszy ruch", speed > 0.1 and speed < Player.SPEED * 0.6)
	_check("brak sprintu", not _player.sprinting)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _wait(0.4)

	# Mniejszy rozrzut niz na stojaco.
	var crouched_spread := _player.equipment.current_spread()
	Input.action_release("crouch")
	await _wait(0.6)
	var standing_spread := _player.equipment.current_spread()
	print("[test] rozrzut: stojac %.2f, kucajac %.2f" % [standing_spread, crouched_spread])
	_check("mniejszy rozrzut", crouched_spread < standing_spread)
	_check("wstaje po puszczeniu", not _player.crouching and _player.crouch_amount == 0.0)

	# Niskie przejscie: wejdzie tylko kucajac i nie wstanie pod sufitem.
	await _move_to(TEST_SPOT)
	var ceiling := _add_low_ceiling(TEST_SPOT + Vector3(0.0, 0.0, -3.5))
	await _wait(0.2)
	_player.input.look_yaw = 0.0
	Input.action_press("move_forward")
	await _wait(1.0)
	print("[test] przed sufitem z=%.2f y=%.2f sufit y=%.2f" % [_player.position.z - TEST_SPOT.z, _player.position.y, ceiling.position.y - 0.5])
	_check("na stojaco nie wejdzie pod sufit", _player.position.z > TEST_SPOT.z - 2.3)
	Input.action_press("crouch")
	var walked := 0.0
	while _player.position.z > TEST_SPOT.z - 3.4 and walked < 3.0:
		await get_tree().physics_frame
		walked += get_physics_process_delta_time()
	_check("w kucki wchodzi", _player.position.z <= TEST_SPOT.z - 3.4)
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await _wait(0.5)
	print("[test] pod sufitem z=%.2f kuca=%s" % [_player.position.z - TEST_SPOT.z, _player.crouching])
	_check("nie wstaje pod sufitem", _player.crouching and _player.position.z > TEST_SPOT.z - 4.5)
	Input.action_press("move_forward")
	await _wait(2.5)
	Input.action_release("move_forward")
	await _wait(0.5)
	_check("wstaje po wyjsciu spod sufitu", not _player.crouching)
	ceiling.queue_free()
	await _wait(0.2)

	# Kucanie przerywa taniec.
	await _move_to(TEST_SPOT)
	_check("taniec rusza", _player.input.request_dance(1))
	await _wait(0.3)
	_check("gracz tanczy", _player.dance_id != DanceCatalog.NONE)
	Input.action_press("crouch")
	await _wait(0.3)
	_check("kucanie przerywa taniec", _player.dance_id == DanceCatalog.NONE)
	Input.action_release("crouch")
	await _wait(0.5)

	_test_hitbox()
	await _test_pose()
	get_tree().quit(1 if _failures > 0 else 0)


## Hitbox zalezy od kucania w danym ticku, a nie od stanu biezacego.
func _test_hitbox() -> void:
	GameState.server_add_player(77, "Cel")
	var target := GameState.player_node(77)
	var world := target.get_world_3d()
	var eye := Vector3(22.0, 1.6, 1.0)
	target.position = Vector3(15.0, 0.0, 1.0)
	var over_head := target.position + Vector3.UP * Hitscan.HEAD_CENTER
	var chest := target.position + Vector3.UP * 0.35
	var trace := func(point: Vector3, tick := -1) -> Dictionary:
		return Hitscan.trace(world, eye, eye.direction_to(point), 1, get_tree(), tick)
	target.crouch_amount = 0.0
	_check("stojacy dostaje w glowe", trace.call(over_head).player == target)
	target.crouch_amount = 1.0
	_check("strzal nad kucajacym pudluje", trace.call(over_head).player == null)
	_check("kucajacy dostaje nizej", trace.call(chest).player == target)
	# Cofanie: serwer pamieta, ze w ticku 500 cel kucal, a w 510 juz stoi. I odwrotnie.
	target._remember_motion(500, target.position, 1.0)
	target._remember_motion(510, target.position, 0.0)
	target.crouch_amount = 0.0
	_check("cofanie: kucal, wiec pudlo", trace.call(over_head, 500).player == null)
	target.crouch_amount = 1.0
	_check("cofanie: stal, wiec trafienie", trace.call(over_head, 510).player == target)
	GameState._on_peer_disconnected(77)


## Poza kucania naprawde obniza glowe i zostawia stopy na ziemi.
func _test_pose() -> void:
	var rig := CharacterRig.new()
	add_child(rig)
	rig.setup("knight")
	await _wait(0.2)
	var skeleton := CharacterAssets.skeleton_of(rig.get_child(0) as Node3D)
	var head := skeleton.find_bone("head")
	var foot := skeleton.find_bone("foot.l")
	# Poza z modyfikatorow istnieje tylko w chwili aktualizacji szkieletu.
	var seen := {}
	skeleton.skeleton_updated.connect(func() -> void:
		seen.head = (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin
		seen.foot = (skeleton.global_transform * skeleton.get_bone_global_pose(foot)).origin)
	await _wait(0.2)
	var head_up: Vector3 = seen.head
	var foot_up: Vector3 = seen.foot
	rig.set_crouch(1.0)
	await _wait(0.2)
	var head_down: Vector3 = seen.head
	var foot_down: Vector3 = seen.foot
	print("[test] glowa %.2f -> %.2f, stopa %.2f -> %.2f" % [head_up.y, head_down.y, foot_up.y, foot_down.y])
	_check("glowa modelu opada", head_down.y < head_up.y - 0.3)
	_check("stopa zostaje na ziemi", absf(foot_down.y - foot_up.y) < 0.08)
	rig.queue_free()


func _move_to(at: Vector3) -> void:
	at.y = ForestTerrain.surface(at.x, at.z) + 0.1
	_player.teleport(at)
	_player.input.look_yaw = 0.0
	await _wait(0.5)


## Sufit na wysokosci 1,3 m z belka nad wejsciem. Bez niskiej kapsuly nie da sie przejsc.
func _add_low_ceiling(center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 1.0, 2.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = center + Vector3.UP * (ForestTerrain.surface(center.x, center.z) + 1.3 + 0.5)
	add_child(body)
	return body


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
