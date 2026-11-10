class_name Equipment
extends Node
## Przedmiot w reku i jego symulacja. Co lezy w slotach wie GameState, a tutaj jest
## stan rollbacku, ktory klient przewiduje od razu. Zachowanie przedmiotu lezy w ItemBehavior.

signal fired
signal thrown
## Zmienil sie stan odbezpieczenia przedmiotu w reku.
signal priming_changed(primed: bool)
signal action_started
signal action_cancelled
## Zmienil sie przedmiot w reku: inny slot albo inny egzemplarz w tym samym slocie.
signal active_item_changed

const ACTION_CORRECTION_TICKS := 8
## Granica cofania czasu, zeby gracz z bardzo slabym laczem nie trafial "przez sciany".
const MAX_REWIND_SECONDS := 0.4
## Rozrzut z serii zaczyna opadac chwile po tym, jak mogl pasc kolejny strzal.
const SPREAD_HOLD_TICKS := 3
## Kucajac strzela sie celniej.
const CROUCH_SPREAD_SCALE := 0.6
## W powietrzu strzela sie gorzej niz w pelnym biegu.
const AIR_MOVE_RATIO := 1.5

# Stan rollbacku. Osobne liczby zamiast tablicy, bo netfox wysyla tylko zmienione wartosci.
var active_slot := 0
var last_fire := -1000
var last_throw := -1000
var prime_tick := -1
var action_end := -1
var draw_end := -1
var slot_uid_0 := 0
var slot_uid_1 := 0
var slot_uid_2 := 0
var slot_uid_3 := 0
var charges_0 := 0
var charges_1 := 0
var charges_2 := 0
var charges_3 := 0
## Rozrzut narosly w serii, w stopniach.
var spread_bloom := 0.0
## Rozrzut ostatniego strzalu. Efekty czytaja go pozniej, gdy ruch i seria sa juz inne.
var shot_spread := 0.0

var _resolved_up_to := -1
var _shown_fire := -1000
var _shown_throw := -1000
var _shown_primed := false
var _shown_slot := -1
var _shown_uid := -1
var _shown_action_end := -1
var _action_stack := {}
var _action_slot := 0

@onready var player := get_parent() as Player
@onready var input := player.get_node("Input") as PlayerInput


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_after_tick_loop)


## Wolane przez gracza, gdy zna juz swoj wpis w GameState.
func initialize() -> void:
	_sync_slots()


func slots() -> Array:
	return player.info.slots


## Przedmiot w aktywnym slocie albo pusty slownik. Sprawdzamy zgodnosc z uid ze stanu,
## bo przy symulacji przeszlosci sloty mogly juz sie zmienic.
func active_stack() -> Dictionary:
	var stack: Dictionary = slots()[active_slot]
	return stack if ItemStack.uid_of(stack) == _slot_uid(active_slot) else {}


func active_stats() -> WeaponStats:
	return ItemStack.weapon_stats_of(active_stack())


func charges(slot: int) -> int:
	match slot:
		0:
			return charges_0
		1:
			return charges_1
		2:
			return charges_2
	return charges_3


## Naboje egzemplarza. Gdy symulacja nie zna go jeszcze, obowiazuje liczba z samego egzemplarza.
func charges_of_stack(slot: int, stack: Dictionary) -> int:
	return charges(slot) if _slot_uid(slot) == ItemStack.uid_of(stack) else stack.get("charges", 0)


func active_charges() -> int:
	return charges(active_slot)


func set_active_charges(value: int) -> void:
	_set_charges(active_slot, value)


## Szybkosc biegu z tym, co jest teraz w reku.
func move_speed_scale() -> float:
	var definition := ItemStack.definition_of(active_stack())
	return definition.move_speed_scale() if definition != null else 1.0


## Rozrzut trzymanej broni w tej chwili, w stopniach. Zero, gdy w reku nie ma broni.
func current_spread() -> float:
	var stats := active_stats()
	if stats == null:
		return 0.0
	return stats.spread_at(_move_ratio(), spread_bloom, player.aiming) * lerpf(1.0, CROUCH_SPREAD_SCALE, player.crouch_amount)


## Zapamietuje rozrzut tego strzalu, a kolejny w serii bedzie mial wiekszy.
func register_shot(stats: WeaponStats) -> void:
	shot_spread = current_spread()
	spread_bloom = minf(spread_bloom + stats.shot_spread_degrees, stats.max_bloom_degrees)


## Do ktorego ticku serwer cofa cele przy rozliczaniu ataku. -1 oznacza stan biezacy.
func rewind_tick(tick: int) -> float:
	if input.view_tick < 0.0:
		return -1.0
	return clampf(input.view_tick, tick - NetworkTime.seconds_to_ticks(MAX_REWIND_SECONDS), tick)


## Celowac mozna tylko bronia i nie w trakcie przeladowania. Luneta wraca dopiero po przeladowaniu zamka.
func can_aim(tick := NetworkTime.tick) -> bool:
	var stats := active_stats()
	if stats == null or is_busy():
		return false
	return not stats.scope or tick - last_fire >= stats.fire_interval_ticks


func is_busy() -> bool:
	return action_end >= 0


func is_reloading() -> bool:
	return is_busy()


func start_timed_action(tick: int, seconds: float) -> void:
	action_end = tick + NetworkTime.seconds_to_ticks(seconds)


func cancel_timed_action() -> void:
	action_end = -1


## Postep trwajacego dzialania od 0 do 1.
func action_progress() -> float:
	var stack := active_stack()
	if not is_busy() or ItemStack.is_empty(stack):
		return 0.0
	var total := NetworkTime.seconds_to_ticks(ItemStack.behavior_of(stack).timed_action_seconds(stack))
	return clampf(1.0 - float(action_end - NetworkTime.tick) / maxi(total, 1), 0.0, 1.0)


