class_name LootTable
extends Resource
## Co moze wypasc i z jakim prawdopodobienstwem. Rodzaj i klasa losowane sa osobno,
## wiec nowy przedmiot wystarczy dopisac do listy.

@export var item_ids: Array[StringName] = []
## Waga kazdego rodzaju, w tej samej kolejnosci co item_ids.
@export var item_weights: Array[int] = []
## Waga kazdej klasy, w kolejnosci z Rarity.Tier.
@export var tier_weights: Array[int] = []
## Dodatkowy przedmiot, ktory czasem wypada obok glownego.
@export var bonus_item: StringName
@export_range(0.0, 1.0) var bonus_chance := 0.0


## Zwraca { item, tier }.
func roll(rng: RandomNumberGenerator) -> Dictionary:
	return { "item": item_ids[_pick(item_weights, rng)], "tier": _pick(tier_weights, rng) }


## Wszystko, co wypada z jednego otwarcia. Pierwszy jest glowny przedmiot.
func roll_all(rng: RandomNumberGenerator) -> Array:
	var loot := [roll(rng)]
	if bonus_item != &"" and rng.randf() < bonus_chance:
		loot.append({ "item": bonus_item, "tier": Rarity.Tier.COMMON })
	return loot


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
