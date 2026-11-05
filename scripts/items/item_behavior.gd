class_name ItemBehavior
extends RefCounted
## Co robi przedmiot w reku. Obiekt jest bezstanowy: caly stan trzyma Equipment,
## dzieki czemu nowe przedmioty, np. apteczka, nie wymagaja zmian w kodzie sieciowym.


## Jeden tick symulacji dla aktywnego przedmiotu. Wolane takze przy rollbacku.
func rollback_tick(_equipment: Equipment, _stack: Dictionary, _tick: int) -> void:
	pass


## Wolane, gdy minal czas trwajacego dzialania, np. przeladowania.
func on_timed_action_finished(_equipment: Equipment, _stack: Dictionary) -> void:
	pass


## Czas dzialania w sekundach, potrzebny do animacji i dzwieku.
func timed_action_seconds(_stack: Dictionary) -> float:
	return 0.0
