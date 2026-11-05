class_name Players
extends Node3D
## Tworzy i usuwa wezly graczy na podstawie listy z GameState.

signal local_player_spawned(player: Player)
signal local_player_removed

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _ready() -> void:
	GameState.player_added.connect(_spawn)
	GameState.player_removed.connect(_despawn)


## Wynik zalezy tylko od danych wspolnych, wiec jest taki sam u wszystkich.
func spawn_point(peer_id: int, respawn_number: int) -> Vector3:
	var points := get_tree().get_nodes_in_group(&"spawn_points")
	var index := absi(hash(peer_id * 37 + respawn_number * 19)) % points.size()
	return (points[index] as Node3D).global_position


func _spawn(id: int) -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = str(id)
	player.peer_id = id
	player.position = spawn_point(id, 0)
	# Serwer wlada stanem postaci, a gracz tylko swoim wejsciem.
	player.set_multiplayer_authority(1)
	player.get_node("Input").set_multiplayer_authority(id)
	if multiplayer.is_server():
		var sync := player.get_node("RollbackSynchronizer") as RollbackSynchronizer
		sync.visibility_filter.add_visibility_filter(GameState.is_player)
	add_child(player)
	_update_visibility()
	if id == multiplayer.get_unique_id():
		local_player_spawned.emit(player)


func _despawn(id: int) -> void:
	var player := get_node_or_null(str(id))
	if player == null:
		return
	if id == multiplayer.get_unique_id() or (player as Player).is_local():
		local_player_removed.emit()
	player.queue_free()
	_update_visibility()


## Dolaczajacy klient nie ma jeszcze wezlow graczy, wiec nie moze dostawac ich stanu.
func _update_visibility() -> void:
	if not multiplayer.is_server():
		return
	for child in get_children():
		if child is Player and not child.is_queued_for_deletion():
			(child.get_node("RollbackSynchronizer") as RollbackSynchronizer).visibility_filter.update_visibility()
