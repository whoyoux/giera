extends Node3D
## Glowna scena: laczy swiat, graczy, menu i interfejs.

const MENU_ORBIT_SPEED := 0.08

@onready var players := $Players as Players
@onready var menu_camera := $MenuCamera as Camera3D
@onready var menu := $Menu as Menu
@onready var hud := $Hud as Hud
@onready var settings_panel := $SettingsPanel as SettingsPanel

var _orbit := 0.6
var _chest_field: ChestField


func _ready() -> void:
	players.local_player_spawned.connect(_on_local_player_spawned)
	players.local_player_removed.connect(_on_local_player_removed)
	Net.session_ended.connect(_on_session_ended)
	Net.session_started.connect(_on_session_started)
	menu.settings_requested.connect(settings_panel.open)
	hud.settings_requested.connect(settings_panel.open)
	Settings.changed.connect(_apply_quality)
	Maps.changed.connect(_load_world)
	_load_world(Maps.current_id)
	if not Net.is_headless:
		add_child(SpectatorCamera.new())
		add_child(ZoneView.new())
	if not Net.is_headless:
		add_child(PickupField.new())
		add_child(ExplosionPool.new())
		add_child(DamageNumbers.new())
		add_child(PodiumView.new())
		add_child(DropView.new())
		var stats := PlayerStats.new()
		stats.name = "PlayerStats"
		add_child(stats)
		var stats_panel := StatsPanel.new()
		add_child(stats_panel)
		menu.stats_requested.connect(func() -> void: stats_panel.open(stats))
	_apply_quality()
	hud.visible = false
	if Net.is_headless:
		menu.visible = false
		set_process(false)
	_report_started()


## Launcher czeka na ten plik, zeby wiedziec, ze nowa wersja naprawde sie uruchomila.
func _report_started() -> void:
	var marker: String = Net.args.get("launcher-marker", "")
	if not marker.is_empty():
		var file := FileAccess.open(marker, FileAccess.WRITE)
		if file != null:
			file.store_string("ok")


## Podmienia swiat na scene mapy. Stary znika od razu, zeby jego punkty startu i skrzynki
## nie zostaly w grupach, a skrzynki rejestruja sie od nowa.
func _load_world(id: String) -> void:
	var old := get_node_or_null("World")
	if old != null:
		remove_child(old)
		old.free()
	if _chest_field != null:
		remove_child(_chest_field)
		_chest_field.free()
	Chests.clear_all()
	var world := (load(Maps.info(id).scene_path) as PackedScene).instantiate() as Node3D
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	_chest_field = ChestField.new()
	add_child(_chest_field)
	_apply_quality()


func _apply_quality() -> void:
	var world := get_node_or_null("World")
	if world == null:
		return
	var low: bool = Settings.graphics() == Settings.Graphics.LOW
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.ssao_enabled = not low
	environment.glow_enabled = not low
	(world.get_node("Sun") as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if low else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _process(delta: float) -> void:
	if not menu_camera.current:
		return
	_orbit += delta * MENU_ORBIT_SPEED
	# Kamera krazy nad mapa, np. nad koronami drzew, skad widac ruiny na polanie.
	var orbit := Maps.info().menu_orbit
	var center := Maps.info().zone_center
	menu_camera.position = Vector3(center.x + sin(_orbit) * orbit.x, orbit.y, center.y + cos(_orbit) * orbit.x)
	menu_camera.look_at(Vector3(center.x, orbit.z, center.y))


func _on_session_started() -> void:
	menu.visible = false


func _on_local_player_spawned(player: Player) -> void:
	menu.visible = false
	hud.bind(player)
	hud.visible = true
	if TutorialPanel.should_show():
		hud.show_tutorial()
	if ExplosionPool.instance != null:
		ExplosionPool.instance.warm_up(player.camera)
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
