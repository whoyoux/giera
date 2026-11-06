class_name WeaponBehavior
extends ItemBehavior
## Strzelanie i przeladowanie. Lokalny strzal widac od razu, a o trafieniu
## i obrazeniach decyduje wylacznie serwer.


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
	equipment.register_shot(stats)
	if equipment.claim_server_action(tick):
		_resolve_shot(equipment, stack, stats, tick)


func on_timed_action_finished(equipment: Equipment, stack: Dictionary, _tick: int) -> void:
	equipment.set_active_charges(ItemStack.weapon_stats_of(stack).magazine)


func was_action_completed(equipment: Equipment, stack: Dictionary, slot: int, _action_end: int) -> bool:
	return equipment.charges(slot) >= ItemStack.weapon_stats_of(stack).magazine


func action_sound() -> AudioStreamWAV:
	return Sfx.reload_sound()


func timed_action_seconds(stack: Dictionary) -> float:
	return ItemStack.weapon_stats_of(stack).reload_seconds


func show_fired(player: Player, stack: Dictionary) -> void:
	var stats := ItemStack.weapon_stats_of(stack)
	player.play_shot_sound(Sfx.shot(stats))
	var hits: Array[Dictionary] = []
	for direction in Hitscan.pellet_directions(player.look_direction(), stats.pellets, player.equipment.shot_spread, player.equipment.last_fire):
		hits.append(Hitscan.trace(player.get_world_3d(), player.eye_position(), direction, player.peer_id, player.get_tree()))
	player.show_shots(hits, stats, ItemStack.tier_of(stack))


## Klient widzi innych graczy z opoznieniem, wiec serwer cofa ich do chwili, ktora
## strzelec mial na ekranie. Dzieki temu liczy sie to, w co gracz naprawde celowal.
## Sruciny jednego strzalu daja jedno trafienie, zeby znaczniki i dzwieki sie nie mnozyly.
func _resolve_shot(equipment: Equipment, stack: Dictionary, stats: WeaponStats, tick: int) -> void:
	var player := equipment.player
	var view_tick := equipment.rewind_tick(tick)
	var damage_by_victim := {}
	for direction in Hitscan.pellet_directions(Hitscan.direction(player.yaw, player.pitch), stats.pellets, equipment.shot_spread, tick):
		var hit := Hitscan.trace(player.get_world_3d(), player.eye_position(), direction, player.peer_id, player.get_tree(), view_tick)
		var victim := hit.player as Player
		if victim != null:
			var damage: int = stats.headshot_damage if hit.headshot else stats.damage
			damage_by_victim[victim.peer_id] = damage_by_victim.get(victim.peer_id, 0) + damage
	for victim_id: int in damage_by_victim:
		GameState.server_damage(victim_id, damage_by_victim[victim_id], player.peer_id, Vector3.INF, stack)
