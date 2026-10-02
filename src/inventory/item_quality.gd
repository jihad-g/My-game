class_name ItemQuality
extends RefCounted
## Item quality (Milestone 15): crafted gear can come out Fine or Masterwork.
## Crafting never fails - quality only ever adds; Normal is the minimum.
##
## A quality item is its own item id, "<base>@fine" / "<base>@masterwork",
## built on demand by ItemDB from the base item, so inventories, equipment,
## saves and multiplayer all keep working with plain ids.

enum { NORMAL, FINE, MASTERWORK }
const NAMES := ["", "Fine", "Masterwork"]
const SUFFIX := ["", "fine", "masterwork"]
## Multiplier on the base item's numeric stats and value.
const STAT_MULT := [1.0, 1.1, 1.2]
const VALUE_MULT := [1.0, 1.5, 2.2]
## Crafting level needed before Masterwork can roll (the "Grandmaster" perk).
const MASTERWORK_CRAFTING := 90
const SKILLS := [&"strength", &"mana_control", &"defense", &"crafting", &"dexterity"]


static func quality_of(id: StringName) -> int:
	var s := String(id)
	var at := s.find("@")
	if at < 0:
		return NORMAL
	return maxi(SUFFIX.find(s.substr(at + 1)), NORMAL)


static func base_id(id: StringName) -> StringName:
	var s := String(id)
	var at := s.find("@")
	return StringName(s.substr(0, at)) if at >= 0 else id


static func with_quality(id: StringName, q: int) -> StringName:
	var b := base_id(id)
	return b if q <= NORMAL else StringName("%s@%s" % [b, SUFFIX[clampi(q, 0, 2)]])


## Only gear (weapons, armour, shields, rings, amulets) has quality.
static func can_have_quality(item: ItemData) -> bool:
	return item != null and item.is_equippable() and not item.is_tool()


## Quality of one crafted item at this Crafting level.
static func roll(crafting: int, rng: RandomNumberGenerator) -> int:
	if rng.randf() >= Skill.quality_chance(crafting):
		return NORMAL
	if crafting >= MASTERWORK_CRAFTING and rng.randf() < 0.3:
		return MASTERWORK
	return FINE


## Builds the quality version of `base` (ItemDB calls this on demand).
static func make_variant(base: ItemData, q: int) -> ItemData:
	var v: ItemData = base.duplicate()
	v.id = with_quality(base.id, q)
	v.display_name = "%s %s" % [NAMES[q], base.display_name]
	v.base_value = roundi(base.base_value * VALUE_MULT[q])
	var stats := {}
	for stat in base.stat_bonuses:
		var val := float(base.stat_bonuses[stat])
		if stat in SKILLS:
			stats[stat] = val + (1 if q == MASTERWORK else 0)  # Masterwork: +1 to every skill bonus
		elif val > 0.0:
			stats[stat] = maxf(roundf(val * STAT_MULT[q]), val + q)
		else:
			stats[stat] = val  # penalties (e.g. heavy armour slowness) stay as they are
	if base.weapon_type != &"" and base.equip_slot == ItemData.EquipSlot.MAIN_HAND:
		stats[&"damage_bonus"] = float(stats.get(&"damage_bonus", 0.0)) + (2.0 if q == FINE else 4.0)
	v.stat_bonuses = stats
	v.description = base.description + ("\n%s quality: better stats than a normal one." % NAMES[q])
	return v
