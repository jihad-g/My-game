class_name EliteAffixes
## Elite monster modifiers (Milestone 7). An elite has one affix, a champion
## two. Elites are bigger, glow in their affix colour, have 2.2x health,
## +25% damage, +3 levels, 3x XP and roll the "elite" loot table on death.
##
## Behaviour is implemented in Monster (search for the affix id).

const POWER := 2.2
const DAMAGE := 1.25
const LEVELS := 3
const XP := 3.0
const SIZE := 1.2

## id -> [name, colour, description]
const AFFIXES := {
	&"vampiric": ["Vampiric", Color(0.85, 0.1, 0.2), "Heals for 30% of the damage it deals."],
	&"frenzied": ["Frenzied", Color(1.0, 0.55, 0.1), "Moves and attacks 35% faster."],
	&"molten": ["Molten", Color(1.0, 0.35, 0.05), "Attacks burn. Explodes in flames when it dies."],
	&"glacial": ["Glacial", Color(0.55, 0.85, 1.0), "Attacks chill. Releases a freezing burst when it dies."],
	&"shielded": ["Shielded", Color(0.45, 0.65, 1.0), "A barrier absorbs damage and recharges if left alone."],
	&"thorned": ["Thorned", Color(0.45, 0.75, 0.25), "Reflects 25% of melee damage back at the attacker."],
	&"blinking": ["Blinking", Color(0.75, 0.45, 1.0), "Teleports behind its target."],
	&"juggernaut": ["Juggernaut", Color(0.7, 0.7, 0.75), "Can't be stunned, frozen or knocked back. +50% health."],
	&"venomous": ["Venomous", Color(0.5, 0.9, 0.3), "Attacks poison."],
}


static func ids() -> Array:
	return AFFIXES.keys()


static func display(id: StringName) -> String:
	return AFFIXES[id][0] if AFFIXES.has(id) else String(id).capitalize()


static func color_of(id: StringName) -> Color:
	return AFFIXES[id][1] if AFFIXES.has(id) else Color.WHITE


static func describe(id: StringName) -> String:
	return AFFIXES[id][2] if AFFIXES.has(id) else ""


## Random distinct affixes. Flying/ranged monsters skip melee-only ones.
static func roll(rng: RandomNumberGenerator, count: int, ranged: bool = false) -> Array[StringName]:
	var pool: Array = ids()
	if ranged:
		pool.erase(&"thorned")
	var out: Array[StringName] = []
	while out.size() < count and not pool.is_empty():
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


## Chance that a spawned monster is an elite (dungeons, raids, blood moon).
static func chance(rank: int, bonus: float = 0.0) -> float:
	return clampf(0.06 + rank * 0.035 + bonus, 0.0, 0.6)
