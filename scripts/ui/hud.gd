class_name Hud
extends CanvasLayer
## Interfejs w grze: zdrowie, speed, amunicja, celownik, zabojstwa, wyniki i pauza.

signal settings_requested

## Lista zabojstw: najwyzej 300 x 150 px w prawym gornym rogu.
const FEED_SECONDS := 4.0
const FEED_NAME_LENGTH := 12
const FEED_MAX_ROWS := 4
const FEED_AVATAR_SIDE := 20.0
const FEED_WEAPON_ICON_SIDE := 22.0
const FEED_FONT := 15
const FEED_ROW_MARGIN := 5
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
## Napisy w dolnej czesci ekranu: podpowiedz stoi tuz nad paskiem przedmiotow, w miejscu nazwy
## przedmiotu, a martwy gracz ma tam napis o smierci. Strefa walki zostaje wolna (docs/UI.md, punkt 6).
const ITEM_LINE_BOTTOM := 126.0
const PROMPT_MAX_WIDTH := 320.0
const PROMPT_FONT := 17
const DEATH_FONT := 19
## Szerszy napis o smierci dotknalby czatu przy lewej krawedzi.
const DEATH_MAX_WIDTH := 500.0
## Napis o smierci jest szerszy niz podpowiedz, wiec stoi troche wyzej, nad numerami slotow.
const DEATH_LIFT := 8.0
## Seria ma ten sam rozmiar co baner rundy, bo stoi w jego miejscu.
const STREAK_SECONDS := 2.0
## Przy celowaniu elementy poboczne bledna, zeby nie odciagaly wzroku.
const AIM_DIM_ALPHA := 0.35
const AIM_DIM_SECONDS := 0.15
const VIGNETTE_SHADER := preload("res://shaders/damage_vignette.gdshader")

var _player: Player
var _crosshair: Crosshair
var _scope: ScopeOverlay
var _health_bar: ProgressBar
var _health_label: Label
var _speed_bar: ProgressBar
var _regen_label: Label
var _regen_was_active := false
var _regen_interrupted_until := 0.0
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
## Przedmiot ma tu swoj numer, a skrzynka numer ujemny. 0 oznacza, ze nic nie pokazano.
var _shown_prompt_id := 0
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
var _streak_panel: PanelContainer
var _streak_label: Label
var _streak_tween: Tween
var _streak_audio: AudioStreamPlayer
var _protection_label: Label
var _chat: ChatPanel
var _match_panel: MatchPanel
var _team_panel: TeamPanel
## Glosowanie na mape po rundzie Deathmatchu: wtedy kursor jest widoczny, zeby kliknac karte mapy.
var _voting := false
var _top_left: VBoxContainer
var _name_center: Control
var _prompt_center: Control
var _use_center: Control
var _streak_center: Control
var _death_center: Control
var _round_panel: RoundPanel
## Przezroczystosc elementow pobocznych: 1 normalnie, AIM_DIM_ALPHA przy celowaniu.
var _side_alpha := 1.0


func _ready() -> void:
	add_to_group(&"hud")
	_build()
	GameState.hit_details.connect(_on_hit_details)
	GameState.streak_announced.connect(_on_streak)
	GameState.damaged.connect(_on_damaged)
	GameState.kill_announced.connect(_on_kill)
	GameState.player_changed.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.player_added.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.player_removed.connect(func(_id: int) -> void: _refresh_scoreboard())
	GameState.pings_updated.connect(_refresh_scoreboard)
	Match.team_scores_changed.connect(_refresh_scoreboard)
	get_window().focus_exited.connect(_on_focus_lost)


func bind(player: Player) -> void:
	_player = player
	_indicator.bind(player)
	_hotbar.bind(player.equipment)
	_shown_item_uid = -1
	_hit_amount = 0.0
	_pause.visible = false
	_refresh_scoreboard()


## Samouczek stoi w lewej kolumnie, w miejscu karty "Najlepsi", ktora na poczatku walki i tak jest pusta.
func show_tutorial() -> void:
	_top_left.add_child(TutorialPanel.new())


