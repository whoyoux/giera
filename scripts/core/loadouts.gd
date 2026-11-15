class_name Loadouts
extends RefCounted
## Zestawy broni w trybie Rundy. Gracz wybiera jeden przed runda, a serwer daje go na starcie
## kazdej rundy. Wszystkie bronie maja zwykla klase, zeby o wyniku decydowala celnosc, a nie lup.

const DEFAULT := 0
const LIST: Array[Dictionary] = [
	{
		"name": "Szturm",
		"hint": "Karabinek, nóż i granat",
		"items": [&"blaster", &"knife", &"grenade"],
	},
	{
		"name": "Bliski dystans",
		"hint": "Strzelba, Uzi i nóż",
		"items": [&"shotgun", &"uzi", &"knife"],
	},
	{
		"name": "Snajper",
		"hint": "AWP, Desert Eagle i nóż",
		"items": [&"awp", &"deagle", &"knife"],
	},
	{
		"name": "Zwiad",
		"hint": "Uzi, Desert Eagle i granat",
		"items": [&"uzi", &"deagle", &"grenade"],
	},
]


static func count() -> int:
	return LIST.size()


static func is_valid(index: int) -> bool:
	return index >= 0 and index < LIST.size()


static func name_of(index: int) -> String:
	return LIST[index].name if is_valid(index) else ""


static func hint_of(index: int) -> String:
	return LIST[index].hint if is_valid(index) else ""


## Przedmioty zestawu. Zly numer daje zestaw domyslny.
static func items_of(index: int) -> Array:
	return LIST[index if is_valid(index) else DEFAULT].items
