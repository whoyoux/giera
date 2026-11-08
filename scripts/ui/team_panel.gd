class_name TeamPanel
extends CenterContainer
## Wybór drużyny w Team Deathmatchu: dwie karty obok siebie z graczami i wolnymi miejscami.
## Gracz bez drużyny widzi ten ekran od razu i nie może go zamknąć, a z drużyną otwiera go klawiszem.
## Serwer pilnuje równowagi, a karta pełnej drużyny jest nieklikalna i mówi dlaczego.

signal closed

const CARD_WIDTH := 300.0
const AVATAR_SIDE := 28.0
const NAME_LENGTH := 18
const CARD_BORDER := 5
const CARD_PADDING := 16
const CARD_RADIUS := 18

var _card: PanelContainer
var _team_cards: Array[Dictionary] = []
var _random_button: Button
var _back_button: Button
var _hint: Label
var _key_row: HBoxContainer
var _hovered := -1
var _dirty := true
## Okno otworzylo sie samo, bo gracz nie mial druzyny. Zamyka sie samo, gdy serwer ja przydzieli.
var _forced := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	GameState.player_changed.connect(func(_id: int) -> void: _dirty = true)
	GameState.player_added.connect(func(_id: int) -> void: _dirty = true)
	GameState.player_removed.connect(func(_id: int) -> void: _dirty = true)
	Match.team_scores_changed.connect(func() -> void: _dirty = true)


## Gracz bez drużyny nie może zamknąć ekranu, bo nie ma czym grać.
func must_choose() -> bool:
	return Teams.is_active() and Teams.team_of(multiplayer.get_unique_id()) == Teams.NONE


func open() -> void:
	if visible or not Teams.is_active():
		return
	visible = true
	_forced = must_choose()
	_dirty = true
	UiStyle.pop_in(_card)
	UiSound.play(Sfx.UiCue.OPEN)


func close() -> void:
	if not visible or must_choose():
		return
	visible = false
	UiSound.play(Sfx.UiCue.CLOSE)
	closed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Panel konca rundy ma pierwszenstwo, a wybor druzyny wraca w nastepnej rundzie.
	if not Teams.is_active() or Match.phase == Match.Phase.RESULTS:
		_forced = false
		visible = false
		closed.emit()
		return
	if _forced and not must_choose():
		_forced = false
		visible = false
		closed.emit()
		return
	if _dirty:
		_dirty = false
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	# Bez druzyny pauza zostaje dla HUD, zeby dalo sie wyjsc z gry.
	if not visible or must_choose():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("team_select"):
		close()
		get_viewport().set_input_as_handled()


func _choose(team: int) -> void:
	var me := multiplayer.get_unique_id()
	if team != Teams.NONE and not Teams.can_join(me, team):
		UiSound.play(Sfx.UiCue.ERROR)
		UiStyle.shake(_team_cards[team].card)
		return
	Match.request_team(team)
	# Gracz bez druzyny czeka na odpowiedz serwera, a ten, kto juz gral, wraca od razu.
	if not _forced:
		visible = false
		closed.emit()


func _refresh() -> void:
	var me := multiplayer.get_unique_id()
	var mine := Teams.team_of(me)
	var sizes := Teams.counts()
	for team in Teams.COUNT:
		var entry: Dictionary = _team_cards[team]
		(entry.count as Label).text = "%d/%d miejsc" % [sizes[team], Teams.MAX_SIZE]
		(entry.score as Label).text = "Wynik: %d" % Match.team_scores[team]
		var rows := entry.rows as VBoxContainer
		for child in rows.get_children():
			child.free()
		var members := Teams.members(team)
		for id: int in members:
			rows.add_child(_member_row(id, id == me))
		if members.is_empty():
			rows.add_child(UiStyle.label("Nikogo jeszcze nie ma", 14, Color(UiStyle.INK, 0.65), false))
		var blocker := Teams.join_blocker(me, team)
		var footer := entry.footer as Label
		footer.text = "Kliknij, żeby dołączyć" if blocker.is_empty() else blocker
		footer.add_theme_color_override("font_color", Color(UiStyle.INK, 0.65) if blocker.is_empty() or team == mine else UiStyle.CORAL.darkened(0.1))
		(entry.badge as Control).visible = team == mine
		entry.blocked = not blocker.is_empty()
		(entry.card as Control).mouse_default_cursor_shape = Control.CURSOR_ARROW if entry.blocked else Control.CURSOR_POINTING_HAND
		_style_card(team)
	_back_button.visible = mine != Teams.NONE
	_key_row.visible = mine != Teams.NONE
	_hint.text = "Kliknij kartę drużyny albo wybierz losowo." if mine == Teams.NONE else "Możesz zmienić drużynę. Wrócisz do gry po jej stronie."


