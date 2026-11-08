class_name ArsenalPanel
extends CanvasLayer
## Zbrojownia z menu glownego: wszystkie przedmioty ze statystykami i porownanie dwoch broni.
## Liczby bierze z ArsenalStats, wiec nowy przedmiot z ItemRegistry pojawia sie tu sam.

const CARD_SIZE := Vector2(1200, 680)
const FIELD := Color("f3ecdd")
const SELECTED_FILL := Color("fff3d6")
const MUTED := Color(UiStyle.INK, 0.62)
const OFF_TINT := Color(1.0, 1.0, 1.0, 0.55)
const LIST_WIDTH := 560.0
const GRID_COLUMNS := 3
const TILE_SIZE := Vector2(170, 136)
const TILE_ICON_SIZE := Vector2(110, 78)
const HERO_HEIGHT := 150.0
const HERO_ICON_SIZE := Vector2(220, 140)
const BAR_LABEL_WIDTH := 150.0
const BAR_VALUE_WIDTH := 76.0
const MAX_BARS := 6
const MAX_FACTS := 4
const BAR_SECONDS := 0.3
## Ikona w podgladzie lekko sie buja, jak zabawka na wystawie.
const BOB_PIXELS := 6.0
const BOB_SPEED := 2.2
const BOB_TILT_DEGREES := -6.0
const SIDE_WIDTH := 300.0
const PICK_SIZE := Vector2(66, 56)
const SIDE_COLORS: Array[Color] = [UiStyle.CORAL, UiStyle.BLUE]
const WIN_COLOR := Color("1f9e5a")
const RADAR_LABELS: Array[String] = ["Obrażenia", "Szybkość", "Celność", "Magazynek", "Przeładowanie", "Mobilność"]

var _card: PanelContainer
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _close: Button
var _time := 0.0

# Zbrojownia
var _category := -1
var _category_buttons := {}
var _tiles := {}
var _selected: ItemDefinition
var _tier := Rarity.Tier.COMMON
var _hero: PanelContainer
var _hero_icon: TextureRect
var _name: Label
var _kind_pill: PanelContainer
var _kind: Label
var _description: Label
var _tier_row: HBoxContainer
var _tier_buttons: Array[Button] = []
var _bar_rows: Array[Dictionary] = []
var _fact_chips: Array[Dictionary] = []

# Porownanie: dwie strony, kazda z bronia i klasa.
var _compare := [
	{ "gun": null, "tier": Rarity.Tier.COMMON },
	{ "gun": null, "tier": Rarity.Tier.LEGENDARY },
]
var _radar: RadarChart
var _compare_rows: Array[Array] = []


func _ready() -> void:
	layer = 5
	visible = false
	var guns := ArsenalStats.guns()
	_compare[0].gun = guns[0]
	_compare[1].gun = guns[mini(2, guns.size() - 1)]
	_selected = ItemRegistry.DEFINITIONS[0]
	_build()


func open() -> void:
	visible = true
	_show_page(0)
	UiSound.play(Sfx.UiCue.OPEN)
	UiStyle.pop_in(_card)
	_close.grab_focus.call_deferred(true)


