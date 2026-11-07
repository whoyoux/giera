extends Node
## Test ukladu HUD jako host, takze bez okna: wlacza naraz wszystko, co moze pokazac sie w czasie gry,
## i sprawdza, czy zadne dwa elementy na siebie nie wchodza i czy kazdy miesci sie na ekranie.
## Robi to dla malej, zwyklej i duzej skali interfejsu. Potem sprawdza ekran wynikow Deathmatchu:
## mala karte na dole, schowany HUD walki i brak strzalow.
## Uzycie: godot --headless --path . -- --settings-path=user://t.cfg --map=forest --tool=res://tools/hud_layout_test.gd
##         Z oknem i --shot-dir=C:/folder zapisuje tez zrzuty.

const PORT := 8163
const LONG_NAMES: Array[String] = ["Bardzo Dlugi Nick Na Steamie", "Zosia Samosia Z Lasu", "Mietek", "Franek Kimono Wielki"]
const SCALES: Array[float] = [Settings.UI_SIZE_MIN, 1.0, Settings.UI_SIZE_MAX]
## Pary, ktore nigdy nie sa widoczne naraz, wiec moga zajmowac to samo miejsce.
const EXCLUSIVE: Array[Array] = [
	["podpowiedz", "uzycie"], ["koniec rundy", "odliczanie"], ["smierc", "ochrona"],
	["smierc", "podpowiedz"], ["smierc", "seria"], ["smierc", "uzycie"], ["smierc", "nazwa przedmiotu"],
]

var _failures := 0
var _hud: Hud
## Bez okna mysz nie jest przechwycona, wiec spust wciskamy po zebraniu wejscia w kazdym ticku.
var _hold_fire := false


func _ready() -> void:
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_hud = get_node("/root/Main/Hud") as Hud
	if get_window().focus_exited.is_connected(_hud._on_focus_lost):
		get_window().focus_exited.disconnect(_hud._on_focus_lost)
	for index in LONG_NAMES.size():
		GameState.server_add_player(index + 2, LONG_NAMES[index])
	await _wait(0.5)
	# Bez ochrony po odrodzeniu, zeby trafienie wlaczylo napis o leczeniu.
	GameState.server_on_shot(1)
	GameState.server_damage(1, 30, 2)
	GameState.players[2].kills = 6
	GameState._broadcast(2)
	Settings.set_value("show_fps", true)
	Settings.set_value("show_net_graph", true)
	_hud.show_tutorial()
	await _wait(0.3)
	# Bez okna ustawienia nie zmieniaja skali, a okno ma dziwny rozmiar, wiec ustawiamy je tutaj.
	get_window().size = Vector2i(1280, 720)
	for scale in SCALES:
		Settings.set_value("ui_size", scale)
		get_tree().root.content_scale_factor = scale
		await _check_layout(scale)
	Settings.set_value("ui_size", 1.0)
	get_tree().root.content_scale_factor = 1.0
	await _check_messages()
	await _check_results()
	get_tree().quit(1 if _failures > 0 else 0)


## Wymusza widocznosc wszystkiego naraz i zatrzymuje HUD, zeby sam nie schowal tego w nastepnej klatce.
func _show_everything() -> Dictionary:
	_set_ui_processing(true)
	for kill in [[2, 3], [4, 5], [2, 4], [5, 1]]:
		GameState.players[kill[1]].death_weapon = { "item": &"deagle", "tier": Rarity.Tier.LEGENDARY }
		GameState.kill_announced.emit(kill[0], kill[1])
	# Cudza seria trafia na liste zabojstw, a wlasna na srodek ekranu.
	_hud._on_streak("ended", 2, 5, 7)
	_hud._on_streak("ended", 1, 2, 7)
	var chat := _hud._chat
	for line in ["siema", "ktos ma apteczke? bo ja juz nie mam zadnej i zaraz padne", "gg"]:
		chat._on_message(3, line)
	await _wait(0.2)
	_set_ui_processing(false)
	_hud._item_name_panel.modulate.a = 1.0
	_hud._item_name.text = "Legendarny Desert Eagle"
	_hud._prompt_panel.visible = true
	_hud._prompt_action.text = "Przytrzymaj, aby otworzyć"
	_hud._prompt_name.text = "skrzynkę"
	_hud._prompt_bar.visible = true
	_hud._use_panel.visible = true
	_hud._use_label.text = "Leczenie…"
	_hud._regen_label.visible = true
	_hud._regen_label.text = "Leczenie przerwane!"
	_hud._death_panel.visible = true
	_hud._death_label.text = _hud._death_cause({ "killer_id": 2, "death_weapon": { "item": &"deagle", "tier": 4 }, "death_headshot": true, "killer_health": 45 }, 1) + "\nWracasz za 3"
	_hud._protection_label.visible = true
	_hud._streak_panel.visible = true
	_hud._streak_panel.modulate.a = 1.0
	var round_panel := _round_panel()
	round_panel._banner.visible = true
	round_panel._clock_panel.visible = true
	round_panel._top_card.visible = true
	_hud._match_panel._big_panel.visible = true
	_hud._match_panel._big_label.text = "Ruszasz za 3"
	await _wait(0.1)
	var tutorials := _hud.find_children("*", "TutorialPanel", true, false)
	return {
		"fps": _hud._fps_panel,
		"wykres sieci": _hud.find_children("*", "NetGraph", true, false)[0],
		"najlepsi": round_panel._top_card,
		"zegar": round_panel._clock_panel,
		"koniec rundy": round_panel._banner,
		"odliczanie": _hud._match_panel._big_panel,
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
		"ochrona": _hud._protection_label,
		"czat": chat._column,
		"samouczek": tutorials[0] if not tutorials.is_empty() else null,
	}


