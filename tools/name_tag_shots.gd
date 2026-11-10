extends Node
## Zrzuty plakietki z nickiem z kilku odleglosci: drugi gracz stoi przed kamera hosta.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://name_tag_shots.cfg --map=desert
##         --tool=res://tools/name_tag_shots.gd --dir=C:/folder

const PORT := 8173
const DISTANCES: Array[float] = [1.2, 2.5, 5.0, 10.0, 20.0]
const TARGET_NAME := "Basia Z Długim Nickiem"


func _ready() -> void:
	Net.start_server(PORT, false, GameMode.Id.DEATHMATCH)
	await _wait(1.5)
	GameState.server_add_player(2, TARGET_NAME)
	await _wait(1.0)
	var target := GameState.player_node(2)
	# Postacie ustawia rollback netfox, wiec ruszamy wlasna kamera, a nie graczem. Plakietka bierze
	# kamere z viewportu, tak jak u widza.
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var dir: String = Net.args.get("dir", "")
	for distance in DISTANCES:
		var head := target.global_position + Vector3.UP * Player.EYE_HEIGHT
		camera.global_position = head + Vector3(0.0, 0.0, distance)
		camera.look_at(head + Vector3.UP * 0.3)
		await _wait(0.4)
		var tag_size := target.name_label.scale.x
		print("[plakietka] odleglosc %.1f m: skala %.2f, widocznosc %.2f" % [distance, tag_size, target.name_label.modulate.a])
		if not dir.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("name_tag_%04.1fm.png" % distance))
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
