class_name UiStyle
extends RefCounted
## Interfejs taktyczny: ciemne, polprzezroczyste panele z cienka krawedzia, male zaokraglenia
## i waska, techniczna czcionka. Kolor to sygnal, nie ozdoba.

## Jasny tekst na ciemnym panelu.
const INK := Color("eceef2")
## Tlo panelu (ciemny grafit, lekko przezroczysty, zeby gra przeswitywala).
const PAPER := Color(0.07, 0.078, 0.094, 1.0)
## Tlo elementow HUD w trakcie walki: lzejsze niz okno, zeby nie zaslanialo gry.
const HUD_FILL := Color(0.04, 0.045, 0.06, 0.62)
## Karta w panelu i pole tekstowe, o ton jasniejsze niz panel.
const PANEL_2 := Color(1.0, 1.0, 1.0, 0.06)
## Prawie czern: znaczki klawiszy, przyciemnienie gry pod oknem, obrys napisow na obrazie.
const DEEP := Color("0b0c10")
## Cienka krawedz panelu.
const LINE := Color(1.0, 1.0, 1.0, 0.1)
const CORAL := Color("ff4d4d")
const SUN := Color("ffc23d")
const TEAL := Color("3ddc97")
const BLUE := Color("4aa8ff")
## Tlo paska z akcentem: prawie czarne, polprzezroczyste, z odrobina koloru akcentu.
const ACCENT_BASE := Color(0.035, 0.04, 0.052, 0.84)
const ACCENT_TINT := 0.16
const ACCENT_EDGE := 4
## Neutralny przycisk drugiego planu.
const NEUTRAL := Color("2a2e37")
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)

const FONT_PATH := "res://assets/fonts/Archivo.ttf"
const AMMO_ICON_PATH := "res://assets/icons/ammo.png"
const POP_FROM := 0.97
const POP_SECONDS := 0.14
const SHAKE_PIXELS := 7.0
const SHAKE_STEP_SECONDS := 0.04
## Zaokraglenie i krawedz panelu sa male niezaleznie od tego, o co prosi wywolujacy.
const MAX_RADIUS := 6
const BORDER := 1

static var _bold: FontVariation
static var _regular: FontVariation
static var _display: FontVariation


## Ustawia czcionke dla calej gry. Mozna wolac wiele razy. Czcionke wczytuja tez same funkcje
## tworzace napisy, bo HUD powstaje wczesniej niz menu.
static func apply_font() -> void:
	_ensure()


static func _ensure() -> void:
	if _bold != null:
		return
	var base := load(FONT_PATH) as FontFile
	_regular = _variation(base, 470, 100)
	_bold = _variation(base, 680, 90)
	_display = _variation(base, 800, 72)


static func _variation(base: FontFile, weight: int, width: int) -> FontVariation:
	var server := TextServerManager.get_primary_interface()
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = { server.name_to_tag("wght"): weight, server.name_to_tag("wdth"): width }
	return variation


## Waska, bardzo gruba czcionka do duzych liczb i tytulow (zegar, wynik, amunicja).
static func display_font() -> Font:
	_ensure()
	return _display if _display != null else font(true)


## Duzy napis czcionka do liczb i tytulow.
static func display_label(text: String, size := 32, color := INK) -> Label:
	_ensure()
	var node := label(text, size, color)
	if _display != null:
		node.add_theme_font_override("font", _display)
	return node


## Maly nadtytul wielkimi literami z odstepem miedzy literami, np. "KONIEC RUNDY".
static func eyebrow(text: String, size := 13, color := Color(INK, 0.6)) -> Label:
	var node := label(text, size, color)
	node.uppercase = true
	return node


## Czcionka gry do rysowania w _draw. Przed apply_font zwraca czcionke zastepcza.
static func font(bold := true) -> Font:
	_ensure()
	var chosen: Font = _bold if bold else _regular
	return chosen if chosen != null else ThemeDB.fallback_font


