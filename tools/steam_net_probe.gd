extends Node
## Czesc tools/steam_net_test.sh: sprawdza u klienta, co serwer rozeslal o graczach.

const OWN_ID := 76561197960287930
const WAIT_SECONDS := 9.0

var _failures := 0


func _ready() -> void:
	await get_tree().create_timer(WAIT_SECONDS).timeout
	var by_name := {}
	for id: int in GameState.players:
		by_name[GameState.players[id].name] = GameState.players[id]
	_check("gracz ze Steamem ma swoje ID", by_name.get("Alfa", {}).get("steam_id", -1) == OWN_ID)
	_check("gracz bez Steama nie ma ID", by_name.get("Beta", {}).get("steam_id", -1) == 0)
	_check("zmyslone ID zostalo odrzucone", by_name.get("Zly", {}).get("steam_id", -1) == 0)
	print("[test] WYNIK: %s" % ("OK" if _failures == 0 else "%d BLEDOW" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("[test] %s: %s" % [what, "OK" if ok else "BLAD"])
	if not ok:
		_failures += 1
