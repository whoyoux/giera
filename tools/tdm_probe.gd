extends Node
## Narzedzie testowe Team Deathmatchu na serwerze: zapisuje zabojstwa z druzynami, co kilka sekund
## sprawdza, ze sojusznik nie zadaje obrazen, a na koniec rundy porownuje wynik druzyn z zabojstwami.
## Wpisy [tdm] czyta tools/tdm_net_test.sh.

const FRIENDLY_CHECK_SECONDS := 3.0

var _timer := 0.0
var _seen_phase := -1


func _ready() -> void:
	GameState.kill_announced.connect(_on_kill)
	Match.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if not Net.in_session or not multiplayer.is_server() or Match.phase != Match.Phase.LIVE:
		return
	_timer += delta
	if _timer < FRIENDLY_CHECK_SECONDS:
		return
	_timer = 0.0
	_check_friendly_fire()
	print("[tdm] druzyny %s" % str(Teams.counts()))


## Strzal sojusznika podany wprost do serwera: zdrowie celu nie moze sie zmienic.
func _check_friendly_fire() -> void:
	for team in Teams.COUNT:
		var members := Teams.members(team)
		if members.size() < 2:
			continue
		var attacker: int = members[0]
		var victim: int = members[1]
		var info: Dictionary = GameState.players[victim]
		if not info.alive:
			continue
		var before: int = info.health
		GameState.server_damage(victim, 40, attacker, Vector3.INF, { "item": &"blaster", "tier": 0 })
		print("[tdm] ogien przyjacielski %s" % ("zablokowany" if info.health == before else "ZADAL OBRAZENIA"))


func _on_kill(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server():
		return
	var killer := Teams.team_of(killer_id)
	var victim := Teams.team_of(victim_id)
	var kind := "wrog" if killer != victim else ("sam" if killer_id == victim_id else "SOJUSZNIK")
	print("[tdm] zabojstwo %s(%d) -> %s(%d) %s" % [GameState.display_name(killer_id), killer, GameState.display_name(victim_id), victim, kind])


func _on_phase_changed() -> void:
	if Match.phase == _seen_phase or not multiplayer.is_server():
		return
	_seen_phase = Match.phase
	if Match.phase != Match.Phase.RESULTS:
		return
	var kills := [0, 0]
	for entry: Dictionary in Match.results:
		if entry.get("team", -1) >= 0:
			kills[entry.team] += entry.kills
	var winner := Match.winning_team
	print("[tdm] koniec rundy wynik %s zabojstwa %s zwyciezca %d" % [str(Match.team_scores), str(kills), winner])
	var top: Dictionary = Match.results[0] if not Match.results.is_empty() else {}
	print("[tdm] podium zaczyna %s z druzyny %d" % [top.get("name", "-"), top.get("team", -1)])
