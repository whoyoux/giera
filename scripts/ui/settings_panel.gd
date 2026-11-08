class_name SettingsPanel
extends CanvasLayer
## Okno ustawien dostepne z menu glownego i z pauzy. Zmiany dzialaja od razu.

signal closed

## Wysokosc listy ustawien. Reszta przewija sie, wiec okno zostaje niskie.
const LIST_HEIGHT := 350.0

var _rows: VBoxContainer
var _keys: KeybindPage
var _scroll: ScrollContainer
var _tabs := {}
const GRAPHICS_NAMES: Array[String] = ["Niska", "Średnia", "Wysoka"]

var _refreshers: Array[Callable] = []
var _shade: ColorRect
var _card: PanelContainer
var _done: Button
## Co mialo fokus przed otwarciem. Po zamknieciu klawiatura wraca w to samo miejsce.
var _focus_before: Control


func _ready() -> void:
	layer = 5
	visible = false
	_build()
	Settings.changed.connect(_refresh)


func open() -> void:
	_show_page(false)
	_refresh()
	_scroll.scroll_vertical = 0
	_focus_before = get_viewport().gui_get_focus_owner()
	visible = true
	UiSound.play(Sfx.UiCue.OPEN)
	UiStyle.pop_in(_card)
	_shade.modulate.a = 0.0
	_shade.create_tween().tween_property(_shade, "modulate:a", 1.0, UiStyle.POP_SECONDS)
	_done.grab_focus(true)