func unbind() -> void:
	_close_dance_wheel()
	_player = null
	_chat.close()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var info := _player.info
	_update_vignette(delta, info)
	_update_vote_cursor()
	_update_team_panel()
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
	# Martwy gracz niczego nie podnosi, a podpowiedz stalaby pod napisem o smierci.
	if not info.alive:
		_prompt_panel.visible = false
		_use_panel.visible = false
	# Nazwa przedmiotu, podpowiedz i napis o smierci stoja w tym samym miejscu.
	_item_name_panel.visible = info.alive and not _prompt_panel.visible and not _use_panel.visible
	_update_top_message()
	_update_heal_feedback(info)
	_update_regen(info)

	_crosshair.hidden_for_sprint = _player.sprinting or _player.dance_id != DanceCatalog.NONE
	if _dance_wheel.is_open and (not info.alive or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		_close_dance_wheel()
	# Kolo moglo zamknac sie samo, a przycisk myszy wciaz moze byc wcisniety.
	if _player.input.wheel_open != _dance_wheel.is_open:
		_player.input.set_wheel_open(_dance_wheel.is_open)
	_crosshair.aiming = _player.aiming
	_crosshair.ally_color = _ally_in_sight()
	var dim := _player.aiming and not _player.is_scoped()
	_side_alpha = move_toward(_side_alpha, AIM_DIM_ALPHA if dim else 1.0, delta * (1.0 - AIM_DIM_ALPHA) / AIM_DIM_SECONDS)
	_update_clutter()
	_scope.amount = move_toward(_scope.amount, 1.0 if _player.is_scoped() else 0.0, get_process_delta_time() * (5.0 if _player.is_scoped() else 12.0))
	_crosshair.visible = _crosshair.visible and _scope.amount < 0.5
	_crosshair.spread_radius = _spread_on_screen(_player)
	_update_death_panel(info)
	var show_scores := Input.is_action_pressed("scoreboard") and not _chat.is_open
	if show_scores != _score_center.visible:
		_score_center.visible = show_scores
		if show_scores:
			UiStyle.pop_in(_score_card)
			UiSound.play(Sfx.UiCue.PRESS)


## W lunecie znika caly interfejs poza nia. Na ekranie wynikow znika wszystko, co dotyczy walki:
## pasek przedmiotow, zdrowie, amunicja, celownik, podpowiedzi i napis o smierci, zeby nie nachodzily
## na karte wynikow i podium. Przy celowaniu bledna elementy poboczne: lewa kolumna (FPS, wykres
## sieci, "Najlepsi", samouczek), lista zabojstw i zamkniety czat. Wszystko w jednym miejscu, zeby
## jedno ustawienie nie nadpisywalo drugiego.
func _update_clutter() -> void:
	var scoped := _scope.amount > 0.5
	var results := Match.phase == Match.Phase.RESULTS
	for child in get_children():
		if child is CanvasItem and child != _scope:
			(child as CanvasItem).modulate.a = 0.0 if scoped else 1.0
	var combat := 0.0 if results or scoped else 1.0
	for control: CanvasItem in [_hotbar, _status_panel, _ammo_panel, _drop_hint, _crosshair, _indicator,
			_name_center, _prompt_center, _use_center, _streak_center, _death_center]:
		control.modulate.a = combat
	if scoped:
		return
	_top_left.modulate.a = _side_alpha
	_feed.modulate.a = _side_alpha
	_chat.modulate.a = 1.0 if _chat.is_open else _side_alpha


## Baner rundy, seria i odliczanie stoja w jednym miejscu pod zegarem. Odliczanie i ostrzezenie
## o strefie maja pierwszenstwo.
func _update_top_message() -> void:
	if not _match_panel.is_counting() and not _match_panel.is_warning_outside():
		return
	_round_panel.hide_banner()
	_streak_panel.visible = false


## Kolor druzyny sojusznika na linii strzalu albo przezroczysty. Sciana przed nim go zaslania.
func _ally_in_sight() -> Color:
	if not Teams.is_active() or not _player.is_alive():
		return Color.TRANSPARENT
	var from := _player.eye_position()
	var direction := Hitscan.direction(_player.input.look_yaw, _player.input.look_pitch)
	var reach := 120.0
	var wall := _player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * reach, Hitscan.WORLD_MASK))
	if not wall.is_empty():
		reach = from.distance_to(wall.position)
	for node in get_tree().get_nodes_in_group(&"players"):
		var other := node as Player
		if other == _player or not other.is_alive() or not Teams.are_allies(_player.peer_id, other.peer_id):
			continue
		var bottom := other.position + Vector3.UP * 0.2
		var top := other.position + Vector3.UP * 1.6
		var closest := Geometry3D.get_closest_points_between_segments(from, from + direction * reach, bottom, top)
		if closest[0].distance_to(closest[1]) < 0.45:
			return Teams.color_of(Teams.team_of(other.peer_id))
	return Color.TRANSPARENT


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
	# Regeneracja dodaje po pare punktow kilka razy na sekunde, wiec nie gra dzwieku za kazdym razem.
	if _seen_health > 0 and health > _seen_health and not GameState.is_regenerating(info):
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


