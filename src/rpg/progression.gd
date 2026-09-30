class_name Progression
## Character levels 1-100 and experience.
##
## XP to go from level L to L+1:
##     100 + 40*(L-1)^1.5 + 0.35*(L-1)^3, rounded to 10
## Early levels come quickly (level 2 after ~5 boars), late levels demand real
## endgame content (~9.8M XP in total to reach 100). See docs/XP_TABLE.md.

const MAX_LEVEL := 100
const SKILL_POINTS_PER_LEVEL := 2
## Extra skill point every N levels.
const BONUS_POINT_EVERY := 5

## XP sources (for statistics, balancing and the XP log).
enum Source { COMBAT, BOSS, DUNGEON, EXPLORATION, DISCOVERY, HARVEST, CRAFTING, FARMING, TRADING, QUEST, OTHER }

const SOURCE_NAMES := ["Combat", "Boss", "Dungeon", "Exploration", "Discovery", "Harvest",
	"Crafting", "Farming", "Trading", "Quest", "Other"]

## Level at which equipment tiers become wearable (ItemData.required_level uses these).
const GEAR_TIER_LEVELS := {1: "Basic gear", 10: "Common gear", 20: "Uncommon gear",
	35: "Rare gear", 55: "Very Rare gear", 75: "Magical gear", 90: "Legendary gear"}


static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var n := float(level - 1)
	var xp := 100.0 + 40.0 * pow(n, 1.5) + 0.35 * n * n * n
	return int(roundf(xp / 10.0) * 10.0)


## Total XP needed to reach `level` from level 1.
static func total_xp_for(level: int) -> int:
	var total := 0
	for l in range(1, clampi(level, 1, MAX_LEVEL)):
		total += xp_to_next(l)
	return total


static func skill_points_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return SKILL_POINTS_PER_LEVEL + (1 if level % BONUS_POINT_EVERY == 0 else 0)


static func total_skill_points_at(level: int) -> int:
	var total := 0
	for l in range(2, level + 1):
		total += skill_points_for_level(l)
	return total


## XP for killing an enemy of `enemy_level` at `player_level`: full value near
## your level, up to +50% for stronger foes, down to 10% for trivial ones.
static func combat_xp(base_xp: int, enemy_level: int, player_level: int) -> int:
	var diff := enemy_level - player_level
	var mult := 1.0
	if diff > 0:
		mult = minf(1.0 + 0.1 * diff, 1.5)
	elif diff < -3:
		mult = maxf(1.0 + 0.12 * (diff + 3), 0.1)
	return maxi(1, roundi(base_xp * mult))
