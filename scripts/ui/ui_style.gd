class_name UiStyle
extends RefCounted
## Wspolny, kreskowkowy wyglad interfejsu: grube obrysy i zaokraglone rogi.

const INK := Color("1f1830")
const PAPER := Color("fff6e0")
const ACCENT := Color("f2994a")
const ACCENT_HOVER := Color("ffb46b")
const TEAL := Color("2ec4b6")
const DANGER := Color("e8505b")


static func panel(fill: Color, border := 4, radius := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	return style


static func label(text: String, size := 20, color := PAPER, outline := 6) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", outline)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, fill := ACCENT) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 50)
	node.add_theme_font_size_override("font_size", 22)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_focus_color", INK)
	node.add_theme_stylebox_override("normal", panel(fill))
	node.add_theme_stylebox_override("hover", panel(fill.lightened(0.18)))
	node.add_theme_stylebox_override("pressed", panel(fill.darkened(0.15)))
	node.add_theme_stylebox_override("focus", panel(fill.lightened(0.18)))
	return node


static func field(text: String, placeholder: String) -> LineEdit:
	var node := LineEdit.new()
	node.text = text
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, 46)
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_placeholder_color", Color(INK, 0.45))
	node.add_theme_color_override("caret_color", INK)
	node.add_theme_stylebox_override("normal", panel(Color.WHITE, 3, 10))
	node.add_theme_stylebox_override("focus", panel(Color.WHITE, 4, 10))
	return node
