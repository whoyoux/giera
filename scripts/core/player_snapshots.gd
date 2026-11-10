extends Node
## Migawka innych graczy. Netfox wysyla stan postaci tylko jej wlascicielowi, bo tylko on ja
## przewiduje. Pozostalych klient nie symuluje, tylko rysuje z bufora RemoteMotion, wiec serwer
## raz na tick wysyla kazdemu klientowi jeden maly pakiet z upakowanym stanem pozostalych graczy.
##
## Pakiet: tick naglowka (u32), liczba rekordow (u8) i rekordy stalej dlugosci. Rekord kazdego
## gracza jest kodowany raz na tick i wklejany do pakietow wszystkich odbiorcow.
## Wysylamy stan, a nie zdarzenia ("ostatni strzal w ticku N"), wiec zgubiony pakiet naprawia nastepny.

const HEADER_BYTES := 5
const RECORD_BYTES := 24
## Pozycja w centymetrach w i16 miesci +-327 m. Najwieksza mapa (Dolina) ma +-224 m.
const POSITION_SCALE := 100.0
const I16_MAX := 32767
const U16_RANGE := 65536
const PITCH_SCALE := 20000.0
const CROUCH_SCALE := 255.0
## Rozrzut w dziesiatych stopnia, najwyzej 25,5.
const SPREAD_SCALE := 10.0
const MAX_AGE := 255
## Tick w rekordzie to 16 mlodszych bitow. Ta wartosc oznacza "brak" albo bardzo dawno.
const TICK_NONE := 0x8000
const TICK_HALF_RANGE := 32768
const TICK_SAFE_RANGE := 30000
const FLAG_SPRINTING := 1
const FLAG_AIMING := 2
const FLAG_ON_GROUND := 4
const FLAG_SLIDING := 8
const SLOT_MASK := 0b11
const DANCE_SHIFT := 2

## Liczniki do narzedzi pomiarowych.
var sent_packets := 0
var received_packets := 0


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_send_snapshots)


func _send_snapshots() -> void:
	if not Net.in_session or not multiplayer.is_server():
		return
	var peers := multiplayer.get_peers()
	if peers.is_empty():
		return
	var records := {}
	var newest := -1
	var nodes := get_tree().get_nodes_in_group(&"players")
	for node in nodes:
		var player := node as Player
		if player.is_queued_for_deletion() or player.snapshot_tick < 0 or not player.info.get("in_match", false):
			continue
		newest = maxi(newest, player.snapshot_tick)
	if newest < 0:
		return
	for node in nodes:
		var player := node as Player
		if player.is_queued_for_deletion() or player.snapshot_tick < 0 or not player.info.get("in_match", false):
			continue
		var net_id: int = player.info.get("net_id", 0)
		if net_id > 0:
			records[player.peer_id] = _encode_record(player, net_id, newest)
	for peer: int in peers:
		if not GameState.players.has(peer):
			continue
		var packet := PackedByteArray()
		packet.resize(HEADER_BYTES)
		packet.encode_u32(0, newest)
		var count := 0
		for id: int in records:
			if id != peer:
				packet.append_array(records[id])
				count += 1
		if count == 0:
			continue
		packet.encode_u8(4, count)
		_receive.rpc_id(peer, packet)
		sent_packets += 1


static func _encode_record(player: Player, net_id: int, header_tick: int) -> PackedByteArray:
	var snap: Dictionary = player.snapshot
	var record := PackedByteArray()
	record.resize(RECORD_BYTES)
	var at: Vector3 = snap.position
	record.encode_u8(0, net_id)
	record.encode_u8(1, clampi(header_tick - player.snapshot_tick, 0, MAX_AGE))
	record.encode_s16(2, _to_i16(at.x * POSITION_SCALE))
	record.encode_s16(4, _to_i16(at.y * POSITION_SCALE))
	record.encode_s16(6, _to_i16(at.z * POSITION_SCALE))
	record.encode_u16(8, roundi(fposmod(snap.yaw, TAU) / TAU * U16_RANGE) % U16_RANGE)
	record.encode_s16(10, _to_i16(snap.pitch * PITCH_SCALE))
	record.encode_u8(12, roundi(clampf(snap.crouch, 0.0, 1.0) * CROUCH_SCALE))
	var flags := 0
	flags |= (FLAG_SPRINTING if snap.sprinting else 0)
	flags |= (FLAG_AIMING if snap.aiming else 0)
	flags |= (FLAG_ON_GROUND if snap.on_ground else 0)
	flags |= (FLAG_SLIDING if snap.sliding else 0)
	record.encode_u8(13, flags)
	record.encode_u8(14, (snap.active_slot & SLOT_MASK) | (snap.dance_id << DANCE_SHIFT))
	record.encode_u16(15, _tick_low(snap.last_fire, header_tick))
	record.encode_u16(17, _tick_low(snap.last_throw, header_tick))
	record.encode_u16(19, _tick_low(snap.prime_tick, header_tick))
	record.encode_u16(21, _tick_low(snap.action_end, header_tick))
	record.encode_u8(23, roundi(clampf(snap.shot_spread * SPREAD_SCALE, 0.0, 255.0)))
	return record


