extends Node
## Narzedzie: zrzuty broni w rece, w chwili strzalu, na ziemi i w Zbrojowni. Sluzy do oceny
## modelu i animacji odrzutu. Uzycie: -- --tool=res://tools/hand_shot.gd --item=deagle --dir=C:/folder

var _dir := ""


func _ready() -> void:
	_dir = Net.args.get("dir", OS.get_user_data_dir())
	var item := StringName(Net.args.get("item", "deagle"))
	var main := get_node("/root/Main")
	Net.player_name = "Kapitan"
	Net.start_server(8047, false, GameMode.Id.DEATHMATCH)
	await _wait(1.0)
	var me := GameState.player_node(1)
	var slot := GameState.server_give_item(1, item, Rarity.Tier.EPIC)
	await _wait(0.3)
	me.input.select_slot(slot)
	await _wait(1.2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("%s_reka.png" % item)
	var steps: Array[float] = [0.016, 0.05, 0.12, 0.3]
	me.equipment.fired.emit()
	var elapsed := 0.0
	for step in steps:
		await _wait(step - elapsed)
		elapsed = step
		await _shot("%s_strzal_%03d.png" % [item, int(step * 1000.0)])
	await _wait(0.6)
	# Na ziemi przed graczem.
	var forward := me.look_direction()
	var spot := me.position + Vector3(forward.x, 0.0, forward.z).normalized() * 2.2
	spot.y = Maps.info().surface(spot.x, spot.z)
	WorldItems._server_spawn(ItemStack.create(9000, item, Rarity.Tier.LEGENDARY), spot, spot)
	me.input.look_pitch = -0.45
	await _wait(1.2)
	await _shot("%s_ziemia.png" % item)
	var panel: ArsenalPanel = null
	for child in main.get_children():
		if child is ArsenalPanel:
			panel = child
	if panel != null:
		panel.open()
		panel._select(ItemRegistry.get_definition(item))
		await _wait(0.8)
		await _shot("%s_zbrojownia.png" % item)
	get_tree().quit()


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _dir.path_join(file_name)
	print("[zrzut] %s %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
