class_name ViewModel
extends Node3D
## Bron w pierwszej osobie: kreskowkowe rekawice na blasterze. Wszystkie ruchy sa
## liczone w kodzie: odrzut, kolysanie, przeladowanie, sprint, skok i ladowanie.

const BASE_POSITION := Vector3(0.24, -0.2, -0.56)
const GUN_SCALE := 0.62
const RIGHT_HAND := Vector3(0.0, -0.17, 0.11)
const LEFT_HAND := Vector3(-0.015, -0.1, -0.2)
const GLOVE := Color("fffaf0")
## Warstwa widziana tylko przez kamere nakladki, nigdy przez kamere swiata.
const OVERLAY_LAYER := 20

var _main_camera: Camera3D
var _overlay_camera: Camera3D
var _overlay_viewport: SubViewport
var _gun: Node3D
var _left: Node3D
var _magazine: Node3D
var _model: Node3D
var _model_path := ""
var _has_item := true
var _reload_seconds := 1.6
var _magazine_home := Vector3.ZERO
var _muzzle: Node3D
var _flash: MeshInstance3D
var _time := 0.0
var _recoil := 0.0
var _flash_time := 0.0
var _hide := 1.0
var _sprint := 0.0
var _landing := 0.0
var _fall_speed := 0.0
var _sway := Vector2.ZERO
var _reload_time := -1.0
var _was_on_floor := true
var _bob_amount := 0.0
var _lift := 0.0
var _landing_shown := 0.0


func setup(peer_id: int) -> void:
	_gun = Node3D.new()
	_gun.scale = Vector3.ONE * GUN_SCALE
	add_child(_gun)
	var sleeve := CharacterAssets.color_for(peer_id)
	_add_hand(_gun, RIGHT_HAND, Vector3(-28, 0, 0), sleeve, Vector3(0.05, -0.2, 0.3))
	_left = _add_hand(_gun, LEFT_HAND, Vector3(12, 0, 0), sleeve, Vector3(-0.2, -0.22, 0.28))

	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.03, -0.42)
	_gun.add_child(_muzzle)
	_flash = MeshInstance3D.new()
	_flash.mesh = LowPoly.ball(0.11, 6, 3)
	_flash.material_override = LowPoly.glow(Color("fff3a3"))
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_muzzle.add_child(_flash)
	_build_overlay()


## Bron jest rysowana przez osobna kamere na wierzchu obrazu, wiec nie wchodzi w sciany.
## Bryly swiata jej nie zaslaniaja, a inni gracze nadal moga schowac sie za osloną.
func _build_overlay() -> void:
	_put_on_overlay_layer(_gun)
	_main_camera = get_parent() as Camera3D
	_main_camera.set_cull_mask_value(OVERLAY_LAYER, false)

	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)
	_overlay_viewport = SubViewport.new()
	var viewport := _overlay_viewport
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.positional_shadow_atlas_size = 0
	canvas.add_child(viewport)
	# Interfejs gry jest skalowany z 1280x720. Bron renderujemy w pikselach okna,
	# bo inaczej powiekszony obraz bylby rozmazany.
	_match_window_size()
	get_window().size_changed.connect(_match_window_size)
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	picture.material = blend
	canvas.add_child(picture)

	_overlay_camera = Camera3D.new()
	_overlay_camera.near = _main_camera.near
	_overlay_camera.cull_mask = 0
	_overlay_camera.set_cull_mask_value(OVERLAY_LAYER, true)
	_overlay_camera.environment = _overlay_environment()
	viewport.add_child(_overlay_camera)
	_overlay_camera.current = true
	# Bron jest dzieckiem kamery, ktora ja rysuje, wiec porusza sie razem z nia w kazdej klatce.
	remove_child(_gun)
	_overlay_camera.add_child(_gun)
	# Kopiujemy pozycje kamery dopiero po tym, jak netfox ustawi pozycje gracza na te klatke.
	process_priority = 100


func _overlay_environment() -> Environment:
	var world_environment := _main_camera.get_world_3d().environment
	var environment := world_environment.duplicate() as Environment if world_environment != null else Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.8
	environment.ssao_enabled = false
	environment.glow_enabled = false
	return environment


func _match_window_size() -> void:
	_overlay_viewport.size = get_window().size


func overlay_size() -> Vector2i:
	return _overlay_viewport.size


func overlay_camera() -> Camera3D:
	return _overlay_camera


func _put_on_overlay_layer(root: Node) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = 1 << (OVERLAY_LAYER - 1)
	for child in root.get_children():
		_put_on_overlay_layer(child)


func _process(_delta: float) -> void:
	if _overlay_camera != null:
		_overlay_camera.global_transform = _main_camera.global_transform
		_overlay_camera.fov = _main_camera.fov


## Wklada przedmiot do rak z krotka animacja wyciagania albo chowa rece przy pustym slocie.
func set_item(stack: Dictionary) -> void:
	if _gun == null:
		return
	_has_item = not ItemStack.is_empty(stack)
	_gun.visible = _has_item
	_reload_time = -1.0
	if not _has_item:
		return
	var path := ItemStack.definition_of(stack).model_path(ItemStack.tier_of(stack))
	if path != _model_path:
		_model_path = path
		_load_model(path)
	# Bron wjezdza od dolu ekranu.
	_hide = 0.8


func has_item() -> bool:
	return _has_item


func set_reload_seconds(seconds: float) -> void:
	_reload_seconds = seconds


