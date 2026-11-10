class_name MeleeDefinition
extends ItemDefinition
## Bron do walki wrecz, bez naboi i przeladowania. Nie ma klas, a sile ciosu ustawia sie tutaj.

@export var damage := 50
## Gra dziala w 30 tickach na sekunde, wiec odstep liczymy w tickach.
@export_range(1, 120) var swing_interval_ticks := 30
## Zasieg od oczu gracza, w metrach.
@export var reach := 2.6
## Jak daleko od srodka celownika cios wciaz trafia, w stopniach.
@export_range(1.0, 60.0) var cone_degrees := 25.0
@export var draw_time := 0.2
## Lzejsza bron pozwala szybciej biegac.
@export_range(1.0, 1.5) var speed_scale := 1.12
@export var item_visual: ItemVisual

static var _behavior: ItemBehavior


func behavior() -> ItemBehavior:
	if _behavior == null:
		_behavior = MeleeBehavior.new()
	return _behavior


func visual(_tier: int) -> ItemVisual:
	return item_visual


func has_tiers() -> bool:
	return false


func draw_seconds(_tier: int) -> float:
	return draw_time


func move_speed_scale() -> float:
	return speed_scale
