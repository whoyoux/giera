class_name ViewModel
extends Node3D
## Bron w pierwszej osobie: kreskowkowe rekawice na blasterze. Wszystkie ruchy sa
## liczone w kodzie: odrzut, kolysanie, przeladowanie, sprint, skok i ladowanie.

const BASE_POSITION := Vector3(0.24, -0.2, -0.56)
const GUN_SCALE := 0.62
## Gdzie ma wypasc wylot lufy przy celowaniu: na srodku, tuz pod celownikiem.
const AIM_MUZZLE_POSITION := Vector3(0.0, -0.075, -0.62)
const AIM_SPEED := 8.0
const RIGHT_HAND := CharacterAssets.HAND_POINT
const GLOVE := Color("fffaf0")
## Warstwa widziana tylko przez kamere nakladki, nigdy przez kamere swiata.
const OVERLAY_LAYER := 20
const EDGE_SHADER := preload("res://shaders/overlay_edges.gdshader")
## Przy odbezpieczonym granacie reka cofa sie do rzutu.
const PRIMED_OFFSET := Vector3(0.06, 0.1, 0.2)
const PRIMED_SPEED := 9.0
const SLASH_SECONDS := 0.34
## Krok calkowania sprezyny odrzutu. Krotki, zeby szybka sprezyna nie wpadla w drgania przy niskim FPS.
const SPRING_STEP := 1.0 / 240.0
## Wyjmowanie broni: lekki obrot przy wjezdzaniu od dolu.
const DRAW_TILT := 0.6

var _main_camera: Camera3D
var _overlay_camera: Camera3D
var _overlay_viewport: SubViewport
var _overlay_canvas: CanvasLayer
var _gun: Node3D
var _left: Node3D
var _magazine: Node3D
var _model: Node3D
var _visual: ItemVisual
var _left_home := Vector3.ZERO
var _flash_material: StandardMaterial3D
var _recoil_strength := 1.0
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
var _aim := 0.0
var _aim_target := false
var _priming := 0.0
var _priming_target := false
var _slash := 1.0
var _pose_callbacks: Array[Callable] = []
## Sprezyna odrzutu: wychylenie i predkosc cofniecia (z) oraz obrotow (x w gore, y i z w bok).
var _kick_offset := Vector4.ZERO
var _kick_speed := Vector4.ZERO
var _kick_return := 16.0
var _kick_damping := 1.0
## Ruch czesci po strzale: zamek, rygiel albo pompka. Czas od strzalu albo -1, gdy nic sie nie rusza.
var _cycle_time := -1.0
var _cycle_action := 0
var _cycle_delay := 0.0
var _cycle_seconds := 0.1
var _cycle_travel := 0.05
var _slide: Node3D
var _slide_home := Vector3.ZERO
var _hammer: Node3D
var _hammer_home := Vector3.ZERO
var _bolt: Node3D
var _bolt_home := Transform3D.IDENTITY
## Jak daleko lewa reka cofnela pompke albo rygiel, od 0 do 1.
var _pump := 0.0


func setup(character_id: String) -> void:
	_gun = Node3D.new()
	_gun.scale = Vector3.ONE * GUN_SCALE
	add_child(_gun)
	var sleeve := CharacterAssets.sleeve_of(character_id)
	_add_hand(_gun, RIGHT_HAND, Vector3(-28, 0, 0), sleeve, Vector3(0.05, -0.2, 0.3))
	_left = _add_hand(_gun, RIGHT_HAND, Vector3(12, 0, 0), sleeve, Vector3(-0.2, -0.22, 0.28))

	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.03, -0.42)
	_gun.add_child(_muzzle)
	_flash = MeshInstance3D.new()
	_flash.mesh = LowPoly.ball(0.11, 6, 3)
	_flash_material = LowPoly.glow(Color("fff3a3"))
	_flash.material_override = _flash_material
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
	_overlay_canvas = canvas
	_overlay_viewport = SubViewport.new()
	var viewport := _overlay_viewport
	viewport.transparent_bg = true
	viewport.msaa_3d = Settings.msaa()
	Settings.changed.connect(_apply_msaa)
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
	var edges := ShaderMaterial.new()
	edges.shader = EDGE_SHADER
	picture.material = edges
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


