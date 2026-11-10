class_name ArsenalStats
extends RefCounted
## Liczby i paski do Zbrojowni, liczone prosto z definicji przedmiotow. Nowa bron z ItemRegistry
## pojawia sie sama, a paski broni palnej skaluja sie do najlepszej broni w grze.

enum Category { GUN, MELEE, THROWN, HEALING }

const CATEGORY_NAMES := {
	Category.GUN: "Broń palna",
	Category.MELEE: "Walka wręcz",
	Category.THROWN: "Rzucane",
	Category.HEALING: "Leczenie",
}
const CATEGORY_COLORS := {
	Category.GUN: UiStyle.CORAL,
	Category.MELEE: UiStyle.BLUE,
	Category.THROWN: Color("f4a259"),
	Category.HEALING: UiStyle.TEAL,
}
const TICKS_PER_SECOND := 60.0
## Rozrzut przy celowaniu, przy ktorym pasek celnosci jest pusty.
const WORST_AIM_SPREAD := 6.0
## Pasek nigdy nie jest calkiem pusty, zeby bylo widac, ze cos tam jest.
const MIN_BAR := 0.04
## Odniesienia dla przedmiotow bez klas, ktorych nie ma z czym porownac.
const REFERENCE_REACH := 3.0
const REFERENCE_FUSE := 5.0
const REFERENCE_BLAST := 10.0
const REFERENCE_USE_SECONDS := 5.0

static var _best := {}


static func category(definition: ItemDefinition) -> Category:
	if definition is MeleeDefinition:
		return Category.MELEE
	if definition is GrenadeDefinition:
		return Category.THROWN
	if definition is MedkitDefinition:
		return Category.HEALING
	return Category.GUN


## Bron z klasami bierze kolor klasy, reszta kolor swojej kategorii.
static func color(definition: ItemDefinition, tier: int) -> Color:
	return Rarity.color(tier) if definition.has_tiers() else CATEGORY_COLORS[category(definition)]


static func title(definition: ItemDefinition, tier: int) -> String:
	if not definition.has_tiers():
		return definition.display_name
	return "%s %s" % [Rarity.display_name(tier, definition.feminine_name), definition.display_name]


static func icon(definition: ItemDefinition, tier: int) -> Texture2D:
	var visual := definition.visual(tier)
	return load(visual.icon_path) as Texture2D if visual != null and not visual.icon_path.is_empty() else null


## Liczby jednej broni palnej w danej klasie.
static func gun_numbers(definition: WeaponDefinition, tier: int) -> Dictionary:
	var stats := definition.stats(tier)
	var rate := TICKS_PER_SECOND / stats.fire_interval_ticks
	var per_shot := stats.damage * stats.pellets
	return {
		"per_shot": per_shot,
		"pellets": stats.pellets,
		"damage": stats.damage,
		"headshot": stats.headshot_damage * stats.pellets,
		"rate": rate,
		"dps": per_shot * rate,
		"aim_spread": stats.spread_degrees * stats.aim_spread_scale,
		"scope": stats.scope,
		"magazine": stats.magazine,
		"reload": stats.reload_seconds,
		"draw": stats.draw_seconds,
		"move": definition.move_scale,
	}


## Paski: kazdy to { label, value od 0 do 1, text }.
static func bars(definition: ItemDefinition, tier: int) -> Array[Dictionary]:
	var best := _best_values()
	var rows: Array[Dictionary] = []
	if definition is WeaponDefinition:
		var n := gun_numbers(definition, tier)
		var accuracy := clampf(1.0 - n.aim_spread / WORST_AIM_SPREAD, 0.0, 1.0)
		rows.append(_bar("Obrażenia", n.per_shot / best.per_shot,
				"%d×%d" % [n.pellets, n.damage] if n.pellets > 1 else str(n.damage)))
		rows.append(_bar("Szybkostrzelność", n.rate / best.rate, "%s/s" % number(n.rate)))
		rows.append(_bar("Celność", accuracy, "luneta" if n.scope else "%d%%" % roundi(accuracy * 100.0)))
		rows.append(_bar("Magazynek", float(n.magazine) / best.magazine, str(n.magazine)))
		rows.append(_bar("Przeładowanie", best.reload / n.reload, "%s s" % number(n.reload)))
		rows.append(_bar("Mobilność", n.move / best.move, "%d%%" % roundi(n.move * 100.0)))
	elif definition is MeleeDefinition:
		var melee := definition as MeleeDefinition
		var rate := TICKS_PER_SECOND / melee.swing_interval_ticks
		rows.append(_bar("Obrażenia", melee.damage / best.per_shot, str(melee.damage)))
		rows.append(_bar("Szybkość ciosów", rate / best.rate, "%s/s" % number(rate)))
		rows.append(_bar("Zasięg", melee.reach / REFERENCE_REACH, "%s m" % number(melee.reach)))
		rows.append(_bar("Mobilność", melee.speed_scale / best.move, "%d%%" % roundi(melee.speed_scale * 100.0)))
	elif definition is GrenadeDefinition:
		var grenade := definition as GrenadeDefinition
		rows.append(_bar("Obrażenia", float(grenade.near_damage) / GameState.MAX_HEALTH, str(grenade.near_damage)))
		rows.append(_bar("Promień wybuchu", grenade.blast_radius / REFERENCE_BLAST, "%s m" % number(grenade.blast_radius)))
		rows.append(_bar("Strefa śmierci", grenade.kill_radius / REFERENCE_BLAST, "%s m" % number(grenade.kill_radius)))
		rows.append(_bar("Zapalnik", grenade.fuse_seconds / REFERENCE_FUSE, "%s s" % number(grenade.fuse_seconds)))
	elif definition is MedkitDefinition:
		var medkit := definition as MedkitDefinition
		rows.append(_bar("Leczenie", float(medkit.heal_amount) / GameState.MAX_HEALTH, "+%d HP" % medkit.heal_amount))
		rows.append(_bar("Czas użycia", medkit.use_seconds / REFERENCE_USE_SECONDS, "%s s" % number(medkit.use_seconds)))
	return rows


