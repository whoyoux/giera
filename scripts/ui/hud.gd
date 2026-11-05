class_name Hud
extends CanvasLayer
## Interfejs w grze: zdrowie, speed, amunicja, celownik, zabojstwa, wyniki i pauza.

signal settings_requested

const FEED_SECONDS := 5.0
const LOW_HEALTH := 35
const ITEM_NAME_SECONDS := 1.4
## Od tylu obrazen reakcja na trafienie jest najmocniejsza.
const HEAVY_HIT_DAMAGE := 40.0
const GOOD_PING := 60
const BAD_PING := 120
const VIGNETTE_SHADER := preload("res://shaders/damage_vignette.gdshader")

var _player: Player
var _crosshair: Crosshair
var _health_bar: ProgressBar
var _health_label: Label
var _speed_bar: ProgressBar
var _speed_fill: StyleBoxFlat
var _hotbar: Hotbar
var _item_name_panel: PanelContainer
var _item_name: Label
var _item_name_style: StyleBoxFlat
var _item_name_tween: Tween
var _shown_item_uid := -1
var _ammo_label: Label
var _ammo_hint: Label
var _ammo_panel: PanelContainer
var _fps_panel: PanelContainer
var _fps_label: Label
var _feed: VBoxContainer
var _death_panel: PanelContainer
var _death_label: Label
var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _indicator: DamageIndicator
var _status_panel: PanelContainer
var _hit_amount := 0.0
var _pulse_time := 0.0
var _score_center: CenterContainer
var _score_rows: VBoxContainer
var _pause: CenterContainer
var _audio: AudioStreamPlayer
var _hurt_audio: AudioStreamPlayer
var _last_ammo := -1


func _ready() -> void:
	add_to_group(&"hud")
	_build()
	GameState.hit_confirmed.connect(_on_hit_confirmed)
	GameState.damaged.connect(_on_damaged)
	GameState.kill_announced.connect(_on_kill)
	GameState.player_changed.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.player_added.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.player_removed.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.pings_updated.connect(_refresh_scoreboard)
	get_window().focus_exited.connect(_on_focus_lost)


func bind(player: Player) -> void:
	_player = player
	_indicator.bind(player)
	_hotbar.bind(player.equipment)
	_shown_item_uid = -1
	_hit_amount = 0.0
	_pause.visible = false
	_refresh_scoreboard()


func unbind() -> void:
	_player = null


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var info := _player.info
	_update_vignette(delta, info)
	_fps_panel.visible = Settings.value("show_fps")
	if _fps_panel.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_health_bar.value = lerpf(_health_bar.value, info.health, 0.25)
	_health_label.text = str(info.health)
	var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = UiStyle.TEAL if info.health > LOW_HEALTH else UiStyle.CORAL

	_speed_bar.value = _player.stamina
	_speed_fill.bg_color = UiStyle.CORAL if _player.exhausted else UiStyle.SUN

	_update_ammo(_player.equipment)
	_update_item_name(_player.equipment)

	_crosshair.hidden_for_sprint = _player.sprinting
	_death_panel.visible = not info.alive
	if not info.alive:
		var seconds := maxf(0.0, (info.respawn_tick - NetworkTime.tick) * NetworkTime.ticktime)
		_death_label.text = "Auć!\nWracasz za %d…" % ceili(seconds)
	_score_center.visible = Input.is_action_pressed("scoreboard")


## Po zmianie przedmiotu pokazuje na chwile jego nazwe w kolorze klasy.
func _update_item_name(equipment: Equipment) -> void:
	var stack := equipment.active_stack()
	var uid := ItemStack.uid_of(stack)
	if uid == _shown_item_uid:
		return
	var first_time := _shown_item_uid == -1
	_shown_item_uid = uid
	if _item_name_tween != null:
		_item_name_tween.kill()
	if first_time or ItemStack.is_empty(stack):
		_item_name_panel.modulate.a = 0.0
		return
	_item_name.text = ItemStack.display_name_of(stack)
	_item_name_style.bg_color = Rarity.color(ItemStack.tier_of(stack))
	_item_name_panel.modulate.a = 1.0
	_item_name_tween = create_tween()
	_item_name_tween.tween_interval(ITEM_NAME_SECONDS)
	_item_name_tween.tween_property(_item_name_panel, "modulate:a", 0.0, 0.3)


