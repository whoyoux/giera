class_name MatchPanel
extends Control
## Interfejs etapow Battle Royale: lobby, odliczanie, licznik zywych, strefa, widz i wyniki.

const ROSTER_NAME_LENGTH := 20
const ROSTER_WIDTH := 300.0
const ZONE_TINT := Color(0.45, 0.33, 1.0)
const ZONE_TINT_ALPHA := 0.2
const ZONE_TINT_PULSE := 0.07
const ZONE_HUM_VOLUME := -8.0
## Mapka stoi nad naklejka z amunicja.
const MAP_MARGIN_RIGHT := 28.0
const MAP_MARGIN_BOTTOM := 136.0
const BIG_MAP_SIDE := 600.0
## Prawa kolumna zaczyna sie pod lista zabojstw, ktora ma najwyzej piec wierszy.
const SIDE_COLUMN_TOP := 290.0
## Karta wynikow w kazdym trybie to jeden niski panel przy dolnej krawedzi, najwyzej 33% wysokosci
## ekranu, zeby nie zaslaniac postaci na podium ani ogladanego zwyciezcy Battle Royale:
## po lewej wynik, po prawej glosowanie na nastepna mape (tylko Deathmatch).
const PODIUM_SUMMARY_WIDTH := 260.0
## Team Deathmatch pokazuje obie druzyny obok siebie, wiec jego czesc z wynikiem jest szersza.
const TEAM_SUMMARY_WIDTH := 400.0
## Battle Royale nie ma glosowania, wiec cala karta to wynik.
const ELIMINATION_SUMMARY_WIDTH := 380.0
## Tylu najlepszych z kazdej druzyny miesci sie w karcie. Reszta jest pod Tab.
const TEAM_ROWS := 3
## W Battle Royale karta pokazuje tylu najlepszych i wlasne miejsce. Reszta jest pod Tab.
const ELIMINATION_ROWS := 3
## Nagrody pod wlasnym wynikiem na podium Deathmatchu. Reszta jest pod Tab.
const AWARD_ROWS := 2
const PODIUM_CARD_BOTTOM := 24.0
const RESULTS_TITLE_SIZE := 28
## Odliczanie stoi pod zegarem rundy Deathmatchu, ktory zajmuje gore ekranu. To samo miejsce dziela
## baner rundy i napis o serii, a odliczanie ma pierwszenstwo.
const BIG_LABEL_TOP := 110.0
const VOTE_THUMB_SIZE := Vector2(144.0, 72.0)
const VOTE_CARD_FILL := Color("f3ecdd")
const VOTE_POP_SCALE := 1.06
## Margines w StyleBoxFlat liczy sie od zewnetrznej krawedzi, wiec obejmuje obwodke. Wnetrze karty
## ma 12 px oddechu od obwodki, a panel 16 (docs/UI.md).
const VOTE_CARD_BORDER := 5
const VOTE_CARD_PADDING := 12
const RESULTS_BORDER := 6
const SECTION_GAP := 24
const DIVIDER_COLOR := Color(0.18, 0.16, 0.24, 0.12)

