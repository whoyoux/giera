extends Node
## Narzedzie testowe do apteczki przez siec. Na serwerze rani graczy co kilka sekund, a u klienta
## liczy rozpoczecia leczenia. Jedno leczenie nie moze zaczynac sie kilka razy.

const DAMAGE_EVERY := 5.0
const DAMAGE := 40

var _elapsed := 0.0
var _print_elapsed := 0.0
var _starts := 0
var _cancels := 0
var _bound: Equipment


func _process(delta: float) -> void:
	_elapsed += delta
	_print_elapsed += delta
	if multiplayer.is_server() and _elapsed >= DAMAGE_EVERY:
		_elapsed = 0.0
		for id: int in GameState.players:
			if GameState.players[id].alive and GameState.players[id].health > DAMAGE:
				GameState.server_damage(id, DAMAGE, 0)
	if _bound == null:
		_bind_local()
	if _print_elapsed >= 1.0:
		_print_elapsed = 0.0
		if _bound != null:
			print("[heal] rozpoczecia=%d przerwania=%d zdrowie=%d sloty=%s" % [_starts, _cancels, _bound.player.info.health, _bound.slots().map(func(s: Dictionary) -> String: return s.get("item", "-"))])


func _bind_local() -> void:
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if player.is_local():
			_bound = player.equipment
			_bound.action_started.connect(func() -> void: _starts += 1)
			_bound.action_cancelled.connect(func() -> void: _cancels += 1)
