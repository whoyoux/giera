extends Node
## Narzedzie: postacie obu druzyn Team Deathmatchu z bliska albo z daleka, zeby sprawdzic,
## czy druzyne widac od razu. Uzycie: -- --tool=res://tools/team_preview.gd --shot=C:/plik.png [--distance=30]


func _ready() -> void:
	var main := get_node("/root/Main") as Node3D
	main.get_node("Menu").visible = false
	var rigs: Array[CharacterRig] = []
	var base := Vector3(17.0, 0.0, 0.5)
	for i in 4:
		var rig := CharacterRig.new()
		main.add_child(rig)
		rig.setup(CharacterAssets.ROSTER[i % CharacterAssets.ROSTER.size()].id)
		rig.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, 0))
		rig.set_team(i % 2, Teams.color_of(i % 2))
		var at := base + Vector3(i * 1.4, 0.0, 0.0)
		at.y = ForestTerrain.surface(at.x, at.z)
		rig.position = at
		rig.rotation.y = PI + (0.35 if i % 2 == 0 else -0.35)
		rigs.append(rig)
	var distance := float(Net.args.get("distance", 4.5))
	var middle := base + Vector3(2.1, 0.0, 0.0)
	middle.y = ForestTerrain.surface(middle.x, middle.z)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.fov = 70.0
	camera.position = middle + Vector3(0.0, 1.4, distance)
	camera.look_at(middle + Vector3(0.0, 0.9, 0.0))
	camera.current = true
	for frame in 40:
		for rig in rigs:
			rig.update_pose(1.0 / 60.0, Vector2.ZERO, true, 0.0, false, false)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://team.png")
	print("[test] zrzut %s: %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
	get_tree().quit()
