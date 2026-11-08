class_name PlayerStats
extends Node
## Osobiste statystyki zapisane tylko na tym komputerze, w user://stats.cfg. Nic nie idzie na serwer,
## bo SteamID nie jest sprawdzane, wiec takie wyniki i tak nie bylyby wiarygodne.

signal round_summary_ready

const PATH := "user://stats.cfg"
const SECTION := "stats"
const GROUP := &"player_stats"

## Liczniki biezacej rundy albo meczu, zerowane na jej poczatku. Tylko w pamieci.
var round_stats := {}
## Wynik ostatniej skonczonej rundy i tej przed nia, do strzalek porownania.
var last_round := {}
var previous_round := {}

var _config := ConfigFile.new()
var _counting := false


func _ready() -> void:
	add_to_group(GROUP)
	round_stats = _empty_round()
	Net.session_ended.connect(func(_reason: String) -> void:
		round_stats = _empty_round()
		last_round = {}
		previous_round = {})
	_config.load(PATH)
	GameState.hit_details.connect(_on_hit)
	GameState.kill_announced.connect(_on_kill)
	Match.phase_changed.connect(_on_phase)
	get_tree().node_added.connect(_on_node_added)


## Usuwa wszystkie statystyki z tego komputera.
func reset() -> void:
	_config.clear()
	_config.save(PATH)


func value(key: String) -> int:
	return _config.get_value(SECTION, key, 0)


## Bron z najwieksza liczba zabojstw albo pusty tekst.
func favorite_weapon() -> String:
	var best := ""
	var best_kills := 0
	for key in _config.get_section_keys("weapons") if _config.has_section("weapons") else PackedStringArray():
		var kills: int = _config.get_value("weapons", key, 0)
		if kills > best_kills:
			best = key
			best_kills = kills
	var definition := ItemRegistry.get_definition(StringName(best)) if not best.is_empty() else null
	return definition.display_name if definition != null else ""


func accuracy() -> float:
	return float(value("hits")) / value("shots") if value("shots") > 0 else 0.0


func summary() -> Array[String]:
	var lines: Array[String] = [
		"Zabójstwa: %d" % value("kills"),
		"Śmierci: %d" % value("deaths"),
		"Rozegrane rundy i mecze: %d" % value("rounds"),
		"Celność: %d%%" % roundi(accuracy() * 100.0),
		"Trafienia w głowę: %d" % value("headshots"),
		"Zadane obrażenia: %d" % value("damage"),
		"Najdłuższe zabójstwo: %d m" % roundi(float(_config.get_value(SECTION, "longest", 0.0))),
	]
	var favorite := favorite_weapon()
	lines.append("Ulubiona broń: %s" % (favorite if not favorite.is_empty() else "–"))
	return lines


func _add(key: String, amount := 1) -> void:
	_config.set_value(SECTION, key, value(key) + amount)
	_config.save(PATH)
	if round_stats.has(key):
		round_stats[key] += amount


func _empty_round() -> Dictionary:
	return { "kills": 0, "deaths": 0, "shots": 0, "hits": 0, "headshots": 0, "damage": 0, "longest": 0.0, "weapons": {}, "fired": {} }


## Celnosc rundy w procentach albo -1, gdy gracz nie strzelal.
static func round_accuracy(stats: Dictionary) -> int:
	return roundi(100.0 * stats.hits / stats.shots) if stats.get("shots", 0) > 0 else -1


## Ulubiona bron rundy: najwiecej zabojstw, a bez zabojstw najwiecej strzalow. Pusty tekst, gdy nic.
static func round_favorite(stats: Dictionary) -> String:
	var best := ""
	var best_score := 0
	for source: String in ["weapons", "fired"]:
		for item: String in stats.get(source, {}):
			var score: int = stats[source][item]
			if score > best_score:
				best = item
				best_score = score
		if not best.is_empty():
			break
	var definition := ItemRegistry.get_definition(StringName(best)) if not best.is_empty() else null
	return definition.display_name if definition != null else ""


func _on_hit(details: Dictionary) -> void:
	if not Net.bot_mode.is_empty():
		return
	_add("hits")
	_add("damage", int(details.get("amount", 0)))
	if details.get("headshot", false):
		_add("headshots")
	if details.get("killed", false):
		_add("kills")
		var me := GameState.player_node(multiplayer.get_unique_id())
		var weapon := String(details.get("item", ""))
		if weapon.is_empty() and me != null:
			weapon = String(me.equipment.active_stack().get("item", ""))
		if not weapon.is_empty():
			_config.set_value("weapons", weapon, _config.get_value("weapons", weapon, 0) + 1)
			_config.save(PATH)
			round_stats.weapons[weapon] = round_stats.weapons.get(weapon, 0) + 1
		_remember_distance(me, details)


## Najdluzsze zabojstwo w metrach: od oczu gracza do miejsca trafienia albo do ofiary.
func _remember_distance(me: Player, details: Dictionary) -> void:
	if me == null:
		return
	var at: Vector3 = details.get("position", Vector3.INF)
	if not at.is_finite():
		var victim := GameState.player_node(details.get("victim", 0))
		if victim == null:
			return
		at = victim.position + Vector3.UP
	var distance := me.eye_position().distance_to(at)
	round_stats.longest = maxf(round_stats.longest, distance)
	if distance > float(_config.get_value(SECTION, "longest", 0.0)):
		_config.set_value(SECTION, "longest", snappedf(distance, 0.1))
		_config.save(PATH)


func _on_kill(_killer_id: int, victim_id: int) -> void:
	if victim_id == multiplayer.get_unique_id() and Net.bot_mode.is_empty():
		_add("deaths")


## Koniec rundy zamraza jej wynik, a kazdy inny etap po wynikach zaczyna liczenie od nowa.
func _on_phase() -> void:
	if Match.phase == Match.Phase.RESULTS and Net.bot_mode.is_empty() and GameState.players.has(multiplayer.get_unique_id()):
		if _counting:
			_counting = false
			_add("rounds")
			previous_round = last_round
			last_round = round_stats.duplicate(true)
			round_summary_ready.emit()
	elif Match.phase != Match.Phase.RESULTS and not _counting:
		_counting = true
		round_stats = _empty_round()


## Strzaly liczy wlasna postac, gdy tylko powstanie.
func _on_node_added(node: Node) -> void:
	if node is Player and Net.bot_mode.is_empty():
		var player := node as Player
		player.ready.connect(func() -> void:
			if player.is_local():
				player.equipment.fired.connect(func() -> void:
					_add("shots")
					var item := String(player.equipment.active_stack().get("item", ""))
					if not item.is_empty():
						round_stats.fired[item] = round_stats.fired.get(item, 0) + 1), CONNECT_ONE_SHOT)
