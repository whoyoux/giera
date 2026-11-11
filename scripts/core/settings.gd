extends Node
## Ustawienia gracza zapisane na tym komputerze w user://, a nie obok pliku gry.
## Dzieki temu nowy build czyta te same wartosci i nic nie trzeba ustawiac od nowa.

signal changed
## Automat zmienil skale obrazu 3D. Bron na wierzchu dopasowuje wtedy swoj rozmiar.
signal render_scale_changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "options"
const SAVE_DELAY := 0.4

enum Graphics { LOW, MEDIUM, HIGH }
## Skala interfejsu z suwaka. Starsza wersja zapisywala numer jednej z trzech wielkosci.
const UI_SIZE_MIN := 0.6
## HUD jest ulozony dla 1280x720 punktow. Wiekszy nie miesci sie bez nakladania sie elementow.
const UI_SIZE_MAX := 1.0
const OLD_UI_SCALES: Array[float] = [0.85, 1.0, 1.2]
## Tryb okna: zwykle okno, pelny ekran bez ramki albo pelny ekran na wylacznosc.
enum WindowMode { WINDOWED, BORDERLESS, EXCLUSIVE }
const WINDOW_MODE_NAMES: Array[String] = ["Okno", "Bez ramki", "Pełny ekran"]
## Rozmiary okna do wyboru. Pierwsza pozycja zostawia okno takie, jak ustawil je gracz.
const WINDOW_SIZES: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## Limity klatek do wyboru. Zero oznacza brak limitu.
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
const CROSSHAIR_COLORS: Array[Color] = [Color.WHITE, Color("5dff7a"), Color("ffe14d"), Color("5de8ff"), Color("ff7ad9"), Color("ff5d5d")]
const CROSSHAIR_COLOR_NAMES: Array[String] = ["Biały", "Zielony", "Żółty", "Błękitny", "Różowy", "Czerwony"]

## Domyslne wartosci. Nowe ustawienie wystarczy dopisac tutaj.
const DEFAULTS := {
	"volume": 0.8,
	"ambience": 1.0,
	"ui_sounds": 1.0,
	"dance_music": 0.8,
	"sensitivity": 1.0,
	"invert_y": false,
	"fov": 80.0,
	"camera_shake": 1.0,
	# Uderzenie kamery od wlasnego strzalu, od 0 do 1. Nie zmienia kierunku pocisku.
	"recoil_camera": 1.0,
	"aim_sensitivity": 1.0,
	"window_mode": WindowMode.WINDOWED,
	# Numer pozycji z WINDOW_SIZES i FPS_LIMITS.
	"window_size": 0,
	"fps_limit": 0,
	"vsync": true,
	"graphics": Graphics.HIGH,
	"render_scale": 1.0,
	# Skala 3D dobierana do rozmiaru okna, zeby obraz 3D mial najwyzej AUTO_RENDER_PIXELS.
	"render_auto": false,
	"show_fps": true,
	"show_net_graph": false,
	"show_damage_numbers": true,
	"ui_size": 1.0,
	# Przelaczanie zamiast trzymania klawisza.
	"toggle_aim": false,
	"toggle_crouch": false,
	# Celownik: numer koloru z CROSSHAIR_COLORS, skala dlugosci i grubosci kresek.
	"crosshair_color": 0,
	"crosshair_size": 1.0,
	"crosshair_thickness": 1.0,
	"crosshair_dot": true,
	"crosshair_outline": true,
	# Wylaczone daje celownik o stalym rozmiarze, ktory nie pokazuje rozrzutu.
	"crosshair_spread": true,
}

