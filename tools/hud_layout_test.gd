extends Node
## Test ukladu HUD jako host, takze bez okna. Wlacza naraz wszystko, co moze pokazac sie w czasie gry
## w danym trybie, i dla kilku rozmiarow okna i skal interfejsu sprawdza zasady z docs/UI.md, punkt 6:
## nic nie wychodzi poza ekran ani nie nachodzi na siebie, strefa walki jest wolna, stale elementy
## walki zajmuja najwyzej 20% ekranu, lista zabojstw ma odstep od sasiadow, a samouczek nie nachodzi
## na mapke ani czat. Potem sprawdza kolejke napisow pod zegarem, tabele pod Tab z 32 graczami
## i ekran wynikow: niska karta na dole, schowany HUD walki i brak strzalow.
## Tryb podaje flaga --mode (deathmatch, team_deathmatch, battle_royale), a all_tests.sh uruchamia
## test raz na kazdy tryb. Nowy element HUD-u trzeba dopisac do _show_everything.
## Uzycie: godot --headless --path . -- --settings-path=user://t.cfg --map=desert --mode=team_deathmatch
##         --tool=res://tools/hud_layout_test.gd    Z oknem i --shot-dir=C:/folder zapisuje tez zrzuty.

const PORT := 8163
const LONG_NAMES: Array[String] = ["Bardzo Dlugi Nick Na Steamie", "Zosia Samosia Z Lasu", "Mietek", "Franek Kimono Wielki"]
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]
const SCALES: Array[float] = [Settings.UI_SIZE_MIN, 1.0]
## Strefa walki: srodek ekranu, 40% szerokosci i 50% wysokosci.
const COMBAT_ZONE := Vector2(0.4, 0.5)
## Te napisy moga stac w strefie walki, bo pojawiaja sie, gdy gracz nie walczy.
const ZONE_ALLOWED: Array[String] = ["smierc", "odliczanie"]
## Elementy widoczne przez cala walke. Razem zajmuja najwyzej COMBAT_COVER_LIMIT ekranu.
const PERSISTENT: Array[String] = ["zegar", "najlepsi", "druzyna 0", "druzyna 1", "zdrowie", "amunicja", "przedmioty", "wyrzuc", "mapka", "strefa info"]
const COMBAT_COVER_LIMIT := 0.2
const FEED_GAP := 16.0
const RESULTS_HEIGHT := 0.33
const SCOREBOARD_PLAYERS := 32
const SCOREBOARD_MARGIN := 16.0
## Pary, ktore nigdy nie sa widoczne naraz, wiec moga zajmowac to samo miejsce. Baner, seria i
## odliczanie dziela jedno miejsce z kolejka, wiec test pokazuje tylko serie, a kolejke sprawdza osobno.
const EXCLUSIVE: Array[Array] = [
	# Jedno miejsce nad paskiem przedmiotow.
	["podpowiedz", "uzycie"], ["podpowiedz", "nazwa przedmiotu"], ["uzycie", "nazwa przedmiotu"],
	["smierc", "podpowiedz"], ["smierc", "uzycie"], ["smierc", "nazwa przedmiotu"],
	# Battle Royale: lista gotowych jest tylko w lobby, a ostrzezenie o strefie zastepuje serie.
	["lobby BR", "samouczek"], ["lobby BR", "mapka"], ["poza strefa", "seria"],
	# Widz w Battle Royale nie ma juz paska przedmiotow, zdrowia ani podpowiedzi.
	["ogladasz", "przedmioty"], ["ogladasz", "zdrowie"], ["ogladasz", "wyrzuc"], ["ogladasz", "amunicja"],
	["ogladasz", "nazwa przedmiotu"], ["ogladasz", "podpowiedz"], ["ogladasz", "uzycie"], ["ogladasz", "smierc"],
]

var _failures := 0
var _hud: Hud
## Bez okna mysz nie jest przechwycona, wiec spust wciskamy po zebraniu wejscia w kazdym ticku.
var _hold_fire := false
var _mode := GameMode.Id.DEATHMATCH