## Prawa kolumna: lista gotowych w lobby i samouczek, jedno pod drugim.
var side_column: VBoxContainer
var _roster_card: PanelContainer
var _roster_rows: VBoxContainer
var _roster_status: Label
var _ready_action: Label
var _big_panel: PanelContainer
var _big_label: Label
var _shown_second := -1
var _info_panel: PanelContainer
var _info_label: Label
var _outside_panel: PanelContainer
var _zone_tint: ColorRect
var _zone_audio: AudioStreamPlayer
var _phase_audio: AudioStreamPlayer
var _shown_phase := -1
var _results_center: VBoxContainer
var _results_card: PanelContainer
var _results_summary: VBoxContainer
var _results_title: Label
## Tylko na podium: nadtytul nad zwyciezca i podpowiedz o pelnej tabeli na dole.
var _results_eyebrow: Label
var _results_tab_hint: Label
var _results_rows: VBoxContainer
var _results_timer: Label
## Prawa czesc panelu wynikow z kreska oddzielajaca ja od wyniku.
var _vote_panel: VBoxContainer
var _vote_divider: Control
var _vote_timer: Label
## Karty map w kolejnosci Match.VOTE_MAPS: { card, count, badge, key, state }.
var _vote_cards: Array[Dictionary] = []
var _hovered_vote := -1
var _round_divider: Control
## Sekcja "Twoja runda": wlasne liczby z tej rundy i strzalki wzgledem poprzedniej.
var _round_section: VBoxContainer
## Jedna linia z liczbami rundy w karcie wynikow. Pelne liczby ze strzalkami sa pod Tab.
var _round_line: Label
var _mini_map: ZoneMap
var _watch_panel: PanelContainer
var _watch_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not Net.is_headless)
	_build_zone_feedback()
	_build_roster()
	_build_big_label()
	_build_watch_hint()
	_build_results()
	_build_map()
	_build_phase_audio()
	Match.phase_changed.connect(_refresh)
	GameState.player_changed.connect(func(_id: int) -> void: _refresh())
	GameState.player_added.connect(func(_id: int) -> void: _refresh())
	GameState.player_removed.connect(func(_id: int) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if Match.can_vote():
		for index in Match.VOTE_MAPS.size():
			if event.is_action_pressed("slot_%d" % (index + 1)):
				_cast_vote(index)
	if event.is_action_pressed("toggle_ready") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Match.can_change_ready():
		Match.toggle_ready()
		UiSound.play(Sfx.UiCue.CONFIRM)


func _process(_delta: float) -> void:
	_update_watch_hint()
	_update_match_info()
	# Na ekranie wynikow mapka nie jest potrzebna, a stalaby obok karty.
	_mini_map.modulate.a = 0.0 if Match.phase == Match.Phase.RESULTS else 1.0
	if _results_center.visible:
		_results_timer.text = ("Powrót do lobby za %d" if Match.is_elimination() else "Nowa runda za %d") % ceili(Match.seconds_left())
		# W Battle Royale licznik i podpowiedz o tabeli stoja w jednej linii, zeby karta byla niska.
		if Match.is_elimination():
			_results_timer.text += " · " + _results_tab_hint.text
		var voting := Match.can_vote()
		_vote_panel.visible = voting
		_vote_divider.visible = voting
		_results_timer.visible = not voting
		if voting:
			_vote_timer.text = _results_timer.text
			_update_vote_cards()
	var round_start := not Match.is_elimination() and Match.is_frozen_at(NetworkTime.tick)
	var counting := Match.phase == Match.Phase.COUNTDOWN or Match.phase == Match.Phase.STARTING or round_start
	_big_panel.visible = counting
	if not counting:
		_shown_second = -1
		return
	var left := (Match.freeze_end_tick - NetworkTime.tick) * NetworkTime.ticktime if round_start else Match.seconds_left()
	var second := ceili(left)
	if second == _shown_second:
		return
	_shown_second = second
	_big_label.text = ("Start za %d" if Match.phase == Match.Phase.COUNTDOWN else "Ruszasz za %d") % second
	UiSound.play(Sfx.UiCue.NOTE)


## Odliczanie startu albo poczatku rundy. Wtedy nie ma miejsca na inne napisy pod zegarem.
func is_counting() -> bool:
	return _big_panel.visible


## Ostrzezenie o wyjsciu poza strefe stoi w tym samym pasie co napis o serii.
func is_warning_outside() -> bool:
	return _outside_panel.visible


## Glos na mape z karty albo klawisza. Drugi glos na te sama mape niczego nie zmienia.
func _cast_vote(index: int) -> void:
	var map_id := Match.VOTE_MAPS[index]
	if Match.votes.get(multiplayer.get_unique_id(), "") == map_id:
		return
	Match.vote(map_id)
	UiSound.play(Sfx.UiCue.CONFIRM)
	var card: Control = _vote_cards[index].card
	card.pivot_offset_ratio = Vector2(0.5, 0.5)
	card.scale = Vector2.ONE * VOTE_POP_SCALE
	card.create_tween().tween_property(card, "scale", Vector2.ONE, UiStyle.POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Liczba glosow, wlasny wybor i najechanie myszka. Styl zmienia sie tylko, gdy cos sie zmienilo.
func _update_vote_cards() -> void:
	var counts := Match.vote_counts()
	var mine: String = Match.votes.get(multiplayer.get_unique_id(), "")
	for index in _vote_cards.size():
		var entry := _vote_cards[index]
		var map_id := Match.VOTE_MAPS[index]
		(entry.count as Label).text = votes_text(counts.get(map_id, 0))
		(entry.key as Label).text = Keybinds.label_of("slot_%d" % (index + 1))
		var state := 2 if map_id == mine else (1 if index == _hovered_vote else 0)
		if state != entry.state:
			entry.state = state
			(entry.card as PanelContainer).add_theme_stylebox_override("panel", _vote_card_style(state))
			(entry.badge as Control).visible = state == 2


## Odmiana: 1 glos, 2 glosy, 5 glosow, 22 glosy.
static func votes_text(count: int) -> String:
	return plural(count, "głos", "głosy", "głosów")


## Liczba z polska odmiana: 1 zabojstwo, 2 zabojstwa, 5 zabojstw, 22 zabojstwa.
static func plural(count: int, one: String, few: String, many: String) -> String:
	if count == 1:
		return "1 " + one
	var tens := count % 100
	if count % 10 in [2, 3, 4] and not (tens >= 12 and tens <= 14):
		return "%d %s" % [count, few]
	return "%d %s" % [count, many]


## 0: zwykla karta, 1: pod kursorem, 2: wlasny glos.
func _vote_card_style(state: int) -> StyleBoxFlat:
	var fills: Array[Color] = [VOTE_CARD_FILL, Color.WHITE, UiStyle.BLUE.lightened(0.75)]
	var borders: Array[Color] = [Color.WHITE, UiStyle.SUN, UiStyle.BLUE]
	var style := UiStyle.sticker(fills[state], 20, VOTE_CARD_BORDER)
	style.border_color = borders[state]
	style.set_content_margin_all(VOTE_CARD_BORDER + VOTE_CARD_PADDING)
	return style


## Licznik zywych i strefa. Ostrzezenie dotyczy tylko zywej postaci gracza.
func _update_match_info() -> void:
	var state := Match.zone_state()
	_info_panel.visible = not state.is_empty()
	var me := GameState.player_node(multiplayer.get_unique_id())
	var outside: bool = not state.is_empty() and me != null and me.is_alive() and Zone.is_outside(state, me.position)
	_outside_panel.visible = outside
	_zone_tint.visible = outside
	if outside != _zone_audio.playing:
		if outside:
			_zone_audio.play()
		else:
			_zone_audio.stop()
	if outside:
		_zone_tint.color = Color(ZONE_TINT, ZONE_TINT_ALPHA + sin(Time.get_ticks_msec() * 0.006) * ZONE_TINT_PULSE)
	if not state.is_empty():
		_info_label.text = "Żywi: %d   ·   %s" % [Match.alive_count(), _zone_text(state)]


func _zone_text(state: Dictionary) -> String:
	if state.seconds_left <= 0.0:
		return "strefa zamknięta"
	var seconds := ceili(state.seconds_left / Match.zone_speed)
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	return "strefa się zwęża %s" % clock if state.shrinking else "strefa rusza za %s" % clock


func _update_watch_hint() -> void:
	var camera := get_tree().get_first_node_in_group(SpectatorCamera.GROUP) as SpectatorCamera
	var watched := camera.target_name() if camera != null else ""
	# Karta wynikow stoi w tym samym miejscu przy dolnej krawedzi.
	_watch_panel.visible = not watched.is_empty() and Match.phase != Match.Phase.RESULTS
	if _watch_panel.visible:
		_watch_label.text = "Oglądasz: %s" % watched


func _refresh() -> void:
	_play_phase_sound()
	_refresh_results()
	_roster_card.visible = Match.can_change_ready()
	if not _roster_card.visible:
		return
	for child in _roster_rows.get_children():
		child.free()
	var ready_count := 0
	for id: int in GameState.players:
		var info: Dictionary = GameState.players[id]
		ready_count += 1 if info.ready else 0
		_roster_rows.add_child(_row(info))
	var total := GameState.players.size()
	if total < Match.MIN_PLAYERS:
		_roster_status.text = "Czekamy na drugiego gracza"
	else:
		_roster_status.text = "Gotowi: %d z %d" % [ready_count, total]
	var mine: Dictionary = GameState.players.get(multiplayer.get_unique_id(), {})
	_ready_action.text = "cofnij gotowość" if mine.get("ready", false) else "jestem gotowy"


func _play_phase_sound() -> void:
	if Match.phase == _shown_phase or Net.is_headless:
		_shown_phase = Match.phase
		return
	_shown_phase = Match.phase
	if Match.phase == Match.Phase.LIVE and Match.is_elimination():
		_phase_audio.stream = Sfx.match_start()
		_phase_audio.play()
	elif Match.phase == Match.Phase.RESULTS:
		_phase_audio.stream = Sfx.match_win() if _i_won() else (Sfx.match_end() if Match.is_elimination() else Sfx.round_end())
		_phase_audio.play()


func _i_won() -> bool:
	if Match.is_team_mode():
		return Match.winning_team >= 0 and Match.winning_team == Teams.team_of(multiplayer.get_unique_id())
	for entry: Dictionary in Match.results:
		if entry.id == multiplayer.get_unique_id():
			return entry.place == 1
	return false


func _refresh_results() -> void:
	var showing := Match.phase == Match.Phase.RESULTS
	if showing and not _results_center.visible:
		_fill_results()
		# Statystyki zamrazaja runde w tym samym sygnale, wiec czytamy je chwile pozniej.
		_fill_round_stats.call_deferred()
		_place_results()
		UiStyle.pop_in(_results_card)
		_hovered_vote = -1
	_results_center.visible = showing


## Karta stoi przy dolnej krawedzi w kazdym trybie. Czyta sie ja od lewej gornej krawedzi.
func _place_results() -> void:
	_results_center.alignment = BoxContainer.ALIGNMENT_END
	_results_center.offset_bottom = -PODIUM_CARD_BOTTOM
	_results_card.custom_minimum_size.x = 0.0
	var width := PODIUM_SUMMARY_WIDTH
	if Match.is_elimination():
		width = ELIMINATION_SUMMARY_WIDTH
	elif Match.is_team_mode():
		width = TEAM_SUMMARY_WIDTH
	_results_summary.custom_minimum_size.x = width
	_results_title.add_theme_font_size_override("font_size", RESULTS_TITLE_SIZE)
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_results_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_results_summary.size_flags_vertical = Control.SIZE_FILL
	_results_tab_hint.text = "%s: pełna tabela" % Keybinds.label_of("scoreboard")
	_results_tab_hint.visible = not Match.is_elimination()
	_results_rows.add_theme_constant_override("separation", 2 if Match.is_elimination() else 4)
	if Match.is_elimination():
		_results_eyebrow.text = "Koniec meczu · Battle Royale"
	else:
		_results_eyebrow.text = "Koniec rundy · Team Deathmatch" if Match.is_team_mode() else "Koniec rundy"


func _fill_results() -> void:
	for child in _results_rows.get_children():
		child.free()
	var my_id := multiplayer.get_unique_id()
	_results_title.add_theme_color_override("font_color", UiStyle.CORAL)
	if Match.is_team_mode():
		_fill_team_results(my_id)
		return
	var winners := Match.results.filter(func(entry: Dictionary) -> bool: return entry.place == 1)
	if winners.size() == 1 and winners[0].id == my_id:
		_results_title.text = "Wygrywasz!"
	elif winners.size() == 1:
		_results_title.text = "Wygrywa %s" % _short(winners[0].name)
	else:
		_results_title.text = "Remis"
	if not Match.is_elimination():
		_fill_podium_rows(my_id)
		return
	# Najlepsi i wlasne miejsce, jesli gracz jest dalej. Pelna lista jest pod Tab.
	var shown := 0
	for entry: Dictionary in Match.results:
		if shown < ELIMINATION_ROWS or entry.id == my_id:
			_results_rows.add_child(_place_row(entry, my_id))
			shown += 1


func _place_row(entry: Dictionary, my_id: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := UiStyle.BLUE if entry.id == my_id else UiStyle.INK
	var place := UiStyle.label("%d." % entry.place, 15, color)
	place.custom_minimum_size.x = 28.0
	row.add_child(place)
	var name_label := UiStyle.label(entry.name, 15, color, entry.id == my_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	row.add_child(UiStyle.label(plural(entry.kills, "zabójstwo", "zabójstwa", "zabójstw"), 15, color, false))
	return row


## Trojke widac na podium, a pelna tabela jest pod Tab. Karta podaje wlasny wynik i nagrody
## poza najwieksza liczba zabojstw, ktora i tak widac po zwyciezcy.
func _fill_podium_rows(my_id: int) -> void:
	for entry: Dictionary in Match.results:
		if entry.id == my_id:
			var mine := UiStyle.label("Twoje miejsce: %d z %d  ·  zabójstwa: %d" % [entry.place, Match.results.size(), entry.kills], 15, UiStyle.BLUE)
			_results_rows.add_child(mine)
	for line in PodiumView.awards(Match.results).slice(1, 1 + AWARD_ROWS):
		var award := UiStyle.label("★ " + line, 14, Color("b07d00"), false)
		award.clip_text = true
		award.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_results_rows.add_child(award)


## Wygrana druzyna w tytule, wynik obu druzyn i po kolumnie na kazda z MVP na gorze.
## Remis ma wlasny tytul i neutralny kolor.
func _fill_team_results(my_id: int) -> void:
	var winner := Match.winning_team
	var mine := Teams.team_of(my_id)
	if winner < 0:
		_results_title.text = "Remis!"
		_results_title.add_theme_color_override("font_color", UiStyle.INK)
	else:
		_results_title.text = ("Wygrywacie, %s!" if winner == mine else "Wygrywają %s") % Teams.name_of(winner)
		_results_title.add_theme_color_override("font_color", Teams.color_of(winner).darkened(0.15))
	# Wynik druzyn stoi w naglowkach kolumn, wiec nie ma osobnej linii.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_rows.add_child(columns)
	for team in Teams.COUNT:
		columns.add_child(_team_column(team, my_id))


func _team_column(team: int, my_id: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := UiStyle.label("%s · %d" % [Teams.name_of(team), Match.team_scores[team]], 15, Teams.color_of(team).darkened(0.25))
	column.add_child(header)
	var mvp := Match.team_mvp(Match.results, team)
	var rows := Match.results.filter(func(entry: Dictionary) -> bool: return entry.get("team", -1) == team)
	for entry: Dictionary in rows.slice(0, TEAM_ROWS):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color := UiStyle.BLUE if entry.id == my_id else UiStyle.INK
		var is_mvp: bool = not mvp.is_empty() and mvp.id == entry.id and entry.kills > 0
		var name_label := UiStyle.label(("★ " if is_mvp else "") + entry.name, 14, Color("b07d00") if is_mvp else color, is_mvp or entry.id == my_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name_label)
		line.add_child(UiStyle.label(str(entry.kills), 14, color))
		column.add_child(line)
	if rows.is_empty():
		column.add_child(UiStyle.label("pusto", 14, Color(UiStyle.INK, 0.65), false))
	return column


## Czy jest sekcja "Twoja runda" do pokazania pod Tab.
func has_round_stats() -> bool:
	return _round_section.visible


## Sekcja "Twoja runda" stoi na dole tabeli pod Tab, a nie w karcie wynikow, ktora musi byc niska.
func move_round_stats(holder: Container) -> void:
	_round_divider.reparent(holder, false)
	_round_section.reparent(holder, false)


## Liczby gracza z tej rundy, liczone u niego na komputerze przez PlayerStats. Strzalka mowi,
## czy jest lepiej niz w poprzedniej rundzie. Bez statystyk (np. bez okna) sekcji nie ma.
## W karcie wynikow zostaje z nich jedna linia.
func _fill_round_stats() -> void:
	for child in _round_section.get_children():
		child.free()
	var stats := get_tree().get_first_node_in_group(PlayerStats.GROUP) as PlayerStats
	var shown: bool = stats != null and not stats.last_round.is_empty() and GameState.players.get(multiplayer.get_unique_id(), {}).get("in_match", true)
	_round_section.visible = shown
	_round_divider.visible = shown
	_round_line.visible = shown
	if not shown:
		return
	var now: Dictionary = stats.last_round
	var before: Dictionary = stats.previous_round
	_round_line.text = round_line(now)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_section.add_child(header)
	var title := UiStyle.label("Twoja runda", 17, UiStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiStyle.label("strzałki: w porównaniu z poprzednią rundą" if not before.is_empty() else "pierwsza runda w tej sesji", 13, Color(UiStyle.INK, 0.65), false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_section.add_child(row)
	var accuracy := PlayerStats.round_accuracy(now)
	var cells: Array[Array] = [
		["Zabójstwa", str(now.kills), _compare(now.kills, before.get("kills", -1), true)],
		["Śmierci", str(now.deaths), _compare(now.deaths, before.get("deaths", -1), false)],
		["Celność", "%d%%" % accuracy if accuracy >= 0 else "–", _compare(accuracy, PlayerStats.round_accuracy(before) if not before.is_empty() else -1, true)],
		["W głowę", str(now.headshots), _compare(now.headshots, before.get("headshots", -1), true)],
		["Obrażenia", str(now.damage), _compare(now.damage, before.get("damage", -1), true)],
		["Najdłuższe", "%d m" % roundi(now.longest) if now.longest > 0.0 else "–", _compare(roundi(now.longest), roundi(before.get("longest", -1.0)), true)],
	]
	for cell: Array in cells:
		row.add_child(_stat_cell(cell[0], cell[1], cell[2]))
	var favorite := PlayerStats.round_favorite(now)
	row.add_child(_stat_cell("Ulubiona broń", favorite if not favorite.is_empty() else "–", 0, 150.0))


## "2 zabójstwa · 1 śmierć · 29% celności · 223 obrażeń".
static func round_line(now: Dictionary) -> String:
	var accuracy := PlayerStats.round_accuracy(now)
	var parts: Array[String] = [plural(now.kills, "zabójstwo", "zabójstwa", "zabójstw"), plural(now.deaths, "śmierć", "śmierci", "śmierci")]
	if accuracy >= 0:
		parts.append("%d%% celności" % accuracy)
	parts.append("%d obrażeń" % now.damage)
	return " · ".join(parts)


## -1 brak porownania, 0 bez zmian, a dalej: 1 wzroslo i dobrze, 2 wzroslo i zle,
## 3 spadlo i dobrze, 4 spadlo i zle. Np. mniej smierci to strzalka w dol w kolorze "dobrze".
static func _compare(value: int, previous: int, more_is_better: bool) -> int:
	if previous < 0 or value < 0:
		return -1
	if value == previous:
		return 0
	var up := value > previous
	var good := up == more_is_better
	return (1 if up else 3) + (0 if good else 1)


func _stat_cell(caption: String, value: String, trend: int, width := 84.0) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.custom_minimum_size.x = width
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(line)
	var number := UiStyle.label(value, 17, UiStyle.INK)
	number.clip_text = true
	number.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	number.custom_minimum_size.x = minf(UiStyle.text_width(value, 17, true) + 2.0, width - 18.0)
	line.add_child(number)
	if trend > 0:
		var good := trend == 1 or trend == 3
		line.add_child(UiStyle.label("▲" if trend <= 2 else "▼", 14, UiStyle.TEAL.darkened(0.15) if good else UiStyle.CORAL))
	cell.add_child(UiStyle.label(caption, 13, Color(UiStyle.INK, 0.65), false))
	return cell


func _short(player_name: String) -> String:
	return player_name if player_name.length() <= ROSTER_NAME_LENGTH else player_name.left(ROSTER_NAME_LENGTH - 1) + "…"


func _row(info: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := UiStyle.label(_short(info.name), 19)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiStyle.label("gotowy" if info.ready else "czeka", 17, UiStyle.TEAL.darkened(0.2) if info.ready else Color(UiStyle.INK, 0.55)))
	return row


func _build_roster() -> void:
	# Po prawej, bo lewa strona nad paskiem zdrowia nalezy do czatu.
	side_column = VBoxContainer.new()
	side_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	side_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side_column.position += Vector2(-24.0, SIDE_COLUMN_TOP)
	side_column.add_theme_constant_override("separation", 12)
	side_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side_column)
	_roster_card = PanelContainer.new()
	_roster_card.size_flags_horizontal = Control.SIZE_SHRINK_END
	_roster_card.custom_minimum_size = Vector2(ROSTER_WIDTH, 0)
	_roster_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 22, 6))
	_roster_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_column.add_child(_roster_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_roster_card.add_child(column)
	column.add_child(UiStyle.label(GameMode.title_of(GameMode.Id.BATTLE_ROYALE), 26, UiStyle.BLUE))
	_roster_status = UiStyle.label("", 17, UiStyle.INK, false)
	column.add_child(_roster_status)
	_roster_rows = VBoxContainer.new()
	_roster_rows.add_theme_constant_override("separation", 4)
	column.add_child(_roster_rows)
	var action := HBoxContainer.new()
	action.add_theme_constant_override("separation", 8)
	column.add_child(action)
	action.add_child(ActionChip.create("toggle_ready", 34, 19))
	_ready_action = UiStyle.label("", 19)
	action.add_child(_ready_action)


func _build_zone_feedback() -> void:
	_zone_tint = ColorRect.new()
	_zone_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zone_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_tint.visible = false
	add_child(_zone_tint)
	_zone_audio = AudioStreamPlayer.new()
	# Dzwiek liczy sie chwile, a serwer bez ekranu nigdy go nie zagra.
	if not Net.is_headless:
		_zone_audio.stream = Sfx.zone_hum()
	_zone_audio.volume_db = ZONE_HUM_VOLUME
	add_child(_zone_audio)

	var info_center := CenterContainer.new()
	info_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	info_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	info_center.position.y = 22.0
	info_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_center)
	_info_panel = PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 16, 4)
	style.set_content_margin_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	_info_panel.add_theme_stylebox_override("panel", style)
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	info_center.add_child(_info_panel)
	_info_label = UiStyle.label("", 19, UiStyle.INK)
	_info_panel.add_child(_info_label)

	var outside_center := CenterContainer.new()
	outside_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	outside_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outside_center.position.y = 76.0
	outside_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outside_center)
	_outside_panel = PanelContainer.new()
	_outside_panel.add_theme_stylebox_override("panel", UiStyle.sticker(Color("7a5cff"), 18, 5))
	_outside_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outside_panel.visible = false
	outside_center.add_child(_outside_panel)
	_outside_panel.add_child(UiStyle.label("Jesteś poza strefą!", 26, Color.WHITE))


func _build_map() -> void:
	var map := ZoneMap.new()
	_mini_map = map
	map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map.grow_vertical = Control.GROW_DIRECTION_BEGIN
	map.position += Vector2(-MAP_MARGIN_RIGHT - ZoneMap.SIDE, -MAP_MARGIN_BOTTOM - ZoneMap.SIDE)
	add_child(map)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var big := ZoneMap.new()
	big.side = BIG_MAP_SIDE
	big.big = true
	center.add_child(big)


## Dzwieki powstaja teraz, zeby koniec meczu nie przycial obrazu.
func _build_phase_audio() -> void:
	_phase_audio = AudioStreamPlayer.new()
	add_child(_phase_audio)
	if not Net.is_headless:
		Sfx.match_start()
		Sfx.match_win()
		Sfx.match_end()


func _build_results() -> void:
	_results_center = VBoxContainer.new()
	_results_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_center.visible = false
	add_child(_results_center)
	_results_card = PanelContainer.new()
	_results_card.custom_minimum_size = Vector2.ZERO
	_results_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := UiStyle.sticker(UiStyle.PAPER, 24, RESULTS_BORDER)
	style.set_content_margin_all(RESULTS_BORDER + 14)
	style.content_margin_left = RESULTS_BORDER + 20
	style.content_margin_right = RESULTS_BORDER + 20
	_results_card.add_theme_stylebox_override("panel", style)
	_results_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_center.add_child(_results_card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_card.add_child(stack)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", SECTION_GAP)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(body)
	# Sekcja "Twoja runda" powstaje tu, ale stoi na dole tabeli pod Tab (move_round_stats).
	_round_divider = ColorRect.new()
	(_round_divider as ColorRect).color = DIVIDER_COLOR
	_round_divider.custom_minimum_size.y = 2
	_round_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_divider.visible = false
	stack.add_child(_round_divider)
	_round_section = VBoxContainer.new()
	_round_section.add_theme_constant_override("separation", 6)
	_round_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_section.visible = false
	stack.add_child(_round_section)

	# Wynik rundy: zwyciezca jest najwazniejszy, pod nim wlasne miejsce i nagrody.
	_results_summary = VBoxContainer.new()
	_results_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_results_summary.add_theme_constant_override("separation", 2)
	_results_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_results_summary)
	_results_eyebrow = UiStyle.label("Koniec rundy", 14, Color(UiStyle.INK, 0.65), false)
	_results_summary.add_child(_results_eyebrow)
	_results_title = UiStyle.label("", 38, UiStyle.CORAL)
	_results_title.clip_text = true
	_results_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_summary.add_child(_results_title)
	_results_rows = VBoxContainer.new()
	_results_rows.add_theme_constant_override("separation", 4)
	_results_summary.add_child(_results_rows)
	# W waskiej czesci karty Deathmatchu linia zawija sie na dwie.
	_round_line = UiStyle.label("", 14, UiStyle.BLUE)
	_round_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_round_line.visible = false
	_results_summary.add_child(_round_line)
	_results_timer = UiStyle.label("", 14, Color(UiStyle.INK, 0.65), false)
	_results_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_summary.add_child(_results_timer)
	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_summary.add_child(push_down)
	_results_tab_hint = UiStyle.label("", 14, Color(UiStyle.INK, 0.65), false)
	_results_summary.add_child(_results_tab_hint)

	_vote_divider = ColorRect.new()
	(_vote_divider as ColorRect).color = DIVIDER_COLOR
	_vote_divider.custom_minimum_size.x = 2
	_vote_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_divider.visible = false
	body.add_child(_vote_divider)
	body.add_child(_build_vote_panel())


## Glosowanie: naglowek z odliczaniem, podpowiedz i karta kazdej mapy.
func _build_vote_panel() -> VBoxContainer:
	_vote_panel = VBoxContainer.new()
	_vote_panel.add_theme_constant_override("separation", 2)
	_vote_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_panel.visible = false
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_panel.add_child(header)
	var title := UiStyle.label("Następna mapa", 18, UiStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_vote_timer = UiStyle.label("", 14, Color(UiStyle.INK, 0.65), false)
	header.add_child(_vote_timer)
	_vote_panel.add_child(UiStyle.label("Kliknij kartę albo naciśnij jej klawisz", 14, Color(UiStyle.INK, 0.65), false))
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	_vote_panel.add_child(gap)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vote_panel.add_child(cards)
	for index in Match.VOTE_MAPS.size():
		cards.add_child(_build_vote_card(index))
	return _vote_panel


func _build_vote_card(index: int) -> PanelContainer:
	var info := Maps.info(Match.VOTE_MAPS[index])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _vote_card_style(0))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	# Miniaturka z zaokraglonymi rogami: panel jest maska, a obraz rysuje sie tylko w nim.
	# Nad obrazem klawisz w lewym gornym rogu i znaczek wlasnego glosu w prawym.
	var overlay := Control.new()
	overlay.custom_minimum_size = VOTE_THUMB_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(overlay)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := StyleBoxFlat.new()
	mask.set_corner_radius_all(8)
	mask.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", mask)
	overlay.add_child(frame)
	var thumb := TextureRect.new()
	if ResourceLoader.exists(info.thumbnail):
		thumb.texture = load(info.thumbnail) as Texture2D
	thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(thumb)
	var chip := UiStyle.key_chip("", 26, 15)
	chip.position = Vector2(8, 8)
	overlay.add_child(chip)
	var badge := PanelContainer.new()
	var badge_style := UiStyle.sticker(UiStyle.BLUE, 12, 3)
	badge_style.set_content_margin_all(3 + 3)
	badge_style.content_margin_left = 3 + 8
	badge_style.content_margin_right = 3 + 8
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiStyle.label("✓ Twój głos", 13, Color.WHITE))
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.position += Vector2(-8, 8)
	badge.visible = false
	overlay.add_child(badge)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var name_label := UiStyle.label(info.title, 15, UiStyle.INK)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(name_label)
	var count := UiStyle.label("", 13, Color(UiStyle.INK, 0.65), false)
	footer.add_child(count)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_cast_vote(index)
			card.accept_event())
	card.mouse_entered.connect(func() -> void:
		_hovered_vote = index
		UiSound.play(Sfx.UiCue.HOVER))
	card.mouse_exited.connect(func() -> void:
		if _hovered_vote == index:
			_hovered_vote = -1)
	_vote_cards.append({ "card": card, "count": count, "badge": badge, "key": chip.get_child(0), "state": 0 })
	return card


