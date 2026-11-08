class_name Teams
extends RefCounted
## Drużyny Team Deathmatchu. Numer drużyny siedzi w stanie gracza ("team") i rozsyła go serwer
## razem ze zdrowiem i wynikami. -1 oznacza gracza, który jeszcze nie wybrał drużyny.

const NONE := -1
const COUNT := 2
## Pomarańcz i błękit różnią daltoniści każdego rodzaju.
const NAMES: Array[String] = ["Kaktusy", "Żuczki"]
const COLORS: Array[Color] = [Color("ff8a1f"), Color("2f8cff")]
## Jaśniejszy odcień na tło karty i plakietki.
const LIGHT: Array[Color] = [Color("ffd9b0"), Color("bcdcff")]
## Tyle graczy mieści drużyna. Razem z drugą to limit meczu.
const MAX_SIZE := 8
## W drużynie może być najwyżej o tyle osób więcej niż w drugiej.
const MAX_DIFFERENCE := 1


static func is_active() -> bool:
	return Match.is_team_mode()


static func name_of(team: int) -> String:
	return NAMES[team] if team >= 0 and team < COUNT else "Bez drużyny"


static func color_of(team: int) -> Color:
	return COLORS[team] if team >= 0 and team < COUNT else UiStyle.INK


static func light_of(team: int) -> Color:
	return LIGHT[team] if team >= 0 and team < COUNT else UiStyle.PAPER


static func team_of(id: int) -> int:
	return GameState.players.get(id, {}).get("team", NONE)


## Kolor nicku gracza: drużyny w Team Deathmatchu, a poza nim podany zwykły kolor.
static func player_color(id: int, fallback: Color) -> Color:
	if not is_active():
		return fallback
	var team := team_of(id)
	return color_of(team) if team != NONE else fallback


## Sojusznik to ktoś inny z tej samej drużyny. Poza Team Deathmatchem nie ma sojuszników.
static func are_allies(first: int, second: int) -> bool:
	if not is_active() or first == second:
		return false
	var team := team_of(first)
	return team != NONE and team == team_of(second)


static func members(team: int) -> Array[int]:
	var ids: Array[int] = []
	for id: int in GameState.players:
		if GameState.players[id].get("team", NONE) == team:
			ids.append(id)
	ids.sort()
	return ids


static func counts(excluded := 0) -> Array[int]:
	var result: Array[int] = []
	result.resize(COUNT)
	for id: int in GameState.players:
		var team: int = GameState.players[id].get("team", NONE)
		if team >= 0 and team < COUNT and id != excluded:
			result[team] += 1
	return result


## Czy gracz może przejść do drużyny. Liczy się stan po przejściu, więc zmiana nie rozbija równowagi.
static func can_join(id: int, team: int) -> bool:
	if team < 0 or team >= COUNT or team_of(id) == team:
		return false
	var sizes := counts(id)
	if sizes[team] >= MAX_SIZE:
		return false
	return sizes[team] + 1 - sizes[1 - team] <= MAX_DIFFERENCE


## Powód, dla którego karta drużyny jest nieklikalna, albo pusty tekst.
static func join_blocker(id: int, team: int) -> String:
	if team_of(id) == team:
		return "To Twoja drużyna"
	var sizes := counts(id)
	if sizes[team] >= MAX_SIZE:
		return "Drużyna jest pełna"
	if not can_join(id, team):
		return "Za dużo graczy, wybierz drugą"
	return ""


## Mniejsza drużyna, a przy równej liczbie ta, która przegrywa. Remis rozstrzyga numer gracza.
static func smaller_team(id: int) -> int:
	var sizes := counts(id)
	if sizes[0] != sizes[1]:
		return 0 if sizes[0] < sizes[1] else 1
	var scores: Array = Match.team_scores
	if scores[0] != scores[1]:
		return 0 if scores[0] < scores[1] else 1
	return absi(id) % COUNT


## Drużyna, której należy się punkt startu. Mapa oznacza je metadaną "team", a bez niej punkty
## dzielą się na dwie połowy wzdłuż osi X, więc każda mapa ma dwie strony.
static func spawn_team(point: Node3D, points: Array[Node]) -> int:
	if point.has_meta(&"team"):
		return int(point.get_meta(&"team"))
	var xs: Array[float] = []
	for other in points:
		xs.append((other as Node3D).global_position.x)
	xs.sort()
	var middle := xs[xs.size() / 2] if not xs.is_empty() else 0.0
	return 0 if point.global_position.x < middle else 1


## Numery punktów startu drużyny. Mapy z punktami tylko do Deathmatchu ("team" = -1) je pomijają.
static func spawn_indices(team: int) -> Array[int]:
	var points := (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"spawn_points")
	var indices: Array[int] = []
	for index in points.size():
		if spawn_team(points[index] as Node3D, points) == team:
			indices.append(index)
	return indices
