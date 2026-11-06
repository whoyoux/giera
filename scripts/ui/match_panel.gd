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
var _results_center: CenterContainer
var _results_card: PanelContainer
var _results_title: Label
var _results_rows: VBoxContainer
var _results_timer: Label
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
	if event.is_action_pressed("toggle_ready") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Match.can_change_ready():
		Match.toggle_ready()
		UiSound.play(Sfx.UiCue.CONFIRM)


func _process(_delta: float) -> void:
	_update_watch_hint()
	_update_match_info()
	if _results_center.visible:
		_results_timer.text = "Powrót do lobby za %d" % ceili(Match.seconds_left())
	var counting := Match.phase == Match.Phase.COUNTDOWN or Match.phase == Match.Phase.STARTING
	_big_panel.visible = counting
	if not counting:
		_shown_second = -1
		return
	var second := ceili(Match.seconds_left())
	if second == _shown_second:
		return
	_shown_second = second
	_big_label.text = ("Start za %d" if Match.phase == Match.Phase.COUNTDOWN else "Ruszasz za %d") % second
	UiSound.play(Sfx.UiCue.NOTE)


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
	return "strefa zawęża się jeszcze %s" % clock if state.shrinking else "strefa ruszy za %s" % clock


func _update_watch_hint() -> void:
	var camera := get_tree().get_first_node_in_group(SpectatorCamera.GROUP) as SpectatorCamera
	var watched := camera.target_name() if camera != null else ""
	_watch_panel.visible = not watched.is_empty()
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
	if Match.phase == _shown_phase or not Match.is_elimination() or Net.is_headless:
		_shown_phase = Match.phase
		return
	_shown_phase = Match.phase
	if Match.phase == Match.Phase.LIVE:
		_phase_audio.stream = Sfx.match_start()
		_phase_audio.play()
	elif Match.phase == Match.Phase.RESULTS:
		_phase_audio.stream = Sfx.match_win() if _i_won() else Sfx.match_end()
		_phase_audio.play()


func _i_won() -> bool:
	for entry: Dictionary in Match.results:
		if entry.id == multiplayer.get_unique_id():
			return entry.place == 1
	return false


func _refresh_results() -> void:
	var showing := Match.phase == Match.Phase.RESULTS
	if showing and not _results_center.visible:
		_fill_results()
		UiStyle.pop_in(_results_card)
	_results_center.visible = showing


func _fill_results() -> void:
	for child in _results_rows.get_children():
		child.free()
	var winners := Match.results.filter(func(entry: Dictionary) -> bool: return entry.place == 1)
	var my_id := multiplayer.get_unique_id()
	if winners.size() == 1 and winners[0].id == my_id:
		_results_title.text = "Wygrywasz!"
	elif winners.size() == 1:
		_results_title.text = "Wygrywa %s" % winners[0].name
	else:
		_results_title.text = "Remis"
	for entry: Dictionary in Match.results:
		var row := HBoxContainer.new()
		var color := UiStyle.BLUE if entry.id == my_id else UiStyle.INK
		var place := UiStyle.label("%d." % entry.place, 21, color)
		place.custom_minimum_size.x = 42.0
		row.add_child(place)
		var name_label := UiStyle.label(entry.name, 21, color)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		row.add_child(UiStyle.label("zabójstwa: %d" % entry.kills, 19, color, false))
		_results_rows.add_child(row)


func _row(info: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var player_name: String = info.name
	if player_name.length() > ROSTER_NAME_LENGTH:
		player_name = player_name.left(ROSTER_NAME_LENGTH - 1) + "…"
	var name_label := UiStyle.label(player_name, 19)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiStyle.label("gotowy" if info.ready else "czeka", 17, UiStyle.TEAL.darkened(0.2) if info.ready else Color(UiStyle.INK, 0.55)))
	return row


func _build_roster() -> void:
	var anchor := CenterContainer.new()
	# Po prawej, bo lewa strona nad paskiem zdrowia nalezy do czatu.
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor.grow_vertical = Control.GROW_DIRECTION_BOTH
	anchor.position.x -= 24.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_roster_card = PanelContainer.new()
	_roster_card.custom_minimum_size = Vector2(ROSTER_WIDTH, 0)
	_roster_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 22, 6))
	_roster_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_roster_card)
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
	action.add_child(UiStyle.key_chip("F", 34, 19))
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
	map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	map.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map.grow_vertical = Control.GROW_DIRECTION_BEGIN
	map.position += Vector2(-MAP_MARGIN_RIGHT - ZoneMap.SIDE, -MAP_MARGIN_BOTTOM - ZoneMap.SIDE)
	add_child(map)


## Dzwieki powstaja teraz, zeby koniec meczu nie przycial obrazu.
func _build_phase_audio() -> void:
	_phase_audio = AudioStreamPlayer.new()
	add_child(_phase_audio)
	if not Net.is_headless:
		Sfx.match_start()
		Sfx.match_win()
		Sfx.match_end()


func _build_results() -> void:
	_results_center = CenterContainer.new()
	_results_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_center.visible = false
	add_child(_results_center)
	_results_card = PanelContainer.new()
	_results_card.custom_minimum_size = Vector2(520, 0)
	_results_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_results_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_center.add_child(_results_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_results_card.add_child(column)
	_results_title = UiStyle.label("", 38, UiStyle.CORAL)
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_results_title)
	_results_rows = VBoxContainer.new()
	_results_rows.add_theme_constant_override("separation", 6)
	column.add_child(_results_rows)
	_results_timer = UiStyle.label("", 17, Color(UiStyle.INK, 0.65), false)
	_results_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_results_timer)


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
	row.add_child(UiStyle.label("LPM: następny gracz", 17, Color(UiStyle.INK, 0.65), false))


func _build_big_label() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.position.y = 96.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_big_panel = PanelContainer.new()
	_big_panel.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.SUN, 24, 6))
	_big_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_panel.visible = false
	center.add_child(_big_panel)
	_big_label = UiStyle.label("", 38, UiStyle.INK)
	_big_panel.add_child(_big_label)
