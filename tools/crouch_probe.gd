extends Node
## Narzedzie testowe dla bota "overhead": liczy wlasne strzaly i potwierdzone trafienia.

var _shots := 0
var _hits := 0


func _ready() -> void:
	GameState.hit_confirmed.connect(func(_killed: bool) -> void: _hits += 1)
	while get_tree().get_nodes_in_group(&"players").is_empty() or GameState.player_node(multiplayer.get_unique_id()) == null:
		await get_tree().process_frame
	GameState.player_node(multiplayer.get_unique_id()).equipment.fired.connect(func() -> void: _shots += 1)
	while true:
		await get_tree().create_timer(2.0).timeout
		print("[nad_glowa] strzaly=%d trafienia=%d" % [_shots, _hits])
