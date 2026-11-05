class_name Hud
extends CanvasLayer
## Interfejs w grze: zdrowie, celownik, komunikaty o zabojstwach, wyniki i pauza.

const FEED_SECONDS := 5.0

var _player: Player
var _crosshair: Crosshair
var _health_bar: ProgressBar
var _health_label: Label
var _feed: VBoxContainer
var _death_panel: Label
var _damage_flash: ColorRect
var _scoreboard: PanelContainer
var _score_rows: VBoxContainer
var _pause: CenterContainer
var _audio: AudioStreamPlayer


func _ready() -> void:
	add_to_group(&"hud")
	_build()
	GameState.hit_confirmed.connect(_on_hit_confirmed)
	GameState.damaged.connect(_on_damaged)
	GameState.kill_announced.connect(_on_kill)
	GameState.player_changed.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.player_added.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.player_removed.connect(func(_id: int) -> void: _refresh_scoreboard())
	get_window().focus_exited.connect(_on_focus_lost)


func bind(player: Player) -> void:
	_player = player
	_pause.visible = false
	_refresh_scoreboard()


func unbind() -> void:
	_player = null


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var info := _player.info
	_health_bar.value = info.health
	_health_label.text = str(info.health)
	var bar_fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	bar_fill.bg_color = UiStyle.TEAL if info.health > 35 else UiStyle.DANGER
	_death_panel.visible = not info.alive
	if not info.alive:
		var seconds := maxf(0.0, (info.respawn_tick - NetworkTime.tick) * NetworkTime.ticktime)
		_death_panel.text = "Trafiony!\nPowrót za %d…" % ceili(seconds)
	_scoreboard.visible = Input.is_action_pressed("scoreboard")


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not visible or not Net.bot_mode.is_empty():
		return
	if event.is_action_pressed("pause"):
		_set_paused(not _pause.visible)
	elif event is InputEventMouseButton and event.pressed and not _pause.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _on_focus_lost() -> void:
	# Bez tego dwa okna na jednym komputerze walczylyby o kursor.
	if _player != null and visible and Net.bot_mode.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_hit_confirmed(killed: bool) -> void:
	_crosshair.flash_hit(killed)
	_audio.stream = Sfx.kill() if killed else Sfx.hit()
	_audio.play()


func _on_damaged(_amount: int) -> void:
	_damage_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_damage_flash, "modulate:a", 0.0, 0.35)


func _on_kill(killer_id: int, victim_id: int) -> void:
	var row := UiStyle.label("%s  ▸  %s" % [GameState.display_name(killer_id), GameState.display_name(victim_id)], 18)
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(row)
	var tween := row.create_tween()
	tween.tween_interval(FEED_SECONDS)
	tween.tween_property(row, "modulate:a", 0.0, 0.4)
	tween.tween_callback(row.queue_free)


func _refresh_scoreboard() -> void:
	if _score_rows == null:
		return
	for child in _score_rows.get_children():
		child.free()
	var ids := GameState.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return GameState.players[a].kills > GameState.players[b].kills)
	_score_rows.add_child(_score_row("Gracz", "Zabójstwa", "Śmierci", UiStyle.ACCENT))
	for id: int in ids:
		var info: Dictionary = GameState.players[id]
		var color := PlayerModel.color_for(id).lightened(0.25)
		_score_rows.add_child(_score_row(info.name, str(info.kills), str(info.deaths), color))


func _score_row(player_name: String, kills: String, deaths: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := UiStyle.label(player_name, 20, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	for value in [kills, deaths]:
		var cell := UiStyle.label(value, 20)
		cell.custom_minimum_size = Vector2(110, 0)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cell)
	return row


func _build() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(UiStyle.DANGER, 0.35)
	_damage_flash.modulate.a = 0.0
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_damage_flash)

	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_crosshair)

	var health_box := Control.new()
	health_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_box.position = Vector2(24, -70)
	add_child(health_box)
	_health_bar = ProgressBar.new()
	_health_bar.max_value = GameState.MAX_HEALTH
	_health_bar.show_percentage = false
	_health_bar.size = Vector2(280, 40)
	_health_bar.add_theme_stylebox_override("background", UiStyle.panel(UiStyle.INK, 4, 12))
	_health_bar.add_theme_stylebox_override("fill", UiStyle.panel(UiStyle.TEAL, 4, 12))
	health_box.add_child(_health_bar)
	_health_label = UiStyle.label("100", 24)
	_health_label.size = Vector2(280, 40)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_box.add_child(_health_label)

	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.position += Vector2(-340, 20)
	_feed.custom_minimum_size = Vector2(320, 0)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	_death_panel = UiStyle.label("", 42, UiStyle.PAPER, 10)
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_panel.visible = false
	add_child(_death_panel)

	var score_center := CenterContainer.new()
	score_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_center)
	_scoreboard = PanelContainer.new()
	_scoreboard.custom_minimum_size = Vector2(560, 0)
	_scoreboard.add_theme_stylebox_override("panel", UiStyle.panel(Color(UiStyle.INK, 0.9), 5, 18))
	_scoreboard.visible = false
	score_center.add_child(_scoreboard)
	_score_rows = VBoxContainer.new()
	_scoreboard.add_child(_score_rows)

	_pause = CenterContainer.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var pause_box := VBoxContainer.new()
	pause_box.custom_minimum_size = Vector2(320, 0)
	pause_box.add_theme_constant_override("separation", 12)
	_pause.add_child(pause_box)
	var pause_title := UiStyle.label("Pauza", 42, UiStyle.ACCENT, 10)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title)
	var resume := UiStyle.button("Wróć do gry", UiStyle.TEAL)
	resume.pressed.connect(_set_paused.bind(false))
	pause_box.add_child(resume)
	var disconnect_button := UiStyle.button("Rozłącz", UiStyle.DANGER)
	disconnect_button.pressed.connect(func() -> void: Net.leave())
	pause_box.add_child(disconnect_button)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)
