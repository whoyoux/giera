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
	GameState.server_add_player(2, "Ziutek")
	GameState.server_add_player(3, "Basia")
	GameState.server_add_player(4, "Mietek")
	await _wait(0.3)
	_add_bot(2, me.position + forward * 6.5 - right * 0.4, right)
	_add_bot(3, me.position + forward * 10.0 - right * 2.4, -right)
	_add_bot(4, me.position + forward * 13.0 + right * 2.0, right)
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
	me.view_model.kick()
	me.equipment.fired.emit()
	await _wait(0.03)
	await _shot("gameplay.png")

	await _wait(0.6)
	Input.action_press("scoreboard")
	await _wait(0.25)
	await _shot("scoreboard.png")
	Input.action_release("scoreboard")

	GameState.players[1].health = 25
	GameState.damaged.emit(40, 3)
	await _wait(0.1)
	await _shot("damage.png")
	get_tree().quit()


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
