extends Node
## Narzedzie: renderuje ikony tancow do kola wyboru, z postacia w charakterystycznej pozie.
## Uzycie: godot --path . -- --tool=res://tools/render_dance_icons.gd
## Po uruchomieniu trzeba zaimportowac nowe pliki: godot --headless --path . --import

const ICON_SIZE := 192
const CHARACTER_ID := "knight"
## W ktorym uderzeniu tanca stoi poza pokazana na ikonie.
const ICON_BEATS := { "bujanka": 1.0, "robot": 6.9, "wiatrak": 1.0, "podskoki": 1.0, "skretas": 0.25, "piruet": 1.2 }


func _ready() -> void:
	get_node("/root/Main/Menu").visible = false
	for dance: Dictionary in DanceCatalog.DANCES:
		await _render(dance)
	get_tree().quit()


func _render(dance: Dictionary) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(ICON_SIZE, ICON_SIZE)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_8X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	view.add_child(sun)
	var character := CharacterAssets.character_for(CHARACTER_ID)
	CharacterAssets.prepare_hands(character)
	character.rotation_degrees.y = 14.0
	view.add_child(character)
	var player := CharacterAssets.player_of(character)
	player.add_animation_library(DanceClips.LIBRARY, DanceClips.library())
	player.play("%s/%s" % [DanceClips.LIBRARY, dance.key])
	player.seek(float(ICON_BEATS[dance.key]) * 60.0 / dance.bpm, true)
	player.pause()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.position = Vector3(0.0, 1.05, 6.0)
	view.add_child(camera)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "res://assets/icons/dance_%s.png" % dance.key
	print("[test] %s: %s" % [path, error_string(view.get_texture().get_image().save_png(path))])
	view.queue_free()
