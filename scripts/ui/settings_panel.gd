class_name SettingsPanel
extends CanvasLayer
## Okno ustawien dostepne z menu glownego i z pauzy. Zmiany dzialaja od razu.

signal closed

var _rows: VBoxContainer
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
	_refresh()
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
	visible = false
	UiSound.play(Sfx.UiCue.CLOSE)
	Settings.save()
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus(true)
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
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

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_card.add_child(_rows)

	var title := UiStyle.label("Ustawienia", 36, UiStyle.BLUE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_child(title)

	_add_slider("Głośność", "volume", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Dźwięki otoczenia", "ambience", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Dźwięki interfejsu", "ui_sounds", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Czułość myszy", "sensitivity", 0.1, 3.0, 0.05, func(v: float) -> String: return "%.2f" % v)
	_add_slider("Czułość przy celowaniu", "aim_sensitivity", 0.3, 1.5, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_slider("Pole widzenia", "fov", 65.0, 110.0, 1.0, func(v: float) -> String: return "%d°" % roundi(v))
	_add_slider("Wstrząsy kamery", "camera_shake", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_add_toggle("Odwrócona mysz w pionie", "invert_y")
	_add_toggle("Pełny ekran", "fullscreen")
	_add_toggle("Synchronizacja pionowa", "vsync")
	_add_toggle("Wysoka jakość cieni", "high_quality")
	_add_toggle("Licznik FPS", "show_fps")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_rows.add_child(buttons)
	var reset := UiStyle.button("Domyślne", UiStyle.TEAL)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(Settings.reset_to_defaults)
	buttons.add_child(reset)
	_done = UiStyle.button("Gotowe", UiStyle.CORAL, Color.WHITE, Sfx.UiCue.NONE)
	_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done.pressed.connect(close)
	buttons.add_child(_done)


func _add_slider(text: String, key: String, min_value: float, max_value: float, step: float, format: Callable) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
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
	shown.custom_minimum_size = Vector2(64, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	slider.value_changed.connect(func(new_value: float) -> void:
		shown.text = format.call(new_value)
		if not is_equal_approx(Settings.value(key), new_value):
			Settings.set_value(key, new_value)
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


func _refresh() -> void:
	for refresher in _refreshers:
		refresher.call()
