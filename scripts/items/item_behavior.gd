class_name ItemBehavior
extends RefCounted
## Co robi przedmiot w reku. Obiekt jest bezstanowy: caly stan trzyma Equipment,
## dzieki czemu nowe przedmioty, np. apteczka, nie wymagaja zmian w kodzie sieciowym.


## Jeden tick symulacji dla aktywnego przedmiotu. Wolane takze przy rollbacku.
func rollback_tick(_equipment: Equipment, _stack: Dictionary, _tick: int) -> void:
	pass


## Wolane, gdy minal czas trwajacego dzialania, np. przeladowania.
func on_timed_action_finished(_equipment: Equipment, _stack: Dictionary, _tick: int) -> void:
	pass


## Czy zakonczone dzialanie sie udalo. Inaczej gra uznaje je za przerwane i ucisza jego dzwiek.
func was_action_completed(_equipment: Equipment, _stack: Dictionary, _slot: int, _action_end: int) -> bool:
	return false


## Czas dzialania w sekundach, potrzebny do animacji i dzwieku.
func timed_action_seconds(_stack: Dictionary) -> float:
	return 0.0


## Dziala co tick, gdy przedmiot jest odbezpieczony. "force_drop" to zmiana przedmiotu w reku.
func primed_tick(_equipment: Equipment, _stack: Dictionary, _tick: int, _force_drop: bool) -> void:
	pass


## Napis nad paskiem przedmiotow w tej chwili. Pusty oznacza brak napisu.
func current_label(equipment: Equipment, stack: Dictionary) -> String:
	return action_label(stack) if equipment.is_busy() else idle_hint(equipment, stack)


## Postep na pasku od 0 do 1 albo liczba ujemna, gdy paska nie ma.
func current_progress(equipment: Equipment, _stack: Dictionary) -> float:
	return equipment.action_progress() if equipment.is_busy() else -1.0


## Dzwiek dzialania. Gra odtwarza go tak szybko, zeby trwal tyle co dzialanie.
func action_sound() -> AudioStreamWAV:
	return null


## Napis na pasku postepu. Pusty oznacza, ze dzialanie nie pokazuje paska.
func action_label(_stack: Dictionary) -> String:
	return ""


## Podpowiedz, gdy przedmiot lezy w reku. Pusta oznacza brak podpowiedzi.
func idle_hint(_equipment: Equipment, _stack: Dictionary) -> String:
	return ""
