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
const PLACE_FONT_SIZE := 10


## Rozmiar mapki. Duza mapa pod klawiszem M to ta sama mapka, tylko wieksza.
var side := SIDE
## Duza mapa pokazuje sie tylko przy wcisnietym klawiszu, a mala wtedy znika.
var big := false


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * side
	size = Vector2.ONE * side
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	var holding := Input.is_action_pressed("map") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var team_map := Match.is_team_mode() and Match.phase == Match.Phase.LIVE
	visible = (not Match.zone_state().is_empty() or team_map) and holding == big
	if visible:
		queue_redraw()


func _draw() -> void:
	var state := Match.zone_state()
	if state.is_empty() and not Match.is_team_mode():
		return
	var middle := size * 0.5
	var map_scale := (side * 0.5 - INNER_MARGIN) / Maps.info().zone_radius
	middle -= Maps.info().zone_center * map_scale
	var outer_middle := size * 0.5
	draw_circle(outer_middle + Vector2(0.0, 4.0), side * 0.5, UiStyle.SHADOW)
	draw_circle(outer_middle, side * 0.5, Color.WHITE)
	if state.is_empty():
		# Team Deathmatch nie ma strefy: cala mapa jest bezpieczna, a liczy sie, gdzie sa swoi.
		draw_circle(outer_middle, side * 0.5 - BORDER, SAFE_COLOR)
		_draw_places(middle, map_scale)
		_draw_allies(middle, map_scale)
		_draw_player(middle, map_scale)
		return
	draw_circle(outer_middle, side * 0.5 - BORDER, DANGER_COLOR)
	var center: Vector2 = state.center
	draw_circle(middle + center * map_scale, state.radius * map_scale, SAFE_COLOR)
	var target: Vector2 = state.target_center
	draw_arc(middle + target * map_scale, state.target_radius * map_scale, 0.0, TAU, CIRCLE_POINTS, Color.WHITE, TARGET_WIDTH, true)
	_draw_places(middle, map_scale)
	_draw_drops(middle, map_scale)
	_draw_player(middle, map_scale)


## Nazwy miejsc na duzej mapie, zeby latwiej sie umowic, gdzie isc.
func _draw_places(middle: Vector2, map_scale: float) -> void:
	var places := Maps.info().places
	if places.size() < 4 and not big:
		return
	var font := ThemeDB.fallback_font
	for place: Dictionary in places:
		var at: Vector2 = middle + (place.at as Vector2) * map_scale
		draw_circle(at, 2.5, UiStyle.INK)
		var text: String = place.name
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
		draw_string_outline(font, at + Vector2(-width * 0.5, -4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(), 3, Color.WHITE)
		draw_string(font, at + Vector2(-width * 0.5, -4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(), UiStyle.INK)


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


## Sojusznicy jako kropki w kolorze druzyny. Wrogow mapa nie zdradza.
func _draw_allies(middle: Vector2, map_scale: float) -> void:
	var me := multiplayer.get_unique_id()
	var radius := 5.0 if big else 3.5
	var limit := side * 0.5 - BORDER - radius
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if other.peer_id == me or not other.is_alive() or not Teams.are_allies(me, other.peer_id):
			continue
		var at := middle + Vector2(other.position.x, other.position.z) * map_scale
		var offset := at - size * 0.5
		if offset.length() > limit:
			at = size * 0.5 + offset.normalized() * limit
		draw_circle(at, radius + 1.5, Color.WHITE)
		draw_circle(at, radius, Teams.color_of(Teams.team_of(other.peer_id)))


func _followed_player() -> Player:
	var me := GameState.player_node(multiplayer.get_unique_id())
	if me != null and me.is_alive():
		return me
	var camera := get_tree().get_first_node_in_group(SpectatorCamera.GROUP) as SpectatorCamera
	return camera.target_player() if camera != null else null


func _font_size() -> int:
	return PLACE_FONT_SIZE * 2 if big else PLACE_FONT_SIZE


## Zrzuty zaopatrzenia jako zolte kwadraty, a te w powietrzu migaja.
func _draw_drops(middle: Vector2, map_scale: float) -> void:
	for id: int in SupplyDrops.drops:
		var drop: Dictionary = SupplyDrops.drops[id]
		var at: Vector2 = middle + Vector2(drop.position.x, drop.position.z) * map_scale
		var half := 7.0 if big else 4.0
		if not drop.landed and int(Time.get_ticks_msec() / 250) % 2 == 0:
			continue
		draw_rect(Rect2(at - Vector2.ONE * (half + 2.0), Vector2.ONE * (half + 2.0) * 2.0), UiStyle.INK)
		draw_rect(Rect2(at - Vector2.ONE * half, Vector2.ONE * half * 2.0), Color("ffcb47"))
