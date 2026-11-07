class_name UpdateNotice
extends MarginContainer
## Informacja w menu, gdy gracz siedzi w grze, a tymczasem wyszla nowa wersja.
## Dziala tylko po uruchomieniu przez launcher, ktory podaje swoja sciezke i adres manifestu.
## Niczego nie instaluje, wiec manifest nie musi tu miec podpisu.

const CHECK_TIMEOUT := 5.0
const EDGE_MARGIN := 16
const ABOVE_VERSION := 36


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("margin_right", EDGE_MARGIN)
	add_theme_constant_override("margin_bottom", ABOVE_VERSION)
	var url: String = Net.args.get("update-manifest", "")
	if url.is_empty() or not Net.args.has("launcher-path") or Net.is_headless:
		return
	var request := HTTPRequest.new()
	request.timeout = CHECK_TIMEOUT
	request.use_threads = true
	add_child(request)
	request.request_completed.connect(_on_checked.bind(request))
	if request.request(url) != OK:
		request.queue_free()


func _on_checked(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	var latest := str(data.get("version", ""))
	if latest.is_empty() or latest == str(ProjectSettings.get_setting("application/config/version", "dev")):
		return
	var button := UiStyle.button("Nowa wersja %s: zaktualizuj" % latest, UiStyle.TEAL, Color.WHITE, Sfx.UiCue.NONE)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_restart)
	add_child(button)


func _restart() -> void:
	var launcher: String = Net.args.get("launcher-path", "")
	if OS.create_process(launcher, PackedStringArray(["--", "--wait-for-game"])) != -1:
		get_tree().quit()