func _apply_msaa() -> void:
	_overlay_viewport.msaa_3d = Settings.msaa()


func _match_window_size() -> void:
	_overlay_viewport.size = get_window().size


func overlay_size() -> Vector2i:
	return _overlay_viewport.size


## Bron lezy na osobnej warstwie obrazu, wiec samo visible jej nie chowa.
func set_shown(shown: bool) -> void:
	visible = shown
	if _overlay_canvas != null:
		_overlay_canvas.visible = shown


func is_shown() -> bool:
	return visible and (_overlay_canvas == null or _overlay_canvas.visible)


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
		_run_pose_callbacks()


## Podaje polozenie lufy, gdy poza na te klatke jest juz gotowa. Strzal zapada w ticku, a wtedy
## bron stoi jeszcze tam, gdzie w poprzedniej klatce, wiec w ruchu smuga zaczynalaby sie obok niej.
func on_next_pose(callback: Callable) -> void:
	_pose_callbacks.append(callback)


func _run_pose_callbacks() -> void:
	if _pose_callbacks.is_empty():
		return
	var muzzle := muzzle_position()
	for callback in _pose_callbacks:
		callback.call(muzzle)
	_pose_callbacks.clear()


## Wklada przedmiot do rak z krotka animacja wyciagania albo chowa rece przy pustym slocie.
func set_item(stack: Dictionary) -> void:
	if _gun == null:
		return
	_has_item = not ItemStack.is_empty(stack)
	_gun.visible = _has_item
	_reload_time = -1.0
	if not _has_item:
		return
	var visual := ItemStack.visual_of(stack)
	if visual != _visual:
		_visual = visual
		_load_model(visual)
	_flash_material.albedo_color = Rarity.effect_color(ItemStack.tier_of(stack))
	# Bron wjezdza od dolu ekranu.
	_hide = 0.8


func shown_visual() -> ItemVisual:
	return _visual


func has_item() -> bool:
	return _has_item


func set_reload_seconds(seconds: float) -> void:
	_reload_seconds = seconds