## Ekrany Retina maja wiecej pikseli, niz wyciagnie zintegrowana karta M1.
const MAC_DEFAULTS := {
	"graphics": Graphics.MEDIUM,
	"render_scale": 0.75,
	"render_auto": true,
}
## Automatyczna skala 3D celuje w tyle pikseli obrazu 3D (mniej wiecej 1600x900).
const AUTO_RENDER_PIXELS := 1600.0 * 900.0
const AUTO_RENDER_MIN := 0.4
## Automat obniza rozdzielczosc, gdy GPU rysuje swiat dluzej, i podnosi, gdy ma zapas.
## Progi zostawiaja miejsce na bron, interfejs i CPU w klatce 60 FPS.
const AUTO_GPU_SLOW_MS := 12.0
const AUTO_GPU_FAST_MS := 8.0
const AUTO_STEP := 0.05
const AUTO_CHECK_SECONDS := 0.5
## Numer zestawu domyslnych ustawien grafiki na macOS. Podniesienie go raz przywraca te ustawienia
## u graczy, ktorzy zapisali starsze, za ciezkie dla M1.
const MAC_GRAPHICS_RESET := 1

## Co wlacza kazdy poziom grafiki. Zasieg roslinnosci i cieni to mnoznik odleglosci z map.
const LEVELS := {
	Graphics.LOW: { "shadow_atlas": 2048, "shadow_filter": RenderingServer.SHADOW_QUALITY_HARD, "splits": 2,
		"shadow_range": 0.6, "view_range": 0.6, "ssao": false, "glow": false, "msaa": Viewport.MSAA_DISABLED, "fxaa": true },
	Graphics.MEDIUM: { "shadow_atlas": 4096, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "splits": 2,
		"shadow_range": 0.8, "view_range": 0.8, "ssao": true, "glow": true, "msaa": Viewport.MSAA_2X, "fxaa": false },
	Graphics.HIGH: { "shadow_atlas": 8192, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "splits": 4,
		"shadow_range": 1.0, "view_range": 1.0, "ssao": true, "glow": true, "msaa": Viewport.MSAA_4X, "fxaa": false },
}

var path := DEFAULT_PATH

var _config := ConfigFile.new()
var _save_timer: Timer
## Skala z automatu, ktora wynika z czasu GPU. Nigdy nie przekracza limitu pikseli dla okna.
var _dynamic_scale := 1.0
## Progi automatu. Test na szybkiej karcie obniza je, zeby automat w ogole zareagowal.
var auto_gpu_slow_ms := AUTO_GPU_SLOW_MS
var auto_gpu_fast_ms := AUTO_GPU_FAST_MS
var _gpu_ms := 0.0
var _gpu_frames := 0
var _gpu_timer := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-path="):
			path = arg.trim_prefix("--settings-path=")
	set_process(false)
	_config.load(path)
	_migrate_old_quality()
	_reset_mac_graphics()
	Keybinds.load_from(_config)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_timer != null and not _save_timer.is_stopped():
		save()


func value(key: String) -> Variant:
	return _config.get_value(SECTION, key, default_of(key))


func default_of(key: String) -> Variant:
	if OS.has_feature("macos") and MAC_DEFAULTS.has(key):
		return MAC_DEFAULTS[key]
	return DEFAULTS[key]


func graphics() -> Graphics:
	return int(value("graphics")) as Graphics


## Ustawienie poziomu grafiki, np. level("splits").
func level(key: String) -> Variant:
	return LEVELS[graphics()][key]


## Bron rysowana na wierzchu korzysta z tej samej wartosci, co reszta swiata.
func msaa() -> Viewport.MSAA:
	return level("msaa")


## Mnoznik zasiegu roslinnosci i rekwizytow. Mapy czytaja go przy budowie.
func view_range() -> float:
	return level("view_range")


## Skala obrazu 3D wzgledem okna, z automatem albo z suwaka.
func render_scale() -> float:
	if not value("render_auto"):
		return float(value("render_scale"))
	return minf(_dynamic_scale, auto_render_scale(get_window().size if is_inside_tree() else Vector2i(1280, 720)))


static func auto_render_scale(window: Vector2i) -> float:
	var pixels := maxf(1.0, float(window.x) * float(window.y))
	return clampf(snappedf(sqrt(AUTO_RENDER_PIXELS / pixels), 0.05), AUTO_RENDER_MIN, 1.0)


## Zmienia ustawienie od razu, a zapis na dysk odklada, zeby suwak nie pisal co klatke.
func set_value(key: String, new_value: Variant) -> void:
	_config.set_value(SECTION, key, new_value)
	apply(key)
	changed.emit()
	if _save_timer != null:
		_save_timer.start()


