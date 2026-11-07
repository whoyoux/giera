class_name MedkitBehavior
extends ItemBehavior
## Uzycie: trzymaj przycisk przez caly czas leczenia. Puszczenie przerywa, a o samym
## uleczeniu i zabraniu apteczki decyduje serwer.

## Po skonczeniu leczenia odpowiedz serwera jest w drodze i apteczka wciaz lezy w rece.
const RETRY_BLOCK_SECONDS := 0.6
## Po trafieniu chwile nie da sie zaczac leczenia od nowa, nawet trzymajac przycisk.
const HIT_BLOCK_SECONDS := 1.2


func rollback_tick(equipment: Equipment, stack: Dictionary, tick: int) -> void:
	var definition := ItemStack.definition_of(stack) as MedkitDefinition
	var wants_use := equipment.input.use_primary
	if equipment.is_busy():
		# Trafienie w trakcie leczenia przerywa je, tak jak przerywa regeneracje w Deathmatchu.
		var started := equipment.action_end - NetworkTime.seconds_to_ticks(definition.use_seconds)
		if not wants_use or equipment.player.info.get("hit_tick", -1) >= started:
			equipment.cancel_timed_action()
		return
	if tick - equipment.last_fire < NetworkTime.seconds_to_ticks(RETRY_BLOCK_SECONDS):
		return
	if equipment.player.info.get("hit_tick", -1) > tick - NetworkTime.seconds_to_ticks(HIT_BLOCK_SECONDS):
		return
	if wants_use and equipment.player.info.health < GameState.MAX_HEALTH:
		equipment.start_timed_action(tick, definition.use_seconds)


func on_timed_action_finished(equipment: Equipment, stack: Dictionary, tick: int) -> void:
	var definition := ItemStack.definition_of(stack) as MedkitDefinition
	# Serwer nie leczy, jesli w trakcie przyszlo trafienie, nawet gdy klient tego jeszcze nie wie.
	if equipment.player.info.get("hit_tick", -1) >= tick - NetworkTime.seconds_to_ticks(definition.use_seconds):
		return
	equipment.last_fire = tick
	if equipment.claim_server_action(tick):
		GameState.server_use_medkit(equipment.player.peer_id, ItemStack.uid_of(stack), definition.heal_amount)


func was_action_completed(equipment: Equipment, _stack: Dictionary, _slot: int, action_end: int) -> bool:
	return equipment.last_fire >= action_end


func timed_action_seconds(stack: Dictionary) -> float:
	return (ItemStack.definition_of(stack) as MedkitDefinition).use_seconds


func action_sound() -> AudioStreamWAV:
	return Sfx.medkit_use()


func action_label(_stack: Dictionary) -> String:
	return "Leczenie…"


func idle_hint(equipment: Equipment, stack: Dictionary) -> String:
	if equipment.player.info.health >= GameState.MAX_HEALTH:
		return "Masz pełne zdrowie"
	return "Przytrzymaj %s: +%d zdrowia" % [Keybinds.label_of("fire"), (ItemStack.definition_of(stack) as MedkitDefinition).heal_amount]
