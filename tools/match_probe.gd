extends Node
## Narzedzie testowe Battle Royale: klika Gotowe o podanych porach i zapisuje przebieg meczu.
## Opcje w sekundach od startu: --ready-at, --unready-at, --ready-again-at.

var _elapsed := 0.0
var _plan := []
var _freeze_start := Vector3.INF
var _freeze_checked := false


func _ready() -> void:
	for key: String in ["ready-at", "unready-at", "ready-again-at"]:
		if Net.args.has(key):
			_plan.append(float(Net.args[key]))
	Match.phase_changed.connect(func() -> void: print("[etap] %s" % Match.Phase.find_key(Match.phase)))


func _process(delta: float) -> void:
	_elapsed += delta
	if not _plan.is_empty() and _elapsed >= _plan[0]:
		_plan.pop_front()
		Match.toggle_ready()
	_check_freeze()


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
