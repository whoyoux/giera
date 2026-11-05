class_name UiStyle
extends RefCounted
## Interfejs jak naklejki z pudelka zabawek: biale obrzeze, cien pod spodem
## i okragla, gruba czcionka.

const INK := Color("2d2a3e")
const PAPER := Color("fffaf0")
const CORAL := Color("ef6f6c")
const SUN := Color("f9c74f")
const TEAL := Color("2ec4b6")
const BLUE := Color("5b8def")
const SHADOW := Color(0.18, 0.13, 0.25, 0.28)

const FONT_PATH := "res://assets/fonts/Fredoka.ttf"
const AMMO_ICON_PATH := "res://assets/icons/ammo.png"

static var _bold: FontVariation
static var _regular: FontVariation


## Ustawia czcionke dla calej gry. Wywolac raz przy starcie.
static func apply_font() -> void:
	var base := load(FONT_PATH) as FontFile
	var regular := FontVariation.new()
	regular.base_font = base
	regular.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 500 }
	_regular = regular
	_bold = FontVariation.new()
	_bold.base_font = base
	_bold.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }


static func sticker(fill: Color, radius := 18, border := 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color.WHITE
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14)
	style.shadow_color = SHADOW
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 5)
	style.anti_aliasing = true
	return style


static func label(text: String, size := 20, color := INK, bold := true) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	var font := _bold if bold else _regular
	if font != null:
		node.add_theme_font_override("font", font)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, fill := CORAL, text_color := Color.WHITE) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 58)
	node.add_theme_font_size_override("font_size", 24)
	if _bold != null:
		node.add_theme_font_override("font", _bold)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, text_color)
	node.add_theme_stylebox_override("normal", sticker(fill, 20))
	node.add_theme_stylebox_override("hover", sticker(fill.lightened(0.12), 20))
	node.add_theme_stylebox_override("pressed", sticker(fill.darkened(0.12), 20))
	node.add_theme_stylebox_override("focus", sticker(fill.lightened(0.12), 20))
	node.add_theme_stylebox_override("disabled", sticker(fill.lerp(Color.WHITE, 0.45), 20))
	node.pivot_offset = Vector2(150, 29)
	node.mouse_entered.connect(func() -> void:
		node.create_tween().tween_property(node, "rotation_degrees", -1.2, 0.08))
	node.mouse_exited.connect(func() -> void:
		node.create_tween().tween_property(node, "rotation_degrees", 0.0, 0.08))
	return node


static func field(text: String, placeholder: String) -> LineEdit:
	var node := LineEdit.new()
	node.text = text
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, 50)
	node.add_theme_font_size_override("font_size", 21)
	if _regular != null:
		node.add_theme_font_override("font", _regular)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	node.add_theme_color_override("caret_color", CORAL)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f3ecdd")
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(12)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = TEAL
	focus.set_border_width_all(3)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("focus", focus)
	return node


## Ikona naboju, wyrenderowana z modelu 3D jak ikony broni.
static func ammo_icon(icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(AMMO_ICON_PATH) as Texture2D
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func bar(fill: Color, height := 18) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0, height)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(INK, 0.16)
	back.set_corner_radius_all(height)
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(height)
	node.add_theme_stylebox_override("background", back)
	node.add_theme_stylebox_override("fill", front)
	return node
