class_name LootTables
## Loot for chests, vaults, lecterns and bosses (Milestone 6).
## Entries: [item_id, min, max, chance, min_rank]. Rank 0..5 = E..S.
## Coins go straight into the player's purse.

const SCROLLS := [&"scroll_sunforged_blade", &"scroll_staff_of_the_archmage", &"scroll_shadowfang",
	&"scroll_titans_greataxe", &"scroll_aegis_of_dawn", &"scroll_mithril_plate", &"scroll_crown_of_stars"]
## Spell tomes (Milestone 7), roughly by power: a "tome" chance rolls one of these.
const TOMES := [&"tome_blink", &"tome_healing_light", &"tome_poison_cloud", &"tome_arcane_barrier",
	&"tome_arcane_missiles", &"tome_blizzard", &"tome_meteor", &"tome_storm_call"]
## Gear by rank band (a random piece is rolled when a table says "gear").
const GEAR := [
	[&"copper_sword", &"copper_dagger", &"leather_gloves", &"fur_cap", &"wooden_buckler", &"copper_ring"],
	[&"iron_sword", &"iron_waraxe", &"chainmail", &"iron_kite_shield", &"fur_boots", &"leather_jerkin"],
	[&"crystal_staff", &"shadow_cloak", &"crystal_ring", &"tusk_charm", &"copper_pickaxe"],
	[&"moonpetal_pendant", &"mithril_pickaxe", &"mithril_hatchet", &"crystal_ring", &"shadow_cloak"],
]
const TABLES := {
	&"ruin_chest": {"coins": 15, "gear": 0.15, "items": [
		[&"ancient_bone", 1, 3, 0.5, 0], [&"iron_ore", 1, 3, 0.4, 0], [&"copper_ingot", 1, 2, 0.4, 0],
		[&"healing_draught", 1, 1, 0.3, 0], [&"leather", 1, 3, 0.3, 0], [&"smithing_manual", 1, 1, 0.08, 0],
		[&"leatherworker_notes", 1, 1, 0.08, 0], [&"crystal_shard", 1, 1, 0.2, 1], [&"mithril_ore", 1, 2, 0.25, 2]]},
	&"vault": {"coins": 45, "gear": 0.6, "scroll": [0.0, 0.0, 0.0, 0.05, 0.15, 0.25], "items": [
		[&"iron_ingot", 2, 4, 0.6, 0], [&"healing_draught", 1, 2, 0.5, 0], [&"mithril_ingot", 1, 2, 0.35, 2],
		[&"crystal_shard", 1, 2, 0.4, 1], [&"void_shard", 1, 1, 0.1, 4]]},
	&"tower": {"coins": 25, "gear": 0.2, "tome": [0.2, 0.25, 0.3, 0.35, 0.4, 0.45], "items": [
		[&"arcane_dust", 2, 4, 0.8, 0], [&"wisp_essence", 1, 2, 0.5, 0], [&"crystal_shard", 1, 2, 0.4, 0],
		[&"mana_tonic", 1, 2, 0.5, 0], [&"arcane_codex", 1, 1, 0.12, 1], [&"void_shard", 1, 1, 0.1, 4]]},
	&"temple": {"coins": 80, "gear": 0.6, "scroll_guaranteed": true, "items": [
		[&"sunstone", 1, 2, 1.0, 0], [&"elixir_of_might", 1, 1, 0.4, 0], [&"stoneskin_elixir", 1, 1, 0.4, 0],
		[&"healing_draught", 2, 3, 0.8, 0], [&"mithril_ingot", 1, 3, 0.5, 2]]},
	&"dungeon_chest": {"coins": 30, "gear": 0.25, "items": [
		[&"healing_draught", 1, 2, 0.5, 0], [&"mana_tonic", 1, 1, 0.3, 0], [&"iron_ore", 2, 4, 0.4, 0],
		[&"coal", 2, 4, 0.4, 0], [&"crystal_shard", 1, 2, 0.3, 1], [&"mithril_ore", 1, 3, 0.4, 2],
		[&"elixir_of_might", 1, 1, 0.15, 2], [&"void_shard", 1, 1, 0.1, 4]]},
	&"dungeon_boss": {"coins": 150, "gear": 1.0, "scroll": [0.0, 0.0, 0.02, 0.08, 0.35, 0.6], "tome": [0.15, 0.2, 0.25, 0.3, 0.4, 0.5], "items": [
		[&"healing_draught", 2, 3, 0.8, 0], [&"mithril_ingot", 2, 4, 0.6, 2], [&"elixir_of_starlight", 1, 1, 0.3, 3],
		[&"stoneskin_elixir", 1, 1, 0.4, 1], [&"elixir_of_might", 1, 1, 0.4, 1]]},
	&"secret": {"coins": 60, "gear": 0.6, "scroll": [0.0, 0.0, 0.0, 0.1, 0.15, 0.2], "tome": [0.25, 0.25, 0.3, 0.3, 0.35, 0.4], "items": [
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