func _ready() -> void:
	_mode = GameMode.from_key(Net.args.get("mode", GameMode.key_of(GameMode.Id.DEATHMATCH)))
	_check("host startuje (%s)" % GameMode.key_of(_mode), Net.start_server(PORT, false, _mode).is_empty())
	await _wait(1.5)
	_hud = get_node("/root/Main/Hud") as Hud
	if get_window().focus_exited.is_connected(_hud._on_focus_lost):
		get_window().focus_exited.disconnect(_hud._on_focus_lost)
	for index in LONG_NAMES.size():
		GameState.server_add_player(index + 2, LONG_NAMES[index])
	await _wait(0.5)
	if Match.is_team_mode():
		for id: int in GameState.players:
			GameState.server_set_team(id, id % 2)
		await _wait(1.0)
	# Bez ochrony po odrodzeniu, zeby trafienie wlaczylo napis o leczeniu.
	GameState.server_on_shot(1)
	GameState.server_damage(1, 30, 2)
	GameState.players[2].kills = 6
	GameState._broadcast(2)
	Settings.set_value("show_fps", true)
	Settings.set_value("show_net_graph", true)
	_hud.show_tutorial()
	await _wait(0.3)
	for window in WINDOWS:
		# Bez okna ustawienia nie zmieniaja skali, wiec ustawiamy rozmiar i skale tutaj.
		get_window().size = window
		for scale in SCALES:
			Settings.set_value("ui_size", scale)
			get_tree().root.content_scale_factor = scale
			await _check_layout(window, scale)
	get_window().size = WINDOWS[0]
	Settings.set_value("ui_size", 1.0)
	get_tree().root.content_scale_factor = 1.0
	# Druga proba bez samouczka: w Deathmatchu wraca wtedy karta "Najlepsi".
	for tutorial in _hud.find_children("*", "TutorialPanel", true, false):
		tutorial.free()
	await _check_layout(WINDOWS[0], 1.0, "bez samouczka")
	await _check_messages()
	await _check_top_queue()
	await _check_scoreboard()
	await _check_results()
	get_tree().quit(1 if _failures > 0 else 0)


## Wymusza widocznosc wszystkiego naraz i zatrzymuje HUD, zeby sam nie schowal tego w nastepnej klatce.
func _show_everything() -> Dictionary:
	_set_ui_processing(true)
	for kill in [[2, 3], [4, 5], [2, 4], [5, 1]]:
		GameState.players[kill[1]].death_weapon = { "item": &"deagle", "tier": Rarity.Tier.LEGENDARY }
		GameState.kill_announced.emit(kill[0], kill[1])
	# Cudza seria trafia na liste zabojstw, a wlasna pod zegar.
	_hud._on_streak("ended", 2, 5, 7)
	var chat := _hud._chat
	for line in ["siema", "ktos ma apteczke? bo ja juz nie mam zadnej i zaraz padne", "gg"]:
		chat._on_message(3, line)
	await _wait(0.2)
	_set_ui_processing(false)
	var elimination := Match.is_elimination()
	_hud._item_name_panel.visible = true
	_hud._item_name_panel.modulate.a = 1.0
	_hud._item_name.text = "Legendarny Desert Eagle"
	_hud._prompt_panel.visible = true
	_hud._prompt_action.text = "Otwórz"
	_hud._prompt_name.text = "skrzynkę"
	_hud._fit_prompt()
	_hud._prompt_bar.visible = true
	_hud._use_panel.visible = true
	_hud._use_label.text = "Leczenie…"
	# Ochrona i leczenie to ta sama linia naklejki zdrowia i nie wystepuja naraz.
	_hud._regen_label.visible = true
	_hud._regen_label.text = "Leczenie przerwane!"
	_hud._protection_label.visible = false
	_hud._death_panel.visible = true
	_hud._death_label.text = _hud._death_cause({ "killer_id": 2, "death_weapon": { "item": &"deagle", "tier": 4 }, "death_headshot": true, "killer_health": 45 }, 1) + "\nWracasz za 3"
	UiStyle.fit_width(_hud._death_label, Hud.DEATH_MAX_WIDTH)
	_hud._streak_panel.visible = false
	_hud._on_streak("ended", 1, 2, 7)
	_hud._streak_panel.modulate.a = 1.0
	var round_panel := _round_panel()
	var tutorials := _hud.find_children("*", "TutorialPanel", true, false)
	# Zegar i ranking sa tylko w rundach Deathmatchu i Team Deathmatchu.
	round_panel._banner.visible = false
	round_panel._clock_panel.visible = not elimination
	round_panel._top_card.visible = not elimination and not Match.is_team_mode() and tutorials.is_empty()
	for chip in round_panel._team_chips:
		chip.visible = Match.is_team_mode()
	var panel := _hud._match_panel
	panel._big_panel.visible = false
	panel._mini_map.set_process(false)
	panel._mini_map.visible = Match.is_team_mode() or elimination
	panel._mini_map.modulate.a = 1.0
	panel._info_panel.visible = elimination
	panel._info_label.text = "Żywi: 10  ·  strefa zawęża się jeszcze 0:03"
	panel._outside_panel.visible = false
	panel._roster_card.visible = elimination
	panel._watch_panel.visible = elimination
	panel._watch_label.text = "Oglądasz: Bardzo Dlugi Nick Na Steamie"
	await _wait(0.1)
	var result := {
		"fps": _hud._fps_panel,
		"wykres sieci": _hud.find_children("*", "NetGraph", true, false)[0],
		"najlepsi": round_panel._top_card,
		"zegar": round_panel._clock_panel,
		"seria": _hud._streak_panel,
		"lista zabojstw": _hud._feed,
		"zdrowie": _hud._status_panel,
		"amunicja": _hud._ammo_panel,
		"przedmioty": _hud._hotbar,
		"wyrzuc": _hud._drop_hint,
		"nazwa przedmiotu": _hud._item_name_panel,
		"podpowiedz": _hud._prompt_panel,
		"uzycie": _hud._use_panel,
		"smierc": _hud._death_panel,
		"czat": chat._column,
		"samouczek": tutorials[0] if not tutorials.is_empty() else null,
		"mapka": panel._mini_map,
		"strefa info": panel._info_panel,
		"lobby BR": panel._roster_card,
		"ogladasz": panel._watch_panel,
	}
	for team in round_panel._team_chips.size():
		result["druzyna %d" % team] = round_panel._team_chips[team]
	return result


