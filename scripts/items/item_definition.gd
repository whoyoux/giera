class_name ItemDefinition
extends Resource
## Opis rodzaju przedmiotu, wspolny dla wszystkich jego egzemplarzy. Egzemplarz to ItemStack.

## Trwaly identyfikator wysylany przez siec. Nie zmieniaj go po wydaniu gry.
@export var id: StringName
@export var display_name := ""
@export_range(1, 99) var max_stack := 1


## Zachowanie przedmiotu trzymanego w reku. Podklasy zwracaja wlasne ItemBehavior.
func behavior() -> ItemBehavior:
	return null


## Wyglad przedmiotu w danej klasie.
func visual(_tier: int) -> ItemVisual:
	return null


## Ile "ladunkow" ma nowy egzemplarz, np. naboje w magazynku.
func full_charges(_tier: int) -> int:
	return 0
