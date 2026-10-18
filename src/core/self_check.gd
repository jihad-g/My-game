class_name SelfCheck
extends RefCounted
## Creative mode's "Check the game" button (Milestone 24): scans the game's
## data for broken links - an item that names a missing recipe, a monster
## that drops an item that doesn't exist, a loot table with a typo, a gear set
## piece with no look - and reports them in plain words.
##
## It only reads data, never changes the world, so it is safe to run any time.
## The report is also written to user://logs/self_check.txt.

const REPORT_PATH := "user://logs/self_check.txt"
const ENEMY_DIR := "res://data/enemies/"

var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var counts: Dictionary = {}


## Runs every check. Returns self (errors, warnings, counts).
static func run() -> SelfCheck:
	var c := SelfCheck.new()
	c._items()
	c._recipes()
	c._monsters()
	c._spawns()
	c._loot()
	c._sets()
	c._spells()
	return c


func ok() -> bool:
	return errors.is_empty()


func _err(text: String) -> void:
	errors.append(text)


func _warn(text: String) -> void:
	warnings.append(text)


func _item_ok(id: StringName) -> bool:
	return ItemDB.has_item(id)


func _items() -> void:
	var looks := {}
	for l in HumanoidModel.OUTFIT_LOOKS:
		looks[StringName(l)] = true
	var n := 0
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it == null:
			_err("Item %s can't be loaded" % id)
			continue
		if "@" in String(id):
			continue  # Fine / Masterwork variants are made from their base item
		n += 1
		if it.display_name.strip_edges() == "":
			_err("Item %s has no name" % id)
		if it.outfit_look != &"" and not looks.has(it.outfit_look):
			_err("Item %s uses the look '%s', which the character model doesn't know" % [id, it.outfit_look])
		if it.set_id != &"" and not GearSets.has_set(it.set_id):
			_err("Item %s belongs to the set '%s', which doesn't exist" % [id, it.set_id])
		for r in it.teaches_recipes:
			if RecipeBook.get_recipe(StringName(r)) == null:
				_err("Book %s teaches the recipe '%s', which doesn't exist" % [id, r])
		if it.teaches_spell != &"" and SpellBook.get_spell(it.teaches_spell) == null:
			_err("Tome %s teaches the spell '%s', which doesn't exist" % [id, it.teaches_spell])
		for stat in it.stat_bonuses:
			if not ItemData.STAT_NAMES.has(stat):
				_warn("Item %s has the stat '%s' with no display name" % [id, stat])
		if it.is_equippable() and it.equip_slot == ItemData.EquipSlot.MAIN_HAND and it.weapon_type == &"" and it.tool_kind == &"":
			_warn("Main-hand item %s has no weapon type" % id)
	counts["items"] = n


func _recipes() -> void:
	var all := RecipeBook.all()
	for r: RecipeData in all.values():
		if not _item_ok(r.result_item):
			_err("Recipe %s makes '%s', which doesn't exist" % [r.id, r.result_item])
		if r.result_count < 1:
			_err("Recipe %s makes %d items" % [r.id, r.result_count])
		for ing in r.ingredients:
			if not _item_ok(StringName(ing)):
				_err("Recipe %s needs '%s', which doesn't exist" % [r.id, ing])
			elif int(r.ingredients[ing]) < 1:
				_err("Recipe %s needs %d of %s" % [r.id, int(r.ingredients[ing]), ing])
		if r.source == RecipeData.Source.DISCOVERY and not _item_ok(r.discovered_by):
			_err("Recipe %s is found through '%s', which doesn't exist" % [r.id, r.discovered_by])
	# Every BOOK recipe should be taught by some book, or nobody can learn it.
	var taught := {}
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it:
			for r in it.teaches_recipes:
				taught[StringName(r)] = true
	for r: RecipeData in all.values():
		if r.source == RecipeData.Source.BOOK and not taught.has(r.id):
			_warn("Recipe %s is a book recipe, but no book teaches it" % r.id)
	counts["recipes"] = all.size()


## Milestone 33: monsters that other systems place (POI guards, dungeon bosses and
## specials, raids, rare events). With WildSpawns and the dungeon themes this is
## where every monster appears; a monster in none of them is never met.
const PLACED_MONSTERS := [&"arcane_colossus", &"bone_king", &"elder_thornmaw", &"starborn_colossus", &"temple_guardian",
	&"tower_warden", &"treasure_goblin", &"bandit_bomber", &"bandit_brute", &"bandit_hexer", &"bandit_warlord",
	&"tusker_chief", &"bone_dragon", &"door_mimic", &"grotto_cultist", &"skeleton_archer", &"skeleton_warrior"]


## Every monster id that appears somewhere in the world.
static func monster_sources() -> Dictionary:
	var out := {}
	for biome in WildSpawns.TABLE:
		for e in WildSpawns.TABLE[biome]:
			out[e[0]] = "wild:%s" % biome
	for theme in PoiLayout.THEME_MONSTERS:
		for id in theme:
			out[id] = "dungeon"
	for id in PoiLayout.THEME_EXTRAS:
		out[id] = "dungeon"
	for id in PLACED_MONSTERS:
		out[id] = out.get(id, "placed")
	return out


