extends Node
## Zakladanie serwera i dolaczanie do gry.
##
## Parametry po "--" w linii polecen:
##   --server              serwer dedykowany (bez gracza)
##   --connect=ADRES       od razu dolacz do serwera
##   --port=7777           port UDP
##   --name=Nick           nazwa gracza
##   --character=knight    postac gracza, np. skeleton_warrior
##   --bot=runner|shooter|headhunter  sterowanie automatyczne, np. cel do cwiczen
##   --tool=res://sciezka  dodatkowy skrypt testowy
##   --debug-items         serwer daje kazdemu dodatkowe bronie do testow
##   --debug-chests        dodatkowe skrzynki przy punktach odrodzenia (na serwerze i u klientow)

signal session_started
signal session_ended(reason: String)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 32
const CONNECT_TIMEOUT_SECONDS := 8.0
const DEDICATED_MAX_FPS := 60
## Podnies przy kazdej zmianie, po ktorej stary build nie dogada sie z serwerem.
const PROTOCOL_VERSION := 11
const JOIN_ANSWER_SECONDS := 6.0
const OUTDATED_MESSAGE := "Masz inną wersję gry niż serwer. Pobierz najnowszy build."

var args := {}
var is_headless := false
var is_dedicated := false
var in_session := false
var bot_mode := ""
var player_name := "Gracz"
var player_character := ""


func _ready() -> void:
	_parse_args()
	is_headless = DisplayServer.get_name() == "headless"
	bot_mode = args.get("bot", "")
	player_name = args.get("name", player_name)
	player_character = args.get("character", player_character)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	await get_tree().process_frame
	if args.has("tool"):
		add_child((load(args.tool) as GDScript).new())
	if args.has("server"):
		start_server(_port_arg(), true)
	elif args.has("connect"):
		join(args.connect, _port_arg())


## Zwraca opis bledu albo pusty tekst, gdy serwer dziala.
func start_server(port := DEFAULT_PORT, dedicated := false) -> String:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		var reason := "Nie mozna uruchomic serwera na porcie %d (%s)." % [port, error_string(error)]
		push_error(reason)
		if dedicated:
			get_tree().quit(1)
		return reason
	is_dedicated = dedicated
	if dedicated:
		# Bez limitu petla silnika zajmowalaby caly rdzen procesora.
		Engine.max_fps = DEDICATED_MAX_FPS
	multiplayer.multiplayer_peer = peer
	in_session = true
	print("[serwer] nasluch na porcie UDP %d (%s)" % [port, "dedykowany" if dedicated else "z graczem"])
	session_started.emit()
	if not dedicated:
		_add_host_player(peer)
	return ""


## Zwraca opis bledu albo pusty tekst, gdy rozpoczeto laczenie.
func join(address: String, port := DEFAULT_PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return "Nie mozna polaczyc z %s:%d (%s)." % [address, port, error_string(error)]
	multiplayer.multiplayer_peer = peer
	print("[klient] lacze z %s:%d" % [address, port])
	get_tree().create_timer(CONNECT_TIMEOUT_SECONDS).timeout.connect(_on_connect_timeout.bind(peer))
	return ""


func leave(reason := "") -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	# NetworkEvents zatrzymuje zegar tylko po rozlaczeniu przez serwer, a nie przy
	# wyjsciu klienta, a kolejne dolaczenie wymaga zatrzymanego zegara.
	NetworkTime.stop()
	in_session = false
	is_dedicated = false
	GameState.reset()
	session_ended.emit(reason)


func _on_connected() -> void:
	print("[klient] polaczono, id %d" % multiplayer.get_unique_id())
	in_session = true
	session_started.emit()
	var peer := multiplayer.multiplayer_peer
	await NetworkTime.after_sync
	if multiplayer.multiplayer_peer == peer:
		var version := int(args.get("protocol", PROTOCOL_VERSION))
		GameState.request_join.rpc_id(1, player_name, version, player_character)
		# Starszy serwer nie zrozumie zgloszenia i nie odpowie.
		get_tree().create_timer(JOIN_ANSWER_SECONDS).timeout.connect(_on_join_answer_timeout.bind(peer))


## Wezly graczy moga powstac dopiero po starcie zegara netfox. Przy ponownej sesji
## zegar pamieta stary tick i nowa postac nie ruszylaby sie, dopoki go nie dogoni.
func _add_host_player(peer: MultiplayerPeer) -> void:
	await NetworkTime.after_sync
	if multiplayer.multiplayer_peer == peer:
		GameState.server_add_player(1, player_name, player_character)


func _on_join_answer_timeout(peer: MultiplayerPeer) -> void:
	if multiplayer.multiplayer_peer == peer and not GameState.players.has(multiplayer.get_unique_id()):
		leave(OUTDATED_MESSAGE)


func _on_connect_timeout(peer: ENetMultiplayerPeer) -> void:
	if multiplayer.multiplayer_peer == peer and not in_session:
		leave("Serwer nie odpowiada.")


func _on_connection_failed() -> void:
	leave("Nie udalo sie polaczyc z serwerem.")


func _on_server_disconnected() -> void:
	leave("Polaczenie z serwerem zostalo zerwane.")


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var key := arg.trim_prefix("--")
		var separator := key.find("=")
		if separator == -1:
			args[key] = true
		else:
			args[key.substr(0, separator)] = key.substr(separator + 1)


func _port_arg() -> int:
	return int(args.get("port", DEFAULT_PORT))
