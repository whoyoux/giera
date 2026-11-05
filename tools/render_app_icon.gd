extends Node
## Narzedzie: rysuje ikone aplikacji do assets/app_icon.png i assets/app_icon.ico.
## Uzycie: godot --path . -- --tool=res://tools/render_app_icon.gd
## Pomysl: skrzynka z lupem na naklejce w kolorach lasu, czyli to, po co gra sie w te gre.

const SIZE := 1024
const ICO_SIZES: Array[int] = [16, 32, 48, 64, 128, 256]
const TILE := Color("2f9e5b")
const TILE_DARK := Color("1f7a44")
const GLOW := Color("ffd24d")
const RAY_CENTER := Vector2(0.0, 40.0)
const RAY_COUNT := 9.0


func _ready() -> void:
	(get_node("/root/Main/Menu") as CanvasLayer).visible = false
	var picture := await _render_scene()
	picture.save_png("res://assets/app_icon.png")
	_save_ico(picture, "res://assets/app_icon.ico")
	print("[test] ikona gotowa")
	get_tree().quit()


func _render_scene() -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	var chest := ChestView.new()
	viewport.add_child(chest)
	await get_tree().process_frame
	chest.set_process(false)
	# Wieko uchylone, a ze srodka bije blask: widac, ze w srodku cos jest.
	chest._lid.rotation.x = -1.45
	chest._glow_material.albedo_color = GLOW
	chest._sparkles.emitting = false
	chest._sparkles.visible = false
	var blaster := (load(ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.LEGENDARY).visual.model_path) as PackedScene).instantiate() as Node3D
	blaster.position = Vector3(0.28, 0.98, 0.42)
	# Bron bokiem do kamery, skierowana lufa w gore i w lewo.
	blaster.basis = Basis(Vector3.BACK, deg_to_rad(-42.0)) * Basis(Vector3.UP, deg_to_rad(90.0)) * Basis.from_scale(Vector3.ONE * 2.1)
	viewport.add_child(blaster)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.75
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.75, 1.6, 3.7), Vector3(0.0, 0.98, 0.0))
	for i in 4:
		await RenderingServer.frame_post_draw
	var scene := viewport.get_texture().get_image()
	scene.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	return _compose(scene)


## Zaokraglona naklejka: biala ramka i dwa odcienie zieleni, jak znaczki w menu.
func _compose(scene: Image) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var margin := 28.0
	var radius := 210.0
	var border := 46.0
	var half := SIZE * 0.5 - margin
	for y in SIZE:
		for x in SIZE:
			var point := Vector2(x + 0.5 - SIZE * 0.5, y + 0.5 - SIZE * 0.5)
			var edge := _rounded_box(point, Vector2(half, half), radius)
			if edge > 1.0:
				continue
			var color := Color.WHITE
			if edge < -border:
				# Promienie rozchodza sie od skrzynki.
				var ray := sin((point - RAY_CENTER).angle() * RAY_COUNT)
				color = TILE if ray > 0.0 else TILE_DARK
				var overlay := scene.get_pixel(x, y)
				color = color.lerp(overlay, overlay.a)
			color.a = clampf(1.0 - edge, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return image


func _rounded_box(point: Vector2, half: Vector2, radius: float) -> float:
	var q := point.abs() - half + Vector2.ONE * radius
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


## Plik ICO to naglowek i obrazki PNG w kolejnych rozmiarach.
func _save_ico(picture: Image, path: String) -> void:
	var entries := PackedByteArray()
	var payload := PackedByteArray()
	var offset := 6 + 16 * ICO_SIZES.size()
	for size in ICO_SIZES:
		var scaled := picture.duplicate() as Image
		scaled.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var png := scaled.save_png_to_buffer()
		var entry := PackedByteArray()
		entry.resize(16)
		entry.encode_u8(0, size % 256)
		entry.encode_u8(1, size % 256)
		entry.encode_u16(4, 1)
		entry.encode_u16(6, 32)
		entry.encode_u32(8, png.size())
		entry.encode_u32(12, offset)
		entries.append_array(entry)
		payload.append_array(png)
		offset += png.size()
	var header := PackedByteArray()
	header.resize(6)
	header.encode_u16(2, 1)
	header.encode_u16(4, ICO_SIZES.size())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(header + entries + payload)
	file.close()