func _load_model(visual: ItemVisual) -> void:
	if _model != null:
		_model.get_parent().remove_child(_model)
		_model.queue_free()
	_model = (load(visual.model_path) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * visual.model_scale
	_model.position = RIGHT_HAND - visual.grip * visual.model_scale
	_gun.add_child(_model)
	_muzzle.position = RIGHT_HAND + (visual.muzzle - visual.grip) * visual.model_scale
	_left_home = RIGHT_HAND + (visual.fore_grip - visual.grip) * visual.model_scale
	_left.visible = not visual.one_handed
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_magazine = _model.find_child("magazine", true, false) as Node3D
	if _magazine != null:
		_magazine_home = _magazine.position
	_slide = _model.find_child("slide", true, false) as Node3D
	_slide_home = _slide.position if _slide != null else Vector3.ZERO
	_hammer = _model.find_child("hammer", true, false) as Node3D
	_hammer_home = _hammer.rotation if _hammer != null else Vector3.ZERO
	_bolt = _model.find_child("bolt", true, false) as Node3D
	_bolt_home = _bolt.transform if _bolt != null else Transform3D.IDENTITY
	_cycle_time = -1.0
	_put_on_overlay_layer(_model)


func kick(strength := 1.0) -> void:
	_recoil = 1.0
	_recoil_strength = strength
	_show_flash()


## Odrzut wedlug profilu broni: pchniecie sprezyny cofniecia, podbicia i obrotu w bok oraz ruch
## zamka, rygla albo pompki. "scale" zmniejsza odrzut przy celowaniu.
func kick_with(stats: WeaponStats, scale := 1.0) -> void:
	var strength := stats.recoil * scale
	_kick_return = maxf(stats.kick_return, 1.0)
	_kick_damping = lerpf(1.0, 0.22, stats.kick_bounce)
	# Pchniecie predkoscia tak dobrane, ze szczyt wychylenia wypada mniej wiecej na zadana wartosc.
	var push := _kick_return * 2.2 * strength
	var side := (stats.kick_side + randf_range(-1.0, 1.0) * stats.kick_jitter) * (-1.0 if randf() < 0.5 else 1.0)
	_kick_speed += Vector4(stats.kick_back, stats.kick_rise + randf_range(-0.5, 0.5) * stats.kick_jitter, side, side * 0.6) * push
	_cycle_action = stats.cycle_action
	_cycle_delay = stats.cycle_delay
	_cycle_seconds = maxf(stats.cycle_seconds, 0.01)
	_cycle_travel = stats.cycle_travel
	_cycle_time = 0.0 if _cycle_action != 0 else -1.0
	_show_flash()


func _show_flash() -> void:
	_flash_time = 0.05
	if _flash != null:
		_flash.visible = true
		_flash.rotation.z = randf() * TAU
		_flash.scale = Vector3.ONE * randf_range(0.9, 1.5)


## Krotkie przysiadniecie broni, np. przy podniesieniu czegos.
func nudge(amount := 0.45) -> void:
	_landing = maxf(_landing, amount)


## Reka wyrzuca przedmiot do przodu i opada, zanim serwer zabierze go ze slotu.
func play_throw() -> void:
	if _gun == null:
		return
	_gun.visible = false
	_has_item = false
	_hide = 1.0


## Ciecie nozem: reka zamachuje sie i przechodzi przez srodek ekranu.
func play_slash() -> void:
	_slash = 0.0


func set_priming(priming: bool) -> void:
	_priming_target = priming


func set_aiming(aiming: bool) -> void:
	_aim_target = aiming


## Jak bardzo bron jest uniesiona do oka, od 0 do 1.
func aim_amount() -> float:
	return _aim


func add_look(delta_look: Vector2) -> void:
	_sway += delta_look


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position


func update_pose(delta: float, speed_ratio: float, on_floor: bool, vertical_speed: float, sprinting: bool, reloading: bool, dead: bool) -> void:
	if _gun == null:
		return
	_time += delta * lerpf(6.0, 13.0, clampf(speed_ratio, 0.0, 1.0))
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)
	_update_kick_spring(delta)
	_pump = _update_cycle(delta)
	var pump := _pump
	_hide = move_toward(_hide, 1.0 if dead else 0.0, delta * 3.5)
	_sprint = move_toward(_sprint, 1.0 if sprinting else 0.0, delta * 7.0)
	_aim = move_toward(_aim, 1.0 if _aim_target and not dead else 0.0, delta * AIM_SPEED)
	_priming = move_toward(_priming, 1.0 if _priming_target else 0.0, delta * PRIMED_SPEED)
	var aim_blend := smoothstep(0.0, 1.0, _aim)
	# Przy celowaniu bron prawie sie nie kolysze, zeby nie przeszkadzala w trafianiu.
	var steadiness := 1.0 - aim_blend * 0.85
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
	var recoil_curve := _recoil * _recoil * _recoil_strength
	var drawn := smoothstep(0.0, 1.0, _hide)
	# Pelna fala cosinusa zamiast wartosci bezwzglednej: bez ostrego odbicia przy kazdym kroku.
	var position_offset := Vector3(sin(_time) * 0.012 * _bob_amount * steadiness, -(1.0 - cos(_time * 2.0)) * 0.007 * _bob_amount * steadiness, recoil_curve * 0.07 + _kick_offset.x)
	_landing_shown = lerpf(_landing_shown, _landing, minf(delta * 22.0, 1.0))
	position_offset.y += _lift - _landing_shown * 0.08
	position_offset += Vector3(-0.1, -0.13, 0.06) * _sprint
	position_offset += Vector3.DOWN * drawn * 0.6
	position_offset += Vector3(0.0, -0.02, 0.03) * pump
	position_offset += Vector3(_sway.x * -0.01, _sway.y * 0.01, 0.0) * steadiness
	position_offset += Vector3(-0.05, 0.02, 0.03) * reload_tilt
	_slash = minf(_slash + delta / SLASH_SECONDS, 1.0)
	var swing := _slash_amount()
	position_offset += Vector3(-0.2, 0.05, -0.14) * swing
	var hold := _visual.hold_offset if _visual != null else Vector3.ZERO
	_gun.position = (BASE_POSITION + hold).lerp(_aim_position(), aim_blend) + position_offset + PRIMED_OFFSET * _priming
	_gun.rotation = Vector3(
		recoil_curve * 0.16 + _kick_offset.y - _sprint * 0.35 + reload_tilt * 0.5 - swing * 0.2 - drawn * DRAW_TILT * 0.5 - pump * 0.08,
		_sprint * 0.9 + reload_tilt * 0.45 + swing * 0.4 + _kick_offset.z,
		_sway.x * 0.012 * steadiness + _sprint * 0.25 + reload_tilt * 0.35 + swing * 0.9 + _kick_offset.w + drawn * DRAW_TILT)


