extends Node3D
## Glowna scena: laczy swiat, graczy, menu i interfejs.

const MENU_ORBIT_SPEED := 0.08

@onready var players := $Players as Players
@onready var menu_camera := $MenuCamera as Camera3D
@onready var menu := $Menu as Menu
@onready var hud := $Hud as Hud
@onready var settings_panel := $SettingsPanel as SettingsPanel
@onready var world_environment := $World/WorldEnvironment as WorldEnvironment

var _orbit := 0.6


func _ready() -> void:
	players.local_player_spawned.connect(_on_local_player_spawned)
	players.local_player_removed.connect(_on_local_player_removed)
	Net.session_ended.connect(_on_session_ended)
	Net.session_started.connect(_on_session_started)
	menu.settings_requested.connect(settings_panel.open)
	hud.settings_requested.connect(settings_panel.open)
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	hud.visible = false
	if Net.is_headless:
		menu.visible = false
		set_process(false)


func _apply_quality() -> void:
	world_environment.environment.ssao_enabled = Settings.value("high_quality")


func _process(delta: float) -> void:
	if not menu_camera.current:
		return
	_orbit += delta * MENU_ORBIT_SPEED
	menu_camera.position = Vector3(sin(_orbit) * 30.0, 13.0, cos(_orbit) * 30.0)
	menu_camera.look_at(Vector3(0, 2, 0))


func _on_session_started() -> void:
	menu.visible = false


func _on_local_player_spawned(player: Player) -> void:
	menu.visible = false
	hud.bind(player)
	hud.visible = true
	if Net.bot_mode.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_local_player_removed() -> void:
	hud.unbind()
	hud.visible = false
	menu_camera.current = true


func _on_session_ended(reason: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	menu_camera.current = true
	if not Net.is_headless:
		menu.show_with_message(reason)
	elif not reason.is_empty():
		print("[klient] koniec sesji: ", reason)
		get_tree().quit()
