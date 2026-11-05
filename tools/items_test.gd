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
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


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