## Every monster file: loads, has attacks, drops real items, summons real monsters.
func _monsters() -> void:
	var sources := monster_sources()
	var n := 0
	for file in ResourceLoader.list_directory(ENEMY_DIR):
		if not file.ends_with(".tres"):
			continue
		var d := load(ENEMY_DIR + file) as EnemyData
		if d == null:
			_err("Monster file %s can't be loaded" % file)
			continue
		n += 1
		if String(d.id) != file.get_basename():
			_warn("Monster file %s has the id '%s'" % [file, d.id])
		if d.max_health <= 0.0:
			_err("Monster %s has no health" % d.id)
		for e in d.loot:
			var le := e as LootEntry
			if le == null:
				_err("Monster %s has an empty loot entry" % d.id)
			elif not _item_ok(le.item_id) and le.item_id != Enemy.COIN_DROP:
				_err("Monster %s drops '%s', which doesn't exist" % [d.id, le.item_id])
		var md := d as MonsterData
		if md == null:
			continue
		var peaceful := md.timid
		if md.melee == null and md.style != MonsterData.Style.RANGED and not peaceful and d.attacks.is_empty():
			_warn("Monster %s has no melee attack" % d.id)
		if md.style == MonsterData.Style.BOSS and md.boss_title == "":
			_warn("Boss %s has no title" % d.id)
		# Milestone 33: a body to show and a place to meet it.
		if not (md.look in MonsterModel.BEASTS or md.look in MonsterModel.HUMANOID_LOOKS):
			_err("Monster %s has the look '%s', which has no model" % [d.id, md.look])
		if not sources.has(d.id):
			_warn("Monster %s never appears in the world (no spawn rule, dungeon or POI)" % d.id)
	counts["monsters"] = n


func _enemy_exists(id: StringName) -> bool:
	return ResourceLoader.exists("%s%s.tres" % [ENEMY_DIR, id])


func _spawns() -> void:
	for biome in WildSpawns.TABLE:
		for rule: Array in WildSpawns.TABLE[biome]:
			if not _enemy_exists(rule[0]):
				_err("Biome %s spawns '%s', which doesn't exist" % [biome, rule[0]])
	for pool in [RaidManager.BANDITS, RaidManager.TUSKERS, RaidManager.UNDEAD]:
		for id: StringName in pool:
			if not _enemy_exists(id):
				_err("Raids use '%s', which doesn't exist" % id)


func _loot() -> void:
	for t in LootTables.TABLES:
		var tbl: Dictionary = LootTables.TABLES[t]
		for e: Array in tbl.get("items", []):
			if not _item_ok(e[0]):
				_err("Loot table %s gives '%s', which doesn't exist" % [t, e[0]])
	for band: Array in LootTables.GEAR:
		for id: StringName in band:
			if not _item_ok(id):
				_err("Dungeon gear list has '%s', which doesn't exist" % id)
	for list in [LootTables.SCROLLS, LootTables.TOMES]:
		for id: StringName in list:
			if not _item_ok(id):
				_err("Loot list has '%s', which doesn't exist" % id)
	counts["loot_tables"] = LootTables.TABLES.size()


## Each set has as many pieces as it says, and each piece has a look.
func _sets() -> void:
	var pieces := {}
	for id in ItemDB.all_ids():
		if "@" in String(id):
			continue
		var it: ItemData = ItemDB.get_item(id)
		if it and it.set_id != &"":
			pieces[it.set_id] = int(pieces.get(it.set_id, 0)) + 1
	for s in GearSets.SETS:
		var have := int(pieces.get(s, 0))
		if have == 0:
			_err("Gear set %s has no pieces" % s)
		elif have < GearSets.full_size(s):
			_warn("Gear set %s has %d of %d pieces" % [s, have, GearSets.full_size(s)])
	counts["sets"] = GearSets.SETS.size()


func _spells() -> void:
	counts["spells"] = SpellBook.all().size()
	var abilities := 0
	for c: ClassData in ClassRegistry.all():
		abilities += AbilityBook.for_class(c.id).size()
	counts["abilities"] = abilities
	if counts["spells"] == 0:
		_err("No spells were loaded")


## A short report: the counts, then each problem.
func report() -> String:
	var lines := PackedStringArray()
	var head := "Checked %d items, %d recipes, %d monsters, %d loot tables, %d gear sets, %d spells, %d class abilities." % [
		counts.get("items", 0), counts.get("recipes", 0), counts.get("monsters", 0), counts.get("loot_tables", 0),
		counts.get("sets", 0), counts.get("spells", 0), counts.get("abilities", 0)]
	lines.append(head)
	if errors.is_empty() and warnings.is_empty():
		lines.append("No problems found.")
	for e in errors:
		lines.append("ERROR: " + e)
	for w in warnings:
		lines.append("Note: " + w)
	return "\n".join(lines)


func save_report() -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_PATH.get_base_dir())
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string("Shardlands v%s self check, %s\n\n%s\n" % [ProjectSettings.get_setting("application/config/version", "0"),
		Time.get_datetime_string_from_system(), report()])
	return ProjectSettings.globalize_path(REPORT_PATH)


## The last `n` error and warning lines of this session's log file.
static func log_problems(n: int = 30) -> PackedStringArray:
	var out := PackedStringArray()
	var path := String(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	if not FileAccess.file_exists(path):
		return out
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("ERROR") or l.begins_with("SCRIPT ERROR") or l.begins_with("WARNING") or l.begins_with("USER ERROR") \
				or l.begins_with("USER WARNING"):
			out.append(l)
	if out.size() > n:
		out = out.slice(out.size() - n)
	return out