func _build_watch_hint() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	center.position.y -= 40.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_watch_panel = PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 18, 5)
	style.set_content_margin_all(9)
	style.content_margin_left = 18
	style.content_margin_right = 18
	_watch_panel.add_theme_stylebox_override("panel", style)
	_watch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_watch_panel.visible = false
	center.add_child(_watch_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_watch_panel.add_child(row)
	_watch_label = UiStyle.label("", 21, UiStyle.INK)
	row.add_child(_watch_label)
	var next := UiStyle.label("", 17, Color(UiStyle.INK, 0.65), false)
	row.add_child(next)
	var update := func() -> void: next.text = "%s: następny gracz" % Keybinds.label_of("fire")
	update.call()
	Settings.changed.connect(update)


func _build_big_label() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.position.y = BIG_LABEL_TOP
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_big_panel = PanelContainer.new()
	var big_style := UiStyle.sticker(UiStyle.SUN, 20, 5)
	big_style.set_content_margin_all(5 + 4)
	big_style.content_margin_left = 5 + 20
	big_style.content_margin_right = 5 + 20
	_big_panel.add_theme_stylebox_override("panel", big_style)
	_big_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_panel.visible = false
	center.add_child(_big_panel)
	_big_label = UiStyle.label("", 32, UiStyle.INK)
	_big_panel.add_child(_big_label)
