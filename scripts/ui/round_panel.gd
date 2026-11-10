class_name RoundPanel
extends Control
## Runda Deathmatchu w HUD: zegar z wlasnym miejscem i trzech najlepszych. Pelna lista jest pod Tab.
## Ostatnie 30 s ma wyrazny sygnal: czerwony zegar, napis i tykanie w ostatnich sekundach.
## Lidera nie ma w zegarze, bo pokazuje go karta "Najlepsi". W Team Deathmatchu wynik daja liczniki druzyn.

signal banner_shown

const TOP_COUNT := 3
const NAME_LENGTH := 14
const BANNER_SECONDS := 2.0
const TICKING_FROM := 10
## Baner, seria i odliczanie dziela jedno miejsce pod zegarem (MatchPanel.BIG_LABEL_TOP).
const BANNER_FONT := 19
## Szerokosc tekstu, a cala naklejka z marginesami (2 x 21) ma najwyzej 340 px.
const BANNER_MAX_WIDTH := 298.0

var _clock_panel: PanelContainer
var _clock_style: StyleBoxFlat
var _clock: Label
var _leader: Label
var _place: Label
var _top_card: PanelContainer
var _top_rows: VBoxContainer
var _banner: PanelContainer
var _banner_timer := 0.0
var _audio: AudioStreamPlayer
var _shown_second := -1
var _warned_round := -1
var _dirty := true
var _banner_label: Label
var _banner_style: StyleBoxFlat
## Wynik obu druzyn po bokach zegara w Team Deathmatchu.
var _team_chips: Array[PanelContainer] = []
var _team_scores: Array[Label] = []
var _seen_leading := -2
var _seen_round := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameState.player_changed.connect(func(_id: int) -> void: _dirty = true)
	GameState.player_added.connect(func(_id: int) -> void: _dirty = true)
	GameState.player_removed.connect(func(_id: int) -> void: _dirty = true)
	Match.phase_changed.connect(func() -> void: _dirty = true)
	Match.team_scores_changed.connect(_on_team_scores_changed)
	set_process(not Net.is_headless)


func _process(delta: float) -> void:
	var shown := Net.in_session and not Match.is_elimination() and Match.phase == Match.Phase.LIVE
	_clock_panel.visible = shown
	# Samouczek stoi w tym samym miejscu, a na poczatku walki nikt i tak nie ma punktow.
	var tutorial := get_tree().get_first_node_in_group(TutorialPanel.GROUP) != null
	_top_card.visible = shown and GameState.players.size() > 1 and not Match.is_team_mode() and not tutorial
	for chip in _team_chips:
		chip.visible = shown and Match.is_team_mode()
	if not shown:
		_banner.visible = false
		_shown_second = -1
		return
	_update_clock(delta)
	if _dirty:
		_dirty = false
		_refresh_standings()


## Ranking stoi w kolumnie lewego gornego rogu HUD, pod licznikiem FPS i wykresem sieci.
func move_top_card(column: Container) -> void:
	_top_card.reparent(column, false)


func clock_text() -> String:
	return _clock.text


func leader_text() -> String:
	return _leader.text


func place_text() -> String:
	return _place.text


func top_names() -> Array[String]:
	var names: Array[String] = []
	for row in _top_rows.get_children():
		names.append((row.get_child(1) as Label).text)
	return names


func is_final_warning() -> bool:
	return Match.phase_end_tick >= 0 and Match.seconds_left() <= Match.FINAL_WARNING_SECONDS


func _update_clock(delta: float) -> void:
	if Match.phase_end_tick < 0:
		_clock.text = "–:––"
		return
	var left := ceili(Match.seconds_left())
	_clock.text = "%d:%02d" % [left / 60, left % 60]
	var final := is_final_warning()
	_clock_style.bg_color = UiStyle.CORAL if final else UiStyle.PAPER
	_clock.add_theme_color_override("font_color", Color.WHITE if final else UiStyle.INK)
	if final and _warned_round != Match.round_number:
		_warned_round = Match.round_number
		_show_banner("Ostatnie 30 sekund!", UiStyle.CORAL)
		_audio.stream = Sfx.match_start()
		_audio.play()
	if final and left != _shown_second and left <= TICKING_FROM:
		UiSound.play(Sfx.UiCue.NOTE, 1.0 + (TICKING_FROM - left) * 0.05)
		_clock_panel.pivot_offset = _clock_panel.size * 0.5
		_clock_panel.scale = Vector2.ONE * 1.12
		_clock_panel.create_tween().tween_property(_clock_panel, "scale", Vector2.ONE, 0.2)
	_shown_second = left
	_banner_timer = maxf(0.0, _banner_timer - delta)
	_banner.visible = _banner_timer > 0.0


func _show_banner(text: String, color: Color) -> void:
	_banner_label.text = text
	UiStyle.fit_width(_banner_label, BANNER_MAX_WIDTH)
	_banner_style.bg_color = color
	_banner_timer = BANNER_SECONDS
	_banner.visible = true
	UiStyle.pop_in(_banner)
	banner_shown.emit()


## Nowy napis w tym samym miejscu (seria albo odliczanie) zastepuje baner.
func hide_banner() -> void:
	_banner_timer = 0.0
	_banner.visible = false


## Krotki napis, gdy prowadzenie przechodzi na druga strone. Remis niczego nie oglasza.
func _on_team_scores_changed() -> void:
	_dirty = true
	if not Match.is_team_mode():
		return
	if _seen_round != Match.round_number:
		_seen_round = Match.round_number
		_seen_leading = -1
	var leading := Match.leading_team()
	var mine := Teams.team_of(multiplayer.get_unique_id())
	if leading < 0 or leading == _seen_leading:
		return
	_seen_leading = leading
	if mine == Teams.NONE or Match.phase != Match.Phase.LIVE:
		return
	if leading == mine:
		_show_banner("Twoja drużyna prowadzi!", UiStyle.TEAL)
	else:
		_show_banner("Twoja drużyna przegrywa", Teams.color_of(leading))
	UiSound.play(Sfx.UiCue.NOTE, 1.2 if leading == mine else 0.85)


