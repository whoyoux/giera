class_name PlayerStats
extends Node
## Osobiste statystyki zapisane tylko na tym komputerze, w user://stats.cfg. Nic nie idzie na serwer,
## bo SteamID nie jest sprawdzane, wiec takie wyniki i tak nie bylyby wiarygodne.

const PATH := "user://stats.cfg"
const SECTION := "stats"

var _config := ConfigFile.new()


func _ready() -> void:
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
	]
	var favorite := favorite_weapon()
	lines.append("Ulubiona broń: %s" % (favorite if not favorite.is_empty() else "–"))
	return lines


func _add(key: String, amount := 1) -> void:
	_config.set_value(SECTION, key, value(key) + amount)
	_config.save(PATH)


func _on_hit(details: Dictionary) -> void:
	if not Net.bot_mode.is_empty():
		return
	_add("hits")
	if details.get("headshot", false):
		_add("headshots")
	if details.get("killed", false):
		_add("kills")
		var me := GameState.player_node(multiplayer.get_unique_id())
		var weapon := String(me.equipment.active_stack().get("item", "")) if me != null else ""
		if not weapon.is_empty():
			_config.set_value("weapons", weapon, _config.get_value("weapons", weapon, 0) + 1)
			_config.save(PATH)


func _on_kill(_killer_id: int, victim_id: int) -> void:
	if victim_id == multiplayer.get_unique_id() and Net.bot_mode.is_empty():
		_add("deaths")


func _on_phase() -> void:
	if Match.phase == Match.Phase.RESULTS and Net.bot_mode.is_empty() and GameState.players.has(multiplayer.get_unique_id()):
		_add("rounds")


## Strzaly liczy wlasna postac, gdy tylko powstanie.
func _on_node_added(node: Node) -> void:
	if node is Player and Net.bot_mode.is_empty():
		var player := node as Player
		player.ready.connect(func() -> void:
			if player.is_local():
				player.equipment.fired.connect(func() -> void: _add("shots")), CONNECT_ONE_SHOT)
