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
const POP_FROM := 0.92
const POP_SECONDS := 0.18
const SHAKE_PIXELS := 9.0
const SHAKE_STEP_SECONDS := 0.045

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


## Czcionka gry do rysowania w _draw. Przed apply_font zwraca czcionke zastepcza.
static func font(bold := true) -> Font:
	var chosen: Font = _bold if bold else _regular
	return chosen if chosen != null else ThemeDB.fallback_font


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


## Napis ma szerokosc swojego tekstu, ale nie wieksza niz limit. Dluzszy konczy sie wielokropkiem.
## Kazda linia jest mierzona osobno.
static func fit_width(node: Label, max_width: float) -> void:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := node.get_theme_font("font")
	var size := node.get_theme_font_size("font_size")
	var widest := 0.0
	for line in node.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	node.custom_minimum_size.x = minf(ceilf(widest) + 2.0, max_width)


## Tekst w kilku kolorach, zawijany do szerokosci. Tresc dodaje sie przez add_text.
static func rich_label(size := 20) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.fit_content = true
	node.scroll_active = false
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_font_size_override("bold_font_size", size)
	node.add_theme_color_override("default_color", INK)
	if _regular != null:
		node.add_theme_font_override("normal_font", _regular)
		node.add_theme_font_override("bold_font", _bold)
	return node


## Szerokosc tekstu w jednej linii.
static func text_width(text: String, size: int, bold: bool) -> float:
	var font: Font = _bold if bold else _regular
	if font == null:
		font = ThemeDB.fallback_font
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Dzwiek mowi, co przycisk robi. Przycisk, ktorego skutek ma wlasny dzwiek, np. otwarcie
## okna, dostaje NONE, zeby jedno klikniecie nie gralo dwoch rzeczy naraz.
static func button(text: String, fill := CORAL, text_color := Color.WHITE, sound := Sfx.UiCue.CONFIRM) -> Button:
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
	node.add_theme_stylebox_override("focus", focus_ring(20))
	node.add_theme_stylebox_override("disabled", sticker(fill.lerp(Color.WHITE, 0.45), 20))
	ButtonFeel.attach(node, sound)
	return node


## Obwodka widoczna tylko przy sterowaniu klawiatura. Inna niz najechanie, zeby bylo wiadomo,
## co zadziala po nacisnieciu Entera, gdy kursor stoi gdzie indziej.
static func focus_ring(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.set_expand_margin_all(3)
	style.anti_aliasing = true
	return style


## Wyskok okna lub napisu. Skala wraca do 1, wiec uklad wokol sie nie przesuwa.
static func pop_in(control: Control, delay := 0.0) -> void:
	control.pivot_offset_ratio = Vector2(0.5, 0.5)
	control.scale = Vector2.ONE * POP_FROM
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, POP_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, POP_SECONDS * 0.6).set_delay(delay)


## Potrzasniecie na boki: "nie, popraw to".
static func shake(control: Control) -> void:
	var home := control.position.x
	var tween := control.create_tween()
	for offset: float in [-SHAKE_PIXELS, SHAKE_PIXELS, -SHAKE_PIXELS * 0.5, SHAKE_PIXELS * 0.5, 0.0]:
		tween.tween_property(control, "position:x", home + offset, SHAKE_STEP_SECONDS)


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
	node.focus_entered.connect(UiSound.play.bind(Sfx.UiCue.PRESS))
	return node


## Klawisz do nacisniecia, pokazany w podpowiedzi.
static func key_chip(key_name: String, chip_size: float, font_size: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2.ONE * chip_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.set_corner_radius_all(10)
	style.anti_aliasing = true
	chip.add_theme_stylebox_override("panel", style)
	var text := label(key_name, font_size, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(text)
	return chip


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
