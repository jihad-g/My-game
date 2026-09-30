class_name Stats
## Names of multiplicative stat channels used by StatBlock.
##
## Survival systems (hunger, temperature), equipment and buffs write multipliers
## into these channels; gameplay code reads the combined result.

const MOVE_SPEED := &"move_speed"
const STAMINA_REGEN := &"stamina_regen"
const STAMINA_COST := &"stamina_cost"
const HEALTH_REGEN := &"health_regen"
const ATTACK_DAMAGE := &"attack_damage"
const ATTACK_SPEED := &"attack_speed"
const HUNGER_RATE := &"hunger_rate"
## Reserved for Phase 2 (mana system). Temperature already writes to it.
const MANA_REGEN := &"mana_regen"

const DISPLAY_NAMES := {
	MOVE_SPEED: "Move speed",
	STAMINA_REGEN: "Stamina regen",
	STAMINA_COST: "Stamina cost",
	HEALTH_REGEN: "Health regen",
	ATTACK_DAMAGE: "Attack damage",
	ATTACK_SPEED: "Attack speed",
	HUNGER_RATE: "Hunger rate",
	MANA_REGEN: "Mana regen",
}


## Human-readable "Move speed -15%" style text for a multiplier.
static func describe(stat: StringName, mult: float) -> String:
	var name: String = DISPLAY_NAMES.get(stat, String(stat))
	var pct := roundi((mult - 1.0) * 100.0)
	return "%s %s%d%%" % [name, "+" if pct >= 0 else "", pct]