## Napis o druzynach zamiast lidera: do ilu gramy i w ktorej druzynie jest gracz.
func _refresh_team_status() -> void:
	for team in Teams.COUNT:
		_team_scores[team].text = str(Match.team_scores[team])
	var mine := Teams.team_of(multiplayer.get_unique_id())
	_leader.text = "Gramy do %d zabójstw" % Match.kill_limit
	_place.text = "Wybierz drużynę" if mine == Teams.NONE else "Do %d · drużyna %s" % [Match.kill_limit, Teams.name_of(mine)]


func _refresh_standings() -> void:
	var rows := Match.standings()
	var my_id := multiplayer.get_unique_id()
	if rows.is_empty():
		return
	if Match.is_team_mode():
		_refresh_team_status()
	var leaders := rows.filter(func(row: Dictionary) -> bool: return row.place == 1)
	if Match.is_team_mode():
		pass
	elif rows[0].kills == 0:
		_leader.text = "Nikt jeszcze nie prowadzi"
	elif leaders.size() > 1:
		_leader.text = "Remis na prowadzeniu · %d" % rows[0].kills
	else:
		_leader.text = "Prowadzi %s · %d" % [_short(leaders[0].name), rows[0].kills]
	for row: Dictionary in rows:
		if row.id == my_id and not Match.is_team_mode():
			_place.text = "Twoje miejsce: %d z %d · do %d" % [row.place, rows.size(), Match.kill_limit]
	for child in _top_rows.get_children():
		child.free()
	for index in mini(TOP_COUNT, rows.size()):
		var row: Dictionary = rows[index]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var color := UiStyle.BLUE if row.id == my_id else Teams.player_color(row.id, UiStyle.INK).darkened(0.15 if Match.is_team_mode() else 0.0)
		line.add_child(UiStyle.label("%d." % row.place, 17, color))
		var name_label := UiStyle.label(_short(row.name), 17, color, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UiStyle.label(str(row.kills), 17, color))
		_top_rows.add_child(line)


func _short(text: String) -> String:
	return text if text.length() <= NAME_LENGTH else text.left(NAME_LENGTH - 1) + "…"


func _build() -> void:
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 18.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_clock_panel = PanelContainer.new()
	_clock_style = UiStyle.sticker(UiStyle.PAPER, 18, 5)
	_clock_style.set_content_margin_all(8)
	_clock_style.content_margin_left = 18
	_clock_style.content_margin_right = 18
	_clock_panel.add_theme_stylebox_override("panel", _clock_style)
	_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar)
	for team in Teams.COUNT:
		var chip := _build_team_chip(team)
		bar.add_child(chip)
		if team == 0:
			bar.add_child(_clock_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_clock_panel.add_child(column)
	_clock = UiStyle.label("5:00", 32, UiStyle.INK)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_clock)
	# Lider jest liczony dla testow i tabeli, ale nie stoi w zegarze: pokazuje go karta "Najlepsi".
	_leader = UiStyle.label("", 16, Color(UiStyle.INK, 0.8), false)
	_leader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leader.visible = false
	column.add_child(_leader)
	_place = UiStyle.label("", 15, Color(UiStyle.INK, 0.65), false)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_place)

	_top_card = PanelContainer.new()
	var top_style := UiStyle.sticker(UiStyle.PAPER, 16, 4)
	top_style.set_content_margin_all(10)
	_top_card.add_theme_stylebox_override("panel", top_style)
	_top_card.custom_minimum_size = Vector2(210, 0)
	_top_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_top_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_card)
	var top_column := VBoxContainer.new()
	top_column.add_theme_constant_override("separation", 2)
	_top_card.add_child(top_column)
	top_column.add_child(UiStyle.label("Najlepsi", 15, UiStyle.CORAL))
	_top_rows = VBoxContainer.new()
	_top_rows.add_theme_constant_override("separation", 2)
	top_column.add_child(_top_rows)

	var banner_center := CenterContainer.new()
	banner_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_center.position.y = MatchPanel.BIG_LABEL_TOP
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_center)
	_banner = PanelContainer.new()
	_banner_style = UiStyle.sticker(UiStyle.CORAL, 18, 5)
	_banner_style.set_content_margin_all(5 + 8)
	_banner_style.content_margin_left = 5 + 16
	_banner_style.content_margin_right = 5 + 16
	_banner.add_theme_stylebox_override("panel", _banner_style)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	banner_center.add_child(_banner)
	_banner_label = UiStyle.label("Ostatnie 30 sekund!", BANNER_FONT, Color.WHITE)
	_banner.add_child(_banner_label)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)


## Naklejka w kolorze druzyny: duzy wynik i nazwa pod nim.
func _build_team_chip(team: int) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := UiStyle.sticker(Teams.color_of(team), 18, 5)
	style.set_content_margin_all(5 + 4)
	style.content_margin_left = 5 + 16
	style.content_margin_right = 5 + 16
	chip.add_theme_stylebox_override("panel", style)
	chip.custom_minimum_size.x = 112
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	chip.add_child(column)
	var score := UiStyle.label("0", 32, Color.WHITE)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(score)
	var title := UiStyle.label(Teams.name_of(team), 14, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_team_chips.append(chip)
	_team_scores.append(score)
	return chip
