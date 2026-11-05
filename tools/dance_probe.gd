extends Node
## Narzedzie do testow sieci: wypisuje kazda zmiane tanca widziana na tym komputerze.
## Z --dance-shot=C:/plik.png robi zrzut cudzego tanca i zamyka gre.
## Uzycie: -- --tool=res://tools/dance_probe.gd

const SHOT_AFTER_SECONDS := 1.4

var _seen := {}
var _shot_timer := 0.0
var _shot_taken := false


func _process(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if _seen.get(player.peer_id, 0) != player.dance_id:
			_seen[player.peer_id] = player.dance_id
			print("[dance] %s %d" % [player.info.name, player.dance_id])
		if Net.args.has("dance-shot") and not _shot_taken and not player.is_local() and player.dance_id != DanceCatalog.NONE:
			_shot_timer += delta
			if _shot_timer >= SHOT_AFTER_SECONDS:
				_shot_taken = true
				_shoot(player)


func _shoot(player: Player) -> void:
	var view := Camera3D.new()
	player.get_parent().add_child(view)
	view.global_position = player.position + Hitscan.direction(player.yaw + 0.5, 0.0) * 3.0 + Vector3.UP * 1.3
	view.look_at(player.position + Vector3.UP * 0.9)
	view.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("[test] zrzut tanca %d: %s" % [player.dance_id, error_string(get_viewport().get_texture().get_image().save_png(Net.args["dance-shot"]))])
	get_tree().quit()
