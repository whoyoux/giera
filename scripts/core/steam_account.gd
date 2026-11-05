extends Node
## Konto Steam zalogowane na tym komputerze: nazwa, SteamID i awatary graczy.
## Bez wtyczki albo bez Steama "active" jest falszywe, a gra dziala z wpisanym nickiem.
##
## Identyfikator Steam wolno uzywac tylko przez _steam: serwer i testy nie maja wtyczki,
## wiec bezposrednie Steam.funkcja() nie skompilowaloby sie.
##
## Parametry po "--" w linii polecen:
##   --no-steam                bez konta Steam
##   --fake-steam=Nazwa:ID     udawane konto do testow i zrzutow, bez Steama
## Tak samo bez konta dzialaja: tryb bez okna, --server, --bot i --name.

signal avatar_ready(steam_id: int)

## Spacewar, testowa aplikacja Valve. Podmienic po zalozeniu wlasnej aplikacji na Steamie.
const APP_ID := 480
const AVATAR_LARGE := 3
const FAKE_AVATAR_SIZE := 64

var active := false
var steam_id := 0
var persona_name := ""

var _steam: Object
var _fake := false
var _avatars := {}
var _requested := {}


## Zwykle konto gracza. Serwer sprawdza nim dane od klienta, ale nie potwierdza wlasciciela.
static func is_valid_id(id: int) -> bool:
	return (id >> 56) == 1 and ((id >> 52) & 0xF) == 1 and (id & 0xFFFFFFFF) != 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--fake-steam="):
			_use_fake(arg.trim_prefix("--fake-steam="))
			return
	if DisplayServer.get_name() == "headless" or _skips_steam(args) or not Engine.has_singleton("Steam"):
		return
	_connect_to_steam()


func _process(_delta: float) -> void:
	_steam.call("run_callbacks")


## Zwraca awatar, jesli jest juz w pamieci. Inaczej prosi o niego i wysle avatar_ready.
## Tabela wynikow przebudowuje sie co sekunde, wiec kazdy awatar pobierany jest raz.
func avatar(id: int) -> Texture2D:
	if _avatars.has(id):
		return _avatars[id]
	if not active or not is_valid_id(id) or _requested.has(id):
		return null
	_requested[id] = true
	if _fake:
		_avatars[id] = _fake_avatar(id)
		return _avatars[id]
	# Prawda oznacza, ze Steam dopiero pobiera dane i odezwie sie przez persona_state_change.
	if not _steam.call("requestUserInformation", id, false):
		_steam.call("getPlayerAvatar", AVATAR_LARGE, id)
	return null


func _skips_steam(args: PackedStringArray) -> bool:
	for arg in args:
		if arg == "--no-steam" or arg == "--server" or arg.begins_with("--bot=") or arg.begins_with("--name="):
			return true
	return false


func _connect_to_steam() -> void:
	_steam = Engine.get_singleton("Steam")
	var result: Dictionary = _steam.call("steamInitEx", APP_ID, false)
	if int(result.get("status", 1)) != 0:
		print("[steam] gra bez konta Steam: %s" % result.get("verbal", ""))
		return
	set_process(true)
	persona_name = _steam.call("getPersonaName")
	steam_id = _steam.call("getSteamID")
	active = not persona_name.is_empty() and is_valid_id(steam_id)
	_steam.connect("avatar_loaded", _on_avatar_loaded)
	_steam.connect("persona_state_change", _on_persona_changed)


func _on_persona_changed(id: int, _flags: int) -> void:
	if _requested.has(id) and not _avatars.has(id):
		_steam.call("getPlayerAvatar", AVATAR_LARGE, id)


func _on_avatar_loaded(id: int, size: int, buffer: PackedByteArray) -> void:
	if size <= 0 or buffer.size() != size * size * 4:
		return
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)
	image.generate_mipmaps()
	_avatars[id] = ImageTexture.create_from_image(image)
	avatar_ready.emit(id)


func _use_fake(account: String) -> void:
	var parts := account.split(":")
	_fake = true
	persona_name = parts[0]
	steam_id = int(parts[1]) if parts.size() > 1 else 0
	active = true


## Przykladowy obrazek bez prawdziwych danych konta.
func _fake_avatar(id: int) -> Texture2D:
	var image := Image.create_empty(FAKE_AVATAR_SIZE, FAKE_AVATAR_SIZE, false, Image.FORMAT_RGBA8)
	var top := Color.from_hsv(fposmod(id * 0.137, 1.0), 0.55, 0.95)
	var bottom := Color.from_hsv(fposmod(id * 0.137 + 0.12, 1.0), 0.75, 0.7)
	for y in FAKE_AVATAR_SIZE:
		for x in FAKE_AVATAR_SIZE:
			image.set_pixel(x, y, top.lerp(bottom, float(x + y) / (FAKE_AVATAR_SIZE * 2 - 2)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
