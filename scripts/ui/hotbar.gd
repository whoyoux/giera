class_name Hotbar
extends HBoxContainer
## Pasek przedmiotow na dole ekranu: cztery naklejki z ikona i kolorem klasy. Numer klawisza
## to znaczek na rogu, a naboje to pigulka na dolnej krawedzi, wiec nie zaslaniaja ikony.

const SLOT_SIZE := Vector2(92, 92)
const ACTIVE_SCALE := 1.14
const ACTIVE_LIFT := -10.0
const EMPTY_FILL := Color(1.0, 0.98, 0.94, 0.72)
const BADGE_SIZE := Vector2(30, 30)
const CHARGES_SIZE := Vector2(58, 26)
const ACTIVE_BADGE := UiStyle.TEAL

var _cells: Array[Dictionary] = []
var _equipment: Equipment
var _shown_active := -1
var _shown_uids: Array[int] = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in Inventory.SLOTS:
		_cells.append(_build_cell(slot))
		_shown_uids.append(-1)


func bind(equipment: Equipment) -> void:
	_equipment = equipment
	_shown_active = -1
	for slot in Inventory.SLOTS:
		_shown_uids[slot] = -1


func _process(_delta: float) -> void:
	if _equipment == null or not is_instance_valid(_equipment):
		return
	var active := _equipment.input.selected_slot()
	var slots := _equipment.slots()
	for slot in Inventory.SLOTS:
		var stack: Dictionary = slots[slot]
		var uid := ItemStack.uid_of(stack)
		if uid != _shown_uids[slot]:
			if uid != 0 and _shown_uids[slot] != -1:
				_pop(_cells[slot].panel)
			_shown_uids[slot] = uid
			_show_stack(_cells[slot], stack)
		_update_charges(_cells[slot], slot, stack)
	if active != _shown_active:
		for slot in Inventory.SLOTS:
			_animate_selection(_cells[slot], slot == active)
		_shown_active = active


func _show_stack(cell: Dictionary, stack: Dictionary) -> void:
	var style: StyleBoxFlat = cell.style
	var icon: TextureRect = cell.icon
	icon.texture = null
	if ItemStack.is_empty(stack):
		style.bg_color = EMPTY_FILL
		style.border_color = Color.WHITE
		return
	var tier := ItemStack.tier_of(stack)
	var color := Rarity.color(tier)
	style.bg_color = color.lerp(Color.WHITE, 0.62)
	style.border_color = color
	var path := ItemStack.definition_of(stack).icon_path(tier)
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D


func _update_charges(cell: Dictionary, slot: int, stack: Dictionary) -> void:
	var pill: PanelContainer = cell.charges_pill
	var definition := ItemStack.definition_of(stack)
	if definition == null or definition.full_charges(ItemStack.tier_of(stack)) <= 0:
		pill.visible = false
		return
	pill.visible = true
	var charges := _equipment.charges(slot)
	(cell.charges as Label).text = str(charges)
	(cell.charges_style as StyleBoxFlat).bg_color = UiStyle.CORAL if charges == 0 else UiStyle.INK


func _animate_selection(cell: Dictionary, active: bool) -> void:
	var panel: Control = cell.panel
	panel.pivot_offset = panel.size * 0.5
	var tween := panel.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE * (ACTIVE_SCALE if active else 1.0), 0.14)
	tween.tween_property(panel, "position:y", ACTIVE_LIFT if active else 0.0, 0.14)
	(cell.badge_style as StyleBoxFlat).bg_color = ACTIVE_BADGE if active else UiStyle.INK


func _pop(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	var settled := panel.scale
	panel.scale = settled * 1.25
	panel.create_tween().set_trans(Tween.TRANS_BACK).tween_property(panel, "scale", settled, 0.2)


func _build_cell(slot: int) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = SLOT_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var panel := PanelContainer.new()
	panel.size = SLOT_SIZE
	panel.custom_minimum_size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.sticker(EMPTY_FILL, 18, 5)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	holder.add_child(panel)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_child(icon)
	var badge_style := _chip_style(15)
	var badge := _chip(badge_style, BADGE_SIZE)
	badge.position = -BADGE_SIZE * 0.5 + Vector2(4, 4)
	inner.add_child(badge)
	badge.add_child(_chip_label(str(slot + 1), 16))

	var charges_style := _chip_style(13)
	var charges_pill := _chip(charges_style, CHARGES_SIZE)
	charges_pill.position = Vector2((SLOT_SIZE.x - 8.0 - CHARGES_SIZE.x) * 0.5, SLOT_SIZE.y - 8.0 - CHARGES_SIZE.y * 0.5)
	charges_pill.visible = false
	inner.add_child(charges_pill)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charges_pill.add_child(row)
	row.add_child(UiStyle.ammo_icon(Vector2(19, 19)))
	var charges := _chip_label("", 16)
	row.add_child(charges)
	return {
		"panel": panel,
		"style": style,
		"icon": icon,
		"badge_style": badge_style,
		"charges": charges,
		"charges_pill": charges_pill,
		"charges_style": charges_style,
	}


func _chip_style(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.INK
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func _chip(style: StyleBoxFlat, chip_size: Vector2) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = chip_size
	chip.size = chip_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", style)
	return chip


func _chip_label(text: String, font_size: int) -> Label:
	var label := UiStyle.label(text, font_size, Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
