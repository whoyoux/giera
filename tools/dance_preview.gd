extends Node
## Narzedzie: rysuje tance na siatce, zeby obejrzec ruch bez uruchamiania gry.
## Wiersz to taniec, a kolumny to kolejne chwile.
## Uzycie: godot --path . -- --tool=res://tools/dance_preview.gd --shot=C:/plik.png [--character=Skeleton_Minion]

const COLUMNS := 8
const CELL := Vector2(1.5, 2.25)
const IMAGE := Vector2i(1500, 1680)


func _ready() -> void:
	get_node("/root/Main/Menu").visible = false
	var view := SubViewport.new()
	view.size = IMAGE
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("cfe3d4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var rows := DanceCatalog.DANCES.size()
	camera.size = CELL.y * rows
	camera.position = Vector3(CELL.x * (COLUMNS - 1) * 0.5, -CELL.y * (rows - 1) * 0.5 + 0.9, 10.0)
	view.add_child(camera)
	var file: String = Net.args.get("character", "Knight")
	for row in rows:
		var dance: Dictionary = DanceCatalog.DANCES[row]
		for column in COLUMNS:
			var character := _character(file)
			character.position = Vector3(column * CELL.x, -row * CELL.y, 0.0)
			character.rotation_degrees.y = 18.0
			view.add_child(character)
			var player := CharacterAssets.player_of(character)
			player.add_animation_library(DanceClips.LIBRARY, DanceClips.library())
			player.play(DanceCatalog.clip_of(row + 1))
			player.seek(float(column) / COLUMNS * dance.beats * 60.0 / dance.bpm, true)
			player.pause()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://dances.png")
	print("[test] siatka %s: %s" % [path, error_string(view.get_texture().get_image().save_png(path))])
	get_tree().quit()


func _character(file: String) -> Node3D:
	for entry: Dictionary in CharacterAssets.ROSTER:
		if entry.file == file:
			var character := CharacterAssets.character_for(entry.id)
			CharacterAssets.prepare_hands(character)
			return character
	return null
