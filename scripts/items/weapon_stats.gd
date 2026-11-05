class_name WeaponStats
extends Resource
## Parametry broni w jednej klasie. Balans zmienia sie tu, bez ruszania kodu.

@export var damage := 20
@export var headshot_damage := 40
## Gra dziala w 30 tickach na sekunde, wiec odstep liczymy w tickach.
@export_range(1, 60) var fire_interval_ticks := 6
@export var magazine := 12
@export var reload_seconds := 1.6
@export var draw_seconds := 0.25
@export_file("*.glb") var model_path := ""
@export_file("*.png") var icon_path := ""
