class_name WildSpawns
extends RefCounted
## Milestone 18b: packs of 5-10 weak "fodder" enemies (Skeleton Minions, Bandit
## Recruits, Cultist Acolytes) for hack-and-slash fights against crowds.
##
## Milestone 15 ("Living Wilds"): wild creatures for every surface biome, on top
## of the rules stored in the biome resources (the Thornback Boar). Each entry:
## [enemy data id, chance per chunk, group min, group max, salt].
##
## Peaceful animals (deer, rabbits) are timid MonsterData; monsters scale with
## the distance from the world origin like before (EnemySpawner.wild_rank).

const MONSTER_SCENE := "res://scenes/enemies/monster.tscn"

const TABLE := {
	&"verdant_meadow": [
		[&"bandit_recruit", 0.02, 5, 9, 304], [&"deer", 0.05, 1, 2, 301], [&"rabbit", 0.08, 1, 2, 302], [&"bandit_thug", 0.02, 2, 3, 303],
	],
	&"whispering_forest": [
		[&"bandit_recruit", 0.02, 5, 8, 315], [&"deer", 0.06, 1, 3, 311], [&"rabbit", 0.05, 1, 2, 312], [&"thorn_crawler", 0.04, 1, 2, 313],
		[&"bandit_archer", 0.015, 1, 2, 314],
	],
	&"emerald_jungle": [
		[&"cultist_acolyte", 0.025, 5, 9, 324], [&"thorn_crawler", 0.07, 1, 2, 321], [&"grotto_cultist", 0.025, 1, 1, 322], [&"deer", 0.03, 1, 2, 323],
	],
	&"murk_swamp": [
		[&"skeleton_minion", 0.03, 6, 10, 334], [&"thorn_crawler", 0.07, 1, 2, 331], [&"arcane_wisp", 0.04, 1, 2, 332], [&"skeleton_warrior", 0.035, 1, 2, 333],
	],
	&"sandy_beach": [
		[&"bandit_recruit", 0.015, 4, 7, 343], [&"shore_crab", 0.1, 1, 3, 341], [&"bandit_thug", 0.02, 1, 2, 342],
	],
	&"sunscorch_desert": [
		[&"bandit_recruit", 0.02, 5, 9, 354], [&"sand_scorpion", 0.09, 1, 1, 351], [&"bandit_archer", 0.025, 1, 2, 352], [&"bandit_thug", 0.025, 2, 2, 353],
	],
	&"snowy_tundra": [
		[&"frost_wolf", 0.06, 2, 4, 361], [&"rabbit", 0.04, 1, 2, 362],
	],
	&"frostpine_taiga": [
		[&"frost_wolf", 0.045, 2, 3, 371], [&"deer", 0.05, 1, 2, 372], [&"rabbit", 0.03, 1, 1, 373],
	],
	&"stonecrown_mountains": [
		[&"skeleton_minion", 0.025, 6, 10, 384], [&"frost_wolf", 0.035, 2, 3, 381], [&"arcane_sentinel", 0.025, 1, 1, 382], [&"skeleton_archer", 0.03, 1, 2, 383],
	],
	&"crystal_glade": [
		[&"cultist_acolyte", 0.02, 5, 8, 394], [&"arcane_wisp", 0.07, 1, 2, 391], [&"arcane_sentinel", 0.035, 1, 1, 392], [&"rabbit", 0.03, 1, 1, 393],
	],
}

static var _cache: Dictionary = {}  # biome id -> Array[EnemySpawnRule]


## Extra spawn rules for a biome (empty for oceans and caves).
static func rules_for(biome_id: StringName) -> Array:
	if _cache.has(biome_id):
		return _cache[biome_id]
	var out := []
	var scene: PackedScene = load(MONSTER_SCENE)
	for e in TABLE.get(biome_id, []):
		var path := "res://data/enemies/%s.tres" % e[0]
		if not ResourceLoader.exists(path):
			push_warning("WildSpawns: no enemy data %s" % path)
			continue
		var r := EnemySpawnRule.new()
		r.enemy_scene = scene
		r.enemy_data = load(path)
		r.chance_per_chunk = e[1]
		r.group_min = e[2]
		r.group_max = e[3]
		r.salt = e[4]
		r.min_height = TerrainGenerator.SEA_LEVEL + 1
		out.append(r)
	_cache[biome_id] = out
	return out


## Every wild enemy id in the table (tests, docs).
static func all_ids() -> Array:
	var out := []
	for b in TABLE:
		for e in TABLE[b]:
			if not e[0] in out:
				out.append(e[0])
	return out
