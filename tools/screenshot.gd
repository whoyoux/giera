extends Node
## Narzedzie testowe: zapisuje zrzut ekranu i zamyka gre.
## Uzycie: -- --tool=res://tools/screenshot.gd --shot=C:/plik.png --shot-after=6
## Z --shot-model kamera ustawia sie przed innym graczem, zeby obejrzec jego model.


func _ready() -> void:
	if Net.args.has("shot-on-damage"):
		await GameState.damaged
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Net.args.get("shot", "user://screenshot.png"))
		print("[test] zrzut przy obrywaniu")
		get_tree().quit()
		return
	await get_tree().create_timer(float(Net.args.get("shot-after", 5.0))).timeout
	if Net.args.has("shot-model"):
		_aim_at_remote_player()
	if Net.args.has("shot-hurt"):
		_fake_damage()
		await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://screenshot.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[test] zrzut %s: %s" % [path, error_string(error)])
	get_tree().quit()


func _aim_at_remote_player() -> void:
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if player.is_local():
			continue
		var camera := get_viewport().get_camera_3d()
		var view := Camera3D.new()
		player.get_parent().add_child(view)
		var front := Hitscan.direction(player.yaw + 0.7, 0.0) * 2.6
		view.global_position = player.position + front + Vector3.UP * 1.3
		view.look_at(player.position + Vector3.UP * 1.0)
		view.current = true
		camera.current = false
		for hud in get_tree().get_nodes_in_group(&"hud"):
			hud.visible = false
		return


## Pokazuje efekty trafienia bez czekania, az bot znajdzie czysta linie strzalu.
func _fake_damage() -> void:
	var me := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if not player.is_local():
			GameState.players[me].health = int(Net.args.get("shot-health", 80))
			GameState.damaged.emit(40, player.peer_id)
			return