func reset_to_defaults() -> void:
	if _config.has_section(SECTION):
		_config.erase_section(SECTION)
	apply()
	changed.emit()
	if _save_timer != null:
		_save_timer.start()


## Zwraca nazwe akcji, ktora oddala klawisz, albo pusty tekst.
func assign_keybind(action: String, event: InputEvent) -> String:
	var swapped := Keybinds.assign(_config, action, event)
	changed.emit()
	save()
	return swapped


func reset_keybinds() -> void:
	Keybinds.reset(_config)
	changed.emit()
	save()


func save() -> void:
	_save_timer.stop()
	var error := _config.save(path)
	if error != OK:
		push_error("Nie mozna zapisac ustawien: %s" % error_string(error))


func player_value(key: String, fallback: String) -> String:
	return _config.get_value("player", key, fallback)


func set_player_value(key: String, new_value: String) -> void:
	_config.set_value("player", key, new_value)
	save()


## Stosuje ustawienia. Pusty klucz oznacza wszystkie, a podany tylko to jedno, zeby suwak
## glosnosci nie ruszal okna ani cieni.
func apply(key := "") -> void:
	if key.is_empty() or key == "volume":
		var volume: float = value("volume")
		AudioServer.set_bus_mute(0, volume <= 0.001)
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if DisplayServer.get_name() == "headless":
		return
	if key.is_empty() or key == "window_mode":
		_apply_window()
	# Przy starcie nie ruszamy okna, ktore gracz ustawil sam, ani limitu z linii polecen.
	if key == "window_size" or (key.is_empty() and int(value("window_size")) > 0):
		_apply_window_size()
	if key == "fps_limit" or (key.is_empty() and fps_limit() > 0):
		Engine.max_fps = fps_limit()
	if key.is_empty() or key == "vsync":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value("vsync") else DisplayServer.VSYNC_DISABLED)
	if key.is_empty() or key == "graphics":
		_apply_graphics()
	if key.is_empty() or key == "ui_size":
		get_tree().root.content_scale_factor = clampf(float(value("ui_size")), UI_SIZE_MIN, UI_SIZE_MAX)
	if key.is_empty() or key == "render_scale" or key == "render_auto":
		_apply_render_scale()


func _apply_render_scale() -> void:
	var auto: bool = value("render_auto")
	var root := get_tree().root
	set_process(auto)
	if auto:
		_dynamic_scale = minf(_dynamic_scale, auto_render_scale(root.size))
		# Czas GPU mierzy sam silnik, a automat tylko go czyta.
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_set_root_scale(render_scale())
	if not root.size_changed.is_connected(_on_window_resized):
		root.size_changed.connect(_on_window_resized)


func _set_root_scale(scale: float) -> void:
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = scale


func _on_window_resized() -> void:
	if value("render_auto"):
		# Wieksze okno zaczyna od limitu pikseli, a automat zejdzie nizej, jesli trzeba.
		_dynamic_scale = 1.0
		_apply_render_scale()
		render_scale_changed.emit()


## Automatyczna rozdzielczosc: co pol sekundy porownuje sredni czas GPU swiata z progami.
func _process(delta: float) -> void:
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_tree().root.get_viewport_rid())
	# Sterownik bez pomiaru czasu zwraca zero. Wtedy zostaje sam limit pikseli.
	if gpu <= 0.0:
		return
	_gpu_ms += gpu
	_gpu_frames += 1
	_gpu_timer += delta
	if _gpu_timer < AUTO_CHECK_SECONDS:
		return
	var average := _gpu_ms / _gpu_frames
	_gpu_ms = 0.0
	_gpu_frames = 0
	_gpu_timer = 0.0
	var cap := auto_render_scale(get_tree().root.size)
	var current := render_scale()
	var wanted := current
	if average > auto_gpu_slow_ms:
		wanted = maxf(AUTO_RENDER_MIN, current - AUTO_STEP)
	elif average < auto_gpu_fast_ms:
		wanted = minf(cap, current + AUTO_STEP)
	if not is_equal_approx(wanted, current):
		_dynamic_scale = wanted
		_set_root_scale(render_scale())
		render_scale_changed.emit()


