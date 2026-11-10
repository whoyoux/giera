extends Node
## Narzedzie pomiarowe dla tools/net_load_test.sh: co 5 s wypisuje ruch ENet (KB/s i pakiety/s)
## oraz czas petli tickow netfox w ms na sekunde. Z flaga --no-diff serwer wylacza stany roznicowe.

var _timer := 0.0
var _loop_start := 0
var _loop_usec := 0
var _loops := 0
var _worst := 0
var _ready_stats := false


func _ready() -> void:
	if Net.args.has("no-diff") and multiplayer.is_server():
		NetworkRollback.enable_diff_states = false
		print("[traffic] diff states OFF")
	NetworkTime.before_tick_loop.connect(func() -> void: _loop_start = Time.get_ticks_usec())
	NetworkTime.after_tick_loop.connect(func() -> void:
		var took := Time.get_ticks_usec() - _loop_start
		_loop_usec += took
		_loops += 1
		_worst = maxi(_worst, took))


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 5.0:
		return
	var elapsed := _timer
	_timer = 0.0
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or peer.host == null:
		return
	var sent := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var received := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	var sent_packets := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	var received_packets := peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)
	if not _ready_stats:
		_ready_stats = true
		_loop_usec = 0
		_loops = 0
		_worst = 0
		return
	print("[traffic] %s graczy=%d wys=%.1fKB/s (%d pak/s) odb=%.1fKB/s (%d pak/s) tick: %.1f ms/s, srednio %.2f ms, najgorzej %.2f ms, fps=%d" % [
		"serwer" if multiplayer.is_server() else "klient", GameState.players.size(),
		sent / 1024.0 / elapsed, roundi(sent_packets / elapsed), received / 1024.0 / elapsed, roundi(received_packets / elapsed),
		_loop_usec / 1000.0 / elapsed, _loop_usec / 1000.0 / maxi(_loops, 1), _worst / 1000.0, Engine.get_frames_per_second()])
	_loop_usec = 0
	_loops = 0
	_worst = 0