func close() -> void:
	if not visible:
		return
	_keys.cancel()
	visible = false
	UiSound.play(Sfx.UiCue.CLOSE)
	Settings.save()
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus(true)
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and not _keys.is_waiting():
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(UiStyle.INK, 0.35)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(560, 0)
	_card.add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	center.add_child(_card)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_card.add_child(layout)

	var title := UiStyle.label("Ustawienia", 36, UiStyle.BLUE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	layout.add_child(tabs)
	for page: Array in [["general_tab", "Ogólne", false], ["keys_tab", "Klawisze", true]]:
		var tab := UiStyle.button(page[1], UiStyle.BLUE, Color.WHITE, Sfx.UiCue.PRESS)
		tab.name = page[0]
		tab.custom_minimum_size.y = 44.0
		tab.add_theme_font_size_override("font_size", 19)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_page.bind(page[2]))
		tabs.add_child(tab)
		_tabs[page[2]] = tab

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Strzalki przewijaja liste do wybranego wiersza.
	_scroll.follow_focus = true
	layout.add_child(_scroll)
	# Odstep, zeby pasek przewijania nie nachodzil na suwaki.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 16)
	_scroll.add_child(gutter)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(pages)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	pages.add_child(_rows)
	_keys = KeybindPage.new()
	_keys.visible = false
	pages.add_child(_keys)

	_add_slider("Wielkość interfejsu", "ui_size", Settings.UI_SIZE_MIN, Settings.UI_SIZE_MAX, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0), false)
	_add_slider("Głośność", "volume", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Dźwięki otoczenia", "ambience", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Dźwięki interfejsu", "ui_sounds", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Muzyka tańców", "dance_music", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Czułość myszy", "sensitivity", 0.1, 3.0, 0.05, func(v: float) -> String: return "%.2f" % v)
	_add_slider("Czułość przy celowaniu", "aim_sensitivity", 0.3, 1.5, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Pole widzenia", "fov", 65.0, 110.0, 1.0, func(v: float) -> String: return "%d°" % roundi(v))
	_add_slider("Wstrząsy kamery", "camera_shake", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Siła odrzutu kamery", "recoil_camera", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Jakość grafiki", "graphics", Settings.Graphics.LOW, Settings.Graphics.HIGH, 1.0, func(v: float) -> String: return GRAPHICS_NAMES[roundi(v)])
	_add_slider("Rozdzielczość 3D", "render_scale", 0.5, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_toggle("Odwrócona mysz w pionie", "invert_y")
	_add_toggle("Pełny ekran", "fullscreen")
	_add_toggle("Synchronizacja pionowa", "vsync")
	_add_toggle("Licznik FPS", "show_fps")
	_add_toggle("Liczby obrażeń", "show_damage_numbers")
	_add_toggle("Wykres sieci (debug)", "show_net_graph")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)
	var reset := UiStyle.button("Domyślne", UiStyle.TEAL)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Na stronie klawiszy przycisk przywraca klawisze, a na pierwszej pozostale ustawienia.
	reset.pressed.connect(func() -> void:
		if _keys.visible:
			_keys.reset_all()
		else:
			Settings.reset_to_defaults())
	buttons.add_child(reset)
	_done = UiStyle.button("Gotowe", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.NONE)
	_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done.pressed.connect(close)
	buttons.add_child(_done)


## "live" wylaczone zapisuje wartosc dopiero po puszczeniu suwaka. Tak jest przy wielkosci interfejsu,
## bo zmiana skali w trakcie przeciagania przesuwalaby suwak pod kursorem.
func _add_slider(text: String, key: String, min_value: float, max_value: float, step: float, format: Callable, live := true) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	# Kolko myszy ma przewijac liste, a nie zmieniac wartosc pod kursorem.
	slider.scrollable = false
	slider.custom_minimum_size = Vector2(190, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(UiStyle.INK, 0.16)
	track.set_corner_radius_all(8)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = UiStyle.TEAL
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	row.add_child(slider)
	var shown := UiStyle.label("", 19, UiStyle.INK)
	shown.custom_minimum_size = Vector2(68, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	var dragging := [false]
	var commit := func() -> void:
		if not is_equal_approx(Settings.value(key), slider.value):
			Settings.set_value(key, slider.value)
	slider.drag_started.connect(func() -> void: dragging[0] = true)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		dragging[0] = false
		commit.call())
	slider.value_changed.connect(func(new_value: float) -> void:
		shown.text = format.call(new_value)
		if live or not dragging[0]:
			commit.call()
		# Gra juz z nowa glosnoscia, wiec suwak od razu pokazuje, jak glosno bedzie.
		UiSound.slider(inverse_lerp(min_value, max_value, new_value)))
	_refreshers.append(func() -> void:
		slider.set_value_no_signal(Settings.value(key))
		shown.text = format.call(slider.value))


func _add_toggle(text: String, key: String) -> void:
	var row := _row(text)
	var toggle := Button.new()
	toggle.name = key
	toggle.toggle_mode = true
	toggle.custom_minimum_size = Vector2(84, 34)
	toggle.add_theme_font_size_override("font_size", 17)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(UiStyle.INK, 0.16)
	off.set_corner_radius_all(17)
	var on_style := off.duplicate() as StyleBoxFlat
	on_style.bg_color = UiStyle.TEAL
	var off_hover := off.duplicate() as StyleBoxFlat
	off_hover.bg_color = Color(UiStyle.INK, 0.26)
	var on_hover := on_style.duplicate() as StyleBoxFlat
	on_hover.bg_color = UiStyle.TEAL.lightened(0.15)
	toggle.add_theme_stylebox_override("normal", off)
	toggle.add_theme_stylebox_override("hover", off_hover)
	toggle.add_theme_stylebox_override("pressed", on_style)
	toggle.add_theme_stylebox_override("hover_pressed", on_hover)
	toggle.add_theme_stylebox_override("focus", UiStyle.focus_ring(17))
	ButtonFeel.attach(toggle, Sfx.UiCue.NONE, false)
	toggle.add_theme_color_override("font_color", UiStyle.INK)
	toggle.add_theme_color_override("font_hover_color", UiStyle.INK)
	toggle.add_theme_color_override("font_focus_color", UiStyle.INK)
	toggle.add_theme_color_override("font_pressed_color", Color.WHITE)
	toggle.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	toggle.toggled.connect(func(on: bool) -> void:
		toggle.text = "Wł." if on else "Wył."
		if Settings.value(key) != on:
			Settings.set_value(key, on))
	row.add_child(toggle)
	_refreshers.append(func() -> void:
		toggle.set_pressed_no_signal(Settings.value(key))
		toggle.text = "Wł." if toggle.button_pressed else "Wył.")


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 36)
	var caption := UiStyle.label(text, 19, UiStyle.INK, false)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	_rows.add_child(row)
	return row


## Klawisze maja osobna strone, bo lista ustawien bylaby inaczej bardzo dluga.
func _show_page(keys: bool) -> void:
	_keys.cancel()
	_rows.visible = not keys
	_keys.visible = keys
	_scroll.scroll_vertical = 0
	for page: bool in _tabs:
		(_tabs[page] as Button).modulate = Color.WHITE if page == keys else Color(1.0, 1.0, 1.0, 0.6)


func _refresh() -> void:
	for refresher in _refreshers:
		refresher.call()
	_keys.refresh()
