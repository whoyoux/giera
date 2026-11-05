class_name DanceCamera
extends RefCounted
## W czasie tanca kamera odjezdza za postac, a mysz kraz nia wokol niej. Patrzy caly czas
## w kierunku wejscia gracza, wiec po tancu wraca do oczu bez szarpniecia.

const DISTANCE := 3.3
const PIVOT_HEIGHT := 1.1
const WALL_MARGIN := 0.3
const OUT_SECONDS := 0.45
const BACK_SECONDS := 0.22
## Przy powrocie model znika, zanim kamera wejdzie mu w glowe.
const MODEL_SHOWN_FROM := 0.3
const WORLD_MASK := 1

var blend := 0.0


func is_active() -> bool:
	return blend > 0.0


func update(player: Player, delta: float) -> void:
	var dancing := player.dance_id != DanceCatalog.NONE
	blend = move_toward(blend, 1.0 if dancing else 0.0, delta / (OUT_SECONDS if dancing else BACK_SECONDS))
	var camera := player.camera
	var active := is_active()
	if camera.top_level != active:
		camera.top_level = active
		if not active:
			camera.position = Vector3.ZERO
	player.view_model.set_shown(not active)
	var model_shown := blend >= MODEL_SHOWN_FROM
	if player.model.visible != model_shown:
		player.model.visible = model_shown
		player.model.set_animating(model_shown)
	if not active:
		return
	var yaw := player.input.look_yaw
	var pitch := player.input.look_pitch
	var pivot := player.position + Vector3.UP * PIVOT_HEIGHT
	var orbit := _clear_point(player, pivot, pivot - Hitscan.direction(yaw, pitch) * DISTANCE)
	var position := player.eye_position().lerp(orbit, smoothstep(0.0, 1.0, blend))
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), position)


## Punkt kamery przed najblizsza przeszkoda, zeby nie zagladac przez sciany i ziemie.
func _clear_point(player: Player, from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	return (hit.position as Vector3) + (from - to).normalized() * WALL_MARGIN
