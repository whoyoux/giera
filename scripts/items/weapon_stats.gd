class_name WeaponStats
extends Resource
## Parametry broni w jednej klasie. Balans zmienia sie tu, bez ruszania kodu.

@export var visual: ItemVisual

@export_group("Walka")
## Obrazenia jednego pocisku. Strzelba wystrzeliwuje ich kilka naraz.
@export var damage := 20
@export var headshot_damage := 40
## Ile pociskow leci w jednym strzale.
@export_range(1, 16) var pellets := 1
## Promien rozrzutu w stopniach. Przy jednym pocisku nie ma znaczenia.
@export_range(0.0, 15.0) var spread_degrees := 0.0
## Gra dziala w 30 tickach na sekunde, wiec odstep liczymy w tickach.
@export_range(1, 60) var fire_interval_ticks := 6
@export var magazine := 12
@export var reload_seconds := 1.6
@export var draw_seconds := 0.25

@export_group("Celowanie")
## O tyle zweza sie pole widzenia. Mniej znaczy mocniejsze przyblizenie.
@export_range(0.3, 1.0) var aim_fov_scale := 0.75
## O tyle zwalnia gracz, ktory celuje.
@export_range(0.2, 1.0) var aim_move_scale := 0.65
## O tyle zmniejsza sie rozrzut przy celowaniu.
@export_range(0.2, 1.0) var aim_spread_scale := 1.0

@export_group("Odczucie strzalu")
## Sila odrzutu broni w rekach, gdzie 1 to zwykly blaster.
@export var recoil := 1.0
## Szarpniecie kamery w radianach. Nie zmienia kierunku strzalu.
@export var camera_kick := 0.006
@export var tracer_width := 0.05
@export var shot_start_hz := 880.0
@export var shot_end_hz := 130.0
@export var shot_seconds := 0.2
@export_range(0.0, 1.0) var shot_noise := 0.35


## Rozrzut w tej chwili, w stopniach.
func current_spread(aiming: bool) -> float:
	return spread_degrees * (aim_spread_scale if aiming else 1.0)
