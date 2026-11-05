extends Node
## Narzedzie: robi zrzuty do README z przykladowymi nazwami i adresem.
## Uzycie: -- --tool=res://tools/readme_shots.gd --dir=C:/folder
## Nie zapisuje ustawien gracza, wiec nie zmienia nicku ani adresu w menu.

const EXAMPLE_NICK := "Kapitan"
const EXAMPLE_ADDRESS := "203.0.113.10"

var _dir := ""
var _time := 0.0
var _bots: Array[Dictionary] = []


func _ready() -> void:
	_dir = Net.args.get("dir", "user://")
	var main := get_node("/root/Main")
	var menu := main.get_node("Menu") as Menu
	menu._name_field.text = EXAMPLE_NICK
	menu._address_field.text = EXAMPLE_ADDRESS
	menu._status.text = ""
	await _wait(1.5)
	await _shot("menu.png")

	Net.player_name = EXAMPLE_NICK
	Net.start_server(int(Net.args.get("port", 8040)))
	await _wait(1.0)
	var me := _local_player()
	var center := -me.position
	center.y = 0.0
	var forward := center.normalized()
	var right := forward.cross(Vector3.UP)
	GameState.server_give_item(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.EPIC)
	GameState.server_give_item(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.LEGENDARY)
	me.input.select_slot(2)
	GameState.server_add_player(2, "Ziutek")
	GameState.server_add_player(3, "Basia")
	GameState.server_add_player(4, "Mietek")
	await _wait(0.3)
	_add_bot(2, me.position + forward * 6.5 - right * 0.4, right)
	_add_bot(3, me.position + forward * 10.0 - right * 2.4, -right)
	_add_bot(4, me.position + forward * 13.0 + right * 2.0, right)
	# Bez przechwyconej myszy ruch uzytkownika nie zmieni kadru.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	me.input.look_yaw = atan2(-forward.x, -forward.z)
	me.input.look_pitch = -0.03
	GameState.players[1].kills = 7
	GameState.players[1].deaths = 2
	GameState.players[2].kills = 4
	GameState.players[2].deaths = 5
	GameState.players[3].kills = 6
	GameState.players[3].deaths = 3
	GameState.players[4].deaths = 1
	GameState.player_changed.emit(1)
	GameState.set_process(false)
	GameState.pings = { 1: 0, 2: 34, 3: 87, 4: 142 }
	GameState.pings_updated.emit()
	GameState.kill_announced.emit(1, 2)
	GameState.kill_announced.emit(3, 4)
	await _wait(1.6)
	me.equipment.fired.emit()
	await _wait(0.03)
	await _shot("gameplay.png")

	await _wait(0.6)
	Input.action_press("scoreboard")
	await _wait(0.25)
	await _shot("scoreboard.png")
	Input.action_release("scoreboard")

	await _loot_shot(me, forward, right)

	GameState.players[1].health = 25
	GameState.damaged.emit(40, 3)
	await _wait(0.1)
	await _shot("damage.png")
	GameState.players[1].health = GameState.MAX_HEALTH
	await _wait(1.0)
	await _chest_shots(me, forward)
	get_tree().quit()


## Trzy klasy na ziemi i podpowiedz przy tej, na ktora patrzy gracz.
func _loot_shot(me: Player, forward: Vector3, right: Vector3) -> void:
	var feet := me.position
	var spots := [feet + forward * 2.2, feet + forward * 3.6 - right * 1.6, feet + forward * 4.4 + right * 1.5]
	var tiers := [Rarity.Tier.LEGENDARY, Rarity.Tier.EPIC, Rarity.Tier.COMMON]
	for i in spots.size():
		WorldItems._server_spawn(ItemStack.create(9000 + i, ItemRegistry.DEFAULT_WEAPON, tiers[i]), spots[i], spots[i])
	me.input.look_pitch = -0.28
	await _wait(1.0)
	await _shot("loot.png")
	for id: int in WorldItems.items.keys():
		WorldItems._remove_item.rpc(id, 0)
	me.input.look_pitch = -0.03
	await _wait(0.2)


## Skrzynka w trakcie otwierania i zaraz po wypadnieciu legendarnej broni.
func _chest_shots(me: Player, forward: Vector3) -> void:
	var field := get_node("/root/Main").find_children("*", "ChestField", false, false)[0] as ChestField
	var id := 900
	var spot := me.position + forward * 2.4
	spot.y = 0.0
	field._add_chest(id, spot, atan2(forward.x, forward.z) + PI + 0.5)
	me.input.look_pitch = -0.42
	GameState.kill_announced.emit(1, 3)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.3)
	Chests.arm()
	Input.action_press("interact")
	await _wait(0.6)
	await _shot("chest.png")
	Input.action_release("interact")
	await _wait(0.1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Chests._chest_opened.rpc(id, 1, Rarity.Tier.LEGENDARY)
	var from := spot + Vector3.UP * Chests.LOOT_START_HEIGHT
	WorldItems._server_spawn(ItemStack.create(9100, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.LEGENDARY), from, me.position + forward * 1.1)
	await _wait(0.28)
	await _shot("chest_open.png")


func _process(delta: float) -> void:
	_time += delta
	for bot in _bots:
		var player: Player = bot.player
		player.position = bot.home + bot.axis * sin(_time * 0.9 + bot.phase) * 1.6
		player.yaw = atan2(-bot.axis.x, -bot.axis.z)
		if cos(_time * 0.9 + bot.phase) < 0.0:
			player.yaw += PI
		player.velocity = Vector3.ZERO


func _add_bot(id: int, home: Vector3, axis: Vector3) -> void:
	var node := get_node("/root/Main/Players").get_node(str(id)) as Player
	node.interpolator.enabled = false
	_bots.append({ "player": node, "home": home, "axis": axis, "phase": float(id) })


func _local_player() -> Player:
	return get_node("/root/Main/Players").get_node("1") as Player


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_dir.path_join(file_name))
	print("[test] %s: %s" % [file_name, error_string(error)])
