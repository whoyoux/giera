class_name GrenadeBehavior
extends ItemBehavior
## Wcisniecie przycisku odbezpiecza granat i rusza zapalnik, a puszczenie go rzuca. Kto trzyma
## za dlugo, wybucha razem z nim. O samym granacie decyduje serwer.

## Odpowiedz serwera jest w drodze, a granat wciaz lezy w rece.
const RETRY_BLOCK_SECONDS := 0.8


func rollback_tick(equipment: Equipment, _stack: Dictionary, tick: int) -> void:
	if equipment.prime_tick >= 0 or not equipment.input.use_primary:
		return
	if tick - equipment.last_throw >= NetworkTime.seconds_to_ticks(RETRY_BLOCK_SECONDS):
		equipment.prime_tick = tick


## Dziala co tick odbezpieczonego granatu, takze w sprincie. "force_drop" to zmiana przedmiotu w reku.
func primed_tick(equipment: Equipment, stack: Dictionary, tick: int, force_drop: bool) -> void:
	var left := _fuse_left(equipment, stack, tick)
	if left <= 0.0:
		_finish(equipment, tick)
		if equipment.claim_server_action(tick):
			Grenades.server_cook_off(equipment.player, stack)
	elif force_drop or not equipment.input.use_primary:
		_finish(equipment, tick)
		if equipment.claim_server_action(tick):
			Grenades.server_throw(equipment.player, stack, left, force_drop)


func current_label(equipment: Equipment, stack: Dictionary) -> String:
	if equipment.prime_tick >= 0:
		return "Puść, aby rzucić!"
	return super.current_label(equipment, stack)


## Pasek pokazuje, ile zostalo do wybuchu.
func current_progress(equipment: Equipment, stack: Dictionary) -> float:
	if equipment.prime_tick < 0:
		return super.current_progress(equipment, stack)
	return clampf(_fuse_left(equipment, stack, NetworkTime.tick) / _definition(stack).fuse_seconds, 0.0, 1.0)


func idle_hint(_equipment: Equipment, _stack: Dictionary) -> String:
	return "Trzymaj %s i puść, aby rzucić" % Keybinds.label_of("fire")


func _finish(equipment: Equipment, tick: int) -> void:
	equipment.prime_tick = -1
	equipment.last_throw = tick


func _fuse_left(equipment: Equipment, stack: Dictionary, tick: int) -> float:
	return _definition(stack).fuse_seconds - (tick - equipment.prime_tick) * NetworkTime.ticktime


func _definition(stack: Dictionary) -> GrenadeDefinition:
	return ItemStack.definition_of(stack) as GrenadeDefinition