static func _to_i16(value: float) -> int:
	return clampi(roundi(value), -I16_MAX, I16_MAX)


## Mlodsze bity ticku. Ujemny albo odlegly o wiecej niz zakres znaczy "brak".
static func _tick_low(tick: int, header_tick: int) -> int:
	if tick < 0 or absi(tick - header_tick) > TICK_SAFE_RANGE:
		return TICK_NONE
	return tick & 0xFFFF


## Pelny tick z mlodszych bitow, wzgledem naglowka. Moze byc w przeszlosci albo przyszlosci.
static func _tick_full(low: int, header_tick: int, none: int) -> int:
	if low == TICK_NONE:
		return none
	var diff := ((low - (header_tick & 0xFFFF) + TICK_HALF_RANGE) & 0xFFFF) - TICK_HALF_RANGE
	return header_tick + diff


## Odczytuje pakiet. Zwraca liste { peer_id, tick, ... } dla graczy znanych z GameState.
static func decode(packet: PackedByteArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if packet.size() < HEADER_BYTES:
		return result
	var header_tick := packet.decode_u32(0)
	var count := packet.decode_u8(4)
	if packet.size() < HEADER_BYTES + count * RECORD_BYTES:
		return result
	var by_net_id := {}
	for id: int in GameState.players:
		by_net_id[GameState.players[id].get("net_id", 0)] = id
	for index in count:
		var at := HEADER_BYTES + index * RECORD_BYTES
		var peer_id: int = by_net_id.get(packet.decode_u8(at), 0)
		if peer_id == 0:
			continue
		var flags := packet.decode_u8(at + 13)
		var slot_dance := packet.decode_u8(at + 14)
		result.append({
			"peer_id": peer_id,
			"tick": header_tick - packet.decode_u8(at + 1),
			"position": Vector3(packet.decode_s16(at + 2), packet.decode_s16(at + 4), packet.decode_s16(at + 6)) / POSITION_SCALE,
			"yaw": packet.decode_u16(at + 8) / float(U16_RANGE) * TAU,
			"pitch": packet.decode_s16(at + 10) / PITCH_SCALE,
			"crouch": packet.decode_u8(at + 12) / CROUCH_SCALE,
			"sprinting": (flags & FLAG_SPRINTING) != 0,
			"aiming": (flags & FLAG_AIMING) != 0,
			"on_ground": (flags & FLAG_ON_GROUND) != 0,
			"sliding": (flags & FLAG_SLIDING) != 0,
			"active_slot": slot_dance & SLOT_MASK,
			"dance_id": slot_dance >> DANCE_SHIFT,
			"last_fire": _tick_full(packet.decode_u16(at + 15), header_tick, Equipment.NO_FIRE_TICK),
			"last_throw": _tick_full(packet.decode_u16(at + 17), header_tick, Equipment.NO_FIRE_TICK),
			"prime_tick": _tick_full(packet.decode_u16(at + 19), header_tick, -1),
			"action_end": _tick_full(packet.decode_u16(at + 21), header_tick, -1),
			"shot_spread": packet.decode_u8(at + 23) / SPREAD_SCALE,
		})
	return result


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive(packet: PackedByteArray) -> void:
	received_packets += 1
	var nodes := {}
	for node in get_tree().get_nodes_in_group(&"players"):
		if not node.is_queued_for_deletion():
			nodes[(node as Player).peer_id] = node
	for record in decode(packet):
		var player: Player = nodes.get(record.peer_id)
		if player != null and not player.is_local():
			player.apply_remote_snapshot(record)
