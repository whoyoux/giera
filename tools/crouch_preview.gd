extends Node
## Narzedzie: zrzut postaci stojacej i kucajacej z boku, zeby obejrzec poze kucania.
## Uzycie: -- --tool=res://tools/crouch_preview.gd --shot=C:/plik.png

const STATES: Array[Array] = [
	["stoi", 0.0, Vector2.ZERO],
	["kuca", 1.0, Vector2.ZERO],
	["idzie w kucki", 1.0, Vector2(0.0, 3.2)],
	["w polowie", 0.5, Vector2.ZERO],
]


func _ready() -> void:
	var main := get_node("/root/Main") as Node3D
	main.get_node("Menu").visible = false
	var rigs: Array[CharacterRig] = []
	var base := Vector3(17.0, 0.0, 0.5)
	for i in STATES.size():
		var rig := CharacterRig.new()
		main.add_child(rig)
		rig.setup(CharacterAssets.ROSTER[i].id)
		rig.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, 0))
		var at := base + Vector3(i * 1.6, 0.0, 0.0)
		at.y = ForestTerrain.surface(at.x, at.z)
		rig.position = at
		rig.rotation.y = PI * 0.5
		rigs.append(rig)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.position = base + Vector3(2.4, 1.0, 4.2)
	camera.position.y += ForestTerrain.surface(base.x, base.z)
	camera.look_at(base + Vector3(2.4, 0.7 + ForestTerrain.surface(base.x, base.z), 0.0))
	camera.current = true
	for frame in 40:
		for i in rigs.size():
			rigs[i].set_crouch(STATES[i][1])
			rigs[i].update_pose(1.0 / 60.0, STATES[i][2], true, 0.0, false, false)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://crouch.png")
	print("[test] zrzut %s: %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
	get_tree().quit()
