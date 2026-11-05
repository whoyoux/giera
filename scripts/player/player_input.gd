class_name PlayerInput
extends Node
## Wejscie gracza. Ten wezel nalezy do klienta, a netfox przesyla jego wlasciwosci
## na serwer co tick.

const MOUSE_SENSITIVITY := 0.0025
const MAX_PITCH := 1.5

# Wysylane do serwera (input_properties w RollbackSynchronizer).
var move := Vector2.ZERO
var jump := false
var fire := false
var yaw := 0.0
var pitch := 0.0

# Biezace polozenie kamery aktualizowane co klatke. Rollback nadpisuje yaw i pitch
# wartosciami z historii, wiec akumulator musi byc osobno.
var look_yaw := 0.0
var look_pitch := 0.0

var _bot_time := 0.0


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw -= event.relative.x * MOUSE_SENSITIVITY
		look_pitch = clampf(look_pitch - event.relative.y * MOUSE_SENSITIVITY, -MAX_PITCH, MAX_PITCH)


func _gather() -> void:
	if not is_multiplayer_authority():
		return
	if not Net.bot_mode.is_empty():
		_gather_bot()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump = Input.is_action_pressed("jump")
		fire = Input.is_action_pressed("fire")
	else:
		move = Vector2.ZERO
		jump = false
		fire = false
	yaw = look_yaw
	pitch = look_pitch


## Prosty bot do testow i cwiczen w pojedynke.
func _gather_bot() -> void:
	_bot_time += NetworkTime.ticktime
	var me := get_parent() as Player
	match Net.bot_mode:
		"runner":
			move = Vector2(sin(_bot_time * 0.9), -0.8).normalized()
			look_yaw += 0.02
			jump = fmod(_bot_time, 4.0) < 0.1
		"shooter":
			var target := _nearest_enemy(me)
			fire = target != null
			if target != null:
				var to_target := target.position + Vector3.UP * 0.9 - me.eye_position()
				look_yaw = atan2(-to_target.x, -to_target.z)
				look_pitch = asin(clampf(to_target.normalized().y, -1.0, 1.0))
			move = Vector2(sin(_bot_time * 0.7), 0.0)


func _nearest_enemy(me: Player) -> Player:
	var best: Player = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if other == me or not other.is_alive():
			continue
		var distance := me.position.distance_squared_to(other.position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best
