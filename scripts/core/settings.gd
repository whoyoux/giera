extends Node
## Ustawienia gracza zapisane na tym komputerze w user://, a nie obok pliku gry.
## Dzieki temu nowy build czyta te same wartosci i nic nie trzeba ustawiac od nowa.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "options"
const SAVE_DELAY := 0.4

## Domyslne wartosci. Nowe ustawienie wystarczy dopisac tutaj.
const DEFAULTS := {
	"volume": 0.8,
	"sensitivity": 1.0,
	"invert_y": false,
	"fov": 80.0,
	"camera_shake": 1.0,
	"aim_sensitivity": 1.0,
	"fullscreen": false,
	"vsync": true,
	"high_quality": true,
	"show_fps": true,
}

var path := DEFAULT_PATH

var _config := ConfigFile.new()
var _save_timer: Timer


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-path="):
			path = arg.trim_prefix("--settings-path=")
	_config.load(path)
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
	return _config.get_value(SECTION, key, DEFAULTS[key])


## Zmienia ustawienie od razu, a zapis na dysk odklada, zeby suwak nie pisal co klatke.
func set_value(key: String, new_value: Variant) -> void:
	_config.set_value(SECTION, key, new_value)
	apply()
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


func apply() -> void:
	var volume: float = value("volume")
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if DisplayServer.get_name() == "headless":
		return
	var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != window_mode:
		DisplayServer.window_set_mode(window_mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value("vsync") else DisplayServer.VSYNC_DISABLED)
	var high: bool = value("high_quality")
	RenderingServer.directional_shadow_atlas_set_size(8192 if high else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if high else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