func _style_card(team: int) -> void:
	var entry: Dictionary = _team_cards[team]
	var mine: bool = Teams.team_of(multiplayer.get_unique_id()) == team
	var hovered: bool = _hovered == team and not entry.blocked
	var style := UiStyle.sticker(Teams.light_of(team).lightened(0.25 if hovered else 0.0), CARD_RADIUS, CARD_BORDER)
	style.border_color = UiStyle.BLUE if mine else (UiStyle.SUN if hovered else Color.WHITE)
	style.set_content_margin_all(CARD_BORDER + CARD_PADDING)
	(entry.card as PanelContainer).add_theme_stylebox_override("panel", style)
	(entry.card as Control).modulate = Color(1, 1, 1, 0.7) if entry.blocked and not mine else Color.WHITE


func _member_row(id: int, me: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(AvatarView.new(GameState.steam_id_of(id), GameState.display_name(id), AVATAR_SIDE))
	var full := GameState.display_name(id)
	var shown := full if full.length() <= NAME_LENGTH else full.left(NAME_LENGTH - 1) + "…"
	var label := UiStyle.label(shown + (" (Ty)" if me else ""), 15, UiStyle.INK, me)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	return row


func _build() -> void:
	_card = PanelContainer.new()
	var style := UiStyle.sticker(UiStyle.PAPER, 24, 6)
	style.set_content_margin_all(6 + 20)
	style.content_margin_left = 6 + 24
	style.content_margin_right = 6 + 24
	_card.add_theme_stylebox_override("panel", style)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_card.add_child(column)
	column.add_child(UiStyle.label("Team Deathmatch", 14, Color(UiStyle.INK, 0.65), false))
	column.add_child(UiStyle.label("Wybierz drużynę", 24, UiStyle.INK))
	_hint = UiStyle.label("", 14, Color(UiStyle.INK, 0.65), false)
	column.add_child(_hint)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	column.add_child(gap)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	column.add_child(cards)
	for team in Teams.COUNT:
		cards.add_child(_build_team_card(team))
	var gap_bottom := Control.new()
	gap_bottom.custom_minimum_size.y = 12
	column.add_child(gap_bottom)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_random_button = UiStyle.button("Losowo", UiStyle.TEAL)
	_random_button.add_theme_font_size_override("font_size", 19)
	_random_button.custom_minimum_size = Vector2(180, 50)
	_random_button.pressed.connect(func() -> void: _choose(Teams.NONE))
	footer.add_child(_random_button)
	_back_button = UiStyle.button("Wróć do gry", UiStyle.BLUE)
	_back_button.add_theme_font_size_override("font_size", 19)
	_back_button.custom_minimum_size = Vector2(180, 50)
	_back_button.pressed.connect(close)
	footer.add_child(_back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_key_row = HBoxContainer.new()
	_key_row.add_theme_constant_override("separation", 8)
	_key_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_key_row)
	_key_row.add_child(ActionChip.create("team_select", 26, 14))
	_key_row.add_child(UiStyle.label("zamyka okno", 14, Color(UiStyle.INK, 0.65), false))


func _build_team_card(team: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_WIDTH
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var swatch := PanelContainer.new()
	var swatch_style := UiStyle.sticker(Teams.color_of(team), 8, 3)
	swatch_style.set_content_margin_all(0)
	swatch_style.shadow_size = 0
	swatch.add_theme_stylebox_override("panel", swatch_style)
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(swatch)
	var title := UiStyle.label(Teams.name_of(team), 19, Teams.color_of(team).darkened(0.25))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var badge := PanelContainer.new()
	var badge_style := UiStyle.sticker(UiStyle.BLUE, 12, 3)
	badge_style.set_content_margin_all(3 + 3)
	badge_style.content_margin_left = 3 + 8
	badge_style.content_margin_right = 3 + 8
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiStyle.label("✓ Twoja", 13, Color.WHITE))
	header.add_child(badge)
	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stats)
	var count := UiStyle.label("", 14, Color(UiStyle.INK, 0.65), false)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(count)
	var score := UiStyle.label("", 14, Color(UiStyle.INK, 0.65), false)
	stats.add_child(score)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.custom_minimum_size.y = (AVATAR_SIDE + 6) * 5
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rows)
	var footer := UiStyle.label("", 13, Color(UiStyle.INK, 0.65), false)
	column.add_child(footer)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			card.accept_event()
			if Teams.team_of(multiplayer.get_unique_id()) == team:
				close()
				return
			if _team_cards[team].blocked:
				UiSound.play(Sfx.UiCue.ERROR)
				UiStyle.shake(card)
				return
			UiSound.play(Sfx.UiCue.CONFIRM)
			_choose(team))
	card.mouse_entered.connect(func() -> void:
		_hovered = team
		if not _team_cards[team].blocked:
			UiSound.play(Sfx.UiCue.HOVER)
		_style_card(team))
	card.mouse_exited.connect(func() -> void:
		if _hovered == team:
			_hovered = -1
		_style_card(team))
	_team_cards.append({ "card": card, "count": count, "score": score, "rows": rows, "footer": footer, "badge": badge, "blocked": false })
	return card
