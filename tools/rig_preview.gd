extends Node
## Narzedzie testowe: zrzuty postaci w roznych stanach i broni w pierwszej osobie.
## Uzycie: -- --tool=res://tools/rig_preview.gd --dir=C:/folder

var _dir := ""


func _ready() -> void:
	_dir = Net.args.get("dir", "user://")
	var main := get_node("/root/Main")
	main.get_node("Menu").visible = false
	var world: Node3D = main
	await _rigs(world)
	await _first_person(world)
	get_tree().quit()


func _rigs(world: Node3D) -> void:
	var states := [
		{ "name": "idle", "move": Vector2.ZERO },
		{ "name": "bieg", "move": Vector2(0, 6.5) },
		{ "name": "sprint", "move": Vector2(0, 9.75), "sprint": true },
		{ "name": "bok", "move": Vector2(6.5, 0) },
		{ "name": "tyl", "move": Vector2(0, -6.5) },
		{ "name": "skok", "move": Vector2.ZERO, "air": true },
		{ "name": "smierc", "move": Vector2.ZERO, "dead": true },
	]
	var rigs: Array[CharacterRig] = []
	for i in states.size():
		var rig := CharacterRig.new()
		world.add_child(rig)
		rig.setup(i + 1)
		rig.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, i % 3))
		rig.position = Vector3((i - 3) * 2.0, 0.1, 25.0)
		rig.rotation.y = PI * 0.85
		rigs.append(rig)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.6, 30.5)
	camera.look_at(Vector3(0, 0.9, 25.0))
	camera.current = true
	for frame in 70:
		for i in states.size():
			var s: Dictionary = states[i]
			rigs[i].update_pose(1.0 / 60.0, s.move, not s.get("air", false), 0.0, s.get("sprint", false), s.get("dead", false))
		await get_tree().process_frame
	var holder := rigs[0].find_child("GunHolder", true, false) as Node3D
	var forward := rigs[0].global_basis.inverse() * (-holder.global_basis.z)
	print("[test] kierunek broni w ukladzie postaci: ", forward.normalized(), " kat Y: ", rad_to_deg(atan2(-forward.x, -forward.z)))
	print("[test] polozenie broni: ", rigs[0].to_local(holder.global_position))
	await _shot("rigs.png")
	rigs[0].play_shot()
	rigs[1].play_reload()
	rigs[3].play_hit()
	for frame in 18:
		for i in states.size():
			var s: Dictionary = states[i]
			rigs[i].update_pose(1.0 / 60.0, s.move, not s.get("air", false), 0.5 if i == 0 else 0.0, s.get("sprint", false), s.get("dead", false))
		await get_tree().process_frame
	await _shot("rigs2.png")
	for rig in rigs:
		rig.queue_free()
	camera.queue_free()
	await get_tree().process_frame


func _first_person(world: Node3D) -> void:
	var camera := Camera3D.new()
	camera.near = 0.03
	camera.fov = 80.0
	world.add_child(camera)
	camera.position = Vector3(0, 1.5, 22)
	camera.current = true
	var view := ViewModel.new()
	camera.add_child(view)
	view.setup(int(Net.args.get("fp-peer", 2)))
	view.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON))
	var pose := func(frames: int, speed: float, sprint: bool, reload: bool, dead := false) -> void:
		for frame in frames:
			view.update_pose(1.0 / 60.0, speed, true, 0.0, sprint, reload, dead)
			await get_tree().process_frame
	await pose.call(50, 0.0, false, false)
	print("[test] okno %s, bron renderowana w %s" % [get_window().size, view.overlay_size()])
	await _shot("fp_aim.png")
	for tier: int in [Rarity.Tier.COMMON, Rarity.Tier.EPIC, Rarity.Tier.LEGENDARY]:
		view.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, tier))
		await pose.call(40, 0.0, false, false)
		await _shot("fp_tier_%d.png" % tier)
		view.kick(ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, tier).recoil)
		await pose.call(2, 0.0, false, false)
		await _shot("fp_tier_%d_shot.png" % tier)
	# Bron przy samej scianie nie moze w nia wchodzic.
	var open_position := camera.position
	camera.position = Vector3(-16.0, 1.5, -31.3)
	await pose.call(4, 0.0, false, false)
	await _shot("fp_wall.png")
	camera.position = open_position
	view.kick()
	await pose.call(3, 0.0, false, false)
	await _shot("fp_shot.png")
	await pose.call(12, 0.0, false, false)
	await pose.call(24, 0.0, false, true)
	await _shot("fp_reload.png")
	await pose.call(26, 0.0, false, true)
	await _shot("fp_reload2.png")
	await pose.call(10, 0.0, false, false)
	await pose.call(40, 1.5, true, false)
	await _shot("fp_sprint.png")


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_dir.path_join(file_name))
	print("[test] %s: %s" % [file_name, error_string(error)])