func _check_layout(window: Vector2i, scale: float, note := "") -> void:
	var controls := await _show_everything()
	var screen := _hud.get_viewport().get_visible_rect()
	var where := "%dx%d skala %.2f%s" % [window.x, window.y, scale, (" " + note) if not note.is_empty() else ""]
	print("[test] %s, ekran %s" % [where, screen.size])
	var rects := {}
	for key: String in controls:
		var control := controls[key] as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		rects[key] = rect
		print("[test]   %-17s %s" % [key, rect])
		_check("%s: %s na ekranie" % [where, key], screen.grow(1.0).encloses(rect))
	var keys := rects.keys()
	for first in keys.size():
		for second in range(first + 1, keys.size()):
			var a: String = keys[first]
			var b: String = keys[second]
			if _exclusive(a, b):
				continue
			var common := (rects[a] as Rect2).intersection(rects[b])
			_check("%s: %s i %s osobno" % [where, a, b], common.get_area() < 4.0)
	# a) Strefa walki.
	var zone := Rect2(screen.size * (Vector2.ONE - COMBAT_ZONE) * 0.5, screen.size * COMBAT_ZONE)
	for key: String in rects:
		if key in ZONE_ALLOWED:
			continue
		var inside := (rects[key] as Rect2).intersection(zone)
		_check("%s: %s poza strefa walki" % [where, key], inside.get_area() < 4.0)
	# b) Stale elementy walki.
	var cover := _coverage(rects, PERSISTENT, screen.size)
	print("[test]   stale elementy walki: %.1f%% ekranu" % (cover * 100.0))
	_check("%s: stale elementy walki najwyzej %d%% ekranu" % [where, roundi(COMBAT_COVER_LIMIT * 100.0)], cover <= COMBAT_COVER_LIMIT)
	# c) Odstep listy zabojstw od sasiadow.
	if rects.has("lista zabojstw"):
		for key: String in rects:
			if key == "lista zabojstw" or _exclusive(key, "lista zabojstw"):
				continue
			var gap := _gap(rects["lista zabojstw"], rects[key])
			if gap < 100.0:
				_check("%s: lista zabojstw %d px od %s" % [where, roundi(gap), key], gap >= FEED_GAP)
	# d) Samouczek nie nachodzi na mapke ani czat (sprawdza to tez petla wyzej, tu jest nazwane wprost).
	if rects.has("samouczek"):
		for key in ["mapka", "czat"]:
			if rects.has(key):
				_check("%s: samouczek nie nachodzi na %s" % [where, key], (rects["samouczek"] as Rect2).intersection(rects[key]).get_area() < 4.0)
	await _shot("hud_%s_%dx%d_%d.png" % [GameMode.key_of(_mode), window.x, window.y, roundi(scale * 100.0)])
	_set_ui_processing(true)


