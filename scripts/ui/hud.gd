class_name Hud
extends CanvasLayer
## Interfejs w grze: zdrowie, speed, amunicja, celownik, zabojstwa, wyniki i pauza.

signal settings_requested

const FEED_SECONDS := 5.0
const FEED_NAME_LENGTH := 18
const FEED_AVATAR_SIDE := 26.0
const FEED_WEAPON_ICON_SIDE := 30.0
const SCORE_AVATAR_SIDE := 34.0
const LOW_HEALTH := 35
const KILL_SHAKE := 0.28
const ITEM_NAME_SECONDS := 1.4
## Od tylu obrazen reakcja na trafienie jest najmocniejsza.
const HEAVY_HIT_DAMAGE := 40.0
const ELIMINATED_SECONDS := 3.0
const GOOD_PING := 60
const BAD_PING := 120
## Jak mocno gra ciemnieje za pauza i tabela wynikow.
const MODAL_SHADE_ALPHA := 0.55
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
var _prompt_panel: PanelContainer
var _prompt_style: StyleBoxFlat
var _prompt_action: Label
var _prompt_name: Label
var _prompt_bar: ProgressBar
var _drop_hint: Control
var _use_panel: PanelContainer
var _use_label: Label
var _use_bar: ProgressBar
var _heal_label: Label
var _heal_audio: AudioStreamPlayer
var _seen_health := -1
var _shown_prompt_id := -1
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
var _score_card: PanelContainer
var _pause_card: PanelContainer
var _resume_button: Button
var _score_rows: VBoxContainer
var _pause: CenterContainer
var _audio: AudioStreamPlayer
var _hurt_audio: AudioStreamPlayer
var _last_ammo := -1
var _dance_wheel: DanceWheel


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
	_close_dance_wheel()
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
	_update_prompt()
	_drop_hint.visible = not ItemStack.is_empty(_player.equipment.active_stack())
	_update_use_panel(_player.equipment)
	_update_heal_feedback(info)

	_crosshair.hidden_for_sprint = _player.sprinting or _player.dance_id != DanceCatalog.NONE
	if _dance_wheel.is_open and (not info.alive or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		_close_dance_wheel()
	# Kolo moglo zamknac sie samo, a przycisk myszy wciaz moze byc wcisniety.
	if _player.input.wheel_open != _dance_wheel.is_open:
		_player.input.set_wheel_open(_dance_wheel.is_open)
	_crosshair.aiming = _player.aiming
	_crosshair.spread_radius = _spread_on_screen(_player)
	_update_death_panel(info)
	var show_scores := Input.is_action_pressed("scoreboard")
	if show_scores != _score_center.visible:
		_score_center.visible = show_scores
		if show_scores:
			UiStyle.pop_in(_score_card)
			UiSound.play(Sfx.UiCue.PRESS)


## Celownik pokazuje, gdzie naprawde moze poleciec pocisk.
func _spread_on_screen(player: Player) -> float:
	var half_height := _crosshair.size.y * 0.5
	return half_height * tan(deg_to_rad(player.equipment.current_spread())) / tan(deg_to_rad(player.camera.fov * 0.5))


## Podpowiedz i pasek uzycia dla przedmiotow, ktore nie sa bronia.
func _update_use_panel(equipment: Equipment) -> void:
	var stack := equipment.active_stack()
	var behavior := ItemStack.behavior_of(stack)
	var text := behavior.current_label(equipment, stack) if behavior != null else ""
	_use_panel.visible = not text.is_empty() and Chests.focused_id == 0 and WorldItems.focused_id == 0
	if not _use_panel.visible:
		return
	_use_label.text = text
	var progress := behavior.current_progress(equipment, stack)
	_use_bar.visible = progress >= 0.0
	_use_bar.value = progress


## Leczenie widac na pasku zdrowia. Powrot po smierci to nie leczenie.
func _update_heal_feedback(info: Dictionary) -> void:
	var health: int = info.health
	if _seen_health > 0 and health > _seen_health:
		_bump(_status_panel)
		_heal_audio.stream = Sfx.heal()
		_heal_audio.play()
		_heal_label.text = "+%d" % (health - _seen_health)
		_heal_label.modulate.a = 1.0
		_heal_label.position.y = 0.0
		var tween := _heal_label.create_tween().set_parallel()
		tween.tween_property(_heal_label, "position:y", -36.0, 0.9)
		tween.tween_property(_heal_label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	_seen_health = health


## Podpowiedz nad paskiem przedmiotow, gdy gracz patrzy na cos do podniesienia.
func _update_prompt() -> void:
	if Chests.focused_id != 0:
		_show_chest_prompt()
		return
	_prompt_bar.visible = false
	var id := WorldItems.focused_id
	_prompt_panel.visible = id != 0 and WorldItems.items.has(id)
	if not _prompt_panel.visible:
		_shown_prompt_id = -1
		return
	var stack: Dictionary = WorldItems.items[id].stack
	var slots := _player.equipment.slots()
	var swaps := Inventory.first_free(slots) < 0
	_prompt_action.text = "Zamień na" if swaps else "Podnieś"
	if id == _shown_prompt_id:
		return
	_shown_prompt_id = id
	_prompt_name.text = ItemStack.display_name_of(stack)
	var color := Rarity.color(ItemStack.tier_of(stack))
	_prompt_style.border_color = color
	_prompt_name.add_theme_color_override("font_color", color.darkened(0.25))
	_bump(_prompt_panel)


## Skrzynke trzeba przytrzymac, wiec podpowiedz ma pasek postepu.
func _show_chest_prompt() -> void:
	_prompt_panel.visible = true
	var progress := Chests.local_progress()
	_prompt_bar.visible = progress > 0.0
	_prompt_bar.value = progress
	var id := -Chests.focused_id
	if id == _shown_prompt_id:
		return
	_shown_prompt_id = id
	_prompt_action.text = "Przytrzymaj, aby otworzyć"
	_prompt_name.text = "skrzynkę"
	_prompt_style.border_color = ChestView.TRIM_COLOR
	_prompt_name.add_theme_color_override("font_color", ChestView.BODY_COLOR)
	_bump(_prompt_panel)


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
	elif event.is_action_pressed("dance") and _player.is_alive() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_dance_wheel.open()
		_player.input.set_wheel_open(true)
	elif event is InputEventMouseButton and event.pressed and not _pause.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_dance_chosen(dance_id: int) -> void:
	_player.input.set_wheel_open(false)
	var started := _player.input.request_dance(dance_id)
	UiSound.play(Sfx.UiCue.CONFIRM if started else Sfx.UiCue.ERROR)


func _close_dance_wheel() -> void:
	_dance_wheel.cancel()
	if _player != null and is_instance_valid(_player):
		_player.input.set_wheel_open(false)


func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	UiSound.play(Sfx.UiCue.OPEN if paused else Sfx.UiCue.CLOSE)
	if paused:
		UiStyle.pop_in(_pause_card)
		# Fokus bez obwodki: Enter wraca do gry, a obwodka pojawi sie dopiero przy strzalkach.
		_resume_button.grab_focus(true)


## Przyciemnia gre za oknem i pojawia sie razem z nim, jakkolwiek okno zostanie otwarte.
func _add_shade_behind(target: Control) -> void:
	var shade := ColorRect.new()
	shade.color = Color(UiStyle.INK, MODAL_SHADE_ALPHA)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = target.visible
	add_child(shade)
	move_child(shade, target.get_index())
	target.visibility_changed.connect(func() -> void:
		if shade.visible == target.visible:
			return
		shade.visible = target.visible
		if shade.visible:
			shade.modulate.a = 0.0
			shade.create_tween().tween_property(shade, "modulate:a", 1.0, UiStyle.POP_SECONDS))


func _on_focus_lost() -> void:
	# Bez tego dwa okna na jednym komputerze walczylyby o kursor.
	if _player != null and visible and Net.bot_mode.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_hit_confirmed(killed: bool) -> void:
	_crosshair.flash_hit(killed)
	if killed and _player != null and is_instance_valid(_player):
		_player.shake_camera(KILL_SHAKE)
	_audio.stream = Sfx.kill() if killed else Sfx.hit()
	_audio.play()


func _on_damaged(amount: int, attacker_id: int, source: Vector3) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var strength := clampf(float(amount) / HEAVY_HIT_DAMAGE, 0.5, 1.0)
	_hit_amount = maxf(_hit_amount, 0.55 + strength * 0.45)
	_player.punch_camera(strength)
	_bump(_status_panel)
	_hurt_audio.stream = Sfx.hurt()
	_hurt_audio.play()
	if source != Vector3.INF:
		_indicator.add_hit(source)
		return
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
	line.add_child(_avatar_of(killer_id, FEED_AVATAR_SIDE))
	line.add_child(UiStyle.label(_short_name(killer_id), 17, UiStyle.BLUE))
	line.add_child(_kill_cause(victim_id))
	line.add_child(_avatar_of(victim_id, FEED_AVATAR_SIDE))
	line.add_child(UiStyle.label(_short_name(victim_id), 17, UiStyle.CORAL))
	if Match.is_elimination():
		line.add_child(UiStyle.label("· zostało %d" % Match.alive_count(victim_id), 15, Color(UiStyle.INK, 0.65), false))
	row.add_child(line)
	_feed.add_child(row)
	var tween := row.create_tween()
	tween.tween_interval(FEED_SECONDS)
	tween.tween_property(row, "modulate:a", 0.0, 0.4)
	tween.tween_callback(row.queue_free)


## Bron z ikona i nazwa w kolorze klasy. Smierc w strefie ma tylko znaczek.
func _kill_cause(victim_id: int) -> Control:
	var info: Dictionary = GameState.players.get(victim_id, {})
	var weapon: Dictionary = info.get("death_weapon", {})
	if ItemStack.definition_of(weapon) == null:
		return UiStyle.label("✦", 15, UiStyle.CORAL)
	var cause := HBoxContainer.new()
	cause.add_theme_constant_override("separation", 4)
	var visual := ItemStack.visual_of(weapon)
	if visual != null and ResourceLoader.exists(visual.icon_path):
		var icon := TextureRect.new()
		icon.texture = load(visual.icon_path) as Texture2D
		icon.custom_minimum_size = Vector2.ONE * FEED_WEAPON_ICON_SIDE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cause.add_child(icon)
	cause.add_child(UiStyle.label(ItemStack.display_name_of(weapon), 15, Rarity.color(ItemStack.tier_of(weapon)).darkened(0.25)))
	return cause


func _avatar_of(id: int, side: float) -> AvatarView:
	return AvatarView.new(GameState.steam_id_of(id), GameState.display_name(id), side)


## Po eliminacji znika to, co dotyczy wlasnej postaci, a napis o miejscu znika po chwili.
func _update_death_panel(info: Dictionary) -> void:
	var watching: bool = Match.is_elimination() and not info.alive
	_status_panel.visible = not watching
	_hotbar.visible = not watching
	_crosshair.visible = not watching
	if not Match.is_elimination():
		_death_panel.visible = not info.alive
		if not info.alive:
			var seconds := maxf(0.0, (info.respawn_tick - NetworkTime.tick) * NetworkTime.ticktime)
			_death_label.text = "Auć!\nWracasz za %d…" % ceili(seconds)
		return
	var fresh: bool = NetworkTime.tick < info.death_tick + NetworkTime.seconds_to_ticks(ELIMINATED_SECONDS)
	_death_panel.visible = watching and info.in_match and fresh
	if _death_panel.visible:
		_death_label.text = "Odpadasz!\nMiejsce %d" % info.place if info.place > 0 else "Odpadasz!"


## Nazwy ze Steama bywaja dlugie, a lista zabojstw musi sie zmiescic przy krawedzi ekranu.
func _short_name(id: int) -> String:
	var full := GameState.display_name(id)
	return full if full.length() <= FEED_NAME_LENGTH else full.left(FEED_NAME_LENGTH - 1) + "…"


func _refresh_scoreboard() -> void:
	if _score_rows == null:
		return
	for child in _score_rows.get_children():
		child.free()
	var ids := GameState.players.keys()
	var elimination := Match.is_elimination()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var first: Dictionary = GameState.players[a]
		var second: Dictionary = GameState.players[b]
		if elimination and first.alive != second.alive:
			return first.alive
		return first.kills > second.kills)
	_score_rows.add_child(_score_row("Gracz", "Zabójstwa", "Status" if elimination else "Śmierci", "Ping", UiStyle.CORAL, UiStyle.CORAL))
	for id: int in ids:
		var info: Dictionary = GameState.players[id]
		var ping: int = GameState.pings.get(id, -1)
		var ping_text := "%d ms" % ping if ping >= 0 else "–"
		var middle := _match_status(info) if elimination else str(info.deaths)
		var row := _score_row(info.name, str(info.kills), middle, ping_text, UiStyle.INK, _ping_color(ping))
		row.add_child(_avatar_of(id, SCORE_AVATAR_SIDE))
		row.move_child(row.get_child(-1), 0)
		_score_rows.add_child(row)


## Co gracz robi teraz w Battle Royale.
func _match_status(info: Dictionary) -> String:
	if Match.can_change_ready():
		return "gotowy" if info.ready else "czeka"
	if not info.in_match:
		return "ogląda"
	if info.place > 0:
		return "miejsce %d" % info.place
	return "żyje" if info.alive else "odpadł"


func _ping_color(ping: int) -> Color:
	if ping < 0:
		return UiStyle.INK
	if ping < GOOD_PING:
		return UiStyle.TEAL.darkened(0.15)
	if ping < BAD_PING:
		return Color("d98a00")
	return UiStyle.CORAL.darkened(0.1)


func _score_row(player_name: String, kills: String, middle: String, ping: String, color: Color, ping_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := UiStyle.label(player_name, 21, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	for value in [kills, middle]:
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

	_dance_wheel = DanceWheel.new()
	_dance_wheel.chosen.connect(_on_dance_chosen)
	add_child(_dance_wheel)

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

	var net_graph := NetGraph.new()
	net_graph.position = Vector2(24, 72)
	add_child(net_graph)

	_build_status_sticker()
	_build_ammo_sticker()
	add_child(MatchPanel.new())

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

	_build_prompt()
	_build_drop_hint()
	_build_use_panel()

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
	_score_card = PanelContainer.new()
	_score_card.custom_minimum_size = Vector2(700, 0)
	_score_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_score_center.add_child(_score_card)
	_score_rows = VBoxContainer.new()
	_score_rows.add_theme_constant_override("separation", 8)
	_score_card.add_child(_score_rows)
	_add_shade_behind(_score_center)

	_pause = CenterContainer.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	_pause_card = PanelContainer.new()
	_pause_card.custom_minimum_size = Vector2(360, 0)
	_pause_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_pause.add_child(_pause_card)
	_add_shade_behind(_pause)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	_pause_card.add_child(pause_box)
	var pause_title := UiStyle.label("Pauza", 40, UiStyle.BLUE)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title)
	_resume_button = UiStyle.button("Wróć do gry", UiStyle.TEAL, Color.WHITE, Sfx.UiCue.NONE)
	_resume_button.pressed.connect(_set_paused.bind(false))
	pause_box.add_child(_resume_button)
	var settings_button := UiStyle.button("Ustawienia", UiStyle.BLUE, Color.WHITE, Sfx.UiCue.NONE)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	pause_box.add_child(settings_button)
	var disconnect_button := UiStyle.button("Rozłącz", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.BACK)
	disconnect_button.pressed.connect(func() -> void: Net.leave())
	pause_box.add_child(disconnect_button)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_hurt_audio = AudioStreamPlayer.new()
	add_child(_hurt_audio)


func _build_prompt() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	center.position.y -= 200.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_prompt_panel = PanelContainer.new()
	_prompt_style = UiStyle.sticker(UiStyle.PAPER, 18, 5)
	_prompt_style.set_content_margin_all(8)
	_prompt_style.content_margin_left = 12
	_prompt_style.content_margin_right = 18
	_prompt_panel.add_theme_stylebox_override("panel", _prompt_style)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	center.add_child(_prompt_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_prompt_panel.add_child(rows)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	rows.add_child(row)
	_prompt_bar = UiStyle.bar(UiStyle.SUN, 12)
	_prompt_bar.max_value = 1.0
	_prompt_bar.step = 0.0
	_prompt_bar.visible = false
	rows.add_child(_prompt_bar)
	row.add_child(UiStyle.key_chip("E", 36, 20))
	_prompt_action = UiStyle.label("Podnieś", 20, UiStyle.INK, false)
	row.add_child(_prompt_action)
	_prompt_name = UiStyle.label("", 21, UiStyle.INK)
	row.add_child(_prompt_name)


func _build_use_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	center.position.y -= 200.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_use_panel = PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 18, 5)
	style.set_content_margin_all(9)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.border_color = UiStyle.TEAL
	_use_panel.add_theme_stylebox_override("panel", style)
	_use_panel.custom_minimum_size = Vector2(300, 0)
	_use_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_panel.visible = false
	center.add_child(_use_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_use_panel.add_child(rows)
	_use_label = UiStyle.label("", 19, UiStyle.INK)
	_use_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_use_label)
	_use_bar = UiStyle.bar(UiStyle.TEAL, 12)
	_use_bar.max_value = 1.0
	_use_bar.step = 0.0
	_use_bar.visible = false
	rows.add_child(_use_bar)

	# Liczba przy pasku zdrowia po uleczeniu.
	var heal_anchor := _anchored(Control.PRESET_BOTTOM_LEFT, Vector2(300, -160), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	_heal_label = UiStyle.label("", 34, UiStyle.TEAL)
	_heal_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_heal_label.add_theme_constant_override("outline_size", 8)
	_heal_label.modulate.a = 0.0
	heal_anchor.add_child(_heal_label)
	_heal_audio = AudioStreamPlayer.new()
	add_child(_heal_audio)


## Przypomnienie o wyrzucaniu tuz obok paska przedmiotow.
func _build_drop_hint() -> void:
	var anchor := _anchored(Control.PRESET_CENTER_BOTTOM, Vector2(226, -66), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = 0.8
	anchor.add_child(row)
	row.add_child(UiStyle.key_chip("G", 28, 16))
	var label := UiStyle.label("wyrzuć", 16, Color.WHITE)
	label.add_theme_color_override("font_outline_color", UiStyle.INK)
	label.add_theme_constant_override("outline_size", 5)
	row.add_child(label)
	_drop_hint = row


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
