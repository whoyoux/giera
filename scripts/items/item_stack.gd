class_name ItemStack
extends RefCounted
## Konkretny egzemplarz przedmiotu. To slownik, bo musi przejsc przez RPC.
## Pusty slot to pusty slownik. Kazdy egzemplarz ma unikalne uid nadane przez serwer.


static func create(uid: int, item_id: StringName, tier: int) -> Dictionary:
	var definition := ItemRegistry.get_definition(item_id)
	return {
		"uid": uid,
		"item": String(item_id),
		"tier": tier,
		"charges": definition.full_charges(tier),
	}


static func is_empty(stack: Dictionary) -> bool:
	return stack.is_empty()


static func uid_of(stack: Dictionary) -> int:
	return stack.get("uid", 0)


static func definition_of(stack: Dictionary) -> ItemDefinition:
	return ItemRegistry.get_definition(StringName(stack.get("item", "")))


static func tier_of(stack: Dictionary) -> int:
	return stack.get("tier", Rarity.Tier.COMMON)


static func behavior_of(stack: Dictionary) -> ItemBehavior:
	var definition := definition_of(stack)
	return definition.behavior() if definition != null else null


static func weapon_stats_of(stack: Dictionary) -> WeaponStats:
	var definition := definition_of(stack) as WeaponDefinition
	return definition.stats(tier_of(stack)) if definition != null else null
