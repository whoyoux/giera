extends Node
## Pomiar HUD jako host: wlacza naraz wszystko, co moze sie pokazac, i dla kilku rozmiarow okna wypisuje
## prostokaty elementow, nakladanie sie i jaka czesc ekranu oraz jego srodka (50% x 50%) zaslaniaja.
## Uzycie: godot --path . --resolution 1280x720 -- --settings-path=user://hud_probe.cfg --map=desert
##         --mode=team_deathmatch --tool=res://tools/hud_sizes_probe.gd --shot-dir=C:/folder

const PORT := 8171
const LONG_NAMES: Array[String] = ["Bardzo Dlugi Nick Na Steamie", "Zosia Samosia Z Lasu", "Mietek", "Franek Kimono Wielki"]
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1280, 800), Vector2i(1280, 1024), Vector2i(1720, 720), Vector2i(960, 540)]
const EXCLUSIVE: Array[Array] = [
	["podpowiedz", "uzycie"], ["koniec rundy", "odliczanie"], ["smierc", "ochrona"],
	["smierc", "podpowiedz"], ["smierc", "seria"], ["smierc", "uzycie"], ["smierc", "nazwa przedmiotu"],
	["strefa info", "zegar"], ["strefa info", "druzyna 0"], ["strefa info", "druzyna 1"], ["poza strefa", "zegar"], ["poza strefa", "koniec rundy"], ["poza strefa", "odliczanie"],
	["lobby BR", "samouczek"], ["lobby BR", "mapka"], ["strefa info", "koniec rundy"], ["poza strefa", "druzyna 0"], ["poza strefa", "druzyna 1"],
	# Baner, seria i odliczanie dziela jedno miejsce pod zegarem: nowy napis zastepuje poprzedni.
	["koniec rundy", "seria"], ["odliczanie", "seria"], ["poza strefa", "seria"],
	# Podpowiedz, nazwa przedmiotu i napis o smierci tez maja jedno miejsce nad paskiem przedmiotow.
	["nazwa przedmiotu", "podpowiedz"], ["nazwa przedmiotu", "uzycie"],
]
## Te elementy moga stac w strefie walki, bo pojawiaja sie, gdy gracz nie walczy: martwy albo
## unieruchomiony na starcie rundy.
const ZONE_ALLOWED: Array[String] = ["smierc", "odliczanie"]
## Strefa walki: srodek ekranu, 40% szerokosci i 50% wysokosci. Wolno w niej byc tylko celownikowi,
## lunecie, wskaznikowi obrazen, liczbom obrazen, kolu tancow i oknom modalnym (docs/UI.md, punkt 6).
const COMBAT_ZONE := Vector2(0.4, 0.5)

var _hud: Hud


func _ready() -> void:
	var mode := GameMode.from_key(Net.args.get("mode", "deathmatch"))
	Net.start_server(PORT, false, mode)
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
	GameState.server_on_shot(1)
	GameState.server_damage(1, 30, 2)
	Settings.set_value("show_fps", true)
	Settings.set_value("show_net_graph", Net.args.has("graph"))
	_hud.show_tutorial()
	await _wait(0.3)
	for window in WINDOWS:
		get_window().size = window
		await _wait(0.4)
		await _measure(window)
	get_tree().quit()


func _show_everything() -> Dictionary:
	_set_ui_processing(true)
	for kill in [[2, 3], [4, 5], [2, 4], [5, 1], [3, 2]]:
		GameState.players[kill[1]].death_weapon = { "item": &"deagle", "tier": Rarity.Tier.LEGENDARY }
		GameState.kill_announced.emit(kill[0], kill[1])
	_hud._on_streak("ended", 1, 2, 7)
	var chat := _hud._chat
	for line in ["siema", "ktos ma apteczke? bo ja juz nie mam zadnej i zaraz padne", "gg"]:
		chat._on_message(3, line)
	await _wait(0.2)
	_set_ui_processing(false)
	_hud._item_name_panel.modulate.a = 1.0
	_hud._item_name.text = "Legendarny Desert Eagle"
	_hud._prompt_panel.visible = true
	_hud._prompt_action.text = "Otwórz"
	_hud._prompt_name.text = "skrzynkę"
	_hud._fit_prompt()
	_hud._prompt_bar.visible = true
	_hud._regen_label.visible = true
	_hud._regen_label.text = "Leczenie przerwane!"
	_hud._death_panel.visible = true
	_hud._death_label.text = _hud._death_cause({ "killer_id": 2, "death_weapon": { "item": &"deagle", "tier": 4 }, "death_headshot": true, "killer_health": 45 }, 1) + "\nWracasz za 3"
	UiStyle.fit_width(_hud._death_label, Hud.DEATH_MAX_WIDTH)
	# Ochrona i leczenie to ta sama linia naklejki zdrowia i nie wystepuja naraz: tuz po odrodzeniu
	# zdrowie jest pelne. Sonda pokazuje leczenie.
	_hud._protection_label.visible = false
	var tutorials := _hud.find_children("*", "TutorialPanel", true, false)
	_hud._streak_panel.visible = true
	_hud._streak_panel.modulate.a = 1.0
	var round_panel := _hud.find_children("*", "RoundPanel", true, false)[0] as RoundPanel
	round_panel._banner.visible = true
	round_panel._banner_label.text = "Twoja drużyna przegrywa"
	round_panel._clock_panel.visible = true
	# "Najlepsi" znika w Team Deathmatchu i na czas samouczka, ktory stoi w tym samym miejscu.
	round_panel._top_card.visible = not Match.is_team_mode() and tutorials.is_empty()
	var match_panel := _hud._match_panel
	match_panel._big_panel.visible = true
	match_panel._big_label.text = "Ruszasz za 3"
	match_panel._info_panel.visible = true
	match_panel._info_label.text = "Żywi: 10  ·  strefa zawęża się jeszcze 0:03"
	match_panel._outside_panel.visible = true
	var maps := match_panel.find_children("*", "ZoneMap", true, false)
	await _wait(0.1)
	var result := {
		"fps": _hud._fps_panel,
		"najlepsi": round_panel._top_card,
		"zegar": round_panel._clock_panel,
		"koniec rundy": round_panel._banner,
		"odliczanie": match_panel._big_panel,
		"strefa info": match_panel._info_panel,
		"poza strefa": match_panel._outside_panel,
		"seria": _hud._streak_panel,
		"lista zabojstw": _hud._feed,
		"zdrowie": _hud._status_panel,
		"amunicja": _hud._ammo_panel,
		"przedmioty": _hud._hotbar,
		"wyrzuc": _hud._drop_hint,
		"nazwa przedmiotu": _hud._item_name_panel,
		"podpowiedz": _hud._prompt_panel,
		"smierc": _hud._death_panel,
		"czat": chat._column,
		"mapka": maps[0],
		"lobby BR": match_panel._roster_card,
		"samouczek": tutorials[0] if not tutorials.is_empty() else null,
	}
	if Match.is_team_mode():
		for team in round_panel._team_chips.size():
			round_panel._team_chips[team].visible = true
			result["druzyna %d" % team] = round_panel._team_chips[team]
	return result


