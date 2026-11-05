class_name CharacterPicker
extends PanelContainer
## Wybor postaci w menu: obracajacy sie model i strzalki. Wybor zostaje na tym komputerze.

signal character_changed(id: String)

const VIEW_SIZE := Vector2i(320, 400)
const SPIN_SPEED := 0.5
const ARROW_SIZE := Vector2(58, 58)
## Model startuje bokiem do kamery, zeby od razu bylo widac jego ksztalt.
const START_ANGLE := 0.5
const POP_SCALE := 0.86
const POP_SECONDS := 0.22

var _viewport: SubViewport
var _stage: Node3D
var _model: Node3D
var _name_label: Label
var _index := 0
var _switch_audio: AudioStreamPlayer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.sticker(UiStyle.PAPER, 26, 7))
	_build()
	select(Settings.player_value("character", CharacterAssets.ROSTER[0].id), false)


func _process(delta: float) -> void:
	if _stage != null and is_visible_in_tree():
		_stage.rotation.y += delta * SPIN_SPEED


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
	_switch_audio.play()


func _show_current() -> void:
	if _model != null:
		_stage.remove_child(_model)
		_model.queue_free()
	var entry: Dictionary = CharacterAssets.ROSTER[_index]
	_name_label.text = entry.name
	_model = CharacterAssets.character_for(entry.id)
	_model.scale = Vector3.ONE * CharacterAssets.MODEL_SCALE * POP_SCALE
	_stage.add_child(_model)
	var holder := CharacterAssets.prepare_hands(_model)
	CharacterAssets.set_gun_model(holder, ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON).visual)
	var player := CharacterAssets.player_of(_model)
	player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	player.play("Idle")
	_stage.rotation.y = START_ANGLE
	var tween := _model.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE * CharacterAssets.MODEL_SCALE, POP_SECONDS)


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := UiStyle.label("Twoja postać", 17, UiStyle.INK, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var view := SubViewportContainer.new()
	view.custom_minimum_size = VIEW_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(view)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	view.add_child(_viewport)
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
	_switch_audio = AudioStreamPlayer.new()
	_switch_audio.stream = Sfx.switch_item()
	add_child(_switch_audio)


func _arrow(text: String, direction: int) -> Button:
	var button := UiStyle.button(text, UiStyle.TEAL)
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
