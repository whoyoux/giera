extends Node
## Narzedzie testowe regeneracji przez siec. Na serwerze rani gracza "Ranny", a potem trafia go
## w trakcie leczenia. Na kliencie sprawdza, ze po trafieniu zdrowie nie rosnie przez 6 s.

const VICTIM := "Ranny"


func _ready() -> void:
	# Przed polaczeniem kazdy proces jest dla Godota serwerem, wiec rozstrzyga linia polecen.
	if Net.args.has("server"):
		_run_server()
	else:
		_run_client()


func _run_server() -> void:
	var id := await _victim_id()
	await get_tree().create_timer(2.0).timeout
	GameState.server_damage(id, 50, GameState.ZONE_ATTACKER)
	await get_tree().create_timer(8.5).timeout
	var healed: int = GameState.players[id].health
	print("[regen] serwer: po 8,5 s zdrowie %d" % healed)
	GameState.server_damage(id, 10, GameState.ZONE_ATTACKER)
	var after_hit: int = GameState.players[id].health
	var highest := after_hit
	# Okno konczy sie przed uplywem 6 s, bo timery tylko w przyblizeniu trzymaja czas.
	for i in 50:
		await get_tree().create_timer(0.1).timeout
		highest = maxi(highest, GameState.players[id].health)
	await get_tree().create_timer(2.0).timeout
	var later: int = GameState.players[id].health
	print("[regen] serwer: leczyl=%s przerwane=%s potem=%s" % [healed > 50, highest == after_hit, later > after_hit])


func _run_client() -> void:
	# Numer gracza jest znany dopiero po polaczeniu.
	while not GameState.players.has(multiplayer.get_unique_id()):
		await get_tree().process_frame
	var me := multiplayer.get_unique_id()
	await GameState.damaged
	await GameState.damaged
	await get_tree().create_timer(0.4).timeout
	var after_hit: int = GameState.players[me].health
	var highest := after_hit
	for i in 50:
		await get_tree().create_timer(0.1).timeout
		highest = maxi(highest, GameState.players[me].health)
	await get_tree().create_timer(2.5).timeout
	var later: int = GameState.players[me].health
	print("[regen] klient: przerwane=%s potem=%s" % [highest == after_hit, later > after_hit])


func _victim_id() -> int:
	while true:
		for id: int in GameState.players:
			if GameState.players[id].name == VICTIM:
				return id
		await get_tree().process_frame
	return 0
