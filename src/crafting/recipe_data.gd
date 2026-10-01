class_name RecipeData
extends Resource
## One crafting recipe. Crafting never fails: a low Crafting skill only makes it
## use more materials (Skill.material_cost_mult).

## Where the recipe can be crafted (a nearby station of this id, or by hand).
enum Station { HAND, WORKBENCH, FORGE, TAILORING, ARCANE, CAMPFIRE, ALCHEMY }
const STATION_NAMES := ["By hand", "Workbench", "Forge", "Tailoring Table", "Arcane Altar", "Campfire", "Alchemy Table"]
const STATION_IDS := [&"hand", &"workbench", &"forge", &"tailoring", &"arcane", &"campfire", &"alchemy"]

## How the recipe is learned.
enum Source { STARTING, DISCOVERY, BOOK }

@export var id: StringName
@export var result_item: StringName
@export var result_count: int = 1
## item id -> count (before the Crafting-skill material multiplier)
@export var ingredients: Dictionary = {}
@export var station: Station = Station.HAND
## Recipe tier (ItemData.Rarity). Needs Skill.recipe_tier(crafting) >= tier.
@export var tier: int = 0
@export var source: Source = Source.STARTING
## DISCOVERY: learned the first time you obtain this item.
@export var discovered_by: StringName
## Human-readable hint where to find it ("Smithing Manual - caves").
@export var source_hint: String = ""
## Crafting XP per craft.
@export var xp: int = 4


func station_name() -> String:
	return STATION_NAMES[station]


func station_id() -> StringName:
	return STATION_IDS[station]


## Crafting level that unlocks this tier.
func required_crafting() -> int:
	return [1, 10, 25, 45, 70, 70, 90][clampi(tier, 0, 6)]


## Materials actually consumed at the given Crafting skill (rounded up, min 1).
## A single item is never scaled up: a novice still cooks one raw meat into one
## meal (wasting half a piece is not a thing) - skill saves on bulk materials.
func cost_at(crafting: int) -> Dictionary:
	var out := {}
	var mult := Skill.material_cost_mult(crafting)
	for item in ingredients:
		var n := int(ingredients[item])
		out[item] = 1 if n <= 1 else maxi(1, ceili(n * mult - 0.001))
	return out