## Tlumiona sprezyna: szybkie cofniecie i powrot, a przy wiekszej sprezystosci lekkie przestrzelenie.
func _update_kick_spring(delta: float) -> void:
	var left := minf(delta, 0.1)
	var stiffness := _kick_return * _kick_return
	var damping := 2.0 * _kick_damping * _kick_return
	while left > 0.0:
		var step := minf(left, SPRING_STEP)
		_kick_speed += (-_kick_offset * stiffness - _kick_speed * damping) * step
		_kick_offset += _kick_speed * step
		left -= step


## Ruch czesci po strzale. Zwraca, jak daleko jest pompka (0 do 1), bo przesuwa ja lewa reka.
func _update_cycle(delta: float) -> float:
	if _cycle_time < 0.0:
		return 0.0
	_cycle_time += delta
	var t := (_cycle_time - _cycle_delay) / _cycle_seconds
	if t >= 1.0:
		_cycle_time = -1.0
		_reset_parts()
		return 0.0
	if t < 0.0:
		return 0.0
	match _cycle_action:
		1:
			# Zamek: blyskawicznie do tylu i nieco wolniej z powrotem, a kurek odskakuje.
			var back := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.35, 1.0, t))
			if _slide != null:
				_slide.position = _slide_home + Vector3(0.0, 0.0, _cycle_travel * back)
			if _hammer != null:
				_hammer.rotation = _hammer_home + Vector3(-0.9 * back, 0.0, 0.0)
		2:
			# Rygiel: obrot w gore, do tylu, do przodu i w dol.
			var lift := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.82, 1.0, t))
			var pull := smoothstep(0.2, 0.42, t) * (1.0 - smoothstep(0.55, 0.78, t))
			if _bolt != null:
				_bolt.transform = _bolt_home.translated_local(Vector3(0.0, 0.0, _cycle_travel * pull)).rotated_local(Vector3.FORWARD, -1.2 * lift)
			return lift * 0.6
		3:
			# Pompka: lewa reka szarpie w tyl i wraca.
			return smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.45, 1.0, t))
	return 0.0


func _reset_parts() -> void:
	if _slide != null:
		_slide.position = _slide_home
	if _hammer != null:
		_hammer.rotation = _hammer_home
	if _bolt != null:
		_bolt.transform = _bolt_home


## Szybki wymach na poczatku i wolniejszy powrot.
func _slash_amount() -> float:
	if _slash >= 1.0:
		return 0.0
	return smoothstep(0.0, 0.25, _slash) * (1.0 - smoothstep(0.35, 1.0, _slash))


## Pozycja broni, przy ktorej lufa kazdego modelu lezy w tym samym miejscu ekranu.
func _aim_position() -> Vector3:
	var offset := _visual.aim_offset if _visual != null else Vector3.ZERO
	return AIM_MUZZLE_POSITION + offset - _muzzle.position * GUN_SCALE


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
	_left.position = _left_home + left_offset + Vector3(0.02, -0.02, _cycle_travel * 2.0 + 0.06) * _pump
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