func _load_model(path: String) -> void:
	if _model != null:
		_model.get_parent().remove_child(_model)
		_model.queue_free()
	_model = (load(path) as PackedScene).instantiate() as Node3D
	_gun.add_child(_model)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_magazine = _model.find_child("magazine", true, false) as Node3D
	if _magazine != null:
		_magazine_home = _magazine.position
	_put_on_overlay_layer(_model)


func kick() -> void:
	_recoil = 1.0
	_flash_time = 0.05
	if _flash != null:
		_flash.visible = true
		_flash.rotation.z = randf() * TAU
		_flash.scale = Vector3.ONE * randf_range(0.9, 1.5)


func add_look(delta_look: Vector2) -> void:
	_sway += delta_look


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position


func update_pose(delta: float, speed_ratio: float, on_floor: bool, vertical_speed: float, sprinting: bool, reloading: bool, dead: bool) -> void:
	if _gun == null:
		return
	_time += delta * lerpf(6.0, 13.0, clampf(speed_ratio, 0.0, 1.0))
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)
	_hide = move_toward(_hide, 1.0 if dead else 0.0, delta * 3.5)
	_sprint = move_toward(_sprint, 1.0 if sprinting else 0.0, delta * 7.0)
	_sway = _sway.lerp(Vector2.ZERO, minf(delta * 10.0, 1.0))
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false

	if not on_floor:
		_fall_speed = minf(_fall_speed, vertical_speed)
	elif not _was_on_floor:
		_landing = clampf(-_fall_speed * 0.09, 0.25, 1.0)
		_fall_speed = 0.0
	_was_on_floor = on_floor
	_landing = move_toward(_landing, 0.0, delta * 3.5)

	var reload_tilt := _update_reload(delta, reloading)

	_bob_amount = move_toward(_bob_amount, minf(speed_ratio, 1.5) if on_floor else 0.0, delta * 5.0)
	_lift = lerpf(_lift, clampf(vertical_speed * 0.006, -0.05, 0.05), minf(delta * 10.0, 1.0))
	var recoil_curve := _recoil * _recoil
	# Pelna fala cosinusa zamiast wartosci bezwzglednej: bez ostrego odbicia przy kazdym kroku.
	var position_offset := Vector3(sin(_time) * 0.012 * _bob_amount, -(1.0 - cos(_time * 2.0)) * 0.007 * _bob_amount, recoil_curve * 0.07)
	_landing_shown = lerpf(_landing_shown, _landing, minf(delta * 22.0, 1.0))
	position_offset.y += _lift - _landing_shown * 0.08
	position_offset += Vector3(-0.1, -0.13, 0.06) * _sprint
	position_offset += Vector3.DOWN * _hide * 0.6
	position_offset += Vector3(_sway.x * -0.01, _sway.y * 0.01, 0.0)
	position_offset += Vector3(-0.05, 0.02, 0.03) * reload_tilt
	_gun.position = BASE_POSITION + position_offset
	_gun.rotation = Vector3(
		recoil_curve * 0.16 - _sprint * 0.35 + reload_tilt * 0.5,
		_sprint * 0.9 + reload_tilt * 0.45,
		_sway.x * 0.012 + _sprint * 0.25 + reload_tilt * 0.35)


## Przeladowanie: bron sie unosi, magazynek wypada, lewa reka wklada nowy.
func _update_reload(delta: float, reloading: bool) -> float:
	if reloading and _reload_time < 0.0:
		_reload_time = 0.0
	elif not reloading:
		_reload_time = -1.0
	var left_offset := Vector3.ZERO
	var magazine_offset := Vector3.ZERO
	var tilt := 0.0
	if _reload_time >= 0.0:
		_reload_time += delta
		var t := clampf(_reload_time / _reload_seconds, 0.0, 1.0)
		tilt = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.85, 1.0, t))
		var dropped := smoothstep(0.14, 0.34, t) * (1.0 - smoothstep(0.42, 0.44, t))
		var hand_away := smoothstep(0.12, 0.38, t) * (1.0 - smoothstep(0.58, 0.82, t))
		var inserted := 1.0 - smoothstep(0.5, 0.8, t)
		magazine_offset = Vector3(0.0, -0.75 * dropped, 0.0)
		if t >= 0.43:
			magazine_offset = Vector3(-0.02, -0.5 * inserted, 0.03 * inserted)
		left_offset = Vector3(-0.02, -0.48, 0.22) * hand_away
	if _magazine != null:
		_magazine.position = _magazine_home + magazine_offset
	_left.position = LEFT_HAND + left_offset
	return tilt


func _add_hand(parent: Node3D, at: Vector3, rot: Vector3, sleeve: Color, arm_offset: Vector3) -> Node3D:
	var hand := Node3D.new()
	hand.position = at
	hand.rotation_degrees = rot
	parent.add_child(hand)
	var glove := LowPoly.part(hand, LowPoly.box(Vector3(0.17, 0.17, 0.2), 0.05), GLOVE)
	glove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var thumb := LowPoly.part(hand, LowPoly.box(Vector3(0.06, 0.06, 0.13), 0.02), GLOVE, Vector3(0.1, 0.03, -0.04), Vector3(0, 12, 0))
	thumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cuff := LowPoly.part(hand, LowPoly.box(Vector3(0.19, 0.19, 0.08), 0.03), GLOVE.darkened(0.06), Vector3(0, -0.04, 0.12), Vector3(20, 0, 0))
	cuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arm := LowPoly.part(hand, LowPoly.box(Vector3(0.15, 0.15, 0.62), 0.04), sleeve, Vector3(0, -0.06, 0.15) + arm_offset, Vector3(24, -arm_offset.x * 60.0, 0))
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return hand
