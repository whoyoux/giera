extends Node
## Test wykresu sieci. Wymaga polaczenia z serwerem, najlepiej przez tools/lag_proxy.py.
## Uzycie: -- --connect=127.0.0.1 --port=PORT --name=Test --settings-path=user://net_graph_test.cfg --tool=res://tools/net_graph_test.gd [--min-loss=PROCENT] [--shots=KATALOG]

var _failures := 0


func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var graph := get_tree().root.find_children("*", "NetGraph", true, false)[0] as NetGraph
	_check("domyslnie wylaczony", not graph.visible and not graph.is_processing())
	Settings.set_value("show_net_graph", true)
	_check("wlacza sie", graph.visible and graph.is_processing())
	await get_tree().create_timer(14.0).timeout
	_check("zbiera probki", graph.sample_count() > 30)
	var text: String = graph._ping_label.text + " | " + graph._traffic_label.text
	print("net_graph: ", text)
	_check("pokazuje ping", text.begins_with("Ping "))
	_check("pokazuje ruch", text.contains("KB/s"))
	print("net_graph: straty ", NetProbe.worst_loss())
	_check("mierzy straty", NetProbe.worst_loss() >= float(Net.args.get("min-loss", "0")))
	await _shot("graph.png")
	var panel := get_node("/root/Main/SettingsPanel") as SettingsPanel
	panel.open()
	await get_tree().create_timer(0.5).timeout
	await _shot("settings.png")
	_check("okno ustawien miesci sie na ekranie", panel._card.get_global_rect().end.y <= panel._card.get_viewport_rect().size.y)
	panel.close()
	Settings.set_value("show_net_graph", false)
	_check("wylacza sie", not graph.visible and not graph.is_processing())
	DirAccess.remove_absolute(Settings.path)
	print("net_graph_test: ", "OK" if _failures == 0 else "BLEDY %d" % _failures)
	get_tree().quit(_failures)


func _shot(file_name: String) -> void:
	if not Net.args.has("shots"):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Net.args.shots.path_join(file_name))


func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "BLAD ") + what)
	if not ok:
		_failures += 1
