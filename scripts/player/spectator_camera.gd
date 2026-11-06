class_name SpectatorCamera
extends Camera3D
## Kamera wyeliminowanego gracza. Leci za zywym graczem, a strzal przelacza na nastepnego.
## Wlaczenie widza nie zmienia symulacji, bo postac gracza nadal lezy tam, gdzie zginela.

const GROUP := &"spectator_camera"
const DISTANCE := 3.6
const HEIGHT := 1.7
const LOOK_HEIGHT := 1.1
const WALL_MARGIN := 0.3
const FOLLOW_SPEED := 9.0
## Przez chwile po smierci gracz widzi jeszcze miejsce, w ktorym zginal.
const DELAY_SECONDS := 2.0

var _target_id := 0
var _untagged: Player


func _ready() -> void:
	add_to_group(GROUP)
	fov = 70.0


## Nazwa ogladanego gracza albo pusty tekst, gdy kamera nie dziala.
func target_name() -> String:
	return GameState.display_name(_target_id) if current and _target_id != 0 else ""


## Ogladany gracz albo null, gdy kamera nie dziala.
func target_player() -> Player:
	return GameState.player_node(_target_id) if current and _target_id != 0 else null


func _unhandled_input(event: InputEvent) -> void:
	if current and event.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_select_next()


func _process(delta: float) -> void:
	var me := GameState.player_node(multiplayer.get_unique_id()) if Net.in_session else null
	if me == null or not _should_watch(me):
		if current and me != null:
			me.camera.current = true
			me.view_model.visible = true
		_target_id = 0
		_show_tag_of(null)
		return
	if not _is_valid_target(_target_id):
		_select_next()
	var target := GameState.player_node(_target_id)
	if target == null:
		return
	if not current:
		current = true
		me.view_model.visible = false
		global_position = target.position + Vector3.UP * HEIGHT
	_show_tag_of(target)
	_follow(target, delta)


## Oddaje nazwe poprzedniemu ogladanemu i chowa ja obecnemu.
func _show_tag_of(target: Player) -> void:
	if target == _untagged:
		return
	if is_instance_valid(_untagged):
		_untagged.set_name_tag_visible(true)
	_untagged = target
	if target != null:
		target.set_name_tag_visible(false)


func _should_watch(me: Player) -> bool:
	if not Match.is_elimination() or me.info.alive:
		return false
	return NetworkTime.tick >= me.info.death_tick + NetworkTime.seconds_to_ticks(DELAY_SECONDS)


func _follow(target: Player, delta: float) -> void:
	var pivot := target.position + Vector3.UP * LOOK_HEIGHT
	var wanted := target.position + Vector3.UP * HEIGHT + Hitscan.direction(target.yaw, 0.0) * -DISTANCE
	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pivot, wanted, Hitscan.WORLD_MASK))
	if not wall.is_empty():
		wanted = wall.position + pivot.direction_to(wanted) * -WALL_MARGIN
	global_position = global_position.lerp(wanted, minf(delta * FOLLOW_SPEED, 1.0))
	if global_position.distance_to(pivot) > 0.01:
		look_at(pivot)


func _is_valid_target(id: int) -> bool:
	var info: Dictionary = GameState.players.get(id, {})
	return not info.is_empty() and info.alive and info.in_match


func _select_next() -> void:
	var ids: Array = GameState.players.keys().filter(_is_valid_target)
	if ids.is_empty():
		return
	ids.sort()
	var after := ids.bsearch(_target_id, false)
	_target_id = ids[after % ids.size()]