## Liczby pod paskami: kazda to [podpis, wartosc].
static func facts(definition: ItemDefinition, tier: int) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if definition is WeaponDefinition:
		var n := gun_numbers(definition, tier)
		rows.append(PackedStringArray(["DPS", str(roundi(n.dps))]))
		rows.append(PackedStringArray(["W głowę", str(n.headshot)]))
		rows.append(PackedStringArray(["Wyciąganie", "%s s" % number(n.draw)]))
	elif definition is MeleeDefinition:
		var melee := definition as MeleeDefinition
		rows.append(PackedStringArray(["DPS", str(roundi(melee.damage * TICKS_PER_SECOND / melee.swing_interval_ticks))]))
		rows.append(PackedStringArray(["Kąt ciosu", "%d°" % roundi(melee.cone_degrees)]))
		rows.append(PackedStringArray(["Wyciąganie", "%s s" % number(melee.draw_time)]))
	elif definition is GrenadeDefinition:
		var grenade := definition as GrenadeDefinition
		rows.append(PackedStringArray(["Z bliska", "zabija"]))
		rows.append(PackedStringArray(["Na krawędzi", str(grenade.edge_damage)]))
		rows.append(PackedStringArray(["Rzut", "%s m/s" % number(grenade.throw_speed)]))
	elif definition is MedkitDefinition:
		var medkit := definition as MedkitDefinition
		rows.append(PackedStringArray(["Pełne zdrowie", str(GameState.MAX_HEALTH)]))
		rows.append(PackedStringArray(["Leczy", "%d%%" % roundi(100.0 * medkit.heal_amount / GameState.MAX_HEALTH)]))
		rows.append(PackedStringArray(["Leczenie trwa", "%s s" % number(medkit.use_seconds)]))
	rows.append(PackedStringArray(["Ze skrzyni", "%d%%" % roundi(Chests.LOOT_TABLE.chance_of(definition.id) * 100.0)]))
	return rows


## Wszystkie bronie palne w kolejnosci z ItemRegistry.
static func guns() -> Array[WeaponDefinition]:
	var list: Array[WeaponDefinition] = []
	for definition in ItemRegistry.DEFINITIONS:
		if definition is WeaponDefinition:
			list.append(definition)
	return list


## Liczba z przecinkiem, jak po polsku, bez zbednych zer.
static func number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2).replace(".", ",")


static func _bar(label: String, value: float, text: String) -> Dictionary:
	return { "label": label, "value": clampf(value, MIN_BAR, 1.0), "text": text }


## Najlepsze wartosci w grze. Licza sie raz, bo definicje sie nie zmieniaja.
static func _best_values() -> Dictionary:
	if not _best.is_empty():
		return _best
	_best = { "per_shot": 1.0, "rate": 0.1, "magazine": 1.0, "reload": 999.0, "move": 1.0 }
	for gun in guns():
		for tier in Rarity.Tier.values():
			var n := gun_numbers(gun, tier)
			_best.per_shot = maxf(_best.per_shot, n.per_shot)
			_best.rate = maxf(_best.rate, n.rate)
			_best.magazine = maxf(_best.magazine, n.magazine)
			_best.reload = minf(_best.reload, n.reload)
	for definition in ItemRegistry.DEFINITIONS:
		_best.move = maxf(_best.move, definition.move_speed_scale())
	return _best
