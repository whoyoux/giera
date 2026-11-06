extends Node
## Narzedzie testowe Battle Royale: klika Gotowe o podanych porach i zapisuje przebieg meczu.
## Opcje w sekundach od startu: --ready-at, --unready-at, --ready-again-at.
## --auto-ready klika Gotowe przy kazdym powrocie do lobby. --quit-after-live=2 wychodzi z gry
## w trakcie meczu. --kill-all-at=3 na serwerze zabija wszystkich w jednej klatce, co jest remisem.
## --kill-name=A,B --kill-name-at=4 na serwerze zabija tych graczy w jednej klatce, w kazdym meczu.
## --quit-in-results wychodzi z gry, gdy tylko zobaczy wyniki meczu.

const RESET_REPORT_DELAY := 2.0

var _elapsed := 0.0
var _plan := []
var _freeze_start := Vector3.INF
var _freeze_checked := false
var _live_time := 0.0
var _matches := 0
var _killed_in_match := false


func _ready() -> void:
	for key: String in ["ready-at", "unready-at", "ready-again-at"]:
		if Net.args.has(key):
			_plan.append(float(Net.args[key]))
	Match.phase_changed.connect(_on_phase_changed)
	GameState.kill_announced.connect(_on_kill)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _plan.is_empty() and _elapsed >= _plan[0]:
		_plan.pop_front()
		Match.toggle_ready()
	_check_freeze()
	_update_scenarios()


func _update_scenarios() -> void:
	var me: Dictionary = GameState.players.get(multiplayer.get_unique_id(), {})
	if Net.args.has("auto-ready") and Match.phase == Match.Phase.LOBBY and not me.is_empty() and not me.ready and Engine.get_process_frames() % 60 == 0:
		Match.toggle_ready()
	if Net.args.has("quit-in-results") and Match.phase == Match.Phase.RESULTS:
		get_tree().quit()
	if Match.phase != Match.Phase.LIVE:
		_live_time = 0.0
		_killed_in_match = false
		return
	_live_time += get_process_delta_time()
	if Net.args.has("quit-after-live") and _live_time >= float(Net.args["quit-after-live"]):
		get_tree().quit()
	if Net.args.has("kill-name-at") and not _killed_in_match and _live_time >= float(Net.args["kill-name-at"]):
		_killed_in_match = true
		var names: PackedStringArray = str(Net.args.get("kill-name", "")).split(",")
		for id: int in GameState.players.keys():
			if names.has(GameState.display_name(id)):
				GameState.server_damage(id, GameState.MAX_HEALTH, id)
	if Net.args.has("kill-all-at") and _live_time >= float(Net.args["kill-all-at"]):
		Net.args.erase("kill-all-at")
		for id: int in GameState.players.keys():
			GameState.server_damage(id, GameState.MAX_HEALTH, id)


func _on_kill(killer_id: int, victim_id: int) -> void:
	var weapon: Dictionary = GameState.players.get(victim_id, {}).get("death_weapon", {})
	print("[zabojstwo] %s -> %s: %s" % [GameState.display_name(killer_id), GameState.display_name(victim_id), ItemStack.display_name_of(weapon)])


func _on_phase_changed() -> void:
	print("[etap] %s" % Match.Phase.find_key(Match.phase))
	if Match.phase == Match.Phase.RESULTS:
		print("[wyniki] %s" % str(Match.results.map(func(entry: Dictionary) -> String: return "%d:%s:%d" % [entry.place, entry.name, entry.kills])))
	elif Match.phase == Match.Phase.LOBBY and _matches > 0:
		_report_clean_state.call_deferred()
	# Deathmatch tez ma etap LIVE, ale nie ma meczow ani strefy.
	if Match.phase == Match.Phase.LIVE and Match.zone != null:
		_matches += 1
		var state := Match.zone.state_at(10000.0)
		print("[strefa] ziarno=%d koniec=%s" % [Match.zone_seed, str(state.center)])


## Po powrocie do lobby nic z meczu nie moze zostac. Czekamy na dotarcie stanu graczy.
func _report_clean_state() -> void:
	await get_tree().create_timer(RESET_REPORT_DELAY).timeout
	var open := 0
	for id: int in Chests.chests:
		open += 1 if Chests.chests[id].open else 0
	var dirty := 0
	for id: int in GameState.players:
		var info: Dictionary = GameState.players[id]
		var kept := 0
		for stack: Dictionary in info.slots:
			kept += 0 if ItemStack.is_empty(stack) else 1
		# Reset daje od nowa tylko to, co wynika z flag testowych.
		var expected := 3 if Net.args.has("debug-weapons") else 0
		if kept != expected or info.health != GameState.MAX_HEALTH or not info.alive or not info.in_match or info.kills != 0 or info.deaths != 0 or info.place != 0 or info.spawn_index != -1:
			dirty += 1
	print("[reset] mecz=%d przedmioty=%d granaty=%d otwarte=%d brudni=%d graczy=%d" % [_matches, WorldItems.items.size(), Grenades.flying_count(), open, dirty, GameState.players.size()])


## Postac ma stac w miejscu przez cale unieruchomienie, a konczyc je na wlasnym punkcie.
func _check_freeze() -> void:
	var player := GameState.player_node(multiplayer.get_unique_id())
	if player == null or Match.freeze_end_tick < 0 or _freeze_checked:
		return
	var margin := NetworkTime.seconds_to_ticks(0.6)
	if _freeze_start == Vector3.INF and NetworkTime.tick >= Match.freeze_from_tick + margin:
		_freeze_start = player.position
	elif _freeze_start != Vector3.INF and NetworkTime.tick >= Match.freeze_end_tick - 2:
		_freeze_checked = true
		var moved := Vector2(player.position.x - _freeze_start.x, player.position.z - _freeze_start.z).length()
		print("[freeze] ruch=%.2f punkt=%d x=%.1f z=%.1f" % [moved, player.info.spawn_index, player.position.x, player.position.z])
