class_name Inventory
extends RefCounted
## Czyste operacje na tablicy slotow. Stan trzyma GameState, a zmieniac go moze tylko serwer.

const SLOTS := 4


static func empty_slots() -> Array:
	var slots := []
	slots.resize(SLOTS)
	for i in SLOTS:
		slots[i] = {}
	return slots


static func first_free(slots: Array) -> int:
	for i in slots.size():
		if ItemStack.is_empty(slots[i]):
			return i
	return -1


static func first_occupied(slots: Array) -> int:
	for i in slots.size():
		if not ItemStack.is_empty(slots[i]):
			return i
	return -1


## Nastepny zajety slot w danym kierunku. Scroll pomija puste miejsca i zawija sie.
## Bez zadnego innego przedmiotu zwraca obecny slot.
static func next_occupied(slots: Array, from: int, direction: int) -> int:
	for step in range(1, slots.size() + 1):
		var index := posmod(from + direction * step, slots.size())
		if not ItemStack.is_empty(slots[index]):
			return index
	return from
