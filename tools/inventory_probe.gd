extends Node
## Narzedzie testowe: co sekunde wypisuje stan ekwipunku graczy, zeby porownac klienta z serwerem.
## Na kliencie liczy tez, ile razy aktywny slot rozjechal sie z wyborem po czasie na zmiane.

const SETTLE_TICKS := 12

var _elapsed := 0.0
var _wrong_ticks := 0
var _total_ticks := 0
var _last_wanted := 0
var _since_change := 0
var _flips := 0
var _last_active := -1


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_watch)


func _watch() -> void:
	var me := _local_player()
	if me == null:
		return
	var wanted := me.input.selected_slot()
	if wanted != _last_wanted:
		_last_wanted = wanted
		_since_change = 0
		_flips -= 1
	_since_change += 1
	if me.equipment.active_slot != _last_active:
		_last_active = me.equipment.active_slot
		_flips += 1
	_total_ticks += 1
	if me.equipment.active_slot != wanted:
		_wrong_ticks += 1


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0:
		return
	_elapsed = 0.0
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		var equipment := player.equipment
		print("[inv] gracz=%s aktywny=%d naboje=%d,%d,%d,%d" % [player.info.name, equipment.active_slot,
				equipment.charges(0), equipment.charges(1), equipment.charges(2), equipment.charges(3)])
	print("[loot] %s" % _loot_summary())
	if _local_player() != null:
		print("[inv] rozjazd_slotu=%d/%d dodatkowe_zmiany=%d" % [_wrong_ticks, _total_ticks, _flips])


## Lista przedmiotow na ziemi i wszystkich egzemplarzy. Zaden uid nie moze wystapic dwa razy.
func _loot_summary() -> String:
	var ids := WorldItems.items.keys()
	ids.sort()
	var uids := []
	for id: int in WorldItems.items:
		uids.append(ItemStack.uid_of(WorldItems.items[id].stack))
	for player_id: int in GameState.players:
		for stack: Dictionary in GameState.players[player_id].slots:
			if not ItemStack.is_empty(stack):
				uids.append(ItemStack.uid_of(stack))
	uids.sort()
	var duplicates := 0
	for i in range(1, uids.size()):
		if uids[i] == uids[i - 1]:
			duplicates += 1
	return "lezy=%s uid=%s duplikaty=%d" % [ids, uids, duplicates]


func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group(&"players"):
		if (node as Player).is_local():
			return node
	return null