func close() -> void:
	if not visible:
		return
	visible = false
	UiSound.play(Sfx.UiCue.CLOSE)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _hero_icon == null:
		return
	_time += delta
	_hero_icon.position.y = sin(_time * BOB_SPEED) * BOB_PIXELS
	_hero_icon.rotation_degrees = BOB_TILT_DEGREES + sin(_time * BOB_SPEED * 0.5) * 2.0


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(UiStyle.INK, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = CARD_SIZE
	_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_card.add_child(column)
	column.add_child(_build_header())
	var pages := MarginContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	_pages = [_build_catalog(), _build_compare()]
	for page in _pages:
		pages.add_child(page)
	_filter(-1)
	_select(_selected)
	_refresh_compare()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title := UiStyle.label("Zbrojownia", 34, UiStyle.CORAL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for index in 2:
		var tab := _small_button(["Wszystkie przedmioty", "Porównaj bronie"][index], [UiStyle.TEAL, UiStyle.BLUE][index], 18, 48)
		tab.custom_minimum_size.x = 210
		tab.pressed.connect(_show_page.bind(index))
		row.add_child(tab)
		_tab_buttons.append(tab)
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	row.add_child(gap)
	_close = UiStyle.button("Gotowe", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.NONE)
	_close.name = "close_arsenal"
	_close.custom_minimum_size = Vector2(130, 48)
	_close.add_theme_font_size_override("font_size", 20)
	_close.pressed.connect(close)
	row.add_child(_close)
	return row


func _show_page(index: int) -> void:
	for page_index in _pages.size():
		_pages[page_index].visible = page_index == index
		_tab_buttons[page_index].modulate = Color.WHITE if page_index == index else OFF_TINT


# ===== Wszystkie przedmioty =====

func _build_catalog() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LIST_WIDTH
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	left.add_child(filters)
	_add_filter(filters, -1, "Wszystko", UiStyle.INK)
	for category: int in ArsenalStats.CATEGORY_NAMES:
		_add_filter(filters, category, ArsenalStats.CATEGORY_NAMES[category], ArsenalStats.CATEGORY_COLORS[category])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for definition in ItemRegistry.DEFINITIONS:
		var tile := _build_tile(definition)
		grid.add_child(tile)
		_tiles[definition] = tile
	row.add_child(_build_detail())
	return row


func _add_filter(parent: Container, category: int, text: String, color: Color) -> void:
	var button := _small_button(text, color, 16, 40)
	button.pressed.connect(_filter.bind(category))
	parent.add_child(button)
	_category_buttons[category] = button


func _filter(category: int) -> void:
	_category = category
	for key: int in _category_buttons:
		(_category_buttons[key] as Button).modulate = Color.WHITE if key == category else OFF_TINT
	for definition: ItemDefinition in _tiles:
		(_tiles[definition] as Button).visible = category < 0 or ArsenalStats.category(definition) == category


func _build_tile(definition: ItemDefinition) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.focus_mode = Control.FOCUS_ALL
	tile.add_theme_stylebox_override("focus", UiStyle.focus_ring(18))
	ButtonFeel.attach(tile, Sfx.UiCue.PRESS)
	tile.pressed.connect(_select.bind(definition))
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	var icon := _icon_rect(ArsenalStats.icon(definition, Rarity.Tier.COMMON), TILE_ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var name_label := UiStyle.label(definition.display_name, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	var kind_label := UiStyle.label(definition.kind_name, 14, MUTED)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(kind_label)
	# Kropki w rogu: w jakich klasach przedmiot wystepuje.
	if definition.has_tiers():
		var dots := HBoxContainer.new()
		dots.add_theme_constant_override("separation", 3)
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
		dots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		for tier in Rarity.Tier.values():
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(12, 12)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = Rarity.color(tier)
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
			style.set_corner_radius_all(6)
			dot.add_theme_stylebox_override("panel", style)
			dots.add_child(dot)
		tile.add_child(dots)
	tile.set_meta("icon", icon)
	return tile


func _build_detail() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)

	_hero = PanelContainer.new()
	_hero.custom_minimum_size.y = HERO_HEIGHT
	column.add_child(_hero)
	var holder := Control.new()
	holder.custom_minimum_size = HERO_ICON_SIZE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(holder)
	_hero_icon = _icon_rect(null, HERO_ICON_SIZE)
	_hero_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero_icon.pivot_offset = HERO_ICON_SIZE * 0.5
	holder.add_child(_hero_icon)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	column.add_child(name_row)
	_name = UiStyle.label("", 30)
	name_row.add_child(_name)
	_kind_pill = PanelContainer.new()
	_kind_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_kind_pill)
	_kind = UiStyle.label("", 15, Color.WHITE)
	_kind_pill.add_child(_kind)

	_description = UiStyle.label("", 16, MUTED, false)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 42
	column.add_child(_description)

	_tier_row = HBoxContainer.new()
	_tier_row.add_theme_constant_override("separation", 8)
	column.add_child(_tier_row)
	_tier_buttons = _build_tier_buttons(_tier_row, _set_tier)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 6)
	column.add_child(bars)
	for index in MAX_BARS:
		_bar_rows.append(_build_bar_row(bars))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 10)
	column.add_child(facts)
	for index in MAX_FACTS:
		_fact_chips.append(_build_chip(facts))
	return column


func _select(definition: ItemDefinition) -> void:
	_selected = definition
	for tile_definition: ItemDefinition in _tiles:
		var tile := _tiles[tile_definition] as Button
		var picked := tile_definition == definition
		var fill := SELECTED_FILL if picked else FIELD
		var normal := UiStyle.sticker(fill, 18, 4) if picked else _flat(fill, 18)
		tile.add_theme_stylebox_override("normal", normal)
		tile.add_theme_stylebox_override("hover", UiStyle.sticker(SELECTED_FILL, 18, 4))
		tile.add_theme_stylebox_override("pressed", normal)
		(tile.get_meta("icon") as TextureRect).texture = ArsenalStats.icon(tile_definition, Rarity.Tier.COMMON)
	_refresh_detail()


