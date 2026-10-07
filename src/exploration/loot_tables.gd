class_name LootTables
## Loot for chests, vaults, lecterns and bosses (Milestone 6).
## Entries: [item_id, min, max, chance, min_rank]. Rank 0..5 = E..S.
## Coins go straight into the player's purse.

const SCROLLS := [&"scroll_sunforged_blade", &"scroll_staff_of_the_archmage", &"scroll_shadowfang",
	&"scroll_titans_greataxe", &"scroll_aegis_of_dawn", &"scroll_mithril_plate", &"scroll_crown_of_stars"]
## Spell tomes (Milestone 7), roughly by power: a "tome" chance rolls one of these.
const TOMES := [&"tome_blink", &"tome_healing_light", &"tome_poison_cloud", &"tome_arcane_barrier",
	&"tome_arcane_missiles", &"tome_blizzard", &"tome_meteor", &"tome_storm_call",
	# Milestone 17c shared spells (the rest come from their own places, see TABLES).
	&"tome_gust", &"tome_stone_skin", &"tome_earth_spike", &"tome_spark_shield", &"tome_fire_ring", &"tome_silence"]
## Gear by rank band (a random piece is rolled when a table says "gear").
const GEAR := [
	[&"copper_sword", &"copper_dagger", &"leather_gloves", &"fur_cap", &"wooden_buckler", &"copper_ring",
		&"squire_greaves", &"raider_bracers", &"shadow_wraps", &"apprentice_shoes",
		&"wooden_shortbow", &"ash_spear", &"stone_maul", &"copper_staff", &"apprentice_wand", &"copper_waraxe"],
	[&"iron_sword", &"iron_dirk", &"iron_waraxe", &"chainmail", &"iron_kite_shield", &"fur_boots", &"leather_jerkin",
		&"recurve_bow", &"iron_pike", &"iron_warhammer", &"iron_greatsword", &"iron_staff"],
	[&"crystal_staff", &"shadow_cloak", &"crystal_ring", &"tusk_charm", &"copper_pickaxe", &"mithril_dirk",
		&"embers_tome", &"mithril_staff"],
	[&"moonpetal_pendant", &"mithril_sword", &"mithril_waraxe", &"mithril_dirk", &"crystal_ring", &"shadow_cloak",
		&"mithril_longbow", &"mithril_halberd", &"frostbite_warhammer", &"stormcaller_wand"],
]
const TABLES := {
	# Milestone 15: wild treasure spots (TreasureSpots).
	&"wild_camp": {"coins": 12, "gear": 0.2, "items": [
		[&"tome_frost_path", 1, 1, 0.06, 0], [&"tome_summon_spirit_wolf", 1, 1, 0.04, 1],
		[&"cooked_meat", 1, 3, 0.5, 0], [&"bandage", 1, 2, 0.5, 0], [&"rope", 1, 3, 0.4, 0], [&"leather", 1, 2, 0.3, 0],
		[&"copper_ingot", 1, 2, 0.25, 0], [&"healing_draught", 1, 1, 0.15, 0], [&"iron_ingot", 1, 2, 0.2, 2],
		[&"wooden_arrow", 5, 12, 0.4, 0]]},
	&"shipwreck": {"coins": 35, "gear": 0.35, "items": [
		[&"tome_detect_treasure", 1, 1, 0.15, 0],
		[&"rope", 2, 4, 0.7, 0], [&"plank", 3, 6, 0.7, 0], [&"gold_nugget", 1, 2, 0.35, 0], [&"gemstone", 1, 1, 0.15, 0],
		[&"healing_draught", 1, 1, 0.3, 0], [&"mithril_ore", 1, 2, 0.2, 2]]},
	&"buried_cache": {"coins": 40, "gear": 0.3, "scroll": [0.0, 0.0, 0.0, 0.03, 0.06, 0.1], "items": [
		[&"tome_tame_beast", 1, 1, 0.08, 0], [&"tome_root_snare", 1, 1, 0.1, 0],
		[&"gold_nugget", 1, 3, 0.5, 0], [&"gemstone", 1, 1, 0.25, 0], [&"crystal_shard", 1, 2, 0.3, 1],
		[&"elixir_of_might", 1, 1, 0.1, 1], [&"void_shard", 1, 1, 0.05, 4]]},
	&"ruin_chest": {"coins": 15, "gear": 0.15, "items": [
		[&"tome_stone_skin", 1, 1, 0.06, 0], [&"tome_earth_spike", 1, 1, 0.05, 1],
		[&"ancient_bone", 1, 3, 0.5, 0], [&"iron_ore", 1, 3, 0.4, 0], [&"copper_ingot", 1, 2, 0.4, 0],
		[&"healing_draught", 1, 1, 0.3, 0], [&"leather", 1, 3, 0.3, 0], [&"smithing_manual", 1, 1, 0.08, 0],
		[&"leatherworker_notes", 1, 1, 0.08, 0], [&"weaponsmith_folio", 1, 1, 0.06, 1], [&"copper_arrow", 5, 10, 0.3, 0], [&"crystal_shard", 1, 1, 0.2, 1], [&"mithril_ore", 1, 2, 0.25, 2]]},
	&"vault": {"coins": 45, "gear": 0.6, "scroll": [0.0, 0.0, 0.0, 0.05, 0.15, 0.25], "items": [
		[&"iron_ingot", 2, 4, 0.6, 0], [&"healing_draught", 1, 2, 0.5, 0], [&"mithril_ingot", 1, 2, 0.35, 2],
		[&"crystal_shard", 1, 2, 0.4, 1], [&"void_shard", 1, 1, 0.1, 4], [&"master_weaponsmith_folio", 1, 1, 0.08, 2],
		[&"iron_arrow", 8, 15, 0.3, 1]]},
	&"tower": {"coins": 25, "gear": 0.2, "tome": [0.2, 0.25, 0.3, 0.35, 0.4, 0.45], "items": [
		[&"tome_gust", 1, 1, 0.12, 0], [&"tome_spark_shield", 1, 1, 0.08, 1], [&"tome_feather_fall", 1, 1, 0.08, 0], [&"tome_silence", 1, 1, 0.06, 2],
		[&"arcane_dust", 2, 4, 0.8, 0], [&"wisp_essence", 1, 2, 0.5, 0], [&"crystal_shard", 1, 2, 0.4, 0],
		[&"mana_tonic", 1, 2, 0.5, 0], [&"arcane_codex", 1, 1, 0.12, 1], [&"void_shard", 1, 1, 0.1, 4]]},
	&"temple": {"coins": 80, "gear": 0.6, "scroll_guaranteed": true, "items": [
		[&"tome_rejuvenate", 1, 1, 0.35, 0],
		[&"sunstone", 1, 2, 1.0, 0], [&"elixir_of_might", 1, 1, 0.4, 0], [&"stoneskin_elixir", 1, 1, 0.4, 0],
		[&"healing_draught", 2, 3, 0.8, 0], [&"mithril_ingot", 1, 3, 0.5, 2]]},
	&"dungeon_chest": {"coins": 30, "gear": 0.25, "items": [
		[&"healing_draught", 1, 2, 0.5, 0], [&"mana_tonic", 1, 1, 0.3, 0], [&"iron_ore", 2, 4, 0.4, 0],
		[&"coal", 2, 4, 0.4, 0], [&"crystal_shard", 1, 2, 0.3, 1], [&"iron_arrow", 6, 12, 0.3, 1], [&"fire_arrow", 4, 8, 0.15, 2], [&"mithril_ore", 1, 3, 0.4, 2],
		[&"elixir_of_might", 1, 1, 0.15, 2], [&"void_shard", 1, 1, 0.1, 4]]},
	&"dungeon_boss": {"coins": 150, "gear": 1.0, "scroll": [0.0, 0.0, 0.02, 0.08, 0.35, 0.6], "tome": [0.15, 0.2, 0.25, 0.3, 0.4, 0.5], "items": [
		[&"tome_fire_ring", 1, 1, 0.12, 1], [&"tome_lightning_dash", 1, 1, 0.1, 2], [&"tome_drain_life", 1, 1, 0.1, 2],
		[&"healing_draught", 2, 3, 0.8, 0], [&"mithril_ingot", 2, 4, 0.6, 2], [&"elixir_of_starlight", 1, 1, 0.3, 3],
		[&"stoneskin_elixir", 1, 1, 0.4, 1], [&"elixir_of_might", 1, 1, 0.4, 1],
		[&"master_weaponsmith_folio", 1, 1, 0.12, 2], [&"mithril_arrow", 8, 15, 0.3, 3],
		[&"starfall_bow", 1, 1, 0.04, 5], [&"shardbreaker", 1, 1, 0.04, 5]]},
	&"secret": {"coins": 60, "gear": 0.6, "scroll": [0.0, 0.0, 0.0, 0.1, 0.15, 0.2], "tome": [0.25, 0.25, 0.3, 0.3, 0.35, 0.4], "items": [
		[&"tome_root_snare", 1, 1, 0.12, 0], [&"tome_tame_beast", 1, 1, 0.1, 0],
		[&"elixir_of_might", 1, 1, 0.4, 0], [&"stoneskin_elixir", 1, 1, 0.4, 0], [&"mithril_ingot", 1, 2, 0.5, 2],
		[&"starlight_orchid", 1, 1, 0.2, 3]]},
	# --- Milestone 7 ---
	&"elite": {"coins": 20, "gear": 0.3, "tome": [0.03, 0.04, 0.05, 0.06, 0.08, 0.1], "items": [
		[&"healing_draught", 1, 1, 0.35, 0], [&"bandage", 1, 2, 0.3, 0], [&"antidote", 1, 1, 0.2, 0],
		[&"crystal_shard", 1, 2, 0.25, 1], [&"mithril_ore", 1, 2, 0.3, 2], [&"gold_nugget", 1, 1, 0.15, 2],
		[&"void_shard", 1, 1, 0.08, 4]]},
	&"treasure_goblin": {"coins": 120, "gear": 0.5, "tome": [0.25, 0.25, 0.3, 0.3, 0.35, 0.4], "items": [
		[&"gold_nugget", 1, 3, 1.0, 0], [&"gemstone", 1, 1, 0.5, 0], [&"elixir_of_might", 1, 1, 0.25, 0],
		[&"purifying_draught", 1, 1, 0.3, 0], [&"elixir_of_starlight", 1, 1, 0.1, 2]]},
	&"raid_spoils": {"coins": 40, "gear": 0.35, "tome": [0.04, 0.05, 0.06, 0.08, 0.1, 0.12], "items": [
		[&"bandit_insignia", 1, 3, 0.8, 0], [&"iron_ingot", 1, 3, 0.5, 0], [&"healing_draught", 1, 2, 0.5, 0],
		[&"bandage", 2, 4, 0.5, 0], [&"gold_nugget", 1, 1, 0.2, 1], [&"mithril_ingot", 1, 1, 0.2, 3]]},
	&"meteor": {"coins": 0, "gear": 0.0, "items": [
		[&"star_metal_ore", 2, 4, 1.0, 0], [&"crystal_shard", 1, 2, 0.5, 0], [&"gemstone", 1, 1, 0.15, 0]]},
}


