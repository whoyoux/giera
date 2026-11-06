extends Node
## Tryb i przebieg gry na tym serwerze. Klient dowiaduje sie o nim od serwera przy dolaczaniu,
## wiec zawsze gra w to, co serwer prowadzi, nawet gdy w menu wybral co innego.

signal mode_changed

var mode := GameMode.Id.DEATHMATCH


func _ready() -> void:
	Net.session_ended.connect(func(_reason: String) -> void: _set_mode(GameMode.Id.DEATHMATCH))


## Wolane przed startem nasluchu, wiec pierwszy gracz zastaje juz wlasciwy tryb.
func server_begin(new_mode: int) -> void:
	_set_mode(new_mode)


func is_elimination() -> bool:
	return mode == GameMode.Id.BATTLE_ROYALE


## Dolaczajacy gracz musi znac tryb, zanim powstanie jego postac.
func server_send_state(id: int) -> void:
	_sync_mode.rpc_id(id, mode)


func _set_mode(new_mode: int) -> void:
	if new_mode != mode:
		mode = new_mode
		mode_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync_mode(new_mode: int) -> void:
	_set_mode(new_mode)