func _set_tier(tier: int) -> void:
	_tier = tier
	_refresh_detail()


func _refresh_detail() -> void:
	var definition := _selected
	var tier := _tier if definition.has_tiers() else Rarity.Tier.COMMON
	var color := ArsenalStats.color(definition, tier)
	var hero_style := _flat(color, 20)
	_hero.add_theme_stylebox_override("panel", hero_style)
	_hero_icon.texture = ArsenalStats.icon(definition, tier)
	(_tiles[definition].get_meta("icon") as TextureRect).texture = _hero_icon.texture
	_name.text = ArsenalStats.title(definition, tier)
	var category := ArsenalStats.category(definition)
	var pill := _flat(ArsenalStats.CATEGORY_COLORS[category], 999)
	pill.content_margin_left = 12
	pill.content_margin_right = 12
	pill.content_margin_top = 2
	pill.content_margin_bottom = 2
	_kind_pill.add_theme_stylebox_override("panel", pill)
	_kind.text = definition.kind_name
	_description.text = definition.description
	_tier_row.visible = definition.has_tiers()
	_mark_tier(_tier_buttons, tier)
	var bars := ArsenalStats.bars(definition, tier)
	for index in _bar_rows.size():
		var row: Dictionary = _bar_rows[index]
		(row.root as Control).visible = index < bars.size()
		if index >= bars.size():
			continue
		(row.label as Label).text = bars[index].label
		(row.value as Label).text = bars[index].text
		var bar := row.bar as ProgressBar
		(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color.darkened(0.08) if definition.has_tiers() and tier == Rarity.Tier.COMMON else color
		bar.create_tween().tween_property(bar, "value", bars[index].value, BAR_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var facts := ArsenalStats.facts(definition, tier)
	for index in _fact_chips.size():
		var chip: Dictionary = _fact_chips[index]
		(chip.root as Control).visible = index < facts.size()
		if index < facts.size():
			(chip.label as Label).text = facts[index][0]
			(chip.value as Label).text = facts[index][1]


# ===== Porownanie =====

func _build_compare() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.add_child(_build_side(0))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 6)
	row.add_child(middle)
	_radar = RadarChart.new()
	_radar.labels = PackedStringArray(RADAR_LABELS)
	_radar.custom_minimum_size = Vector2(0, 290)
	middle.add_child(_radar)
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 6)
	table.add_theme_constant_override("v_separation", 5)
	middle.add_child(table)
	for label_text in ["Obrażenia na strzał", "DPS", "W głowę", "Strzały na sekundę", "Magazynek", "Przeładowanie", "Mobilność"]:
		var cells: Array = []
		for column in 3:
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", _flat(FIELD, 10, 4))
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if column != 1 else Control.SIZE_FILL
			var text := UiStyle.label(label_text if column == 1 else "", 17 if column != 1 else 15, UiStyle.INK if column != 1 else MUTED)
			text.horizontal_alignment = [HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_LEFT][column]
			if column == 1:
				text.custom_minimum_size.x = 170
			cell.add_child(text)
			table.add_child(cell)
			cells.append(text)
		_compare_rows.append(cells)
	row.add_child(_build_side(1))
	return row


func _build_side(side: int) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = SIDE_WIDTH
	column.add_theme_constant_override("separation", 10)
	var hero := PanelContainer.new()
	hero.custom_minimum_size.y = 150
	column.add_child(hero)
	var icon := _icon_rect(null, Vector2(200, 130))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.add_child(icon)
	var name_label := UiStyle.label("", 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var picks := GridContainer.new()
	picks.columns = 4
	picks.add_theme_constant_override("h_separation", 8)
	picks.add_theme_constant_override("v_separation", 8)
	column.add_child(picks)
	var pick_buttons := {}
	for gun in ArsenalStats.guns():
		var pick := Button.new()
		pick.custom_minimum_size = PICK_SIZE
		pick.tooltip_text = gun.display_name
		pick.add_theme_stylebox_override("focus", UiStyle.focus_ring(14))
		ButtonFeel.attach(pick, Sfx.UiCue.PRESS)
		var pick_icon := _icon_rect(ArsenalStats.icon(gun, Rarity.Tier.COMMON), PICK_SIZE - Vector2(12, 12))
		pick_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		pick.add_child(pick_icon)
		pick.pressed.connect(func() -> void:
			_compare[side].gun = gun
			_refresh_compare())
		picks.add_child(pick)
		pick_buttons[gun] = pick
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 6)
	column.add_child(tiers)
	var tier_buttons := _build_tier_buttons(tiers, func(tier: int) -> void:
		_compare[side].tier = tier
		_refresh_compare())
	var legend := UiStyle.label("Lewa broń" if side == 0 else "Prawa broń", 16, SIDE_COLORS[side])
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(legend)
	_compare[side].merge({ "hero": hero, "icon": icon, "name": name_label, "picks": pick_buttons, "tiers": tier_buttons })
	return column


