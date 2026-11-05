extends Node
## Test konta Steam bez prawdziwego Steama.
## Z kontem:  -- --tool=res://tools/steam_account_test.gd --fake-steam=Kapitan:76561197960265729
## Bez konta: -- --tool=res://tools/steam_account_test.gd --no-steam

const FAKE_ID := 76561197960265729
const PORT := 7820

var _failures := 0


func _ready() -> void:
	_test_helpers()
	var menu := get_node("/root/Main/Menu") as Menu
	if Net.args.has("no-steam"):
		_check("bez konta jest pole nicku", menu._name_field != null and menu._account_name == null)
		_check("bez konta nie ma SteamID", not SteamAccount.active and SteamAccount.steam_id == 0)
		_finish()
		return
	_check("konto jest aktywne", SteamAccount.active and SteamAccount.persona_name == "Kapitan")
	_check("nie ma pola nicku", menu._name_field == null)
	_check("menu pokazuje nazwe", menu._account_name != null and menu._account_name.text == "Kapitan")
	_check("awatar jest w pamieci", SteamAccount.avatar(FAKE_ID) != null)
	_check("awatar jest ten sam", SteamAccount.avatar(FAKE_ID) == SteamAccount.avatar(FAKE_ID))
	_check("zle ID nie ma awatara", SteamAccount.avatar(123) == null)
	var saved_name: String = Settings.player_value("name", "brak")
	menu._apply_settings()
	_check("nazwa idzie do sieci", Net.player_name == "Kapitan")
	_check("nazwa ze Steama nie nadpisuje nicku", Settings.player_value("name", "brak") == saved_name)
	_check("host startuje", Net.start_server(PORT).is_empty())
	await get_tree().create_timer(1.0).timeout
	_check("host ma nazwe ze Steama", GameState.display_name(1) == "Kapitan")
	_check("host ma SteamID", GameState.players.get(1, {}).get("steam_id", 0) == FAKE_ID)
	if not Net.is_headless:
		await _test_game_avatars()
	Net.leave()
	_finish()


## Tylko w oknie, bo bez niego gra nie tworzy awatarow nad graczami.
func _test_game_avatars() -> void:
	GameState.server_add_player(2, "Basia", "mage", FAKE_ID + 2)
	GameState.server_add_player(3, "Mietek", "mage")
	await get_tree().create_timer(0.5).timeout
	var hud := get_node("/root/Main/Hud") as Hud
	_check("tabela ma awatar kazdego gracza", _avatars_in(hud._score_rows).size() == 3)
	_check("wiersz gracza ma zdjecie", _pictures_in(hud._score_rows) == 2)
	var feed_before := _avatars_in(hud._feed).size()
	GameState.kill_announced.emit(1, 3)
	_check("lista zabojstw ma obu graczy", _avatars_in(hud._feed).size() == feed_before + 2)
	_check("nad graczem jest zdjecie", _tag_visible(2))
	_check("nad graczem bez konta nie ma zdjecia", not _tag_visible(3))
	_check("nad soba nie ma zdjecia", _tag_of(1) == null)


func _avatars_in(parent: Node) -> Array[Node]:
	return parent.find_children("*", "AvatarView", true, false)


func _pictures_in(parent: Node) -> int:
	var count := 0
	for view in _avatars_in(parent):
		if (view as AvatarView)._picture.visible:
			count += 1
	return count


func _tag_of(id: int) -> AvatarTag:
	var found := GameState.player_node(id).find_children("*", "AvatarTag", false, false)
	return found[0] if found.size() > 0 else null


func _tag_visible(id: int) -> bool:
	var tag := _tag_of(id)
	return tag != null and tag.visible


func _test_helpers() -> void:
	_check("poprawne ID", SteamAccount.is_valid_id(FAKE_ID))
	_check("zero to nie konto", not SteamAccount.is_valid_id(0))
	_check("male ID to nie konto", not SteamAccount.is_valid_id(123))
	_check("ID ujemne to nie konto", not SteamAccount.is_valid_id(-FAKE_ID))
	_check("ID grupy to nie konto", not SteamAccount.is_valid_id(103582791429521412))
	_check("nazwa bez znakow sterujacych", GameState.clean_name("A\nB\tC\u007f") == "ABC")
	_check("nazwa bez spacji na brzegach", GameState.clean_name("  Ala  ") == "Ala")
	_check("nazwa przycieta", GameState.clean_name("x".repeat(500)).length() == GameState.MAX_NAME_LENGTH)
	_check("polskie znaki zostaja", GameState.clean_name("Żółć") == "Żółć")


func _check(what: String, ok: bool) -> void:
	print("[test] %s: %s" % [what, "OK" if ok else "BLAD"])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("[test] WYNIK: %s" % ("OK" if _failures == 0 else "%d BLEDOW" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)