func _update_ammo(equipment: Equipment) -> void:
	var stats := equipment.active_stats()
	_ammo_panel.visible = stats != null
	if stats == null:
		_last_ammo = -1
		return
	var ammo := equipment.active_charges()
	_ammo_label.text = str(ammo)
	if equipment.is_reloading():
		_ammo_hint.text = "ładuję…"
	elif ammo == 0:
		_ammo_hint.text = "naciśnij R"
	else:
		_ammo_hint.text = "/ %d" % stats.magazine
	if ammo < _last_ammo:
		_crosshair.kick()
		_bump(_ammo_panel)
	_last_ammo = ammo


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


func _on_damaged(amount: int, attacker_id: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var strength := clampf(float(amount) / HEAVY_HIT_DAMAGE, 0.5, 1.0)
	_hit_amount = maxf(_hit_amount, 0.55 + strength * 0.45)
	_player.punch_camera(strength)
	_bump(_status_panel)
	_hurt_audio.stream = Sfx.hurt()
	_hurt_audio.play()
	var attacker := _player.get_parent().get_node_or_null(str(attacker_id)) as Player
	if attacker != null:
		_indicator.add_hit(attacker.position)


func _update_vignette(delta: float, info: Dictionary) -> void:
	_hit_amount = move_toward(_hit_amount, 0.0, delta * 1.6)
	_pulse_time += delta * 5.0
	var low := 0.0
	if info.alive and info.health <= LOW_HEALTH:
		# Im mniej zdrowia, tym mocniejszy rytm "bicia serca".
		var danger := 1.0 - float(info.health) / LOW_HEALTH
		low = (0.45 + danger * 0.3) * (0.75 + sin(_pulse_time) * 0.25)
	_vignette_material.set_shader_parameter("hit", _hit_amount)
	_vignette_material.set_shader_parameter("low_health", low)


func _on_kill(killer_id: int, victim_id: int) -> void:
	var row := PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 14, 3)
	style.set_content_margin_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(UiStyle.label(GameState.display_name(killer_id), 17, UiStyle.BLUE))
	line.add_child(UiStyle.label("✦", 15, UiStyle.CORAL))
	line.add_child(UiStyle.label(GameState.display_name(victim_id), 17, UiStyle.CORAL))
	row.add_child(line)
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
	_score_rows.add_child(_score_row("Gracz", "Zabójstwa", "Śmierci", "Ping", UiStyle.CORAL, UiStyle.CORAL))
	for id: int in ids:
		var info: Dictionary = GameState.players[id]
		var ping: int = GameState.pings.get(id, -1)
		var ping_text := "%d ms" % ping if ping >= 0 else "–"
		_score_rows.add_child(_score_row(info.name, str(info.kills), str(info.deaths), ping_text, UiStyle.INK, _ping_color(ping)))


func _ping_color(ping: int) -> Color:
	if ping < 0:
		return UiStyle.INK
	if ping < GOOD_PING:
		return UiStyle.TEAL.darkened(0.15)
	if ping < BAD_PING:
		return Color("d98a00")
	return UiStyle.CORAL.darkened(0.1)