func _refresh_compare() -> void:
	var numbers: Array[Dictionary] = []
	var radar_values: Array[PackedFloat32Array] = []
	for side in 2:
		var entry: Dictionary = _compare[side]
		var gun := entry.gun as WeaponDefinition
		var tier: int = entry.tier
		(entry.hero as PanelContainer).add_theme_stylebox_override("panel", _flat(Rarity.color(tier), 20))
		(entry.icon as TextureRect).texture = ArsenalStats.icon(gun, tier)
		(entry.name as Label).text = ArsenalStats.title(gun, tier)
		for pick_gun: WeaponDefinition in entry.picks:
			var picked: bool = pick_gun == gun
			var button := entry.picks[pick_gun] as Button
			var style := UiStyle.sticker(Color.WHITE, 14, 4) if picked else _flat(FIELD, 14)
			if picked:
				style.border_color = SIDE_COLORS[side]
			style.set_content_margin_all(4)
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(state, style)
		_mark_tier(entry.tiers, tier)
		numbers.append(ArsenalStats.gun_numbers(gun, tier))
		var values := PackedFloat32Array()
		for bar in ArsenalStats.bars(gun, tier):
			values.append(bar.value)
		radar_values.append(values)
	_radar.set_series(radar_values, SIDE_COLORS)
	# [klucz, czy wiecej znaczy lepiej, jak pokazac]
	var rows := [
		["per_shot", true, func(v: float) -> String: return str(roundi(v))],
		["dps", true, func(v: float) -> String: return str(roundi(v))],
		["headshot", true, func(v: float) -> String: return str(roundi(v))],
		["rate", true, func(v: float) -> String: return ArsenalStats.number(v)],
		["magazine", true, func(v: float) -> String: return str(roundi(v))],
		["reload", false, func(v: float) -> String: return "%s s" % ArsenalStats.number(v)],
		["move", true, func(v: float) -> String: return "%d%%" % roundi(v * 100.0)],
	]
	for index in rows.size():
		var key: String = rows[index][0]
		var more_is_better: bool = rows[index][1]
		var format: Callable = rows[index][2]
		var left := float(numbers[0][key])
		var right := float(numbers[1][key])
		var cells: Array = _compare_rows[index]
		for side in 2:
			var mine := left if side == 0 else right
			var theirs := right if side == 0 else left
			var wins := mine > theirs if more_is_better else mine < theirs
			var label := cells[0 if side == 0 else 2] as Label
			label.text = format.call(mine)
			label.add_theme_color_override("font_color", WIN_COLOR if wins else UiStyle.INK)


# ===== Wspolne =====

func _build_tier_buttons(parent: HBoxContainer, on_pick: Callable) -> Array[Button]:
	var buttons: Array[Button] = []
	for tier in Rarity.Tier.values():
		var button := _small_button(Rarity.display_name(tier), Rarity.color(tier), 16, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_pick.bind(tier))
		parent.add_child(button)
		buttons.append(button)
	return buttons


func _mark_tier(buttons: Array[Button], tier: int) -> void:
	for index in buttons.size():
		buttons[index].modulate = Color.WHITE if index == tier else OFF_TINT


func _build_bar_row(parent: Container) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := UiStyle.label("", 17)
	label.custom_minimum_size.x = BAR_LABEL_WIDTH
	row.add_child(label)
	var bar := UiStyle.bar(UiStyle.TEAL, 14)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value := UiStyle.label("", 17)
	value.custom_minimum_size.x = BAR_VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return { "root": row, "label": label, "bar": bar, "value": value }


func _build_chip(parent: Container) -> Dictionary:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _flat(FIELD, 14, 10))
	parent.add_child(chip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	chip.add_child(column)
	var label := UiStyle.label("", 13, MUTED)
	column.add_child(label)
	var value := UiStyle.label("", 21)
	column.add_child(value)
	return { "root": chip, "label": label, "value": value }


func _small_button(text: String, color: Color, font_size: int, height: float) -> Button:
	var button := UiStyle.button(text, color, Color.WHITE, Sfx.UiCue.PRESS)
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.set_content_margin_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.set_border_width_all(4)
		button.add_theme_stylebox_override(state, style)
	return button


func _icon_rect(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _flat(color: Color, radius: int, margin := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	return style
