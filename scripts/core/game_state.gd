extends Node
## Lista graczy i walka. Serwer jest jedynym zrodlem prawdy: klienci dostaja
## stan przez niezawodne RPC. Ruch synchronizuje netfox w player.gd.
##
## Zdrowie celowo nie jest stanem rollbacku. Gdy klient z duzym pingiem dosyla
## ruch z przeszlosci, netfox przywraca stan z tamtego ticku, co mogloby skasowac
## obrazenia zadane w miedzyczasie przez innego gracza.

signal player_added(id: int)
signal player_removed(id: int)
signal player_changed(id: int)
signal kill_announced(killer_id: int, victim_id: int)
signal hit_confirmed(killed: bool)
signal damaged(amount: int, attacker_id: int, source: Vector3)
signal pings_updated

const MAX_HEALTH := 100
const RESPAWN_SECONDS := 3.0
const MAX_NAME_LENGTH := 32
const PING_INTERVAL := 1.0
const REJECT_FLUSH_SECONDS := 0.5

var players := {}
## Ping graczy w milisekundach, mierzony przez serwer. Host ma zawsze 0.
var pings := {}

var _ping_timer := 0.0
var _next_item_uid := 1
var _adding_player := false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(delta: float) -> void:
	_ping_timer += delta
	if _ping_timer < PING_INTERVAL:
		return
	_ping_timer = 0.0
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or not multiplayer.is_server():
		return
	var connected := multiplayer.get_peers()
	var fresh := {}
	for id: int in players:
		if id == 1:
			fresh[id] = 0
		elif connected.has(id):
			fresh[id] = int(peer.get_peer(id).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	pings = fresh
	pings_updated.emit()
	_sync_pings.rpc(fresh)


## Nazwa od klienta: bez znakow sterujacych i nie dluzsza niz limit.
static func clean_name(raw: String) -> String:
	var kept := ""
	for character in raw.substr(0, MAX_NAME_LENGTH * 4):
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			kept += character
	return kept.strip_edges().substr(0, MAX_NAME_LENGTH)


## Czysci stan lokalny przy wyjsciu z sesji.
func reset() -> void:
	pings.clear()
	for id: int in players.keys():
		players.erase(id)
		player_removed.emit(id)


func is_player(id: int) -> bool:
	return players.has(id)


func display_name(id: int) -> String:
	var info: Dictionary = players.get(id, {})
	return info.get("name", "Gracz")


## SteamID gracza albo 0, gdy nie ma konta Steam lub juz wyszedl z gry.
func steam_id_of(id: int) -> int:
	var info: Dictionary = players.get(id, {})
	return info.get("steam_id", 0)


# --- Serwer -----------------------------------------------------------------

## Dodaje gracza i informuje wszystkich. Wywolywane tylko na serwerze.
func server_add_player(id: int, player_name: String, character := "", steam_id := 0) -> void:
	var clean := clean_name(player_name)
	if clean.is_empty():
		clean = "Gracz %d" % (players.size() + 1)
	players[id] = {
		"name": clean,
		# Podaje je klient i nikt tego nie sprawdza, wiec sluzy tylko do pokazania awatara.
		"steam_id": steam_id if SteamAccount.is_valid_id(steam_id) else 0,
		"character": CharacterAssets.resolve(character, id),
		"health": MAX_HEALTH,
		"alive": true,
		"kills": 0,
		"deaths": 0,
		"respawn_id": 0,
		"death_tick": -1,
		"respawn_tick": -1,
		"slots": Inventory.empty_slots(),
		"inventory_tick": -1,
	}
	_adding_player = true
	_give_starting_items(id)
	_adding_player = false
	print("[serwer] dolaczyl %s (%d), graczy: %d" % [clean, id, players.size()])
	player_added.emit(id)
	if id != 1:
		_sync_roster.rpc_id(id, players)
	_broadcast(id)


## Zadaje obrazenia. Wywolywane tylko na serwerze, raz na kazdy rozliczony strzal.
## "source" to miejsce wybuchu. Bez niego kierunek trafienia wskazuje na atakujacego.
func server_damage(victim_id: int, amount: int, attacker_id: int, source := Vector3.INF) -> void:
	var victim: Dictionary = players.get(victim_id, {})
	if victim.is_empty() or not victim.alive:
		return
	victim.health = maxi(0, victim.health - amount)
	var killed: bool = victim.health == 0
	if killed:
		victim.alive = false
		victim.deaths += 1
		victim.respawn_id += 1
		victim.death_tick = NetworkTime.tick
		victim.respawn_tick = NetworkTime.tick + NetworkTime.seconds_to_ticks(RESPAWN_SECONDS)
		_drop_loot_on_death(victim_id)
		# Wlasny granat to smierc, ale nie punkt.
		if players.has(attacker_id) and attacker_id != victim_id:
			players[attacker_id].kills += 1
			_broadcast(attacker_id)
		print("[serwer] %s zabil %s" % [display_name(attacker_id), display_name(victim_id)])
		_announce_kill.rpc(attacker_id, victim_id)
	_broadcast(victim_id)
	_notify_damage(victim_id, amount, attacker_id, source)
	if attacker_id != victim_id:
		_notify_hit(attacker_id, killed)


## Konczy respawn, gdy symulacja przeniosla juz gracza na punkt odrodzenia.
func server_finish_respawn(id: int) -> void:
	var info: Dictionary = players.get(id, {})
	if info.is_empty() or info.alive:
		return
	info.alive = true
	info.health = MAX_HEALTH
	_give_debug_items(id)
	print("[serwer] %s wraca do gry" % display_name(id))
	_broadcast(id)


## Dodaje przedmiot do pierwszego wolnego slotu. Zwraca numer slotu albo -1, gdy brak miejsca.
func server_give_item(id: int, item_id: StringName, tier: int) -> int:
	var info: Dictionary = players.get(id, {})
	if info.is_empty():
		return -1
	var slot := Inventory.first_free(info.slots)
	if slot < 0:
		return -1
	info.slots[slot] = server_new_stack(item_id, tier)
	info.inventory_tick = NetworkTime.tick
	if not _adding_player:
		_broadcast(id)
	return slot


## Nowy egzemplarz, ktory nie lezy jeszcze w niczyim ekwipunku.
func server_new_stack(item_id: StringName, tier: int) -> Dictionary:
	var stack := ItemStack.create(_next_item_uid, item_id, tier)
	_next_item_uid += 1
	return stack


## Wklada podniesiony przedmiot do ekwipunku. Zwraca to, co trzeba bylo wyjac, albo pusty slownik.
func server_store_stack(id: int, stack: Dictionary, active_slot: int) -> Dictionary:
	var info: Dictionary = players.get(id, {})
	if info.is_empty():
		return {}
	var slot := Inventory.slot_for_pickup(info.slots, active_slot)
	var replaced := _take_from_slot(id, slot)
	info.slots[slot] = stack
	info.inventory_tick = NetworkTime.tick
	_broadcast(id)
	return replaced


## Wyjmuje przedmiot, jesli w slocie wciaz lezy ten egzemplarz. Inaczej zwraca pusty slownik.
func server_take_stack(id: int, slot: int, uid: int) -> Dictionary:
	var info: Dictionary = players.get(id, {})
	if info.is_empty() or slot < 0 or slot >= Inventory.SLOTS or uid == 0 or ItemStack.uid_of(info.slots[slot]) != uid:
		return {}
	var stack := _take_from_slot(id, slot)
	_broadcast(id)
	return stack


## Leczy i zabiera apteczke. Wolane raz na skonczone uzycie, tylko na serwerze.
func server_use_medkit(id: int, uid: int, amount: int) -> void:
	var info: Dictionary = players.get(id, {})
	if info.is_empty() or not info.alive or info.health >= MAX_HEALTH:
		return
	for slot in Inventory.SLOTS:
		if ItemStack.uid_of(info.slots[slot]) == uid:
			info.slots[slot] = {}
			info.inventory_tick = NetworkTime.tick
			info.health = mini(info.health + amount, MAX_HEALTH)
			print("[serwer] %s uleczyl sie do %d" % [info.name, info.health])
			_broadcast(id)
			return


func player_node(id: int) -> Player:
	for node in get_tree().get_nodes_in_group(&"players"):
		if (node as Player).peer_id == id and not node.is_queued_for_deletion():
			return node
	return null


## Naboje zna symulacja, wiec wyjety egzemplarz dostaje ich aktualna liczbe.
func _take_from_slot(id: int, slot: int) -> Dictionary:
	var info: Dictionary = players[id]
	var stack: Dictionary = info.slots[slot]
	if ItemStack.is_empty(stack):
		return {}
	var taken := stack.duplicate()
	var node := player_node(id)
	if node != null:
		taken.charges = node.equipment.charges_of_stack(slot, stack)
	info.slots[slot] = {}
	info.inventory_tick = NetworkTime.tick
	return taken


func _give_starter(id: int) -> void:
	var slot := server_give_item(id, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON)
	if slot >= 0:
		players[id].slots[slot].starter = true


func _give_starting_items(id: int) -> void:
	_give_starter(id)
	_give_debug_items(id)


func _give_debug_items(id: int) -> void:
	if Net.args.has("debug-items"):
		server_give_item(id, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.LEGENDARY)
		server_give_item(id, &"medkit", Rarity.Tier.COMMON)
		server_give_item(id, &"grenade", Rarity.Tier.COMMON)
	if Net.args.has("debug-weapons"):
		server_give_item(id, &"shotgun", Rarity.Tier.COMMON)
		server_give_item(id, &"shotgun", Rarity.Tier.LEGENDARY)
		server_give_item(id, &"knife", Rarity.Tier.COMMON)


## Zwykly zdobyty przedmiot zostaje na ziemi, a jeden startowy blaster przy graczu.
## Kto swoj wyrzucil, dostaje nowy, zeby nikt nie wracal do gry z pustymi rekami.
func _drop_loot_on_death(id: int) -> void:
	var kept_starter := _scatter_loot(id, true)
	if not kept_starter:
		_give_starter(id)


## Zwraca, czy gracz zachowal startowy blaster. Pozostale startowe znikaja, zeby nie zasmiecac mapy.
func _scatter_loot(id: int, keep_starter: bool) -> bool:
	var kept := false
	var loot := []
	for slot in Inventory.SLOTS:
		var stack: Dictionary = players[id].slots[slot]
		if ItemStack.is_empty(stack):
			continue
		if stack.get("starter", false):
			if keep_starter and not kept:
				kept = true
				continue
			_take_from_slot(id, slot)
		else:
			loot.append(_take_from_slot(id, slot))
	var node := player_node(id)
	if node != null and not loot.is_empty():
		WorldItems.server_scatter(loot, node.position, node.get_world_3d())
	return kept


func _broadcast(id: int) -> void:
	player_changed.emit(id)
	_sync_player.rpc(id, players[id])


func _notify_damage(victim_id: int, amount: int, attacker_id: int, source: Vector3) -> void:
	if victim_id == multiplayer.get_unique_id():
		damaged.emit(amount, attacker_id, source)
	elif players.has(victim_id):
		_receive_damage.rpc_id(victim_id, amount, attacker_id, source)


func _notify_hit(attacker_id: int, killed: bool) -> void:
	if attacker_id == multiplayer.get_unique_id():
		hit_confirmed.emit(killed)
	elif players.has(attacker_id):
		_confirm_hit.rpc_id(attacker_id, killed)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	print("[serwer] wyszedl %s (%d)" % [display_name(id), id])
	_scatter_loot(id, false)
	players.erase(id)
	player_removed.emit(id)
	_remove_player.rpc(id)


# --- RPC --------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_join(player_name: String, version: int, character: String, steam_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if version != Net.PROTOCOL_VERSION:
		print("[serwer] odrzucono klienta %d: wersja %d zamiast %d" % [sender, version, Net.PROTOCOL_VERSION])
		_reject_join.rpc_id(sender)
		await get_tree().create_timer(REJECT_FLUSH_SECONDS).timeout
		if multiplayer.get_peers().has(sender):
			multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	if not players.has(sender):
		server_add_player(sender, player_name, character, steam_id)


@rpc("authority", "call_remote", "reliable")
func _reject_join() -> void:
	Net.leave(Net.OUTDATED_MESSAGE)


@rpc("authority", "call_remote", "reliable")
func _sync_roster(roster: Dictionary) -> void:
	for id: int in roster:
		_store(id, roster[id])


@rpc("authority", "call_remote", "reliable")
func _sync_player(id: int, info: Dictionary) -> void:
	_store(id, info)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_pings(fresh: Dictionary) -> void:
	pings = fresh
	pings_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _remove_player(id: int) -> void:
	if players.erase(id):
		player_removed.emit(id)


@rpc("authority", "call_local", "reliable")
func _announce_kill(killer_id: int, victim_id: int) -> void:
	kill_announced.emit(killer_id, victim_id)


@rpc("authority", "call_remote", "reliable")
func _confirm_hit(killed: bool) -> void:
	hit_confirmed.emit(killed)


@rpc("authority", "call_remote", "reliable")
func _receive_damage(amount: int, attacker_id: int, source: Vector3) -> void:
	damaged.emit(amount, attacker_id, source)


## Aktualizuje slownik w miejscu, bo wezel gracza trzyma do niego referencje.
func _store(id: int, info: Dictionary) -> void:
	if players.has(id):
		players[id].merge(info, true)
		player_changed.emit(id)
	else:
		players[id] = info.duplicate()
		player_added.emit(id)
