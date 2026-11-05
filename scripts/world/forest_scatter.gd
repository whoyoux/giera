@tool
class_name ForestScatter
extends Node3D
## Trawa, krzaki i dalekie drzewa bez kolizji. To czysta dekoracja, wiec kazdy klient losuje
## je sam, a jeden model rysowany setki razy kosztuje tyle co jedno wywolanie.

const SEED := 4217
const PLAY_RADIUS := 38.0
const FAR_RADIUS := 85.0
const GRASS_COUNT := 900
const BUSH_COUNT := 130
const FAR_TREE_COUNT := 260
const GRASS_FADE := 50.0
const RUIN_RADIUS := 9.0
const GRASS_MODELS: Array[String] = ["Grass_1_A", "Grass_1_B", "Grass_1_C", "Grass_2_A", "Grass_2_B"]
const BUSH_MODELS: Array[String] = ["Bush_1_A", "Bush_1_C", "Bush_2_A", "Bush_2_C", "Bush_3_A", "Bush_4_A"]
const TREE_MODELS: Array[String] = ["Tree_1_A", "Tree_1_B", "Tree_2_A", "Tree_2_B", "Tree_3_A", "Tree_4_A", "Tree_4_B"]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_scatter(GRASS_MODELS, GRASS_COUNT, 0.0, PLAY_RADIUS, Vector2(1.1, 2.1), rng, GRASS_FADE, false)
	_scatter(BUSH_MODELS, BUSH_COUNT, 11.0, PLAY_RADIUS, Vector2(1.6, 3.2), rng, 0.0, true)
	_scatter(TREE_MODELS, FAR_TREE_COUNT, PLAY_RADIUS + 3.0, FAR_RADIUS, Vector2(1.5, 2.6), rng, 0.0, true)


func _scatter(models: Array[String], count: int, inner: float, outer: float, sizes: Vector2, rng: RandomNumberGenerator, fade: float, shadows: bool) -> void:
	var batches := {}
	for model in models:
		batches[model] = []
	for i in count:
		var angle := rng.randf() * TAU
		# Pierwiastek rozklada punkty rowno na calej powierzchni kola.
		var distance := sqrt(rng.randf_range(inner * inner, outer * outer))
		var x := sin(angle) * distance
		var z := cos(angle) * distance
		var picked: String = models[rng.randi() % models.size()]
		var scale_by := rng.randf_range(sizes.x, sizes.y)
		var yaw := rng.randf() * TAU
		if _is_blocked(x, z):
			continue
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_by)
		batches[picked].append(Transform3D(basis, Vector3(x, ForestTerrain.surface(x, z), z)))
	for model: String in batches:
		_add_batch(model, batches[model], fade, shadows)


func _is_blocked(x: float, z: float) -> bool:
	if Vector2(x, z).length() < RUIN_RADIUS or ForestTerrain.is_path(x, z):
		return true
	return ForestTerrain.creek_distance(x, z) < ForestTerrain.CREEK_OUTER - 0.8


func _add_batch(model: String, transforms: Array, fade: float, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var source := (load(ForestProp.MODEL_FOLDER % (model + "_Color1")) as PackedScene).instantiate()
	var mesh_node := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh_node.mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	source.free()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if fade > 0.0:
		instance.visibility_range_end = fade
		instance.visibility_range_end_margin = 8.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)
