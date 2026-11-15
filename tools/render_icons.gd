extends Node
## Narzedzie: renderuje ikony przedmiotow z ich modeli 3D do assets/icons.
## Uzycie: godot --path . -- --tool=res://tools/render_icons.gd [--only=deagle,awp]
## Po uruchomieniu trzeba zaimportowac nowe pliki: godot --headless --path . --import

const ICON_SIZE := 256
const AMMO_MODEL := "res://assets/weapons/bullet-foam-tip.glb"
const TIER_NAMES := { Rarity.Tier.COMMON: "common", Rarity.Tier.EPIC: "epic", Rarity.Tier.LEGENDARY: "legendary" }
## Ikony z prawie bialym metalem znikaja na kremowym tle naklejek (np. na liscie zabojstw przy 22 px),
## wiec biale czesci dostaja stalowy odcien, ciemniejszy niz tlo.
const STEEL_ICONS: Array[String] = ["res://assets/icons/knife.png"]
const STEEL_TINT := Color(0.58, 0.67, 0.8)
const STEEL_MIN_BRIGHTNESS := 0.8


func _ready() -> void:
	get_node("/root/Main/Menu").visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	var rendered := {}
	var only: PackedStringArray = str(Net.args.get("only", "")).split(",", false)
	for definition in ItemRegistry.DEFINITIONS:
		if not only.is_empty() and not only.has(String(definition.id)):
			continue
		for tier: int in TIER_NAMES:
			var visual := definition.visual(tier)
			if visual != null and not rendered.has(visual.icon_path):
				rendered[visual.icon_path] = true
				await _render(visual.model_path, visual.icon_path)
	if only.is_empty():
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
	var image := viewport.get_texture().get_image()
	if STEEL_ICONS.has(target):
		_tint_steel(image)
	var error := image.save_png(target)
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


## Prawie biale, nienasycone piksele (metal) dostaja odcien stali.
func _tint_steel(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0 and pixel.v >= STEEL_MIN_BRIGHTNESS and pixel.s < 0.25:
				image.set_pixel(x, y, Color(pixel.r * STEEL_TINT.r, pixel.g * STEEL_TINT.g, pixel.b * STEEL_TINT.b, pixel.a))