## Panel. Nazwa zostala po dawnym stylu naklejek: promien i grubosc krawedzi od wywolujacego sa
## tylko wskazowka (wiekszy promien to troche wieksze zaokraglenie), bo nowy styl ma male rogi
## i krawedz 1 px. Dzieki temu stare wywolania nie musza znac nowych liczb.
## Panele sa plaskie, bez cienia: cien pod polprzezroczystym panelem wyglada sztucznie.
## Kolorowe tlo (druzyna, ostrzezenie, seria) zamienia sie w ciemny pasek z akcentem, patrz accent.
static func sticker(fill: Color, radius := 18, _border := 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(corner(radius))
	style.set_content_margin_all(14)
	style.anti_aliasing = true
	if is_signal_color(fill):
		paint_accent(style, fill)
	else:
		style.bg_color = fill
		style.border_color = LINE
		style.set_border_width_all(BORDER)
	return style


## Kolor sygnalowy: nasycony i nieprzezroczysty, np. druzyna, CORAL, SUN. Takie tlo nie wypelnia
## calego panelu, tylko daje akcent.
static func is_signal_color(color: Color) -> bool:
	return color.a > 0.9 and color.s > 0.35 and color.v > 0.35


## Ciemny polprzezroczysty pasek z lekkim odcieniem koloru i grubsza krawedzia w tym kolorze
## (domyslnie z lewej). Tak wygladaja banery, liczniki druzyn i ostrzezenia we wspolczesnych
## strzelankach: kolor jest sygnalem, a tekst zostaje jasny i czytelny.
static func accent(color: Color, radius := 18, side := SIDE_LEFT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(corner(radius))
	style.set_content_margin_all(14)
	style.anti_aliasing = true
	paint_accent(style, color, side)
	return style


## Zmienia kolor akcentu istniejacego panelu, np. baneru albo karty smierci.
static func paint_accent(style: StyleBoxFlat, color: Color, side := SIDE_LEFT) -> void:
	style.bg_color = Color(ACCENT_BASE.lerp(color, ACCENT_TINT), ACCENT_BASE.a)
	style.border_color = color
	style.set_border_width_all(0)
	style.set_border_width(side, ACCENT_EDGE)
	style.shadow_size = 0


## Zwykly ciemny panel HUD, np. gdy baner wraca z koloru do neutralnego.
static func paint_plain(style: StyleBoxFlat, fill := HUD_FILL) -> void:
	style.bg_color = fill
	style.border_color = LINE
	style.set_border_width_all(BORDER)


## Promien rogu w nowym stylu dla promienia z dawnego stylu.
static func corner(old_radius: int) -> int:
	return clampi(roundi(old_radius * 0.3), 2, MAX_RADIUS)


## Plaskie tlo bez krawedzi i cienia, np. wiersz albo karta w panelu.
static func flat(fill := PANEL_2, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	style.anti_aliasing = true
	return style


static func label(text: String, size := 20, color := INK, bold := true) -> Label:
	_ensure()
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
	_ensure()
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
	_ensure()
	var font: Font = _bold if bold else _regular
	if font == null:
		font = ThemeDB.fallback_font
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Dzwiek mowi, co przycisk robi. Przycisk, ktorego skutek ma wlasny dzwiek, np. otwarcie
## okna, dostaje NONE, zeby jedno klikniecie nie gralo dwoch rzeczy naraz.
static func button(text: String, fill := CORAL, text_color := Color.WHITE, sound := Sfx.UiCue.CONFIRM) -> Button:
	_ensure()
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 50)
	node.add_theme_font_size_override("font_size", 20)
	if _bold != null:
		node.add_theme_font_override("font", _bold)
	paint_button(node, fill, text_color)
	node.add_theme_stylebox_override("focus", focus_ring(4))
	ButtonFeel.attach(node, sound)
	return node


## Zmienia kolor przycisku, np. gdy zostaje wybrany. Marginesy tresci zostaja takie, jakie byly.
static func paint_button(node: Button, fill: Color, text_color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, text_color)
	node.add_theme_color_override("font_disabled_color", Color(text_color, 0.45))
	var boxes := {
		"normal": _button_box(fill, Color.TRANSPARENT),
		"hover": _button_box(fill.lightened(0.1), Color(1.0, 1.0, 1.0, 0.45)),
		"pressed": _button_box(fill.darkened(0.15), Color.TRANSPARENT),
		"disabled": _button_box(fill.lerp(NEUTRAL, 0.7), Color.TRANSPARENT),
	}
	for state: String in boxes:
		var box: StyleBoxFlat = boxes[state]
		if node.has_theme_stylebox_override(state):
			var old := node.get_theme_stylebox(state)
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				box.set_content_margin(side, old.get_content_margin(side))
		node.add_theme_stylebox_override(state, box)


## Przycisk drugiego planu: neutralne tlo, jasny tekst.
static func secondary_button(text: String, sound := Sfx.UiCue.CONFIRM) -> Button:
	return button(text, NEUTRAL, INK, sound)


static func _button_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(BORDER if edge.a > 0.0 else 0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	style.anti_aliasing = true
	return style


## Obwodka widoczna tylko przy sterowaniu klawiatura. Inna niz najechanie, zeby bylo wiadomo,
## co zadziala po nacisnieciu Entera, gdy kursor stoi gdzie indziej.
static func focus_ring(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(corner(radius) if radius > MAX_RADIUS else radius)
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
	_ensure()
	var node := LineEdit.new()
	node.text = text
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, 46)
	node.add_theme_font_size_override("font_size", 19)
	if _regular != null:
		node.add_theme_font_override("font", _regular)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	node.add_theme_color_override("caret_color", BLUE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	normal.border_color = LINE
	normal.set_border_width_all(BORDER)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(12)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = BLUE
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("focus", focus)
	node.focus_entered.connect(UiSound.play.bind(Sfx.UiCue.PRESS))
	return node


## Klawisz do nacisniecia, pokazany w podpowiedzi.
static func key_chip(key_name: String, chip_size: float, font_size: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2.ONE * chip_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", chip_box())
	var text := label(key_name, font_size, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(text)
	return chip


## Tlo znaczka klawisza: ciemne, z jasna krawedzia, czytelne i na panelu, i na obrazie gry.
static func chip_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DEEP
	style.border_color = Color(1.0, 1.0, 1.0, 0.3)
	style.set_border_width_all(BORDER)
	style.set_corner_radius_all(3)
	style.anti_aliasing = true
	return style


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
	back.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	back.set_corner_radius_all(1)
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(1)
	node.add_theme_stylebox_override("background", back)
	node.add_theme_stylebox_override("fill", front)
	return node
