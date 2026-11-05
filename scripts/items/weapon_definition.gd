class_name WeaponDefinition
extends ItemDefinition
## Bron: jeden rodzaj z osobnymi parametrami dla kazdej klasy.

@export var common: WeaponStats
@export var epic: WeaponStats
@export var legendary: WeaponStats

static var _behavior: ItemBehavior


func stats(tier: int) -> WeaponStats:
	match tier:
		Rarity.Tier.EPIC:
			return epic
		Rarity.Tier.LEGENDARY:
			return legendary
	return common


func behavior() -> ItemBehavior:
	if _behavior == null:
		_behavior = WeaponBehavior.new()
	return _behavior


func visual(tier: int) -> ItemVisual:
	return stats(tier).visual


func full_charges(tier: int) -> int:
	return stats(tier).magazine
