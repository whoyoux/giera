extends Node
## Narzedzie: zrzut modelu broni z boku i z trzech czwartych na jasnym tle, np. do porownania
## przed i po. Uzycie: -- --tool=res://tools/weapon_preview.gd --item=deagle --shot=C:/plik.png


func _ready() -> void:
	var main := get_node("/root/Main") as Node3D
	main.get_node("Menu").visible = false
	var definition := ItemRegistry.get_definition(StringName(Net.args.get("item", "deagle")))
	var visual := ItemStack.visual_of(ItemStack.create(1, definition.id, 0))
	var stage := Node3D.new()
	main.add_child(stage)
	stage.position = Vector3(0.0, 200.0, 0.0)
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	backdrop.mesh = plane
	backdrop.material_override = LowPoly.material(Color("f3ecdd"), 0.9)
	backdrop.position = Vector3(0.0, 0.0, -1.2)
	backdrop.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	stage.add_child(backdrop)
	for index in 2:
		var model := (load(visual.model_path) as PackedScene).instantiate() as Node3D
		stage.add_child(model)
		model.scale = Vector3.ONE * 2.2
		model.position = Vector3(-0.55 + index * 1.1, 0.0, 0.0)
		model.rotation_degrees = Vector3(0.0, 90.0, 0.0) if index == 0 else Vector3(-12.0, 145.0, 0.0)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.0, 0.25, 2.3)
	camera.fov = 45.0
	camera.look_at(stage.global_position + Vector3(0.0, 0.1, 0.0))
	camera.current = true
	for frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://weapon.png")
	print("[zrzut] %s" % error_string(get_viewport().get_texture().get_image().save_png(path)))
	get_tree().quit()
