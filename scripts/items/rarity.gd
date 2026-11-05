class_name Rarity
extends RefCounted
## Klasy przedmiotow. Wartosci ida przez siec, wiec nowe klasy dopisuj na koncu.

enum Tier { COMMON, EPIC, LEGENDARY }

const NAMES := { Tier.COMMON: "Zwykły", Tier.EPIC: "Epicki", Tier.LEGENDARY: "Legendarny" }
const EFFECT_COLORS := { Tier.COMMON: Color("fff3a3"), Tier.EPIC: Color("d9b8ff"), Tier.LEGENDARY: Color("ffd24d") }
const COLORS := { Tier.COMMON: Color("a9adb8"), Tier.EPIC: Color("9b5de5"), Tier.LEGENDARY: Color("f6a609") }


static func display_name(tier: int) -> String:
	return NAMES.get(tier, NAMES[Tier.COMMON])


## Kolor smugi i blysku strzalu.
static func effect_color(tier: int) -> Color:
	return EFFECT_COLORS.get(tier, EFFECT_COLORS[Tier.COMMON])


static func color(tier: int) -> Color:
	return COLORS.get(tier, COLORS[Tier.COMMON])
