class_name GearSets
extends RefCounted
## Armour and clothing sets (Milestone 14). Wearing several pieces of one set
## gives extra bonuses on top of the pieces' own stats. Sets are what make a
## character *feel* like a Knight, Barbarian, Assassin or Wizard - any class
## can wear any set (the class keeps only a small talent, see ClassData).
##
## Bonus stats use the same keys as ItemData.stat_bonuses.

const SETS := {
	&"squire": {
		"name": "Squire's Kit",
		"feel": "Knight",
		"bonuses": {2: {&"max_health": 15}, 4: {&"parry": 50, &"block": 5, &"defense": 2}},
	},
	&"raider": {
		"name": "Raider's Furs",
		"feel": "Barbarian",
		"bonuses": {2: {&"physical_damage": 5}, 4: {&"max_stamina": 20, &"strength": 2}},
	},
	&"shadow": {
		"name": "Shadowstalker's Garb",
		"feel": "Assassin",
		"bonuses": {2: {&"backstab": 15}, 4: {&"crit_chance": 5, &"dexterity": 2}},
	},
	&"apprentice": {
		"name": "Apprentice's Vestments",
		"feel": "Wizard",
		"bonuses": {2: {&"spell_power": 5}, 4: {&"mana_regen": 15, &"mana_control": 2}},
	},
}


static func has_set(id: StringName) -> bool:
	return SETS.has(id)


static func display_name(id: StringName) -> String:
	return String(SETS[id].name) if SETS.has(id) else String(id).capitalize()


## Number of pieces needed for the full set.
static func full_size(id: StringName) -> int:
	if not SETS.has(id):
		return 0
	var n := 0
	for k in SETS[id].bonuses:
		n = maxi(n, int(k))
	return n


## Bonus stats active with `count` pieces of set `id` worn.
static func active_bonuses(id: StringName, count: int) -> Dictionary:
	var out := {}
	if not SETS.has(id):
		return out
	var tiers: Dictionary = SETS[id].bonuses
	for need in tiers:
		if count >= int(need):
			for stat in tiers[need]:
				out[stat] = float(out.get(stat, 0.0)) + float(tiers[need][stat])
	return out


## Tooltip lines for a set.
static func describe(id: StringName, worn: int = -1) -> PackedStringArray:
	var lines := PackedStringArray()
	if not SETS.has(id):
		return lines
	var head := "Set: %s" % display_name(id)
	if worn >= 0:
		head += " (%d/%d)" % [worn, full_size(id)]
	lines.append(head)
	var tiers: Dictionary = SETS[id].bonuses
	var keys := tiers.keys()
	keys.sort()
	for need in keys:
		var parts := PackedStringArray()
		for stat in tiers[need]:
			parts.append("%+d %s" % [roundi(float(tiers[need][stat])), ItemData.STAT_NAMES.get(stat, String(stat))])
		lines.append("  (%d) %s" % [int(need), ", ".join(parts)])
	return lines
