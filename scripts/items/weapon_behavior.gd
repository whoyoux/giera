class_name WeaponBehavior
extends ItemBehavior
## Strzelanie i przeladowanie. Lokalny strzal widac od razu, a o trafieniu
## i obrazeniach decyduje wylacznie serwer.

## Granica cofania czasu, zeby gracz z bardzo slabym laczem nie trafial "przez sciany".
const MAX_REWIND_SECONDS := 0.3


func rollback_tick(equipment: Equipment, stack: Dictionary, tick: int) -> void:
	var stats := ItemStack.weapon_stats_of(stack)
	var input := equipment.input
	var charges := equipment.active_charges()
	if not equipment.is_busy() and charges < stats.magazine and (input.reload or (charges == 0 and input.use_primary)):
		equipment.start_timed_action(tick, stats.reload_seconds)
	if not input.use_primary or equipment.is_busy() or charges <= 0:
		return
	if tick - equipment.last_fire < stats.fire_interval_ticks:
		return
	equipment.last_fire = tick
	equipment.set_active_charges(charges - 1)
	if equipment.claim_server_shot(tick):
		_resolve_shot(equipment, stats, tick)


func on_timed_action_finished(equipment: Equipment, stack: Dictionary) -> void:
	equipment.set_active_charges(ItemStack.weapon_stats_of(stack).magazine)


func timed_action_seconds(stack: Dictionary) -> float:
	return ItemStack.weapon_stats_of(stack).reload_seconds


## Klient widzi innych graczy z opoznieniem, wiec serwer cofa ich do chwili, ktora
## strzelec mial na ekranie. Dzieki temu liczy sie to, w co gracz naprawde celowal.
func _resolve_shot(equipment: Equipment, stats: WeaponStats, tick: int) -> void:
	var player := equipment.player
	var view_tick := -1
	if equipment.input.view_tick >= 0:
		view_tick = clampi(equipment.input.view_tick, tick - NetworkTime.seconds_to_ticks(MAX_REWIND_SECONDS), tick)
	var hit := Hitscan.trace(player.get_world_3d(), player.eye_position(),
			Hitscan.direction(player.yaw, player.pitch), player.peer_id, player.get_tree(), view_tick)
	var victim := hit.player as Player
	if victim != null:
		var damage: int = stats.headshot_damage if hit.headshot else stats.damage
		GameState.server_damage(victim.peer_id, damage, player.peer_id)
