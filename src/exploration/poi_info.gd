class_name PoiInfo
extends SettlementInfo
## A point of interest (Milestone 6): ruins, wizard tower, temple, dungeon
## entrance or hidden grove. Shares the flattening fields with SettlementInfo.

enum Kind { RUINS, TOWER, TEMPLE, DUNGEON, GROVE }
const KIND_NAMES := ["Ruins", "Wizard Tower", "Temple", "Dungeon", "Hidden Grove"]
const RANKS := ["E", "D", "C", "B", "A", "S"]
enum DungeonTheme { CRYPT, ARCANE, GROTTO }
const THEME_NAMES := ["Crypt", "Arcane Sanctum", "Thornwild Grotto"]

var kind: int = Kind.RUINS
## 0 (E) .. 5 (S): difficulty and loot quality.
var rank: int = 0
var theme: int = DungeonTheme.CRYPT
## Groves are not flattened (they keep the natural ground).
var flatten := true


func rank_letter() -> String:
	return RANKS[rank]


func is_hidden() -> bool:
	return kind == Kind.GROVE


func title() -> String:
	match kind:
		Kind.DUNGEON:
			return "%s of %s (Rank %s)" % [THEME_NAMES[theme], name, rank_letter()]
		Kind.GROVE:
			return "Hidden Grove of %s" % name
		Kind.TOWER:
			return "%s's Tower" % name
		Kind.TEMPLE:
			return "Temple of %s" % name
	return "Ruins of %s" % name


func short_title() -> String:
	return title()
