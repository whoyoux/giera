class_name ZoneMap
extends Control
## Mapka w rogu: strefa, jej nastepne kolo i wlasna pozycja. Innych graczy celowo nie pokazuje.
## Widz widzi na niej ogladanego gracza.

const SIDE := 170.0
const BORDER := 5.0
const INNER_MARGIN := 7.0
const DANGER_COLOR := Color("8d78e8")
const SAFE_COLOR := Color("cfe8b8")
const TARGET_WIDTH := 2.5
const ARROW_LENGTH := 11.0
const ARROW_WIDTH := 7.0
const CIRCLE_POINTS := 64


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * SIDE
	size = Vector2.ONE * SIDE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	visible = not Match.zone_state().is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	var state := Match.zone_state()
	if state.is_empty():
		return
	var middle := size * 0.5
	var map_scale := (SIDE * 0.5 - INNER_MARGIN) / Maps.info().zone_radius
	middle -= Maps.info().zone_center * map_scale
	draw_circle(middle + Vector2(0.0, 4.0), SIDE * 0.5, UiStyle.SHADOW)
	draw_circle(middle, SIDE * 0.5, Color.WHITE)
	draw_circle(middle, SIDE * 0.5 - BORDER, DANGER_COLOR)
	var center: Vector2 = state.center
	draw_circle(middle + center * map_scale, state.radius * map_scale, SAFE_COLOR)
	var target: Vector2 = state.target_center
	draw_arc(middle + target * map_scale, state.target_radius * map_scale, 0.0, TAU, CIRCLE_POINTS, Color.WHITE, TARGET_WIDTH, true)
	_draw_player(middle, map_scale)


func _draw_player(middle: Vector2, map_scale: float) -> void:
	var player := _followed_player()
	if player == null:
		return
	var at := middle + Vector2(player.position.x, player.position.z) * map_scale
	var look := player.look_direction()
	var forward := Vector2(look.x, look.z).normalized()
	var side := forward.orthogonal() * ARROW_WIDTH
	var points := PackedVector2Array([at + forward * ARROW_LENGTH, at - forward * ARROW_LENGTH * 0.5 + side, at - forward * ARROW_LENGTH * 0.5 - side])
	draw_colored_polygon(points, UiStyle.CORAL)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color.WHITE, 1.5, true)


func _followed_player() -> Player:
	var me := GameState.player_node(multiplayer.get_unique_id())
	if me != null and me.is_alive():
		return me
	var camera := get_tree().get_first_node_in_group(SpectatorCamera.GROUP) as SpectatorCamera
	return camera.target_player() if camera != null else null
