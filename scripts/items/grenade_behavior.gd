class_name GrenadeBehavior
extends ItemBehavior
## Rzut po wcisnieciu przycisku. Klient od razu pokazuje ruch reki, a o samym granacie
## decyduje serwer, ktory zabiera przedmiot i wypuszcza pocisk.

## Odpowiedz serwera jest w drodze, a granat wciaz lezy w rece.
const RETRY_BLOCK_SECONDS := 0.8


func rollback_tick(equipment: Equipment, stack: Dictionary, tick: int) -> void:
	if not equipment.input.use_primary:
		return
	if tick - equipment.last_throw < NetworkTime.seconds_to_ticks(RETRY_BLOCK_SECONDS):
		return
	equipment.last_throw = tick
	if equipment.claim_server_action(tick):
		Grenades.server_throw(equipment.player, stack)


func idle_hint(_equipment: Equipment, _stack: Dictionary) -> String:
	return "LPM: rzuć granat"