## Regeneracja w Deathmatchu: widac, ze trwa, ile zostalo do jej startu i ze trafienie ja przerwalo.
func _update_regen(info: Dictionary) -> void:
	var from: int = info.get("regen_tick", -1)
	var active := GameState.is_regenerating(info)
	var waiting: bool = info.alive and from >= 0 and not active and info.health < GameState.MAX_HEALTH
	var now := Time.get_ticks_msec() / 1000.0
	if _regen_was_active and waiting:
		_regen_interrupted_until = now + 1.2
		_bump(_status_panel)
	_regen_was_active = active
	_regen_label.visible = active or waiting
	if not _regen_label.visible:
		return
	if now < _regen_interrupted_until:
		_regen_label.text = "Leczenie przerwane!"
		_regen_label.add_theme_color_override("font_color", UiStyle.CORAL)
	elif active:
		_regen_label.text = "+ Leczenie %d/s" % roundi(GameState.REGEN_PER_SECOND)
		_regen_label.add_theme_color_override("font_color", UiStyle.TEAL.darkened(0.2))
		_regen_label.modulate.a = 0.75 + sin(now * 6.0) * 0.25
		return
	else:
		var seconds := ceili((from - NetworkTime.tick) * NetworkTime.ticktime)
		_regen_label.text = "Leczenie za %d s" % seconds
		_regen_label.add_theme_color_override("font_color", Color(UiStyle.INK, 0.6))
	_regen_label.modulate.a = 1.0


## Podpowiedz nad paskiem przedmiotow, gdy gracz patrzy na cos do podniesienia.
func _update_prompt() -> void:
	if Chests.focused_id != 0:
		_show_chest_prompt()
		return
	_prompt_bar.visible = false
	var id := WorldItems.focused_id
	_prompt_panel.visible = id != 0 and WorldItems.items.has(id)
	if not _prompt_panel.visible:
		_shown_prompt_id = 0
		return
	var stack: Dictionary = WorldItems.items[id].stack
	var slots := _player.equipment.slots()
	var swaps := Inventory.first_free(slots) < 0
	var action := "Zamień na" if swaps else "Podnieś"
	if action != _prompt_action.text:
		_prompt_action.text = action
		_fit_prompt()
	if id == _shown_prompt_id:
		return
	_shown_prompt_id = id
	_prompt_name.text = ItemStack.display_name_of(stack)
	_fit_prompt()
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
	_prompt_action.text = "Otwórz"
	_prompt_name.text = "skrzynkę"
	_fit_prompt()
	_prompt_style.border_color = ChestView.TRIM_COLOR
	_prompt_name.add_theme_color_override("font_color", ChestView.BODY_COLOR)
	_bump(_prompt_panel)


## Cala podpowiedz miesci sie w PROMPT_MAX_WIDTH. Skraca sie nazwa przedmiotu, a nie czynnosc.
func _fit_prompt() -> void:
	var fixed := _prompt_action.get_minimum_size().x + _prompt_row_extra()
	UiStyle.fit_width(_prompt_name, maxf(PROMPT_MAX_WIDTH - fixed, 40.0))


