extends Node
## Narzedzie: miniaturki map do glosowania, z tego samego widoku co kamera menu, bez interfejsu.
## Uzycie: --resolution 1280x720 -- --tool=res://tools/map_thumbnails.gd [--only=desert]
## Zapisuje assets/maps/<id>.png. Po zmianie wygladu mapy wystarczy puscic je jeszcze raz.

const SIZE := Vector2i(480, 270)
## Kat na orbicie kamery menu, z ktorego mapa wyglada najlepiej.
const ANGLES := { "forest": 0.6, "city": PI, "valley": 0.5, "desert": 0.75 }


func _ready() -> void:
	var main := get_node("/root/Main")
	main.get_node("Menu").visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	main.add_child(camera)
	camera.current = true
	for id: String in Maps.ids():
		if Net.args.has("only") and Net.args.only != id:
			continue
		Maps.select(id)
		await get_tree().create_timer(1.0).timeout
		var info := Maps.info()
		var orbit := info.menu_orbit
		var angle: float = ANGLES.get(id, 0.0)
		camera.position = Vector3(info.zone_center.x + sin(angle) * orbit.x, orbit.y, info.zone_center.y + cos(angle) * orbit.x)
		camera.look_at(Vector3(info.zone_center.x, orbit.z, info.zone_center.y))
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(info.thumbnail)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		print("[test] %s: %s" % [path, error_string(image.save_png(path))])
	get_tree().quit()
