class_name ItemDefinition
extends Resource
## Opis rodzaju przedmiotu, wspolny dla wszystkich jego egzemplarzy. Egzemplarz to ItemStack.

## Trwaly identyfikator wysylany przez siec. Nie zmieniaj go po wydaniu gry.
@export var id: StringName
@export var display_name := ""
## Nazwa rodzaju zenskiego, wiec klasa ma inna odmiane.
@export var feminine_name := false
@export_range(1, 99) var max_stack := 1
## Rodzaj pokazywany w Zbrojowni, np. "Pistolet".
@export var kind_name := ""
## Krotki opis do Zbrojowni: do czego sluzy i na co uwazac.
@export_multiline var description := ""


## Zachowanie przedmiotu trzymanego w reku. Podklasy zwracaja wlasne ItemBehavior.
func behavior() -> ItemBehavior:
	return null


## Wyglad przedmiotu w danej klasie.
func visual(_tier: int) -> ItemVisual:
	return null


## Czy przedmiot wystepuje w klasach. Bez klas nazwa nie ma przedrostka, a kazdy egzemplarz jest zwykly.
func has_tiers() -> bool:
	return true


## Ile "ladunkow" ma nowy egzemplarz, np. naboje w magazynku.
func full_charges(_tier: int) -> int:
	return 0


## Czas wyciagania, zanim przedmiotu mozna uzyc.
func draw_seconds(_tier: int) -> float:
	return 0.0


## Szybkosc biegu z tym przedmiotem w reku.
func move_speed_scale() -> float:
	return 1.0
