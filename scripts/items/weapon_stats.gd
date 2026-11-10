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
## W tickach sieci, ktorych jest 60 na sekunde.
@export_range(1, 120) var fire_interval_ticks := 12
@export var magazine := 12
@export var reload_seconds := 1.6
@export var draw_seconds := 0.25

@export_group("Rozrzut")
## Promien rozrzutu w stopniach, gdy gracz stoi i nie strzelal przed chwila. To najmniejszy rozrzut.
@export_range(0.0, 15.0) var spread_degrees := 0.0
## Tyle dochodzi przy pelnej predkosci biegu.
@export_range(0.0, 15.0) var move_spread_degrees := 0.0
## Tyle dochodzi z kazdym strzalem w serii, ale nie wiecej niz max_bloom_degrees.
@export_range(0.0, 5.0) var shot_spread_degrees := 0.0
@export_range(0.0, 15.0) var max_bloom_degrees := 0.0
## Jak szybko rozrzut z serii opada po przerwaniu ognia, w stopniach na sekunde.
@export_range(0.0, 30.0) var bloom_recovery := 5.0
## O tyle zmniejsza sie caly rozrzut przy celowaniu. Zero to idealna celnosc w lunecie.
@export_range(0.0, 1.0) var aim_spread_scale := 1.0
## Rozrzut przy celowaniu w pelnym biegu, doliczany juz po skali celowania. Dla snajperki.
@export_range(0.0, 15.0) var scoped_move_spread_degrees := 0.0

@export_group("Celowanie")
## O tyle zweza sie pole widzenia. Mniej znaczy mocniejsze przyblizenie.
@export_range(0.3, 1.0) var aim_fov_scale := 0.75
## Celowanie przez lunete: nakladka na caly ekran, ukryta bron i wyrzucenie z lunety po strzale.
@export var scope := false
## O tyle zwalnia gracz, ktory celuje.
@export_range(0.2, 1.0) var aim_move_scale := 0.65

@export_group("Odczucie strzalu")
## Sila odrzutu broni w rekach, gdzie 1 to zwykly blaster.
@export var recoil := 1.0
## Szarpniecie kamery w radianach. Nie zmienia kierunku strzalu.
@export var camera_kick := 0.006
@export var tracer_width := 0.05

@export_group("Odrzut wizualny")
## Ksztalt odrzutu w rekach przy sile "recoil" rownej 1. Liczy sie tylko na ekranie: kierunek pocisku
## i rozrzut zostaja takie same, bo liczy je rollback. Cofniecie w metrach, obroty w radianach.
@export var kick_back := 0.07
## Podbicie lufy do gory.
@export var kick_rise := 0.16
## Obrot w bok, za kazdym razem w losowa strone.
@export var kick_side := 0.0
## Szybkosc powrotu na sprezynie: im wieksza, tym krocej trwa odrzut.
@export var kick_return := 16.0
## Sprezystosc: 0 wraca gladko, a wyzej bron lekko przestrzeliwuje i wraca.
@export_range(0.0, 1.0) var kick_bounce := 0.2
## Drganie przy kazdym strzale, np. w serii blastera.
@export var kick_jitter := 0.0
## Ruch czesci broni po strzale: zamek pistoletu, rygiel snajperki albo pompka strzelby.
@export_enum("Brak", "Zamek", "Rygiel", "Pompka") var cycle_action := 0
## Po ilu sekundach od strzalu rusza ta czesc i ile trwa jej ruch.
@export var cycle_delay := 0.0
@export var cycle_seconds := 0.1
## Jak daleko jedzie czesc, w metrach modelu.
@export var cycle_travel := 0.05
@export var shot_start_hz := 880.0
@export var shot_end_hz := 130.0
@export var shot_seconds := 0.2
@export_range(0.0, 1.0) var shot_noise := 0.35


## Rozrzut w stopniach. "move_ratio" to szybkosc ruchu, gdzie 1 oznacza pelny bieg.
func spread_at(move_ratio: float, bloom: float, aiming: bool) -> float:
	var spread := spread_degrees + move_spread_degrees * move_ratio + bloom
	if aiming:
		return spread * aim_spread_scale + scoped_move_spread_degrees * move_ratio
	return spread
