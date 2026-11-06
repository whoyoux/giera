class_name MatchPanel
extends Control
## Interfejs etapow Battle Royale: lista gotowosci w lobby i duze odliczanie.

const ROSTER_NAME_LENGTH := 20
const ROSTER_WIDTH := 300.0

var _roster_card: PanelContainer
var _roster_rows: VBoxContainer
var _roster_status: Label
var _ready_action: Label
var _big_panel: PanelContainer
var _big_label: Label
var _shown_second := -1
var _watch_panel: PanelContainer
var _watch_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_roster()
	_build_big_label()
	_build_watch_hint()
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


func _update_watch_hint() -> void:
	var camera := get_tree().get_first_node_in_group(SpectatorCamera.GROUP) as SpectatorCamera
	var watched := camera.target_name() if camera != null else ""
	_watch_panel.visible = not watched.is_empty()
	if _watch_panel.visible:
		_watch_label.text = "Oglądasz: %s" % watched


func _refresh() -> void:
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
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	anchor.grow_horizontal = Control.GROW_DIRECTION_END
	anchor.grow_vertical = Control.GROW_DIRECTION_BOTH
	anchor.position.x = 24.0
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
