extends Node
## Test apteczki w oknie gry, jako host. Sprawdza tez, czy system przedmiotow nie zaklada, ze wszystko jest bronia.
## Uzycie: godot --path . --resolution 1280x720 -- --tool=res://tools/medkit_test.gd

const PORT := 8124
const MEDKIT := &"medkit"

var _failures := 0
var _info: Dictionary
var _equipment: Equipment
var _player: Player


func _ready() -> void:
	_check_data()
	_check("host startuje", Net.start_server(PORT).is_empty())
	await _wait(1.5)
	_player = get_node("/root/Main/Players/1") as Player
	var hud := get_node("/root/Main/Hud") as Hud
	get_window().focus_exited.disconnect(hud._on_focus_lost)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_info = GameState.players[1]
	_equipment = _player.equipment
	GameState.server_add_player(2, "Cel")
	var definition := ItemRegistry.get_definition(MEDKIT) as MedkitDefinition

	var slot := GameState.server_give_item(1, MEDKIT, Rarity.Tier.COMMON)
	await _wait(0.1)
	_player.input.select_slot(slot)
	await _wait(0.2)
	_check("apteczka jest w rece", _player.view_model.has_item() and _player.view_model.shown_visual() == definition.item_visual)
	_check("apteczka nie ma pola nabojow", _equipment.active_stats() == null and not hud._ammo_panel.visible)
	_check("podpowiedz o pelnym zdrowiu", hud._use_panel.visible and hud._use_label.text.contains("pełne"))

	# Przy pelnym zdrowiu nic sie nie dzieje.
	await _hold(0.4)
	_check("pelne zdrowie nie zuzywa", _equipment.active_stack() != {} and not _equipment.is_busy())

	GameState.server_damage(1, 70, 2)
	await _wait(0.1)
	_check("podpowiedz pokazuje leczenie", hud._use_label.text.contains("+50"))

	# Puszczenie przycisku przerywa.
	await _hold(0.5)
	_check("krotkie przytrzymanie nie leczy", _info.health == 30 and not _equipment.is_busy())
	_check("przerwanie zatrzymuje dzwiek", not _player.reload_audio.playing)
	_check("apteczka zostaje", not ItemStack.is_empty(_info.slots[slot]))

	# Zmiana slotu przerywa.
	Input.action_press("fire")
	await _wait(0.3)
	_check("uzycie trwa i gra dzwiek", _equipment.is_busy() and _player.reload_audio.playing)
	_check("pasek rosnie", hud._use_bar.visible and hud._use_bar.value > 0.0)
	_player.input.select_slot(0)
	await _wait(0.2)
	Input.action_release("fire")
	_check("zmiana slotu przerywa", not _equipment.is_busy() and _info.health == 30)
	await _wait(0.2)
	_player.input.select_slot(slot)
	await _wait(0.2)

	# Cale uzycie leczy i zabiera apteczke.
	Input.action_press("fire")
	var started := Time.get_ticks_msec()
	while _info.health == 30 and Time.get_ticks_msec() - started < 4000:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("[test] leczenie trwalo %.2f s" % elapsed)
	await _wait(0.2)
	Input.action_release("fire")
	_check("leczy o %d" % definition.heal_amount, _info.health == 80)
	_check("czas sie zgadza", absf(elapsed - definition.use_seconds) < 0.25)
	_check("apteczka znika", ItemStack.is_empty(_info.slots[slot]))
	_check("wybor wraca na bron", _player.input.selected_slot() == 0)
	_check("nie bylo strzalu", _equipment.charges(0) == 12)

	# Nie leczy powyzej maksimum i serwer pilnuje egzemplarza.
	var again := GameState.server_give_item(1, MEDKIT, Rarity.Tier.COMMON)
	GameState.server_use_medkit(1, 987654, 50)
	_check("zly egzemplarz nic nie robi", _info.health == 80 and not ItemStack.is_empty(_info.slots[again]))
	GameState.server_use_medkit(1, ItemStack.uid_of(_info.slots[again]), 50)
	_check("leczenie ma limit", _info.health == GameState.MAX_HEALTH and ItemStack.is_empty(_info.slots[again]))

	# Apteczke mozna wyrzucic i podniesc jak kazdy przedmiot, a po smierci wypada.
	var third := GameState.server_give_item(1, MEDKIT, Rarity.Tier.COMMON)
	await _wait(0.2)
	_player.input.select_slot(third)
	await _wait(0.2)
	_player.input.look_pitch = 0.0
	_player.try_drop()
	await _wait(0.2)
	_check("apteczka lezy na ziemi", WorldItems.items.size() == 1)
	var stack: Dictionary = WorldItems.items.values()[0].stack
	_check("na ziemi ma nazwe bez klasy", ItemStack.display_name_of(stack) == "Apteczka")
	await _wait(0.3)
	_player.try_pickup()
	await _wait(0.2)
	_check("apteczke mozna podniesc", WorldItems.items.is_empty() and ItemStack.uid_of(_info.slots[third]) == ItemStack.uid_of(stack))
	GameState.server_damage(1, 500, 2)
	await _wait(0.2)
	_check("po smierci apteczka wypada", WorldItems.items.size() == 1 and ItemStack.is_empty(_info.slots[third]))

	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_data() -> void:
	var definition := ItemRegistry.get_definition(MEDKIT) as MedkitDefinition
	_check("rejestr zna apteczke", definition != null)
	_check("model i ikona istnieja", ResourceLoader.exists(definition.item_visual.model_path) and ResourceLoader.exists(definition.item_visual.icon_path))
	_check("apteczka nie ma ladunkow", definition.full_charges(Rarity.Tier.COMMON) == 0)
	var table := Chests.LOOT_TABLE
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bonus := 0
	var tiers := [0, 0, 0]
	for i in 10000:
		var rolled: Array = table.roll_all(rng)
		tiers[rolled[0].tier] += 1
		_expect_item(rolled[0], ItemRegistry.DEFAULT_WEAPON)
		if rolled.size() > 1:
			bonus += 1
			_expect_item(rolled[1], MEDKIT)
	print("[test] klasy: %s, apteczek: %d" % [tiers, bonus])
	_check("bron wypada zawsze w tych samych proporcjach", absi(tiers[0] - 7000) < 300 and absi(tiers[1] - 2500) < 300 and absi(tiers[2] - 500) < 150)
	_check("apteczka wypada w okolo 30%", absi(bonus - 3000) < 300)


func _expect_item(rolled: Dictionary, item: StringName) -> void:
	if rolled.item != item:
		_check("wypadl wlasciwy przedmiot", false)


func _hold(seconds: float) -> void:
	Input.action_press("fire")
	await _wait(seconds)
	Input.action_release("fire")
	await _wait(0.15)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
