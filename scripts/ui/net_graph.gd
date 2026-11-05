class_name NetGraph
extends PanelContainer
## Wykres polaczenia do debugowania: ping i ruch podaje ENet, a straty mierzy NetProbe.
## U hosta pokazuje najgorszego z polaczonych graczy, a ruch liczy lacznie.

const SAMPLE_SECONDS := 0.25
const SAMPLES := 120
const GRAPH_SIZE := Vector2(300, 80)
const MIN_PING_SCALE := 100.0
## Tyle procent strat wypelnia cala wysokosc wykresu.
const LOSS_SCALE := 20.0

var _pings := PackedFloat32Array()
var _losses := PackedFloat32Array()
var _graph: Control
var _ping_label: Label
var _traffic_label: Label
var _timer := 0.0
## Licznik ruchu w ENet zbiera sie tez, gdy wykres jest ukryty. Pierwszy odczyt tylko go zeruje.
var _traffic_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.sticker(UiStyle.PAPER, 14, 3)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	add_child(rows)
	_ping_label = UiStyle.label("", 15, UiStyle.INK, false)
	rows.add_child(_ping_label)
	_graph = Control.new()
	_graph.custom_minimum_size = GRAPH_SIZE
	_graph.draw.connect(_draw_graph)
	rows.add_child(_graph)
	_traffic_label = UiStyle.label("", 15, UiStyle.INK, false)
	rows.add_child(_traffic_label)
	Settings.changed.connect(_apply_setting)
	_apply_setting()


func add_sample(ping: float, loss: float) -> void:
	_pings.append(ping)
	_losses.append(loss)
	if _pings.size() > SAMPLES:
		_pings.remove_at(0)
		_losses.remove_at(0)
	_graph.queue_redraw()


func sample_count() -> int:
	return _pings.size()


func _apply_setting() -> void:
	var on: bool = Settings.value("show_net_graph")
	if on == visible and on == is_processing():
		return
	visible = on
	set_process(on)
	NetProbe.enabled = on
	_pings.clear()
	_losses.clear()
	_timer = 0.0
	_traffic_ready = false
	_show_offline()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < SAMPLE_SECONDS:
		return
	var elapsed := _timer
	_timer = 0.0
	var connection := _connection()
	if connection == null:
		_traffic_ready = false
		_show_offline()
		return
	_read_peers(connection)
	_read_traffic(connection, elapsed)


func _connection() -> ENetConnection:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return null
	return peer.host


func _read_peers(connection: ENetConnection) -> void:
	var ping := 0.0
	var jitter := 0.0
	var connected := 0
	for peer in connection.get_peers():
		if peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
			continue
		connected += 1
		ping = maxf(ping, peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		jitter = maxf(jitter, peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE))
	if connected == 0:
		_ping_label.text = "Brak graczy w sieci"
		return
	var loss := NetProbe.worst_loss()
	add_sample(ping, loss)
	_ping_label.text = "Ping %d ms  ±%d    Straty %.1f%%" % [roundi(ping), roundi(jitter), loss]


func _read_traffic(connection: ENetConnection, elapsed: float) -> void:
	var sent := connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var received := connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	var sent_packets := connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	var received_packets := connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)
	if not _traffic_ready:
		_traffic_ready = true
		return
	_traffic_label.text = "Wys. %.1f KB/s (%d/s)    Odb. %.1f KB/s (%d/s)" % [
		sent / 1024.0 / elapsed, roundi(sent_packets / elapsed),
		received / 1024.0 / elapsed, roundi(received_packets / elapsed)]


func _show_offline() -> void:
	_ping_label.text = "Brak połączenia"
	_traffic_label.text = ""
	_graph.queue_redraw()


func _draw_graph() -> void:
	var area := Rect2(Vector2.ZERO, _graph.size)
	_graph.draw_rect(area, Color(UiStyle.INK, 0.1))
	var ping_scale := MIN_PING_SCALE
	for ping in _pings:
		ping_scale = maxf(ping_scale, ping)
	var step := area.size.x / float(SAMPLES - 1)
	# Najnowsza probka jest zawsze przy prawej krawedzi.
	var start := area.size.x - step * (_pings.size() - 1)
	var line := PackedVector2Array()
	for i in _pings.size():
		var x := start + step * i
		if _losses[i] > 0.0:
			var height := minf(_losses[i] / LOSS_SCALE, 1.0) * area.size.y
			_graph.draw_rect(Rect2(x - step, area.size.y - height, maxf(step, 2.0), height), UiStyle.CORAL)
		line.append(Vector2(x, area.size.y * (1.0 - _pings[i] / ping_scale)))
	if line.size() >= 2:
		_graph.draw_polyline(line, UiStyle.TEAL.darkened(0.2), 2.0, true)
	var font := _ping_label.get_theme_font("font")
	_graph.draw_string(font, Vector2(4, 13), "%d ms" % roundi(ping_scale), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiStyle.INK, 0.7))
