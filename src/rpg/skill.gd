class_name Skill
## The five core skills (levels 1-100) and every gameplay formula they drive.
##
## All numbers live here so balancing happens in one place and can be tested
## and exported to docs (tools/gen_rpg_tables.gd -> docs/SKILLS.md).
## `eff` is the class's efficiency for that skill (ClassData.skill_efficiency):
## the same Strength level makes a Barbarian far stronger than a Wizard.

const STRENGTH := &"strength"
const MANA_CONTROL := &"mana_control"
const DEFENSE := &"defense"
const CRAFTING := &"crafting"
const DEXTERITY := &"dexterity"

const ALL: Array[StringName] = [STRENGTH, MANA_CONTROL, DEFENSE, CRAFTING, DEXTERITY]
const MAX_LEVEL := 100

const NAMES := {
	STRENGTH: "Strength",
	MANA_CONTROL: "Mana Control",
	DEFENSE: "Defense",
	CRAFTING: "Crafting",
	DEXTERITY: "Dexterity",
}

const DESCRIPTIONS := {
	STRENGTH: "Physical damage, stamina, knockback and poise damage.",
	MANA_CONTROL: "Maximum mana, mana regeneration, spell power and cheaper abilities.",
	DEFENSE: "Maximum health, armor, blocking efficiency and resilience.",
	CRAFTING: "Material efficiency, harvesting yield, cooking and recipe tiers.",
	DEXTERITY: "Attack speed, critical hits, movement, dodging and backstabs.",
}

## Milestone perks: skill -> [[level, name, description], ...]. Effects are
## applied by the formulas below (see has_perk()).
const PERKS := {
	STRENGTH: [
		[25, "Heavy Hitter", "Heavy attacks deal +50% poise damage."],
		[50, "Unshakable", "Knockback taken -50%."],
		[75, "Crushing Blows", "Heavy attacks always stagger non-boss enemies."],
		[100, "Titan", "+10% physical damage."],
	],
	MANA_CONTROL: [
		[25, "Arcane Flow", "+25% mana regeneration."],
		[50, "Focused Mind", "Ability cooldowns -10%."],
		[75, "Overchannel", "Spells deal +15% damage when above 50% mana."],
		[100, "Archmage", "+15% spell power."],
	],
	DEFENSE: [
		[25, "Steady Guard", "Block negates an extra 10% damage."],
		[50, "Iron Skin", "Harmful status effects last 30% shorter."],
		[75, "Last Stand", "+20% damage reduction below 25% health."],
		[100, "Bulwark", "Immune to knockback."],
	],
	CRAFTING: [
		[10, "Apprentice Crafter", "Unlocks Common-tier recipes."],
		[25, "Journeyman", "Unlocks Uncommon-tier recipes; +10% cooking yield."],
		[45, "Artisan", "Unlocks Rare-tier recipes."],
		[70, "Master Artisan", "Unlocks Very Rare and Magical recipes."],
		[90, "Grandmaster", "Unlocks Legendary recipes; crafted gear can roll Masterwork."],
	],
	DEXTERITY: [
		[25, "Light Feet", "Dodge rolls cost 25% less stamina."],
		[50, "Precision", "Critical hits deal +25% damage."],
		[75, "Evasion", "Dodge invulnerability lasts 50% longer."],
		[100, "Shadowdancer", "+10% attack speed and +5% crit chance."],
	],
}


static func has_perk(skill: StringName, level: int, perk_level: int) -> bool:
	return level >= perk_level


static func perks_unlocked(skill: StringName, level: int) -> Array:
	var out := []
	for p in PERKS[skill]:
		if level >= int(p[0]):
			out.append(p)
	return out


static func next_perk(skill: StringName, level: int) -> Array:
	for p in PERKS[skill]:
		if level < int(p[0]):
			return p
	return []


# --- Strength -------------------------------------------------------------------------

## Multiplier on physical attack damage. `class_base` is ClassData.physical_power.
static func physical_damage_mult(strength: int, eff: float, class_base: float) -> float:
	var m := class_base * (1.0 + 0.012 * strength * eff)
	if strength >= 100:
		m *= 1.1
	return m


static func bonus_stamina(strength: int, eff: float) -> float:
	return 0.5 * strength * eff


static func poise_mult(strength: int, eff: float) -> float:
	return 1.0 + 0.01 * strength * eff


