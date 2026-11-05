class_name LootTable
extends Resource
## Co moze wypasc i z jakim prawdopodobienstwem. Rodzaj i klasa losowane sa osobno,
## wiec nowy przedmiot wystarczy dopisac do listy. Przedmiot bez klas jest zawsze zwykly.

@export var item_ids: Array[StringName] = []
## Waga kazdego rodzaju, w tej samej kolejnosci co item_ids.
@export var item_weights: Array[int] = []
## Waga kazdej klasy, w kolejnosci z Rarity.Tier.
@export var tier_weights: Array[int] = []


## Zwraca { item, tier }.
func roll(rng: RandomNumberGenerator) -> Dictionary:
	var item := item_ids[_pick(item_weights, rng)]
	var tier := _pick(tier_weights, rng)
	return { "item": item, "tier": tier if ItemRegistry.get_definition(item).has_tiers() else Rarity.Tier.COMMON }


func _pick(weights: Array[int], rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in weights:
		total += weight
	var left := rng.randi_range(1, total)
	for index in weights.size():
		left -= weights[index]
		if left <= 0:
			return index
	return 0
