extends Node
## Narzedzie: zrzuty mapy z kilku miejsc, bez interfejsu, zeby ocenic wyglad i czytelnosc.
## Uzycie: --resolution 1280x720 -- --map=city --tool=res://tools/map_shots.gd --dir=C:/folder

const VIEWS := {
	"city": [
		["city_air", Vector3(32.0, 34.0, 40.0), Vector3(0.0, 0.0, 0.0)],
		["city_street", Vector3(0.0, 1.6, 33.0), Vector3(0.0, 1.4, -10.0)],
		["city_cross", Vector3(8.0, 1.6, 9.0), Vector3(-6.0, 1.2, -4.0)],
		["city_plaza", Vector3(8.0, 2.2, -11.0), Vector3(18.0, 0.8, -21.0)],
		["city_yard", Vector3(-6.0, 3.0, 34.0), Vector3(-18.0, 0.6, 18.0)],
		["city_crawl", Vector3(-19.0, 1.0, 27.5), Vector3(-19.0, 0.7, 20.0)],
		["city_tenement", Vector3(-19.0, 4.7, -22.0), Vector3(-15.0, 3.6, -29.0)],
		["city_roof", Vector3(-20.0, 8.0, -21.0), Vector3(8.0, 2.0, -6.0)],
		["city_hotel", Vector3(4.0, 2.0, 30.0), Vector3(18.0, 3.0, 20.0)],
		["city_garage", Vector3(18.0, 1.4, 11.0), Vector3(26.0, 1.0, 11.0)],
		["city_alley", Vector3(-31.0, 1.6, 33.0), Vector3(-30.0, 1.2, -10.0)],
	],
}


func _ready() -> void:
	var dir: String = Net.args.get("dir", "user://")
	var main := get_node("/root/Main")
	main.get_node("Menu").visible = false
	Maps.select(Net.args.get("map", "city"))
	await get_tree().create_timer(1.0).timeout
	var camera := Camera3D.new()
	camera.fov = 75.0
	main.add_child(camera)
	camera.current = true
	for view: Array in VIEWS.get(Maps.current_id, []):
		camera.global_position = view[1]
		camera.look_at(view[2])
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := dir.path_join("%s.png" % view[0])
		print("[test] %s: %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
	get_tree().quit()