## Rolls a table: {"coins": int, "items": {id: count}}.
static func roll(table: StringName, rank: int, rng: RandomNumberGenerator, first_open: bool = true) -> Dictionary:
	var t: Dictionary = TABLES.get(table, {})
	var out := {"coins": 0, "items": {}}
	if t.is_empty():
		return out
	out.coins = roundi(float(t.coins) * (1.0 + rank * 0.8) * rng.randf_range(0.7, 1.3))
	for e in t.items:
		if rank >= int(e[4]) and rng.randf() < float(e[3]):
			_add(out, e[0], rng.randi_range(int(e[1]), int(e[2])))
	if rng.randf() < float(t.get("gear", 0.0)):
		var band: Array = GEAR[mini(rank, GEAR.size() - 1)]
		_add(out, band[rng.randi() % band.size()], 1)
	var tc: Array = t.get("tome", [])
	if not tc.is_empty() and rng.randf() < float(tc[clampi(rank, 0, 5)]):
		# Low ranks find the simpler tomes; every rank step unlocks one more.
		var top := mini(TOMES.size(), 3 + rank)
		_add(out, TOMES[rng.randi() % top], 1)
	var sc: Array = t.get("scroll", [])
	if (t.get("scroll_guaranteed", false) and first_open) or (not sc.is_empty() and rng.randf() < float(sc[clampi(rank, 0, 5)])):
		_add(out, SCROLLS[rng.randi() % SCROLLS.size()], 1)
	return out


static func _add(out: Dictionary, id: StringName, n: int) -> void:
	if n > 0 and ItemDB.has_item(id):
		out.items[id] = int(out.items.get(id, 0)) + n


## Hands a roll to the player: coins directly, items as pickups at `pos`.
static func give(roll_result: Dictionary, pos: Vector3) -> void:
	var w := World.instance
	if w == null:
		return
	if int(roll_result.coins) > 0:
		w.player.coins += int(roll_result.coins)
		Events.coins_changed.emit(w.player.coins)
		Events.toast.emit("+%s" % Economy.format_coins(int(roll_result.coins)), UITheme.GOLD)
	var k := 0
	for id in roll_result.items:
		var off := Vector3(cos(k * 1.3) * 0.6, 1.0, sin(k * 1.3) * 0.6)
		w.spawn_pickup(id, int(roll_result.items[id]), pos + off)
		k += 1
