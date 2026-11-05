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
signal damaged(amount: int, attacker_id: int)
signal pings_updated

const MAX_HEALTH := 100
const RESPAWN_SECONDS := 3.0
const MAX_NAME_LENGTH := 16
const PING_INTERVAL := 1.0

var players := {}
## Ping graczy w milisekundach, mierzony przez serwer. Host ma zawsze 0.
var pings := {}

var _ping_timer := 0.0


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


# --- Serwer -----------------------------------------------------------------

## Dodaje gracza i informuje wszystkich. Wywolywane tylko na serwerze.
func server_add_player(id: int, player_name: String) -> void:
	var clean := player_name.strip_edges().substr(0, MAX_NAME_LENGTH)
	if clean.is_empty():
		clean = "Gracz %d" % (players.size() + 1)
	players[id] = {
		"name": clean,
		"health": MAX_HEALTH,
		"alive": true,
		"kills": 0,
		"deaths": 0,
		"respawn_id": 0,
		"death_tick": -1,
		"respawn_tick": -1,
	}
	print("[serwer] dolaczyl %s (%d), graczy: %d" % [clean, id, players.size()])
	player_added.emit(id)
	if id != 1:
		_sync_roster.rpc_id(id, players)
	_broadcast(id)


## Zadaje obrazenia. Wywolywane tylko na serwerze, raz na kazdy rozliczony strzal.
func server_damage(victim_id: int, amount: int, attacker_id: int) -> void:
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
		if players.has(attacker_id):
			players[attacker_id].kills += 1
			_broadcast(attacker_id)
		print("[serwer] %s zabil %s" % [display_name(attacker_id), display_name(victim_id)])
		_announce_kill.rpc(attacker_id, victim_id)
	_broadcast(victim_id)
	_notify_damage(victim_id, amount, attacker_id)
	_notify_hit(attacker_id, killed)


## Konczy respawn, gdy symulacja przeniosla juz gracza na punkt odrodzenia.
func server_finish_respawn(id: int) -> void:
	var info: Dictionary = players.get(id, {})
	if info.is_empty() or info.alive:
		return
	info.alive = true
	info.health = MAX_HEALTH
	print("[serwer] %s wraca do gry" % display_name(id))
	_broadcast(id)


func _broadcast(id: int) -> void:
	player_changed.emit(id)
	_sync_player.rpc(id, players[id])


func _notify_damage(victim_id: int, amount: int, attacker_id: int) -> void:
	if victim_id == multiplayer.get_unique_id():
		damaged.emit(amount, attacker_id)
	elif players.has(victim_id):
		_receive_damage.rpc_id(victim_id, amount, attacker_id)


func _notify_hit(attacker_id: int, killed: bool) -> void:
	if attacker_id == multiplayer.get_unique_id():
		hit_confirmed.emit(killed)
	elif players.has(attacker_id):
		_confirm_hit.rpc_id(attacker_id, killed)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	print("[serwer] wyszedl %s (%d)" % [display_name(id), id])
	players.erase(id)
	player_removed.emit(id)
	_remove_player.rpc(id)


# --- RPC --------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_join(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		server_add_player(sender, player_name)


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
func _receive_damage(amount: int, attacker_id: int) -> void:
	damaged.emit(amount, attacker_id)


## Aktualizuje slownik w miejscu, bo wezel gracza trzyma do niego referencje.
func _store(id: int, info: Dictionary) -> void:
	if players.has(id):
		players[id].merge(info, true)
		player_changed.emit(id)
	else:
		players[id] = info.duplicate()
		player_added.emit(id)