static func knockback_taken_mult(strength: int, defense: int) -> float:
	if defense >= 100:
		return 0.0
	return 0.5 if strength >= 50 else 1.0


# --- Mana Control ------------------------------------------------------------------------

static func max_mana(mana_control: int, class_base: float, per_point: float) -> float:
	return class_base + mana_control * per_point


static func mana_regen(mana_control: int, eff: float) -> float:
	var r := 1.5 * (1.0 + 0.02 * mana_control * eff)
	if mana_control >= 25:
		r *= 1.25
	return r


static func spell_power_mult(mana_control: int, eff: float, class_base: float) -> float:
	var m := class_base * (1.0 + 0.015 * mana_control * eff)
	if mana_control >= 100:
		m *= 1.15
	return m


## Ability mana cost multiplier (down to 0.7 at 100).
static func mana_cost_mult(mana_control: int) -> float:
	return 1.0 - 0.003 * mana_control


static func cooldown_mult(mana_control: int) -> float:
	return 0.9 if mana_control >= 50 else 1.0


# --- Defense -----------------------------------------------------------------------------

static func max_health(defense: int, class_base: float, per_point: float) -> float:
	return class_base + defense * per_point


static func skill_armor(defense: int, eff: float) -> float:
	return defense * 0.8 * eff


## Damage reduction from armor (diminishing returns, capped at 75%).
static func damage_reduction(armor: float) -> float:
	return minf(armor / (armor + 100.0), 0.75)


static func block_stamina_mult(defense: int) -> float:
	return 1.0 - 0.005 * defense


static func block_bonus(defense: int) -> float:
	return 0.1 if defense >= 25 else 0.0


static func status_duration_mult(defense: int) -> float:
	return 0.7 if defense >= 50 else 1.0


# --- Crafting ----------------------------------------------------------------------------

## Materials consumed per recipe relative to the recipe's listed amounts.
## Low skill wastes material (never fails); mastery saves material.
static func material_cost_mult(crafting: int) -> float:
	return 1.6 - 0.008 * crafting


## Chance of one extra drop when harvesting/gathering.
static func harvest_bonus_chance(crafting: int, eff: float) -> float:
	return 0.008 * crafting * eff


## Chance to cook two portions instead of one.
static func cooking_bonus_chance(crafting: int, eff: float) -> float:
	return 0.005 * crafting * eff + (0.1 if crafting >= 25 else 0.0)


## Highest recipe rarity tier unlocked (ItemData.Rarity index).
static func recipe_tier(crafting: int) -> int:
	if crafting >= 90:
		return ItemData.Rarity.LEGENDARY
	if crafting >= 70:
		return ItemData.Rarity.MAGICAL
	if crafting >= 45:
		return ItemData.Rarity.RARE
	if crafting >= 25:
		return ItemData.Rarity.UNCOMMON
	if crafting >= 10:
		return ItemData.Rarity.COMMON
	return ItemData.Rarity.BASIC


## Chance for a crafted item to be of higher quality (Fine/Masterwork).
static func quality_chance(crafting: int) -> float:
	return clampf((crafting - 20) * 0.006, 0.0, 0.5)


# --- Dexterity ---------------------------------------------------------------------------

static func attack_speed_mult(dexterity: int, eff: float) -> float:
	var m := 1.0 + 0.004 * dexterity * eff
	if dexterity >= 100:
		m += 0.1
	return m


static func crit_chance(dexterity: int, eff: float) -> float:
	return 0.05 + 0.002 * dexterity * eff + (0.05 if dexterity >= 100 else 0.0)


static func crit_damage_mult(dexterity: int) -> float:
	return 1.5 + (0.25 if dexterity >= 50 else 0.0)


static func move_speed_mult(dexterity: int, eff: float) -> float:
	return 1.0 + 0.0015 * dexterity * eff


static func dodge_cost_mult(dexterity: int) -> float:
	return (1.0 - 0.003 * dexterity) * (0.75 if dexterity >= 25 else 1.0)


static func dodge_iframe_mult(dexterity: int) -> float:
	return 1.5 if dexterity >= 75 else 1.0 + 0.003 * dexterity


static func backstab_bonus(dexterity: int, eff: float) -> float:
	return 0.005 * dexterity * eff