## Najmniejsza odleglosc miedzy dwoma prostokatami albo 0, gdy sie stykaja lub nachodza.
static func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return maxf(dx, dy) if dx == 0.0 or dy == 0.0 else Vector2(dx, dy).length()


## Czesc ekranu zajeta przez podane elementy, liczona na siatce co 8 px.
static func _coverage(rects: Dictionary, keys: Array[String], screen: Vector2) -> float:
	var total := 0
	var covered := 0
	for x in range(0, int(screen.x), 8):
		for y in range(0, int(screen.y), 8):
			total += 1
			for key in keys:
				if rects.has(key) and (rects[key] as Rect2).has_point(Vector2(x, y)):
					covered += 1
					break
	return covered / float(maxi(total, 1))


## Napisy, ktore wyskakuja w czasie gry, maja sie miescic w rozsadnej szerokosci.
func _check_messages() -> void:
	await _wait(0.1)
	_hud._on_streak("ended", 1, 2, 7)
	await _wait(0.1)
	var streak_width := _hud._streak_panel.size.x
	print("[test] seria: %s (%.0f px)" % [_hud._streak_label.text, streak_width])
	_check("napis o serii najwyzej 340 px", streak_width <= 340.0)
	var feed := _hud._feed.get_global_rect()
	print("[test] lista zabojstw: %s" % feed)
	_check("lista zabojstw najwyzej 300 x 150 px", feed.size.x <= 300.0 and feed.size.y <= 150.0)
	var death := _hud._death_cause({ "killer_id": 2, "death_weapon": { "item": &"deagle", "tier": 4 }, "death_headshot": true, "killer_health": 45 }, 1)
	_check("ekran smierci podaje HP zabojcy", death.contains("45 HP"))


## Baner, seria i odliczanie dziela jedno miejsce: nowy napis zastepuje poprzedni, a odliczanie wygrywa.
func _check_top_queue() -> void:
	var round_panel := _round_panel()
	_set_ui_processing(true)
	_hud._on_streak("ended", 1, 2, 7)
	round_panel._show_banner("Twoja drużyna przegrywa", UiStyle.CORAL)
	await _wait(0.05)
	_check("baner zastepuje serie", round_panel._banner.visible and not _hud._streak_panel.visible)
	_hud._on_streak("ended", 1, 2, 7)
	await _wait(0.05)
	_check("seria zastepuje baner", _hud._streak_panel.visible and not round_panel._banner.visible)
	_hud._match_panel._big_panel.visible = true
	_hud._update_top_message()
	_check("odliczanie ma pierwszenstwo", not _hud._streak_panel.visible and not round_panel._banner.visible)
	_hud._on_streak("ended", 1, 2, 7)
	_check("w czasie odliczania nie ma serii", not _hud._streak_panel.visible)
	_hud._match_panel._big_panel.visible = false
	round_panel.hide_banner()


## f) Tabela pod Tab miesci sie na ekranie przy pelnym serwerze.
func _check_scoreboard() -> void:
	for id in range(LONG_NAMES.size() + 2, SCOREBOARD_PLAYERS + 1):
		GameState.server_add_player(id, "Gracz Z Dlugim Nickiem %d" % id)
		if Match.is_team_mode():
			GameState.server_set_team(id, id % 2)
	await _wait(0.5)
	_hud._refresh_scoreboard()
	_hud._score_center.visible = true
	await _wait(0.2)
	var screen := _hud.get_viewport().get_visible_rect()
	var card := _hud._score_card.get_global_rect()
	print("[test] tabela z %d graczami: %s" % [GameState.players.size(), card])
	_check("tabela z %d graczami miesci sie na ekranie" % GameState.players.size(), screen.grow(-SCOREBOARD_MARGIN).encloses(card))
	await _shot("scoreboard_%s.png" % GameMode.key_of(_mode))
	_hud._score_center.visible = false


