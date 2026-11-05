class_name Equipment
extends Node
## Przedmiot w reku i jego symulacja. Co lezy w slotach wie GameState, a tutaj jest
## stan rollbacku, ktory klient przewiduje od razu. Zachowanie przedmiotu lezy w ItemBehavior.

signal fired
signal action_started
signal action_cancelled
## Zmienil sie przedmiot w reku: inny slot albo inny egzemplarz w tym samym slocie.
signal active_item_changed

# Stan rollbacku. Osobne liczby zamiast tablicy, bo netfox wysyla tylko zmienione wartosci.
var active_slot := 0
var last_fire := -1000
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

var _resolved_up_to := -1
var _shown_fire := -1000
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


func active_charges() -> int:
	return charges(active_slot)


func set_active_charges(value: int) -> void:
	_set_charges(active_slot, value)


func is_busy() -> bool:
	return action_end >= 0


func is_reloading() -> bool:
	return is_busy()


func start_timed_action(tick: int, seconds: float) -> void:
	action_end = tick + NetworkTime.seconds_to_ticks(seconds)


## Ten sam tick moze byc symulowany kilka razy, ale strzal rozliczamy tylko raz.
func claim_server_shot(tick: int) -> bool:
	if not multiplayer.is_server() or tick <= _resolved_up_to:
		return false
	_resolved_up_to = tick
	return true


## Po odrodzeniu wszystkie przedmioty sa gotowe do uzycia.
func on_respawn() -> void:
	action_end = -1
	_sync_slots()
	for slot in Inventory.SLOTS:
		var stack: Dictionary = slots()[slot]
		if not ItemStack.is_empty(stack):
			_set_charges(slot, ItemStack.definition_of(stack).full_charges(ItemStack.tier_of(stack)))


func _rollback_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	if tick >= player.info.inventory_tick:
		_sync_slots(tick)
	var dead := player.is_dead_at(tick)
	var wanted := clampi(input.slot, 0, Inventory.SLOTS - 1)
	if not dead and wanted != active_slot:
		active_slot = wanted
		_begin_draw(tick)
	var stack := active_stack()
	if dead or player.sprinting or ItemStack.is_empty(stack):
		action_end = -1
	elif action_end >= 0 and tick >= action_end:
		action_end = -1
		ItemStack.behavior_of(stack).on_timed_action_finished(self, stack)
	if dead or player.sprinting or ItemStack.is_empty(stack) or tick < draw_end:
		return
	ItemStack.behavior_of(stack).rollback_tick(self, stack, tick)


func _begin_draw(tick: int) -> void:
	action_end = -1
	var stats := active_stats()
	draw_end = tick + (NetworkTime.seconds_to_ticks(stats.draw_seconds) if stats != null else 0)


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
	if action_end != _shown_action_end:
		_report_action_change()
		_shown_action_end = action_end
	var uid := _slot_uid(active_slot)
	if active_slot != _shown_slot or uid != _shown_uid:
		_shown_slot = active_slot
		_shown_uid = uid
		active_item_changed.emit()


## Koniec dzialania z pelnym magazynkiem to sukces, a kazdy inny to przerwanie.
func _report_action_change() -> void:
	if _shown_action_end >= 0:
		var definition := ItemStack.definition_of(_action_stack)
		var full := definition.full_charges(ItemStack.tier_of(_action_stack)) if definition != null else 0
		if charges(_action_slot) < full or action_end >= 0:
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
