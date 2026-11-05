extends Node
## Narzedzie testowe: ile strzalow celnych na ekranie klienta zaliczyl serwer.
## Uzywac z --bot=headhunter, ktory strzela tylko, gdy na ekranie ma cel w celowniku.

var _shots := 0
var _hits := 0
var _damaged := 0
var _player: Player


func _ready() -> void:
	GameState.hit_confirmed.connect(func(_killed: bool) -> void: _hits += 1)
	GameState.damaged.connect(func(_amount: int, _attacker: int, _source: Vector3) -> void: _damaged += 1)
	get_tree().create_timer(5.0).timeout.connect(_report)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Equipment:
		node.ready.connect(func() -> void:
			if (node as Equipment).player.is_local():
				node.fired.connect(func() -> void: _shots += 1))


func _report() -> void:
	var percent := 100.0 * _hits / maxi(_shots, 1)
	print("[hit_stats] pingi=", GameState.pings.values(), " rtt_klienta=", int(NetworkTime.remote_rtt * 1000.0))
	print("[hit_stats] strzaly=%d trafienia=%d zaliczone=%.1f%% obrywal=%d rtt=%dms" % [_shots, _hits, percent, _damaged, int(NetworkTime.remote_rtt * 1000.0)])
	get_tree().create_timer(5.0).timeout.connect(_report)