func _score_row(player_name: String, kills: String, deaths: String, ping: String, color: Color, ping_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := UiStyle.label(player_name, 21, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	for value in [kills, deaths]:
		var cell := UiStyle.label(value, 21, color)
		cell.custom_minimum_size = Vector2(120, 0)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cell)
	var ping_cell := UiStyle.label(ping, 21, ping_color)
	ping_cell.custom_minimum_size = Vector2(90, 0)
	ping_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(ping_cell)
	return row


func _bump(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * 1.08
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.12)


func _anchored(preset: Control.LayoutPreset, offset: Vector2, grow_h: Control.GrowDirection, grow_v: Control.GrowDirection) -> Control:
	var node := Control.new()
	node.set_anchors_and_offsets_preset(preset)
	node.position += offset
	node.grow_horizontal = grow_h
	node.grow_vertical = grow_v
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node


func _build() -> void:
	_vignette = ColorRect.new()
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VIGNETTE_SHADER
	_vignette.material = _vignette_material
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)

	_indicator = DamageIndicator.new()
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_indicator)

	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_crosshair)

	_fps_panel = PanelContainer.new()
	var fps_style := UiStyle.sticker(UiStyle.PAPER, 14, 3)
	fps_style.set_content_margin_all(8)
	fps_style.content_margin_left = 14
	fps_style.content_margin_right = 14
	_fps_panel.add_theme_stylebox_override("panel", fps_style)
	_fps_panel.position = Vector2(24, 22)
	_fps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_panel)
	_fps_label = UiStyle.label("0 FPS", 17, UiStyle.INK)
	_fps_panel.add_child(_fps_label)

	_build_status_sticker()
	_build_ammo_sticker()

	_hotbar = Hotbar.new()
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.position.y -= 32.0
	add_child(_hotbar)

	var name_center := CenterContainer.new()
	name_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	name_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	name_center.position.y -= 150.0
	name_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_center)
	_item_name_panel = PanelContainer.new()
	_item_name_style = UiStyle.sticker(UiStyle.BLUE, 16, 4)
	_item_name_style.set_content_margin_all(7)
	_item_name_style.content_margin_left = 16
	_item_name_style.content_margin_right = 16
	_item_name_panel.add_theme_stylebox_override("panel", _item_name_style)
	_item_name_panel.modulate.a = 0.0
	_item_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_center.add_child(_item_name_panel)
	_item_name = UiStyle.label("", 19, Color.WHITE)
	_item_name_panel.add_child(_item_name)

	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.position += Vector2(-24, 22)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.add_theme_constant_override("separation", 6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	var death_center := CenterContainer.new()
	death_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_center)
	_death_panel = PanelContainer.new()
	_death_panel.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.CORAL, 26, 7))
	_death_panel.rotation_degrees = -3.0
	_death_panel.visible = false
	death_center.add_child(_death_panel)
	_death_label = UiStyle.label("", 38, Color.WHITE)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_panel.add_child(_death_label)

	_score_center = CenterContainer.new()
	_score_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_center.visible = false
	add_child(_score_center)
	var scoreboard := PanelContainer.new()
	scoreboard.custom_minimum_size = Vector2(700, 0)
	scoreboard.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_score_center.add_child(scoreboard)
	_score_rows = VBoxContainer.new()
	_score_rows.add_theme_constant_override("separation", 8)
	scoreboard.add_child(_score_rows)

	_pause = CenterContainer.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var pause_card := PanelContainer.new()
	pause_card.custom_minimum_size = Vector2(360, 0)
	pause_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_pause.add_child(pause_card)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	pause_card.add_child(pause_box)
	var pause_title := UiStyle.label("Pauza", 40, UiStyle.BLUE)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title)
	var resume := UiStyle.button("Wróć do gry", UiStyle.TEAL)
	resume.pressed.connect(_set_paused.bind(false))
	pause_box.add_child(resume)
	var settings_button := UiStyle.button("Ustawienia", UiStyle.BLUE)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	pause_box.add_child(settings_button)
	var disconnect_button := UiStyle.button("Rozłącz", UiStyle.CORAL)
	disconnect_button.pressed.connect(func() -> void: Net.leave())
	pause_box.add_child(disconnect_button)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_hurt_audio = AudioStreamPlayer.new()
	add_child(_hurt_audio)


func _build_status_sticker() -> void:
	var anchor := _anchored(Control.PRESET_BOTTOM_LEFT, Vector2(28, -28), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	var panel := PanelContainer.new()
	_status_panel = panel
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 22, 6))
	panel.rotation_degrees = -1.2
	panel.position = Vector2(0, -112)
	anchor.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 10)
	rows.add_child(health_row)
	_health_label = UiStyle.label("100", 30, UiStyle.INK)
	_health_label.custom_minimum_size = Vector2(62, 0)
	health_row.add_child(_health_label)
	_health_bar = UiStyle.bar(UiStyle.TEAL, 22)
	_health_bar.max_value = GameState.MAX_HEALTH
	_health_bar.value = GameState.MAX_HEALTH
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_row.add_child(_health_bar)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	rows.add_child(speed_row)
	var speed_name := UiStyle.label("speed", 16, UiStyle.INK)
	speed_name.custom_minimum_size = Vector2(62, 0)
	speed_row.add_child(speed_name)
	_speed_bar = UiStyle.bar(UiStyle.SUN, 14)
	_speed_bar.max_value = Player.STAMINA_MAX
	_speed_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_fill = _speed_bar.get_theme_stylebox("fill") as StyleBoxFlat
	speed_row.add_child(_speed_bar)


func _build_ammo_sticker() -> void:
	var anchor := _anchored(Control.PRESET_BOTTOM_RIGHT, Vector2(-28, -28), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_ammo_panel = PanelContainer.new()
	_ammo_panel.custom_minimum_size = Vector2(190, 84)
	_ammo_panel.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 22, 6))
	_ammo_panel.rotation_degrees = 1.5
	_ammo_panel.position = Vector2(-190, -88)
	anchor.add_child(_ammo_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ammo_panel.add_child(row)
	row.add_child(UiStyle.ammo_icon(Vector2(40, 40)))
	_ammo_label = UiStyle.label("12", 40, UiStyle.BLUE)
	row.add_child(_ammo_label)
	_ammo_hint = UiStyle.label("/ 12", 18, UiStyle.INK, false)
	row.add_child(_ammo_hint)
