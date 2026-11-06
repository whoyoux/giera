extends Node
## Test sieci: bot biega i skacze, a sonda porownuje przewidziany stan wlasnej postaci ze stanem
## z serwera. Rozjazd oznacza, ze klient zobaczy szarpniecie obrazu.
## Uruchamia go tools/prediction_net_test.sh.

const MAX_POSITION_ERROR := 0.05
const MAX_VELOCITY_ERROR := 1.0
const JUMP_EVERY_SECONDS := 1.0
const JUMP_SECONDS := 0.1
## Przewidywania starsze o tyle tickow od stanu z serwera nie sa juz potrzebne.
const KEEP_TICKS := 4

var _player: Player
var _predicted := {}
var _last_state_tick := -1
var _time := 0.0
var _compared := 0
var _position_errors := 0
var _velocity_errors := 0
var _worst_position := 0.0


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_compare)
	get_tree().create_timer(float(Net.args.get("probe-seconds", 30.0))).timeout.connect(_finish)


func _force_jump() -> void:
	if is_instance_valid(_player):
		_time += NetworkTime.ticktime
		_player.input.jump = fmod(_time, JUMP_EVERY_SECONDS) < JUMP_SECONDS


func _compare() -> void:
	if not is_instance_valid(_player):
		_find_player()
		return
	var states: _PropertyHistoryBuffer = _player.sync._states
	var state_tick := _player.sync.get_last_known_state()
	if state_tick > _last_state_tick:
		_last_state_tick = state_tick
		if _predicted.has(state_tick) and states.has(state_tick):
			_compare_state(_predicted[state_tick], states.get_snapshot(state_tick))
	# Stan z serwera nadpisze te ticki, wiec zapamietujemy je, dopoki sa jeszcze przewidziane.
	for tick in range(state_tick + 1, NetworkTime.tick + 1):
		if states.has(tick):
			_predicted[tick] = states.get_snapshot(tick)
	for tick: int in _predicted.keys():
		if tick < state_tick - KEEP_TICKS:
			_predicted.erase(tick)


func _find_player() -> void:
	for node in get_tree().get_nodes_in_group(&"players"):
		if (node as Player).is_local():
			_player = node
			# Zegar wywola to po zebraniu wejscia bota, wiec nasz skok ma pierwszenstwo.
			NetworkTime.before_tick_loop.connect(_force_jump)


func _compare_state(guess: _PropertySnapshot, server: _PropertySnapshot) -> void:
	var position_error: float = (guess.get_value(":position") - server.get_value(":position")).length()
	var velocity_error: float = (guess.get_value(":velocity") - server.get_value(":velocity")).length()
	_compared += 1
	_worst_position = maxf(_worst_position, position_error)
	if position_error > MAX_POSITION_ERROR:
		_position_errors += 1
	if velocity_error > MAX_VELOCITY_ERROR:
		_velocity_errors += 1


func _finish() -> void:
	print("[prediction] stany=%d pozycja=%d predkosc=%d najgorszy_blad=%.3f" % [_compared, _position_errors, _velocity_errors, _worst_position])
	get_tree().quit()
