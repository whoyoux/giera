extends Node
## Narzedzie: renderuje ikony przedmiotow z ich modeli 3D do assets/icons.
## Uzycie: godot --path . -- --tool=res://tools/render_icons.gd
## Po uruchomieniu trzeba zaimportowac nowe pliki: godot --headless --path . --import

const ICON_SIZE := 256
const AMMO_MODEL := "res://assets/weapons/bullet-foam-tip.glb"
const TIER_NAMES := { Rarity.Tier.COMMON: "common", Rarity.Tier.EPIC: "epic", Rarity.Tier.LEGENDARY: "legendary" }


func _ready() -> void:
	get_node("/root/Main/Menu").visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	for definition in ItemRegistry.DEFINITIONS:
		for tier: int in TIER_NAMES:
			var path := definition.model_path(tier)
			if not path.is_empty():
				await _render(path, "res://assets/icons/%s_%s.png" % [definition.id, TIER_NAMES[tier]])
	await _render(AMMO_MODEL, "res://assets/icons/ammo.png", 28.0, Vector3(-1.4, 0.8, 0.9))
	get_tree().quit()


func _render(model_path: String, target: String, tilt := 0.0, view := Vector3(-1.6, 0.55, -0.35)) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
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
	sun.rotation_degrees = Vector3(-50, -60, 0)
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	viewport.add_child(model)
	model.rotation_degrees.z = -tilt
	var bounds := _bounds_of(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(maxf(bounds.size.x, bounds.size.z), bounds.size.y) * 1.2
	viewport.add_child(camera)
	var center := bounds.get_center()
	camera.look_at_from_position(center + view.normalized() * 3.0, center)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(target)
	print("[test] %s: %s" % [target, error_string(error)])
	viewport.queue_free()


func _bounds_of(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
