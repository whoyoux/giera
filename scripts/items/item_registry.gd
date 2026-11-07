extends Node
## Spis wszystkich rodzajow przedmiotow. Pliki sa wymienione wprost, zeby eksport gry
## na pewno je zawieral. Nowy przedmiot wystarczy dopisac do listy.

const DEFAULT_WEAPON := &"blaster"
const DEFINITIONS: Array[ItemDefinition] = [
	preload("res://data/items/blaster.tres"),
	preload("res://data/items/medkit.tres"),
	preload("res://data/items/grenade.tres"),
	preload("res://data/items/shotgun.tres"),
	preload("res://data/items/knife.tres"),
	preload("res://data/items/deagle.tres"),
	preload("res://data/items/awp.tres"),
]

var _by_id := {}


func _init() -> void:
	for definition in DEFINITIONS:
		assert(not _by_id.has(definition.id), "Powtorzone id przedmiotu: %s" % definition.id)
		_by_id[definition.id] = definition


func get_definition(id: StringName) -> ItemDefinition:
	return _by_id.get(id)


func weapon_stats(id: StringName, tier: int) -> WeaponStats:
	var definition := get_definition(id) as WeaponDefinition
	return definition.stats(tier) if definition != null else null