func _check_results() -> void:
	var elimination := Match.is_elimination()
	var me := GameState.player_node(1)
	if not elimination:
		GameState.server_give_item(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON)
		me.input.select_slot(0)
		await _wait(0.6)
		NetworkTime.before_tick_loop.connect(func() -> void:
			if _hold_fire:
				me.input.use_primary = true)
		# Proba kontrolna: w trakcie rundy ten sam spust strzela.
		var live_shots := await _fire_for(me, 0.5)
		_check("w trakcie rundy spust strzela", live_shots > 0)
		await _wait(0.5)
		Match._finish_round(Match.standings())
	else:
		var results := []
		var place := 1
		for id: int in GameState.players:
			results.append({ "id": id, "name": GameState.players[id].name, "kills": place % 4, "place": place })
			place += 1
		Match.results = results
		Match._enter_phase(Match.Phase.RESULTS, NetworkTime.tick + NetworkTime.seconds_to_ticks(Match.RESULTS_SECONDS))
	await _wait(0.6)
	var panel := _hud._match_panel
	var screen := _hud.get_viewport().get_visible_rect()
	var card := panel._results_card.get_global_rect()
	print("[test] wyniki: %s, karta %s" % [panel._results_title.text, card])
	_check("ekran wynikow", Match.phase == Match.Phase.RESULTS and panel._results_center.visible)
	_check("karta na dole ekranu", card.position.y > screen.size.y * 0.55 and card.end.y <= screen.size.y)
	# e) Karta wynikow w kazdym trybie.
	_check("karta najwyzej %d%% wysokosci ekranu (%.1f%%)" % [roundi(RESULTS_HEIGHT * 100.0), card.size.y * 100.0 / screen.size.y], card.size.y <= screen.size.y * RESULTS_HEIGHT)
	_check("celownik schowany", _hud._crosshair.modulate.a == 0.0)
	_check("pasek przedmiotow schowany", _hud._hotbar.modulate.a == 0.0)
	_check("lista zabojstw schowana", _hud._feed.modulate.a == 0.0)
	if elimination:
		await _shot("results_%s.png" % GameMode.key_of(_mode))
		return
	if not Net.is_headless:
		_check("podium stoi", get_node("/root/Main").find_children("*", "PodiumView", true, false).any(func(view: PodiumView) -> bool: return view.is_shown()))
	_check("bron zablokowana", Match.blocks_items_at(NetworkTime.tick))
	var ammo := me.equipment.active_charges()
	var shots := await _fire_for(me, 0.8)
	print("[test] amunicja %d -> %d, strzaly %d" % [ammo, me.equipment.active_charges(), shots])
	_check("na ekranie wynikow nie da sie strzelac", shots == 0 and me.equipment.active_charges() == ammo)
	await _shot("results_%s.png" % GameMode.key_of(_mode))


func _fire_for(me: Player, seconds: float) -> int:
	var shots := [0]
	var count := func() -> void: shots[0] += 1
	me.equipment.fired.connect(count)
	_hold_fire = true
	await _wait(seconds)
	_hold_fire = false
	me.equipment.fired.disconnect(count)
	await _wait(0.1)
	return shots[0]


func _exclusive(a: String, b: String) -> bool:
	return EXCLUSIVE.any(func(pair: Array) -> bool: return (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a))


func _round_panel() -> RoundPanel:
	return _hud.find_children("*", "RoundPanel", true, false)[0] as RoundPanel


func _set_ui_processing(on: bool) -> void:
	_hud.set_process(on)
	_round_panel().set_process(on and not Net.is_headless)
	_hud._match_panel.set_process(on and not Net.is_headless)


func _shot(file: String) -> void:
	var dir: String = Net.args.get("shot-dir", "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(file))


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[test] %s: %s" % [label, "OK" if ok else "BLAD"])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
