class_name PerfOverlay
extends PanelContainer
## Licznik wydajnosci pod F3: czas klatki, CPU, GPU swiata i broni, ticki sieci i rollbacku,
## rozdzielczosc obrazu 3D i karta graficzna. Shift+F3 kopiuje odczyt, zeby tester mogl go wkleic.
## Z --perf-log gra wypisuje ten sam odczyt co 2 s na konsole.

const AVERAGE_SECONDS := 1.0
const LOG_SECONDS := 2.0

var _label: Label
var _hint: Label
var _frames := 0
var _elapsed := 0.0
var _worst_frame := 0.0
var _ticks := 0
var _rollback_ticks := 0
## Czas petli tickow netfox (ruch, rollback, bron) liczony od jej poczatku do konca.
var _tick_loop_usec := 0
var _tick_loop_started := 0
var _process_ms := 0.0
## Znaczniki na poczatku i koncu kolejki _process, wiec ich roznica to czas wszystkich skryptow.
var _first: Node
var _last: Node
var _process_started := 0
var _process_usec := 0
var _physics_ms := 0.0
var _world_gpu := 0.0
var _weapon_gpu := 0.0
var _text := ""
var _log_timer := 0.0
var _log := false
var _measuring := false
var _copied_until := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.sticker(UiStyle.PAPER, 14, 3)
	style.set_content_margin_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	add_child(rows)
	_label = UiStyle.label("", 14, UiStyle.INK, false)
	rows.add_child(_label)
	_hint = UiStyle.label("Shift+F3 kopiuje odczyt", 13, Color(UiStyle.INK, 0.65), false)
	rows.add_child(_hint)
	_log = Net.args.has("perf-log")
	NetworkTime.on_tick.connect(func(_delta: float, _tick: int) -> void: _ticks += 1)
	NetworkRollback.on_process_tick.connect(func(_tick: int) -> void: _rollback_ticks += 1)
	NetworkTime.before_tick_loop.connect(func() -> void: _tick_loop_started = Time.get_ticks_usec())
	NetworkTime.after_tick_loop.connect(func() -> void: _tick_loop_usec += Time.get_ticks_usec() - _tick_loop_started)
	visible = false
	_first = _marker(-100000, func() -> void: _process_started = Time.get_ticks_usec())
	_last = _marker(100000, func() -> void:
		if _process_started > 0:
			_process_usec += Time.get_ticks_usec() - _process_started)
	_set_measuring(_log)


func _marker(priority: int, callback: Callable) -> Node:
	var node := Node.new()
	node.process_priority = priority
	node.set_script(_MarkerScript)
	node.set_meta(&"callback", callback)
	add_child(node)
	return node


func toggle() -> void:
	visible = not visible
	_set_measuring(visible or _log)


func copy_to_clipboard() -> void:
	DisplayServer.clipboard_set(_text)
	_copied_until = Time.get_ticks_msec() / 1000.0 + 1.5


func text() -> String:
	return _text


func _set_measuring(on: bool) -> void:
	_measuring = on
	set_process(on)
	if _first != null:
		_first.set_process(on)
		_last.set_process(on)
	# Automatyczna rozdzielczosc tez czyta czas GPU, wiec wtedy pomiaru nie wylaczamy.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), on or Settings.value("render_auto"))
	var weapon := _weapon_viewport()
	if weapon != null:
		RenderingServer.viewport_set_measure_render_time(weapon.get_viewport_rid(), on)


func _weapon_viewport() -> SubViewport:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	for child in camera.get_children():
		if child is ViewModel:
			return (child as ViewModel).overlay_viewport()
	return null


func _process(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	_worst_frame = maxf(_worst_frame, delta)
	_process_ms += _process_usec / 1000.0
	_process_usec = 0
	_physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_world_gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	var weapon := _weapon_viewport()
	if weapon != null:
		# Bron moze pojawic sie po wlaczeniu licznika, wiec pomiar wlaczamy przy kazdej klatce.
		RenderingServer.viewport_set_measure_render_time(weapon.get_viewport_rid(), true)
		_weapon_gpu += RenderingServer.viewport_get_measured_render_time_gpu(weapon.get_viewport_rid())
	_hint.text = "Skopiowano" if Time.get_ticks_msec() / 1000.0 < _copied_until else "Shift+F3 kopiuje odczyt"
	if _elapsed < AVERAGE_SECONDS:
		return
	_text = _build_text()
	_label.text = _text
	_log_timer += _elapsed
	if _log and _log_timer >= LOG_SECONDS:
		_log_timer = 0.0
		print("[perf] " + _text.replace("\n", " | "))
	_frames = 0
	_elapsed = 0.0
	_worst_frame = 0.0
	_ticks = 0
	_rollback_ticks = 0
	_tick_loop_usec = 0
	_process_ms = 0.0
	_physics_ms = 0.0
	_world_gpu = 0.0
	_weapon_gpu = 0.0


func _build_text() -> String:
	var frames := float(maxi(_frames, 1))
	var root := get_tree().root
	var window := get_window().size
	var scale := root.scaling_3d_scale
	var internal := Vector2i(roundi(window.x * scale), roundi(window.y * scale))
	var lines: Array[String] = [
		"%d FPS  klatka %.1f ms (najgorsza %.1f)" % [roundi(_frames / _elapsed), _elapsed / frames * 1000.0, _worst_frame * 1000.0],
		"CPU: skrypty %.1f ms, fizyka %.1f ms" % [_process_ms / frames, _physics_ms / frames],
		"GPU: świat %.1f ms, broń %.1f ms" % [_world_gpu / frames, _weapon_gpu / frames],
		"Sieć: %.1f ticku i %.1f rollbacku na klatkę, %.1f ms" % [_ticks / frames, _rollback_ticks / frames, _tick_loop_usec / frames / 1000.0],
		"Obraz: %d wywołań, %d tys. trójkątów" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			roundi(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)],
		"Okno %dx%d (skala ekranu %.1f), 3D %dx%d" % [window.x, window.y, DisplayServer.screen_get_scale(), internal.x, internal.y],
		"Grafika %s, MSAA %s, %s" % [SettingsPanel.GRAPHICS_NAMES[Settings.graphics()], _msaa_name(root.msaa_3d), "FSR" if root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR else "bez FSR"],
		"%s %s, %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()],
		"%s %s, vsync %s, limit %d" % [OS.get_name(), Engine.get_architecture_name(), "wł." if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "wył.", Engine.max_fps],
	]
	return "\n".join(lines)


## Wezel znacznika czasu: na kazdej klatce wola funkcje zapisana w meta.
static var _MarkerScript := _marker_script()


static func _marker_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node
func _process(_delta: float) -> void:
	(get_meta(&\"callback\") as Callable).call()
"
	script.reload()
	return script


static func _msaa_name(msaa: Viewport.MSAA) -> String:
	return ["wył.", "2x", "4x", "8x"][int(msaa)] if int(msaa) < 4 else "?"