func _check_layout(scale: float) -> void:
	var controls := await _show_everything()
	var screen := _hud.get_viewport().get_visible_rect()
	print("[test] skala %.2f, ekran %s" % [scale, screen.size])
	var rects := {}
	for key: String in controls:
		var control := controls[key] as Control
		if control == null or not control.is_visible_in_tree():
			print("[test]   %s: niewidoczne" % key)
			continue
		var rect := control.get_global_rect()
		rects[key] = rect
		print("[test]   %-17s %s" % [key, rect])
		_check("skala %.2f: %s na ekranie" % [scale, key], screen.grow(1.0).encloses(rect))
	var keys := rects.keys()
	for first in keys.size():
		for second in range(first + 1, keys.size()):
			var a: String = keys[first]
			var b: String = keys[second]
			if _exclusive(a, b):
				continue
			var common := (rects[a] as Rect2).intersection(rects[b])
			_check("skala %.2f: %s i %s osobno" % [scale, a, b], common.get_area() < 4.0)
	await _shot("hud_%d.png" % roundi(scale * 100.0))
	_set_ui_processing(true)


## Napisy, ktore wyskakuja w czasie gry, maja sie miescic w rozsadnej szerokosci.
func _check_messages() -> void:
	await _wait(0.1)
	_hud._on_streak("ended", 1, 2, 7)
	await _wait(0.1)
	var streak_width := _hud._streak_panel.size.x
	print("[test] seria: %s (%.0f px)" % [_hud._streak_label.text, streak_width])
	_check("napis o serii krotki", streak_width < 420.0)
	var feed_width := 0.0
	for row in _hud._feed.get_children():
		feed_width = maxf(feed_width, (row as Control).size.x)
	print("[test] najszerszy wiersz zabojstw: %.0f px" % feed_width)
	_check("wiersz zabojstw krotki", feed_width < 400.0)
	var death := _hud._death_cause({ "killer_id": 2, "death_weapon": { "item": &"deagle", "tier": 4 }, "death_headshot": true, "killer_health": 45 }, 1)
	_check("ekran smierci podaje HP zabojcy", death.contains("45 HP"))


func _check_results() -> void:
	var me := GameState.player_node(1)
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
	await _wait(0.6)
	var panel := _hud._match_panel
	var screen := _hud.get_viewport().get_visible_rect()
	var card := panel._results_card.get_global_rect()
	print("[test] wyniki: %s, karta %s" % [panel._results_title.text, card])
	_check("ekran wynikow", Match.phase == Match.Phase.RESULTS and panel._results_center.visible)
	_check("karta na dole ekranu", card.position.y > screen.size.y * 0.55 and card.end.y <= screen.size.y)
	_check("karta mala", card.size.y < screen.size.y * 0.33 and card.size.x < screen.size.x * 0.5)
	_check("celownik schowany", _hud._crosshair.modulate.a == 0.0)
	_check("pasek przedmiotow schowany", _hud._hotbar.modulate.a == 0.0)
	if not Net.is_headless:
		_check("podium stoi", get_node("/root/Main").find_children("*", "PodiumView", true, false).any(func(view: PodiumView) -> bool: return view.is_shown()))
	_check("bron zablokowana", Match.blocks_items_at(NetworkTime.tick))
	var ammo := me.equipment.active_charges()
	var shots := await _fire_for(me, 0.8)
	print("[test] amunicja %d -> %d, strzaly %d" % [ammo, me.equipment.active_charges(), shots])
	_check("na ekranie wynikow nie da sie strzelac", shots == 0 and me.equipment.active_charges() == ammo)
	await _shot("results.png")


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
