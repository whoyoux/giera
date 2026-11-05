class_name CharacterPicker
extends PanelContainer
## Wybor postaci w menu: obracajacy sie model i strzalki. Wybor zostaje na tym komputerze.

signal character_changed(id: String)

const VIEW_SIZE := Vector2(320, 400)
## Obraz powstaje dwa razy wiekszy niz na ekranie i jest zmniejszany, co daje gladkie krawedzie.
const SUPERSAMPLING := 2.0
const SWAY_SPEED := 0.7
const SWAY_ANGLE := 0.55
## Model domyslnie patrzy od kamery, wiec obracamy go przodem z lekkim skosem na bron.
const FRONT_ANGLE := PI + 0.35
const ARROW_SIZE := Vector2(58, 58)
const POP_SCALE := 0.86
const POP_SECONDS := 0.22
const EDGE_SHADER := preload("res://shaders/overlay_edges.gdshader")

var _viewport: SubViewport
var _picture: TextureRect
var _stage: Node3D
var _rig: CharacterRig
var _name_label: Label
var _index := 0
var _time := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_build()
	get_window().size_changed.connect(_match_window)
	_match_window()
	select(Settings.player_value("character", CharacterAssets.ROSTER[0].id), false)


func _process(delta: float) -> void:
	if _stage == null or not is_visible_in_tree():
		return
	_time += delta
	_stage.rotation.y = FRONT_ANGLE + sin(_time * SWAY_SPEED) * SWAY_ANGLE
	if _rig != null:
		_rig.update_pose(delta, Vector2.ZERO, true, 0.0, false, false)


func selected_id() -> String:
	return CharacterAssets.ROSTER[_index].id


## Pokazuje postac. Nieznana nazwa, np. ze starych ustawien, oznacza pierwsza z listy.
func select(id: String, save := true) -> void:
	_index = maxi(CharacterAssets.index_of(id), 0)
	_show_current()
	if save:
		Settings.set_player_value("character", selected_id())
		character_changed.emit(selected_id())


func step(direction: int) -> void:
	select(CharacterAssets.ROSTER[posmod(_index + direction, CharacterAssets.ROSTER.size())].id)
	UiSound.play(Sfx.UiCue.SWITCH)


func _show_current() -> void:
	if _rig != null:
		_stage.remove_child(_rig)
		_rig.queue_free()
	var entry: Dictionary = CharacterAssets.ROSTER[_index]
	_name_label.text = entry.name
	UiStyle.pop_in(_name_label)
	# Ten sam wezel postaci co w grze, wiec poza i chwyt broni sa takie jak u innych graczy.
	_rig = CharacterRig.new()
	_rig.scale = Vector3.ONE * POP_SCALE
	_stage.add_child(_rig)
	_rig.setup(entry.id)
	_rig.set_item(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON))
	var tween := _rig.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rig, "scale", Vector3.ONE, POP_SECONDS)


## Interfejs jest skalowany z 1280x720, a obraz postaci liczymy w pikselach okna, inaczej bylby rozmyty.
func _match_window() -> void:
	var window := get_window()
	var ui_scale := float(window.size.y) / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	_viewport.size = Vector2i(VIEW_SIZE * maxf(ui_scale, 1.0) * SUPERSAMPLING)


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := UiStyle.label("Twoja postać", 17, UiStyle.INK, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	_picture = TextureRect.new()
	_picture.custom_minimum_size = VIEW_SIZE
	_picture.texture = _viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edges := ShaderMaterial.new()
	edges.shader = EDGE_SHADER
	_picture.material = edges
	column.add_child(_picture)
	_build_stage()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	row.add_child(_arrow("<", -1))
	_name_label = UiStyle.label("", 22, UiStyle.BLUE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_label)
	row.add_child(_arrow(">", 1))


func _arrow(text: String, direction: int) -> Button:
	var button := UiStyle.button(text, UiStyle.TEAL, Color.WHITE, Sfx.UiCue.NONE)
	button.name = "Next" if direction > 0 else "Previous"
	button.custom_minimum_size = ARROW_SIZE
	button.pressed.connect(step.bind(direction))
	return button


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	_viewport.add_child(sun)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var camera := Camera3D.new()
	camera.fov = 32.0
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.1, 4.1), Vector3(0.0, 0.92, 0.0))
