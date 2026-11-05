class_name AvatarView
extends PanelContainer
## Awatar gracza jako naklejka. Bez zdjecia pokazuje pierwsza litere nazwy,
## a zdjecie podmienia, gdy tylko przyjdzie ze Steama.

const ROUNDED_SHADER := preload("res://shaders/rounded_avatar.gdshader")
const BORDER_RATIO := 0.07
const FILLS: Array[Color] = [UiStyle.CORAL, UiStyle.TEAL, UiStyle.BLUE, Color("9b7bff")]

var _steam_id := 0
var _picture: TextureRect


func _init(steam_id: int, player_name: String, side: float) -> void:
	_steam_id = steam_id
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var border := maxi(2, roundi(side * BORDER_RATIO))
	var style := UiStyle.sticker(FILLS[absi(player_name.hash()) % FILLS.size()], roundi(side * 0.22), border)
	style.set_content_margin_all(border)
	add_theme_stylebox_override("panel", style)

	var letter := UiStyle.label(player_name.left(1).to_upper(), roundi(side * 0.5), Color.WHITE)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(letter)

	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rounded := ShaderMaterial.new()
	rounded.shader = ROUNDED_SHADER
	_picture.material = rounded
	add_child(_picture)


func _ready() -> void:
	SteamAccount.avatar_ready.connect(_on_avatar_ready)
	_show_picture()


func _on_avatar_ready(id: int) -> void:
	if id == _steam_id:
		_show_picture()


func _show_picture() -> void:
	_picture.texture = SteamAccount.avatar(_steam_id)
	_picture.visible = _picture.texture != null
