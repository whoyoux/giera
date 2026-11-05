extends Node
## Narzedzie testowe: mierzy korekty pozycji lokalnego gracza.
## Co sekunde wypisuje najwiekszy nadmiarowy skok ponad to, co wynika z predkosci.

var _player: Player
var _before := Vector3.ZERO
var _seen_respawn := 0
var _worst := 0.0
var _ticks := 0
var _over_limit := 0
var _ticks_in_loop := 0


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_before_loop)
	NetworkTime.after_tick_loop.connect(_after_loop)
	NetworkTime.on_tick.connect(func(_delta: float, _tick: int) -> void: _ticks_in_loop += 1)


func _find_player() -> void:
	for node in get_tree().get_nodes_in_group(&"players"):
		if (node as Player).is_local():
			_player = node


func _before_loop() -> void:
	if _player == null or not is_instance_valid(_player):
		_find_player()
	if _player != null:
		_before = _player.position
	_ticks_in_loop = 0


func _after_loop() -> void:
	if _player == null:
		return
	if _player.applied_respawn != _seen_respawn:
		_seen_respawn = _player.applied_respawn
		return
	var moved := _player.position - _before
	moved.y = 0.0
	var allowed := Player.SPEED * NetworkTime.ticktime * _ticks_in_loop
	var excess := maxf(0.0, moved.length() - allowed)
	_worst = maxf(_worst, excess)
	_ticks += 1
	if excess > 0.1:
		_over_limit += 1
	if _ticks % 150 == 0:
		print("[probe] rtt=%dms najwieksza_korekta=%.3fm korekt>10cm=%d/%d" % [
			int(NetworkTime.remote_rtt * 1000.0),
			_worst, _over_limit, _ticks])
		_worst = 0.0
