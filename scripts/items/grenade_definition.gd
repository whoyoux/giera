class_name GrenadeDefinition
extends ItemDefinition
## Granat: rzucany raz, wybucha po chwili. Nie ma klas, a sile wybuchu ustawia sie tutaj.

## Tak daleko od wybuchu ginie sie od razu.
@export var kill_radius := 2.2
## Dalej wybuch juz nie rani.
@export var blast_radius := 8.0
## Obrazenia tuz za promieniem smierci i na samej krawedzi wybuchu.
@export var near_damage := 85
@export var edge_damage := 8
## Liczy sie od odbezpieczenia, a nie od rzutu.
@export var fuse_seconds := 3.0
@export var throw_speed := 17.0
@export var throw_lift := 3.5
@export var item_visual: ItemVisual

static var _behavior: ItemBehavior


func behavior() -> ItemBehavior:
	if _behavior == null:
		_behavior = GrenadeBehavior.new()
	return _behavior


func visual(_tier: int) -> ItemVisual:
	return item_visual


func has_tiers() -> bool:
	return false


## Obrazenia w danej odleglosci: im blizej, tym wiecej, a tuz obok cale zdrowie.
func damage_at(distance: float) -> int:
	if distance <= kill_radius:
		return GameState.MAX_HEALTH
	if distance >= blast_radius:
		return 0
	var falloff := (distance - kill_radius) / (blast_radius - kill_radius)
	return roundi(lerpf(near_damage, edge_damage, falloff))
