extends Node
## Ustawienia gracza zapisane na tym komputerze w user://, a nie obok pliku gry.
## Dzieki temu nowy build czyta te same wartosci i nic nie trzeba ustawiac od nowa.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "options"
const SAVE_DELAY := 0.4

enum Graphics { LOW, MEDIUM, HIGH }
## Skala interfejsu: male, normalne i duze napisy oraz przyciski.
const UI_SCALES: Array[float] = [0.85, 1.0, 1.2]

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
	"aim_sensitivity": 1.0,
	"fullscreen": false,
	"vsync": true,
	"graphics": Graphics.HIGH,
	"render_scale": 1.0,
	"show_fps": true,
	"show_net_graph": false,
	"show_damage_numbers": true,
	"ui_scale": 1,
}

## Ekrany Retina maja wiecej pikseli, niz wyciagnie zintegrowana karta M1.
const MAC_DEFAULTS := {
	"graphics": Graphics.MEDIUM,
	"render_scale": 0.75,
}

var path := DEFAULT_PATH

var _config := ConfigFile.new()
var _save_timer: Timer


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-path="):
			path = arg.trim_prefix("--settings-path=")
	_config.load(path)
	_migrate_old_quality()
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


## Bron rysowana na wierzchu korzysta z tej samej wartosci, co reszta swiata.
func msaa() -> Viewport.MSAA:
	return Viewport.MSAA_4X if graphics() == Graphics.HIGH else Viewport.MSAA_2X


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
	if key.is_empty() or key == "fullscreen":
		_apply_window()
	if key.is_empty() or key == "vsync":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value("vsync") else DisplayServer.VSYNC_DISABLED)
	if key.is_empty() or key == "graphics":
		_apply_graphics()
	if key.is_empty() or key == "ui_scale":
		get_tree().root.content_scale_factor = UI_SCALES[clampi(int(value("ui_scale")), 0, UI_SCALES.size() - 1)]
	if key.is_empty() or key == "render_scale":
		var render_scale: float = value("render_scale")
		get_tree().root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		get_tree().root.scaling_3d_scale = render_scale


## Stary przelacznik "Wysoka jakosc cieni" zamieniamy na nowa skale, zeby zachowac wybor gracza.
func _migrate_old_quality() -> void:
	if _config.has_section_key(SECTION, "high_quality"):
		var high: bool = _config.get_value(SECTION, "high_quality")
		_config.set_value(SECTION, "graphics", Graphics.HIGH if high else Graphics.LOW)
		_config.erase_section_key(SECTION, "high_quality")


## Otoczenie i slonce ustawia scena gry w main.gd, a tutaj jest to, co dotyczy calego silnika.
func _apply_graphics() -> void:
	var level := graphics()
	var high := level == Graphics.HIGH
	var shadow_atlas: int = {Graphics.LOW: 2048, Graphics.MEDIUM: 4096, Graphics.HIGH: 8192}[level]
	var shadow_filter: RenderingServer.ShadowQuality = {
		Graphics.LOW: RenderingServer.SHADOW_QUALITY_HARD,
		Graphics.MEDIUM: RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		Graphics.HIGH: RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	}[level]
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow_filter)
	# Pelne SSAO zabiera na duzym ekranie najwiecej ze wszystkich efektow.
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_HIGH if high else RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		not high, 0.5, 2, 50.0, 300.0)
	get_tree().root.msaa_3d = msaa()


## Wychodzac z pelnego ekranu wracamy do okna, a okna zmaksymalizowanego nie ruszamy.
func _apply_window() -> void:
	var current := DisplayServer.window_get_mode()
	var is_fullscreen := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if value("fullscreen") and not is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not value("fullscreen") and is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
