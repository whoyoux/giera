class_name MedkitDefinition
extends ItemDefinition
## Apteczka: leczy raz i znika. Nie ma klas, wiec kazda dziala tak samo.

@export_range(1, 100) var heal_amount := 50
@export var use_seconds := 2.5
@export var item_visual: ItemVisual

static var _behavior: ItemBehavior


func behavior() -> ItemBehavior:
	if _behavior == null:
		_behavior = MedkitBehavior.new()
	return _behavior


func visual(_tier: int) -> ItemVisual:
	return item_visual


func has_tiers() -> bool:
	return false
