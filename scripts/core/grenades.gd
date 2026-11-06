extends Node
## Rzucone granaty. Serwer decyduje o wybuchu i obrazeniach. Klienci licza lot sami,
## bo odbija sie tylko od nieruchomej mapy, a miejsce wybuchu dostaja od serwera.

signal exploded(at: Vector3, owner_id: int)

const CHEST_HEIGHT := 0.9
const SIGHT_ORIGIN_HEIGHT := 0.35
const THROW_START_DISTANCE := 0.6
## Czesc predkosci gracza przechodzi na granat, zeby rzut w biegu wygladal naturalnie.
const INHERITED_SPEED := 0.4
const DROP_HEIGHT := 1.0
const DROP_SPEED := 1.5

var _next_id := 1
var _flying := {}


func _ready() -> void:
	Net.session_started.connect(clear)
	Net.session_ended.connect(func(_reason: String) -> void: clear())
	if DisplayServer.get_name() != "headless":
		# Dzwieki powstaja teraz, zeby pierwszy wybuch w grze nie przycial obrazu.
		Sfx.explosion()
		Sfx.grenade_throw()
		Sfx.grenade_pin()
		Sfx.grenade_bounce()
		Sfx.grenade_beep()


func clear() -> void:
	for id: int in _flying:
		(_flying[id] as GrenadeProjectile).queue_free()
	_flying.clear()


func flying_count() -> int:
	return _flying.size()


# --- Serwer -----------------------------------------------------------------

## Zabiera granat z reki i wypuszcza go. "fuse" to czas, ktory zostal na zapalniku,
## a "drop" oznacza upuszczenie pod nogi, np. przy zmianie przedmiotu.
func server_throw(player: Player, stack: Dictionary, fuse: float, drop := false) -> void:
	var definition := ItemStack.definition_of(stack) as GrenadeDefinition
	_take_from_hand(player, stack)
	if drop:
		var look_flat := Hitscan.direction(player.yaw, 0.0)
		_thrown.rpc(_next_id, String(definition.id), player.position + Vector3.UP * DROP_HEIGHT, look_flat * DROP_SPEED, fuse, player.peer_id)
		_next_id += 1
		return
	var look := Hitscan.direction(player.yaw, player.pitch)
	var eye := player.eye_position()
	var from := eye + look * THROW_START_DISTANCE
	var wall := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, from, Hitscan.WORLD_MASK))
	if not wall.is_empty():
		from = eye
	var speed := look * definition.throw_speed + Vector3.UP * definition.throw_lift + player.velocity * INHERITED_SPEED
	_thrown.rpc(_next_id, String(definition.id), from, speed, fuse, player.peer_id)
	_next_id += 1


## Kto trzymal za dlugo, wybucha razem z granatem.
func server_cook_off(player: Player, stack: Dictionary) -> void:
	var definition := ItemStack.definition_of(stack) as GrenadeDefinition
	_take_from_hand(player, stack)
	var at := player.position + Vector3.UP * CHEST_HEIGHT
	print("[serwer] granat wybuchl w rece: %s" % player.info.name)
	_apply_damage(definition, at, player.peer_id)
	_exploded.rpc(0, at, player.peer_id)


func _take_from_hand(player: Player, stack: Dictionary) -> void:
	var uid := ItemStack.uid_of(stack)
	var slots: Array = player.info.slots
	for slot in slots.size():
		if ItemStack.uid_of(slots[slot]) == uid:
			GameState.server_take_stack(player.peer_id, slot, uid)
			return


## Wolane przez pocisk na serwerze, gdy skonczy sie zapalnik.
func server_explode(id: int) -> void:
	var grenade := _flying.get(id) as GrenadeProjectile
	if grenade == null:
		return
	var at := grenade.global_position
	print("[serwer] wybuch granatu %d" % id)
	_apply_damage(grenade.definition, at, grenade.owner_id)
	_exploded.rpc(id, at, grenade.owner_id)


func _apply_damage(definition: GrenadeDefinition, at: Vector3, owner_id: int) -> void:
	var space := get_tree().current_scene.get_viewport().get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if not player.is_alive():
			continue
		var chest := player.position + Vector3.UP * CHEST_HEIGHT
		var amount := definition.damage_at(at.distance_to(chest))
		if amount > 0 and _can_reach(space, at, player):
			print("[serwer] granat zadal %s obrazenia: %d" % [player.info.name, amount])
			GameState.server_damage(player.peer_id, amount, owner_id, at, { "item": definition.id })


## Mur albo pien chroni przed wybuchem, chyba ze zza oslony wystaje tulow lub glowa.
func _can_reach(space: PhysicsDirectSpaceState3D, at: Vector3, player: Player) -> bool:
	var from := at + Vector3.UP * SIGHT_ORIGIN_HEIGHT
	for height: float in [CHEST_HEIGHT, Hitscan.HEAD_CENTER]:
		var query := PhysicsRayQueryParameters3D.create(from, player.position + Vector3.UP * height, Hitscan.WORLD_MASK)
		if space.intersect_ray(query).is_empty():
			return true
	return false


# --- RPC --------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _thrown(id: int, item: String, from: Vector3, speed: Vector3, fuse: float, owner_id: int) -> void:
	var grenade := GrenadeProjectile.new()
	grenade.grenade_id = id
	grenade.definition = ItemRegistry.get_definition(StringName(item)) as GrenadeDefinition
	grenade.velocity = speed
	grenade.fuse = fuse
	grenade.owner_id = owner_id
	grenade.position = from
	_flying[id] = grenade
	get_tree().current_scene.add_child(grenade)


@rpc("authority", "call_local", "reliable")
func _exploded(id: int, at: Vector3, owner_id: int) -> void:
	var grenade := _flying.get(id) as GrenadeProjectile
	if grenade != null:
		_flying.erase(id)
		grenade.queue_free()
	exploded.emit(at, owner_id)
	if Net.is_headless:
		return
	if ExplosionPool.instance != null:
		ExplosionPool.instance.play(at)
	var camera := get_viewport().get_camera_3d()
	for node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Player
		if player.is_local() and camera != null:
			player.shake_camera(GrenadeFx.shake_at(camera.global_position.distance_to(at)))