func _measure(window: Vector2i) -> void:
	var controls := await _show_everything()
	await _wait(0.1)
	var screen := _hud.get_viewport().get_visible_rect()
	print("[hud] okno %s -> ekran logiczny %s" % [window, screen.size])
	var rects := {}
	for key: String in controls:
		var control := controls[key] as Control
		if control == null:
			continue
		var rect := control.get_global_rect()
		rects[key] = rect
		var off := "" if screen.grow(1.0).encloses(rect) else "  POZA EKRANEM"
		print("[hud]   %-17s x %4d..%4d  y %4d..%4d%s%s" % [key, rect.position.x, rect.end.x, rect.position.y, rect.end.y, off, "" if control.is_visible_in_tree() else "  (ukryte)"])
	var zone := Rect2(screen.size * (Vector2.ONE - COMBAT_ZONE) * 0.5, screen.size * COMBAT_ZONE)
	for key: String in rects:
		var inside := (rects[key] as Rect2).intersection(zone)
		if inside.get_area() >= 4.0 and controls[key].is_visible_in_tree() and not key in ZONE_ALLOWED:
			print("[hud]   STREFA WALKI: %s (%d x %d px)" % [key, inside.size.x, inside.size.y])
	var keys := rects.keys()
	for first in keys.size():
		for second in range(first + 1, keys.size()):
			var a: String = keys[first]
			var b: String = keys[second]
			if _exclusive(a, b) or not controls[a].is_visible_in_tree() or not controls[b].is_visible_in_tree():
				continue
			var common := (rects[a] as Rect2).intersection(rects[b])
			if common.get_area() >= 4.0:
				print("[hud]   NAKLADANIE: %s + %s (%d x %d px)" % [a, b, common.size.x, common.size.y])
	# Pokrycie ekranu: caly ekran i srodek (50% x 50%), bez wyskakujacego napisu o smierci.
	var total := 0
	var covered := 0
	var mid_total := 0
	var mid_covered := 0
	var middle := Rect2(screen.size * 0.25, screen.size * 0.5)
	for x in range(0, int(screen.size.x), 8):
		for y in range(0, int(screen.size.y), 8):
			var point := Vector2(x, y)
			var hit := false
			for key: String in rects:
				if key in ["smierc", "lobby BR", "samouczek", "odliczanie", "poza strefa", "strefa info"]:
					continue
				# Ukrytego elementu nie ma na ekranie. "Najlepsi" w Deathmatchu znika tylko na czas samouczka.
				if not controls[key].is_visible_in_tree() and (key != "najlepsi" or Match.is_team_mode()):
					continue
				if (rects[key] as Rect2).has_point(point):
					hit = true
					break
			total += 1
			covered += 1 if hit else 0
			if middle.has_point(point):
				mid_total += 1
				mid_covered += 1 if hit else 0
	print("[hud]   pokrycie ekranu %.1f%%, srodka %.1f%%" % [covered * 100.0 / total, mid_covered * 100.0 / mid_total])
	var dir: String = Net.args.get("shot-dir", "")
	if not dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("hud_%s_%dx%d.png" % [GameMode.key_of(Match.mode), window.x, window.y]))
	_set_ui_processing(true)


func _exclusive(a: String, b: String) -> bool:
	return EXCLUSIVE.any(func(pair: Array) -> bool: return (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a))


func _set_ui_processing(on: bool) -> void:
	_hud.set_process(on)
	(_hud.find_children("*", "RoundPanel", true, false)[0] as RoundPanel).set_process(on and not Net.is_headless)
	_hud._match_panel.set_process(on and not Net.is_headless)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
