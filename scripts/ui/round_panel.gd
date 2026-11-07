class_name RoundPanel
extends Control
## Runda Deathmatchu w HUD: zegar, lider, wlasne miejsce i trzech najlepszych. Pelna lista jest pod Tab.
## Ostatnie 30 s ma wyrazny sygnal: czerwony zegar, napis i tykanie w ostatnich sekundach.

const TOP_COUNT := 3
const NAME_LENGTH := 14
const BANNER_SECONDS := 2.5
const TICKING_FROM := 10

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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameState.player_changed.connect(func(_id: int) -> void: _dirty = true)
	GameState.player_added.connect(func(_id: int) -> void: _dirty = true)
	GameState.player_removed.connect(func(_id: int) -> void: _dirty = true)
	Match.phase_changed.connect(func() -> void: _dirty = true)
	set_process(not Net.is_headless)


func _process(delta: float) -> void:
	var shown := Net.in_session and not Match.is_elimination() and Match.phase == Match.Phase.LIVE
	_clock_panel.visible = shown
	_top_card.visible = shown and GameState.players.size() > 1
	if not shown:
		_banner.visible = false
		_shown_second = -1
		return
	_update_clock(delta)
	if _dirty:
		_dirty = false
		_refresh_standings()


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
		_banner_timer = BANNER_SECONDS
		UiStyle.pop_in(_banner)
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


func _refresh_standings() -> void:
	var rows := Match.standings()
	var my_id := multiplayer.get_unique_id()
	if rows.is_empty():
		return
	var leaders := rows.filter(func(row: Dictionary) -> bool: return row.place == 1)
	if rows[0].kills == 0:
		_leader.text = "Nikt jeszcze nie prowadzi"
	elif leaders.size() > 1:
		_leader.text = "Remis na prowadzeniu · %d" % rows[0].kills
	else:
		_leader.text = "Prowadzi %s · %d" % [_short(leaders[0].name), rows[0].kills]
	for row: Dictionary in rows:
		if row.id == my_id:
			_place.text = "Twoje miejsce: %d z %d   (limit %d)" % [row.place, rows.size(), Match.kill_limit]
	for child in _top_rows.get_children():
		child.free()
	for index in mini(TOP_COUNT, rows.size()):
		var row: Dictionary = rows[index]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var color := UiStyle.BLUE if row.id == my_id else UiStyle.INK
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
	top.add_child(_clock_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_clock_panel.add_child(column)
	_clock = UiStyle.label("5:00", 32, UiStyle.INK)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_clock)
	_leader = UiStyle.label("", 16, Color(UiStyle.INK, 0.8), false)
	_leader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_leader)
	_place = UiStyle.label("", 15, Color(UiStyle.INK, 0.65), false)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_place)

	_top_card = PanelContainer.new()
	var top_style := UiStyle.sticker(UiStyle.PAPER, 16, 4)
	top_style.set_content_margin_all(10)
	_top_card.add_theme_stylebox_override("panel", top_style)
	_top_card.custom_minimum_size = Vector2(210, 0)
	_top_card.position = Vector2(24, 128)
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
	banner_center.position.y = 140.0
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_center)
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.CORAL, 22, 6))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	banner_center.add_child(_banner)
	_banner.add_child(UiStyle.label("Ostatnie 30 sekund!", 30, Color.WHITE))

	_audio = AudioStreamPlayer.new()
	add_child(_audio)
