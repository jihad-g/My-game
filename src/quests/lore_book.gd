class_name LoreBook
extends RefCounted
## The history of the Shardlands (Milestone 16). Pages are found in chests at
## ruins, towers, temples and caches (one unread page now and then), boss pages
## the first time you face a boss, and every kingdom's ruler tells its history.
## Everything you have read is kept in the journal (O).

## id -> [title, text]. Order = reading order in the journal.
const PAGES := {
	&"shattering": ["The Shattering",
		"Long ago a great crystal fell from the stars and broke over this land. Its pieces - the shards - " +
		"scattered across the world. Where they fell, magic woke up: crystals grew, wisps began to glow and " +
		"strange beasts were born. That is why we call this place the Shardlands. Stars still fall, " +
		"and the people say the sky is still looking for what it lost."],
	&"ancients": ["The Ancients",
		"Before the kingdoms there were the Ancients. They learned to hold the shards without going mad, and " +
		"they built the temples on the high places to keep the shards safe. They made stone guardians that " +
		"never sleep. The Ancients are gone, but their guardians still follow the old orders."],
	&"guardians": ["The Temple Guardians",
		"A guardian does not hate you. It was told to keep the altar safe, and it will keep it safe until " +
		"someone proves stronger. Those who defeat a guardian and cleanse the temple may kneel at the altar " +
		"and receive the Blessing of the Ancients."],
	&"towers": ["The Tower Order",
		"The wizards of the towers study the shards. Each tower has a warden who keeps the books and the " +
		"secrets. Young wizards learn their first spells here; the order says magic is a tool, not a crown."],
	&"great_shards": ["The Great Shards",
		"Most shards are small - a fragment you can hold in your hand. But three pieces were as big as a " +
		"house, and each one changed whoever found it. The scholars call them the Great Shards. One fell into " +
		"a royal crypt, one into an arcane sanctum, and one into a grotto full of thorns."],
	&"bone_king": ["The Bone King",
		"King Aldric was afraid of death. When a Great Shard fell into his crypt, he pressed it into his own " +
		"chest. He did not die - but he did not stay alive either. Now he sits on a throne of bones, " +
		"and his dead knights still guard him."],
	&"arcane_colossus": ["The Arcane Colossus",
		"The tower order built a giant of stone and brass to carry a Great Shard to safety. The shard's light " +
		"filled the machine, and it forgot every order but one: let no one take the shard. It still walks " +
		"the halls of the sanctum, burning anyone who comes close."],
	&"elder_thornmaw": ["The Elder Thornmaw",
		"In the deepest grotto a Great Shard sank into the roots of the old thorn trees. A crawler ate the " +
		"roots, and it grew, and grew. The grotto cultists now feed it and call it their god. Its bite carries " +
		"the poison of a thousand thorns."],
	&"starborn": ["The Starborn",
		"Some falling stars are not rocks. Some carry a sleeping giant made of star metal. The Starborn wake " +
		"when they feel a shard nearby - and they always try to bring it back to the sky."],
	&"bandits": ["The Brotherhood",
		"The bandit brotherhood started as farmers who lost everything in the Shattering's long winter. " +
		"Today they are led by warlords like Grimtusk, who want the shards to rule the land by fear."],
	&"tundra_clans": ["The Tundra Clans",
		"After the Shattering came a winter that lasted ten years. The northern clans survived it in tents of " +
		"fur, fighting wolves for every meal. Their children still learn to swing an axe before they can read."],
	&"kingdoms": ["The First Kingdoms",
		"When the winter ended, people came out of the caves and built villages. The strongest villages " +
		"became kingdoms, and their rulers swore knights to protect the roads. Every kingdom keeps its own " +
		"banner and its own old rival."],
}

## Pages that can be found in chests (bosses' pages come from facing them).
const FINDABLE := [&"ancients", &"guardians", &"towers", &"great_shards", &"starborn", &"bandits", &"tundra_clans", &"kingdoms"]
## Boss enemy id -> page read the first time you face it.
const BOSS_PAGES := {&"bone_king": &"bone_king", &"arcane_colossus": &"arcane_colossus", &"elder_thornmaw": &"elder_thornmaw",
	&"starborn_colossus": &"starborn", &"bandit_warlord": &"bandits", &"temple_guardian": &"guardians", &"tower_warden": &"towers"}

const FOUNDERS := ["Queen Maren", "King Osric", "Queen Ysolde", "King Bran", "Queen Liora", "King Taddeus", "Lady Corvina", "Lord Hale"]
const SYMBOLS := ["a silver stag", "a burning star", "two crossed axes", "a white tower", "a crowned wolf", "a golden wheat sheaf", "a blue wave", "an iron key"]
const DEEDS := ["drove the bandits out of the valley", "found a shard and gave it to the temple", "built the first stone wall",
	"survived the long winter with only a hundred people", "made peace with the tundra clans", "killed a frost wolf with bare hands"]


static func title_of(id: StringName) -> String:
	return String(PAGES[id][0]) if PAGES.has(id) else String(id).capitalize()


static func text_of(id: StringName) -> String:
	return String(PAGES[id][1]) if PAGES.has(id) else ""


## A kingdom's history (4f): founder, banner and an old rival, from the seed.
static func kingdom_history(kingdom_name: String, seed: int, rival_name: String) -> String:
	var h: int = abs(seed)
	return "The Kingdom of %s was founded by %s, who %s. Our banner shows %s. For a hundred years we have been rivals of %s - %s." % [
		kingdom_name, FOUNDERS[h % FOUNDERS.size()], DEEDS[(h / 7) % DEEDS.size()], SYMBOLS[(h / 13) % SYMBOLS.size()],
		rival_name, ["they say our founder stole their crown", "we fought over the same river for years",
			"their king once broke a promise to ours", "both of us claim the same old temple"][(h / 17) % 4]]