## Ten sam tick moze byc symulowany kilka razy, ale strzal czy leczenie rozliczamy tylko raz.
func claim_server_action(tick: int) -> bool:
	if not multiplayer.is_server() or tick <= _resolved_up_to:
		return false
	_resolved_up_to = tick
	return true


## Po odrodzeniu wszystkie przedmioty sa gotowe do uzycia.
func on_respawn() -> void:
	action_end = -1
	spread_bloom = 0.0
	_sync_slots()
	for slot in Inventory.SLOTS:
		var stack: Dictionary = slots()[slot]
		if not ItemStack.is_empty(stack):
			_set_charges(slot, ItemStack.definition_of(stack).full_charges(ItemStack.tier_of(stack)))


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	if tick >= player.info.inventory_tick:
		_sync_slots(tick)
	_recover_spread(tick, delta)
	var dead := player.is_dead_at(tick)
	var wanted := clampi(input.slot, 0, Inventory.SLOTS - 1)
	if prime_tick >= 0:
		_update_primed(tick, dead or wanted != active_slot)
	if not dead and wanted != active_slot:
		active_slot = wanted
		_begin_draw(tick)
	var stack := active_stack()
	if dead or player.sprinting or ItemStack.is_empty(stack):
		action_end = -1
	elif action_end >= 0 and tick >= action_end:
		action_end = -1
		ItemStack.behavior_of(stack).on_timed_action_finished(self, stack, tick)
	if dead or player.sprinting or ItemStack.is_empty(stack) or tick < draw_end or Match.blocks_items_at(tick):
		return
	ItemStack.behavior_of(stack).rollback_tick(self, stack, tick)


func _recover_spread(tick: int, delta: float) -> void:
	var stats := active_stats()
	if stats == null:
		spread_bloom = 0.0
	elif tick - last_fire > stats.fire_interval_ticks + SPREAD_HOLD_TICKS:
		spread_bloom = maxf(spread_bloom - stats.bloom_recovery * delta, 0.0)


func _move_ratio() -> float:
	if not player.is_on_floor():
		return AIR_MOVE_RATIO
	return minf(Vector2(player.velocity.x, player.velocity.z).length() / Player.SPEED, 1.0)


## Przedmiot zniknal z reki, np. po smierci, wiec nie ma juz czego odbezpieczac.
func _update_primed(tick: int, force_drop: bool) -> void:
	var stack := active_stack()
	if ItemStack.is_empty(stack):
		prime_tick = -1
	else:
		ItemStack.behavior_of(stack).primed_tick(self, stack, tick, force_drop)


func _begin_draw(tick: int) -> void:
	action_end = -1
	spread_bloom = 0.0
	var stack := active_stack()
	var definition := ItemStack.definition_of(stack)
	draw_end = tick + (NetworkTime.seconds_to_ticks(definition.draw_seconds(ItemStack.tier_of(stack))) if definition != null else 0)


## Dopasowuje stan do zawartosci slotow. Nowy egzemplarz wnosi wlasne naboje.
func _sync_slots(tick := -1) -> void:
	for slot in Inventory.SLOTS:
		var stack: Dictionary = slots()[slot]
		var uid := ItemStack.uid_of(stack)
		if uid == _slot_uid(slot):
			continue
		_set_slot_uid(slot, uid)
		_set_charges(slot, stack.get("charges", 0))
		if slot == active_slot and tick >= 0:
			_begin_draw(tick)


func _after_tick_loop() -> void:
	if last_fire > _shown_fire:
		_shown_fire = last_fire
		fired.emit()
	if last_throw > _shown_throw:
		_shown_throw = last_throw
		thrown.emit()
	if (prime_tick >= 0) != _shown_primed:
		_shown_primed = prime_tick >= 0
		priming_changed.emit(_shown_primed)
	if action_end != _shown_action_end:
		# Korekta serwera moze przesunac koniec o pare tickow, ale to wciaz to samo dzialanie.
		if action_end < 0 or _shown_action_end < 0 or absi(action_end - _shown_action_end) > ACTION_CORRECTION_TICKS:
			_report_action_change()
		_shown_action_end = action_end
	var uid := _slot_uid(active_slot)
	if active_slot != _shown_slot or uid != _shown_uid:
		_shown_slot = active_slot
		_shown_uid = uid
		active_item_changed.emit()


## O tym, czy dzialanie sie udalo, decyduje zachowanie przedmiotu.
func _report_action_change() -> void:
	if _shown_action_end >= 0:
		var behavior := ItemStack.behavior_of(_action_stack)
		if action_end >= 0 or behavior == null or not behavior.was_action_completed(self, _action_stack, _action_slot, _shown_action_end):
			action_cancelled.emit()
	if action_end >= 0:
		_action_stack = active_stack()
		_action_slot = active_slot
		action_started.emit()


func _slot_uid(slot: int) -> int:
	match slot:
		0:
			return slot_uid_0
		1:
			return slot_uid_1
		2:
			return slot_uid_2
	return slot_uid_3


func _set_slot_uid(slot: int, value: int) -> void:
	match slot:
		0:
			slot_uid_0 = value
		1:
			slot_uid_1 = value
		2:
			slot_uid_2 = value
		_:
			slot_uid_3 = value


func _set_charges(slot: int, value: int) -> void:
	match slot:
		0:
			charges_0 = value
		1:
			charges_1 = value
		2:
			charges_2 = value
		_:
			charges_3 = value
