extends Node
## Test danych przedmiotow i operacji na ekwipunku.
## Uzycie: godot --headless --path . -- --tool=res://tools/items_test.gd

var _failures := 0


func _ready() -> void:
	var blaster := ItemRegistry.get_definition(ItemRegistry.DEFAULT_WEAPON) as WeaponDefinition
	_check("rejestr zna blaster", blaster != null)
	_check("nieznany przedmiot nie istnieje", ItemRegistry.get_definition(&"nie_ma") == null)
	var common := blaster.stats(Rarity.Tier.COMMON)
	var epic := blaster.stats(Rarity.Tier.EPIC)
	var legendary := blaster.stats(Rarity.Tier.LEGENDARY)
	_check("zwykly ma dzisiejsze wartosci", common.damage == 20 and common.headshot_damage == 40 and common.magazine == 12 and common.fire_interval_ticks == 6)
	_check("klasy rosna w sile", common.damage < epic.damage and epic.damage < legendary.damage)
	_check("wyzsza klasa szybciej laduje", common.reload_seconds > epic.reload_seconds and epic.reload_seconds > legendary.reload_seconds)
	_check("kazda klasa ma inny model", common.visual.model_path != epic.visual.model_path and epic.visual.model_path != legendary.visual.model_path)
	_check("modele i ikony istnieja", _visuals_exist(blaster))
	_check("wyzsza klasa ma silniejszy odrzut", common.recoil < epic.recoil and epic.recoil < legendary.recoil)
	_check("nazwa dla gracza", ItemStack.display_name_of(ItemStack.create(1, ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.EPIC)) == "Epicki Blaster")
	_check("dzwieki strzalu sa rozne", Sfx.shot(common) != Sfx.shot(epic) and Sfx.shot(epic) != Sfx.shot(legendary))
	_check("nazwy klas", Rarity.display_name(Rarity.Tier.EPIC) == "Epicki")
	_check_shotgun()
	_check_knife()
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_shotgun() -> void:
	var shotgun := ItemRegistry.get_definition(&"shotgun") as WeaponDefinition
	_check("rejestr zna strzelbe", shotgun != null)
	_check("modele i ikony strzelby istnieja", _visuals_exist(shotgun))
	var common := shotgun.stats(Rarity.Tier.COMMON)
	var epic := shotgun.stats(Rarity.Tier.EPIC)
	var legendary := shotgun.stats(Rarity.Tier.LEGENDARY)
	_check("strzelba ma wiele srucin", common.pellets > 1 and common.spread_degrees > 0.0)
	_check("wyzsza klasa strzelby jest silniejsza", common.damage * common.pellets < epic.damage * epic.pellets and epic.damage * epic.pellets < legendary.damage * legendary.pellets)
	_check("wyzsza klasa ma mniejszy rozrzut", common.spread_degrees > epic.spread_degrees and epic.spread_degrees > legendary.spread_degrees)
	_check("wyzsza klasa strzelby szybciej laduje", common.reload_seconds > epic.reload_seconds and epic.reload_seconds > legendary.reload_seconds)
	_check("celowanie zaciska rozrzut w danych", common.current_spread(true) < common.current_spread(false))
	_check("nazwa odmienia sie przez rodzaj", ItemStack.display_name_of(ItemStack.create(1, &"shotgun", Rarity.Tier.EPIC)) == "Epicka Strzelba")
	_check("strzelba brzmi inaczej niz blaster", Sfx.shot(common) != Sfx.shot(ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON)))
	var blaster := ItemRegistry.weapon_stats(ItemRegistry.DEFAULT_WEAPON, Rarity.Tier.COMMON)
	_check("blaster wciaz strzela jednym pociskiem", blaster.pellets == 1 and blaster.current_spread(false) == 0.0)


func _check_knife() -> void:
	var knife := ItemRegistry.get_definition(&"knife") as MeleeDefinition
	_check("rejestr zna noz", knife != null)
	var visual := knife.visual(Rarity.Tier.COMMON)
	_check("model i ikona noza istnieja", ResourceLoader.exists(visual.model_path) and ResourceLoader.exists(visual.icon_path))
	_check("noz nie ma klas ani nabojow", not knife.has_tiers() and knife.full_charges(Rarity.Tier.COMMON) == 0)
	_check("dwa ciosy zabijaja", knife.damage * 2 >= GameState.MAX_HEALTH and knife.damage < GameState.MAX_HEALTH)
	_check("z nozem biega sie szybciej", knife.move_speed_scale() > 1.0)
	_check("dzwieki noza istnieja", Sfx.knife_swing() != null and Sfx.knife_hit() != null)


func _visuals_exist(definition: WeaponDefinition) -> bool:
	for tier: int in [Rarity.Tier.COMMON, Rarity.Tier.EPIC, Rarity.Tier.LEGENDARY]:
		var visual := definition.visual(tier)
		if not ResourceLoader.exists(visual.model_path) or not ResourceLoader.exists(visual.icon_path):
			return false
	return true


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_failures += 1
