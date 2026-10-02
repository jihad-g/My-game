class_name QuestBook
extends RefCounted
## Quest definitions (Milestone 16). A quest is a list of steps; each step has
## a goal the QuestLog checks against game events:
##   talk        - talk to any townsperson (main quest start)
##   collect     - have `count` of `item` (shard fragments)
##   keepers     - defeat every boss in `ids` (any order, any rank)
##   altar       - use an Arcane Altar while carrying the Great Shards
##   kill_meta   - defeat the monster summoned for this quest
##   deliver     - hand `count` of `item` to the quest giver (kingdom errand)
##   kill        - defeat `count` hostile monsters
##   dungeon     - clear a dungeon of rank `rank` or higher
##   return      - talk to the quest giver again
## `hint` tells the tracker where to point (village, poi, dungeon, altar, giver).

const MAIN := &"lost_shards"
const KEEPERS := [&"bone_king", &"arcane_colossus", &"elder_thornmaw"]
## Dungeon theme of each keeper (PoiInfo.DungeonTheme: 0 crypt, 1 sanctum, 2 grotto).
const KEEPER_THEME := {&"bone_king": 0, &"arcane_colossus": 1, &"elder_thornmaw": 2}
## Chests that can hold shard fragments while the main quest asks for them.
const FRAGMENT_TABLES := [&"ruin_chest", &"tower", &"temple", &"vault", &"secret", &"buried_cache"]
const MAIN_TITLE := "Shardbearer"


static func main_quest() -> Dictionary:
	return {
		"id": MAIN,
		"title": "The Lost Shards",
		"giver": "",
		"summary": "Stars still fall over the Shardlands. Find out why - and what the shards want.",
		"steps": [
			{"goal": "talk", "hint": "village", "text": "Ask the people of a village about the falling stars"},
			{"goal": "collect", "item": &"shard_fragment", "count": 3, "hint": "poi",
				"text": "Recover Shard Fragments from the chests of ruins, towers and temples"},
			{"goal": "keepers", "ids": KEEPERS, "hint": "dungeon",
				"text": "Defeat the three Shard Keepers in their dungeons and take the Great Shards"},
			{"goal": "altar", "hint": "altar", "text": "Join the Great Shards on an Arcane Altar (build one with B)"},
			{"goal": "kill_meta", "meta": &"quest_starborn", "hint": "boss", "text": "Defeat the Starborn Colossus"},
		],
		"rewards": {"xp": 4000, "coins": 2500, "items": {&"shardheart_amulet": 1}, "title": MAIN_TITLE},
	}


const ERRAND_ITEMS := [[&"iron_ingot", 5], [&"leather", 6], [&"plank", 20], [&"cooked_meat", 8], [&"rope", 10], [&"copper_ingot", 8]]


## A kingdom's royal errand (11c): three tasks for its ruler, ending in a
## knighthood. Generated from the kingdom so every ruler asks for different things.
static func kingdom_quest(info: SettlementInfo) -> Dictionary:
	var h: int = abs(info.seed)
	var want: Array = ERRAND_ITEMS[h % ERRAND_ITEMS.size()]
	var item: ItemData = ItemDB.get_item(want[0])
	var kills := 6 + (h / 5) % 5
	var rank := (h / 11) % 2  # E or D
	return {
		"id": StringName("kingdom:%s" % info.kingdom_id),
		"title": "A Royal Errand for %s" % info.kingdom_name,
		"giver": info.kingdom_id,
		"summary": "The ruler of %s wants to know if you can be trusted with the realm's safety." % info.kingdom_name,
		"steps": [
			{"goal": "deliver", "item": want[0], "count": want[1], "hint": "giver",
				"text": "Bring %d %s to the ruler of %s" % [want[1], item.display_name if item else String(want[0]), info.kingdom_name]},
			{"goal": "kill", "count": kills, "hint": "", "text": "Make the roads safe: defeat %d monsters in the wild" % kills},
			{"goal": "dungeon", "rank": rank, "hint": "dungeon",
				"text": "Clear a dungeon of rank %s or higher" % PoiInfo.RANKS[rank]},
			{"goal": "return", "hint": "giver", "text": "Return to the ruler of %s" % info.kingdom_name},
		],
		"rewards": {"xp": 900, "coins": 600, "rep": 20.0, "title_tier": 3},
	}


static func step_count(q: Dictionary) -> int:
	return (q.steps as Array).size()
