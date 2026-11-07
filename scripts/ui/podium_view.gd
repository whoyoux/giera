class_name PodiumView
extends Node3D
## Podium na koniec rundy Deathmatchu: najlepsza trojka stoi na stopniach i tanczy, a kamera
## patrzy na nia z przodu. Postacie to same modele, wiec nic tu nie idzie przez siec.

const STEP_HEIGHTS: Array[float] = [1.2, 0.8, 0.5]
const STEP_OFFSETS: Array[float] = [0.0, -1.7, 1.7]
const STEP_COLORS: Array[Color] = [Color("ffcb47"), Color("cfd6e3"), Color("e3a46b")]
const CAMERA_DISTANCE := 6.5
const CAMERA_HEIGHT := 2.4
const NAME_LENGTH := 12

var _camera: Camera3D
var _previous_camera: Camera3D
var _shown := false


func _ready() -> void:
	Match.phase_changed.connect(_refresh)
	Net.session_ended.connect(func(_reason: String) -> void: _hide())


func is_shown() -> bool:
	return _shown


func _refresh() -> void:
	var wanted := Net.in_session and not Match.is_elimination() and Match.phase == Match.Phase.RESULTS and not Match.results.is_empty()
	if wanted and not _shown:
		_show()
	elif not wanted and _shown:
		_hide()


func _show() -> void:
	_shown = true
	var spot := Maps.info().podium
	global_position = spot
	rotation.y = Maps.info().podium_yaw
	for index in mini(3, Match.results.size()):
		var entry: Dictionary = Match.results[index]
		var step := Node3D.new()
		step.position = Vector3(STEP_OFFSETS[index], 0.0, 0.0)
		add_child(step)
		LowPoly.part(step, LowPoly.box(Vector3(1.5, STEP_HEIGHTS[index], 1.5), 0.08), STEP_COLORS[index], Vector3(0.0, STEP_HEIGHTS[index] * 0.5, 0.0))
		var rig := CharacterRig.new()
		rig.position = Vector3(0.0, STEP_HEIGHTS[index], 0.0)
		# Model patrzy w -Z, a kamera stoi z przodu podium w +Z.
		rig.rotation.y = PI
		step.add_child(rig)
		rig.setup(CharacterAssets.resolve(entry.get("character", ""), entry.id))
		rig.set_item({})
		rig.set_dance(1 + (index + Match.round_number) % DanceCatalog.DANCES.size())
		var label := Label3D.new()
		label.text = "%d. %s" % [entry.place, _short(entry.name)]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 12
		label.pixel_size = 0.006
		label.position = Vector3(0.0, STEP_HEIGHTS[index] + 2.1, 0.0)
		step.add_child(label)
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	_camera.look_at(global_position + Vector3.UP * 1.6)
	_camera.current = true


func _hide() -> void:
	_shown = false
	for child in get_children():
		child.queue_free()
	_camera = null
	if is_instance_valid(_previous_camera):
		_previous_camera.current = true
	_previous_camera = null


## Stopnie stoja blisko siebie, wiec dlugi nick zaslanialby sasiada.
static func _short(player_name: String) -> String:
	return player_name if player_name.length() <= NAME_LENGTH else player_name.left(NAME_LENGTH - 1) + "…"


## Nagrody rundy z wynikow: najwiecej zabojstw, najcelniejszy i najwiecej trafien w glowe.
static func awards(results: Array) -> Array[String]:
	var lines: Array[String] = []
	if results.is_empty():
		return lines
	var best_kills: Dictionary = results[0]
	var accurate: Dictionary = {}
	var heads: Dictionary = {}
	for entry: Dictionary in results:
		var shots: int = entry.get("shots", 0)
		if shots >= 3 and (accurate.is_empty() or float(entry.hits) / shots > float(accurate.hits) / maxi(accurate.shots, 1)):
			accurate = entry
		if entry.get("headshots", 0) > 0 and (heads.is_empty() or entry.headshots > heads.headshots):
			heads = entry
	lines.append("Najwięcej zabójstw: %s (%d)" % [best_kills.name, best_kills.kills])
	if not accurate.is_empty():
		lines.append("Najcelniejszy: %s (%d%%)" % [accurate.name, roundi(100.0 * accurate.hits / maxi(accurate.shots, 1))])
	if not heads.is_empty():
		lines.append("Najwięcej trafień w głowę: %s (%d)" % [heads.name, heads.headshots])
	return lines
