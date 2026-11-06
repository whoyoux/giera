class_name MeleeBehavior
extends ItemBehavior
## Cios dziala od razu po kliknieciu, a trzymanie przycisku tnie dalej. Lokalnie widac
## go natychmiast, a o trafieniu i obrazeniach decyduje wylacznie serwer.


func rollback_tick(equipment: Equipment, stack: Dictionary, tick: int) -> void:
	var definition := _definition(stack)
	if not equipment.input.use_primary or tick - equipment.last_fire < definition.swing_interval_ticks:
		return
	equipment.last_fire = tick
	if not equipment.claim_server_action(tick):
		return
	var player := equipment.player
	var hit := Hitscan.melee(player.get_world_3d(), player.eye_position(), Hitscan.direction(player.yaw, player.pitch),
			definition.reach, definition.cone_degrees, player.peer_id, player.get_tree(), equipment.rewind_tick(tick))
	var victim := hit.player as Player
	if victim != null:
		GameState.server_damage(victim.peer_id, definition.damage, player.peer_id, Vector3.INF, stack)


func show_fired(player: Player, stack: Dictionary) -> void:
	var definition := _definition(stack)
	var hit := Hitscan.melee(player.get_world_3d(), player.eye_position(), player.look_direction(),
			definition.reach, definition.cone_degrees, player.peer_id, player.get_tree())
	player.play_shot_sound(Sfx.knife_hit() if hit.player != null or hit.hit_world else Sfx.knife_swing())
	player.show_swing(hit)


func idle_hint(_equipment: Equipment, _stack: Dictionary) -> String:
	return "LPM: cios z bliska"


func _definition(stack: Dictionary) -> MeleeDefinition:
	return ItemStack.definition_of(stack) as MeleeDefinition
