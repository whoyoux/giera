extends Node
## Narzedzie testowe: mierzy czas klatki przy kazdym poziomie grafiki i robi zrzuty do porownania.
## Licznik GPU pokazuje koszt swiata i broni, a "klatka" czas calej klatki bez synchronizacji.
## Uzycie: --resolution 2560x1440 -- --connect=127.0.0.1 --port=7990 --settings-path=user://perf.cfg
##         --tool=res://tools/perf_probe.gd --shots=C:/folder

const SETTLE_FRAMES := 40
const SAMPLE_FRAMES := 120
const VIEWS: Array[Array] = [
	[Vector3(0.0, 1.7, 30.0), Vector3(0.0, 1.5, 70.0)],
	[Vector3(-14.0, 1.7, -3.0), Vector3(20.0, 1.5, 5.0)],
]
## Widoki dla duzej doliny: przez las w strone ruin i z obozu na pol mapy.
const VALLEY_VIEWS: Array[Array] = [
	[Vector3(60.0, 3.0, 20.0), Vector3(-12.0, 2.0, -18.0)],
	[Vector3(10.0, 14.0, 132.0), Vector3(-12.0, 2.0, -18.0)],
]
## Widoki dla pustyni: z targu na twierdze i z wiezy twierdzy na cala mape.
const DESERT_VIEWS: Array[Array] = [
	[Vector3(-14.0, 1.7, 16.0), Vector3(0.0, 2.0, 52.0)],
	[Vector3(-21.0, 6.8, 46.0), Vector3(0.0, 1.0, -40.0)],
]
## Widoki dla miasta: wzdluz glownej ulicy i z dachu na plac.
const CITY_VIEWS: Array[Array] = [
	[Vector3(0.0, 1.7, 30.0), Vector3(0.0, 1.5, -30.0)],
	[Vector3(-20.0, 8.0, -20.0), Vector3(10.0, 0.0, 10.0)],
]
## Skala -1 oznacza automatyczna rozdzielczosc 3D, jak domyslnie na macOS.
const PRESETS: Array[Array] = [
	["wysoka 100", Settings.Graphics.HIGH, 1.0],
	["srednia 100", Settings.Graphics.MEDIUM, 1.0],
	["srednia 75", Settings.Graphics.MEDIUM, 0.75],
	["niska 75", Settings.Graphics.LOW, 0.75],
	["niska 50", Settings.Graphics.LOW, 0.5],
	["srednia auto", Settings.Graphics.MEDIUM, -1.0],
	["niska auto", Settings.Graphics.LOW, -1.0],
]

var _overlay: SubViewport


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	while get_tree().get_nodes_in_group(&"players").is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	for node in get_node("/root/Main").find_children("*", "SubViewport", true, false):
		if not (node as SubViewport).own_world_3d:
			_overlay = node
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(_overlay.get_viewport_rid(), true)
	print("[perf] okno %s, GPU %s" % [get_window().size, RenderingServer.get_video_adapter_name()])
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 80.0
	camera.current = true
	var views: Array[Array] = {"valley": VALLEY_VIEWS, "desert": DESERT_VIEWS, "city": CITY_VIEWS}.get(Maps.current_id, VIEWS)
	for view_index in views.size():
		var from: Vector3 = views[view_index][0]
		if Maps.current_id == "valley":
			from.y += ValleyTerrain.surface(from.x, from.z)
		camera.global_position = from
		camera.look_at(views[view_index][1])
		for preset in PRESETS:
			Settings.set_value("graphics", float(preset[1]))
			Settings.set_value("render_auto", preset[2] < 0.0)
			if preset[2] > 0.0:
				Settings.set_value("render_scale", preset[2])
			await _measure(preset[0], view_index)
	get_tree().quit()


func _measure(label: String, view_index: int) -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var world := 0.0
	var overlay := 0.0
	var started := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		world += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		overlay += RenderingServer.viewport_get_measured_render_time_gpu(_overlay.get_viewport_rid())
	var frame_ms := float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE_FRAMES
	print("[perf] widok %d %-12s GPU swiat %5.2f ms, bron %4.2f ms | klatka %5.2f ms | 3D %d%%, %d wywolan" % [view_index, label, world / SAMPLE_FRAMES, overlay / SAMPLE_FRAMES, frame_ms,
		roundi(get_tree().root.scaling_3d_scale * 100.0), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if Net.args.has("shots"):
		get_viewport().get_texture().get_image().save_png("%s/v%d_%s.png" % [Net.args.shots, view_index, label.replace(" ", "_")])