## Klawisz, odstepy i marginesy podpowiedzi, czyli wszystko poza dwoma napisami.
func _prompt_row_extra() -> float:
	var row := _prompt_action.get_parent() as HBoxContainer
	var chip := row.get_child(0) as Control
	return chip.get_combined_minimum_size().x + row.get_theme_constant("separation") * 2 + _prompt_style.content_margin_left + _prompt_style.content_margin_right


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
		_ammo_hint.text = "naciśnij %s" % Keybinds.label_of("reload")
	else:
		_ammo_hint.text = "/ %d" % stats.magazine
	if ammo < _last_ammo:
		_crosshair.kick()
		_bump(_ammo_panel)
	_last_ammo = ammo


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not visible or not Net.bot_mode.is_empty():
		return
	if _chat.is_open:
		# Klikniecie obok pola wraca do gry. Scroll przewija historie.
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_chat.close()
	elif event.is_action_pressed("pause"):
		_set_paused(not _pause.visible)
	elif (event.is_action_pressed("chat") or (event.is_action_pressed("team_chat") and Teams.is_active())) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_chat.open(event.is_action_pressed("team_chat"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("team_select") and Teams.is_active() and not _team_panel.visible:
		_team_panel.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dance") and _player.is_alive() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_dance_wheel.open()
		_player.input.set_wheel_open(true)
	elif event is InputEventMouseButton and event.pressed and not _pause.visible and not Match.can_vote() and not _team_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_dance_chosen(dance_id: int) -> void:
	_player.input.set_wheel_open(false)
	var started := _player.input.request_dance(dance_id)
	UiSound.play(Sfx.UiCue.CONFIRM if started else Sfx.UiCue.ERROR)


## Klikniecie, ktore zamknelo czat, nie moze jeszcze wystrzelic.
func _on_chat_closed() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	Input.mouse_mode = _game_mouse_mode()
	_player.input.block_fire()


## Bez okna na wierzchu kursor jest schowany, chyba ze trwa glosowanie na mape.
func _game_mouse_mode() -> Input.MouseMode:
	return Input.MOUSE_MODE_VISIBLE if Match.can_vote() or _team_panel.visible else Input.MOUSE_MODE_CAPTURED


## Gracz bez druzyny ma przed soba wybor druzyny i kursor, zeby kliknac karte.
func _update_team_panel() -> void:
	if not _team_panel.must_choose() or _team_panel.visible or Match.phase == Match.Phase.RESULTS:
		return
	_team_panel.open()
	if not _pause.visible and get_window().has_focus() and Net.bot_mode.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_team_panel_closed() -> void:
	if _player == null or not is_instance_valid(_player) or _pause.visible:
		return
	Input.mouse_mode = _game_mouse_mode()
	_player.input.block_fire()


## Glosowanie odslania kursor, a jego koniec chowa go z powrotem. Klikniecie karty nie strzela.
func _update_vote_cursor() -> void:
	if _voting == Match.can_vote() or not Net.bot_mode.is_empty():
		return
	_voting = Match.can_vote()
	if _pause.visible or _chat.is_open or not get_window().has_focus():
		return
	Input.mouse_mode = _game_mouse_mode()
	_player.input.block_fire()


func _close_dance_wheel() -> void:
	_dance_wheel.cancel()
	if _player != null and is_instance_valid(_player):
		_player.input.set_wheel_open(false)


func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else _game_mouse_mode()
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


func _on_hit_details(details: Dictionary) -> void:
	var killed: bool = details.get("killed", false)
	var headshot: bool = details.get("headshot", false)
	var kind := Crosshair.hit_kind(killed, headshot, StringName(details.get("item", &"")) == &"awp")
	_crosshair.flash_kind(kind)
	if killed and _player != null and is_instance_valid(_player):
		_player.shake_camera(KILL_SHAKE)
	_audio.stream = hit_sound(kind)
	_audio.play()


## Kazdy rodzaj trafienia brzmi inaczej, wiec bez patrzenia wiadomo, co sie stalo.
static func hit_sound(kind: String) -> AudioStreamWAV:
	match kind:
		"headshot":
			return Sfx.headshot()
		"kill":
			return Sfx.kill()
		"kill_headshot":
			return Sfx.kill_headshot()
		"sniper":
			return Sfx.sniper_ding()
	return Sfx.hit()


## Pierwsza krew, podwojne i potrojne zabojstwo, seria i jej przerwanie. Wlasny wyczyn to krotki
## napis na srodku ekranu bez nazwy gracza, a cudzy to zolty wiersz na liscie zabojstw.
func _on_streak(kind: String, killer_id: int, victim_id: int, count: int) -> void:
	var mine := killer_id == multiplayer.get_unique_id()
	var text := streak_text(kind, count, "" if mine else _short_name(killer_id), _short_name(victim_id))
	if text.is_empty():
		return
	if mine or kind == "first_blood":
		_streak_audio.stream = Sfx.streak()
		_streak_audio.play()
	if not mine:
		var label := UiStyle.label(text, FEED_FONT, UiStyle.INK)
		_add_feed_row(label, UiStyle.SUN)
		return
	# Odliczanie i ostrzezenie o strefie maja pierwszenstwo przed seria, a seria zastepuje baner rundy.
	if _match_panel.is_counting() or _match_panel.is_warning_outside():
		return
	_round_panel.hide_banner()
	_streak_label.text = text
	UiStyle.fit_width(_streak_label, RoundPanel.BANNER_MAX_WIDTH)
	_streak_panel.visible = true
	UiStyle.pop_in(_streak_panel)
	if _streak_tween != null:
		_streak_tween.kill()
	_streak_tween = create_tween()
	_streak_tween.tween_interval(STREAK_SECONDS)
	_streak_tween.tween_callback(func() -> void: _streak_panel.visible = false)


## Pusty "killer" oznacza wlasny wyczyn, wiec napis mowi do gracza.
static func streak_text(kind: String, count: int, killer: String, victim: String) -> String:
	var you := killer.is_empty()
	match kind:
		"first_blood":
			return "Pierwsza krew!" if you else "Pierwsza krew: %s" % killer
		"double":
			return "Podwójne zabójstwo!" if you else "%s: podwójne" % killer
		"triple":
			if you:
				return "Potrójne zabójstwo!" if count == 3 else "%d zabójstwa naraz!" % count
			return "%s: potrójne" % killer if count == 3 else "%s: %d naraz" % [killer, count]
		"streak":
			return "Seria %d!" % count if you else "%s: seria %d" % [killer, count]
		"ended":
			return "Przerywasz serię: %s" % victim if you else "%s przerywa serię" % killer
	return ""


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
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.add_child(_avatar_of(killer_id, FEED_AVATAR_SIDE))
	line.add_child(UiStyle.label(_short_name(killer_id), FEED_FONT, Teams.player_color(killer_id, UiStyle.BLUE).darkened(0.1 if Teams.is_active() else 0.0)))
	line.add_child(_kill_cause(victim_id))
	if GameState.players.get(victim_id, {}).get("death_headshot", false):
		line.add_child(UiStyle.label("◎", FEED_FONT, Color("d99a00")))
	line.add_child(_avatar_of(victim_id, FEED_AVATAR_SIDE))
	line.add_child(UiStyle.label(_short_name(victim_id), FEED_FONT, Teams.player_color(victim_id, UiStyle.CORAL).darkened(0.1 if Teams.is_active() else 0.0)))
	# Liczbe zywych w Battle Royale podaje pasek u gory, wiec wiersz zostaje krotki.
	_add_feed_row(line, UiStyle.PAPER)


## Lista ma kilka wierszy, zeby nie zjechac na srodek ekranu. Najstarszy znika od razu.
func _add_feed_row(content: Control, color: Color) -> void:
	var row := PanelContainer.new()
	var style := UiStyle.sticker(color, 12, 3)
	style.set_content_margin_all(FEED_ROW_MARGIN)
	style.content_margin_left = 3 + 8
	style.content_margin_right = 3 + 8
	row.add_theme_stylebox_override("panel", style)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(content)
	_feed.add_child(row)
	while _feed.get_child_count() > FEED_MAX_ROWS:
		_feed.get_child(0).free()
	var tween := row.create_tween()
	tween.tween_interval(FEED_SECONDS)
	tween.tween_property(row, "modulate:a", 0.0, 0.4)
	tween.tween_callback(row.queue_free)


## Bron to sama ikona w kolorze klasy, a nazwa tylko wtedy, gdy ikony brak. Smierc w strefie ma znaczek.
func _kill_cause(victim_id: int) -> Control:
	var info: Dictionary = GameState.players.get(victim_id, {})
	var weapon: Dictionary = info.get("death_weapon", {})
	if ItemStack.definition_of(weapon) == null:
		return UiStyle.label("✦", FEED_FONT, UiStyle.CORAL)
	var cause := HBoxContainer.new()
	cause.add_theme_constant_override("separation", 4)
	var visual := ItemStack.visual_of(weapon)
	var tint := Rarity.color(ItemStack.tier_of(weapon))
	if visual != null and ResourceLoader.exists(visual.icon_path):
		var icon := TextureRect.new()
		icon.texture = load(visual.icon_path) as Texture2D
		icon.custom_minimum_size = Vector2.ONE * FEED_WEAPON_ICON_SIDE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cause.add_child(icon)
		# Pasek w kolorze klasy przed ikona zastepuje dluga nazwe broni.
		var stripe := ColorRect.new()
		stripe.color = tint
		stripe.custom_minimum_size = Vector2(4, FEED_WEAPON_ICON_SIDE * 0.7)
		stripe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cause.add_child(stripe)
		cause.move_child(stripe, 0)
	else:
		cause.add_child(UiStyle.label(ItemStack.display_name_of(weapon), FEED_FONT, tint.darkened(0.25)))
	return cause


func _avatar_of(id: int, side: float) -> AvatarView:
	return AvatarView.new(GameState.steam_id_of(id), GameState.display_name(id), side)


## Po eliminacji znika to, co dotyczy wlasnej postaci, a napis o miejscu znika po chwili.
func _update_death_panel(info: Dictionary) -> void:
	var watching: bool = Match.is_elimination() and not info.alive
	_status_panel.visible = not watching
	_hotbar.visible = not watching
	_crosshair.visible = not watching and _scope.amount < 0.5
	if not Match.is_elimination():
		_death_panel.visible = not info.alive and info.in_match
		# W Team Deathmatchu tlo ma kolor druzyny zabojcy.
		var killer_team := Teams.team_of(info.get("killer_id", 0)) if Teams.is_active() else Teams.NONE
		(_death_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Teams.color_of(killer_team) if killer_team != Teams.NONE else UiStyle.CORAL
		if not info.alive:
			var seconds := maxf(0.0, (info.respawn_tick - NetworkTime.tick) * NetworkTime.ticktime)
			_death_label.text = "%s\nWracasz za %d" % [_death_cause(info, multiplayer.get_unique_id()), ceili(seconds)]
			UiStyle.fit_width(_death_label, DEATH_MAX_WIDTH)
		_protection_label.visible = info.alive and NetworkTime.tick < info.get("protected_until", -1)
		return
	var fresh: bool = NetworkTime.tick < info.death_tick + NetworkTime.seconds_to_ticks(ELIMINATED_SECONDS)
	# Ekran wynikow podaje juz miejsce, a napis by go zaslonil.
	_death_panel.visible = watching and info.in_match and fresh and Match.phase != Match.Phase.RESULTS
	if _death_panel.visible:
		_death_label.text = "Odpadasz!\nMiejsce %d" % info.place if info.place > 0 else "Odpadasz!"
		UiStyle.fit_width(_death_label, DEATH_MAX_WIDTH)


## Kto zabil, czym i ile zdrowia mu zostalo. Smierc od strefy albo wlasnego granatu ma krotszy opis.
func _death_cause(info: Dictionary, victim_id: int) -> String:
	var killer: int = info.get("killer_id", 0)
	if killer == GameState.ZONE_ATTACKER or not GameState.players.has(killer):
		return "Auć!"
	if killer == victim_id:
		return "Własny granat!"
	var weapon := ItemStack.display_name_of(info.get("death_weapon", {}))
	var head := " w głowę" if info.get("death_headshot", false) else ""
	return "Zabija Cię %s%s · %s · zostało mu %d HP" % [_short_name(killer), head, weapon, info.get("killer_health", 0)]


## Nazwy ze Steama bywaja dlugie, a lista zabojstw musi sie zmiescic przy krawedzi ekranu.
func _short_name(id: int) -> String:
	var full := GameState.display_name(id)
	return full if full.length() <= FEED_NAME_LENGTH else full.left(FEED_NAME_LENGTH - 1) + "…"


func _refresh_scoreboard() -> void:
	if _score_rows == null:
		return
	for child in _score_rows.get_children():
		child.free()
	_score_card.custom_minimum_size.x = 860.0 if Teams.is_active() else 700.0
	if Teams.is_active():
		_refresh_team_scoreboard()
		return
	var ids := GameState.players.keys()
	var elimination := Match.is_elimination()
	var places := {}
	for row: Dictionary in Match.standings():
		places[row.id] = row.place
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
		var shown_name: String = info.name if elimination else "%d. %s" % [places.get(id, 0), info.name]
		var row := _score_row(shown_name, str(info.kills), middle, ping_text, UiStyle.INK, _ping_color(ping))
		row.add_child(_avatar_of(id, SCORE_AVATAR_SIDE))
		row.move_child(row.get_child(-1), 0)
		_score_rows.add_child(row)


## Tabela Team Deathmatchu: dwie kolumny druzyn obok siebie, kazda z wynikiem w naglowku.
## Gracze bez druzyny stoja pod spodem jako widzowie.
func _refresh_team_scoreboard() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	_score_rows.add_child(columns)
	for team in Teams.COUNT:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		column.add_child(header)
		var title := UiStyle.label(Teams.name_of(team), 22, Teams.color_of(team).darkened(0.2))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		header.add_child(UiStyle.label(str(Match.team_scores[team]), 22, Teams.color_of(team).darkened(0.2)))
		column.add_child(_team_score_row("Gracz", "Z", "Ś", "Ping", Color(UiStyle.INK, 0.65), Color(UiStyle.INK, 0.65), false))
		var members := Teams.members(team)
		members.sort_custom(func(a: int, b: int) -> bool:
			return GameState.players[a].kills > GameState.players[b].kills or (GameState.players[a].kills == GameState.players[b].kills and a < b))
		for id: int in members:
			var info: Dictionary = GameState.players[id]
			var ping: int = GameState.pings.get(id, -1)
			var mine := id == multiplayer.get_unique_id()
			var row := _team_score_row(info.name, str(info.kills), str(info.deaths), "%d ms" % ping if ping >= 0 else "–", UiStyle.BLUE if mine else UiStyle.INK, _ping_color(ping), mine)
			row.add_child(_avatar_of(id, 28.0))
			row.move_child(row.get_child(-1), 0)
			column.add_child(row)
		if members.is_empty():
			column.add_child(UiStyle.label("Nikogo jeszcze nie ma", 14, Color(UiStyle.INK, 0.65), false))
	var watching := Teams.members(Teams.NONE)
	if not watching.is_empty():
		var names := watching.map(func(id: int) -> String: return _short_name(id))
		_score_rows.add_child(UiStyle.label("Wybierają drużynę: " + ", ".join(names), 14, Color(UiStyle.INK, 0.65), false))


func _team_score_row(player_name: String, kills: String, deaths: String, ping: String, color: Color, ping_color: Color, bold: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := UiStyle.label(player_name, 17, color, bold)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	for value in [kills, deaths]:
		var cell := UiStyle.label(value, 17, color)
		cell.custom_minimum_size = Vector2(44, 0)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cell)
	var ping_cell := UiStyle.label(ping, 15, ping_color, false)
	ping_cell.custom_minimum_size = Vector2(64, 0)
	ping_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(ping_cell)
	return row


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

	_scope = ScopeOverlay.new()
	add_child(_scope)

	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_crosshair)

	_dance_wheel = DanceWheel.new()
	_dance_wheel.chosen.connect(_on_dance_chosen)
	add_child(_dance_wheel)

	# Lewy gorny rog to kolumna: kazdy element stoi pod poprzednim, wiec nic tu na siebie nie wchodzi.
	_top_left = VBoxContainer.new()
	_top_left.position = Vector2(24, 22)
	_top_left.add_theme_constant_override("separation", 10)
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_left)
	_fps_panel = PanelContainer.new()
	var fps_style := UiStyle.sticker(UiStyle.PAPER, 14, 3)
	fps_style.set_content_margin_all(8)
	fps_style.content_margin_left = 14
	fps_style.content_margin_right = 14
	_fps_panel.add_theme_stylebox_override("panel", fps_style)
	_fps_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left.add_child(_fps_panel)
	_fps_label = UiStyle.label("0 FPS", 17, UiStyle.INK)
	_fps_panel.add_child(_fps_label)

	var net_graph := NetGraph.new()
	net_graph.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_top_left.add_child(net_graph)

	_build_status_sticker()
	_build_ammo_sticker()
	_match_panel = MatchPanel.new()
	add_child(_match_panel)
	_round_panel = RoundPanel.new()
	add_child(_round_panel)
	_round_panel.move_top_card(_top_left)
	_round_panel.banner_shown.connect(func() -> void: _streak_panel.visible = false)
	_chat = ChatPanel.new()
	_chat.closed.connect(_on_chat_closed)
	add_child(_chat)

	_hotbar = Hotbar.new()
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.position.y -= 32.0
	add_child(_hotbar)

	var name_center := CenterContainer.new()
	_name_center = name_center
	name_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	name_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	name_center.position.y -= ITEM_LINE_BOTTOM
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

	# Napis o smierci stoi nad paskiem przedmiotow, a nie na srodku ekranu.
	var death_center := CenterContainer.new()
	_death_center = death_center
	death_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	death_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	death_center.position.y -= ITEM_LINE_BOTTOM + DEATH_LIFT
	death_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_center)
	_death_panel = PanelContainer.new()
	var death_style := UiStyle.sticker(UiStyle.CORAL, 20, 5)
	death_style.set_content_margin_all(5 + 8)
	death_style.content_margin_left = 5 + 16
	death_style.content_margin_right = 5 + 16
	_death_panel.add_theme_stylebox_override("panel", death_style)
	_death_panel.rotation_degrees = -2.0
	_death_panel.visible = false
	death_center.add_child(_death_panel)
	_death_label = UiStyle.label("", DEATH_FONT, Color.WHITE)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_panel.add_child(_death_label)

	var streak_center := CenterContainer.new()
	_streak_center = streak_center
	streak_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	streak_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# W miejscu banera rundy i odliczania, pod zegarem.
	streak_center.position.y = MatchPanel.BIG_LABEL_TOP
	streak_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(streak_center)
	_streak_panel = PanelContainer.new()
	var streak_style := UiStyle.sticker(UiStyle.SUN, 18, 5)
	streak_style.set_content_margin_all(5 + 8)
	streak_style.content_margin_left = 5 + 16
	streak_style.content_margin_right = 5 + 16
	_streak_panel.add_theme_stylebox_override("panel", streak_style)
	_streak_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_panel.visible = false
	streak_center.add_child(_streak_panel)
	_streak_label = UiStyle.label("", RoundPanel.BANNER_FONT, UiStyle.INK)
	_streak_panel.add_child(_streak_label)
	_streak_audio = AudioStreamPlayer.new()
	add_child(_streak_audio)

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

	_team_panel = TeamPanel.new()
	_team_panel.closed.connect(_on_team_panel_closed)
	add_child(_team_panel)
	_add_shade_behind(_team_panel)

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
	_prompt_center = center
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	center.position.y -= ITEM_LINE_BOTTOM
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_prompt_panel = PanelContainer.new()
	_prompt_style = UiStyle.sticker(UiStyle.PAPER, 16, 4)
	_prompt_style.set_content_margin_all(4 + 4)
	_prompt_style.content_margin_left = 4 + 8
	_prompt_style.content_margin_right = 4 + 12
	_prompt_panel.add_theme_stylebox_override("panel", _prompt_style)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	center.add_child(_prompt_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	_prompt_panel.add_child(rows)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	rows.add_child(row)
	_prompt_bar = UiStyle.bar(UiStyle.SUN, 6)
	_prompt_bar.max_value = 1.0
	_prompt_bar.step = 0.0
	_prompt_bar.visible = false
	rows.add_child(_prompt_bar)
	row.add_child(ActionChip.create("interact", 28, 15))
	_prompt_action = UiStyle.label("Podnieś", PROMPT_FONT, UiStyle.INK, false)
	row.add_child(_prompt_action)
	_prompt_name = UiStyle.label("", PROMPT_FONT, UiStyle.INK)
	row.add_child(_prompt_name)


func _build_use_panel() -> void:
	var center := CenterContainer.new()
	_use_center = center
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	center.position.y -= ITEM_LINE_BOTTOM
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_use_panel = PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 16, 4)
	style.set_content_margin_all(4 + 4)
	style.content_margin_left = 4 + 12
	style.content_margin_right = 4 + 12
	style.border_color = UiStyle.TEAL
	_use_panel.add_theme_stylebox_override("panel", style)
	_use_panel.custom_minimum_size = Vector2(PROMPT_MAX_WIDTH, 0)
	_use_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_panel.visible = false
	center.add_child(_use_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_use_panel.add_child(rows)
	_use_label = UiStyle.label("", PROMPT_FONT, UiStyle.INK)
	_use_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_use_label.clip_text = true
	_use_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rows.add_child(_use_label)
	_use_bar = UiStyle.bar(UiStyle.TEAL, 6)
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
	row.add_child(ActionChip.create("drop_item", 28, 16))
	var label := UiStyle.label("wyrzuć", 16, Color.WHITE)
	label.add_theme_color_override("font_outline_color", UiStyle.INK)
	label.add_theme_constant_override("outline_size", 5)
	row.add_child(label)
	_drop_hint = row


func _build_status_sticker() -> void:
	var anchor := _anchored(Control.PRESET_BOTTOM_LEFT, Vector2(28, -28), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	var panel := PanelContainer.new()
	_status_panel = panel
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 22, 6))
	panel.rotation_degrees = -1.2
	anchor.add_child(panel)
	# Dolna krawedz stoi w miejscu, a napis o leczeniu dokleja sie u gory, a nie wychodzi za ekran.
	panel.resized.connect(func() -> void: panel.position.y = -panel.size.y)

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

	_regen_label = UiStyle.label("", 16, UiStyle.TEAL, false)
	_regen_label.visible = false
	rows.add_child(_regen_label)
	# Ochrona po odrodzeniu to linia w naklejce zdrowia, tak jak leczenie, a nie napis na srodku ekranu.
	_protection_label = UiStyle.label("Ochrona po odrodzeniu", 16, UiStyle.TEAL.darkened(0.2))
	_protection_label.visible = false
	rows.add_child(_protection_label)


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