## Na macOS przywracamy raz domyslne ustawienia grafiki, bo starsze zapisy (np. wysoka jakosc
## przeniesiona ze starego przelacznika cieni) dawaly na M1 kilkanascie klatek.
func _reset_mac_graphics() -> void:
	if not OS.has_feature("macos") or int(_config.get_value(SECTION, "mac_graphics_reset", 0)) >= MAC_GRAPHICS_RESET:
		return
	for key: String in MAC_DEFAULTS:
		if _config.has_section_key(SECTION, key):
			_config.erase_section_key(SECTION, key)
	_config.set_value(SECTION, "mac_graphics_reset", MAC_GRAPHICS_RESET)
	_config.save(path)


## Stary przelacznik "Wysoka jakosc cieni" zamieniamy na nowa skale, zeby zachowac wybor gracza.
func _migrate_old_quality() -> void:
	if _config.has_section_key(SECTION, "high_quality"):
		var high: bool = _config.get_value(SECTION, "high_quality")
		_config.set_value(SECTION, "graphics", Graphics.HIGH if high else Graphics.LOW)
		_config.erase_section_key(SECTION, "high_quality")
	if _config.has_section_key(SECTION, "fullscreen"):
		if _config.get_value(SECTION, "fullscreen"):
			_config.set_value(SECTION, "window_mode", WindowMode.BORDERLESS)
		_config.erase_section_key(SECTION, "fullscreen")
	if _config.has_section_key(SECTION, "ui_scale"):
		var index := clampi(int(_config.get_value(SECTION, "ui_scale")), 0, OLD_UI_SCALES.size() - 1)
		_config.set_value(SECTION, "ui_size", minf(OLD_UI_SCALES[index], UI_SIZE_MAX))
		_config.erase_section_key(SECTION, "ui_scale")


## Otoczenie i slonce ustawia scena gry w main.gd, a tutaj jest to, co dotyczy calego silnika.
func _apply_graphics() -> void:
	var high := graphics() == Graphics.HIGH
	RenderingServer.directional_shadow_atlas_set_size(level("shadow_atlas"), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(level("shadow_filter"))
	# Pelne SSAO zabiera na duzym ekranie najwiecej ze wszystkich efektow.
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_HIGH if high else RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		not high, 0.5, 2, 50.0, 300.0)
	get_tree().root.msaa_3d = msaa()
	# Bez MSAA krawedzie wygladzamy tanim FXAA.
	get_tree().root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level("fxaa") else Viewport.SCREEN_SPACE_AA_DISABLED


## Wychodzac z pelnego ekranu wracamy do okna, a okna zmaksymalizowanego nie ruszamy.
func _apply_window() -> void:
	var current := DisplayServer.window_get_mode()
	var wanted := int(value("window_mode"))
	var target := DisplayServer.WINDOW_MODE_WINDOWED
	if wanted == WindowMode.BORDERLESS:
		target = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif wanted == WindowMode.EXCLUSIVE:
		target = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var is_fullscreen := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if wanted == WindowMode.WINDOWED and not is_fullscreen:
		return
	if current != target:
		DisplayServer.window_set_mode(target)
		if target == DisplayServer.WINDOW_MODE_WINDOWED:
			_apply_window_size()


func fps_limit() -> int:
	return FPS_LIMITS[clampi(int(value("fps_limit")), 0, FPS_LIMITS.size() - 1)]


func crosshair_color() -> Color:
	return CROSSHAIR_COLORS[clampi(int(value("crosshair_color")), 0, CROSSHAIR_COLORS.size() - 1)]


## Rozmiar okna dziala tylko w trybie okna. Okno wieksze niz ekran jest przycinane i staje na srodku.
func _apply_window_size() -> void:
	var wanted := WINDOW_SIZES[clampi(int(value("window_size")), 0, WINDOW_SIZES.size() - 1)]
	if wanted == Vector2i.ZERO or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	var fitted := Vector2i(mini(wanted.x, area.size.x), mini(wanted.y, area.size.y))
	DisplayServer.window_set_size(fitted)
	DisplayServer.window_set_position(area.position + (area.size - fitted) / 2)
