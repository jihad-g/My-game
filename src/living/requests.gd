class_name Requests
## Daily requests on a settlement's notice board: deliveries and monster hunts.
## Generated deterministically from (settlement, day); completion is saved by
## SettlementManager. A small stand-in for the full quest system (later phase).

const VILLAGE_POOL := [[&"wood", 20], [&"stone", 15], [&"plant_fiber", 15], [&"boar_hide", 3], [&"raw_meat", 5],
	[&"cooked_meat", 4], [&"copper_ore", 6], [&"coal", 6], [&"rope", 5], [&"plank", 8], [&"berries", 10],
	[&"clay", 6], [&"leather", 3], [&"wheat", 10], [&"carrot", 8], [&"flint", 4]]
const KINGDOM_POOL := [[&"copper_ingot", 4], [&"iron_ingot", 3], [&"leather", 5], [&"plank", 20], [&"bread", 6],
	[&"hearty_stew", 3], [&"iron_ore", 8], [&"crystal_shard", 1], [&"boar_tusk", 3], [&"rope", 10]]
const HUNT_BIOMES := [&"verdant_meadow", &"whispering_forest", &"emerald_jungle", &"frostpine_taiga"]
## Kills within this distance of the settlement count for its hunt request.
const HUNT_RANGE := 400.0
const HUNT_COUNT := 3


static func for_settlement(info: SettlementInfo, day: int) -> Array:
	var out := []
	var pool: Array = KINGDOM_POOL if info.is_kingdom() else VILLAGE_POOL
	var n := 3 if info.is_kingdom() else 2
	var used := {}
	for k in n:
		var idx := HashUtils.hash3(info.seed, day, 40 + k) % pool.size()
		var guard := 0
		while used.has(idx) and guard < pool.size():
			idx = (idx + 1) % pool.size()
			guard += 1
		used[idx] = true
		var e: Array = pool[idx]
		var item: ItemData = ItemDB.get_item(e[0])
		var value := maxf(1.0, item.base_value if item else 1.0) * int(e[1])
		out.append({
			"id": "%s:%d:%d" % [info.id, day, k], "type": "deliver", "item": e[0], "count": int(e[1]),
			"reward": ceili(value * 2.2) + 10,
			"rep": clampf(3.0 + value / 25.0, 3.0, 12.0) * (1.2 if info.is_kingdom() else 1.0),
		})
	if info.biome_id in HUNT_BIOMES and HashUtils.hash3(info.seed, day, 99) % 2 == 0:
		out.append({
			"id": "%s:%d:hunt" % [info.id, day], "type": "hunt", "enemy": &"thornback_boar", "count": HUNT_COUNT,
			"reward": 60, "rep": 8.0,
		})
	return out


static func describe(r: Dictionary, info: SettlementInfo) -> String:
	if r.type == "hunt":
		return "Thornback Boars are raiding the fields: defeat %d within %d m of %s" % [r.count, roundi(HUNT_RANGE), info.name]
	var item: ItemData = ItemDB.get_item(r.item)
	return "Wanted: %d %s" % [r.count, item.display_name if item else String(r.item)]
