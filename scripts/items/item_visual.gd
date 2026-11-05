class_name ItemVisual
extends Resource
## Jak przedmiot wyglada i gdzie sie go trzyma. Punkty sa w ukladzie modelu, wiec
## kazdy model moze miec inny ksztalt, a dlonie i tak trafia we wlasciwe miejsce.

@export_file("*.glb", "*.tscn") var model_path := ""
@export_file("*.png") var icon_path := ""
## Gdzie lezy prawa dlon.
@export var grip := Vector3.ZERO
## Gdzie lezy lewa dlon.
@export var fore_grip := Vector3.ZERO
## Wylot lufy.
@export var muzzle := Vector3.ZERO
