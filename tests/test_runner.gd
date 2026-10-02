extends Node
## Automated test suite: unit tests for core systems + integration tests that
## boot the real main scene and play it with simulated input.
##
## Run headless:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = failures.
## Run only some tests: add `-- --only=test_m14` (tests whose name contains it).

var _passed := 0
var _failed := 0
var _current := ""
var _only := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
	print("\n=== Shardlands test suite ===%s" % (" (only %s)" % _only if _only != "" else ""))
	var t0 := Time.get_ticks_msec()
	# Unit tests
	_run(&"test_hash_determinism")
	_run(&"test_world_to_chunk")
	_run(&"test_terrain_determinism")
	_run(&"test_terrain_statistics")
	_run(&"test_biome_distribution")
	_run(&"test_climate_continuity")
	_run(&"test_caves")
	_run(&"test_chunk_generation")
	_run(&"test_prop_placement_deterministic")
	_run(&"test_data_integrity")
	_run(&"test_inventory")
	_run(&"test_stat_block")
	_run(&"test_game_state")
	await _run_async(&"test_hunger")
	await _run_async(&"test_temperature_never_damages")
	# Integration tests (real main scene)
	await _run_async(&"test_integration")
	await _run_async(&"test_layers_and_swimming")
	await _run_async(&"test_save_load")
	_run(&"test_rpg_data")
	_run(&"test_progression")
	_run(&"test_skill_formulas")
	await _run_async(&"test_character_and_equipment")
	await _run_async(&"test_class_abilities")
	await _run_async(&"test_rpg_save_load")
	_run(&"test_m4_data")
	await _run_async(&"test_crafting_system")
	await _run_async(&"test_building_system")
	await _run_async(&"test_building_save_load")
	_run(&"test_m5_settlements")
	_run(&"test_m5_economy")
	await _run_async(&"test_m5_living")
	await _run_async(&"test_m5_kingdom")
	await _run_async(&"test_m5_save_load")
	_run(&"test_m6_data")
	_run(&"test_m6_pois")
	await _run_async(&"test_m6_combat")
	await _run_async(&"test_m6_pois_ingame")
	await _run_async(&"test_m6_dungeon")
	_run(&"test_m7_data")
	await _run_async(&"test_m7_status")
	await _run_async(&"test_m7_ai_elites")
	await _run_async(&"test_m7_bosses")
	await _run_async(&"test_m7_magic")
	await _run_async(&"test_m7_base_raid")
	await _run_async(&"test_m7_town_raid")
	await _run_async(&"test_m7_events")
	_run(&"test_m8_blueprint_format")
	await _run_async(&"test_m8_construction")
	_run(&"test_m9_world_bounds")
	_run(&"test_m9_world_sampling")
	_run(&"test_m9_far_terrain")
	_run(&"test_m9_region_store")
	await _run_async(&"test_m9_save_regions")
	await _run_async(&"test_m9_streaming")
	_run(&"test_m10_audio")
	_run(&"test_m10_icons")
	_run(&"test_m10_weather_rules")
	_run(&"test_m10_visual_assets")
	_run(&"test_m10_settings")
	await _run_async(&"test_m10_animation")
	await _run_async(&"test_m10_world_polish")
	_run(&"test_m11_protocol")
	await _run_async(&"test_m11_session")
	_run(&"test_m12_balance")
	await _run_async(&"test_m12_gameplay_loop")
	_run(&"test_m12_worldgen_stress")
	await _run_async(&"test_m12_performance")
	_run(&"test_m13_input_rebinding")
	await _run_async(&"test_m13_settings_accessibility")
	await _run_async(&"test_m13_tutorial")
	await _run_async(&"test_m13_save_recovery")
	await _run_async(&"test_m13_crash_handling")
	await _run_async(&"test_m13_platform")
	_run(&"test_m13_release")
	_run(&"test_m14_outfit_data")
	await _run_async(&"test_m14_outfits_ingame")
	_run(&"test_m14_gear_data")
	await _run_async(&"test_m14_gear_in_game")
	await _run_async(&"test_m14_character_creation")
	_run(&"test_m15_data")
	await _run_async(&"test_m15_wilds_ingame")
	print("\n=== %d passed, %d failed (%.1fs) ===" % [_passed, _failed, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(1 if _failed > 0 else 0)


func _run(test: StringName) -> void:
	if _only != "" and not String(test).contains(_only):
		return
	_current = test
	print("\n-- %s" % test)
	call(test)


func _run_async(test: StringName) -> void:
	if _only != "" and not String(test).contains(_only):
		return
	_current = test
	print("\n-- %s" % test)
	await call(test)


func check(cond: bool, msg: String) -> bool:
	if cond:
		_passed += 1
		print("   ok   %s" % msg)
	else:
		_failed += 1
		print("   FAIL %s  [%s]" % [msg, _current])
		push_error("FAIL %s [%s]" % [msg, _current])
	return cond


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _settings() -> WorldGenSettings:
	return load("res://data/worldgen/default_worldgen.tres")


# --- Unit tests ---------------------------------------------------------------------------

func test_hash_determinism() -> void:
	check(HashUtils.hash3(1, 2, 3) == HashUtils.hash3(1, 2, 3), "hash3 is deterministic")
	check(HashUtils.hash3(1, 2, 3) != HashUtils.hash3(3, 2, 1), "hash3 depends on argument order")
	var h := HashUtils.hash3(-5, 99999, 7)
	check(h >= 0 and h <= HashUtils.MASK_31, "hash3 is a non-negative 31-bit int")
	var u := HashUtils.to_unit(h, 4)
	check(u >= 0.0 and u < 1.0, "to_unit in [0,1)")


func test_world_to_chunk() -> void:
	check(TerrainGenerator.world_to_chunk(Vector3(0.1, 0, 0.1)) == Vector2i(0, 0), "origin -> chunk 0,0")
	check(TerrainGenerator.world_to_chunk(Vector3(-0.1, 0, -0.1)) == Vector2i(-1, -1), "negative coords floor correctly")
	check(TerrainGenerator.world_to_chunk(Vector3(16.0, 0, 15.99)) == Vector2i(1, 0), "chunk boundary at 16")
	check(TerrainGenerator.column_to_chunk(-17, 33) == Vector2i(-2, 2), "column_to_chunk negative")
	check(TerrainGenerator.world_to_chunk(Vector3(20000, 0, -20000)) == Vector2i(1250, -1250), "far coordinates (large world)")


func test_terrain_determinism() -> void:
	var a := TerrainGenerator.new(42, _settings())
	var b := TerrainGenerator.new(42, _settings())
	var c := TerrainGenerator.new(43, _settings())
	var same := true
	var differs := 0
	for i in 400:
		var x := (i * 37) % 900 - 450
		var z := (i * 91) % 900 - 450
		if a.get_height_blocks(x, z) != b.get_height_blocks(x, z):
			same = false
		if a.get_height_blocks(x, z) != c.get_height_blocks(x, z):
			differs += 1
	check(same, "same seed -> identical heights")
	check(differs > 100, "different seed -> different terrain (%d/400 differ)" % differs)
	# Far away from origin still works (no world limit).
	var far := a.get_height_blocks(13000, -13000)
	check(far > -100 and far < 200, "terrain generates at +-13km (h=%d)" % far)


func test_terrain_statistics() -> void:
	var g := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var hmin := 99999
	var hmax := -99999
	var water := 0
	var inland_water := 0
	var n := 0
	for z in range(-3000, 3000, 30):
		for x in range(-3000, 3000, 30):
			var smp := g.sample_column(x, z)
			var h := TerrainGenerator.unpack_height(smp)
			var b := g.biomes[TerrainGenerator.unpack_biome(smp)]
			hmin = mini(hmin, h)
			hmax = maxi(hmax, h)
			if h < TerrainGenerator.SEA_LEVEL:
				water += 1
				if b.role == BiomeData.Role.LAND:
					inland_water += 1
			n += 1
	var wf := float(water) / n
	print("   6x6 km: heights %d..%d blocks, water %.1f%%, inland water (rivers/lakes) %.1f%%" % [hmin, hmax, wf * 100.0, inland_water * 100.0 / n])
	check(wf > 0.05 and wf < 0.6, "oceans and lakes exist but most of the world is land")
	check(inland_water > n / 200, "rivers and lakes inside land biomes")
	check(hmax > 70, "tall mountains exist (max %d blocks = %d m)" % [hmax, hmax / 2])
	check(hmin < -10, "deep oceans exist (min %d blocks)" % hmin)
	check(hmax < 200, "no absurd spikes")


func test_biome_distribution() -> void:
	var g := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var counts := {}
	var n := 0
	for z in range(-5000, 5000, 50):
		for x in range(-5000, 5000, 50):
			var b := g.biomes[g.get_biome_index(x, z)]
			counts[b.id] = counts.get(b.id, 0) + 1
			n += 1
	var parts := PackedStringArray()
	for id in counts:
		parts.append("%s %.1f%%" % [id, counts[id] * 100.0 / n])
	print("   10x10 km: " + ", ".join(parts))
	var surface_biomes := 0
	for b in g.biomes:
		if b.role != BiomeData.Role.UNDERGROUND:
			surface_biomes += 1
	check(counts.size() >= surface_biomes - 1, "%d of %d surface biomes appear in 10x10 km" % [counts.size(), surface_biomes])
	var rare := float(counts.get(&"crystal_glade", 0)) / n
	check(rare > 0.0 and rare < 0.06, "magical Crystal Glade is rare (%.2f%%)" % (rare * 100.0))
	var other := TerrainGenerator.new(GameState.DEFAULT_SEED + 1, _settings())
	var differ := 0
	for i in 200:
		if g.get_biome_index(i * 97 - 9000, i * 61 - 6000) != other.get_biome_index(i * 97 - 9000, i * 61 - 6000):
			differ += 1
	check(differ > 40, "a different seed lays out biomes differently (%d/200)" % differ)


func test_climate_continuity() -> void:
	var g := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var max_step := 0.0
	var tmin := 999.0
	var tmax := -999.0
	for i in 3000:
		var p := Vector3(i * 3.0 - 4500.0, 0, i * 1.7 - 2500.0)
		var a := g.get_climate(p).x
		var b := g.get_climate(p + Vector3(1, 0, 0)).x
		max_step = maxf(max_step, absf(a - b))
		tmin = minf(tmin, a)
		tmax = maxf(tmax, a)
	print("   sea-level climate range %.1f..%.1f °C" % [tmin, tmax])
	check(max_step < 0.5, "temperature is continuous across columns (max step %.3f °C)" % max_step)
	check(tmin < 0.0 and tmax > 28.0, "world has both freezing and hot regions")


func test_caves() -> void:
	var g := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var entrances := g.get_cave_entrances_near(-800, -800, 800, 800)
	check(entrances.size() >= 20, "cave entrances are common (%d in 1.6x1.6 km)" % entrances.size())
	var ok := true
	for e in entrances:
		if g.get_height_blocks(e.x, e.y) < TerrainGenerator.SEA_LEVEL + 2:
			ok = false
		if not g.is_cave_open(e.x, e.y, entrances):
			ok = false
	check(ok, "every entrance is on dry land and opens into a cave room below")
	var open := 0
	var total := 0
	for z in range(-400, 400, 4):
		for x in range(-400, 400, 4):
			total += 1
			if g.is_cave_open(x, z, []):
				open += 1
	var frac := float(open) / total
	print("   cave open fraction %.1f%%" % (frac * 100.0))
	check(frac > 0.15 and frac < 0.7, "caves mix tunnels/caverns with solid rock")
	if not entrances.is_empty():
		var e := entrances[0]
		var coord := TerrainGenerator.column_to_chunk(e.x, e.y)
		var top := g.generate_chunk(coord, 0, TerrainGenerator.Layer.SURFACE)
		var below := g.generate_chunk(coord, 0, TerrainGenerator.Layer.UNDERGROUND)
		check(top.features.any(func(f: Dictionary) -> bool: return f.type == &"cave_entrance"), "surface chunk has the cave entrance")
		check(below.features.any(func(f: Dictionary) -> bool: return f.type == &"cave_exit"), "cave chunk has the matching exit")
		check(below.water_vertices.is_empty() and not below.collision_faces.is_empty(), "cave chunk: collision, no water")
		check(below.max_height < TerrainGenerator.CAVE_FLOOR + 10, "cave floor is deep underground")
	var cave_props := 0
	for cz in range(-3, 3):
		for cx in range(-3, 3):
			cave_props += g.generate_chunk(Vector2i(cx, cz), 0, TerrainGenerator.Layer.UNDERGROUND).props.size()
	check(cave_props > 10, "caves contain ores/fungi/stalagmites (%d in 36 chunks)" % cave_props)


func test_chunk_generation() -> void:
	var g := TerrainGenerator.new(7, _settings())
	var t0 := Time.get_ticks_usec()
	var d0 := g.generate_chunk(Vector2i(0, 0), 0)
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("   LOD0 chunk generated in %.2f ms (%d verts, %d props)" % [gen_ms, d0.vertices.size(), d0.props.size()])
	check(d0.vertices.size() > 0, "LOD0 has vertices")
	check(d0.indices.size() % 6 == 0, "indices form whole quads")
	check(d0.vertices.size() == d0.normals.size() and d0.vertices.size() == d0.colors.size(), "attribute arrays match")
	check(d0.collision_faces.size() == d0.indices.size(), "collision matches render triangles")
	var max_index := 0
	for i in d0.indices:
		max_index = maxi(max_index, i)
	check(max_index < d0.vertices.size(), "indices in range")
	var d1 := g.generate_chunk(Vector2i(0, 0), 1)
	var d2 := g.generate_chunk(Vector2i(0, 0), 2)
	check(d1.vertices.size() < d0.vertices.size(), "LOD1 is lighter than LOD0")
	check(d2.vertices.size() < d1.vertices.size(), "LOD2 is lighter than LOD1")
	check(d1.collision_faces.is_empty() and d2.collision_faces.is_empty(), "only LOD0 has collision")
	check(d2.props.is_empty(), "LOD2 has no props")
	# Top faces must face up (winding check): first quad is a top face.
	var a := d0.vertices[d0.indices[0]]
	var b := d0.vertices[d0.indices[1]]
	var c := d0.vertices[d0.indices[2]]
	check((b - a).cross(c - a).dot(Vector3.UP) < 0.0, "top faces use clockwise (front) winding")


func test_prop_placement_deterministic() -> void:
	var g1 := TerrainGenerator.new(99, _settings())
	var g2 := TerrainGenerator.new(99, _settings())
	var total := 0
	var all_same := true
	for cz in range(-2, 3):
		for cx in range(-2, 3):
			var p1 := g1.generate_chunk(Vector2i(cx, cz), 0).props
			var p2 := g2.generate_chunk(Vector2i(cx, cz), 0).props
			total += p1.size()
			if p1.size() != p2.size():
				all_same = false
				continue
			for i in p1.size():
				if p1[i].index != p2[i].index or p1[i].position != p2[i].position:
					all_same = false
	check(all_same, "props identical for same seed")
	check(total > 25, "25 chunks contain props (%d)" % total)
	# LOD1 props are a subset of LOD0 props (same indices/positions).
	var l0 := g1.generate_chunk(Vector2i(1, 1), 0).props
	var l1 := g1.generate_chunk(Vector2i(1, 1), 1).props
	var idx0 := {}
	for p in l0:
		idx0[p.index] = p.position
	var subset := true
	for p in l1:
		if not idx0.has(p.index) or idx0[p.index] != p.position:
			subset = false
	check(subset, "LOD1 props match LOD0 props (no popping)")


func test_data_integrity() -> void:
	check(ItemDB.all_ids().size() >= 21, "ItemDB loaded %d items" % ItemDB.all_ids().size())
	var lib := PropLibrary.new()
	var ok := true
	var rule_count := 0
	var ids := {}
	for biome in _settings().biomes:
		check(not ids.has(biome.id), "biome id %s is unique" % biome.id)
		ids[biome.id] = true
		check(biome.prop_rules.size() < 64, "%s has < 64 prop rules (index scheme)" % biome.id)
		for rule in biome.prop_rules:
			rule_count += 1
			var pd := lib.get_prop(rule.prop_id)
			if pd == null:
				ok = false
				print("   %s: missing prop %s" % [biome.id, rule.prop_id])
				continue
			if lib.get_mesh(rule.prop_id) == null:
				ok = false
			for loot in pd.drops:
				if not ItemDB.has_item(loot.item_id):
					ok = false
					print("   prop %s drops unknown item %s" % [pd.id, loot.item_id])
			if TerrainGenerator.CHUNK_SIZE % rule.cell_size != 0:
				ok = false
				print("   %s: bad cell size for %s" % [biome.id, rule.prop_id])
	check(ok, "all %d prop rules reference existing props with meshes and valid drops" % rule_count)
	var boar: EnemyData = load("res://data/enemies/thornback_boar.tres")
	check(boar.get_attack(ThornbackBoar.BITE_ID) != null and boar.get_attack(ThornbackBoar.CHARGE_ID) != null, "boar attacks defined")
	var loot_ok := true
	for loot in boar.loot:
		loot_ok = loot_ok and ItemDB.has_item(loot.item_id)
	check(loot_ok, "boar loot items exist")
	var kit: ItemData = ItemDB.get_item(&"campfire_kit")
	check(kit != null and kit.is_placeable(), "campfire kit is placeable")


func test_inventory() -> void:
	var inv := Inventory.new(4)
	var left := inv.add_item(&"wood", 150)
	check(left == 0, "150 wood fits in 4 slots")
	check(inv.get_slot(0).count == 99 and inv.get_slot(1).count == 51, "stacks capped at max_stack 99")
	left = inv.add_item(&"stone", 300)
	check(left == 300 - 99 * 2, "overflow returned as leftover (%d)" % left)
	check(inv.count_of(&"wood") == 150, "count_of wood")
	check(inv.remove_item(&"wood", 60), "remove 60 wood")
	check(inv.count_of(&"wood") == 90, "90 wood left")
	check(not inv.remove_item(&"wood", 1000), "can't remove more than owned")
	check(inv.add_item(&"does_not_exist", 5) == 5, "unknown items rejected")
	var inv2 := Inventory.new(3)
	inv2.add_item(&"berries", 20)
	inv2.slots[1] = {"id": &"berries", "count": 15}
	inv2.move_slot(1, 0)
	check(inv2.get_slot(0).count == 30 and inv2.get_slot(1).count == 5, "move_slot merges up to max stack (30)")
	inv2.move_slot(1, 2)
	check(inv2.get_slot(1) == null and inv2.get_slot(2).count == 5, "move_slot into empty slot")
	var data := inv2.to_array()
	var inv3 := Inventory.new(3)
	inv3.from_array(data)
	check(inv3.count_of(&"berries") == 35, "serialization round trip")


func test_stat_block() -> void:
	var s := StatBlock.new()
	check(is_equal_approx(s.get_mult(Stats.MOVE_SPEED), 1.0), "default mult is 1")
	s.set_source(&"a", {Stats.MOVE_SPEED: 0.5})
	s.set_source(&"b", {Stats.MOVE_SPEED: 0.8, Stats.ATTACK_DAMAGE: 1.2})
	check(is_equal_approx(s.get_mult(Stats.MOVE_SPEED), 0.4), "multipliers stack multiplicatively")
	s.set_source(&"a", {})
	check(is_equal_approx(s.get_mult(Stats.MOVE_SPEED), 0.8), "empty set clears source")
	s.free()


func test_game_state() -> void:
	var saved := GameState.to_dict()
	GameState.reset(123)
	GameState.world_time = 100.0
	GameState.mark_prop_removed(Vector2i(-3, 4), 17)
	check(GameState.is_prop_removed(Vector2i(-3, 4), 17, 0.0), "removed prop stays removed")
	check(GameState.is_prop_removed(Vector2i(-3, 4), 17, 50.0), "regrowing prop removed before regrow time")
	var d := GameState.to_dict()
	GameState.reset(1)
	GameState.from_dict(d)
	check(GameState.world_seed == 123 and GameState.is_prop_removed(Vector2i(-3, 4), 17, 0.0), "state serializes round trip")
	GameState.world_time = 200.0
	check(not GameState.is_prop_removed(Vector2i(-3, 4), 17, 50.0), "prop regrows after regrow time")
	GameState.mark_enemy_killed("0,0:0")
	check(not GameState.can_spawn_slot("0,0:0", 60.0), "killed slot blocked")
	GameState.world_time = 300.0
	check(GameState.can_spawn_slot("0,0:0", 60.0), "slot respawns after respawn time")
	GameState.from_dict(saved)


func test_hunger() -> void:
	var root := Node.new()
	var stats := StatBlock.new()
	var health := HealthComponent.new()
	var hunger := HungerComponent.new()
	health.max_health = 100.0
	hunger.stats = stats
	hunger.health = health
	root.add_child(stats)
	root.add_child(health)
	root.add_child(hunger)
	add_child(root)
	await get_tree().process_frame
	root.process_mode = Node.PROCESS_MODE_DISABLED  # drive manually
	check(hunger.state == HungerComponent.State.WELL_FED, "starts well fed (80%)")
	var before := hunger.current
	hunger._process(10.0)
	check(hunger.current < before, "hunger drains over time")
	hunger.activity_multiplier = 2.0
	var b2 := hunger.current
	hunger._process(10.0)
	check(before - b2 < b2 - hunger.current + 0.0001, "sprinting drains faster")
	hunger.activity_multiplier = 1.0
	hunger._set_current(0.0)
	check(hunger.state == HungerComponent.State.STARVING, "0 hunger -> starving")
	check(stats.get_mult(Stats.ATTACK_DAMAGE) < 1.0, "starving weakens attacks")
	var hp := health.current
	for i in 20:
		hunger._process(1.0)
	check(health.current < hp, "starvation damages health")
	hunger.eat(50.0)
	check(hunger.state == HungerComponent.State.SATED, "eating restores state")
	root.queue_free()


func test_temperature_never_damages() -> void:
	var root := Node.new()
	var stats := StatBlock.new()
	var health := HealthComponent.new()
	var temp := TemperatureComponent.new()
	temp.stats = stats
	root.add_child(stats)
	root.add_child(health)
	root.add_child(temp)
	add_child(root)
	await get_tree().process_frame
	root.process_mode = Node.PROCESS_MODE_DISABLED
	var ambient := [-45.0]
	temp.ambient_provider = func() -> float: return ambient[0]
	temp.snap_to_ambient()
	for i in 1200:
		temp._process(1.0)  # 20 minutes of freezing
	check(temp.exposure == TemperatureComponent.Exposure.FREEZING, "extreme cold -> Freezing")
	check(health.current == health.max_health, "freezing never damages health")
	check(stats.get_mult(Stats.MOVE_SPEED) < 1.0 and stats.get_mult(Stats.HEALTH_REGEN) == 0.0, "freezing applies debuffs")
	check(stats.get_mult(Stats.HUNGER_RATE) > 1.0, "cold increases hunger rate")
	# Warmth sources bring you back.
	temp.insulation = 0.0
	ambient[0] = 18.0
	for i in 600:
		temp._process(1.0)
	check(temp.exposure == TemperatureComponent.Exposure.COMFORTABLE, "warming up -> Comfortable")
	check(stats.get_mult(Stats.MOVE_SPEED) == 1.0, "debuffs removed when comfortable")
	ambient[0] = 60.0
	for i in 1200:
		temp._process(1.0)
	check(temp.exposure == TemperatureComponent.Exposure.SCORCHING, "extreme heat -> Scorching")
	check(health.current == health.max_health, "heat never damages health")
	check(stats.get_mult(Stats.STAMINA_COST) > 1.0, "heat makes stamina actions costlier")
	# Buffs / insulation shift the effective temperature.
	ambient[0] = -5.0
	temp.ambient = -5.0
	temp.add_buff(&"stew", 8.0, 60.0)
	check(is_equal_approx(temp.get_effective_ambient(), 3.0), "food buff warms (+8)")
	temp.insulation = 20.0
	check(temp.get_effective_ambient() <= TemperatureComponent.COMFORT_MIN, "insulation caps at comfort band")
	root.queue_free()


# --- Integration --------------------------------------------------------------------------

func test_integration() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world := scene.instantiate() as World
	add_child(world)
	var player := world.player

	# 1. World streaming & spawn
	var waited := 0
	while not world.is_ready and waited < 1200:
		await get_tree().process_frame
		waited += 1
	check(world.is_ready, "world around spawn generated (%d frames)" % waited)
	if not world.is_ready:
		world.queue_free()
		return
	var stats := world.chunk_manager.get_debug_stats()
	print("   chunks: %s" % str(stats))
	check(stats.lod0 >= 25, "LOD0 ring loaded")
	check(world.chunk_manager.is_collision_ready_at(player.global_position), "collision under player")
	await _frames(60)
	check(player.is_on_floor(), "player stands on terrain")
	var ground := world.get_ground_height(player.global_position)
	check(absf(player.global_position.y - ground) < 0.8, "player at ground height (%.2f vs %.2f)" % [player.global_position.y, ground])

	# 2. Movement (simulated input)
	var start := player.global_position
	Input.action_press(&"move_forward")
	await _frames(60)
	Input.action_release(&"move_forward")
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	check(moved > 2.0, "WASD moves the player (%.2f m in 1 s)" % moved)
	Input.action_press(&"move_right")
	Input.action_press(&"sprint")
	var st := player.stamina.current
	await _frames(40)
	Input.action_release(&"move_right")
	Input.action_release(&"sprint")
	check(player.stamina.current < st, "sprinting costs stamina")

	# 3. Eat food
	player.hunger._set_current(40.0)
	var berries_slot := -1
	for i in player.inventory.capacity:
		var s = player.inventory.get_slot(i)
		if s != null and s.id == &"berries":
			berries_slot = i
	check(berries_slot >= 0, "starting berries in inventory")
	player.use_slot(berries_slot)
	check(player.hunger.current > 45.0, "eating berries restores hunger")

	# 4. Combat vs Thornback Boar
	player.health.reset_full()
	await _frames(5)
	var facing := player.get_facing()
	var boar_pos := player.global_position + facing * 1.6
	boar_pos.y = world.get_ground_height(boar_pos) + 0.3
	var boar := world.spawner.spawn_enemy(world.debug_enemy_scene, boar_pos, "") as ThornbackBoar
	check(boar != null, "boar spawned from pool")
	await _frames(10)
	player.set_lock_target(boar)
	var boar_hp := boar.health.current
	player.combat.request(&"light")
	await _frames(40)
	check(boar.health.current < boar_hp, "light attack damages the boar (%.0f -> %.0f)" % [boar_hp, boar.health.current])
	check(boar.target == player, "boar aggroes on the attacker")

	# Enemy damages player (let it fight back while we stand still).
	player.health.reset_full()
	var php := player.health.current
	var waited_hit := 0
	while player.health.current >= php and waited_hit < 600:
		await get_tree().physics_frame
		waited_hit += 1
	check(player.health.current < php, "boar damages the player (%d frames)" % waited_hit)

	# Dodge i-frames, block, parry (direct hit resolution)
	player.health.reset_full()
	player.state = Player.State.NORMAL
	var info := DamageInfo.create(20.0, boar)
	info.direction = -player.get_facing()
	player.health.invulnerable = true
	player.receive_hit(info)
	check(player.health.current == player.health.max_health, "i-frames ignore damage")
	player.health.invulnerable = false
	player.is_blocking = true
	player._block_time = 1.0
	player.stamina.refill()
	info = DamageInfo.create(20.0, boar)
	info.direction = -player.get_facing()
	player.receive_hit(info)
	var blocked_dmg := player.health.max_health - player.health.current
	check(blocked_dmg > 0.0 and blocked_dmg < 10.0, "frontal block reduces damage (took %.1f of 20)" % blocked_dmg)
	player.health.reset_full()
	player._block_time = 0.05
	info = DamageInfo.create(20.0, boar)
	info.direction = -player.get_facing()
	player.receive_hit(info)
	check(player.health.current == player.health.max_health, "perfect parry negates damage")
	check(boar.exposed, "parried boar is exposed")
	player.is_blocking = false

	# Kill the boar with attacks -> loot
	player.health.invulnerable = true  # keep the test deterministic
	var frames := 0
	while not boar.is_dead and frames < 1800:
		if boar.global_position.distance_to(player.global_position) > 1.8:
			var to := boar.global_position - player.global_position
			to.y = 0
			player.global_position = boar.global_position - to.normalized() * 1.5
		player.set_lock_target(boar)
		player.combat.request(&"light")
		await get_tree().physics_frame
		frames += 1
	check(boar.is_dead, "boar killed with melee combo (%d frames)" % frames)
	await _frames(20)
	check(world.pickup_pool.active_count() > 0, "boar dropped loot pickups")
	await _frames(120)
	check(player.inventory.count_of(&"raw_meat") > 0, "loot auto-collected into inventory")
	await _frames(160)
	check(not boar.visible, "dead boar returned to pool")
	player.health.invulnerable = false

	# 5. Harvest a tree (persistent world modification)
	var tree_body: PropBody = null
	var tree_chunk: Chunk = null
	for coord in world.chunk_manager._chunks:
		var ch: Chunk = world.chunk_manager._chunks[coord]
		if ch.lod != 0:
			continue
		for child in ch.get_children():
			if child is PropBody and child.data.interact_mode == PropData.InteractMode.HARVEST and child.data.id == &"tree_oak":
				tree_body = child
				tree_chunk = ch
				break
		if tree_body:
			break
	check(tree_body != null, "found a harvestable oak tree")
	if tree_body:
		var idx := tree_body.prop_index
		var c := tree_chunk.coord
		var count_before := tree_chunk.prop_count()
		for i in tree_body.data.hits_to_break:
			tree_body.receive_hit(DamageInfo.create(10.0, player))
		check(GameState.is_prop_removed(c, idx, 0.0), "felled tree recorded in world state")
		check(tree_chunk.prop_count() == count_before - 1, "tree removed from chunk")
		await _frames(2)
		check(world.pickup_pool.active_count() > 0, "tree dropped wood")

	# 6. Gather (interact) a berry bush / loose items via interact()
	var gather: PropBody = null
	for coord in world.chunk_manager._chunks:
		var ch: Chunk = world.chunk_manager._chunks[coord]
		for child in ch.get_children():
			if child is PropBody and child.is_interactable():
				gather = child
				break
		if gather:
			break
	check(gather != null, "found a gatherable prop")
	if gather:
		var total_before := 0
		for s in player.inventory.slots:
			if s != null:
				total_before += s.count
		gather.interact(player)
		var total_after := 0
		for s in player.inventory.slots:
			if s != null:
				total_after += s.count
		check(total_after > total_before, "gathering adds items directly to inventory")

	# 7. Campfire: place and warm up
	var kit_slot := -1
	for i in player.inventory.capacity:
		var s = player.inventory.get_slot(i)
		if s != null and s.id == &"campfire_kit":
			kit_slot = i
	check(kit_slot >= 0, "campfire kit in inventory")
	world.debug_temperature_offset = -40.0
	var cold_air := world.get_temperature_at(player.global_position)
	player.use_slot(kit_slot)
	await _frames(2)
	check(get_tree().get_nodes_in_group(&"heat_sources").size() == 1, "campfire placed")
	var warm := world.get_temperature_at(player.global_position)
	check(warm > cold_air + 5.0, "campfire warms the area (%.1f -> %.1f)" % [cold_air, warm])
	# Cooking: raw meat -> cooked meat
	var fire: Campfire = get_tree().get_nodes_in_group(&"heat_sources")[0]
	var raw := player.inventory.count_of(&"raw_meat")
	var cooked := player.inventory.count_of(&"cooked_meat")  # Barbarians start with some (M14)
	fire.interact(player)
	check(player.inventory.count_of(&"cooked_meat") == cooked + 1 and player.inventory.count_of(&"raw_meat") == raw - 1, "cooking converts raw meat")
	fire.queue_free()

	# 8. Cold exposure in the real world: debuffs but never damage
	await _frames(2)
	player.health.reset_full()
	player.temperature.snap_to_ambient()
	await _frames(30)
	check(player.temperature.exposure < 0, "debug cold -> player exposure %s" % player.temperature.exposure_name())
	check(player.stats.get_mult(Stats.MOVE_SPEED) < 1.0, "cold slows the player")
	check(player.health.current >= player.health.max_health - 0.01, "cold did not damage the player")
	world.debug_temperature_offset = 0.0

	# 9. Streaming: teleport far away, old chunks unload, new ones load
	var far := player.global_position + Vector3(400, 0, 400)
	far.y = world.get_ground_height(far) + 2.0
	player.global_position = far
	var old_coord := TerrainGenerator.world_to_chunk(start)
	waited = 0
	while not world.chunk_manager.is_near_area_ready() and waited < 1200:
		await get_tree().process_frame
		waited += 1
	check(world.chunk_manager.is_near_area_ready(), "new area streamed in (%d frames)" % waited)
	check(world.chunk_manager.get_chunk(old_coord) == null, "old chunks unloaded")
	var s2 := world.chunk_manager.get_debug_stats()
	check(s2.loaded < 400, "loaded chunk count bounded (%d)" % s2.loaded)
	check(s2.pooled > 0, "unloaded chunks recycled into pool")
	# Coming back regenerates the felled tree's chunk without the tree.
	if tree_body == null:
		pass

	# 10. Death & respawn
	player.health.apply_raw_damage(9999.0)
	await _frames(2)
	check(player.is_dead, "player can die")
	player.respawn()
	await _frames(2)
	check(not player.is_dead and player.health.current > 0.0, "player respawns")

	world.queue_free()
	await _frames(5)


## Boots the main scene and waits until the area around the player is ready.
func _boot_world() -> World:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as World
	add_child(world)
	var waited := 0
	while not world.is_ready and waited < 1500:
		await get_tree().process_frame
		waited += 1
	return world


func _wait_ready(world: World) -> int:
	var waited := 0
	await get_tree().process_frame
	while not world.is_ready and waited < 1500:
		await get_tree().process_frame
		waited += 1
	return waited


func test_layers_and_swimming() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED)
	var world: World = await _boot_world()
	var player := world.player
	check(world.is_ready, "world ready")
	var g := world.generator
	var start := player.global_position

	# --- Swimming: find deep water within 1.5 km and swim in it.
	var deep := Vector3.INF
	for r in range(20, 1500, 20):
		for k in 24:
			var a := TAU * k / 24.0
			var p := start + Vector3(cos(a), 0, sin(a)) * r
			if g.get_height_at(p) < TerrainGenerator.WATER_Y - 2.0 and not g.get_biome_at(p).frozen_water:
				deep = p
				break
		if deep != Vector3.INF:
			break
	check(deep != Vector3.INF, "found deep water near spawn")
	if deep != Vector3.INF:
		player.global_position = Vector3(deep.x, TerrainGenerator.WATER_Y - 1.0, deep.z)
		var w := await _wait_ready_after_teleport(world)
		await _frames(90)
		check(player.is_swimming, "player swims in deep water (streamed in %d frames)" % w)
		check(absf(player.global_position.y - (TerrainGenerator.WATER_Y - player.swim_depth)) < 0.3,
			"player floats at the surface (y=%.2f)" % player.global_position.y)
		var st := player.stamina.current
		Input.action_press(&"move_forward")
		await _frames(30)
		Input.action_release(&"move_forward")
		check(player.stamina.current < st, "swimming costs stamina")

	# --- Caves: walk into an entrance and back out.
	var entrances := g.get_cave_entrances_near(floori(start.x) - 600, floori(start.z) - 600, floori(start.x) + 600, floori(start.z) + 600)
	check(not entrances.is_empty(), "cave entrance within 600 m of spawn")
	if entrances.is_empty():
		world.queue_free()
		return
	var e := entrances[0]
	var epos := Vector3(e.x + 0.5, g.get_height_blocks(e.x, e.y) * TerrainGenerator.BLOCK_HEIGHT, e.y + 0.5)
	player.global_position = epos + Vector3(2, 0.5, 0)
	await _wait_ready_after_teleport(world)
	await _frames(10)
	var passage: CavePassage = null
	var chunk := world.chunk_manager.get_chunk(TerrainGenerator.world_to_chunk(epos))
	if chunk:
		for c in chunk.get_children():
			if c is CavePassage:
				passage = c
	check(passage != null and passage.target_layer == TerrainGenerator.Layer.UNDERGROUND, "entrance structure spawned in the chunk")
	if passage:
		passage.interact(player)
	else:
		world.travel_to_layer(TerrainGenerator.Layer.UNDERGROUND, epos)
	check(world.layer == TerrainGenerator.Layer.UNDERGROUND, "travelled to the underground layer")
	var waited := await _wait_ready(world)
	check(world.is_ready, "cave streamed in (%d frames)" % waited)
	await _frames(60)
	check(player.is_on_floor(), "player stands on the cave floor")
	check(player.global_position.y < -100.0, "player is deep underground (y=%.1f)" % player.global_position.y)
	check(world.current_biome != null and world.current_biome.id == &"the_deeps", "biome is The Deeps")
	check(absf(world.get_air_temperature(player.global_position) - world.worldgen.cave_temperature) < 0.1, "caves have a steady temperature")
	check(not world.day_night.sun.visible, "no sun underground")
	var cave_chunk := world.chunk_manager.get_chunk(TerrainGenerator.world_to_chunk(player.global_position))
	check(cave_chunk != null and cave_chunk.layer == 1, "underground chunks loaded")
	var any_props := 0
	for coord in world.chunk_manager._chunks:
		any_props += world.chunk_manager._chunks[coord].prop_count()
	check(any_props > 0, "cave props (ores, fungi) present (%d)" % any_props)
	world.travel_to_layer(TerrainGenerator.Layer.SURFACE, epos)
	await _wait_ready(world)
	await _frames(30)
	check(world.layer == 0 and player.global_position.y > -20.0, "climbed back to the surface")
	check(world.day_night.sun.visible, "sun is back")
	world.queue_free()
	await _frames(5)


func _wait_ready_after_teleport(world: World) -> int:
	var waited := 0
	await get_tree().process_frame
	while not world.chunk_manager.is_near_area_ready() and waited < 1500:
		await get_tree().process_frame
		waited += 1
	return waited


func test_save_load() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds"
	for w in SaveManager.list_worlds():
		SaveManager.delete_world(w.id)
	var id := SaveManager.create_world("Test World!", 424242)
	check(id == "test_world_", "world id derived from name (%s)" % id)
	check(SaveManager.is_persistent(), "created world is persistent")
	var world: World = await _boot_world()
	var player := world.player
	check(world.is_ready, "new saved world boots")
	check(FileAccess.file_exists("user://test_worlds/%s/save.json" % id), "initial save written")
	# Change things.
	player.global_position += Vector3(3, 0, 2)
	player.inventory.add_item(&"iron_ore", 7)
	player.hunger._set_current(42.0)
	player.health.current = 55.0
	player.temperature.add_buff(&"test_buff", 5.0, 100.0)
	world.day_night.hour = 17.5
	world.place_object(load("res://scenes/world/campfire.tscn"), player.global_position + Vector3(2, 0, 0))
	GameState.mark_prop_removed(Vector2i(3, -2), 12345, 0)
	GameState.mark_prop_removed(Vector2i(3, -2), 777, 1)
	GameState.mark_enemy_killed("1,1:10:0")
	GameState.discover_biome(&"sunscorch_desert")
	await _frames(3)
	var pos := player.global_position
	check(world.save_now(false), "save_now succeeds")
	world.queue_free()
	await _frames(5)

	# Wreck the in-memory state, then load from disk.
	GameState.reset(1)
	check(SaveManager.list_worlds().size() == 1, "world appears in the world list")
	check(SaveManager.load_world(id), "load_world succeeds")
	check(GameState.world_seed == 424242, "seed restored")
	check(GameState.is_prop_removed(Vector2i(3, -2), 12345, 0.0, 0), "surface world change restored")
	check(GameState.is_prop_removed(Vector2i(3, -2), 777, 0.0, 1), "underground world change restored")
	check(not GameState.can_spawn_slot("1,1:10:0", 300.0), "killed spawn slot restored")
	check(GameState.discovered_biomes.has("sunscorch_desert"), "discovered biomes restored")
	world = await _boot_world()
	player = world.player
	check(world.is_ready, "loaded world boots")
	check(player.global_position.distance_to(pos) < 0.6, "player position restored (%.2f m off)" % player.global_position.distance_to(pos))
	check(player.inventory.count_of(&"iron_ore") == 7, "inventory restored")
	check(absf(player.hunger.current - 42.0) < 1.0, "hunger restored")
	check(absf(player.health.current - 55.0) < 2.0, "health restored")
	check(player.temperature.get_buffs().has(&"test_buff"), "temperature buffs restored")
	check(absf(world.day_night.hour - 17.5) < 0.2, "time of day restored")
	check(get_tree().get_nodes_in_group(&"heat_sources").size() == 1, "placed campfire restored")
	world.queue_free()
	await _frames(5)
	# A corrupt main save falls back to the backup.
	var f := FileAccess.open("user://test_worlds/%s/save.json" % id, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	check(SaveManager.load_world(id) and not SaveManager.pending.is_empty(), "corrupt save falls back to .bak")
	SaveManager.pending = {}
	check(SaveManager.delete_world(id), "world deleted")
	check(SaveManager.list_worlds().is_empty(), "world list empty after delete")
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


# --- Milestone 3: RPG ------------------------------------------------------------------

func test_rpg_data() -> void:
	var classes := ClassRegistry.all()
	check(classes.size() == 4, "four classes")
	for c in classes:
		check(c.starting_skill_total() == 50, "%s starts with exactly 50 skill points" % c.id)
		check(c.abilities.size() == 3, "%s has 3 abilities" % c.id)
		var mc_req := c.temperature_shield_requirement()
		var max_mana_at_req := Skill.max_mana(mc_req, c.base_mana, c.mana_per_point)
		var shield_cost := c.temperature_shield_cost * Skill.mana_cost_mult(mc_req)
		check(max_mana_at_req >= shield_cost, "%s can afford the Temperature Shield once unlocked (%d/%d mana)" % [c.id, roundi(shield_cost), roundi(max_mana_at_req)])
		for id in c.starting_equipment:
			var item: ItemData = ItemDB.get_item(StringName(id))
			check(item != null and item.is_equippable() and item.required_level <= 1, "%s starting gear %s is valid" % [c.id, id])
	var costs := {}
	for c in classes:
		costs[c.id] = c.temperature_shield_cost
	check(costs[&"wizard"] < costs[&"knight"] and costs[&"wizard"] < costs[&"barbarian"] and costs[&"wizard"] < costs[&"assassin"],
		"Wizard has the cheapest Temperature Shield")
	var weapons := 0
	for id in ItemDB.all_ids():
		var item: ItemData = ItemDB.get_item(id)
		if item.equip_slot == ItemData.EquipSlot.MAIN_HAND:
			weapons += 1
			check(item.moveset != null and not item.moveset.light_combo.is_empty() and item.moveset.heavy_attack != null,
				"weapon %s has a complete moveset" % id)


func test_progression() -> void:
	var prev := 0
	var increasing := true
	for l in range(1, 100):
		var x := Progression.xp_to_next(l)
		if x <= prev:
			increasing = false
		prev = x
	check(increasing, "XP per level strictly increases 1->100")
	check(Progression.xp_to_next(1) == 100, "level 2 needs 100 XP")
	check(Progression.xp_to_next(100) == 0, "no XP beyond level 100")
	var total := Progression.total_xp_for(100)
	print("   total XP to level 100: %d; level 10: %d; level 50: %d" % [total, Progression.total_xp_for(10), Progression.total_xp_for(50)])
	check(total > 2000000, "reaching level 100 takes millions of XP (endgame not trivial)")
	check(Progression.total_xp_for(5) < 1500, "early levels are quick (level 5 at %d XP)" % Progression.total_xp_for(5))
	check(Progression.total_skill_points_at(100) == 99 * 2 + 20, "skill points at 100: %d" % Progression.total_skill_points_at(100))
	check(50 + Progression.total_skill_points_at(100) < 5 * 100, "you cannot max every skill (build choices matter)")
	check(Progression.combat_xp(20, 3, 1) > 20, "stronger enemies give bonus XP")
	check(Progression.combat_xp(20, 3, 30) <= 2, "trivial enemies give almost no XP")


func test_skill_formulas() -> void:
	var knight := ClassRegistry.get_class_data(&"knight")
	var wizard := ClassRegistry.get_class_data(&"wizard")
	var barb := ClassRegistry.get_class_data(&"barbarian")
	var wiz100 := Skill.physical_damage_mult(100, wizard.efficiency(Skill.STRENGTH), wizard.physical_power)
	var kn100 := Skill.physical_damage_mult(100, knight.efficiency(Skill.STRENGTH), knight.physical_power)
	var kn_start := Skill.physical_damage_mult(knight.starting_skill(Skill.STRENGTH), knight.efficiency(Skill.STRENGTH), knight.physical_power)
	var barb100 := Skill.physical_damage_mult(100, barb.efficiency(Skill.STRENGTH), barb.physical_power)
	print("   physical x at STR100: wizard %.2f, knight %.2f, barbarian %.2f (knight start %.2f)" % [wiz100, kn100, barb100, kn_start])
	# Option A (Milestone 14): gear makes the build, the class keeps a talent -
	# a Wizard who trains Strength gets close to a Knight but never equals one.
	check(wiz100 < kn100 * 0.9, "a max-Strength Wizard never equals a max-Strength Knight (×%.2f)" % (wiz100 / kn100))
	check(wiz100 > kn_start, "but a Wizard who trains Strength can out-hit a fresh Knight")
	check(barb100 > kn100, "Barbarian has the highest physical ceiling")
	check(Skill.material_cost_mult(1) > 1.4 and Skill.material_cost_mult(100) < 0.85, "crafting skill reduces material cost (never fails)")
	check(Skill.recipe_tier(100) == ItemData.Rarity.LEGENDARY and Skill.recipe_tier(1) == ItemData.Rarity.BASIC, "crafting unlocks recipe tiers")
	check(Skill.damage_reduction(1000000.0) <= 0.75, "armor damage reduction capped at 75%")
	check(Skill.attack_speed_mult(100, 1.0) > Skill.attack_speed_mult(10, 1.0), "dexterity raises attack speed")
	check(Skill.mana_cost_mult(100) < Skill.mana_cost_mult(0), "mana control lowers ability costs")
	for s in Skill.ALL:
		check(Skill.PERKS[s].size() >= 4, "%s has milestone perks" % s)


func _boot_class(class_id: StringName) -> World:
	SaveManager.start_transient(GameState.DEFAULT_SEED, class_id)
	var world: World = await _boot_world()
	world.player.health.invulnerable = false
	return world


func _spawn_boar(world: World, offset: Vector3) -> ThornbackBoar:
	var p := world.player.global_position + offset
	p.y = world.get_ground_height(p) + 0.3
	var boar := world.spawner.spawn_enemy(world.debug_enemy_scene, p, "") as ThornbackBoar
	boar.stagger(4.0)  # hold still so tests are deterministic
	return boar


## Offset (distance `d`) toward flat ground with a clear line of sight.
func _clear_offset(world: World, d: float) -> Vector3:
	var p := world.player.global_position
	var g0 := world.get_ground_height(p)
	for k in 16:
		var dir := Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0))
		var ok := true
		for s in range(1, int(d * 2) + 1):
			var q := p + dir * (s * 0.5)
			if absf(world.get_ground_height(q) - g0) > 0.01 or world.is_in_water(q):
				ok = false
				break
		if ok:
			return dir * d
	return world.player.get_facing() * d


func test_character_and_equipment() -> void:
	var world: World = await _boot_class(&"knight")
	var player := world.player
	var ch := player.character
	check(ch.class_data.id == &"knight" and ch.level == 1, "new Knight at level 1")
	check(player.equipment.weapon_type() == &"sword" and player.equipment.offhand() != null, "Knight starts with sword and shield")
	check(player.combat.light_combo.size() == 3, "sword moveset loaded (3-hit combo)")
	check(player.health.max_health > 100.0 and player.health.current == player.health.max_health, "Defense raises max health (%d)" % roundi(player.health.max_health))
	var armor_before := ch.armor
	# XP & levels
	var gained := ch.grant_xp(Progression.total_xp_for(6), Progression.Source.OTHER)
	check(gained == 5 and ch.level == 6, "XP levels up (now %d)" % ch.level)
	check(ch.unspent_points == Progression.total_skill_points_at(6), "level-ups grant skill points (%d)" % ch.unspent_points)
	var str_before := ch.physical_mult
	check(ch.spend_point(Skill.STRENGTH), "spend a point on Strength")
	check(ch.physical_mult > str_before, "Strength raises physical damage")
	var hp_before := player.health.max_health
	ch.spend_point(Skill.DEFENSE)
	check(player.health.max_health > hp_before and ch.armor > armor_before, "Defense raises health and armor")
	var mana_before := player.mana.max_mana
	ch.spend_point(Skill.MANA_CONTROL)
	check(player.mana.max_mana > mana_before, "Mana Control raises max mana")
	var spd := ch.attack_speed
	ch.spend_point(Skill.DEXTERITY)
	check(ch.attack_speed > spd and player.stats.get_mult(Stats.ATTACK_SPEED) >= ch.attack_speed * 0.99, "Dexterity raises attack speed")
	# Equipment
	player.inventory.add_item(&"chainmail", 1)
	player.inventory.add_item(&"crystal_staff", 1)
	var slot := -1
	for i in player.inventory.capacity:
		var s = player.inventory.get_slot(i)
		if s != null and s.id == &"chainmail":
			slot = i
	check(not player.equip_from_slot(slot), "level requirement blocks chainmail at level 6")
	ch.grant_xp(Progression.total_xp_for(12) - ch.total_xp, Progression.Source.OTHER)
	var armor_now := ch.armor
	check(player.equip_from_slot(slot), "chainmail equips at level %d" % ch.level)
	check(ch.armor > armor_now + 10.0 and player.inventory.count_of(&"squire_plate") == 1, "armor rises and old chest piece returns to the inventory")
	var dmg_sword := ch.weapon_mult(&"sword")
	check(dmg_sword > ch.weapon_mult(&"staff"), "Knights are proficient with swords, not staves")
	ch.grant_xp(Progression.total_xp_for(ItemDB.get_item(&"crystal_staff").required_level) - ch.total_xp, Progression.Source.OTHER)
	for i in player.inventory.capacity:
		var s = player.inventory.get_slot(i)
		if s != null and s.id == &"crystal_staff":
			player.equip_from_slot(i)
	check(player.equipment.weapon_type() == &"staff" and player.combat.light_combo.size() == 2, "weapon swap changes the moveset")
	check(player.unequip_slot(ItemData.EquipSlot.MAIN_HAND) and player.combat.light_combo[0].id == &"punch_1", "unarmed moveset without a weapon")
	# Real damage: a proficient sword out-damages an unarmed/off-class hit.
	var boar := _spawn_boar(world, Vector3(0, 0, 3))
	await _frames(5)
	ch.crit_chance = 0.0  # compare without random crits (restored by recalculate)
	var unarmed := 0.0
	for i in 20:
		unarmed += player.combat.build_physical(10.0, boar, 0.0, 0.0).amount / 20.0
	for i in player.inventory.capacity:
		var s = player.inventory.get_slot(i)
		if s != null and s.id == &"squire_sword":
			player.equip_from_slot(i)
	ch.crit_chance = 0.0
	var armed := 0.0
	for i in 20:
		armed += player.combat.build_physical(10.0, boar, 0.0, 0.0).amount / 20.0
	ch.recalculate()
	check(player.equipment.weapon_type() == &"sword", "sword re-equipped")
	print("   same attack: unarmed %.1f vs sword %.1f" % [unarmed, armed])
	check(armed > unarmed * 0.95, "proficient weapon is not weaker than bare fists")
	# Armor reduces damage taken.
	player.health.reset_full()
	var info := DamageInfo.create(40.0, boar)
	info.direction = player.get_facing()  # from behind: no block
	player.receive_hit(info)
	var taken := player.health.max_health - player.health.current
	check(taken < 40.0 * (1.0 - ch.damage_reduction) + 0.5 and taken > 5.0, "armor reduces damage (took %.1f of 40)" % taken)
	# XP from kills
	var xp_before := ch.total_xp
	boar.health.apply_raw_damage(9999.0)
	await _frames(2)
	check(ch.total_xp > xp_before, "killing an enemy grants XP")
	# Temperature Shield requirement
	check(not ch.can_use_temperature_shield() or ch.base_skill(Skill.MANA_CONTROL) >= ch.class_data.temperature_shield_requirement(), "shield gated by Mana Control")
	world.queue_free()
	await _frames(5)


func test_class_abilities() -> void:
	# --- Wizard
	var world: World = await _boot_class(&"wizard")
	var p := world.player
	var ab := p.abilities
	var boar := _spawn_boar(world, _clear_offset(world, 6.0))
	await _frames(3)
	p.set_lock_target(boar)
	# A sturdy target so the burn is still ticking when we look.
	boar.health.max_health = 400.0
	boar.health.current = 400.0
	var hp := boar.health.current
	check(ab.try_use(0), "Wizard casts Firebolt")
	await _frames(30)
	check(boar.health.current < hp and boar.status.has(&"burn"), "Firebolt damages and burns (%.0f -> %.0f)" % [hp, boar.health.current])
	check(not ab.try_use(1), "Frost Nova locked below level 5")
	p.character.grant_xp(Progression.total_xp_for(15), Progression.Source.OTHER)
	await _frames(40)
	boar = _spawn_boar(world, p.get_facing() * 3.0)  # the first one burned to death
	p.set_lock_target(boar)
	await _frames(3)
	check(ab.try_use(1), "Frost Nova at level %d" % p.character.level)
	check(boar.status.has(&"frozen"), "Frost Nova freezes")
	hp = boar.health.current
	ab.cooldowns.clear()
	p.set_lock_target(boar)
	ab.try_use(0)
	await _frames(20)
	check(not boar.status.has(&"frozen") and boar.health.current < hp, "Firebolt shatters the frozen enemy")
	boar = _spawn_boar(world, p.get_facing() * 5.0)
	var boar2 := _spawn_boar(world, p.get_facing() * 5.0 + Vector3(2, 0, 0))
	await _frames(3)
	var hp1 := boar.health.current
	var hp2 := boar2.health.current
	p.set_lock_target(boar)
	check(ab.try_use(2), "Chain Lightning cast")
	check(boar.health.current < hp1 and boar2.health.current < hp2, "Chain Lightning jumps to a second enemy")
	# Temperature shield (Wizard can afford it from the start: MC 22 -> needs 24)
	check(not ab.try_use(3), "Temperature Shield needs MC +2")
	p.character.spend_point(Skill.MANA_CONTROL)
	p.character.spend_point(Skill.MANA_CONTROL)
	p.mana.refill()
	check(ab.try_use(3), "Temperature Shield cast after raising Mana Control")
	check(ab.has_buff(&"temperature_shield") and absf(ab.buff_time(&"temperature_shield") - 600.0) < 1.0, "shield lasts 10 minutes")
	world.debug_temperature_offset = -45.0
	p.temperature.snap_to_ambient()
	await _frames(10)
	var shielded := p.temperature.get_effective_ambient()
	ab.remove_buff(&"temperature_shield")
	await _frames(2)
	check(shielded > p.temperature.get_effective_ambient() + 15.0, "shield protects from cold (%.0f vs %.0f°C)" % [shielded, p.temperature.get_effective_ambient()])
	world.debug_temperature_offset = 0.0
	world.queue_free()
	await _frames(5)

	# --- Barbarian
	world = await _boot_class(&"barbarian")
	p = world.player
	ab = p.abilities
	var b1 := _spawn_boar(world, Vector3(1.8, 0, 0))
	var b2 := _spawn_boar(world, Vector3(-1.8, 0, 0))
	await _frames(3)
	var h1 := b1.health.current
	var h2 := b2.health.current
	check(ab.try_use(0), "Barbarian Whirlwind")
	await _frames(40)
	check(b1.health.current < h1 and b2.health.current < h2, "Whirlwind hits enemies on both sides")
	check(ab.rage > 0.0, "dealing damage builds Rage (%.0f)" % ab.rage)
	p.character.grant_xp(Progression.total_xp_for(15), Progression.Source.OTHER)
	ab.cooldowns.clear()
	check(ab.try_use(1) and ab.has_buff(&"battle_cry"), "Battle Cry buff")
	check(ab.outgoing_mult() > 1.25, "Battle Cry + Rage raise damage (x%.2f)" % ab.outgoing_mult())
	ab.set_rage(80.0)
	check(ab.try_use(2) and ab.has_buff(&"berserk") and ab.rage == 0.0, "Berserk consumes Rage")
	check(p.stats.get_mult(Stats.ATTACK_SPEED) > p.character.attack_speed * 1.3, "Berserk raises attack speed")
	world.queue_free()
	await _frames(5)

	# --- Knight
	world = await _boot_class(&"knight")
	p = world.player
	ab = p.abilities
	var kb := _spawn_boar(world, p.get_facing() * 1.8)
	p.set_lock_target(kb)  # face it (headless mouse aim would turn us away)
	await _frames(3)
	kb._stagger_left = 0.0
	check(ab.try_use(0), "Knight Shield Bash")
	check(kb.status.has(&"stunned") and kb.is_taunted(), "Shield Bash stuns and taunts")
	p.character.grant_xp(Progression.total_xp_for(15), Progression.Source.OTHER)
	ab.cooldowns.clear()
	check(ab.try_use(1) and ab.incoming_mult() < 0.6, "Guardian Stance halves damage taken")
	ab.remove_buff(&"guardian")
	var far := _spawn_boar(world, _clear_offset(world, 9.0))
	p.set_lock_target(far)  # charge toward a clear direction
	await _frames(3)
	var start := p.global_position
	p.health.current = p.health.max_health * 0.5
	var h_before := p.health.current
	check(ab.try_use(2), "Rallying Charge")
	await _frames(40)
	check(p.global_position.distance_to(start) > 4.0 and p.health.current > h_before, "charge moves you forward and heals")
	world.queue_free()
	await _frames(5)

	# --- Assassin
	world = await _boot_class(&"assassin")
	p = world.player
	ab = p.abilities
	var ab_boar := _spawn_boar(world, p.get_facing() * 6.0)
	await _frames(3)
	p.set_lock_target(ab_boar)
	check(ab.try_use(0), "Assassin Shadow Step")
	var behind: Vector3 = ab_boar.get_facing().dot((ab_boar.global_position - p.global_position).normalized()) as float * Vector3.ONE
	check(p.global_position.distance_to(ab_boar.global_position) < 2.5 and behind.x > 0.5, "Shadow Step lands behind the target")
	check(ab.has_buff(&"ambush"), "next hit is a guaranteed critical")
	var info := p.combat.build_damage(p.combat.light_combo[0], ab_boar, ab.consume_attack_bonus())
	check(info.is_crit and info.tag.contains("Backstab"), "guaranteed crit + backstab from behind (%.0f dmg)" % info.amount)
	p.character.grant_xp(Progression.total_xp_for(15), Progression.Source.OTHER)
	ab.cooldowns.clear()
	check(ab.try_use(1), "Poison Blade")
	ab.on_hit_dealt(ab_boar, 1.0)
	ab.on_hit_dealt(ab_boar, 1.0)
	check(ab_boar.status.stacks(&"poison") == 2, "poison stacks on hits")
	ab_boar.target = p
	check(ab.try_use(2) and p.is_stealthed(), "Vanish makes you stealthed")
	check(ab_boar.target == null or ab_boar.is_taunted(), "enemy loses track of you")
	var amb := ab.consume_attack_bonus()
	check(amb.mult == 2.0 and not p.is_stealthed(), "attacking from stealth is an Ambush (x2) and breaks stealth")
	world.queue_free()
	await _frames(5)


func test_rpg_save_load() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds"
	for w in SaveManager.list_worlds():
		SaveManager.delete_world(w.id)
	var id := SaveManager.create_world("RPG Test", 777, &"assassin")
	var world: World = await _boot_world()
	var p := world.player
	check(p.character.class_data.id == &"assassin", "world created with the chosen class")
	p.character.grant_xp(Progression.total_xp_for(8), Progression.Source.OTHER)
	p.character.spend_point(Skill.DEXTERITY)
	p.character.spend_point(Skill.DEXTERITY)
	p.inventory.add_item(&"copper_dagger", 1)
	for i in p.inventory.capacity:
		var s = p.inventory.get_slot(i)
		if s != null and s.id == &"copper_dagger":
			p.equip_from_slot(i)
	var level := p.character.level
	var dex := p.character.base_skill(Skill.DEXTERITY)
	var pts := p.character.unspent_points
	var total := p.character.total_xp
	var max_hp := p.health.max_health
	world.save_now(false)
	world.queue_free()
	await _frames(5)
	check(SaveManager.load_world(id), "load RPG world")
	world = await _boot_world()
	p = world.player
	check(p.character.class_data.id == &"assassin", "class restored")
	check(p.character.level == level and p.character.total_xp == total, "level and XP restored (Lv %d)" % p.character.level)
	check(p.character.base_skill(Skill.DEXTERITY) == dex and p.character.unspent_points == pts, "skills and unspent points restored")
	check(p.equipment.weapon() != null and p.equipment.weapon().id == &"copper_dagger", "equipment restored")
	check(absf(p.health.max_health - max_hp) < 0.01, "derived max health identical after load")
	check(p.model != null and p.combat.light_combo.size() == 4, "dagger moveset active after load")
	var meta_list := SaveManager.list_worlds()
	check(meta_list.size() == 1 and meta_list[0].get("class") == "assassin" and int(meta_list[0].get("level", 0)) == level, "world list shows class and level")
	world.queue_free()
	await _frames(5)
	SaveManager.delete_world(id)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


# --- Milestone 4: building & crafting -------------------------------------------------------

func _grove_poi() -> PoiInfo:
	var g := PoiInfo.new()
	g.kind = PoiInfo.Kind.GROVE
	g.id = "p:0,0"
	g.name = "Test"
	return g


func test_m4_data() -> void:
	var recipes := RecipeBook.all()
	check(recipes.size() >= 40, "%d recipes loaded" % recipes.size())
	var ok := true
	var taught := {}
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		for r in it.teaches_recipes:
			taught[StringName(r)] = true
			if not recipes.has(StringName(r)):
				ok = false
				print("   %s teaches unknown recipe %s" % [id, r])
	for r: RecipeData in recipes.values():
		if not ItemDB.has_item(r.result_item):
			ok = false
			print("   recipe %s makes unknown item %s" % [r.id, r.result_item])
		for ing in r.ingredients:
			if not ItemDB.has_item(ing):
				ok = false
				print("   recipe %s needs unknown item %s" % [r.id, ing])
		if r.source == RecipeData.Source.DISCOVERY and not ItemDB.has_item(r.discovered_by):
			ok = false
			print("   recipe %s discovered by unknown item" % r.id)
		if r.source == RecipeData.Source.BOOK and not taught.has(r.id):
			ok = false
			print("   book recipe %s is taught by no book" % r.id)
	check(ok, "recipes reference existing items; every book recipe is taught by a book")
	# Cost scaling: more skill never costs more, never below 1, never above +60%.
	var scale_ok := true
	for r: RecipeData in recipes.values():
		var lo := r.cost_at(1)
		var mid := r.cost_at(50)
		var hi := r.cost_at(100)
		for ing in r.ingredients:
			var base := int(r.ingredients[ing])
			if not (lo[ing] >= mid[ing] and mid[ing] >= hi[ing] and hi[ing] >= 1 and lo[ing] <= ceili(base * 1.6)):
				scale_ok = false
	check(scale_ok, "material costs shrink with Crafting skill and stay >= 1")
	var rope := RecipeBook.get_recipe(&"rope")
	check(rope.cost_at(1)[&"plant_fiber"] == 5 and rope.cost_at(100)[&"plant_fiber"] == 3,
		"rope: 5 fiber at Crafting 1, 3 at Crafting 100 (base 3)")
	check(int(RecipeBook.get_recipe(&"cooked_meat").cost_at(1)[&"raw_meat"]) == 1,
		"a novice cooks one raw meat into one meal (single items never scale up)")
	# Build pieces
	var pieces := BuildingManager.all_pieces()
	check(pieces.size() >= 20, "%d build pieces loaded" % pieces.size())
	var piece_ok := true
	var categories := {}
	for d: BuildPieceData in pieces.values():
		categories[d.category] = true
		for item in d.cost:
			if not ItemDB.has_item(item):
				piece_ok = false
				print("   piece %s costs unknown item %s" % [d.id, item])
		if d.behavior == BuildPieceData.Behavior.STATION and not RecipeData.STATION_IDS.has(d.station_id):
			piece_ok = false
			print("   station %s has unknown station id" % d.id)
		var m := BuildMeshes.get_mesh(d.mesh)
		if m == null or m.get_aabb().size == Vector3.ONE:
			piece_ok = false
			print("   piece %s has no mesh builder (%s)" % [d.id, d.mesh])
	check(piece_ok, "build pieces: valid costs, stations and meshes")
	check(categories.size() == BuildPieceData.CATEGORY_NAMES.size(), "every build category has pieces")
	var stations := {}
	for d: BuildPieceData in pieces.values():
		if d.station_id != &"":
			stations[d.station_id] = true
	var reach_ok := true
	for r: RecipeData in recipes.values():
		if r.station_id() != &"hand" and r.station_id() != &"campfire" and not stations.has(r.station_id()):
			reach_ok = false
			print("   recipe %s needs unbuildable station %s" % [r.id, r.station_id()])
	check(reach_ok, "every recipe station can be built (or is hand/campfire)")
	# Everything used in recipes and building is obtainable (gathered, looted or crafted).
	var obtainable := {}
	var lib := PropLibrary.new()
	for biome in _settings().biomes:
		for rule in biome.prop_rules:
			for loot in lib.get_prop(rule.prop_id).drops:
				obtainable[loot.item_id] = true
	var boar: EnemyData = load("res://data/enemies/thornback_boar.tres")
	for loot in boar.loot:
		obtainable[loot.item_id] = true
	# Milestone 5: shops sell things, farms grow produce from seeds.
	for role in Economy.STOCK:
		for e in Economy.STOCK[role]:
			obtainable[e[0]] = true
	for e in Economy.TRADER_POOL:
		obtainable[e[0]] = true
	for c in Farming.CROPS:
		if obtainable.has(Farming.CROPS[c].seed):
			obtainable[Farming.CROPS[c].produce] = true
	# Milestone 6: monster loot, chests/bosses, hidden-grove plants.
	for f in ResourceLoader.list_directory("res://data/enemies/"):
		var ed := load("res://data/enemies/" + f) as EnemyData
		if ed:
			for loot in ed.loot:
				obtainable[loot.item_id] = true
	for t in LootTables.TABLES.values():
		for e in t.items:
			obtainable[e[0]] = true
	for band in LootTables.GEAR:
		for g in band:
			obtainable[g] = true
	for sc in LootTables.SCROLLS:
		obtainable[sc] = true
	for o in PoiLayout.build(_grove_poi()).objects:
		if o.get("item", &"") != &"":
			obtainable[o.item] = true
	var changed := true
	while changed:
		changed = false
		for r: RecipeData in recipes.values():
			if obtainable.has(r.result_item):
				continue
			var all_in := true
			for ing in r.ingredients:
				all_in = all_in and obtainable.has(ing)
			if all_in:
				obtainable[r.result_item] = true
				changed = true
	var missing := PackedStringArray()
	for r: RecipeData in recipes.values():
		for ing in r.ingredients:
			if not obtainable.has(ing):
				missing.append(String(ing))
	for d: BuildPieceData in pieces.values():
		for item in d.cost:
			if not obtainable.has(item):
				missing.append(String(item))
	check(missing.is_empty(), "every recipe ingredient and build cost is obtainable in the world %s" % [missing])
	for book in [&"smithing_manual", &"leatherworker_notes", &"arcane_codex", &"cooks_journal"]:
		check(obtainable.has(book), "%s can be found in the world" % book)
	# Tool tiers
	check(ItemDB.get_item(&"stone_pickaxe").tool_tier == 1 and ItemDB.get_item(&"iron_pickaxe").tool_tier == 3, "tool tiers 1-3")
	check(lib.get_prop(&"ore_iron").tool_tier == 2 and lib.get_prop(&"crystal_cluster").tool_tier == 3
		and lib.get_prop(&"tree_oak").tool_tier == 0, "iron needs tier 2, crystal tier 3, trees need no tool")


## Places a piece near the player on the first valid cell (pay = false unless asked).
func _place_near(world: World, id: StringName, min_d: int = 2, pay: bool = false, max_d: int = 6) -> BuildPiece:
	var data := BuildingManager.get_piece_data(id)
	var pc := Vector2i(floori(world.player.global_position.x), floori(world.player.global_position.z))
	for d in range(min_d, max_d + 1):
		for dx in range(-d, d + 1):
			for dz in range(-d, d + 1):
				if maxi(absi(dx), absi(dz)) != d:
					continue
				var cell := pc + Vector2i(dx, dz)
				var slot := BuildingManager.slot_kind(data)
				if slot == "edge":
					slot = "edge_n"
				if world.building.check_place(data, cell, slot, world.player, pay) == "":
					return world.building.place(data, cell, slot, 0, world.player, pay)
	return null


func _clear_enemies(world: World) -> void:
	world.spawner.max_active = 0
	world.spawner.wild_enabled = false  # Milestone 15: the land is full of wild life
	world.spawner.despawn_all()


func test_crafting_system() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	var ch := p.character
	_clear_enemies(world)
	# Recipe learning
	check(p.recipes.knows(&"rope") and p.recipes.knows(&"stone_pickaxe") and p.recipes.knows(&"cooked_meat"), "starting recipes known")
	check(not p.recipes.knows(&"copper_ingot") and not p.recipes.knows(&"iron_ingot") and not p.recipes.knows(&"hearty_stew"),
		"discovery and book recipes unknown at start")
	p.give_item(&"copper_ore", 6)
	check(p.recipes.knows(&"copper_ingot") and p.recipes.knows(&"copper_pickaxe"), "obtaining copper ore discovers copper recipes")
	p.inventory.add_item(&"smithing_manual", 1)
	for i in p.inventory.capacity:
		var s = p.inventory.get_slot(i)
		if s != null and s.id == &"smithing_manual":
			p.use_slot(i)
			break
	check(p.recipes.knows(&"iron_ingot") and p.recipes.knows(&"iron_pickaxe") and p.inventory.count_of(&"smithing_manual") == 0,
		"reading the Smithing Manual teaches iron recipes and uses up the book")
	# Crafting by hand never fails; low skill only costs more
	var stations := Crafting.stations_near(get_tree(), p.global_position)
	check(stations.has(&"hand") and not stations.has(&"workbench"), "no stations nearby: hand crafting only")
	var rope := RecipeBook.get_recipe(&"rope")
	p.inventory.add_item(&"plant_fiber", 60)
	var crafting := ch.skill_level(Skill.CRAFTING)
	var per := int(rope.cost_at(crafting)[&"plant_fiber"])
	check(per > 3, "Crafting %d: a rope costs %d fiber instead of 3" % [crafting, per])
	var fiber0 := p.inventory.count_of(&"plant_fiber")
	var rope0 := p.inventory.count_of(&"rope")
	var xp0 := ch.total_xp
	check(Crafting.craft(p, rope, stations, 3) == 3, "crafting never fails: 3 of 3 ropes made")
	check(p.inventory.count_of(&"rope") == rope0 + 3 and p.inventory.count_of(&"plant_fiber") == fiber0 - per * 3,
		"ropes added and exactly the scaled materials consumed")
	check(ch.total_xp > xp0, "crafting grants Crafting XP (+%d)" % (ch.total_xp - xp0))
	p.inventory.remove_item(&"plant_fiber", p.inventory.count_of(&"plant_fiber"))
	check(Crafting.check(p, rope, stations) == "Missing Plant Fiber" and Crafting.craft(p, rope, stations) == 0,
		"without materials nothing is crafted and nothing is lost")
	# Station gating
	p.inventory.add_item(&"wood", 60)
	p.inventory.add_item(&"stone", 40)
	var plank := RecipeBook.get_recipe(&"plank")
	check(Crafting.check(p, plank, stations) == "Requires a Workbench nearby", "planks need a workbench")
	var wb := _place_near(world, &"workbench", 2, true, 3)
	check(wb != null, "workbench placed next to the player")
	stations = Crafting.stations_near(get_tree(), p.global_position)
	check(stations.has(&"workbench"), "workbench detected as a nearby station")
	var planks0 := p.inventory.count_of(&"plank")
	check(Crafting.craft(p, plank, stations, 2) == 2 and p.inventory.count_of(&"plank") == planks0 + 4, "crafted 4 planks at the workbench")
	# Tier gating (Crafting skill) + forge level requirement
	var ingot := RecipeBook.get_recipe(&"copper_ingot")
	p.inventory.add_item(&"coal", 10)
	check(Crafting.check(p, ingot, stations).begins_with("Requires Crafting 10"), "Common-tier recipe needs Crafting 10")
	var forge_data := BuildingManager.get_piece_data(&"forge")
	var cell := Vector2i(floori(p.global_position.x), floori(p.global_position.z)) + Vector2i(0, 3)
	check(world.building.check_place(forge_data, cell, "object", p) == "Requires level 3", "the forge needs level 3")
	ch.grant_xp(Progression.total_xp_for(3), Progression.Source.OTHER)
	p.inventory.add_item(&"clay", 10)
	var forge := _place_near(world, &"forge", 2, true, 3)
	check(forge != null, "forge placed after reaching level 3")
	ch.skills[Skill.CRAFTING] = 12
	ch.recalculate()
	stations = Crafting.stations_near(get_tree(), p.global_position)
	check(Crafting.craft(p, ingot, stations) == 1 and p.inventory.count_of(&"copper_ingot") == 1, "copper ingot smelted at the forge")
	# Campfire cooking station
	var kit: ItemData = ItemDB.get_item(&"campfire_kit")
	var fire := kit.placeable_scene.instantiate() as Node3D
	world.placed_root.add_child(fire)
	fire.global_position = p.global_position + Vector3(1.5, 0, 0)
	stations = Crafting.stations_near(get_tree(), p.global_position)
	check(stations.has(&"campfire"), "campfires are cooking stations")
	p.inventory.add_item(&"raw_meat", 2)
	check(Crafting.craft(p, RecipeBook.get_recipe(&"cooked_meat"), stations) == 1 and p.inventory.count_of(&"cooked_meat") >= 1,
		"cooked meat at the campfire")
	fire.queue_free()
	# Tools
	check(p.best_tool_tier(&"pickaxe") == 0, "no pickaxe yet")
	p.inventory.add_item(&"stick", 10)
	p.inventory.add_item(&"rope", 6)
	check(Crafting.craft(p, RecipeBook.get_recipe(&"stone_pickaxe"), stations) == 1
		and Crafting.craft(p, RecipeBook.get_recipe(&"stone_hatchet"), stations) == 1, "stone pickaxe and hatchet crafted")
	check(p.best_tool_tier(&"pickaxe") == 1 and p.best_tool_tier(&"axe") == 1, "tools work from the inventory (tier 1)")
	var body: PropBody = null
	var stack: Array = [world]
	while not stack.is_empty() and body == null:
		var n: Node = stack.pop_back()
		if n is PropBody and (n as PropBody).data.interact_mode == PropData.InteractMode.HARVEST and (n as PropBody).data.tool_kind != &"":
			body = n
		stack.append_array(n.get_children())
	if check(body != null, "found a harvestable prop near spawn (%s)" % (body.data.id if body else "-")):
		var original := body.data
		body.data = original.duplicate()
		body.data.tool_tier = 2
		body.hits_left = 50
		var info := DamageInfo.create(10.0, p, &"physical")
		body.receive_hit(info)
		check(body.hits_left == 50, "tier 1 tool can't break a tier 2 resource")
		body.data.tool_tier = 1
		body.receive_hit(info)
		check(body.hits_left == 48, "tier 1 tool hits twice as hard (50 -> %d)" % body.hits_left)
		body.data = original
		var tcell := Vector2i(floori(body.global_position.x), floori(body.global_position.z))
		var why := world.building.check_place(BuildingManager.get_piece_data(&"table"), tcell, "object", null)
		check(why.begins_with("Blocked by"), "can't build through a %s (%s)" % [body.data.display_name, why])
	world.queue_free()
	await _frames(5)


func test_building_system() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	var b := world.building
	_clear_enemies(world)
	var wall := BuildingManager.get_piece_data(&"wood_wall")
	var pc := Vector2i(floori(p.global_position.x), floori(p.global_position.z))
	# Edge addressing: every edge has exactly one address.
	var c := Vector3(pc.x + 3.5, 0, pc.y + 0.5)
	check(b.address_for(wall, c + Vector3(0, 0, -0.45)).slot == "edge_n", "north edge -> edge_n")
	var south: Dictionary = b.address_for(wall, c + Vector3(0, 0, 0.45))
	check(south.slot == "edge_n" and south.cell == pc + Vector2i(3, 1), "south edge -> neighbour's edge_n")
	var east: Dictionary = b.address_for(wall, c + Vector3(0.45, 0, 0))
	check(east.slot == "edge_w" and east.cell == pc + Vector2i(4, 0), "east edge -> neighbour's edge_w")
	check(b.address_for(BuildingManager.get_piece_data(&"wood_floor"), c).slot == "floor", "floors use the floor slot")
	# Costs and rules
	p.inventory.clear()
	check(b.check_place(wall, pc + Vector2i(2, 0), "edge_n", p) == "Missing Wood", "walls cost wood")
	p.inventory.add_item(&"wood", 90)
	p.inventory.add_item(&"stone", 60)
	p.inventory.add_item(&"plank", 60)
	p.inventory.add_item(&"rope", 20)
	p.inventory.add_item(&"plant_fiber", 60)
	p.inventory.add_item(&"stick", 30)
	p.inventory.add_item(&"clay", 10)
	var wood0 := p.inventory.count_of(&"wood")
	var w := _place_near(world, &"wood_wall", 2, true)
	check(w != null and p.inventory.count_of(&"wood") == wood0 - 4, "wood wall placed for 4 wood")
	check(b.check_place(wall, w.cell, w.slot, p) == "Something is already built here", "can't stack pieces in one slot")
	check(b.check_place(wall, pc + Vector2i(15, 0), "edge_n", p) == "Too far away", "can't build far away")
	check(b.check_place(BuildingManager.get_piece_data(&"stone_wall"), pc + Vector2i(2, 2), "edge_w", p) == "Requires level 5",
		"stone walls need level 5")
	check(b.check_place(BuildingManager.get_piece_data(&"table"), pc, "object", p) == "You're standing there",
		"can't build a solid piece on yourself")
	var roof := BuildingManager.get_piece_data(&"thatch_roof")
	check(b.check_place(roof, pc + Vector2i(-5, -5), "roof", p).begins_with("Roofs need"), "roofs need support")
	check(b.check_place(roof, w.cell, "roof", p) == "", "a wall supports a roof")
	# Walls block movement (physics)
	await _frames(3)
	var top := w.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(top + Vector3(0, 0, -1.0), top + Vector3(0, 0, 1.0), p.collision_mask)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty() and hit.collider == w, "a wall is solid to the player")
	check(w.get_parent() == b and b.pieces.size() >= 1, "pieces are owned by the building manager")
	# Door
	var door := _place_near(world, &"wood_door", 2, false)
	door.interact(p)
	await _frames(3)
	check(door.is_open, "door opens")
	var dq := PhysicsRayQueryParameters3D.create(door.global_position + Vector3(0, 1.2, -1), door.global_position + Vector3(0, 1.2, 1), p.collision_mask)
	var dhit := p.get_world_3d().direct_space_state.intersect_ray(dq)
	check(dhit.is_empty() or dhit.collider != door, "an open door lets you through")
	door.interact(p)
	check(not door.is_open and door.get_interact_text() == "Open door", "door closes again")
	# Chest
	var chest := _place_near(world, &"storage_chest", 2, false)
	check(chest.storage != null and chest.storage.capacity == 16, "storage chest has 16 slots")
	var stick_slot := -1
	for i in p.inventory.capacity:
		var s = p.inventory.get_slot(i)
		if s != null and s.id == &"stick":
			stick_slot = i
	var moved := ContainerPanel.transfer(p.inventory, stick_slot, chest.storage)
	check(moved == 30 and chest.storage.count_of(&"stick") == 30 and p.inventory.count_of(&"stick") == 0, "moved a stack into the chest")
	check(not b.remove(chest, p) and is_instance_valid(chest), "a chest with items can't be deconstructed")
	var opened: Array = []
	var cb := func(n: Node) -> void: opened.append(n)
	Events.open_container.connect(cb)
	chest.interact(p)
	Events.open_container.disconnect(cb)
	check(opened.size() == 1 and opened[0] == chest, "interacting with a chest opens it")
	check(world.hud._chest.visible and world.hud._chest.container == chest, "the chest window is shown")
	world.hud._chest.close()
	ContainerPanel.transfer(chest.storage, 0, p.inventory)
	# Refunds: 50% outside your land
	wood0 = p.inventory.count_of(&"wood")
	check(b.remove(w, p) and p.inventory.count_of(&"wood") == wood0 + 2, "deconstructing outside your land refunds 50%")
	# Land claims
	var flag := _place_near(world, &"claim_flag", 2, true)
	check(flag != null and b.is_claimed(p.global_position), "claim flag claims the land around you")
	check(not b.is_claimed(flag.global_position + Vector3(30, 0, 0)), "land 30 m away is not claimed")
	var second := BuildingManager.get_piece_data(&"claim_flag")
	check(b.check_place(second, pc + Vector2i(3, 3), "object", p) == "Overlaps land you already claimed", "claims can't overlap")
	var w2 := _place_near(world, &"wood_wall", 2, true)
	wood0 = p.inventory.count_of(&"wood")
	check(b.remove(w2, p) and p.inventory.count_of(&"wood") == wood0 + 4, "deconstructing on your land refunds 100%")
	world.spawner.max_active = 50
	var rule := EnemySpawnRule.new()
	rule.enemy_scene = world.debug_enemy_scene
	rule.enemy_data = load("res://data/enemies/thornback_boar.tres")
	var before := world.spawner.active_count()
	var slot := {"rule": rule, "key": "test_claim_slot", "position": flag.global_position + Vector3(4, 0, 0)}
	check(world.spawner._try_spawn(Vector2i.ZERO, slot) and world.spawner.active_count() == before, "monsters don't spawn on claimed land")
	world.spawner.max_active = 0
	# Shelter
	var hut := _place_near(world, &"wood_wall", 3, false)
	var roof_piece := b.place(roof, hut.cell, "roof", 0, p, false)
	check(roof_piece != null, "roof placed on a wall")
	var inside := Vector3(hut.cell.x + 0.5, hut.global_position.y + 0.5, hut.cell.y + 0.5)
	var outside := inside + Vector3(40, 0, 40)
	check(b.is_sheltered(inside) and not b.is_sheltered(outside), "shelter detected under the roof only")
	world.debug_temperature_offset = -40.0
	var air := world.get_air_temperature(inside)
	check(is_equal_approx(world.get_temperature_at(inside), minf(air + World.SHELTER_EFFECT, TemperatureComponent.COMFORT_MIN)),
		"a roof keeps you %d°C warmer in the cold" % roundi(World.SHELTER_EFFECT))
	world.debug_temperature_offset = 40.0
	air = world.get_air_temperature(inside)
	check(is_equal_approx(world.get_temperature_at(inside), maxf(air - World.SHELTER_EFFECT, TemperatureComponent.COMFORT_MAX)),
		"a roof keeps you cooler in the heat")
	world.debug_temperature_offset = 0.0
	# Torch warmth
	var torch := _place_near(world, &"torch", 2, false)
	check(torch.is_in_group(&"heat_sources") and torch.heat_at(torch.global_position) > 5.0, "torches give a little warmth")
	# Bed
	var bed := _place_near(world, &"bed", 2, false)
	world.day_night.hour = 12.0
	bed.interact(p)
	check(p.spawn_point.distance_to(bed.global_position) < 2.0 and is_equal_approx(world.day_night.hour, 12.0),
		"bed sets the respawn point; no sleeping at noon")
	world.day_night.hour = 23.0
	var hp_max := p.health.max_health
	p.health.current = hp_max * 0.3
	bed.interact(p)
	check(absf(world.day_night.hour - 7.0) < 0.01 and p.health.current > hp_max * 0.6, "sleeping at night skips to 07:00 and heals")
	# Spikes
	var boar := _spawn_boar(world, _clear_offset(world, 5.0))
	var bc := Vector2i(floori(boar.global_position.x), floori(boar.global_position.z))
	var trap := b.place(BuildingManager.get_piece_data(&"spike_trap"), bc, "floor", 0, null, false)
	var hp0 := boar.health.current
	await _frames(80)
	check(trap != null and boar.health.current < hp0, "spike trap hurts monsters (%d -> %d)" % [roundi(hp0), roundi(boar.health.current)])
	check(not p.health.is_dead, "spikes don't hurt the player")
	# Build mode
	var bm := world.build_mode
	bm.set_active(true)
	check(world.hud._palette.visible, "build palette shown in build mode")
	bm.select(BuildingManager.get_piece_data(&"wood_floor"))
	var xp0 := p.character.total_xp
	var target := p.global_position + Vector3(0, 0, 0)
	var placed: BuildPiece = null
	for k in 16:
		var dir := Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0))
		bm._update_target(p.global_position + dir * 3.0)
		placed = bm.place_current()
		if placed:
			break
	check(placed != null and placed.data.id == &"wood_floor", "build mode places the selected piece at the cursor")
	check(p.character.total_xp > xp0, "building grants a little XP")
	bm.set_active(false)
	check(not world.hud._palette.visible, "palette hidden when leaving build mode")
	# Crafting UI
	world.hud._crafting.toggle()
	world.hud._crafting.select(RecipeBook.get_recipe(&"rope"))
	var r0 := p.inventory.count_of(&"rope")
	check(world.hud._crafting.craft_selected(1) == 1 and p.inventory.count_of(&"rope") == r0 + 1, "crafting screen crafts the selected recipe")
	world.hud._crafting.toggle()
	world.queue_free()
	await _frames(5)


func test_building_save_load() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds"
	for wl in SaveManager.list_worlds():
		SaveManager.delete_world(wl.id)
	var id := SaveManager.create_world("Build Test", 4242, &"barbarian")
	var world: World = await _boot_world()
	_clear_enemies(world)
	var p := world.player
	var wall := _place_near(world, &"wood_wall", 2, false)
	var door := _place_near(world, &"wood_door", 2, false)
	door.set_open(true)
	var chest := _place_near(world, &"storage_chest", 2, false)
	chest.storage.add_item(&"iron_ore", 7)
	var flag_pos := _place_near(world, &"claim_flag", 2, false).global_position
	p.recipes.learn(&"hearty_stew")
	var count := world.building.pieces.size()
	var wall_key := BuildingManager.key(wall.cell, wall.slot, wall.layer)
	var chest_key := BuildingManager.key(chest.cell, chest.slot, chest.layer)
	var door_key := BuildingManager.key(door.cell, door.slot, door.layer)
	world.save_now(false)
	world.queue_free()
	await _frames(5)
	check(SaveManager.load_world(id), "load building world")
	world = await _boot_world()
	var b := world.building
	check(b.pieces.size() == count, "all %d pieces restored" % count)
	check(b.pieces.has(wall_key) and b.pieces[wall_key].data.id == &"wood_wall", "wall restored in the same slot")
	check(b.pieces.has(chest_key) and b.pieces[chest_key].storage.count_of(&"iron_ore") == 7, "chest contents restored")
	check(b.pieces.has(door_key) and b.pieces[door_key].is_open, "door state restored")
	check(b.is_claimed(flag_pos), "land claim restored")
	check(world.player.recipes.knows(&"hearty_stew") and world.player.recipes.knows(&"rope"), "known recipes restored")
	world.queue_free()
	await _frames(5)
	SaveManager.delete_world(id)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


# --- Milestone 5: living world ---------------------------------------------------------------

func test_m5_settlements() -> void:
	var g1 := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var g2 := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var list1 := g1.settlements.near(Vector3.ZERO, 3000.0)
	var list2 := g2.settlements.near(Vector3.ZERO, 3000.0)
	var same := list1.size() == list2.size()
	for i in mini(list1.size(), list2.size()):
		same = same and list1[i].id == list2[i].id and list1[i].center == list2[i].center and list1[i].name == list2[i].name
	check(same and list1.size() >= 5, "settlements are deterministic (%d within 3 km)" % list1.size())
	var villages := 0
	var kingdoms := 0
	var flat_ok := true
	var member_ok := true
	var names_ok := true
	for s in list1:
		if s.is_kingdom():
			kingdoms += 1
		else:
			villages += 1
			if s.kingdom_id != "":
				var cap := g1.settlements.find(s.kingdom_id)
				member_ok = member_ok and cap != null and cap.is_kingdom() and Vector2(cap.center - s.center).length() <= Settlements.MEMBERSHIP_RANGE
		names_ok = names_ok and s.name.length() >= 4
		for k in 16:
			var a := TAU * k / 16.0
			for r in [0.0, s.radius * 0.5, s.radius - 1.0]:
				var x := s.center.x + roundi(cos(a) * r)
				var z := s.center.y + roundi(sin(a) * r)
				if g1.get_height_blocks(x, z) != s.height:
					flat_ok = false
	check(villages >= 4 and kingdoms >= 1, "%d villages and %d kingdom capitals near spawn" % [villages, kingdoms])
	check(flat_ok, "settlement ground is flattened to one height")
	check(member_ok, "villages belong to a nearby kingdom (or none)")
	check(names_ok, "settlements have names (e.g. %s, %s)" % [list1[0].title(), list1[-1].title()])
	# No wild props, cave entrances or monster spawns inside towns.
	var s0: SettlementInfo = list1[0]
	var clear := true
	var c0 := TerrainGenerator.world_to_chunk(Vector3(s0.center.x, 0, s0.center.y))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var data := g1.generate_chunk(c0 + Vector2i(dx, dz), 0)
			var origin := Vector3((c0.x + dx) * TerrainGenerator.CHUNK_SIZE, 0, (c0.y + dz) * TerrainGenerator.CHUNK_SIZE)
			for pr in data.props:
				if s0.contains(origin + pr.position):
					clear = false
			for sp in data.spawns:
				if s0.contains(sp.position, 30.0):
					clear = false
	for e in g1.get_cave_entrances_near(s0.center.x - 100, s0.center.y - 100, s0.center.x + 100, s0.center.y + 100):
		if s0.contains(Vector3(e.x, 0, e.y), 20.0):
			clear = false
	check(clear, "towns have no wild trees/rocks, monster spawns or cave entrances")
	# Layouts
	for s in [list1.filter(func(x: SettlementInfo) -> bool: return not x.is_kingdom())[0],
			list1.filter(func(x: SettlementInfo) -> bool: return x.is_kingdom())[0]]:
		var l := SettlementLayout.build(s)
		var overlap := false
		for i in l.buildings.size():
			for j in range(i + 1, l.buildings.size()):
				if (l.buildings[i].rect as Rect2).intersects(l.buildings[j].rect):
					overlap = true
			for f in l.farms:
				if (l.buildings[i].rect as Rect2).intersects(f.rect):
					overlap = true
		check(not overlap, "%s: %d buildings and %d farms don't overlap" % [s.name, l.buildings.size(), l.farms.size()])
		var roles := {}
		for n in l.npcs:
			roles[n.role] = int(roles.get(n.role, 0)) + 1
		if s.is_kingdom():
			check(roles.has(&"noble") and int(roles.get(&"guard", 0)) >= 4 and roles.has(&"royal_merchant") and roles.has(&"blacksmith"),
				"kingdom has a ruler, guards, royal merchant, armorer (%s)" % [roles])
		else:
			check(roles.has(&"merchant") and roles.has(&"blacksmith") and roles.has(&"villager"), "village has merchant, blacksmith, villagers (%s)" % [roles])
		var inside := true
		for b in l.buildings:
			inside = inside and s.contains(l.to_world(b.inside) - Vector3(0.5, 0, 0.5))
		check(inside, "%s: all buildings are inside the flattened area" % s.name)
		check(SettlementLayout.build(s).statics.size() == l.statics.size(), "%s layout is deterministic" % s.name)


func test_m5_economy() -> void:
	check(Economy.format_coins(12345) == "1g 23s 45c" and Economy.format_coins(7) == "7c", "coin formatting (1g 23s 45c)")
	var gen := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var info: SettlementInfo = gen.settlements.near(Vector3.ZERO, 3000.0)[0]
	var arbitrage := false
	for id in ItemDB.all_ids():
		for t in Reputation.TIERS.size():
			if Economy.sell_price(info, id, t, 0.0) >= Economy.buy_price(info, id, t):
				arbitrage = true
	check(not arbitrage, "buying is always dearer than selling back (no money loop)")
	check(Economy.sell_price(info, &"iron_sword", 0, 5.0) < Economy.sell_price(info, &"iron_sword", 0, 0.0), "selling the same item again pays less (saturation)")
	check(Economy.buy_price(info, &"iron_sword", 4) < Economy.buy_price(info, &"iron_sword", 0), "reputation lowers prices")
	var desert := SettlementInfo.new()
	desert.biome_id = &"sunscorch_desert"
	var tundra := SettlementInfo.new()
	tundra.biome_id = &"snowy_tundra"
	check(Economy.buy_price(desert, &"wood", 0) > Economy.buy_price(tundra, &"stone", 0) or Economy.demand(desert, &"wood") > 1.0,
		"wood is dear in the desert (x%.2f)" % Economy.demand(desert, &"wood"))
	check(Economy.demand(desert, &"cactus_fruit") < 1.0 and Economy.demand(tundra, &"hearty_stew") > 1.0, "local produce is cheap, scarce goods are dear")
	var st := Economy.new_shop_state(info, &"blacksmith", 1)
	st.stock["iron_sword"] = 0
	st.sold["iron_sword"] = 4.0
	var next := Economy.roll_day(st, info, &"blacksmith", 2)
	check(int(next.stock["iron_sword"]) >= 1 and float(next.sold["iron_sword"]) == 2.0, "shops restock daily and saturation halves")
	check(Economy.will_buy(&"blacksmith", &"iron_ore") and not Economy.will_buy(&"blacksmith", &"berries") and Economy.will_buy(&"farmer", &"wheat"),
		"shopkeepers buy what fits their trade")
	# Reputation
	var rep := Reputation.new()
	var village := SettlementInfo.new()
	village.id = "v:1,1"
	village.kingdom_id = "k:0,0"
	rep.add(village, 20.0)
	check(rep.tier(village.id) == 1 and is_equal_approx(rep.get_points("k:0,0"), 10.0), "village standing also counts half for its kingdom")
	rep.on_trade(village, 120)
	check(is_equal_approx(rep.get_points(village.id), 22.0), "trading 120 copper gives +2 standing")
	rep.add(village, 500.0)
	check(rep.get_points(village.id) == Reputation.MAX and rep.tier_name(village.id) == "Revered", "standing caps at Revered")
	# Requests
	var r1 := Requests.for_settlement(info, 5)
	var r2 := Requests.for_settlement(info, 5)
	var r3 := Requests.for_settlement(info, 6)
	check(r1.size() >= 2 and str(r1) == str(r2) and str(r1) != str(r3), "daily requests are deterministic and change every day")
	var distinct := {}
	for r in r1:
		if r.type == "deliver":
			distinct[r.item] = true
			check(ItemDB.has_item(r.item) and int(r.reward) > 10, "request: %s" % Requests.describe(r, info))
	# Farming
	check(Farming.stage(&"wheat", 0.0, 0.0) == 0 and Farming.stage(&"wheat", 0.0, 450.0) == 1 and Farming.stage(&"wheat", 0.0, 900.0) == 3,
		"crops grow through stages over world time")
	check(Farming.crop_for_seed(&"carrot_seeds") == &"carrot", "seeds map to crops")


func _nearest(world: World, kingdom: bool) -> SettlementInfo:
	for s in world.generator.settlements.near(world.player.global_position, 4000.0):
		if s.is_kingdom() == kingdom:
			return s
	return null


func _go_to_town(world: World, s: SettlementInfo) -> void:
	var p := world.player
	p.global_position = s.world_center() + Vector3(0.5, 0.4, -1.5)
	p.velocity = Vector3.ZERO
	var frames := 0
	await _frames(2)
	while (not world.chunk_manager.is_near_area_ready() or world.chunk_manager.pending_count() > 0) and frames < 3000:
		await get_tree().process_frame
		frames += 1
	p.global_position = s.world_center() + Vector3(0.5, 0.4, -1.5)
	world.living.update_now(true)
	world.living.finish_sites()
	await _frames(5)


## Moves the player to flat, dry ground just outside a settlement.
func _go_outside(world: World, s: SettlementInfo) -> void:
	var p := world.player
	for k in 16:
		var a := TAU * k / 16.0
		var q := s.world_center() + Vector3(cos(a), 0, sin(a)) * (s.radius + s.blend + 8.0)
		if not world.is_in_water(q) and absf(world.get_ground_height(q) - s.ground_y()) < 3.0:
			p.global_position = Vector3(q.x, world.get_ground_height(q) + 0.3, q.z)
			break
	await _frames(20)


func test_m5_living() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	_clear_enemies(world)
	check(p.coins == World.STARTING_COINS, "new characters start with %s" % Economy.format_coins(p.coins))
	var v := _nearest(world, false)
	if not check(v != null, "found a village"):
		world.queue_free()
		return
	world.day_night.hour = 10.0
	var xp0 := p.character.total_xp
	await _go_to_town(world, v)
	var site := world.living.site_of(v)
	check(site != null and site.npcs.size() >= 5, "%s streamed in with %d townsfolk" % [v.name, site.npcs.size() if site else 0])
	check(world.living.current == v and world.living.is_discovered(v.id), "entering discovers the village")
	check(p.reputation.get_points(v.id) >= 2.0 and p.character.total_xp > xp0, "first visit: +2 standing and XP")
	check(world.hud._town_label.text.begins_with(v.name), "HUD shows the current settlement (%s)" % world.hud._town_label.text)
	# Terrain/buildings
	check(absf(world.get_ground_height(v.world_center()) - v.ground_y()) < 0.01, "village ground is flat")
	var body_count := 0
	for c in site.get_children():
		if c is StaticBody3D:
			body_count += c.get_child_count()
	check(body_count > 50, "buildings have collision (%d shapes)" % body_count)
	# Paths: every door reaches the plaza along clear streets.
	var paths_ok := true
	for b in site.layout.buildings:
		var path := site.find_path(b.door_out, site.layout.points.plaza[0])
		var prev: Vector3 = b.door_out
		for q in path:
			if not site._segment_clear_any(prev, q):
				paths_ok = false
			prev = q
	check(paths_ok, "every house door reaches the plaza without walking through walls")
	# Routines
	var merchant := site.npc_by_role(&"merchant")
	check(merchant != null and merchant.activity == &"work" and merchant.is_open(), "at 10:00 the merchant is at the stall")
	world.day_night.hour = 23.5
	for n in site.npcs:
		n._update_activity(true)
	check(merchant.asleep and not merchant.visible and not merchant.is_interactable(), "at night the merchant sleeps at home")
	var guard_count := 0
	for n in site.npcs:
		if n.asleep:
			guard_count += 1
	world.day_night.hour = 10.0
	for n in site.npcs:
		n._think = 0.0
	await _frames(10)
	check(not merchant.asleep and (merchant._path.size() > 0 or merchant.activity == &"work"), "in the morning the merchant walks to work")
	var walked := merchant.position
	await _frames(90)
	check(merchant.position.distance_to(walked) > 0.5 or merchant._path.is_empty(), "townsfolk actually walk their routes")
	for n in site.npcs:
		n._update_activity(true)
	# Talk
	world.hud._dialogue.open(merchant)
	check(world.hud._dialogue.visible and merchant.talking, "talking opens the dialogue")
	var gossip := Gossip.lines(merchant, world.living)
	check(gossip.size() >= 3, "townsfolk share real gossip (%d lines): \"%s\"" % [gossip.size(), gossip[0] if not gossip.is_empty() else ""])
	world.hud._dialogue.close()
	# Trade
	p.global_position = site.to_global(merchant.position) + Vector3(0, 0.3, 1.5)
	p.coins = 500
	var st := world.living.shop_state(v, &"merchant")
	var rope_stock := int(st.stock.get("rope", 0))
	var price := world.living.buy_price(v, &"merchant", &"rope")
	var rope0 := p.inventory.count_of(&"rope")
	check(world.living.buy(v, &"merchant", &"rope") == "" and p.coins == 500 - price and p.inventory.count_of(&"rope") == rope0 + 1
		and int(st.stock["rope"]) == rope_stock - 1, "bought rope for %s" % Economy.format_coins(price))
	check(world.living.buy(v, &"merchant", &"cooks_journal").begins_with("Requires"), "better stock needs reputation")
	p.inventory.add_item(&"boar_hide", 5)
	var hide_slot := -1
	for i in p.inventory.capacity:
		var sl = p.inventory.get_slot(i)
		if sl != null and sl.id == &"boar_hide":
			hide_slot = i
	var sp1 := world.living.sell_price(v, &"merchant", &"boar_hide")
	var coins1 := p.coins
	check(world.living.sell(v, &"merchant", hide_slot, 1) == "" and p.coins == coins1 + sp1, "sold a boar hide for %s" % Economy.format_coins(sp1))
	world.living.sell(v, &"merchant", hide_slot, 3)
	check(world.living.sell_price(v, &"merchant", &"boar_hide") < sp1, "selling more hides lowers their price (%s -> %s)" % [
		Economy.format_coins(sp1), Economy.format_coins(world.living.sell_price(v, &"merchant", &"boar_hide"))])
	check(world.living.sell(v, &"blacksmith", hide_slot, 1) == "Not interested in that", "the blacksmith doesn't buy hides")
	world.hud._trade.open(merchant)
	check(world.hud._trade.visible and world.hud._trade._buy_list.get_child_count() > 3, "trade window lists the stock")
	world.hud._trade.close()
	# Requests
	var reqs := world.living.requests(v)
	var deliver: Dictionary = {}
	for r in reqs:
		if r.type == "deliver":
			deliver = r
			break
	p.inventory.add_item(deliver.item, int(deliver.count))
	var rep0 := p.reputation.get_points(v.id)
	var coins2 := p.coins
	check(world.living.complete_request(v, deliver) == "" and p.coins == coins2 + int(deliver.reward) and p.reputation.get_points(v.id) > rep0,
		"delivery request pays %s and reputation" % Economy.format_coins(int(deliver.reward)))
	check(world.living.complete_request(v, deliver) == "Already done", "requests can only be done once")
	world.hud._requests.open(site)
	check(world.hud._requests.visible and world.hud._requests._list.get_child_count() == reqs.size(), "notice board lists today's requests")
	world.hud._requests.close()
	# Hunt progress
	var boar := _spawn_boar(world, Vector3(0, 0, 30))
	var hunt_id := "%s:%d:hunt" % [v.id, world.day_night.day]
	var before := int(world.living.hunt_progress.get(hunt_id, 0))
	Events.enemy_killed.emit(boar, &"thornback_boar", v.world_center() + Vector3(60, 0, 0))
	var has_hunt := false
	for r in reqs:
		has_hunt = has_hunt or r.type == "hunt"
	check(not has_hunt or int(world.living.hunt_progress.get(hunt_id, 0)) == before + 1, "monster kills near town count for hunt requests")
	# Building is not allowed inside towns.
	check(world.building.check_place(BuildingManager.get_piece_data(&"wood_wall"), Vector2i(floori(p.global_position.x) + 2, floori(p.global_position.z)), "edge_n", p)
		== "This land belongs to %s" % v.name, "you can't build inside a village")
	# Farming (outside town)
	await _go_outside(world, v)
	var plot := _place_near(world, &"farm_plot", 2, false)
	p.inventory.add_item(&"wheat_seeds", 2)
	check(plot != null and plot.farm_interact(p) == &"planted" and plot.crop == &"wheat", "planted wheat on a farm plot")
	check(plot.farm_interact(p) == &"growing", "crops need time to grow")
	GameState.world_time += 1000.0
	plot.update_crop_visual()
	var wheat0 := p.inventory.count_of(&"wheat")
	check(plot.farm_interact(p) == &"harvested" and p.inventory.count_of(&"wheat") >= wheat0 + 2 and plot.crop == &"", "ripe wheat harvested")
	p.inventory.add_item(&"wheat", 3)
	var fire := (ItemDB.get_item(&"campfire_kit") as ItemData).placeable_scene.instantiate() as Node3D
	world.placed_root.add_child(fire)
	fire.global_position = p.global_position + Vector3(1.5, 0, 0)
	check(Crafting.craft(p, RecipeBook.get_recipe(&"bread"), Crafting.stations_near(get_tree(), p.global_position)) == 1, "baked bread at a campfire")
	fire.queue_free()
	# Village smithy is a usable crafting station.
	var smith := site.npc_by_role(&"blacksmith")
	p.global_position = site.to_global(smith.data.work) + Vector3(0, 0.3, 0)
	await _frames(3)
	check(Crafting.stations_near(get_tree(), p.global_position).has(&"forge"), "the village forge works as a crafting station")
	world.queue_free()
	await _frames(5)


func test_m5_kingdom() -> void:
	var world: World = await _boot_class(&"barbarian")
	var p := world.player
	_clear_enemies(world)
	var k := _nearest(world, true)
	if not check(k != null, "found a kingdom capital"):
		world.queue_free()
		return
	world.day_night.hour = 11.0
	await _go_to_town(world, k)
	var site := world.living.site_of(k)
	check(site != null and site.npc_by_role(&"noble") != null, "%s has a ruler: %s" % [k.title(), site.npc_by_role(&"noble").full_name() if site else ""])
	var guards := 0
	for n in site.npcs:
		if n.role == &"guard":
			guards += 1
	check(guards >= 4, "%d guards" % guards)
	# Recognition
	var noble := site.npc_by_role(&"noble")
	check(world.living.recognition(k).begins_with("Serve"), "strangers get no title")
	p.reputation.add(k, 65.0)
	var coins0 := p.coins
	var answer := world.living.recognition(k)
	check(answer.begins_with("By my decree") and p.inventory.count_of(&"royal_signet") == 1 and p.coins == coins0 + 100,
		"at Honored the ruler grants titles and gifts: %s" % p.reputation.title_for(k.id, k.kingdom_name))
	check(world.living.recognition(k).begins_with("You already"), "titles are granted once")
	check(noble.is_interactable(), "the ruler can be talked to at court")
	# Guards defend the town.
	var guard: NPC = null
	for n in site.npcs:
		if n.role == &"guard":
			guard = n
			break
	var xp0 := p.character.total_xp
	var boar := world.spawner.spawn_enemy(world.debug_enemy_scene, guard.global_position + Vector3(4, 0.3, 0), "")
	boar.stagger(20.0)
	boar.health.current = 30.0
	var frames := 0
	while not boar.is_dead and frames < 900:
		await get_tree().physics_frame
		frames += 1
	check(boar.is_dead, "guards kill monsters that come near (%d frames)" % frames)
	check(p.character.total_xp == xp0, "no XP for kills made by guards")
	# Save / load of living-world state
	world.queue_free()
	await _frames(5)


func test_m5_save_load() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds"
	for wl in SaveManager.list_worlds():
		SaveManager.delete_world(wl.id)
	var id := SaveManager.create_world("Living Test", GameState.DEFAULT_SEED, &"wizard")
	var world: World = await _boot_world()
	_clear_enemies(world)
	var p := world.player
	var v := _nearest(world, false)
	world.day_night.hour = 10.0
	await _go_to_town(world, v)
	p.coins = 777
	p.reputation.add(v, 33.0)
	world.living.buy(v, &"merchant", &"rope")
	var stock := int(world.living.shop_state(v, &"merchant").stock["rope"])
	var req: Dictionary = world.living.requests(v)[0]
	if req.type == "deliver":
		p.inventory.add_item(req.item, int(req.count))
	world.living.complete_request(v, req)
	var coins := p.coins
	var rep := p.reputation.get_points(v.id)
	await _go_outside(world, v)
	var plot := _place_near(world, &"farm_plot", 2, false)
	p.inventory.add_item(&"carrot_seeds", 1)
	plot.farm_interact(p)
	var plot_key := BuildingManager.key(plot.cell, plot.slot, plot.layer)
	world.save_now(false)
	world.queue_free()
	await _frames(5)
	check(SaveManager.load_world(id), "load living world")
	world = await _boot_world()
	p = world.player
	check(p.coins == coins and is_equal_approx(p.reputation.get_points(v.id), rep), "coins and reputation restored")
	check(int(world.living.shop_state(v, &"merchant").stock["rope"]) == stock, "shop stock restored")
	check(world.living.requests(v)[0].done, "completed requests stay completed")
	check(world.living.is_discovered(v.id), "discovered settlements restored")
	var plot2: BuildPiece = world.building.pieces.get(plot_key)
	check(plot2 != null and plot2.crop == &"carrot", "planted crops restored")
	world.queue_free()
	await _frames(5)
	SaveManager.delete_world(id)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


# --- Milestone 6: exploration ---------------------------------------------------------------

func test_m6_data() -> void:
	var monsters := 0
	var ok := true
	for f in ResourceLoader.list_directory("res://data/enemies/"):
		var md := load("res://data/enemies/" + f) as MonsterData
		if md == null:
			continue
		monsters += 1
		if md.melee == null or md.max_health <= 0.0:
			ok = false
			print("   %s: no melee attack" % md.id)
		if md.style == MonsterData.Style.BOSS and (md.boss_title == "" or md.boss_moves.is_empty() or md.heavy == null):
			ok = false
			print("   boss %s incomplete" % md.id)
		if md.style in [MonsterData.Style.RANGED, MonsterData.Style.CASTER] and md.projectile_damage <= 0.0:
			ok = false
	check(monsters >= 11 and ok, "%d monster types with valid attacks, bosses have titles and move sets" % monsters)
	for theme in PoiLayout.THEME_MONSTERS:
		for id in theme:
			check(load("res://data/enemies/%s.tres" % id) is MonsterData, "theme monster %s exists" % id)
	var legendary := 0
	var scroll_ok := true
	for sc in LootTables.SCROLLS:
		var it: ItemData = ItemDB.get_item(sc)
		var target: ItemData = ItemDB.get_item(StringName(it.teaches_recipes[0])) if it else null
		var r := RecipeBook.get_recipe(StringName(it.teaches_recipes[0])) if it else null
		if target and target.rarity == ItemData.Rarity.LEGENDARY and r and r.tier == 6 and r.required_crafting() == 90:
			legendary += 1
		else:
			scroll_ok = false
	check(scroll_ok and legendary == 7, "7 legendary recipe scrolls teach legendary gear (Crafting 90)")
	var heal: ItemData = ItemDB.get_item(&"healing_draught")
	var might: ItemData = ItemDB.get_item(&"elixir_of_might")
	var tonic: ItemData = ItemDB.get_item(&"mana_tonic")
	check(heal.health_restore > 0 and might.buff_id == &"might" and tonic.mana_restore > 0 and might.effect_lines().size() > 0, "potions heal, restore mana and grant buffs")
	var lib := PropLibrary.new()
	for pid in [&"sunbloom", &"frost_lotus", &"emberroot", &"dreamcap", &"starlight_orchid", &"ore_mithril"]:
		var pd := lib.get_prop(pid)
		check(pd != null and lib.get_mesh(pid) != null and not pd.drops.is_empty(), "rare prop %s exists" % pid)
	var in_biomes := {}
	for biome in _settings().biomes:
		for rule in biome.prop_rules:
			in_biomes[rule.prop_id] = true
	check(in_biomes.has(&"sunbloom") and in_biomes.has(&"frost_lotus") and in_biomes.has(&"emberroot") and in_biomes.has(&"dreamcap")
		and in_biomes.has(&"ore_mithril") and not in_biomes.has(&"starlight_orchid"), "magical plants grow in their biomes; starlight orchids only in hidden groves")
	check(lib.get_prop(&"ore_mithril").tool_tier == 3 and ItemDB.get_item(&"mithril_pickaxe").tool_tier == 4, "mithril needs an iron pickaxe; mithril tools are tier 4")


func test_m6_pois() -> void:
	var g1 := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var g2 := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var a := g1.pois.near(Vector3.ZERO, 3000.0)
	var b := g2.pois.near(Vector3.ZERO, 3000.0)
	var same := a.size() == b.size()
	for i in mini(a.size(), b.size()):
		same = same and a[i].id == b[i].id and a[i].kind == b[i].kind and a[i].rank == b[i].rank
	check(same and a.size() > 20, "points of interest are deterministic (%d within 3 km)" % a.size())
	var kinds := {}
	var near_rank := 0.0
	var far_rank := 0.0
	var nn := 0
	var nf := 0
	var towns_ok := true
	var flat_ok := true
	for p in a:
		kinds[p.kind] = true
		if p.distance_to(Vector3.ZERO) < 1000.0:
			near_rank += p.rank
			nn += 1
		elif p.distance_to(Vector3.ZERO) > 2200.0:
			far_rank += p.rank
			nf += 1
		for s in g1.settlements.near(p.world_center(), 200.0):
			if s.distance_to(p.world_center()) < s.radius + p.radius + 20.0:
				towns_ok = false
		if p.flatten:
			for k in 8:
				var ang := TAU * k / 8.0
				if g1.get_height_blocks(p.center.x + roundi(cos(ang) * (p.radius - 1.0)), p.center.y + roundi(sin(ang) * (p.radius - 1.0))) != p.height:
					flat_ok = false
	check(kinds.size() == 5, "all five kinds exist: ruins, towers, temples, dungeons, hidden groves")
	check(nf > 0 and nn > 0 and far_rank / nf > near_rank / nn + 1.0, "danger grows with distance (avg rank %.1f near, %.1f far)" % [near_rank / maxi(nn, 1), far_rank / maxi(nf, 1)])
	check(towns_ok, "points of interest keep clear of villages and kingdoms")
	check(flat_ok, "structures stand on flattened ground")
	var clear := true
	for p in a.slice(0, 6):
		var c0 := TerrainGenerator.world_to_chunk(Vector3(p.center.x, 0, p.center.y))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var data := g1.generate_chunk(c0 + Vector2i(dx, dz), 0)
				var origin := Vector3((c0.x + dx) * TerrainGenerator.CHUNK_SIZE, 0, (c0.y + dz) * TerrainGenerator.CHUNK_SIZE)
				for pr in data.props:
					if p.contains(origin + pr.position):
						clear = false
	check(clear, "no wild props inside points of interest")
	# Layouts
	for kind in 5:
		var poi: PoiInfo = null
		for p in a:
			if p.kind == kind:
				poi = p
				break
		if poi == null:
			continue
		var l := PoiLayout.build(poi)
		match kind:
			PoiInfo.Kind.RUINS:
				check(not l.guardians.is_empty() and l.chests.size() == 1, "%s: skeleton guardians and a chest" % poi.title())
			PoiInfo.Kind.TOWER:
				check(l.objects.any(func(o: Dictionary) -> bool: return o.kind == PoiObject.Kind.LECTERN) and l.doors.size() == 1, "%s: warden, lectern and door" % poi.title())
			PoiInfo.Kind.TEMPLE:
				check(l.guardians[0].data == &"temple_guardian" and l.chests[0].sealed and l.chests[0].table == &"temple", "%s: dormant guardian boss and sealed chest" % poi.title())
			PoiInfo.Kind.DUNGEON:
				check(l.objects.any(func(o: Dictionary) -> bool: return o.kind == PoiObject.Kind.ENTRANCE), "%s: entrance" % poi.title())
			PoiInfo.Kind.GROVE:
				check(l.objects.filter(func(o: Dictionary) -> bool: return o.kind == PoiObject.Kind.PLANT).size() >= 4 and poi.is_hidden(), "%s: hidden, with magical plants" % poi.title())
	# Dungeon plans for every rank
	for r in 6:
		var poi := PoiInfo.new()
		poi.rank = r
		poi.seed = 1234 + r
		poi.theme = r % 3
		var floors: int = DungeonPlan.FLOORS[r]
		var all_ok := true
		for f in floors:
			var plan := DungeonPlan.generate(poi, f)
			var types := {}
			for room in plan.rooms:
				types[room.type] = true
			if not types.has(DungeonPlan.Room.START) or not types.has(DungeonPlan.Room.BOSS if plan.is_final else DungeonPlan.Room.END):
				all_ok = false
			# Every room reachable over floor cells from the start.
			var seen := {}
			var start := Vector2i(plan.room_center(plan.start_room).x, plan.room_center(plan.start_room).z)
			var q: Array[Vector2i] = [start]
			seen[start] = true
			while not q.is_empty():
				var c: Vector2i = q.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if plan.cells.has(n) and not seen.has(n):
						seen[n] = true
						q.append(n)
			if seen.size() != plan.cells.size():
				all_ok = false
			if r >= 1 and plan.secret.is_empty():
				pass  # a secret needs a free neighbouring slot; usually present
		check(all_ok, "rank %s dungeon: %d floor(s), start, stairs/boss, all rooms connected" % [PoiInfo.RANKS[r], floors])
	# Loot
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var void_at_e := 0
	for i in 200:
		var roll := LootTables.roll(&"dungeon_chest", 0, rng)
		void_at_e += int(roll.items.get(&"void_shard", 0))
	check(void_at_e == 0, "rare resources are rank-gated (no void shards from rank E chests)")
	var temple := LootTables.roll(&"temple", 2, rng, true)
	var has_scroll := false
	for id in temple.items:
		has_scroll = has_scroll or String(id).begins_with("scroll_")
	check(has_scroll and int(temple.coins) > 0, "temple chests always hold a legendary recipe")


func _spawn_monster(world: World, id: StringName, offset: Vector3, rank: int = 0) -> Monster:
	var pos := world.player.global_position + offset
	pos.y = world.get_ground_height(pos) + 0.3
	var m := world.spawner.spawn_enemy(load("res://scenes/enemies/monster.tscn"), pos, "", load("res://data/enemies/%s.tres" % id)) as Monster
	m.configure(PoiLayout.RANK_POWER[rank], PoiLayout.RANK_DAMAGE[rank], PoiLayout.RANK_LEVELS[rank], PoiLayout.RANK_XP[rank])
	return m


func test_m6_combat() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	_clear_enemies(world)
	world.spawner.max_active = 50
	# Melee
	var sk := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 3.0))
	check(sk != null and sk.mdata.look == &"skeleton" and (sk.model as MonsterModel).rig is HumanoidModel, "skeleton warrior spawned with a skeleton model")
	p.health.reset_full()
	var hp0 := p.health.current
	var frames := 0
	while p.health.current >= hp0 and frames < 600:
		await get_tree().physics_frame
		frames += 1
	check(p.health.current < hp0, "skeleton warriors attack (%d frames)" % frames)
	var xp0 := p.character.total_xp
	sk.health.current = 1.0
	sk.receive_hit(DamageInfo.create(50.0, p, &"physical"))
	check(sk.is_dead and p.character.total_xp > xp0, "killing monsters grants XP")
	await _frames(5)
	# Ranged
	var archer := _spawn_monster(world, &"skeleton_archer", _clear_offset(world, 8.0))
	p.health.reset_full()
	hp0 = p.health.current
	frames = 0
	var shot := false
	while frames < 900 and p.health.current >= hp0:
		await get_tree().physics_frame
		frames += 1
		shot = shot or archer.ai == Monster.AI.SHOOT
	check(shot and p.health.current < hp0, "archers shoot arrows that hit (%d frames)" % frames)
	archer.health.current = 0.1
	archer.receive_hit(DamageInfo.create(50.0, p))
	# Poison
	var crawler := _spawn_monster(world, &"thorn_crawler", _clear_offset(world, 2.0))
	frames = 0
	while not p.afflictions.has(&"poison") and frames < 600:
		p.health.reset_full()
		await get_tree().physics_frame
		frames += 1
	check(p.afflictions.has(&"poison"), "thorn crawler bites poison the player")
	crawler.health.current = 0.1
	crawler.receive_hit(DamageInfo.create(50.0, p))
	p.health.reset_full()
	var hp1 := p.health.current
	await _frames(70)
	check(p.health.current < hp1, "poison deals damage over time")
	# Rank scaling
	var e_rank := _spawn_monster(world, &"skeleton_warrior", Vector3(20, 0, 0), 0)
	var s_rank := _spawn_monster(world, &"skeleton_warrior", Vector3(22, 0, 0), 5)
	check(s_rank.health.max_health >= e_rank.health.max_health * PoiLayout.RANK_POWER[5] * 0.98 and s_rank.xp_value() > e_rank.xp_value() \
			and s_rank.effective_level() == e_rank.effective_level() + PoiLayout.RANK_LEVELS[5],
		"rank S monsters have x%.0f health, more XP and +%d levels" % [PoiLayout.RANK_POWER[5], PoiLayout.RANK_LEVELS[5]])
	e_rank.health.current = 0.1
	e_rank.receive_hit(DamageInfo.create(50.0, p))
	s_rank.health.current = 0.1
	s_rank.receive_hit(DamageInfo.create(50.0, p))
	# Boss
	var king := _spawn_monster(world, &"bone_king", _clear_offset(world, 6.0))
	king.health.current = king.health.max_health
	frames = 0
	while not world.hud._boss_panel.visible and frames < 300:
		await get_tree().physics_frame
		frames += 1
	check(world.hud._boss_panel.visible and world.hud._boss_name.text.begins_with("The Bone King"), "boss bar shows The Bone King")
	king.health.current = king.health.max_health * 0.45
	king._special_cd = 0.0
	var summoned := false
	var seen_special := {}
	frames = 0
	while frames < 900 and (not summoned or not king.enraged):
		p.health.reset_full()
		await get_tree().physics_frame
		frames += 1
		seen_special[king.ai] = true
		summoned = summoned or king._summons_done > 0
	check(king.enraged, "bosses enrage below half health")
	check(summoned, "the Bone King summons skeletons")
	king.health.current = 0.1
	king.receive_hit(DamageInfo.create(50.0, p))
	await _frames(3)
	check(not world.hud._boss_panel.visible, "boss bar hides when the boss dies")
	# Potions
	p.health.current = 20.0
	p.inventory.add_item(&"healing_draught", 1)
	p.inventory.add_item(&"elixir_of_might", 1)
	p.inventory.add_item(&"mana_tonic", 1)
	for id in [&"healing_draught", &"elixir_of_might", &"mana_tonic"]:
		for i in p.inventory.capacity:
			var s = p.inventory.get_slot(i)
			if s != null and s.id == id:
				p.use_slot(i)
				break
	check(p.health.current >= 89.0, "healing draught heals")
	check(p.abilities.has_buff(&"might") and is_equal_approx(p.abilities.outgoing_mult(), 1.2), "elixir of might: +20% damage")
	world.queue_free()
	await _frames(5)


func _nearest_poi(world: World, kind: int, max_rank: int = 5) -> PoiInfo:
	for p in world.generator.pois.near(world.player.global_position, 4000.0):
		if p.kind == kind and p.rank <= max_rank:
			return p
	return null


func _go_to_poi(world: World, poi: PoiInfo, offset: Vector3 = Vector3(0, 0, 0)) -> PoiSite:
	var p := world.player
	p.global_position = poi.world_center() + offset + Vector3(0, 0.5, 0)
	p.velocity = Vector3.ZERO
	var frames := 0
	await _frames(2)
	while (not world.chunk_manager.is_near_area_ready() or world.chunk_manager.pending_count() > 0) and frames < 3000:
		await get_tree().process_frame
		frames += 1
	p.global_position = poi.world_center() + offset + Vector3(0, 0.5, 0)
	world.exploration.update_now(true)
	await _frames(5)
	return world.exploration.site_of(poi)


func _kill(m: Enemy, world: World) -> void:
	if is_instance_valid(m) and not m.is_dead:
		if m is Monster:
			(m as Monster)._iframes = 0.0  # a mid-dodge monster would shrug off the killing hit
		m.health.invulnerable = false
		m.health.current = 0.1
		m.receive_hit(DamageInfo.create(99.0, world.player, &"true"))


func test_m6_pois_ingame() -> void:
	var world: World = await _boot_class(&"wizard")
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	world.spawner.max_active = 60
	# Ruins
	var ruins := _nearest_poi(world, PoiInfo.Kind.RUINS)
	var site := await _go_to_poi(world, ruins, Vector3(0, 0, 3))
	check(site != null and site.guardians.size() >= 2, "%s streamed in with %d guardians" % [ruins.title(), site.guardians.size() if site else 0])
	check(world.exploration.is_discovered(ruins.id), "visiting discovers the ruins")
	var coins0 := p.coins
	var chest: LootChest = site.chests[0]
	chest.open()
	check(p.coins > coins0 and world.exploration.has_state("open:" + chest.persist_key), "chest gives coins and stays opened")
	# A ruin with a hidden vault
	var vault_ruin: PoiInfo = null
	for q in world.generator.pois.near(p.global_position, 4000.0):
		if q.kind == PoiInfo.Kind.RUINS and not PoiLayout.build(q).cracked.is_empty():
			vault_ruin = q
			break
	if vault_ruin:
		var vs := await _go_to_poi(world, vault_ruin, Vector3(0, 0, 3))
		var cb: CrackedBlock = null
		for c in vs.get_children():
			if c is CrackedBlock:
				cb = c
		var before := vs.chests.size()
		for i in 3:
			cb.receive_hit(DamageInfo.create(10.0, p))
		await _frames(2)
		check(vs.chests.size() == before + 1 and vs.chests[-1].table == &"vault", "breaking the cracked floor reveals a hidden vault")
	# Tower lectern
	var tower := _nearest_poi(world, PoiInfo.Kind.TOWER)
	var ts := await _go_to_poi(world, tower, Vector3(0, 0, 0.5))
	var lectern: PoiObject = null
	for c in ts.get_children():
		if c is PoiObject and c.kind == PoiObject.Kind.LECTERN:
			lectern = c
	var inv0 := p.inventory.slots.filter(func(x) -> bool: return x != null).size()
	lectern.interact(p)
	check(p.inventory.slots.filter(func(x) -> bool: return x != null).size() > inv0 and not lectern.is_available(), "the tower lectern holds a recipe tome (once)")
	check(ts.guardians.any(func(m: Monster) -> bool: return m.data.id == &"tower_warden"), "a Tower Warden guards the tower")
	# Temple
	var temple := _nearest_poi(world, PoiInfo.Kind.TEMPLE)
	if check(temple != null, "found a temple"):
		var tsite := await _go_to_poi(world, temple, Vector3(0, 0, 14))
		var guardian: Monster = tsite.guardians[0]
		check(guardian.ai == Monster.AI.DORMANT and tsite.chests[0].locked_reason != "", "the temple guardian sleeps and the chest is sealed")
		_kill(guardian, world)
		await _frames(3)
		check(world.exploration.has_state("cleared:" + temple.id) and tsite.chests[0].locked_reason == "", "defeating the guardian cleanses the temple")
		var altar: PoiObject = null
		for c in tsite.get_children():
			if c is PoiObject and c.kind == PoiObject.Kind.ALTAR:
				altar = c
		altar.interact(p)
		check(p.abilities.has_buff(&"blessing"), "praying at the altar grants the Blessing of the Ancients")
		var roll: Dictionary = tsite.chests[0].open()
		var got_scroll := false
		for item in roll.items:
			got_scroll = got_scroll or String(item).begins_with("scroll_")
		check(got_scroll, "the temple chest holds a legendary recipe")
	# Hidden grove
	var grove := _nearest_poi(world, PoiInfo.Kind.GROVE)
	var xp0 := p.character.total_xp
	var gs := await _go_to_poi(world, grove, Vector3(0, 0, 1))
	check(world.exploration.is_discovered(grove.id) and p.character.total_xp >= xp0 + 100, "finding a hidden grove: discovery + big XP")
	var plant: PoiObject = null
	for c in gs.get_children():
		if c is PoiObject and c.kind == PoiObject.Kind.PLANT and c.item_id == &"starlight_orchid":
			plant = c
	var o0 := p.inventory.count_of(&"starlight_orchid")
	plant.interact(p)
	check(p.inventory.count_of(&"starlight_orchid") == o0 + 1 and not plant.is_available(), "picked a starlight orchid (it regrows later)")
	world.queue_free()
	await _frames(5)


func test_m6_dungeon() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds"
	for wl in SaveManager.list_worlds():
		SaveManager.delete_world(wl.id)
	var id := SaveManager.create_world("Dungeon Test", GameState.DEFAULT_SEED, &"barbarian")
	var world: World = await _boot_world()
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	world.spawner.max_active = 60
	var dpoi := _nearest_poi(world, PoiInfo.Kind.DUNGEON, 1)
	await _go_to_poi(world, dpoi, Vector3(0, 0, 3))
	var entrance := p.global_position
	check(world.enter_dungeon(dpoi) and world.dungeon != null, "entered %s" % dpoi.title())
	await _frames(10)
	var d := world.dungeon
	check(absf(p.global_position.y - DungeonInstance.ORIGIN.y) < 2.0 and p.is_on_floor(), "standing on the dungeon floor")
	check(d.alive_count() >= 3 and d.boss != null, "%d monsters and a boss (%s)" % [d.alive_count(), d.boss.display_name() if d.boss else "-"])
	check(not world.chunk_manager.visible and world.hud._biome_label.text.begins_with(dpoi.title().split(" (")[0]), "the surface is paused while inside")
	world.hud._map.toggle()
	await _frames(3)
	check(world.hud._map._title.text.contains("Floor"), "the map shows the dungeon floor")
	world.hud._map.toggle()
	# Saving inside stores the entrance.
	var save := p.to_save()
	check(Vector3(save.position[0], save.position[1], save.position[2]).distance_to(d.return_position) < 0.1, "saving inside a dungeon stores its entrance")
	# Secret room
	if not d.plan.secret.is_empty():
		var cb: CrackedBlock = null
		for c in d.get_children():
			if c is CrackedBlock:
				cb = c
		for i in 3:
			cb.receive_hit(DamageInfo.create(10.0, p))
		await _frames(2)
		check(not is_instance_valid(cb) or cb.is_queued_for_deletion(), "cracked walls hide secret rooms")
	# Traps hurt
	var trap: DungeonTrap = null
	for c in d.get_children():
		if c is DungeonTrap:
			trap = c
	if trap:
		p.health.invulnerable = false
		p.health.reset_full()
		p.global_position = trap.global_position + Vector3(0, 0.3, 0)
		var hp0 := p.health.current
		var frames := 0
		while p.health.current >= hp0 and frames < 240:
			p.global_position = trap.global_position + Vector3(0, 0.3, 0)
			await get_tree().physics_frame
			frames += 1
		check(p.health.current < hp0, "spike traps hurt when they spring up")
		p.health.invulnerable = true
	# Descend and fight the boss.
	var floors := d.plan.floor_count
	while not world.dungeon.plan.is_final:
		world.next_dungeon_floor()
		await _frames(5)
	d = world.dungeon
	check(d.plan.is_final and d.floor_index == floors - 1, "descended to the last floor (%d)" % floors)
	for m in d.monsters:
		if not m.is_boss():
			_kill(m, world)
	var arena := d.to_global(d.plan.room_center(d.plan.end_room) + Vector3(0, 0.3, 3.0))
	p.global_position = arena
	var frames2 := 0
	while not d.boss_started and frames2 < 120:
		p.global_position = arena
		await get_tree().physics_frame
		frames2 += 1
	check(d.boss_started and d._gate != null, "entering the arena seals the gate")
	_kill(d.boss, world)
	await _frames(5)
	check(d.cleared and world.exploration.has_state("dungeon:" + dpoi.id), "boss defeated: dungeon cleared")
	var portal := false
	var boss_chest := false
	for c in d.get_children():
		portal = portal or (c is DungeonDoor and c.kind == DungeonDoor.Kind.EXIT and d.plan.room_at(c.position) == d.plan.end_room)
		boss_chest = boss_chest or (c is LootChest and c.table == &"dungeon_boss")
	check(portal and boss_chest, "a portal home and the boss chest appear")
	world.exit_dungeon()
	var waited := await _wait_ready(world)
	check(world.dungeon == null and p.global_position.distance_to(entrance) < 6.0 and world.chunk_manager.visible, "back at the entrance (%d frames)" % waited)
	check(not world.enter_dungeon(dpoi), "a cleared dungeon stays empty for a while")
	# Death inside a dungeon carries you out.
	world.exploration.state.erase("dungeon:" + dpoi.id)
	world.enter_dungeon(dpoi)
	await _frames(5)
	p.health.invulnerable = false
	p.health.apply_damage(DamageInfo.create(9999.0, null, &"true"))
	await _frames(3)
	p.respawn()
	await _wait_ready(world)
	check(world.dungeon == null and world.layer == TerrainGenerator.Layer.SURFACE, "dying in a dungeon puts you back on the surface")
	# Save / load of exploration state
	world.exploration.set_state("dungeon:" + dpoi.id)
	world.save_now(false)
	world.queue_free()
	await _frames(5)
	SaveManager.load_world(id)
	world = await _boot_world()
	check(world.exploration.has_state("dungeon:" + dpoi.id) and world.exploration.is_discovered(dpoi.id), "exploration progress is saved")
	world.queue_free()
	await _frames(5)
	SaveManager.delete_world(id)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


# --- Milestone 7: advanced gameplay ---------------------------------------------------------

func test_m7_data() -> void:
	const MOVES := [&"cleave", &"slam", &"volley", &"charge", &"summon", &"spikes", &"nova", &"beam", &"meteor_rain",
		&"teleport", &"shield", &"pull", &"roar", &"bomb"]
	for id in [&"bone_king", &"arcane_colossus", &"elder_thornmaw", &"temple_guardian", &"bandit_warlord", &"starborn_colossus"]:
		var md := load("res://data/enemies/%s.tres" % id) as MonsterData
		var ok := md != null and md.phases.size() >= 2
		if ok:
			for ph in md.phases:
				ok = ok and float(ph.at) > 0.0 and float(ph.at) < 1.0 and not (ph.moves as Array).is_empty()
				for mv in ph.moves:
					ok = ok and MOVES.has(StringName(mv))
		check(ok, "boss %s has %d phases with valid moves" % [id, md.phases.size() if md else 0])
	for id in [&"bandit_thug", &"bandit_archer", &"bandit_brute", &"bandit_hexer", &"bandit_bomber"]:
		var md := load("res://data/enemies/%s.tres" % id) as MonsterData
		check(md and md.raider and md.category == EnemyData.Category.BANDIT, "%s is a bandit raider" % md.display_name)
	check((load("res://data/enemies/bandit_brute.tres") as MonsterData).siege_mult >= 2.0
		and (load("res://data/enemies/bandit_bomber.tres") as MonsterData).projectile_explode_radius > 0.0, "brutes and bombers are siege specialists")
	check((load("res://data/enemies/bandit_hexer.tres") as MonsterData).support == &"heal"
		and (load("res://data/enemies/grotto_cultist.tres") as MonsterData).support == &"heal"
		and (load("res://data/enemies/tower_warden.tres") as MonsterData).support == &"ward", "support casters heal or ward allies")
	check((load("res://data/enemies/treasure_goblin.tres") as MonsterData).flee_below >= 1.0, "treasure goblins always run")
	# Spells and tomes
	var spells := SpellBook.all()
	var tomes_ok := true
	for id in spells:
		var tome: ItemData = ItemDB.get_item(StringName("tome_%s" % id))
		var sp: AbilityData = spells[id]
		tomes_ok = tomes_ok and tome != null and tome.is_spell_tome() and tome.teaches_spell == id and sp.required_mana_control > 0 \
			and sp.cost > 0 and sp.cooldown > 0 and PlayerAbilities.new().has_method("_spell_%s" % sp.effect)
	check(spells.size() == 8 and tomes_ok, "8 advanced spells, each with a tome and an implementation")
	var droppable := true
	for id in spells:
		droppable = droppable and LootTables.TOMES.has(StringName("tome_%s" % id))
	check(droppable, "every spell tome can drop from loot tables")
	var ids := SpellBook.sorted_ids()
	check(SpellBook.get_spell(ids[0]).required_mana_control <= SpellBook.get_spell(ids[ids.size() - 1]).required_mana_control, "spells sort by Mana Control requirement")
	# Cures
	var bandage: ItemData = ItemDB.get_item(&"bandage")
	var antidote: ItemData = ItemDB.get_item(&"antidote")
	var purify: ItemData = ItemDB.get_item(&"purifying_draught")
	check(bandage.cures.has(&"bleed") and bandage.health_restore > 0 and antidote.cures.has(&"poison") and purify.cures.has(&"all"),
		"bandages stop bleeding, antidotes cure poison, purifying draughts cure everything")
	check(RecipeBook.get_recipe(&"bandage") != null and RecipeBook.get_recipe(&"bandage").source == RecipeData.Source.STARTING, "bandages are a starting recipe")
	# Defenses
	check(BuildingManager.get_piece_data(&"wood_wall").get_max_health() == 200.0 and BuildingManager.get_piece_data(&"stone_wall").get_max_health() == 500.0
		and BuildingManager.get_piece_data(&"palisade_wall").get_max_health() == 700.0 and BuildingManager.get_piece_data(&"reinforced_door").get_max_health() == 1200.0,
		"building hit points: wood 200, stone 500, palisade 700, reinforced door 1200")
	var tower := BuildingManager.get_piece_data(&"arrow_tower")
	check(tower.behavior == BuildPieceData.Behavior.TURRET and tower.turret_damage > 0 and BuildingManager.get_piece_data(&"alarm_bell").behavior == BuildPieceData.Behavior.BELL,
		"arrow towers and alarm bells exist")
	for id in [&"arrow_tower", &"alarm_bell", &"palisade_wall", &"reinforced_door"]:
		check(BuildMeshes.get_mesh(BuildingManager.get_piece_data(id).mesh).get_aabb().size.y > 1.0, "%s has a mesh" % id)
	# Elite affixes
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var two := EliteAffixes.roll(rng, 2)
	check(two.size() == 2 and two[0] != two[1] and EliteAffixes.AFFIXES.size() == 9, "elite affixes roll distinct (9 kinds)")
	check(not EliteAffixes.roll(rng, 9, true).has(&"thorned"), "ranged elites never get melee-only affixes")
	check(EliteAffixes.chance(5) > EliteAffixes.chance(0), "higher ranks spawn more elites")
	# Loot tables
	var got := {}
	for k in 200:
		var r := LootTables.roll(&"treasure_goblin", 5, rng)
		for id in r.items:
			got[id] = true
	var tome_found := false
	for id in got:
		tome_found = tome_found or String(id).begins_with("tome_")
	check(got.has(&"gold_nugget") and tome_found, "treasure goblins carry gold and sometimes spell tomes")
	check(not LootTables.roll(&"meteor", 0, rng).items.is_empty() and LootTables.roll(&"meteor", 0, rng).items.has(&"star_metal_ore"), "meteors hold star metal")
	check(LootTables.roll(&"raid_spoils", 2, rng).coins > 0 and LootTables.TABLES.has(&"elite"), "raid spoils and elite loot tables")
	check(RecipeBook.get_recipe(&"star_metal_ingot") != null and RecipeBook.get_recipe(&"starfall_blade") != null and RecipeBook.get_recipe(&"tome_meteor") != null,
		"star metal can be smelted into gear and the Meteor tome")


func test_m7_status() -> void:
	var holder := Node.new()
	add_child(holder)
	var hc := HealthComponent.new()
	hc.max_health = 200.0
	holder.add_child(hc)
	var se := StatusEffects.new()
	se.health = hc
	holder.add_child(se)
	await _frames(1)
	var reactions: Array[String] = []
	se.reaction.connect(func(t: String) -> void: reactions.append(t))
	se.apply(&"burn", 4.0, {"dps": 5.0})
	se.apply(&"wet", 4.0)
	check(not se.has(&"burn") and se.has(&"wet") and reactions.has("Doused"), "getting wet puts out burning")
	check(not se.apply(&"burn", 4.0, {"dps": 5.0}) and not se.has(&"wet") and reactions.has("Steam"), "fire on a wet target only makes steam (and dries it)")
	se.clear()
	se.apply(&"chilled", 3.0)
	se.apply(&"chilled", 3.0)
	check(se.has(&"frozen") and not se.has(&"chilled") and reactions.has("Deep Freeze"), "chilling a chilled target freezes it (Deep Freeze)")
	se.clear()
	se.apply(&"wet", 3.0)
	se.apply(&"chilled", 3.0)
	check(se.has(&"frozen"), "chilling a wet target freezes it")
	se.apply(&"wet", 3.0)
	check(is_equal_approx(float(se.incoming(&"lightning")[0]), 1.5) and se.incoming(&"lightning")[1] == "Conducted", "lightning is conducted by wet targets (x1.5)")
	se.clear()
	se.apply(&"shocked", 3.0)
	check(is_equal_approx(float(se.incoming(&"physical")[0]), 1.2), "shocked targets take 20% more damage")
	se.apply(&"weakened", 3.0)
	check(is_equal_approx(se.outgoing_mult(), 0.75), "weakened targets deal 25% less")
	se.apply(&"slowed", 3.0)
	se.apply(&"haste", 3.0)
	check(is_equal_approx(se.speed_mult(), 0.7 * 1.25), "slow and haste stack on movement speed")
	for i in 7:
		se.apply(&"bleed", 5.0, {"dps": 1.0})
	check(se.stacks(&"bleed") == 5, "bleeding stacks up to 5")
	se.apply(&"regen", 5.0, {"hps": 4.0})
	check(se.cleanse() >= 4 and se.has(&"regen") and se.has(&"haste") and se.effects.size() == 2, "cleansing removes every harmful effect and keeps buffs")
	se.immune = Array([&"stunned"], TYPE_STRING_NAME, &"", null)
	check(not se.apply(&"stunned", 2.0) and not se.is_stunned(), "immunities block effects")
	se.duration_mult = 0.7
	se.apply(&"poison", 10.0, {"dps": 2.0})
	check(is_equal_approx(se.time_left(&"poison"), 7.0) and is_equal_approx(se.time_left(&"regen"), 5.0), "Iron Skin shortens harmful effects only")
	hc.current = 100.0
	se.clear()
	se.apply(&"regen", 3.0, {"hps": 5.0})
	await get_tree().create_timer(1.2).timeout
	check(hc.current > 100.0, "regeneration heals over time")
	holder.queue_free()
	# The player uses the same component.
	var world: World = await _boot_class(&"knight")
	var p := world.player
	_clear_enemies(world)
	p.afflict(&"bleed", 6.0, {"dps": 2.0})
	check(p.afflictions.has(&"bleed") and p.status.has(&"bleed"), "players can bleed")
	p.health.current = p.health.max_health * 0.5
	await _frames(15)
	check(world.hud._status_row.get_child_count() >= 1 and world.hud._status_row.get_child(0).visible
		and (world.hud._status_row.get_child(0).get_child(0) as Label).text.begins_with("Bleeding"), "the HUD shows status chips")
	p.inventory.add_item(&"bandage", 1)
	for i in p.inventory.capacity:
		var st = p.inventory.get_slot(i)
		if st != null and st.id == &"bandage":
			p.use_slot(i)
			break
	check(not p.status.has(&"bleed") and p.health.current > p.health.max_health * 0.5, "a bandage stops the bleeding and heals")
	p.afflict(&"chilled", 5.0)
	check(p.stats.get_mult(Stats.MOVE_SPEED) < 0.9, "chill slows the player")
	p.status.clear()
	p._update_status_stats()
	p.character.skills[Skill.DEFENSE] = 50
	p.afflict(&"poison", 10.0, {"dps": 1.0})
	check(p.status.time_left(&"poison") <= 7.01, "Defense 50 (Iron Skin) shortens harmful effects by 30%")
	p.status.clear()
	p.afflict(&"silenced", 3.0)
	check(not p.abilities.try_use(0), "silenced players can't use abilities")
	p.status.clear()
	p.afflict(&"shocked", 3.0)
	p.health.reset_full()
	var hp0 := p.health.current
	var hit := DamageInfo.create(20.0, null, &"physical")
	p.receive_hit(hit)
	var shocked_loss := hp0 - p.health.current
	p.status.clear()
	p.health.reset_full()
	p.receive_hit(DamageInfo.create(20.0, null, &"physical"))
	check(shocked_loss > hp0 - p.health.current + 0.5, "shocked players take more damage")
	p.status.clear()
	world.queue_free()
	await _frames(5)


func _monsters_in_ai(ms: Array, ai: int) -> int:
	var n := 0
	for m in ms:
		if is_instance_valid(m) and not m.is_dead and m.ai == ai:
			n += 1
	return n


func test_m7_ai_elites() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	world.spawner.max_active = 60
	CombatDirector.clear()
	# Attack tokens: a pack surrounds you, at most two swing at once.
	var pack: Array = []
	for k in 5:
		var a := TAU * k / 5.0
		pack.append(_spawn_monster(world, &"skeleton_warrior", Vector3(cos(a), 0, sin(a)) * 4.0))
	for m in pack:
		m._alert(p)
	var max_att := 0
	var attacked := false
	var circled := false
	for f in 420:
		await get_tree().physics_frame
		var att := _monsters_in_ai(pack, Monster.AI.ATTACK)
		max_att = maxi(max_att, att)
		attacked = attacked or att > 0
		if CombatDirector.attackers_of(p) >= CombatDirector.MAX_MELEE:
			for m in pack:
				if m.ai == Monster.AI.CHASE and m.global_position.distance_to(p.global_position) < CombatDirector.RING + 2.5:
					circled = true
	check(attacked and max_att <= CombatDirector.MAX_MELEE, "a pack of 5 never has more than %d attackers at once (max %d)" % [CombatDirector.MAX_MELEE, max_att])
	check(circled, "waiting monsters circle the target")
	for m in pack:
		_kill(m, world)
	await _frames(3)
	# Pack alert
	var off := _clear_offset(world, 13.0)
	var a1 := _spawn_monster(world, &"skeleton_warrior", off)
	var a2 := _spawn_monster(world, &"skeleton_warrior", off + off.normalized().cross(Vector3.UP) * 3.0)
	a1._set_ai(Monster.AI.IDLE, 99.0)
	a2._set_ai(Monster.AI.IDLE, 99.0)
	a1._alert(p)
	check(a2.ai == Monster.AI.ALERT and a2.target == p, "alerting one monster alerts its pack")
	_kill(a1, world)
	_kill(a2, world)
	# Fleeing
	var thug := _spawn_monster(world, &"bandit_thug", _clear_offset(world, 4.0))
	thug._alert(p)
	await _frames(40)
	thug.health.current = thug.health.max_health * 0.1
	var fled := false
	for f in 120:
		await get_tree().physics_frame
		fled = fled or thug.ai == Monster.AI.FLEE
	check(fled, "badly hurt bandits run away")
	_kill(thug, world)
	# Dodging
	var duelist := _spawn_monster(world, &"bandit_thug", _clear_offset(world, 2.5))
	duelist.mdata = duelist.mdata.duplicate()
	duelist.mdata.dodge_chance = 1.0
	duelist.mdata.flee_below = 0.0
	duelist._alert(p)
	var dodged := false
	for f in 400:
		if not p.combat.is_attacking():
			p.face_direction(duelist.global_position - p.global_position, true)
			p.combat.request(&"light")
		await get_tree().physics_frame
		dodged = dodged or duelist.ai == Monster.AI.DODGE
	check(dodged, "nimble enemies sidestep your swings")
	_kill(duelist, world)
	# Support: a cultist heals a wounded ally.
	var hurt := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 6.0))
	var healer := _spawn_monster(world, &"grotto_cultist", _clear_offset(world, 8.0))
	hurt.health.current = hurt.health.max_health * 0.3
	hurt.stagger(30.0)
	var hp_hurt := hurt.health.current
	healer._alert(p)
	var healed := false
	for f in 600:
		await get_tree().physics_frame
		if hurt.health.current > hp_hurt + 1.0:
			healed = true
			break
	check(healed, "support casters heal wounded allies")
	_kill(hurt, world)
	_kill(healer, world)
	# Steering: a wall straight ahead makes the monster turn.
	var stee := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 3.0))
	await _frames(3)
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.BUILDING
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 3.0, 2.2)
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)
	var fwd := Vector3(1, 0, 0)
	wall.global_position = stee.global_position + fwd * 1.2 + Vector3(0, 1.5, 0)
	await _frames(2)
	check(absf(stee._choose_heading(fwd)) > 0.1, "monsters steer around walls in their way")
	wall.queue_free()
	_kill(stee, world)
	# Elites
	var el := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 5.0))
	var base_hp := el.health.max_health
	el.make_elite([&"shielded"])
	check(el.is_elite() and el.display_name().begins_with("Shielded") and el.health.max_health > base_hp * 2.0 and el.barrier > 0.0,
		"elites: name prefix, x2.2 health and their affix (%s)" % el.display_name())
	var hp_el := el.health.current
	el.receive_hit(DamageInfo.create(10.0, p, &"physical"))
	check(is_equal_approx(el.health.current, hp_el) and el.barrier < el.barrier_max, "the elite's shield absorbs damage first")
	var champ := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 6.0))
	champ.make_elite([&"juggernaut", &"vampiric"])
	check(champ.display_name().ends_with("(Champion)") and champ.status.immune.has(&"stunned"), "champions have two affixes; juggernauts can't be stunned")
	champ.apply_status(&"stunned", 3.0, {})
	check(not champ.status.is_stunned(), "stuns don't stick to juggernauts")
	champ.health.current = champ.health.max_health * 0.5
	var hp_c := champ.health.current
	p.health.invulnerable = false
	p.health.max_health = 5000.0
	p.health.reset_full()
	champ._hit_target(p, champ.mdata.melee, 1.0)
	check(champ.health.current > hp_c, "vampiric elites heal when they hit")
	var molten := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 7.0))
	molten.make_elite([&"molten"])
	var mpos := molten.global_position
	var coins0 := p.coins
	_kill(molten, world)
	await _frames(2)
	var eruption := false
	for c in molten.get_parent().get_children():
		eruption = eruption or (c is GroundHazard and c.global_position.distance_to(mpos) < 1.0 and c.damage_type == &"fire")
	check(eruption, "molten elites erupt when they die")
	_kill(el, world)
	_kill(champ, world)
	await _frames(5)
	check(p.coins > coins0, "elites drop extra loot (coins from the elite table)")
	p.health.invulnerable = true
	world.queue_free()
	await _frames(5)


func test_m7_bosses() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	_clear_enemies(world)
	world.spawner.max_active = 60
	p.health.invulnerable = false
	p.health.max_health = 20000.0
	p.health.reset_full()
	var off := _clear_offset(world, 6.0)
	var boss := _spawn_monster(world, &"bone_king", off)
	boss._alert(p)
	await _frames(40)
	# Phase 2
	boss.health.current = boss.health.max_health * 0.6
	await _frames(3)
	check(boss.phase == 1 and boss.ai == Monster.AI.PHASE and boss._moves().has(&"spikes"), "at 66% the Bone King enters phase 2 with new moves")
	check(boss.receive_hit(DamageInfo.create(50.0, p, &"physical")) == 0.0, "bosses are invulnerable while changing phase")
	await _frames(110)
	# Spikes
	var hp0 := p.health.current
	boss._start_special(&"spikes", 3.0, p)
	var bled := false
	for f in 240:
		await get_tree().physics_frame
		bled = bled or p.status.has(&"bleed")
	check(p.health.current < hp0 and bled, "bone spikes erupt under the player and cause bleeding")
	# Ward
	boss._raise_ward()
	var pylons := get_tree().get_nodes_in_group(&"ward_pylons")
	check(boss.warded and pylons.size() == 3, "the ward is powered by 3 pylons")
	check(boss.receive_hit(DamageInfo.create(80.0, p, &"physical")) == 0.0, "warded bosses take no damage")
	for py in pylons:
		py.receive_hit(DamageInfo.create(9999.0, p, &"physical"))
	await _frames(2)
	check(not boss.warded and boss.ai == Monster.AI.RECOVER and boss.exposed, "destroying every pylon breaks the ward and exposes the boss")
	await _frames(200)
	# Beam (Temple Guardian)
	var guardian := _spawn_monster(world, &"temple_guardian", -off)
	guardian._alert(p)
	await _frames(40)
	hp0 = p.health.current
	guardian._start_beam(p)
	await _frames(150)
	check(p.health.current < hp0 and guardian._beam_node == null or p.health.current < hp0, "sun beams burn whoever stands in them")
	_kill(guardian, world)
	# Teleport
	var b2 := boss
	b2._set_ai(Monster.AI.CHASE)
	b2.global_position = p.global_position + off * 1.5
	b2._start_special(&"teleport", 9.0, p)
	await _frames(40)
	var to_boss := b2.global_position - p.global_position
	check(to_boss.length() < 5.0, "teleporting bosses reappear right next to you (%.1f m)" % to_boss.length())
	await _frames(120)
	# Pull
	b2._set_ai(Monster.AI.CHASE)
	b2.global_position = p.global_position + off.normalized() * 9.0
	await _frames(2)
	var d0 := b2.global_position.distance_to(p.global_position)
	b2._set_ai(Monster.AI.PULL, 1.0)
	await _frames(40)
	check(b2.global_position.distance_to(p.global_position) < d0 - 1.0, "pull moves drag the player in")
	await _frames(120)
	# Roar
	b2._set_ai(Monster.AI.CHASE)
	b2.global_position = p.global_position + off.normalized() * 3.0
	p.status.clear()
	b2._set_ai(Monster.AI.ROAR, 0.1)
	await _frames(15)
	check(p.status.has(&"weakened"), "a roar knocks back, stuns and weakens")
	p.status.clear()
	# Poise break
	await _frames(60)
	b2._set_ai(Monster.AI.CHASE)
	b2.poise = 1.0
	b2.receive_hit(DamageInfo.create(1.0, p, &"physical"))
	var info := DamageInfo.create(1.0, p, &"physical")
	info.poise_damage = 500.0
	b2.poise = 1.0
	b2.receive_hit(info)
	check(b2.ai == Monster.AI.RECOVER and b2.ai_time > 1.5 and b2.exposed, "breaking a boss's poise leaves it Broken and exposed")
	_kill(b2, world)
	await _frames(5)
	# Bandit warlord: bombs and phases
	var warlord := _spawn_monster(world, &"bandit_warlord", off)
	warlord._alert(p)
	await _frames(40)
	check(warlord.display_name() == "Grimtusk the Warlord" and warlord.mdata.phases.size() == 2, "Grimtusk the Warlord leads big raids")
	hp0 = p.health.current
	warlord._start_special(&"bomb", 5.0, p)
	await _frames(150)
	check(p.health.current < hp0, "the warlord's fire bombs land where you stand")
	_kill(warlord, world)
	world.queue_free()
	await _frames(5)


func _learn_and_slot(p: Player, id: StringName) -> AbilityData:
	p.spells.learn(id)
	p.spells.assign(0, id)
	p.abilities.cooldowns.clear()
	p.mana.current = p.mana.max_mana
	return SpellBook.get_spell(id)


func test_m7_magic() -> void:
	var world: World = await _boot_class(&"wizard")
	var p := world.player
	var ch := p.character
	_clear_enemies(world)
	world.spawner.max_active = 60
	p.health.invulnerable = true
	# Tomes
	p.inventory.add_item(&"tome_blink", 1)
	p.inventory.add_item(&"tome_meteor", 1)
	for id in [&"tome_blink", &"tome_meteor"]:
		for i in p.inventory.capacity:
			var st = p.inventory.get_slot(i)
			if st != null and st.id == id:
				p.use_slot(i)
				break
	check(p.spells.knows(&"blink") and p.spells.knows(&"meteor") and p.spells.slots == [&"blink", &"meteor"]
		and p.inventory.count_of(&"tome_blink") == 0, "reading tomes teaches spells and fills the spell slots")
	p.inventory.add_item(&"tome_blink", 1)
	for i in p.inventory.capacity:
		var st = p.inventory.get_slot(i)
		if st != null and st.id == &"tome_blink":
			p.use_slot(i)
	check(p.inventory.count_of(&"tome_blink") == 1, "a tome you already know isn't used up")
	p.spells.assign(0, &"meteor")
	check(p.spells.slots == [&"meteor", &"blink"], "assigning a spell to the other slot swaps them")
	# Requirements
	ch.skills[Skill.MANA_CONTROL] = 5
	ch.recalculate()
	check(p.abilities.spell_block_reason(SpellBook.get_spell(&"meteor")).contains("Mana Control"), "low Mana Control can't cast Meteor")
	check(not p.abilities.try_cast(0), "casting fails without the requirement")
	ch.skills[Skill.MANA_CONTROL] = 80
	ch.recalculate()
	p.mana.max_mana = 1000.0
	p.mana.current = 1000.0
	# Targets: crawlers held in place (thorn crawlers aren't immune to anything we use).
	var off := _clear_offset(world, 7.0)
	p.face_direction(off, true)
	var target := _spawn_monster(world, &"thorn_crawler", off)
	target.configure(60.0, 1.0, 0, 1.0)  # tough: the Apprentice set boosts spells (M14)
	target.stagger(120.0)
	await _frames(3)
	p.set_lock_target(target)
	# Blink
	var a := _learn_and_slot(p, &"blink")
	var pos0 := p.global_position
	p.set_lock_target(null)
	p.face_direction(-off, true)
	check(p.abilities.try_cast(0) and p.global_position.distance_to(pos0) > 2.0, "Blink teleports you (%.1f m)" % p.global_position.distance_to(pos0))
	p.set_lock_target(target)
	check(p.abilities.cooldown_left(a) > 0.0 and p.mana.current < 1000.0, "casting costs mana and starts a cooldown")
	p.global_position = pos0
	p.face_direction(off, true)
	await _frames(5)
	# Healing Light
	p.health.invulnerable = false
	p.health.current = p.health.max_health * 0.4
	p.afflict(&"burn", 8.0, {"dps": 1.0})
	var hp0 := p.health.current
	_learn_and_slot(p, &"healing_light")
	check(p.abilities.try_cast(0) and p.health.current > hp0 + 10.0 and not p.status.has(&"burn") and p.status.has(&"regen"),
		"Healing Light heals, cures and regenerates")
	p.health.invulnerable = true
	# Miasma + Combustion
	_learn_and_slot(p, &"poison_cloud")
	var thp := target.health.current
	check(p.abilities.try_cast(0), "Miasma cast")
	await _frames(80)
	check(target.status.has(&"poison") and target.health.current < thp, "Miasma poisons enemies inside it")
	var clouds := get_tree().get_nodes_in_group(&"poison_clouds")
	check(clouds.size() == 1 and p.abilities.ignite_clouds(target.global_position, 1.0, 40.0) == 1, "fire ignites the cloud: Combustion!")
	await _frames(3)
	check(get_tree().get_nodes_in_group(&"poison_clouds").is_empty(), "the ignited cloud is consumed")
	# Blizzard -> Deep Freeze
	target.status.clear()
	target.stagger(120.0)
	_learn_and_slot(p, &"blizzard")
	check(p.abilities.try_cast(0), "Blizzard cast")
	var froze := false
	for f in 240:
		await get_tree().physics_frame
		froze = froze or target.status.has(&"frozen")
	check(froze, "Blizzard chills twice and freezes (Deep Freeze)")
	# Meteor
	target.status.clear()
	target.stagger(120.0)
	_learn_and_slot(p, &"meteor")
	thp = target.health.current
	check(p.abilities.try_cast(0), "Meteor cast")
	await _frames(100)
	check(target.health.current < thp - 20.0 and target.status.has(&"burn"), "the meteor lands: heavy fire damage and burning")
	# Arcane Missiles
	target.health.reset_full()
	thp = target.health.current
	_learn_and_slot(p, &"arcane_missiles")
	check(p.abilities.try_cast(0), "Arcane Missiles cast")
	await _frames(120)
	check(target.health.current < thp, "homing missiles hit")
	# Storm Call
	target.health.reset_full()
	target.status.clear()
	target.stagger(120.0)
	thp = target.health.current
	_learn_and_slot(p, &"storm_call")
	check(p.abilities.try_cast(0), "Storm Call cast")
	await _frames(150)
	check(target.health.current < thp and target.status.has(&"shocked"), "lightning strikes shock enemies")
	# Arcane Barrier
	_learn_and_slot(p, &"arcane_barrier")
	p.health.invulnerable = false
	p.health.reset_full()
	check(p.abilities.try_cast(0) and p.abilities.barrier > 0.0, "Arcane Barrier raised (%d)" % roundi(p.abilities.barrier))
	var hpb := p.health.current
	p.receive_hit(DamageInfo.create(20.0, null, &"physical"))
	check(is_equal_approx(p.health.current, hpb), "the barrier absorbs hits")
	p.health.invulnerable = true
	# Silence
	p.afflict(&"silenced", 5.0)
	p.abilities.cooldowns.clear()
	check(not p.abilities.try_cast(0), "silenced: no spells")
	p.status.clear()
	# Save / load of the spellbook
	var saved := p.spells.to_save()
	var book := SpellBook.new()
	book.from_save(saved)
	check(book.known.size() == p.spells.known.size() and book.slots == p.spells.slots, "the spellbook is saved")
	# Spellbook panel
	world.hud._spellbook.toggle()
	await _frames(3)
	check(world.hud._spellbook.visible and world.hud._spellbook._list.get_child_count() == 8, "the spellbook (L) lists all 8 spells")
	world.hud._spellbook.toggle()
	_kill(target, world)
	world.queue_free()
	await _frames(5)


## Builds a small base (claim + walls + chest + defenses) around the player.
func _build_base(world: World) -> Dictionary:
	var p := world.player
	for i in 9:
		p.character.grant_xp(p.character.xp_needed(), Progression.Source.OTHER)
	var claim := _place_near(world, &"claim_flag", 1, false, 3)
	var pieces := []
	for id in [&"wood_wall", &"wood_wall", &"wood_wall", &"palisade_wall", &"storage_chest", &"arrow_tower", &"alarm_bell", &"wood_wall", &"stone_wall"]:
		var bp := _place_near(world, id, 2, false, 6)
		if bp:
			pieces.append(bp)
	return {"claim": claim, "pieces": pieces}


func test_m7_base_raid() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	var b := _build_base(world)
	check(b.claim != null and b.pieces.size() >= 8, "built a base (%d pieces)" % b.pieces.size())
	var base := world.raids.find_player_base()
	check(not base.is_empty() and int(base.pieces) >= RaidManager.BASE_MIN_PIECES, "the claim counts as a base worth raiding")
	check(world.raids.has_bell(base.center, base.radius), "the alarm bell is part of the base")
	var warned := [false]
	var ended := [null]
	Events.raid_warning.connect(func(_t: String, _pos: Vector3, _s: float) -> void: warned[0] = true)
	Events.raid_ended.connect(func(_t: String, won: bool) -> void: ended[0] = won)
	world.raids.start_base_raid(base, &"bandits")
	check(warned[0] and world.raids.raid.phase == "warning" and is_equal_approx(float(world.raids.raid.t), RaidManager.BASE_WARNING + RaidManager.BELL_BONUS),
		"raids are announced (with the bell: %ds warning)" % roundi(float(world.raids.raid.t)))
	check(world.raids.status_text().begins_with("RAID"), "the HUD shows the raid countdown")
	world.raids.raid.t = 0.2
	# Stand off to the side so the raiders go for the buildings.
	var c: Vector3 = base.center
	var dir: float = world.raids.raid.dir
	p.global_position = c + Vector3(cos(dir + PI * 0.5), 0, sin(dir + PI * 0.5)) * 24.0
	p.global_position.y = world.get_ground_height(p.global_position) + 0.3
	await _frames(20)
	var raiders := world.raids.alive_raiders()
	check(world.raids.raid.phase == "fight" and raiders.size() >= 3, "wave 1: %d raiders" % raiders.size())
	var obj_ok := true
	for m in raiders:
		obj_ok = obj_ok and m.objective.distance_to(c) < 0.1 and m.get_meta(&"raid", "") == world.raids.raid.id
	check(obj_ok, "raiders march on the base")
	# Sturdier raiders for this check: with lucky arrow-tower volleys the
	# towers could kill the whole wave before anyone reached a wall.
	for m in raiders:
		m.health.max_health *= 4.0
		m.health.current = m.health.max_health
	var damaged := [false]
	Events.building_damaged.connect(func(_pc: Node, _d: bool) -> void: damaged[0] = true)
	var turret_hit := false
	for f in 2400:
		await get_tree().physics_frame
		for m in world.raids.alive_raiders():
			turret_hit = turret_hit or m.health.current < m.health.max_health
		if damaged[0] and turret_hit:
			break
	check(damaged[0], "raiders damage your buildings")
	check(turret_hit, "arrow towers shoot raiders")
	var coins0 := p.coins
	for k in 12:
		for m in world.raids.alive_raiders():
			_kill(m, world)
		await _frames(4)
		if not world.raids.is_active():
			break
	check(ended[0] == true and not world.raids.is_active(), "every wave beaten: raid repelled")
	await _frames(5)
	check(p.coins > coins0, "raid spoils (coins) awarded")
	# Losing: the survivors plunder your chests.
	var chest: BuildPiece = null
	for bp in b.pieces:
		if is_instance_valid(bp) and bp.storage:
			chest = bp
	chest.storage.add_item(&"iron_ingot", 5)
	chest.storage.add_item(&"plank", 20)
	var stacks0 := chest.storage.capacity - chest.storage.free_slot_count()
	world.raids.start_base_raid(base, &"bandits")
	world.raids.raid.t = 0.0
	await _frames(5)
	world.raids._finish(false)
	check(ended[0] == false and chest.storage.capacity - chest.storage.free_slot_count() < stacks0 and world.raids.alive_raiders().is_empty(),
		"if you abandon a raid the raiders steal from your chests and leave")
	# Damage, destruction, repair
	var wall: BuildPiece = null
	for bp in b.pieces:
		if is_instance_valid(bp) and bp.data.id == &"wood_wall":
			wall = bp
	var raider := _spawn_monster(world, &"bandit_brute", Vector3(30, 0, 0))
	check(wall.receive_hit(DamageInfo.create(30.0, p, &"physical")) == 0.0, "you can't damage your own buildings")
	wall.receive_hit(DamageInfo.create(120.0, raider, &"physical"))
	check(wall.is_damaged() and wall.health == wall.max_health() - 120.0, "pieces have hit points")
	p.global_position = wall.global_position + Vector3(1.5, 0.3, 1.5)
	check(world.building.repair(wall, p) != "", "repairs need materials")
	p.inventory.add_item(&"wood", 10)
	check(world.building.repair(wall, p) == "" and not wall.is_damaged(), "repairing restores the piece (cost %s)" % str(wall.repair_cost()))
	var key := BuildingManager.key(wall.cell, wall.slot, wall.layer)
	wall.receive_hit(DamageInfo.create(9999.0, raider, &"physical"))
	await _frames(2)
	check(not world.building.pieces.has(key), "destroyed pieces are gone")
	_kill(raider, world)
	world.queue_free()
	await _frames(5)


func test_m7_town_raid() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	var s := _nearest(world, false)
	await _go_to_town(world, s)
	var site: SettlementSite = world.living.sites.get(s.id)
	check(site != null and not site.npcs.is_empty(), "standing in %s" % s.name)
	var guard: NPC = site.npc_by_role(&"guard")
	var villager: NPC = null
	for n in site.npcs:
		if n.role in [&"villager", &"farmer", &"merchant"]:
			villager = n
	var rep0 := p.reputation.get_points(s.id)
	var coins0 := p.coins
	world.raids.start_town_raid(s, 0)
	check(site.under_attack and world.raids.raid.kind == "town", "%s is under attack" % s.name)
	check(villager == null or villager.schedule(12.0) == &"sleep", "villagers hide at home during a raid")
	check(guard == null or guard.can_be_attacked(), "guards stand and fight")
	world.raids.raid.t = 0.1
	await _frames(10)
	var raiders := world.raids.alive_raiders()
	check(raiders.size() >= 3 and raiders[0].objective.distance_to(s.world_center()) < 0.5, "raiders march on the town (%d)" % raiders.size())
	if guard:
		guard.receive_hit(DamageInfo.create(9999.0, raiders[0], &"physical"))
		check(guard.downed and not guard.can_be_attacked(), "guards can be knocked down (never killed)")
	for k in 12:
		for m in world.raids.alive_raiders():
			_kill(m, world)
		await _frames(4)
		if not world.raids.is_active():
			break
	check(not world.raids.is_active() and not site.under_attack, "the town is saved")
	check(p.reputation.get_points(s.id) > rep0 + 5.0 and p.coins > coins0, "defending a town earns reputation and a reward")
	check(guard == null or not guard.downed, "downed guards get back up")
	check(world.raids.defended.has(s.id), "the town remembers")
	# Plundered settlements charge more.
	var price0 := world.living.buy_price(s, &"merchant", &"healing_draught")
	world.raids.plundered[s.id] = world.day_night.day + 2
	var price1 := world.living.buy_price(s, &"merchant", &"healing_draught")
	check(world.raids.is_plundered(s.id) and price1 > price0, "plundered towns charge more (%d -> %d)" % [price0, price1])
	# Announced raids on far towns resolve without you.
	var far: SettlementInfo = null
	for o in world.generator.settlements.near(p.global_position, 3000.0):
		if o.distance_to(p.global_position) > 400.0:
			far = o
			break
	if far:
		world.raids.announce_town_raid(far, 1.0)
		check(world.raids.pending_town.id == far.id and world.raids.status_text().contains("attacked"), "a rider warns of the attack on %s" % far.name)
		world.raids.pending_town.at = GameState.world_time
		await _frames(3)
		check(world.raids.pending_town.is_empty() and world.raids.raided.has(far.id), "without you the town's guards decide the outcome")
	# Save / load
	var saved := world.raids.to_save()
	var rm := RaidManager.new()
	rm.world = world
	rm.from_save(saved)
	check(rm.is_plundered(s.id) and rm.defended.has(s.id), "raid outcomes are saved")
	rm.free()
	world.queue_free()
	await _frames(5)


func test_m7_events() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	world.spawner.max_active = 60
	var ev := world.events
	# Blood moon
	check(ev.start(&"blood_moon") and ev.is_active(&"blood_moon") and world.day_night.sky_tint.a > 0.3, "the blood moon turns the sky red")
	check(is_equal_approx(ev.xp_mult(), 1.5) and ev.elite_bonus() > 0.0, "blood moon: +50% XP and more elites")
	var horde := 0
	for k in 12:
		ev._spawn_horde()
		horde = 0
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e.get_meta(&"event", &"") == &"horde" and not e.is_dead:
				horde += 1
		if horde >= 2:
			break
	check(horde >= 2, "the dead walk (%d)" % horde)
	var xp_got := [0]
	Events.xp_gained.connect(func(n: int, _s: int) -> void: xp_got[0] = n)
	var sk := _spawn_monster(world, &"skeleton_warrior", _clear_offset(world, 4.0))
	var expected := Progression.combat_xp(sk.xp_value(), sk.effective_level(), p.character.level)
	_kill(sk, world)
	check(xp_got[0] == roundi(expected * 1.5), "kills give 50% more XP (%d vs %d)" % [xp_got[0], expected])
	ev.stop(&"blood_moon")
	check(not ev.is_active(&"blood_moon") and world.day_night.sky_tint.a == 0.0, "the blood moon ends")
	# Aurora
	ev.start(&"aurora")
	check(float(p.stats.get_source(&"aurora").get(Stats.MANA_REGEN, 1.0)) >= 2.0 and is_equal_approx(ev.spell_mult(), 1.15), "aurora: double mana regen, +15% spell damage")
	ev.stop(&"aurora")
	check(p.stats.get_source(&"aurora").is_empty(), "the aurora fades")
	# Eclipse
	ev.start(&"eclipse")
	check(world.day_night.eclipse > 0.5, "an eclipse darkens the day")
	ev.stop(&"eclipse")
	# Meteor
	var at := p.global_position + _clear_offset(world, 6.0)
	var crater := ev.drop_meteor(at)
	check(crater != null and ev.craters.has(crater.crater_id) and crater.is_in_group(&"meteor_craters"), "a meteor crashes and leaves a crater")
	p.inventory.add_item(&"stone_pickaxe", 1)
	crater.interact(p)
	p.global_position = crater.global_position + Vector3(1.0, 0.3, 0.0)
	await _frames(90)
	check(crater.is_mined and not ev.craters.has(crater.crater_id) and p.inventory.count_of(&"star_metal_ore") > 0, "mining the meteor gives star metal")
	var colossus := ev.spawn_colossus(at)
	check(colossus != null and colossus.is_boss() and colossus.ai == Monster.AI.DORMANT and colossus.mdata.phases.size() == 2,
		"a Starborn Colossus may guard the crater")
	_kill(colossus, world)
	# Treasure goblin
	var coins0 := p.coins
	check(ev.start(&"treasure_goblin") and ev._goblin != null, "a treasure goblin appears")
	var g := ev._goblin
	var gpos := p.global_position + _clear_offset(world, 6.0)
	gpos.y = world.get_ground_height(gpos) + 0.4
	g.global_position = gpos
	g._alert(p)
	var d0 := g.global_position.distance_to(p.global_position)
	var ran := false
	var far := 0.0
	for f in 300:
		await get_tree().physics_frame
		ran = ran or g.ai == Monster.AI.FLEE
		far = maxf(far, g.global_position.distance_to(p.global_position))
	check(ran and far > d0 + 2.0, "it runs away from you (%.1f -> %.1f m)" % [d0, far])
	_kill(g, world)
	await _frames(5)
	check(p.coins > coins0 and not ev.is_active(&"treasure_goblin"), "catching it pays well")
	# Save / load
	ev.start(&"blood_moon")
	ev.craters["meteor:1,2"] = [1.0, 5.0, 2.0]
	var saved := ev.to_save()
	ev.stop(&"blood_moon")
	ev.craters.clear()
	ev.from_save(saved)
	check(ev.is_active(&"blood_moon") and ev.craters.has("meteor:1,2"), "active events and craters are saved")
	ev.stop(&"blood_moon")
	ev.craters.clear()
	ev.refresh_craters()
	world.queue_free()
	await _frames(5)


# --- Milestone 8: blueprints ------------------------------------------------------------------

func _keys(bp: Blueprint) -> Dictionary:
	var out := {}
	for e in bp.pieces:
		out["%s@%s" % [Blueprint.entry_key(e), e.id]] = true
	return out


func test_m8_blueprint_format() -> void:
	var builtin := BlueprintLibrary.builtin()
	check(builtin.size() >= 4, "%d built-in blueprints" % builtin.size())
	for bp in builtin:
		check(bp.warnings.is_empty() and bp.pieces.size() >= 10 and not bp.total_cost().is_empty(),
			"%s: %d pieces, clean, costs %s" % [bp.name, bp.pieces.size(), bp.total_cost()])
	var hut: Blueprint = builtin.filter(func(b: Blueprint) -> bool: return b.name == "Starter Hut")[0]
	# JSON round trip
	var again := Blueprint.from_json(hut.to_json())
	check(again != null and _keys(again) == _keys(hut) and again.name == hut.name, "blueprints survive a JSON round trip")
	check(Blueprint.from_json("{\"hello\": 1}") == null and Blueprint.from_json("not json") == null, "other JSON isn't a blueprint")
	# Rotation
	check(_keys(hut.rotated(4)) == _keys(hut), "four quarter turns give back the same design")
	var room := Blueprint.new()
	for e in [[0, 0, "edge_n"], [0, 1, "edge_n"], [0, 0, "edge_w"], [1, 0, "edge_w"], [0, 0, "floor"]]:
		room.pieces.append({"id": &"wood_wall" if String(e[2]).begins_with("edge") else &"wood_floor", "x": e[0], "z": e[1], "slot": e[2], "rot": 0})
	var turned := room.rotated(1)
	var expect := {}
	for e in [[0, -1, "edge_n"], [0, 0, "edge_n"], [0, -1, "edge_w"], [1, -1, "edge_w"], [0, -1, "floor"]]:
		expect["%d,%d,%s" % e] = true
	var got := {}
	for e in turned.pieces:
		got[Blueprint.entry_key(e)] = true
	check(got == expect, "a walled cell turned 90 degrees is still a walled cell (edges map to edges)")
	check(turned.pieces[4].rot == 1, "piece rotation turns with the design")
	# Validation
	var messy := Blueprint.from_json(JSON.stringify({"format": "shardlands-blueprint", "version": 1, "name": "", "pieces": [
		{"id": "wood_wall", "x": 0, "z": 0, "slot": "edge_n"}, {"id": "wood_wall", "x": 0, "z": 0, "slot": "edge_n"},
		{"id": "golden_throne", "x": 1, "z": 1, "slot": "object"}, {"id": "wood_wall", "x": 2, "z": 2, "slot": "floor"},
		{"id": "bed", "x": 3, "z": 3}]}))
	check(messy != null and messy.pieces.size() == 2 and messy.warnings.size() == 3 and messy.name == "Untitled",
		"bad entries are dropped with warnings (unknown piece, wrong slot, duplicate)")
	check(messy.pieces[1].slot == "object", "a missing slot is filled in from the piece type")
	# Costs
	var cost := hut.total_cost()
	var manual := {}
	for e in hut.pieces:
		var d := BuildingManager.get_piece_data(e.id)
		for item in d.cost:
			manual[item] = int(manual.get(item, 0)) + int(d.cost[item])
	check(cost == manual, "total cost adds up every piece")
	var have := {}
	for item in cost:
		have[item] = int(cost[item]) - 1
	var miss := hut.missing(have)
	check(miss.size() == cost.size() and int(miss.values()[0]) == 1 and hut.missing(cost).is_empty(), "missing materials are computed")
	check(hut.required_level() >= 1 and hut.bounds().size.x >= 4 and hut.bounds().size.y >= 4, "footprint %s" % hut.bounds().size)
	var order := hut.build_order()
	check(order[0].slot == "floor" and order[order.size() - 1].slot == "roof", "build order: floors first, roofs last")
	# The web designer's catalog matches the game (rebuild with tools/build_designer.py).
	var html := FileAccess.get_file_as_string("res://web/blueprint-designer/index.html")
	var start := html.find("const CATALOG = ")
	var stop := html.find(";\nconst STANDALONE")
	var cat = JSON.parse_string(html.substr(start + 16, stop - start - 16)) if start >= 0 and stop > start else null
	var web_ids := {}
	if cat is Dictionary:
		for wp in cat.pieces:
			web_ids[StringName(wp.id)] = wp
	var sync: bool = cat is Dictionary and web_ids.size() == BuildingManager.all_pieces().size() and cat.examples.size() == builtin.size()
	if sync:
		for id in BuildingManager.all_pieces():
			var d := BuildingManager.get_piece_data(id)
			var wp = web_ids.get(id)
			sync = sync and wp != null and int(wp.level) == d.required_level and float(wp.hp) == d.get_max_health() \
				and wp.slot == BuildingManager.slot_kind(d) and (wp.cost as Dictionary).size() == d.cost.size()
	check(sync, "the web designer's piece catalog matches the game's build pieces")
	# Library (temporary folder)
	var saved_dir := BlueprintLibrary.user_dir
	BlueprintLibrary.user_dir = "user://test_blueprints/"
	for bp in BlueprintLibrary.user():
		BlueprintLibrary.delete(bp)
	var copy := hut.duplicate_bp()
	copy.name = "My Hut!"
	var path := BlueprintLibrary.save(copy)
	var path2 := BlueprintLibrary.save(copy.duplicate_bp())
	check(path.ends_with("my_hut.json") and path2.ends_with("my_hut_2.json") and BlueprintLibrary.user().size() == 2, "saving never overwrites another design")
	var imported := BlueprintLibrary.import_text(hut.to_json())
	check(imported != null and BlueprintLibrary.user().size() == 3, "importing JSON text saves the design")
	check(BlueprintLibrary.import_text("garbage") == null, "garbage isn't imported")
	for bp in BlueprintLibrary.user():
		BlueprintLibrary.delete(bp)
	check(BlueprintLibrary.user().is_empty() and not BlueprintLibrary.delete(hut), "user designs can be deleted; built-ins can't")
	BlueprintLibrary.user_dir = saved_dir


## A flat, clear anchor near the player where every non-roof piece of `bp` fits.
func _free_anchor(world: World, bp: Blueprint, q: int = 0) -> Vector2i:
	var placer := world.blueprints.placer
	placer.begin(bp)
	placer.rotation_q = q
	placer._rebuild_ghosts()
	var pc := Vector2i(floori(world.player.global_position.x), floori(world.player.global_position.z))
	var found := Vector2i(1 << 30, 0)
	for r in range(4, 30, 2):
		for k in 12:
			var a := TAU * k / 12.0
			var c := pc + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			placer.move_to(c)
			if placer.blocked == 0:
				found = c
				break
		if found.x != 1 << 30:
			break
	return found


func test_m8_construction() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds"
	for wl in SaveManager.list_worlds():
		SaveManager.delete_world(wl.id)
	var wid := SaveManager.create_world("Blueprint Test", GameState.DEFAULT_SEED, &"knight")
	var world: World = await _boot_world()
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	for i in 9:
		p.character.grant_xp(p.character.xp_needed(), Progression.Source.OTHER)
	var hut: Blueprint = BlueprintLibrary.builtin().filter(func(b: Blueprint) -> bool: return b.name == "Starter Hut")[0]
	# Placement preview
	var anchor := _free_anchor(world, hut)
	check(anchor.x != 1 << 30, "found a clear spot for the Starter Hut at %s" % anchor)
	var placer := world.blueprints.placer
	check(placer.active and placer._ghosts.size() == hut.pieces.size(), "the preview shows every piece as a hologram")
	var site := placer.confirm()
	check(site != null and not placer.active and world.blueprints.sites.size() == 1 and site.total == hut.pieces.size(), "placing lays out a construction site")
	await _frames(3)
	var holos := site._holos.size()
	check(holos > 0 and holos <= hut.pieces.size(), "%d holograms in the world" % holos)
	# Manual: build one floor by hand.
	p.inventory.clear()
	var floor_i := -1
	for i in site.entries.size():
		if site.entries[i].slot == "floor":
			floor_i = i
			break
	var holo: BlueprintHologram = site._holos[floor_i]
	check(holo.get_interact_text().begins_with("Build Wood Floor"), "holograms say what they build (%s)" % holo.get_interact_text())
	holo.interact(p)
	check(not site.entries[floor_i].built, "can't build without materials")
	p.inventory.add_item(&"wood", 2)
	holo.interact(p)
	await _frames(1)
	var fe: Dictionary = site.entries[floor_i]
	check(fe.built and world.building.pieces.has(BuildingManager.key(fe.cell, "floor", world.layer)) and p.inventory.count_of(&"wood") == 0,
		"pressing F on a hologram builds that piece and pays for it")
	# Auto-build waits for materials
	site.auto = true
	await _frames(40)
	check(site.status.begins_with("Missing") and site.pending_count() == site.total - 1, "auto-build waits when materials are missing (%s)" % site.status)
	# Chests near the site count as material sources.
	site.auto = false
	var chest_data := BuildingManager.get_piece_data(&"storage_chest")
	var chest: BuildPiece = null
	for dz in range(-8, 9):
		for dx in [-7, 7, -8, 8]:
			if chest == null and world.building.check_place(chest_data, anchor + Vector2i(dx, dz), "object", null, false) == "":
				chest = world.building.place(chest_data, anchor + Vector2i(dx, dz), "object", 0, null, false)
	check(chest != null, "placed a storage chest next to the site")
	var chest_cell := chest.cell
	var need := site.remaining_cost()
	for item in need:
		var n := int(need[item])
		var into_chest := n / 2
		chest.storage.add_item(item, into_chest)
		p.inventory.add_item(item, n - into_chest)
	check(site.remaining_cost().keys().all(func(it) -> bool: return int(site.available().get(it, 0)) >= int(site.remaining_cost()[it])),
		"inventory + nearby chest cover the remaining cost")
	# Save mid-construction and reload.
	site.build_entry(site.next_buildable())
	var pending := site.pending_count()
	world.save_now(false)
	world.queue_free()
	await _frames(5)
	SaveManager.load_world(wid)
	world = await _boot_world()
	p = world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	check(world.blueprints.sites.size() == 1 and world.blueprints.sites[0].pending_count() == pending, "construction sites are saved (%d pieces left)" % pending)
	site = world.blueprints.sites[0]
	await _frames(70)
	check(site._holos.size() > 0, "holograms come back after loading")
	# Auto-build the rest.
	site.auto = true
	var frames := 0
	while world.blueprints.sites.has(site) and frames < 2400:
		await get_tree().physics_frame
		frames += 1
	check(not world.blueprints.sites.has(site), "auto-build finished the hut (%d frames)" % frames)
	var ok := true
	for e in hut.pieces:
		var k := BuildingManager.key(anchor + Vector2i(int(e.x), int(e.z)), String(e.slot), world.layer)
		var piece: BuildPiece = world.building.pieces.get(k)
		ok = ok and piece != null and piece.data.id == StringName(e.id)
	check(ok, "every piece of the design stands where the blueprint says")
	var chest2: BuildPiece = world.building.pieces.get(BuildingManager.key(chest_cell, "object", world.layer))
	check(chest2 != null and chest2.storage.free_slot_count() == chest2.storage.capacity, "materials were taken from the chest too")
	# Capture what we built and compare.
	p.global_position = Vector3(anchor.x + 0.5, world.get_ground_height(Vector3(anchor.x + 0.5, 0, anchor.y + 0.5)) + 0.3, anchor.y + 0.5)
	var cap := world.blueprints.capture_here("Copy", 4.5)
	var hut_keys := _keys(hut)
	var cap_keys := _keys(cap)
	var all_in := true
	for k in hut_keys:
		all_in = all_in and cap_keys.has(k)
	check(all_in, "capturing the built hut gives back the design (%d pieces)" % cap.pieces.size())
	# A rotated placement puts pieces where the rotated design says.
	var cottage: Blueprint = BlueprintLibrary.builtin().filter(func(b: Blueprint) -> bool: return b.name == "Stone Cottage")[0]
	var a2 := _free_anchor(world, cottage, 1)
	var site2 := world.blueprints.placer.confirm()
	check(site2 != null and site2.rotation_q == 1, "placed a rotated Stone Cottage")
	var rot_ok := true
	for i in cottage.pieces.size():
		var r := Blueprint.rotate_entry(cottage.pieces[i], 1)
		var found := false
		for e in site2.entries:
			found = found or (e.cell == a2 + Vector2i(int(r.x), int(r.z)) and e.slot == r.slot and e.id == StringName(cottage.pieces[i].id))
		rot_ok = rot_ok and found
	check(rot_ok, "the rotated site matches the rotated blueprint")
	world.blueprints.cancel_site(site2)
	await _frames(2)
	check(world.blueprints.sites.is_empty() and get_tree().get_nodes_in_group(&"construction_sites").filter(func(n) -> bool: return not n.is_queued_for_deletion()).is_empty(),
		"removing a site clears its holograms")
	# UI
	world.hud._blueprints.toggle()
	await _frames(3)
	var panel: BlueprintPanel = world.hud._blueprints
	check(panel.visible and panel._list.get_child_count() == BlueprintLibrary.all().size() and panel._cost.get_child_count() > 0,
		"the blueprint screen (N) lists designs with their materials")
	panel.select(cottage)
	check(panel._title.text == "Stone Cottage" and panel._preview.blueprint == cottage, "selecting a design shows its preview and costs")
	panel._on_place()
	check(not panel.visible and world.blueprints.placer.active, "Place starts the preview")
	world.blueprints.placer.end()
	world.queue_free()
	await _frames(5)
	SaveManager.delete_world(wid)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


# --- Milestone 9: massive world ---------------------------------------------------------

func test_m9_world_bounds() -> void:
	check(TerrainGenerator.WORLD_CHUNK_COUNT == 3003289, "world has 1733 x 1733 = 3,003,289 chunks")
	check(TerrainGenerator.WORLD_CHUNK_COUNT >= 3000000, "world reaches the 3-million-chunk target")
	check(TerrainGenerator.is_chunk_in_world(Vector2i(866, -866)) and not TerrainGenerator.is_chunk_in_world(Vector2i(867, 0)),
		"chunk bounds are +-866")
	var c := TerrainGenerator.clamp_to_world(Vector3(20000, 5, -30000))
	check(c.x < TerrainGenerator.WORLD_LIMIT_M and c.z > -TerrainGenerator.WORLD_LIMIT_M and c.y == 5.0, "positions clamp to the world square")
	var gen := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	# Past WORLD_EDGE_END_M everything is deep ocean.
	var dry := 0
	for k in 240:
		var a := TAU * k / 240.0
		var r := TerrainGenerator.WORLD_EDGE_END_M + 50 + (k % 7) * 40
		var x := roundi(clampf(cos(a) * r * 1.5, -r, r))
		var z := roundi(clampf(sin(a) * r * 1.5, -r, r))
		var smp := gen.sample_column(x, z)
		if TerrainGenerator.unpack_height(smp) >= TerrainGenerator.SEA_LEVEL or gen.biomes[TerrainGenerator.unpack_biome(smp)].role != BiomeData.Role.OCEAN:
			dry += 1
	check(dry == 0, "the world edge is ocean all around (%d dry columns)" % dry)
	# Generation is deterministic in the far corners (fresh generator, other order).
	var gen2 := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var corners := [Vector2i(866, 866), Vector2i(-866, -866), Vector2i(866, -866), Vector2i(-866, 866), Vector2i(0, 866), Vector2i(-700, 650)]
	var same := true
	for cc: Vector2i in corners:
		var d1 := gen.generate_chunk(cc, 0)
		var d2 := gen2.generate_chunk(cc, 0)
		same = same and d1.heights == d2.heights and d1.vertices == d2.vertices and d1.colors == d2.colors and d1.props.size() == d2.props.size()
	check(same, "corner chunks generate identically")
	# Float precision at the far reaches: 1 mm steps still resolve.
	var far := float(TerrainGenerator.WORLD_LIMIT_M)
	var v := Vector3(far, 0, far) + Vector3(0.001, 0, 0.001)
	check(v.x != far, "float positions resolve 1 mm at %d m" % int(far))


func test_m9_world_sampling() -> void:
	var gen := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var land := 0
	var seen := {}
	var bad := 0
	var n := 1500
	var inner := TerrainGenerator.WORLD_EDGE_START_M / TerrainGenerator.CHUNK_SIZE
	for i in n:
		var c := Vector2i(rng.randi_range(-inner, inner), rng.randi_range(-inner, inner))
		var smp := gen.sample_column(c.x * 16 + 8, c.y * 16 + 8)
		var h := TerrainGenerator.unpack_height(smp)
		var b := TerrainGenerator.unpack_biome(smp)
		if h < -80 or h > 220 or b < 0 or b >= gen.biomes.size():
			bad += 1
		if h >= TerrainGenerator.SEA_LEVEL:
			land += 1
		seen[b] = true
	check(bad == 0, "random columns across the world are sane (%d bad)" % bad)
	var lf := float(land) / n
	check(lf > 0.2 and lf < 0.9, "land/sea mix across the world (%.0f%% land)" % (lf * 100.0))
	check(seen.size() >= 9, "most biomes appear across the world (%d)" % seen.size())
	var ok := true
	var t0 := Time.get_ticks_usec()
	for i in 24:
		var c := Vector2i(rng.randi_range(-866, 866), rng.randi_range(-866, 866))
		var d := gen.generate_chunk(c, 0)
		if d.vertices.is_empty() or d.indices.size() % 3 != 0 or d.collision_faces.size() != d.indices.size():
			ok = false
		for vtx in d.vertices:
			if not vtx.is_finite():
				ok = false
				break
	check(ok, "random LOD0 chunks anywhere build valid meshes (%.1f ms each)" % ((Time.get_ticks_usec() - t0) / 24000.0))


func test_m9_far_terrain() -> void:
	var gen := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var ft := FarTerrain.new()
	ft.setup(gen)
	var t := Vector2i(3, -2)
	var open := ft.build_tile(t, Vector2i(9999, 9999), 8)
	check(not open.holed, "tile far from the player has no hole")
	var tops := 0
	var verts: PackedVector3Array = open.terrain[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = open.terrain[Mesh.ARRAY_NORMAL]
	for i in range(0, norms.size(), 4):
		if norms[i] == Vector3.UP and verts[i].y > TerrainGenerator.WATER_Y + 0.01:
			tops += 1
	var water := (open.water[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 4
	check(tops + water >= FarTerrain.CELLS * FarTerrain.CELLS - 4, "full tile covers every cell (%d land + %d water)" % [tops, water])
	var hts: PackedInt32Array = open.heights
	var k := 3 * FarTerrain.W + 5
	var wx := t.x * FarTerrain.TILE_SIZE + 4 * FarTerrain.STEP + FarTerrain.STEP / 2
	var wz := t.y * FarTerrain.TILE_SIZE + 2 * FarTerrain.STEP + FarTerrain.STEP / 2
	check(hts[k] == gen.get_height_blocks(wx, wz), "far tile heights follow the real terrain")
	var center_chunk := Vector2i(t.x * 4 + 1, t.y * 4 + 1)
	var cut := ft.build_tile(t, center_chunk, 1)
	check(cut.holed and (cut.terrain[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < verts.size(), "cells under near chunks are cut out")
	var cached := ft.build_tile(t, Vector2i(9999, 9999), 8, [open.heights, open.biomes])
	check(cached.terrain[Mesh.ARRAY_VERTEX] == open.terrain[Mesh.ARRAY_VERTEX], "re-meshing from cached heights is identical")
	var dr := FarTerrain.tile_distance_range(Vector2i(0, 0), Vector2i(0, 0))
	check(dr.x == 0.0 and is_equal_approx(dr.y, Vector2(3, 3).length()), "tile distance range")
	ft.free()


func test_m9_region_store() -> void:
	var dir := "user://test_regions"
	_rm_tree(dir)
	var rs := RegionStore.new()
	rs.directory = dir
	rs.mark_prop(Vector2i(1, 1), 0, 5, 10.0)
	rs.mark_prop(Vector2i(-40, 70), 0, 9, 11.0)  # region (-2, 2)
	rs.mark_prop(Vector2i(1, 1), 1, 5, 12.0)  # underground
	rs.mark_death("33,-1:4:0", 20.0)
	rs.mark_death("poi_7_3:g0", 21.0)
	check(RegionStore.region_of(Vector2i(-40, 70), 0) == Vector3i(-2, 2, 0), "negative chunks map to the right region")
	check(RegionStore.region_of_slot("poi_7_3:g0") == RegionStore.MISC, "non-chunk slot keys use the misc region")
	check(rs.dirty_count() == 5, "changes mark regions dirty (%d)" % rs.dirty_count())
	check(rs.flush() and rs.file_count() == 5 and rs.dirty_count() == 0, "flush writes one compressed file per region (%d)" % rs.file_count())
	var rs2 := RegionStore.new()
	rs2.directory = dir
	check(rs2.loaded_count() == 0, "a fresh store loads nothing up front")
	check(is_equal_approx(rs2.prop_time(Vector2i(-40, 70), 0, 9), 11.0) and is_equal_approx(rs2.prop_time(Vector2i(1, 1), 1, 5), 12.0)
		and rs2.prop_time(Vector2i(1, 1), 0, 6) < 0.0, "props read back from region files")
	check(is_equal_approx(rs2.death_time("33,-1:4:0"), 20.0) and is_equal_approx(rs2.death_time("poi_7_3:g0"), 21.0), "spawn slots read back")
	check(rs2.loaded_count() == 5, "only touched regions are loaded (%d)" % rs2.loaded_count())
	rs2.erase_prop(Vector2i(-40, 70), 0, 9)
	rs2.flush()
	check(rs2.file_count() == 4 and not FileAccess.file_exists(rs2.file_path(Vector3i(-2, 2, 0))), "emptied regions delete their file")
	# Bounded memory: dirty regions stay until flushed, clean ones are evicted.
	var rs3 := RegionStore.new()
	rs3.directory = dir
	rs3.max_loaded = 4
	for i in 30:
		rs3.mark_prop(Vector2i(i * 32, 500), 0, i, 1.0)
	check(rs3.loaded_count() == 30, "unsaved regions are never dropped")
	rs3.flush()
	check(rs3.loaded_count() <= 4, "clean regions evicted after a flush (%d)" % rs3.loaded_count())
	for i in 60:
		rs3.prop_time(Vector2i(i * 32, -900), 0, 1)
	check(rs3.loaded_count() <= 4 + 16, "reading many regions stays bounded (%d)" % rs3.loaded_count())
	check(is_equal_approx(rs3.prop_time(Vector2i(29 * 32, 500), 0, 29), 1.0), "evicted regions reload from disk")
	var f := FileAccess.open(rs3.file_path(RegionStore.region_of(Vector2i(0, 500), 0)), FileAccess.READ)
	check(f != null and f.get_length() < 400, "region files are small (%d bytes)" % (f.get_length() if f else -1))
	f = null
	# Corrupt files are ignored, not fatal.
	var bad := FileAccess.open(rs3.file_path(Vector3i(50, 50, 0)), FileAccess.WRITE)
	bad.store_string("not a region")
	bad.close()
	check(rs3.prop_time(Vector2i(50 * 32, 50 * 32), 0, 1) < 0.0, "corrupt region file reads as empty")
	# Memory-only stores don't grow from reads.
	var mem := RegionStore.new()
	for i in 50:
		mem.prop_time(Vector2i(i * 40, 0), 0, 1)
	check(mem.loaded_count() == 0, "memory-only store doesn't grow from reads")
	var inline := RegionStore.new()
	check(inline.import_inline({"3,4,0": {"17": 5.0}, "-9,2": {"1": 6.0}}, {"1,1:0:0": 7.0}) == 3, "legacy dictionaries import")
	check(is_equal_approx(inline.prop_time(Vector2i(-9, 2), 0, 1), 6.0) and is_equal_approx(inline.death_time("1,1:0:0"), 7.0), "imported data queryable")
	var back := inline.to_inline()
	check((back.removed_props as Dictionary).has("3,4,0") and (back.enemy_deaths as Dictionary).has("1,1:0:0"), "inline form round trips")
	_rm_tree(dir)


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_rm_tree(path + "/" + sub)
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


func test_m9_save_regions() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds_m9"
	for w in SaveManager.list_worlds():
		SaveManager.delete_world(w.id)
	var id := SaveManager.create_world("Region World", 77001)
	var world: World = await _boot_world()
	check(world.is_ready, "persistent world boots")
	GameState.mark_prop_removed(Vector2i(500, -300), 42)
	GameState.mark_prop_removed(Vector2i(2, 3), 7, 1)
	GameState.mark_enemy_killed("500,-300:2:1")
	check(SaveManager.save_world(world), "save with region files")
	var rdir := SaveManager.regions_path(id)
	check(DirAccess.dir_exists_absolute(rdir) and GameState.regions.file_count() >= 2, "region files written (%d)" % GameState.regions.file_count())
	var save_text := FileAccess.get_file_as_string("%s/%s/save.json" % [SaveManager.worlds_dir, id])
	check(not save_text.contains("removed_props") and save_text.contains("\"regions\""), "save.json no longer carries per-chunk changes")
	world.queue_free()
	await get_tree().process_frame
	check(SaveManager.load_world(id), "load world")
	check(GameState.regions.loaded_count() == 0, "regions load lazily")
	check(GameState.is_prop_removed(Vector2i(500, -300), 42, 0.0) and GameState.is_prop_removed(Vector2i(2, 3), 7, 0.0, 1),
		"removed props survive save/load")
	check(not GameState.can_spawn_slot("500,-300:2:1", 99999.0), "killed slot survives save/load")
	# Legacy (v1) save: changes inline in save.json are migrated to region files.
	var legacy_id := SaveManager.create_world("Legacy World", 77002)
	var v1 := {"save_version": 1, "game_state": {"world_seed": "77002", "world_time": 50.0,
		"removed_props": {"10,-4,0": {"3": 40.0}}, "enemy_deaths": {"10,-4:1:0": 45.0}}}
	var f := FileAccess.open("%s/%s/save.json" % [SaveManager.worlds_dir, legacy_id], FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	check(SaveManager.load_world(legacy_id), "v1 save loads")
	check(GameState.is_prop_removed(Vector2i(10, -4), 3, 0.0) and not GameState.can_spawn_slot("10,-4:1:0", 99999.0), "v1 changes imported")
	SaveManager.pending = {}
	world = await _boot_world()
	check(SaveManager.save_world(world), "migrated save written")
	check(FileAccess.file_exists(GameState.regions.file_path(RegionStore.region_of(Vector2i(10, -4), 0))), "v1 changes now in a region file")
	world.queue_free()
	await get_tree().process_frame
	check(SaveManager.delete_world(legacy_id) and not DirAccess.dir_exists_absolute("%s/%s" % [SaveManager.worlds_dir, legacy_id]),
		"delete_world removes region folders too")
	SaveManager.delete_world(id)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


func test_m9_streaming() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world: World = await _boot_world()
	var cm := world.chunk_manager
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	var frames := 0
	while (cm.pending_count() > 0 or cm.far.pending_count() > 0) and frames < 4000:
		await get_tree().process_frame
		frames += 1
	var s := cm.get_debug_stats()
	print("   stats: %s" % str(s))
	check(s.far_tiles >= 100, "horizon tiles around the player (%d)" % s.far_tiles)
	check(s.lod2 > 0 and s.threads >= 2, "LOD rings + worker threads")
	check(world.camera_rig.camera.far >= 600.0, "camera sees out to the horizon")
	# Cache: leave and come back -> the chunks come from memory.
	var home := p.global_position
	var hits0: int = s.cache_hits
	p.frozen = true
	p.global_position = home + Vector3(600, 0, 0)
	await get_tree().process_frame
	while not cm.is_near_area_ready() and frames < 8000:
		await get_tree().process_frame
		frames += 1
	p.global_position = home
	await get_tree().process_frame
	var back_frames := 0
	while not cm.is_near_area_ready() and back_frames < 2000:
		await get_tree().process_frame
		back_frames += 1
	var hits := int(cm.get_debug_stats().cache_hits) - hits0
	check(hits >= 30, "returning reuses cached chunk data (%d hits, %d frames)" % [hits, back_frames])
	# Long fast journey: memory and node counts stay bounded, prefetch runs ahead.
	var objects0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var max_loaded := 0
	var max_children := 0
	var max_cache := 0.0
	var max_far := 0
	var speed := 70.0
	var dist := 0.0
	var dir := Vector3(1, 0, 0.35).normalized()
	var last := Time.get_ticks_msec()
	while dist < 1800.0:
		await get_tree().process_frame
		var dt := minf(0.05, (Time.get_ticks_msec() - last) / 1000.0)
		last = Time.get_ticks_msec()
		dist += speed * dt
		var pos := home + dir * dist
		pos.y = world.get_ground_height(pos) + 1.0
		p.global_position = pos
		var st := cm.get_debug_stats()
		max_loaded = maxi(max_loaded, st.loaded)
		max_children = maxi(max_children, cm.get_child_count())
		max_cache = maxf(max_cache, st.cache_mb)
		max_far = maxi(max_far, st.far_tiles)
	var s2 := cm.get_debug_stats()
	print("   after journey: %s" % str(s2))
	check(cm.focus_velocity().length() > 20.0, "travel speed tracked (%.0f m/s)" % cm.focus_velocity().length())
	check(s2.prefetched > 0, "prefetch generated chunks ahead (%d)" % s2.prefetched)
	check(max_loaded <= 360, "loaded chunks bounded during travel (max %d)" % max_loaded)
	check(max_children <= 420, "chunk nodes bounded by the pool (max %d)" % max_children)
	check(max_cache <= cm.cache_budget_mb * 1.05, "data cache within its budget (max %.1f MB)" % max_cache)
	check(max_far <= 260, "far tiles bounded (max %d)" % max_far)
	check(s2.evicted > 0 or s2.cache_mb < cm.cache_budget_mb, "cache evicts old data")
	check(s2.prewarms >= 2, "towns/POIs prewarmed ahead of travel (%d)" % s2.prewarms)
	frames = 0
	while not cm.is_near_area_ready() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	check(cm.is_near_area_ready(), "area ready after the journey")
	var growth := Performance.get_monitor(Performance.OBJECT_COUNT) - objects0
	check(growth < 6000, "object count stays bounded (+%d)" % growth)
	# The edge of the world stops the player.
	p.frozen = false
	p.global_position = Vector3(TerrainGenerator.WORLD_LIMIT_M + 400.0, 5.0, 200.0)
	await _frames(3)
	check(p.global_position.x < TerrainGenerator.WORLD_LIMIT_M, "player kept inside the world (x %.0f)" % p.global_position.x)
	world.queue_free()
	await get_tree().process_frame


# --- Milestone 10: art & polish ---------------------------------------------------------

func test_m10_audio() -> void:
	for b in Audio.BUSES:
		check(AudioServer.get_bus_index(b) >= 0, "audio bus %s exists" % b)
	# Every sound the code asks for by name exists.
	var missing := PackedStringArray()
	var names := {}
	var re := RegEx.create_from_string("Audio\\.play(?:_at|_ui)?\\(&\"([a-z_0-9]+)\"")
	var re2 := RegEx.create_from_string("\\[\"[a-z_]+\", &\"([a-z_0-9]+)\"\\]")
	for dir in ["res://src"]:
		for path in _all_files(dir, ".gd"):
			var text := FileAccess.get_file_as_string(path)
			for m in re.search_all(text):
				names[m.get_string(1)] = path
			if path.ends_with("audio.gd"):
				for m in re2.search_all(text):
					names[m.get_string(1)] = path
				for m in RegEx.create_from_string("play(?:_at|_ui)?\\(&\"([a-z_0-9]+)\"").search_all(text):
					names[m.get_string(1)] = path
	for n in names:
		if not Audio.has_sound(StringName(n)):
			missing.append("%s (%s)" % [n, names[n].get_file()])
	for surf in ["grass", "stone", "sand", "snow", "wood"]:
		if not Audio.has_sound(StringName("step_" + surf)):
			missing.append("step_" + surf)
	check(names.size() >= 30 and missing.is_empty(), "all %d sounds referenced in code exist %s" % [names.size(), missing])
	for t in [&"menu", &"explore_day", &"explore_night", &"town", &"combat", &"dungeon", &"boss"]:
		var st = load(Audio.MUSIC_DIR + String(t) + ".ogg")
		check(st is AudioStreamOggVorbis and (st as AudioStream).get_length() > 40.0, "music track %s (%.0f s)" % [t, st.get_length() if st else 0.0])
	for l in [&"wind", &"wind_strong", &"rain", &"rain_heavy", &"birds", &"crickets", &"cave", &"sea", &"fire", &"town"]:
		check(load(Audio.AMB_DIR + String(l) + ".ogg") is AudioStreamOggVorbis, "ambience loop %s" % l)
	check(Audio.pick_music({"boss": true, "combat": true}) == &"boss" and Audio.pick_music({"combat": true, "town": true}) == &"combat"
		and Audio.pick_music({"town": true, "night": true}) == &"town" and Audio.pick_music({"night": true}) == &"explore_night"
		and Audio.pick_music({}) == &"explore_day" and Audio.pick_music({"underground": true}) == &"dungeon", "music follows the situation")
	check(Audio.ability_sound(&"firebolt") == &"fire" and Audio.ability_sound(&"frost_nova") == &"frost" and Audio.ability_sound(&"healing_light") == &"heal"
		and Audio.ability_sound(&"something") == &"cast", "spells pick a matching sound")
	var before := Audio.played
	check(Audio.play(&"pickup", -80.0, 0.0, &"SFX", 1000), "a sound plays")
	check(not Audio.play(&"pickup", -80.0, 0.0, &"SFX", 1000) and Audio.played == before + 1, "rapid repeats are rate-limited")
	check(not Audio.play(&"no_such_sound"), "unknown sounds are ignored")
	var sfx := AudioServer.get_bus_index(&"SFX")
	Audio.set_volume(&"SFX", 0.5)
	check(is_equal_approx(AudioServer.get_bus_volume_db(sfx), linear_to_db(0.5 * Audio.BUS_MIX[&"SFX"])), "bus volume follows the setting")
	Audio.set_volume(&"SFX", 0.0)
	check(AudioServer.is_bus_mute(sfx), "zero volume mutes")
	Audio.set_volume(&"SFX", 1.0)


func _all_files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_all_files(dir + "/" + d, ext))
	return out


func test_m10_icons() -> void:
	var shapes := {}
	var bad := PackedStringArray()
	var count := 0
	for f in DirAccess.get_files_at("res://data/items"):
		if not f.ends_with(".tres"):
			continue
		var item: ItemData = ItemDB.get_item(StringName(f.get_basename()))
		if item == null:
			continue
		count += 1
		var img := ItemIcons.render(item)
		var opaque := 0
		var outline := 0
		var dark := item.icon_color.darkened(0.75)
		for y in ItemIcons.SIZE:
			for x in ItemIcons.SIZE:
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					opaque += 1
					if absf(c.r - dark.r) + absf(c.g - dark.g) + absf(c.b - dark.b) < 0.03:
						outline += 1
		if opaque < 60 or opaque > 900 or outline < 20:
			bad.append("%s(%d/%d)" % [item.id, opaque, outline])
		shapes[ItemIcons.shape_of(item)] = true
	check(count >= 130 and bad.is_empty(), "every item (%d) gets a drawn, outlined icon %s" % [count, bad])
	check(shapes.size() >= 40, "icons use many different drawings (%d)" % shapes.size())
	var expect := {&"copper_pickaxe": &"pickaxe", &"glowcap": &"mushroom", &"carrot_seeds": &"seeds", &"moonpetal_pendant": &"amulet",
		&"iron_ingot": &"ingot", &"healing_draught": &"potion", &"scroll_shadowfang": &"scroll", &"tome_blink": &"book",
		&"wooden_buckler": &"shield", &"stoneskin_elixir": &"potion", &"tusk_charm": &"amulet", &"plank": &"plank", &"wood": &"log"}
	var wrong := PackedStringArray()
	for id in expect:
		if ItemIcons.shape_of(ItemDB.get_item(id)) != expect[id]:
			wrong.append(String(id))
	check(wrong.is_empty(), "items map to the right drawing %s" % wrong)
	var it := ItemDB.get_item(&"iron_sword")
	check(ItemIcons.get_icon(it) == ItemIcons.get_icon(it), "icons are cached")


func test_m10_weather_rules() -> void:
	var w := WeatherSystem.new()
	var a := w.roll(1234.0, 0.5, 0.6, &"verdant_meadow")
	var b := w.roll(1234.0 + 10.0, 0.5, 0.6, &"verdant_meadow")
	check(a == b, "same weather spell, same weather")
	var counts := {"temperate_wet": {}, "temperate_dry": {}, "cold": {}, "desert": {}}
	for i in 600:
		var t := i * WeatherSystem.SPELL_SECONDS
		for k in counts:
			var r: Dictionary
			match k:
				"temperate_wet":
					r = w.roll(t, 0.5, 0.85, &"emerald_jungle")
				"temperate_dry":
					r = w.roll(t, 0.5, 0.15, &"verdant_meadow")
				"cold":
					r = w.roll(t, 0.15, 0.5, &"snowy_tundra")
				"desert":
					r = w.roll(t, 0.8, 0.1, &"sunscorch_desert")
			counts[k][r.kind] = int(counts[k].get(r.kind, 0)) + 1
	var wet_rain: int = int(counts.temperate_wet.get(WeatherSystem.Kind.RAIN, 0)) + int(counts.temperate_wet.get(WeatherSystem.Kind.STORM, 0))
	var dry_rain: int = int(counts.temperate_dry.get(WeatherSystem.Kind.RAIN, 0)) + int(counts.temperate_dry.get(WeatherSystem.Kind.STORM, 0))
	check(wet_rain > dry_rain * 1.5 and dry_rain > 0, "wet lands get more rain (%d vs %d of 600)" % [wet_rain, dry_rain])
	check(not counts.cold.has(WeatherSystem.Kind.RAIN) and not counts.cold.has(WeatherSystem.Kind.STORM) and int(counts.cold.get(WeatherSystem.Kind.SNOW, 0)) > 30,
		"it snows instead of raining in the cold (%d snow)" % int(counts.cold.get(WeatherSystem.Kind.SNOW, 0)))
	check(not counts.desert.has(WeatherSystem.Kind.RAIN) and int(counts.desert.get(WeatherSystem.Kind.SANDSTORM, 0)) > 10,
		"deserts get sandstorms, not rain (%d)" % int(counts.desert.get(WeatherSystem.Kind.SANDSTORM, 0)))
	check(int(counts.temperate_dry.get(WeatherSystem.Kind.CLEAR, 0)) > 200, "clear skies are the most common")
	w.kind = WeatherSystem.Kind.STORM
	w.intensity = 1.0
	check(w.temperature_offset() < -3.0 and w.is_precipitating(), "storms are cold and wet")
	w.kind = WeatherSystem.Kind.SANDSTORM
	check(w.temperature_offset() > 0.0 and not w.is_precipitating(), "sandstorms are hot and dry")
	w.free()


func test_m10_visual_assets() -> void:
	var lib := PropLibrary.new()
	check(lib.get_mesh(&"tree_oak").surface_get_material(0) is ShaderMaterial, "trees use the swaying foliage shader")
	var mat := lib.get_mesh(&"tree_oak").surface_get_material(0) as ShaderMaterial
	check(mat.get_shader_parameter(&"fade_near") == true, "trees still fade near the camera")
	check(lib.get_mesh(&"grass_tuft").surface_get_material(0) is ShaderMaterial, "grass sways")
	check(not (lib.get_mesh(&"rock").surface_get_material(0) is ShaderMaterial), "rocks don't sway")
	check(Materials.water() is ShaderMaterial, "water is the animated shader")
	for sh in ["sky", "foliage", "water"]:
		check(load("res://assets/shaders/%s.gdshader" % sh) is Shader, "%s shader loads" % sh)
	# Terrain AO: some top faces get darker corners next to higher columns.
	var gen := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var data := gen.generate_chunk(Vector2i(3, 2), 0)
	var shaded := 0
	for q in range(0, data.vertices.size(), 4):
		if data.normals[q] != Vector3.UP:
			continue
		var c0 := data.colors[q]
		for k in range(1, 4):
			if not data.colors[q + k].is_equal_approx(c0):
				shaded += 1
				break
	check(shaded > 5, "terrain corners are shaded by neighbours (%d faces)" % shaded)
	check(data.indices.size() % 3 == 0 and data.collision_faces.size() == data.indices.size(), "AO faces still build valid collision")


func test_m10_settings() -> void:
	var saved_path := Settings.path
	var saved := Settings.values.duplicate()
	Settings.path = "user://test_settings.cfg"
	Settings.set_value("music_volume", 0.3)
	Settings.set_value("screen_shake", false)
	check(is_equal_approx(Audio.get_volume(&"Music"), 0.3), "music volume applies")
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.load_settings()
	check(is_equal_approx(float(Settings.get_value("music_volume")), 0.3) and Settings.get_value("screen_shake") == false, "settings saved and loaded")
	Settings.reset_defaults()
	check(is_equal_approx(float(Settings.get_value("music_volume")), 1.0), "reset to defaults")
	var panel := SettingsPanel.new()
	add_child(panel)
	var controls := 0
	for n in panel.find_children("*", "", true, false):
		if n.has_meta(&"key"):
			controls += 1
	check(controls >= 13, "settings screen has every option (%d)" % controls)
	panel.queue_free()
	DirAccess.remove_absolute("user://test_settings.cfg")
	Settings.path = saved_path
	Settings.values = saved
	Settings.apply()


func test_m10_animation() -> void:
	var m := HumanoidModel.new()
	add_child(m)
	await get_tree().process_frame
	var steps := [0]
	m.footstep.connect(func(_l: bool) -> void: steps[0] += 1)
	for i in 120:
		m.set_locomotion(1.0, 1.0 / 60.0)
		m._process(1.0 / 60.0)
	check(steps[0] >= 5, "running makes footsteps (%d in 2 s)" % steps[0])
	check(absf(m._shin_l.rotation.x) > 0.05 or absf(m._shin_r.rotation.x) > 0.05, "knees bend while running")
	check(m._torso.rotation.x > 0.05, "leans into the run")
	m.set_locomotion(0.0, 1.0)
	m.set_air_state(true, false)
	for i in 20:
		m._process(1.0 / 60.0)
	check(m._arm_l.rotation.x < -1.0 and m._shin_l.rotation.x > 0.4, "jump pose: arms up, knee tucked")
	m.set_air_state(false, true)
	for i in 40:
		m._process(1.0 / 60.0)
	check(m._root.rotation.x > 0.8, "swimming lies flat in the water")
	m.set_air_state(false, false)
	for i in 60:
		m._process(1.0 / 60.0)
	check(absf(m._root.rotation.x) < 0.2, "stands up again on land")
	m.play_cast(0.5)
	for i in 10:
		m._process(1.0 / 60.0)
	check(m._arm_r.rotation.x < -1.0, "casting raises the hands")
	m.set_weapon(&"sword", false)
	m.play_attack(&"slash", 0.05, 0.25, 0.1)
	var trail_on := false
	for i in 30:
		await get_tree().create_timer(0.02).timeout
		if m._trail != null and m._trail.active:
			trail_on = true
			break
	check(trail_on, "sword swings leave a trail")
	await get_tree().create_timer(0.4).timeout
	check(m._trail == null or not m._trail.active, "trail stops after the swing")
	m.queue_free()
	# Particles: one-shot voxel debris cleans itself up.
	var holder := Node3D.new()
	add_child(holder)
	VFX.debris(holder, Vector3.ZERO, Color.BROWN, 6)
	VFX.dust(holder, Vector3.ZERO)
	check(holder.get_child_count() == 2, "debris and dust spawn particles")
	await get_tree().create_timer(1.3).timeout
	check(holder.get_child_count() == 0, "finished particles free themselves")
	VFX.enabled = false
	VFX.sparks(holder, Vector3.ZERO)
	check(holder.get_child_count() == 0, "particles can be switched off")
	VFX.enabled = true
	holder.queue_free()


func test_m10_world_polish() -> void:
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"knight")
	var world: World = await _boot_world()
	var p := world.player
	p.health.invulnerable = true
	world.spawner.max_active = 0
	var env := world.day_night.environment.environment
	check(env.sky != null and env.sky.sky_material is ShaderMaterial and env.background_mode == Environment.BG_SKY, "sky shader in use")
	# Day and night.
	world.day_night.hour = 12.0
	world.day_night.advance_hours(0.0)
	var noon := world.day_night.sun.light_energy
	check(world.day_night.sun.global_transform.basis.z.y > 0.5, "noon light comes from high up")
	world.day_night.hour = 0.5
	world.day_night.advance_hours(0.0)
	check(world.day_night.sun.light_energy < noon * 0.5 and world.day_night.is_night(), "night is darker (moonlight)")
	check(world.day_night.sun.global_transform.basis.z.y >= sin(deg_to_rad(DayNightCycle.MIN_LIGHT_ELEVATION)) - 0.01, "moonlight never comes from below")
	var phases := {}
	for d in 8:
		world.day_night.day = d + 1
		phases[world.day_night.moon_phase_name()] = true
	check(phases.size() >= 6, "the moon goes through its phases (%d)" % phases.size())
	world.day_night.hour = 12.0
	# Weather in the running game.
	var wthr := world.weather
	wthr.force(WeatherSystem.Kind.CLEAR)
	await _frames(3)
	var air_clear := world.get_air_temperature(p.global_position)
	var fog_clear := env.fog_depth_end
	wthr.force(WeatherSystem.Kind.RAIN)
	await _frames(3)
	check(wthr._rain.emitting and wthr._rain.amount_ratio > 0.5, "rain falls around the player")
	check(world.get_air_temperature(p.global_position) < air_clear - 1.0, "rain cools the air")
	await get_tree().create_timer(1.3).timeout
	if not (world.building and world.building.is_sheltered(p.global_position)):
		check(p.status.has(&"wet"), "standing in the rain makes you wet")
	check(float(Audio._amb_target.get(&"rain", 0.0)) > 0.3, "rain ambience plays")
	wthr.force(WeatherSystem.Kind.STORM)
	await _frames(2)
	var strikes := wthr.lightning_strikes
	wthr.strike()
	await _frames(1)
	check(wthr.lightning_strikes == strikes + 1 and world.day_night.weather_flash > 0.3, "lightning flashes")
	wthr.force(WeatherSystem.Kind.FOG)
	await _frames(3)
	check(env.fog_depth_end < fog_clear * 0.5, "fog closes in (%.0f m)" % env.fog_depth_end)
	wthr.force(WeatherSystem.Kind.SNOW)
	await _frames(2)
	check(wthr._snow.emitting and not wthr._rain.emitting, "snow replaces rain")
	wthr.force(-1)
	await _frames(2)
	# Ambient effects follow biome and time.
	world.day_night.hour = 23.0
	world.day_night.advance_hours(0.0)
	world.current_biome = world.generator.biomes[world.generator.biomes.map(func(b: BiomeData) -> StringName: return b.id).find(&"whispering_forest")]
	wthr.force(WeatherSystem.Kind.CLEAR)
	var t := world.ambient.targets()
	check(t[&"fireflies"] > 0.5 and t[&"leaves"] > 0.3 and t[&"pollen"] == 0.0, "forest nights have fireflies and leaves")
	world.day_night.hour = 12.0
	world.day_night.advance_hours(0.0)
	check(world.ambient.targets()[&"fireflies"] == 0.0, "no fireflies by day")
	# Music director.
	world.ambient._update_sound()
	check(Audio.music_track in [&"explore_day", &"town"], "daytime exploring music (%s)" % Audio.music_track)
	var boar := _spawn_boar(world, Vector3(4, 0, 0))
	boar.target = p
	world.ambient._update_sound()
	check(Audio.music_track == &"combat", "combat music when an enemy targets you")
	boar.queue_free()
	# Footstep surface and landing.
	check(p.footstep_surface() in ["grass", "stone", "sand", "snow", "wood"], "footstep surface (%s)" % p.footstep_surface())
	p.global_position += Vector3(0, 8, 0)
	var landed := false
	for i in 120:
		await get_tree().physics_frame
		if p._fall_speed > 6.0:
			landed = true
		if landed and p.is_on_floor():
			break
	check(landed and p._fall_speed == 0.0, "a fall is tracked and resets on landing")
	# Settings reach the world.
	Settings.values["shadows"] = 0
	Settings.values["weather_particles"] = false
	Settings.apply_to_world(world)
	check(not world.day_night.sun.shadow_enabled and not wthr.particles_enabled, "graphics settings apply to the world")
	Settings.values["shadows"] = 2
	Settings.values["weather_particles"] = true
	Settings.apply_to_world(world)
	# HUD shows weather; icons show in slots.
	await _frames(2)
	check(world.hud._clock.text.contains("\n"), "clock shows the weather")
	world.queue_free()
	await get_tree().process_frame


# --- Milestone 11: multiplayer ------------------------------------------------------------

func test_m11_protocol() -> void:
	var st := NetProtocol.encode_state(Vector3(1, 2, 3), 0.5, Vector3(4, 0, 5), 0.8, NetProtocol.F_SWIMMING, 0, 0.75)
	var d := NetProtocol.decode_state(st)
	check(d.pos == Vector3(1, 2, 3) and is_equal_approx(d.yaw, 0.5) and d.flags == NetProtocol.F_SWIMMING and is_equal_approx(d.hp, 0.75), "state packet round trip")
	check(NetProtocol.decode_state([1, 2]).is_empty() and NetProtocol.decode_state("x").is_empty()
		and NetProtocol.decode_state([INF, 0, 0, 0, 0, 0, 0, 0, 0, 0]).is_empty()
		and NetProtocol.decode_state([0, 0, 0, 0, 0, 0, 0, "x", 0, 0]).is_empty(), "malformed packets are rejected")
	check(NetProtocol.decode_state([0, 0, 0, 0, 0, 0, 99.0, 0, 7, 5.0]).layer == 1, "packet values are clamped")
	check(NetProtocol.clean_name("  Ab<script>c!!  ") == "Abscriptc" and NetProtocol.clean_name("") == "Player"
		and NetProtocol.clean_name("x".repeat(40)).length() == 16, "player names are cleaned")
	check(NetProtocol.slot_arg(3, 10) == 3 and NetProtocol.slot_arg(10, 10) == -1 and NetProtocol.slot_arg("a", 10) == -1, "slot arguments validated")
	var g1 := TerrainGenerator.new(4242, _settings())
	var g2 := TerrainGenerator.new(4242, _settings())
	var g3 := TerrainGenerator.new(4243, _settings())
	check(NetProtocol.world_checksum(g1) == NetProtocol.world_checksum(g2), "same seed, same world checksum")
	check(NetProtocol.world_checksum(g1) != NetProtocol.world_checksum(g3), "other seed, other checksum")
	# A guest's inventory is a read-only mirror.
	var inv := Inventory.new(8)
	inv.add_item(&"wood", 5)
	var moves := []
	inv.remote = true
	inv.remote_mover = func(f: int, t: int) -> void: moves.append([f, t])
	check(inv.add_item(&"stone", 3) == 3 and not inv.remove_item(&"wood", 1) and inv.remove_from_slot(0, 1) == 0, "remote inventory refuses local changes")
	inv.move_slot(0, 4)
	check(moves == [[0, 4]] and inv.get_slot(0) != null, "slot moves become requests")
	inv.from_array([{"id": "stone", "count": 7}])
	check(inv.count_of(&"stone") == 7 and inv.count_of(&"wood") == 0, "server snapshots apply")
	# Puppet interpolation.
	var rp := RemotePlayer.new()
	rp._snaps = [{"t": 1.0, "pos": Vector3(0, 0, 0), "yaw": 0.0, "move": 0.0, "flags": 0, "layer": 0, "hp": 1.0},
		{"t": 1.1, "pos": Vector3(1, 0, 0), "yaw": 0.0, "move": 1.0, "flags": 0, "layer": 0, "hp": 1.0}]
	check(rp.sample(1.05).pos.is_equal_approx(Vector3(0.5, 0, 0)), "puppets interpolate between snapshots")
	check(rp.sample(1.2).pos.x > 1.5 and rp.sample(2.0).pos.x < 3.1, "late packets extrapolate a little, then hold")
	rp.free()
	# Region export/import (what a guest receives).
	var rs := RegionStore.new()
	rs.mark_prop(Vector2i(3, 4), 0, 9, 5.0)
	var ex := rs.export_region(RegionStore.region_of(Vector2i(3, 4), 0))
	var rs2 := RegionStore.new()
	rs2.import_region(RegionStore.region_of(Vector2i(3, 4), 0), ex.props, ex.deaths)
	check(is_equal_approx(rs2.prop_time(Vector2i(3, 4), 0, 9), 5.0), "region snapshots transfer")


func test_m11_session() -> void:
	SaveManager.start_transient(31337, &"knight")
	Net.player_name = "Hosty"
	var world: World = await _boot_world()
	var p := world.player
	p.health.invulnerable = true
	check(world.is_ready, "host world ready")
	var port := 24600 + randi() % 800
	check(Net.host(port) == OK and Net.is_server(), "hosting on port %d" % port)
	check(world.spawner.max_active == 0, "monsters pause while hosting")
	var out := "user://net_client_result.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out))
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://tests/net_client_runner.tscn", "--",
		"--connect=127.0.0.1:%d" % port, "--out=%s" % out]
	var pid := OS.create_process(OS.get_executable_path(), args)
	check(pid > 0, "guest process started")
	var chats := []
	Net.chat_received.connect(func(from: String, text: String) -> void: chats.append([from, text]))
	# Wait for the guest to join and load.
	var t0 := Time.get_ticks_msec()
	while (Net.server.peers.is_empty() or not Net.server.peers.values()[0].ready) and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	var joined: bool = not Net.server.peers.is_empty() and Net.server.peers.values()[0].ready
	check(joined, "guest joined and loaded the world (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if not joined:
		OS.kill(pid)
		Net.leave()
		world.queue_free()
		return
	var ps = Net.server.peers.values()[0]
	check(ps.name == "Guesty" and ps.class_id == &"barbarian", "guest name and class (%s, %s)" % [ps.name, ps.class_id])
	check(Net.players.size() == 2, "two players in the session")
	check(is_instance_valid(ps.puppet) and ps.puppet.is_inside_tree(), "guest puppet in the host's world")
	# Give the guest materials (authoritative inventory).
	Net.server.give(ps, &"wood", 20)
	# Walk the host a little so the guest sees it move.
	for i in 40:
		p.global_position += Vector3(0.1, 0, 0)
		await get_tree().physics_frame
	# The host builds and harvests; the guest must see both.
	var hcell := Vector2i(floori(p.global_position.x), floori(p.global_position.z) - 3)
	var fdata := BuildingManager.get_piece_data(&"wood_floor")
	var hpiece := world.building.place(fdata, hcell, "floor", 0, p, false)
	if hpiece == null:
		hcell += Vector2i(2, -2)
		hpiece = world.building.place(fdata, hcell, "floor", 0, p, false)
	check(hpiece != null, "host placed a floor")
	Net.say("TEST host_piece %d,%d" % [hcell.x, hcell.y])
	var harvested := ""
	for chunk in world.chunk_manager._chunks.values():
		if chunk.lod != 0 or harvested != "":
			continue
		for c in chunk.get_children():
			if c is PropBody and c.data.interact_mode == PropData.InteractMode.HARVEST:
				harvested = "%d,%d,%d,%d" % [chunk.coord.x, chunk.coord.y, chunk.layer, c.prop_index]
				chunk.harvest_prop(c.prop_index, p)
				break
	check(harvested != "", "host harvested a prop")
	Net.say("TEST host_prop " + harvested)
	var max_puppet_move := 0.0
	var start_pos: Vector3 = ps.puppet.global_position
	var phase := 0.0
	var home := p.global_position
	while OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 160000:
		await get_tree().process_frame
		# The host strolls back and forth so the guest can watch it move.
		phase += get_process_delta_time()
		var hp := home + Vector3(sin(phase * 0.8) * 2.5, 0, 0)
		hp.y = world.get_ground_height(hp) + 0.1
		p.global_position = hp
		if is_instance_valid(ps.puppet):
			max_puppet_move = maxf(max_puppet_move, ps.puppet.global_position.distance_to(start_pos))
	check(not OS.is_process_running(pid), "guest finished")
	if OS.is_process_running(pid):
		OS.kill(pid)
	var res = JSON.parse_string(FileAccess.get_file_as_string(out))
	check(res is Dictionary, "guest wrote its report")
	if not res is Dictionary:
		Net.leave()
		world.queue_free()
		return
	print("   guest report: %s" % JSON.stringify(res))
	check(res.get("welcome") == true and String(res.get("seed")) == "31337", "welcome with the host's seed")
	check(res.get("world_loaded") == true, "guest generated the same world locally")
	check(res.get("remote_inventory") == true and res.get("local_add_refused") == true, "guest inventory is server-owned")
	check(res.get("monsters_paused") == true, "guest has no local monsters")
	check(res.get("host_seen") == true and res.get("spawn_near_host") == true, "guest sees the host next to it (%.1f m)" % float(res.get("host_distance", -1)))
	check(float(res.get("host_moved", 0.0)) > 1.5, "host movement reaches the guest")
	check(max_puppet_move > 1.0, "guest movement reaches the host (%.1f m)" % max_puppet_move)
	check(res.get("got_items") == true, "items given by the server arrive")
	check(res.get("gather_ok") == true and res.get("gather_removed_locally") == true, "guest gathered through the server (%s)" % String(res.get("gather_msg", "")))
	var gathered := ""
	for c in chats:
		if String(c[1]).begins_with("TEST gathered "):
			gathered = String(c[1]).substr(14)
	var gp := gathered.split(",")
	check(gp.size() == 4 and GameState.is_prop_removed(Vector2i(gp[0].to_int(), gp[1].to_int()), gp[3].to_int(), 0.0, gp[2].to_int()),
		"the guest's gathering removed the prop on the host")
	check(res.get("place_ok") == true and res.get("place_seen") == true, "guest built through the server (%s)" % String(res.get("place_msg", "")))
	check(int(res.get("wood_after_build", 0)) == int(res.get("wood_before", 0)) - 2 + int((res.get("gather_items", {}) as Dictionary).get("wood", 0)),
		"building cost came out of the server inventory")
	var built := ""
	for c in chats:
		if String(c[1]).begins_with("TEST built "):
			built = String(c[1]).substr(11)
	var bp := built.split(",")
	var gpiece: BuildPiece = world.building.pieces.get(BuildingManager.key(Vector2i(bp[0].to_int(), bp[1].to_int()), "floor", 0)) if bp.size() == 2 else null
	check(gpiece != null and String(gpiece.get_meta(&"owner", "")) == "Guesty", "guest's floor exists on the host, owned by the guest")
	check(res.get("drop_ok") == true and res.get("drop_seen") == true and res.get("pickup_ok") == true and res.get("wood_drop_roundtrip") == true,
		"drop and pick up go through the server")
	check(res.get("host_piece_seen") == true and res.get("host_piece_owner") == "Hosty", "host's building reaches the guest")
	check(res.get("remove_others_refused") == true, "guests can't remove other players' buildings")
	check(res.get("host_prop_seen") == true, "host's harvest reaches the guest")
	var height := ""
	for c in chats:
		if String(c[1]).begins_with("TEST height "):
			height = String(c[1]).substr(12)
	check(height != "" and absf(height.to_float() - world.generator.get_height_at(Vector3(37.5, 0, -81.5))) < 0.001, "identical terrain on both machines")
	check(absf(float(res.get("world_time", -1000.0)) - GameState.world_time) < 30.0, "world time synchronised")
	check(res.get("corrected") == true and Net.stats.corrections > 0, "impossible movement is corrected by the server")
	var hello := false
	for c in chats:
		if c[0] == "Guesty" and c[1] == "hello from guest":
			hello = true
	check(hello, "chat reaches the host")
	await get_tree().create_timer(0.5).timeout
	check(Net.server.peers.is_empty() and Net.players.size() == 1, "guest left cleanly")
	check(Net.player_records.has("Guesty") and (Net.player_records.Guesty.inventory as Array).size() > 0, "guest's character is kept for next time")
	var saved: Dictionary = world.to_save()
	check((saved.get("net_players", {}) as Dictionary).has("Guesty"), "guest records saved with the host's world")
	# Dedicated server + returning player.
	var rec_wood := 0
	for s in Net.player_records.Guesty.inventory:
		if s != null and String(s.id) == "wood":
			rec_wood += int(s.count)
	Net.leave()
	check(Net.host(port + 1, true) == OK and Net.dedicated and not Net.players.has(1), "dedicated server (no host player)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out))
	var pid2 := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/net_client_runner.tscn", "--", "--connect=127.0.0.1:%d" % (port + 1), "--out=%s" % out, "--rejoin"])
	var t1 := Time.get_ticks_msec()
	while OS.is_process_running(pid2) and Time.get_ticks_msec() - t1 < 60000:
		await get_tree().process_frame
	if OS.is_process_running(pid2):
		OS.kill(pid2)
	var res2 = JSON.parse_string(FileAccess.get_file_as_string(out))
	check(res2 is Dictionary and res2.get("fresh") == false and int(res2.get("welcome_wood", -1)) == rec_wood and res2.get("host_name") == "",
		"returning player gets their inventory back (%s wood) from a dedicated server" % (str(res2.get("welcome_wood")) if res2 is Dictionary else "?"))
	Net.leave()
	check(not Net.is_online() and world.spawner.max_active > 0, "offline again: monsters return")
	world.queue_free()
	await get_tree().process_frame
	Net.player_name = "Player"
	Net.player_records.clear()


# --- Milestone 12: balance + full loop ------------------------------------------------------

func test_m12_balance() -> void:
	# Classes: every class can fight level-appropriate content at every stage,
	# none dominates, and a Wizard never matches the fighters physically.
	var w_phys := BalanceModel.max_strength_phys(&"wizard")
	check(w_phys < BalanceModel.max_strength_phys(&"knight") * 0.9 and w_phys < BalanceModel.max_strength_phys(&"barbarian") * 0.9,
		"max-Strength Wizard stays below Knight and Barbarian (×%.2f vs ×%.2f)" % [w_phys, BalanceModel.max_strength_phys(&"knight")])
	for lvl in BalanceModel.LEVELS:
		var powers := []
		var ratios := []
		for c in BalanceModel.CLASSES:
			var d := BalanceModel.duel(c, lvl)
			powers.append(float(d.char.dps) * float(d.char.ehp))
			ratios.append(float(d.ratio))
		var lo: float = ratios.min()
		var hi: float = ratios.max()
		check(lo >= 3.0 and hi <= 32.0, "level %d: every class beats its content with margin, none trivially (ratio %.1f-%.1f)" % [lvl, lo, hi])
		var spread: float = float(powers.max()) / maxf(float(powers.min()), 0.01)
		check(spread < 3.0, "level %d: class power spread ×%.2f" % [lvl, spread])
	# Wild monsters scale with distance like the dungeons around them.
	check(EnemySpawner.wild_rank(Vector3(300, 0, 400)) == 0 and EnemySpawner.wild_rank(Vector3(Exploration.RANK_STEP * 3.5, 0, 0)) == 2
		and EnemySpawner.wild_rank(Vector3(13000, 0, 0)) == 5, "wild monster rank grows with distance (E near spawn, S at the edge)")
	# Gear tiers cover the levels where content gets harder.
	var top_req := 0
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it and it.is_equippable():
			top_req = maxi(top_req, it.required_level)
			if it.rarity >= ItemData.Rarity.LEGENDARY:
				check(it.required_level >= 40, "%s is end-game gear (level %d)" % [id, it.required_level])
	check(top_req >= 45, "gear keeps unlocking into the late game (top %d)" % top_req)
	# XP pacing.
	var h10 := BalanceModel.hours_to_level(10)
	var h50 := BalanceModel.hours_to_level(50)
	var h100 := BalanceModel.hours_to_level(100)
	print("   hours to level 10: %.1f, 50: %.1f, 100: %.0f" % [h10, h50, h100])
	check(h10 > 0.4 and h10 < 2.0, "about an hour to level 10 (%.1f h)" % h10)
	check(h50 > 12.0 and h50 < 60.0, "level 50 is a long-term goal (%.1f h)" % h50)
	check(h100 > h50 * 3.0, "level 100 is the endgame (%.0f h)" % h100)
	for l in [5, 20, 40, 60]:
		check(BalanceModel.minutes_per_level(l) > 1.0 and BalanceModel.minutes_per_level(l) < 120.0,
			"level %d takes %.0f min" % [l, BalanceModel.minutes_per_level(l)])
	# Crafting and economy: no money machines.
	var trade := BalanceModel.trade_arbitrage()
	check(trade < 1.0, "town-to-town trading alone never makes money (×%.2f)" % trade)
	var worst := 0.0
	var worst_id := ""
	for id in RecipeBook.all():
		var a := BalanceModel.craft_arbitrage(RecipeBook.all()[id])
		if a > worst:
			worst = a
			worst_id = String(id)
	check(worst < 1.0, "no recipe turns bought materials into profit (best %s ×%.2f)" % [worst_id, worst])
	for id in [&"copper_ingot", &"iron_ingot", &"mithril_ingot", &"leather", &"plank", &"rope"]:
		var v := BalanceModel.recipe_value(RecipeBook.get_recipe(id), 75)
		check(float(v.ratio) >= 0.95, "processing %s keeps its value (×%.2f)" % [id, v.ratio])
	for id in [&"copper_sword", &"iron_sword", &"chainmail", &"iron_waraxe"]:
		var v := BalanceModel.recipe_value(RecipeBook.get_recipe(id), 75)
		check(float(v.ratio) >= 0.9, "crafting %s adds value (×%.2f)" % [id, v.ratio])


func test_m12_gameplay_loop() -> void:
	var world: World = await _boot_class(&"knight")
	var bot := Playthrough.new(get_tree(), world)
	var res: Dictionary = await bot.run()
	for line in bot.steps:
		print("   " + line)
	for step in ["craft stone hatchet", "craft stone pickaxe", "chop 30 wood", "mine 16 stone", "build a workbench",
			"build floors and walls", "light a campfire", "defeat 5 monsters", "cook meat at the campfire",
			"level up from fighting and crafting", "find a village", "sell materials", "buy food", "craft a squire sword",
			"equip the sword", "find ruins", "defeat the ruin guardians", "loot the ruins"]:
		check(res.get(step, false) == true, "loop: " + step)
	check(float(res.get("play_minutes", 0.0)) < 90.0, "the loop fits in a play session (%.0f min)" % float(res.get("play_minutes", 0.0)))
	world.queue_free()
	await _frames(5)


func test_m12_worldgen_stress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var worst := 0.0
	for i in 6:
		var s := rng.randi()
		var r := Stress.worldgen_seed(s, 12)
		worst = maxf(worst, float(r.chunk_max_ms))
		check((r.errors as PackedStringArray).is_empty(), "seed %d: spawn %s (%s), %d towns, %d POIs, %d dungeon floors%s" % [s, str(r.spawn),
			r.spawn_biome, r.towns_2km, r.pois_2_5km, r.dungeon_floors,
			"" if (r.errors as PackedStringArray).is_empty() else " - " + "; ".join(r.errors)])
	check(worst < Stress.BUDGET_CHUNK_MS, "LOD0 chunks generate in < %d ms (worst %.1f ms)" % [Stress.BUDGET_CHUNK_MS, worst])


func test_m12_performance() -> void:
	var world: World = await _boot_class(&"knight")
	await _frames(30)
	var b: Dictionary = await Stress.benchmark(get_tree(), world, 0.6)
	for k in ["idle", "enemies", "buildings", "particles", "streaming"]:
		var st: Dictionary = b[k]
		print("   %-10s avg %.1f ms, p95 %.1f ms, max %.1f ms" % [k, st.avg, st.p95, st.max])
	for k in ["idle", "enemies", "buildings", "particles"]:
		check(float(b[k].avg) < Stress.BUDGET_AVG_MS and float(b[k].p95) < Stress.BUDGET_P95_MS,
			"%s within frame budget (avg %.1f, p95 %.1f ms)" % [k, b[k].avg, b[k].p95])
	check(int(b.enemies.count) >= 20 and int(b.buildings.count) >= 100, "benchmark load (%d monsters, %d pieces)" % [b.enemies.count, b.buildings.count])
	check(float(b.streaming.max) < Stress.BUDGET_STREAM_SPIKE_MS and float(b.streaming.ready_s) < Stress.BUDGET_STREAM_READY_S,
		"streaming after long jumps: worst frame %.0f ms, ready in %.1f s" % [b.streaming.max, b.streaming.ready_s])
	world.queue_free()
	await _frames(5)


# --- Milestone 13: beta / release preparation ------------------------------------------------

## A stand-in for the GodotSteam singleton: records what the game sends.
class FakeSteam:
	extends RefCounted
	signal overlay_toggled(active: bool, user_initiated: bool, app_id: int)
	var achievements: Array = []
	var stats: Dictionary = {}
	var presence: Dictionary = {}
	var stores := 0
	var callbacks := 0

	func steamInitEx(_retrieve: bool, _app: int) -> Dictionary:
		return {"status": 0, "verbal": "Steamworks active"}

	func run_callbacks() -> void:
		callbacks += 1

	func setAchievement(id: String) -> bool:
		if not achievements.has(id):
			achievements.append(id)
		return true

	func setStatInt(id: String, v: int) -> bool:
		stats[id] = v
		return true

	func storeStats() -> bool:
		stores += 1
		return true

	func setRichPresence(k: String, v: String) -> bool:
		presence[k] = v
		return true

	func getPersonaName() -> String:
		return "Steamy"


func test_m13_input_rebinding() -> void:
	var saved_path := Settings.path
	Settings.path = "user://test_settings_m13.cfg"
	InputSetup.reset_all()
	check(InputSetup.action_label(&"interact", false) == "F" and InputSetup.action_label(&"interact", true) == "A",
		"default bindings for keyboard and gamepad (%s / %s)" % [InputSetup.action_label(&"interact", false), InputSetup.action_label(&"interact", true)])
	check(InputSetup.action_label(&"attack_light", false) == "LMB" and InputSetup.action_label(&"ability_2", true) == "RT", "mouse and trigger names")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	var clashes := InputSetup.rebind(&"interact", e)
	check(clashes.has(&"cam_rotate_right"), "rebinding warns about keys already in use")
	check(InputSetup.action_label(&"interact", false) == "E" and InputSetup.action_label(&"interact", true) == "A", "keyboard rebind keeps the gamepad binding")
	check(InputSetup.custom_bindings().has("interact") and not InputSetup.custom_bindings().has("dodge"), "only changed actions are saved")
	var ok := true
	for s in ["key:%d" % KEY_K, "mouse:%d" % MOUSE_BUTTON_MIDDLE, "pad:%d" % JOY_BUTTON_Y, "axis:%d:-" % JOY_AXIS_LEFT_Y]:
		ok = ok and InputSetup.event_to_string(InputSetup.event_from_string(s)) == s
	check(ok, "bindings serialize both ways (key, mouse, button, axis)")
	Settings.save_settings()
	var saved_file := FileAccess.get_file_as_string(Settings.path)
	InputSetup.reset_all()  # (resetting saves at once, like the Reset button)
	check(InputSetup.action_label(&"interact", false) == "F", "reset restores the default")
	var sf := FileAccess.open(Settings.path, FileAccess.WRITE)
	sf.store_string(saved_file)
	sf.close()
	Settings.load_settings()
	check(InputSetup.action_label(&"interact", false) == "E", "custom bindings load from settings.cfg")
	var panel := SettingsPanel.new()
	add_child(panel)
	panel.listen(&"dodge", false)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	panel.capture(k)
	check(InputSetup.action_label(&"dodge", false) == "K" and (panel.bind_buttons[&"dodge"][0] as Button).text == "K", "the Controls tab rebinds by pressing a key")
	panel.listen(&"block", true)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	jb.pressed = true
	panel.capture(jb)
	check(InputSetup.action_label(&"block", true) == "RB" and InputSetup.action_label(&"block", false) == "Ctrl", "gamepad buttons rebind separately")
	check(panel.tabs.get_tab_count() >= 5 and panel.bind_buttons.size() >= 40, "settings has %d tabs, %d rebindable actions" % [panel.tabs.get_tab_count(), panel.bind_buttons.size()])
	panel.queue_free()
	var changed := [0]
	InputSetup.device_changed.connect(func(_p: bool) -> void: changed[0] += 1, CONNECT_ONE_SHOT)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	InputSetup._input(pad)
	check(InputSetup.using_gamepad and changed[0] == 1, "using a gamepad switches hints and aiming to the pad")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	InputSetup._input(key)
	check(not InputSetup.using_gamepad, "and the keyboard switches back")
	Settings.reset_controls()
	check(InputSetup.custom_bindings().is_empty(), "reset controls clears every custom binding")
	DirAccess.remove_absolute("user://test_settings_m13.cfg")
	Settings.path = saved_path
	Settings.save_settings()


func test_m13_settings_accessibility() -> void:
	var saved_path := Settings.path
	var saved := Settings.values.duplicate()
	Settings.path = "user://test_settings_m13.cfg"
	var world: World = await _boot_class(&"knight")
	var p := world.player
	_clear_enemies(world)
	# Difficulty
	var taken := []
	for d in [0, 1, 2]:
		Settings.set_value("difficulty", d)
		p.health.reset_full()
		var before := p.health.current
		p.receive_hit(DamageInfo.create(20.0, null))
		taken.append(before - p.health.current)
		await _frames(2)
	print("   damage taken (story/normal/hard): %s" % str(taken))
	check(taken[0] < taken[1] * 0.6 and taken[2] > taken[1] * 1.4, "difficulty scales the damage you take")
	Settings.set_value("difficulty", 1)
	check(is_equal_approx(Settings.hunger_mult(), 1.0), "normal difficulty keeps hunger as designed")
	# Display
	Settings.set_value("max_fps", 60)
	check(Engine.max_fps == 60, "frame rate cap applies")
	Settings.set_value("max_fps", 0)
	Settings.set_value("ui_scale", 1.25)
	check(is_equal_approx(get_tree().root.content_scale_factor, 1.25), "interface scale applies")
	Settings.set_value("ui_scale", 1.0)
	Settings.set_value("show_fps", true)
	check(Settings.accessibility.fps_label.visible, "FPS counter")
	Settings.set_value("show_fps", false)
	# Colour vision
	Settings.set_value("colorblind_mode", 2)
	check(Settings.accessibility.filter.visible and int((Settings.accessibility.filter.material as ShaderMaterial).get_shader_parameter(&"mode")) == 2,
		"colour-vision filter (deuteranopia)")
	Settings.set_value("colorblind_mode", 0)
	check(not Settings.accessibility.filter.visible, "filter off by default")
	# High contrast
	Settings.set_value("high_contrast", true)
	var panel_box := UITheme.build().get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	check(panel_box.bg_color.a > 0.95 and panel_box.border_width_top >= 3, "high-contrast panels are opaque with bold borders")
	check(world.hud._root.theme == UITheme.build(), "every screen shares the theme, so it updates live")
	Settings.set_value("high_contrast", false)
	check((UITheme.build().get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat).bg_color.a < 0.9, "and back")
	# Captions
	Settings.set_value("captions", true)
	Audio.play_at(&"monster_growl", p.global_position + world.camera_rig.global_transform.basis.x * 12.0, 0.0, 0.0, 45.0, 0)
	await _frames(1)
	var cap := ""
	for c in Settings.accessibility.captions.get_children():
		cap += (c as Label).text
	check(cap.contains("Monster growls") and (cap.contains("right") or cap.contains("left")), "sound captions with direction (%s)" % cap)
	Audio.play(&"ui_click", 0.0, 0.0, &"UI", 0)
	Settings.set_value("captions", false)
	await _frames(1)
	check(Settings.accessibility.captions.get_child_count() == 0, "captions off clears them")
	# Reduced flashing
	if world.weather:
		Settings.set_value("reduce_flashing", true)
		world.weather.strike()
		check(world.weather._flash <= 0.2, "reduced flashing: lightning only glows")
		Settings.set_value("reduce_flashing", false)
		world.weather.strike()
		check(world.weather._flash > 0.9, "normal lightning flash")
	# Reduced motion
	Settings.set_value("reduce_motion", true)
	check(not world.camera_rig.shake_enabled, "reduced motion turns camera shake off")
	var box := PanelContainer.new()
	world.hud._root.add_child(box)
	UIFx.pop_in(box)
	check(box.scale == Vector2.ONE and box.modulate.a == 1.0, "panels appear without animation")
	box.queue_free()
	Settings.set_value("reduce_motion", false)
	# Damage numbers and autosave
	Settings.set_value("autosave_minutes", 0)
	check(Settings.autosave_interval() == 0.0, "autosave can be turned off")
	Settings.set_value("autosave_minutes", 5)
	check(Settings.autosave_interval() == 300.0, "autosave every 5 minutes")
	# Toggle sprint
	Settings.set_value("toggle_sprint", true)
	p.stamina.refill()
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await get_tree().physics_frame
	var latched := p._sprint_held()
	Input.action_release(&"sprint")
	await _frames(3)
	var still := p._sprint_held()
	Input.action_release(&"move_forward")
	await _frames(2)
	check(latched and still and not p._sprint_held(), "toggle sprint: one press keeps running until you stop")
	Settings.set_value("toggle_sprint", false)
	# Settings file round trip with the new keys.
	Settings.set_value("difficulty", 2)
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.load_settings()
	check(int(Settings.get_value("difficulty")) == 2, "new settings save and load")
	var cf := ConfigFile.new()
	cf.set_value("settings", "difficulty", "hard?!")
	cf.save(Settings.path)
	Settings.load_settings()
	check(int(Settings.get_value("difficulty")) == 1, "a damaged settings file falls back to defaults")
	world.queue_free()
	await _frames(5)
	DirAccess.remove_absolute("user://test_settings_m13.cfg")
	Settings.path = saved_path
	Settings.values = saved
	Settings.apply()


func test_m13_tutorial() -> void:
	var saved_profile := Tutorial.profile_path
	Tutorial.profile_path = "user://test_profile_m13.cfg"
	DirAccess.remove_absolute(Tutorial.profile_path)
	Tutorial.reset_progress()
	Settings.values["tutorial_hints"] = true
	InputSetup.reset_all()
	var world: World = await _boot_class(&"knight")
	var p := world.player
	_clear_enemies(world)
	await _frames(30)
	check(Tutorial.current.get("id") == &"move", "the first hint is about moving")
	var card := world.hud.tutorial_card
	check(card.visible and card.text().contains("[WASD]") and card.text().contains("[Shift]"), "the hint names the real keys (%s)" % card.text())
	var e := InputEventKey.new()
	e.physical_keycode = KEY_K
	InputSetup.rebind(&"sprint", e)
	await _frames(1)
	check(card.text().contains("[K]"), "hints follow rebinding")
	InputSetup.reset_action(&"sprint")
	p.global_position += Vector3(10, 0, 0)
	p.global_position.y = world.get_ground_height(p.global_position) + 0.3
	await _frames(20)
	check(Tutorial.is_done(&"move"), "walking completes the movement hint")
	await get_tree().create_timer(Tutorial.GAP + 0.6).timeout
	check(Tutorial.current.get("id") == &"camera", "next: the camera (%s)" % Tutorial.current.get("id"))
	world.camera_rig._target_yaw += 45.0
	await _frames(20)
	check(Tutorial.is_done(&"camera"), "turning the camera completes it")
	Tutorial._gap = 0.0
	await _frames(30)
	check(Tutorial.current.get("id") == &"gather", "then gathering (%s)" % Tutorial.current.get("id"))
	Events.item_picked_up.emit(&"stick", 1)
	await _frames(20)
	check(Tutorial.is_done(&"gather"), "picking something up completes it")
	# Situational hints wait for their moment.
	check(not Tutorial.is_done(&"night") and Tutorial.current.get("id") != &"night", "the night hint waits for night")
	# Progress is per profile, not per world.
	Tutorial.load_progress()
	check(Tutorial.is_done(&"move") and Tutorial.is_done(&"gather"), "progress is saved to the player profile")
	Tutorial.complete(&"inventory")
	check(Tutorial.is_done(&"inventory"), "hints can be dismissed")
	Settings.values["tutorial_hints"] = false
	await _frames(5)
	check(Tutorial.current.is_empty() and not card.visible, "turning hints off hides them")
	Settings.values["tutorial_hints"] = true
	# Guide
	var guide := world.hud.guide
	guide.toggle()
	check(guide.visible and guide._controls.text.contains("Interact / gather") and guide.tabs.get_tab_count() >= 6, "F1 opens the guide (%d pages)" % guide.tabs.get_tab_count())
	check(Tutorial._flags.has(&"guide_opened"), "opening the guide counts for the tutorial")
	guide.toggle()
	check((world.hud._help.get_node("HelpText") as Label).text.contains("guide"), "the corner cheat sheet points to the guide")
	Tutorial.reset_progress()
	check(Tutorial.done.is_empty(), "the tutorial can be replayed")
	world.queue_free()
	await _frames(5)
	DirAccess.remove_absolute(Tutorial.profile_path)
	Tutorial.profile_path = saved_profile
	Tutorial.load_progress()


func test_m13_save_recovery() -> void:
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds_m13"
	_remove_dir("user://test_worlds_m13")
	var id := SaveManager.create_world("Recovery Test", 4242, &"knight")
	var world: World = await _boot_world()
	check(SaveManager.save_world(world), "world saved")
	var path := "%s/%s/save.json" % [SaveManager.worlds_dir, id]
	check(FileAccess.get_file_as_string(path).begins_with(SaveManager.HEADER), "save files carry a SHA-256 checksum")
	check(SaveManager.verify_world(id).ok, "a fresh world verifies")
	check(SaveManager.list_backups(id).size() >= 1, "a backup snapshot is made")
	world.player.inventory.add_item(&"iron_ore", 5)
	check(SaveManager.save_world(world), "second save (the first is kept as .bak)")
	world.queue_free()
	await _frames(5)
	# One flipped character inside valid JSON: only the checksum can tell.
	var damaged := FileAccess.get_file_as_string(path).replace("iron_ore", "iron_orf")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(damaged)
	f.close()
	check(not SaveManager.verify_world(id).ok and "save.json is damaged (the previous save is fine)" in SaveManager.verify_world(id).problems,
		"silent damage is detected (%s)" % ", ".join(SaveManager.verify_world(id).problems))
	check(SaveManager.load_world(id) and SaveManager.last_load.source == "bak", "loading falls back to the previous save")
	# Both saves damaged: the newest good snapshot.
	for pth in [path, path + ".bak"]:
		var g := FileAccess.open(pth, FileAccess.WRITE)
		g.store_string(SaveManager.HEADER + "0000\n{\"broken\": true}")
		g.close()
	check(SaveManager.load_world(id) and SaveManager.last_load.source == "backup" and not SaveManager.pending.is_empty(),
		"then to the newest backup (%s)" % SaveManager.last_load.get("backup", ""))
	SaveManager.pending = {}
	# Restore from the menu.
	var backups := SaveManager.list_backups(id)
	var count := backups.size()
	var recovery := RecoveryPanel.new()
	add_child(recovery)
	recovery.open(id)
	check(recovery._list.get_child_count() >= 1, "the Recover screen lists the backups")
	check(recovery.restore(backups[backups.size() - 1].name), "restoring a backup")
	check(SaveManager.verify_world(id).save, "the restored save is healthy")
	var reasons := []
	for b in SaveManager.list_backups(id):
		reasons.append(b.reason)
	check(reasons.has("before restore"), "the replaced save was kept as a backup (undo)")
	recovery.queue_free()
	# Crash snapshot of a live world.
	check(SaveManager.load_world(id), "reload")
	world = await _boot_world()
	var snap := SaveManager.snapshot_world(world, "crash")
	check(snap != "" and SaveManager.list_backups(id)[0].reason == "crash", "an emergency snapshot never touches save.json")
	# Old snapshots are pruned.
	for k in 8:
		SaveManager._snapshot_files(id, "autosave")
	check(SaveManager.list_backups(id).size() <= SaveManager.MAX_SNAPSHOTS, "only the newest %d backups are kept" % SaveManager.MAX_SNAPSHOTS)
	world.queue_free()
	await _frames(5)
	check(SaveManager.delete_world(id) and not DirAccess.dir_exists_absolute(SaveManager.backups_path(id)), "deleting a world removes its backups too")
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_dir(path + "/" + sub)
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


func test_m13_crash_handling() -> void:
	var ch := CrashHandler
	var saved := [ch.sessions_dir, ch.reports_dir, ch.logs_dir, ch.crashed_last_time, ch.previous_session, ch.last_report]
	ch.sessions_dir = "user://test_sessions"
	ch.reports_dir = "user://test_crash_reports"
	ch.logs_dir = "user://test_logs"
	for d in [ch.sessions_dir, ch.reports_dir, ch.logs_dir]:
		_remove_dir(d)
		DirAccess.make_dir_recursive_absolute(d)
	ch.crashed_last_time = false
	# A session that died: its process is gone, its lock is still there.
	var dead := FileAccess.open(ch.sessions_dir + "/999999.lock", FileAccess.WRITE)
	dead.store_string(JSON.stringify({"started": 1000.0, "heartbeat": 1600.0, "version": "0.13.0", "world": "my_world",
		"level": 7, "position": [1, 2, 3], "scene": "res://scenes/main.tscn"}))
	dead.close()
	var lf := FileAccess.open(ch.logs_dir + "/godot2026-01-01T00.00.00.log", FileAccess.WRITE)
	for n in 300:
		lf.store_line("log line %d" % n)
	lf.store_line("ERROR: something went wrong")
	lf.close()
	# A session that is still running (another instance) must be left alone.
	var pid := OS.create_process("sleep", ["5"])
	var alive := FileAccess.open(ch.sessions_dir + "/%d.lock" % pid, FileAccess.WRITE)
	alive.store_string("{}")
	alive.close()
	ch.check_previous_session()
	check(ch.crashed_last_time and String(ch.previous_session.get("world", "")) == "my_world", "an unclean exit is detected at startup")
	check(not FileAccess.file_exists(ch.sessions_dir + "/999999.lock"), "the stale lock is cleared")
	check(FileAccess.file_exists(ch.sessions_dir + "/%d.lock" % pid), "another running instance is not a crash")
	var report := FileAccess.get_file_as_string(ch.last_report + "/report.txt")
	check(report.contains("0.13.0") and report.contains("my_world") and report.contains("OS:") and report.contains("10m 00s"),
		"the crash report has the session and system info")
	var tail := FileAccess.get_file_as_string(ch.last_report + "/log_tail.txt")
	check(tail.contains("ERROR: something went wrong") and not tail.contains("log line 50\n"), "and the end of the previous log")
	OS.kill(pid)
	# The running game's own lock.
	ch.write_lock()
	check(FileAccess.file_exists(ch.lock_path) and String(JSON.parse_string(FileAccess.get_file_as_string(ch.lock_path)).get("version", "")) != "",
		"this session holds a lock with what it's doing")
	# Emergency snapshot on an engine crash.
	var saved_dir := SaveManager.worlds_dir
	SaveManager.worlds_dir = "user://test_worlds_m13"
	var id := SaveManager.create_world("Crash Test", 99, &"wizard")
	var world: World = await _boot_world()
	SaveManager.save_world(world)
	ch._emergency_done = false
	ch._notification(Node.NOTIFICATION_CRASH)
	check(SaveManager.list_backups(id)[0].reason == "crash", "a crash writes an emergency backup of the world")
	world.queue_free()
	await _frames(5)
	# The menu tells the player.
	var menu := (load("res://scenes/menu/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await _frames(2)
	check(menu.crash_notice.visible, "the main menu shows the crash notice")
	menu.queue_free()
	SaveManager.delete_world(id)
	SaveManager.worlds_dir = saved_dir
	SaveManager.start_transient(GameState.DEFAULT_SEED)
	for d in [ch.sessions_dir, ch.reports_dir, ch.logs_dir]:
		_remove_dir(d)
	ch.sessions_dir = saved[0]
	ch.reports_dir = saved[1]
	ch.logs_dir = saved[2]
	ch.crashed_last_time = saved[3]
	ch.previous_session = saved[4]
	ch.last_report = saved[5]
	ch.lock_path = "%s/%s.lock" % [ch.sessions_dir, ch._session_name()]
	ch.write_lock()


func test_m13_platform() -> void:
	var saved_path := Platform.profile_path
	var saved_backend := Platform.backend
	Platform.profile_path = "user://test_profile_platform.cfg"
	DirAccess.remove_absolute(Platform.profile_path)
	Platform.load_profile()
	check(saved_backend.id() == "local", "without Steam the game uses the local platform")
	var fake := FakeSteam.new()
	var sb := SteamBackend.new(fake, 480)
	check(sb.init() and sb.user_name() == "Steamy", "the Steam backend starts through GodotSteam")
	Platform.backend = sb
	sb.overlay_changed.connect(Platform._on_overlay)
	Platform._process(0.016)
	check(fake.callbacks > 0, "Steam callbacks are pumped every frame")
	Events.item_crafted.emit(&"rope", 1)
	check(Platform.is_unlocked(&"first_craft") and fake.achievements.has("first_craft") and int(fake.stats.get("items_crafted", 0)) == 1,
		"crafting unlocks an achievement on Steam and in the profile")
	var p := Platform.progress(&"master_crafter")
	check(p[0] == 1 and p[1] == 500, "progress toward stat achievements (%d/%d)" % p)
	Platform.add_stat(&"monsters_killed", 500)
	check(Platform.is_unlocked(&"slayer") and Platform.is_unlocked(&"first_blood"), "stat milestones unlock")
	Platform.flush()
	check(fake.stores > 0, "stats are stored to Steam")
	var unlocked := Platform.unlocked.size()
	Platform.load_profile()
	check(Platform.unlocked.size() == unlocked and Platform.stat(&"monsters_killed") == 500, "achievements and stats are saved in the profile")
	check(not Platform.unlock(&"first_craft") and not Platform.unlock(&"no_such_achievement"), "achievements unlock once")
	var world: World = await _boot_class(&"assassin")
	Platform._presence_left = 0.0
	Platform._process(0.016)
	check(String(fake.presence.get("status", "")).begins_with("Level 1 Assassin"), "rich presence (%s)" % fake.presence.get("status", ""))
	fake.overlay_toggled.emit(true, true, 480)
	check(get_tree().paused, "the Steam overlay pauses a single-player game")
	world.hud.set_paused(false)
	var panel := AchievementsPanel.new()
	add_child(panel)
	panel.refresh()
	check(panel._list.get_child_count() == Achievements.LIST.size(), "the Achievements screen lists all %d" % Achievements.LIST.size())
	panel.queue_free()
	world.queue_free()
	await _frames(5)
	Platform.backend = saved_backend
	DirAccess.remove_absolute(Platform.profile_path)
	Platform.profile_path = saved_path
	Platform.load_profile()


func test_m13_release() -> void:
	check(String(ProjectSettings.get_setting("application/config/version")).begins_with("0.15"), "version 0.15 (beta)")
	var cf := ConfigFile.new()
	check(cf.load("res://export_presets.cfg") == OK, "export presets are in the repository")
	var names := []
	for sec in cf.get_sections():
		if cf.has_section_key(sec, "name"):
			names.append(cf.get_value(sec, "name"))
			check(String(cf.get_value(sec, "exclude_filter")).contains("tests/*") and String(cf.get_value(sec, "include_filter")).contains("*.json"),
				"%s export leaves out tests/tools and keeps the blueprint JSON" % cf.get_value(sec, "name"))
	check(names.has("Windows Desktop") and names.has("Linux") and names.has("Web"), "Windows, Linux and Web presets (%s)" % str(names))
	var csv := FileAccess.get_file_as_string("res://platform/steam/achievements.csv").strip_edges().split("\n")
	check(csv.size() == Achievements.LIST.size() + 1, "Steam achievement list matches the game (%d)" % (csv.size() - 1))
	check(FileAccess.file_exists("res://platform/steam/app_build.vdf") and FileAccess.file_exists("res://platform/steam/rich_presence.vdf"), "SteamPipe build scripts")
	var symbols_ok := true
	for ch in "→★✕⚠●↺♛":
		var c := ch.unicode_at(0)
		symbols_ok = symbols_ok and (ThemeDB.fallback_font.has_char(c) or ThemeDB.fallback_font.fallbacks.any(func(f: Font) -> bool: return f.has_char(c)))
	check(symbols_ok, "UI symbols render on every platform (bundled fallback font)")
	var page := FileAccess.get_file_as_string("res://tools/web/shardlands.html")
	check(page.contains("{PARTS}") and page.contains("{VERSION}"), "web launcher template")
	# Browser builds have no threads: streaming does one job per frame.
	var cm := ChunkManager.new()
	cm.single_threaded = true
	add_child(cm)
	cm.setup(TerrainGenerator.new(1, _settings()), PropLibrary.new())
	check(cm._threads == 1 and cm.max_prefetch == 0 and cm.prewarm_radius_m <= 400 and cm.lod_radii[2] <= 7, "single-threaded (web) streaming mode")
	cm.queue_free()
	var ach_ids := {}
	for a in Achievements.LIST:
		check(not ach_ids.has(a[0]) and (a[3] == &"" or Achievements.STATS.has(a[3])), "achievement %s is well-formed" % a[0])
		ach_ids[a[0]] = true


# --- Milestone 14: Outfits --------------------------------------------------------------

## Equips `id` directly (level requirements are tested elsewhere).
func _wear(player: Player, id: StringName) -> void:
	player.equipment.equip(ItemDB.get_item(id))


func test_m14_outfit_data() -> void:
	var bad := []
	var looks := {}
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it == null or not it.is_equippable():
			continue
		var worn: bool = it.equip_slot in [ItemData.EquipSlot.HEAD, ItemData.EquipSlot.CHEST, ItemData.EquipSlot.HANDS,
			ItemData.EquipSlot.FEET, ItemData.EquipSlot.OFF_HAND]
		if worn and (it.armor_weight == ItemData.ArmorWeight.NONE or it.outfit_look == &""):
			bad.append(id)
		if it.outfit_look != &"":
			looks[it.outfit_look] = true
			if not HumanoidModel.OUTFIT_LOOKS.has(it.outfit_look):
				bad.append("%s:%s" % [id, it.outfit_look])
		if it.equip_slot == ItemData.EquipSlot.MAIN_HAND and it.armor_weight != ItemData.ArmorWeight.NONE:
			bad.append("%s (weapon with weight)" % id)
	check(bad.is_empty(), "every armour piece and shield has a weight and a known look %s" % [bad])
	check(looks.size() >= 20, "gear uses many different looks (%d)" % looks.size())
	# Classes: same body, different starting outfits; abilities and skills stay per class.
	var heads := {}
	for cid in ClassRegistry.ORDER:
		var c := ClassRegistry.get_class_data(cid)
		var head := &""
		for id in c.starting_equipment:
			var it: ItemData = ItemDB.get_item(StringName(id))
			if it and it.equip_slot == ItemData.EquipSlot.HEAD:
				head = it.outfit_look
		check(head != &"" and not heads.has(head), "%s starts with its own head piece (%s)" % [cid, head])
		heads[head] = true
		check(c.starting_skill_total() == 50 and c.abilities.size() == 3, "%s keeps its 50 starting points and 3 class abilities" % cid)
	# Every new piece can be made by anyone (crafting never fails, any class can craft).
	for id in [&"squire_helm", &"horned_helm", &"wizard_hat", &"shadow_hood", &"iron_helm", &"iron_gauntlets",
			&"iron_greaves", &"soft_leather_boots"]:
		check(RecipeBook.get_recipe(id) != null, "%s has a crafting recipe" % id)
	# Small skill bonuses on everyday gear.
	check(int(ItemDB.get_item(&"leather_gloves").stat_bonuses.get(&"dexterity", 0)) == 1
		and int(ItemDB.get_item(&"chainmail").stat_bonuses.get(&"defense", 0)) == 2
		and int(ItemDB.get_item(&"iron_gauntlets").stat_bonuses.get(&"strength", 0)) == 2,
		"armour and clothes give +1 / +2 to skills")
	# Weight maths.
	var eq := Equipment.new()
	check(is_equal_approx(eq.notice_mult(), 1.0) and eq.outfit_style() == "Clothes only", "no armour: normal notice range")
	for id in [&"shadow_hood", &"leather_jerkin", &"leather_gloves", &"soft_leather_boots"]:
		eq.equip(ItemDB.get_item(id))
	var light_notice := eq.notice_mult()
	var light_dodge := eq.dodge_cost_mult()
	check(eq.outfit_style() == "Light" and light_notice < 0.8 and light_dodge < 0.9,
		"full light outfit: noticed at %d%%, dodge %d%%" % [roundi(light_notice * 100), roundi(light_dodge * 100)])
	eq.clear()
	for id in [&"iron_helm", &"chainmail", &"iron_gauntlets", &"iron_greaves", &"iron_kite_shield"]:
		eq.equip(ItemDB.get_item(id))
	check(eq.outfit_style() == "Heavy" and eq.notice_mult() > 1.3 and eq.dodge_cost_mult() > 1.2,
		"full heavy outfit: noticed at %d%%, dodge %d%%" % [roundi(eq.notice_mult() * 100), roundi(eq.dodge_cost_mult() * 100)])
	var args := eq.look_args()
	check(args.size() == 4 and String(args[2]).split(",").size() == 5, "look args carry the outfit for multiplayer (%s)" % [args])


func test_m14_outfits_ingame() -> void:
	# Every class: same body, its own starting outfit.
	var shirts := {}
	for cid in ClassRegistry.ORDER:
		var w: World = await _boot_class(cid)
		var m := w.player.model
		shirts[m.shirt_color] = true
		var looks := m.outfit_looks()
		print("   %s wears %s" % [cid, looks])
		check(not looks.is_empty(), "%s is dressed by its starting gear" % cid)
		w.queue_free()
		await _frames(5)
	check(shirts.size() == 1, "all classes share one body")

	# A Knight dressed as an Assassin.
	var world: World = await _boot_class(&"knight")
	var p := world.player
	check(p.model.outfit_looks().has(&"helm_plume"), "Knight starts with the plumed helm")
	_wear(p, &"shadow_hood")
	_wear(p, &"shadow_cloak")
	_wear(p, &"leather_gloves")
	_wear(p, &"soft_leather_boots")
	_wear(p, &"iron_dirk")
	p.equipment.unequip(ItemData.EquipSlot.OFF_HAND)
	await _frames(2)
	var looks: Array = p.model.outfit_looks()
	check(looks.has(&"hood_mask") and looks.has(&"cloak") and not looks.has(&"helm_plume"), "changing clothes changes the look %s" % [looks])
	check(p.equipment.weapon_type() == &"dagger" and p.combat.light_combo.size() == 4, "the Knight fights with the dagger combo")
	check(p.character.weapon_mult(&"dagger") >= 0.9, "Knights are no longer bad with daggers (x%.2f)" % p.character.weapon_mult(&"dagger"))
	check(p.character.class_data.id == &"knight" and p.abilities.get_slot(0).id == &"shield_bash", "still a Knight with Knight abilities")
	var dex_base := p.character.base_skill(Skill.DEXTERITY)
	check(p.character.skill_level(Skill.DEXTERITY) >= dex_base + 4, "light gear adds Dexterity (%d -> %d)" % [dex_base, p.character.skill_level(Skill.DEXTERITY)])
	# Stealthy outfit: an idle skeleton 11 m away doesn't notice the Knight...
	var off := _clear_offset(world, 11.0)
	var sk := _spawn_monster(world, &"skeleton_warrior", off)
	await _frames(10)
	print("   light: notice x%.2f, range %.1f m" % [p.notice_mult(), sk.notice_range(p)])
	check(sk.ai in [Monster.AI.IDLE, Monster.AI.WANDER], "light armour: an idle skeleton at 11 m doesn't notice you")
	# ...but in full iron he is spotted at once.
	for id in [&"iron_helm", &"chainmail", &"iron_gauntlets", &"iron_greaves", &"iron_kite_shield"]:
		_wear(p, id)
	await _frames(10)
	print("   heavy: notice x%.2f, range %.1f m" % [p.notice_mult(), sk.notice_range(p)])
	check(not sk.ai in [Monster.AI.IDLE, Monster.AI.WANDER], "heavy armour: the same skeleton notices you")
	check(p.model.outfit_looks().has(&"great_helm"), "now wearing the great helm")
	# Dodging costs more stamina in heavy armour.
	p.stamina.current = p.stamina.max_stamina
	var before := p.stamina.current
	p._start_dodge(Vector3.FORWARD)
	var heavy_cost := before - p.stamina.current
	check(heavy_cost > p.dodge_cost * 1.1, "heavy armour: dodge costs %.1f stamina (base %.1f)" % [heavy_cost, p.dodge_cost])
	# Save and load keep the outfit.
	var saved := p.equipment.to_save()
	p.equipment.clear()
	await _frames(1)
	check(p.model.outfit_looks().is_empty(), "no gear: plain clothes")
	p.equipment.from_save(saved)
	await _frames(1)
	check(p.model.outfit_looks().has(&"great_helm") and p.model.outfit_looks().has(&"plate") == false, "outfit restored after loading")
	sk.health.apply_raw_damage(99999.0)
	world.queue_free()
	await _frames(5)

	# The Wizard rule still holds in any outfit.
	world = await _boot_class(&"wizard")
	p = world.player
	p.character.skills[Skill.STRENGTH] = Skill.MAX_LEVEL
	for id in [&"horned_helm", &"chainmail", &"iron_gauntlets", &"iron_greaves", &"iron_kite_shield", &"iron_sword"]:
		_wear(p, id)
	await _frames(1)
	var wiz := p.character.physical_mult * p.character.weapon_mult(&"sword")
	var knight := ClassRegistry.get_class_data(&"knight")
	var knight_start := Skill.physical_damage_mult(knight.starting_skill(Skill.STRENGTH), knight.efficiency(Skill.STRENGTH),
		knight.physical_power) * knight.proficiency(&"sword")
	var knight_max := BalanceModel.max_strength_phys(&"knight") * knight.proficiency(&"sword")
	print("   Wizard in iron with a sword at 100 Strength: x%.2f · starting Knight x%.2f · max Knight x%.2f" % [wiz, knight_start, knight_max])
	# Option A (chosen with the player): close, but never equal.
	check(wiz < knight_max * 0.9, "a Wizard in full iron is never as strong as a Knight (×%.2f)" % (wiz / knight_max))
	check(p.abilities.get_slot(0).id == &"firebolt", "the Wizard keeps Wizard abilities in any outfit")
	world.queue_free()
	await _frames(5)

	# Multiplayer: another player's outfit is drawn from the look event.
	var rp := RemotePlayer.new()
	rp.setup(7, "Guest", &"wizard")
	add_child(rp)
	rp.play_event("look", ["dagger", false, "shadow_hood,shadow_cloak,not_an_item", "iron_dirk"])
	var rl: Array = rp.model.outfit_looks()
	check(rl.has(&"hood_mask") and rl.has(&"cloak") and rl.size() == 2, "a remote player's outfit is shown (unknown ids ignored)")
	rp.queue_free()

# --- Milestone 14: gear makes the hero -----------------------------------------------------

const _M14_SLOTS := [ItemData.EquipSlot.HEAD, ItemData.EquipSlot.CHEST, ItemData.EquipSlot.HANDS, ItemData.EquipSlot.FEET]


func test_m14_gear_data() -> void:
	# Every class starts with a full outfit + weapon, and its full set.
	for c in ClassRegistry.all():
		var eq := ClassPicker.starting_equipment(c)
		var full: bool = eq.weapon() != null
		for slot in _M14_SLOTS:
			full = full and eq.get_item(slot) != null
		check(full, "%s starts with a weapon and a full outfit (head, chest, hands, feet)" % c.display_name)
		var sets := eq.set_counts()
		check(sets.size() == 1 and GearSets.has_set(sets.keys()[0]) and int(sets.values()[0]) == 4,
			"%s starts in its complete set (%s)" % [c.display_name, sets])
		check(not c.starting_items.is_empty(), "%s has its own starting supplies" % c.display_name)
		var st := ClassPicker.starting_stats(c)
		check(int(st.health) > 50 and int(st.armor) >= 0, "%s start: %d health, %d mana, %d armor" % [c.display_name, st.health, st.mana, st.armor])
	# Every armour piece has a drawable look; set pieces give +1/+2 style skill bonuses.
	var bad := []
	var skill_pieces := 0
	for id in ItemDB.all_ids():
		var it: ItemData = ItemDB.get_item(id)
		if it == null or not it.equip_slot in _M14_SLOTS:
			continue
		if not it.outfit_look in HumanoidModel.OUTFIT_LOOKS:
			bad.append(id)
		if it.set_id != &"":
			check(GearSets.has_set(it.set_id), "%s belongs to a real set" % id)
			for s in Skill.ALL:
				if it.stat_bonuses.has(s):
					skill_pieces += 1
					check(int(it.stat_bonuses[s]) >= 1 and int(it.stat_bonuses[s]) <= 3, "%s gives a small skill bonus (+%d %s)" % [id, it.stat_bonuses[s], s])
		check(ItemIcons.shape_of(it) in [&"helmet", &"hood", &"hat", &"crown", &"armor", &"robe", &"gloves", &"boots"],
			"%s gets an armour icon (%s)" % [id, ItemIcons.shape_of(it)])
	check(bad.is_empty(), "every armour piece has a known look style %s" % [bad])
	check(skill_pieces >= 16, "set pieces raise skills (%d bonuses)" % skill_pieces)
	# Anyone can make any set: starting recipes exist for every set piece.
	for id in [&"squire_plate", &"raider_harness", &"shadow_garb", &"wizard_hat"]:
		var r := RecipeBook.get_recipe(id)
		check(r != null and r.source == RecipeData.Source.STARTING, "%s can be crafted by every class" % id)
	# Set bonuses.
	var eq := Equipment.new()
	eq.equip(ItemDB.get_item(&"shadow_hood"))
	check(is_zero_approx(eq.total(&"backstab")), "1 shadow piece: no set bonus yet")
	eq.equip(ItemDB.get_item(&"shadow_garb"))
	check(is_equal_approx(eq.total(&"backstab"), 15.0), "2 shadow pieces: +15% backstab")
	eq.equip(ItemDB.get_item(&"shadow_wraps"))
	eq.equip(ItemDB.get_item(&"shadow_boots"))
	check(is_equal_approx(eq.total(&"dexterity"), 1 + 2 + 1 + 1 + 2.0), "4 pieces: piece bonuses + set Dexterity (%d)" % eq.total(&"dexterity"))
	check(GearSets.describe(&"shadow").size() == 3, "set tooltip lists both bonus tiers")
	check(ItemDB.get_item(&"shadow_garb").effect_lines()[-3].begins_with("Set:"), "item tooltips show the set")
	# Option A: the class keeps a small talent, a Wizard never equals a Knight.
	var kn := ClassRegistry.get_class_data(&"knight")
	var wz := ClassRegistry.get_class_data(&"wizard")
	var as_ := ClassRegistry.get_class_data(&"assassin")
	for strength in [10, 40, 70, 100]:
		var k := Skill.physical_damage_mult(strength, kn.efficiency(Skill.STRENGTH), kn.physical_power) * kn.proficiency(&"sword")
		var w := Skill.physical_damage_mult(strength, wz.efficiency(Skill.STRENGTH), wz.physical_power) * wz.proficiency(&"sword")
		check(w < k * 0.9 and w > k * 0.6, "same Strength %d and sword: Wizard ×%.2f of a Knight (close, never equal)" % [strength, w / k])
	check(kn.proficiency(&"dagger") >= 0.85 and as_.proficiency(&"dagger") > kn.proficiency(&"dagger"),
		"a Knight can fight with daggers (×%.2f), an Assassin still does it best" % kn.proficiency(&"dagger"))
	# Body.
	var clean := CharacterLook.sanitize({"skin": 99, "hair": -4, "style": "x", "beard": 1}, &"wizard")
	check(int(clean.skin) == CharacterLook.SKINS.size() - 1 and int(clean.hair) == 0 and clean.beard == true,
		"hostile look data is clamped")
	# The model draws what is worn, on the chosen body.
	var m := HumanoidModel.new()
	add_child(m)
	m.set_body({"skin": 5, "hair": 6, "style": 1, "beard": true})
	check(m.skin_color == CharacterLook.SKINS[5] and m.hair_color == CharacterLook.HAIRS[6], "the chosen skin and hair are used")
	var bare := m._parts.size()
	m.set_outfit(ClassPicker.starting_equipment(kn).outfit_ids())
	check(m._parts.size() > bare + 8 and &"helm_plume" in m.outfit_looks() and &"plate" in m.outfit_looks(),
		"the Squire's Kit is drawn on the body (%d -> %d parts)" % [bare, m._parts.size()])
	m.set_outfit(ClassPicker.starting_equipment(as_).outfit_ids())
	check(&"cloak" in m.outfit_looks() and &"hood_mask" in m.outfit_looks() and &"wraps" in m.outfit_looks(),
		"the same body in Shadowstalker's Garb looks like an Assassin")
	m.set_outfit(ClassPicker.starting_equipment(ClassRegistry.get_class_data(&"barbarian")).outfit_ids())
	check(&"fur_mantle" in m.outfit_looks() and &"bracers" in m.outfit_looks(), "the Raider's Furs draw a fur mantle and bracers")
	m.queue_free()


func test_m14_gear_in_game() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	var ch := p.character
	check(p.equipment.set_counts().get(&"squire", 0) == 4, "a new Knight wears the full Squire's Kit")
	check(p.inventory.count_of(&"bandage") >= 3, "and gets the Knight's supplies")
	check(&"helm_plume" in p.model.outfit_looks(), "the Knight looks like a knight")
	var parry_kit := ch.parry_window
	var dex_before := ch.skill_level(Skill.DEXTERITY)
	var backstab_before := ch.backstab_mult
	# Change into the Assassin's clothes and daggers: still a Knight, plays like an Assassin.
	for id in [&"shadow_hood", &"shadow_garb", &"shadow_wraps", &"shadow_boots", &"rusty_dagger"]:
		var item: ItemData = ItemDB.get_item(id)
		p.equipment.equip(item)
	p.equipment.unequip(ItemData.EquipSlot.OFF_HAND)
	p._on_equipment_changed()
	check(ch.class_data.id == &"knight", "still a Knight")
	check(ch.skill_level(Skill.DEXTERITY) >= dex_before + 7, "Shadowstalker gear: Dexterity %d -> %d" % [dex_before, ch.skill_level(Skill.DEXTERITY)])
	check(ch.backstab_mult > backstab_before + 0.14, "the set's backstab bonus applies (×%.2f -> ×%.2f)" % [backstab_before, ch.backstab_mult])
	check(ch.parry_window < parry_kit, "the Squire's parry bonus is gone with the Squire's Kit")
	check(p.equipment.weapon_type() == &"dagger" and &"hood_mask" in p.model.outfit_looks()
		and &"cloak" in p.model.outfit_looks(), "and looks like an Assassin")
	var args := p.look_args()
	check(args.size() == 5 and String(args[0]) == "dagger" and (args[4] as Dictionary).size() == 4, "the look event carries outfit + body for other players")
	# A remote puppet draws it the same way.
	var rp := RemotePlayer.new()
	rp.setup(77, "Friend", &"knight")
	world.add_child(rp)
	p.set_look({"skin": 5, "hair": 3, "style": 0, "beard": false})
	args = p.look_args()
	rp.play_event("look", args)
	check(&"cloak" in rp.model.outfit_looks() and rp.model.skin_color == CharacterLook.SKINS[5], "other players see the outfit and the body")
	rp.queue_free()
	# Save / load keeps body and outfit.
	p.set_look({"skin": 4, "hair": 6, "style": 2, "beard": true})
	var saved := p.to_save()
	check((saved.look as Dictionary).hair == 6, "the body is saved")
	p.set_look({})
	p.from_save(saved)
	check(int(p.look.hair) == 6 and int(p.look.style) == 2 and &"cloak" in p.model.outfit_looks(),
		"the body and outfit load back")
	var old := saved.duplicate(true)
	old.erase("look")
	p.from_save(old)
	check(p.look == CharacterLook.default_for(&"knight"), "pre-M14 saves get the class's default body")
	world.queue_free()
	await _frames(2)


func test_m14_character_creation() -> void:
	var picker := ClassPicker.new()
	add_child(picker)
	await _frames(2)
	picker.select_class(&"wizard")
	check(picker.look == CharacterLook.default_for(&"wizard"), "the picker suggests a look per class")
	check(&"wizard_hat" in picker._model.outfit_looks() and &"robe" in picker._model.outfit_looks(), "the preview wears the Wizard's starting kit")
	picker.cycle_look("hair", 1)
	picker.select_class(&"barbarian")
	check(picker.look_edited and int(picker.look.hair) == (CharacterLook.default_for(&"wizard").hair + 1) % CharacterLook.HAIRS.size(),
		"an edited body is kept when switching class")
	check(&"horned_helm" in picker._model.outfit_looks(), "the preview switches to the Raider's kit")
	check(ClassPicker.talent_text(ClassRegistry.get_class_data(&"barbarian")).contains("Strength"), "the class talent is shown")
	var chosen := picker.look.duplicate()
	picker.queue_free()
	# A new world starts the character with the chosen class + body.
	SaveManager.start_transient(GameState.DEFAULT_SEED, &"assassin", chosen)
	var world: World = await _boot_world()
	check(world.player.character.class_data.id == &"assassin" and world.player.look == CharacterLook.sanitize(chosen),
		"the new character has the chosen class and body")
	check(world.player.equipment.set_counts().get(&"shadow", 0) == 4 and world.player.inventory.count_of(&"antidote") >= 2,
		"and the Assassin's starting kit and supplies")
	world.queue_free()
	await _frames(2)


# --- Milestone 15: Living Wilds -------------------------------------------------------------

func test_m15_data() -> void:
	# Every land biome has wild creatures; every entry loads.
	var land := 0
	for b in WildSpawns.TABLE:
		var rules := WildSpawns.rules_for(b)
		check(rules.size() >= 2 and rules.size() == WildSpawns.TABLE[b].size(), "%s has %d wild spawns" % [b, rules.size()])
		land += 1
	check(land >= 10 and WildSpawns.rules_for(&"deep_ocean").is_empty(), "10 land biomes have wild life, the ocean none")
	for id in [&"frost_wolf", &"sand_scorpion", &"shore_crab", &"deer", &"rabbit"]:
		var d: MonsterData = load("res://data/enemies/%s.tres" % id)
		check(d != null and d.look in MonsterModel.BEASTS and d.melee != null and not d.loot.is_empty(), "%s: data, model and loot" % id)
	var wolf: MonsterData = load("res://data/enemies/frost_wolf.tres")
	var scorp: MonsterData = load("res://data/enemies/sand_scorpion.tres")
	var deer: MonsterData = load("res://data/enemies/deer.tres")
	check(wolf.howls and wolf.pack_alert >= 20.0 and float(wolf.damage_multipliers.get(&"fire", 1.0)) > 1.0, "Frost Wolves howl for the pack and are weak to fire")
	check(scorp.burrow_range > 0.0 and scorp.melee_status.size() > 0 and scorp.melee_status[0] == &"poison", "Sand Scorpions burrow and poison")
	check(deer.timid and deer.flee_below >= 1.0, "deer are timid")
	# Spawn slots: groups for packs, every land biome reached on a real world.
	var gen := TerrainGenerator.new(GameState.DEFAULT_SEED, _settings())
	var by_biome := {}
	var wolf_groups := 0
	var counted := 0
	for cx in range(-160, 160, 3):
		for cz in range(-160, 160, 3):
			var slots := gen.get_spawn_slots(Vector2i(cx, cz))
			var wolves := 0
			for sl in slots:
				var rule: EnemySpawnRule = sl.rule
				var bid: StringName = gen.biomes[gen.get_biome_index(int(sl.position.x), int(sl.position.z))].id
				by_biome[bid] = int(by_biome.get(bid, 0)) + 1
				if rule.enemy_data and rule.enemy_data.id == &"frost_wolf":
					wolves += 1
				counted += 1
			if wolves >= 2:
				wolf_groups += 1
	print("   wild spawn slots by biome: %s" % [by_biome])
	check(by_biome.size() >= 8, "wild spawns in %d biomes (was 4)" % by_biome.size())
	check(wolf_groups > 0, "frost wolves come in packs (%d packs)" % wolf_groups)
	var a := gen.get_spawn_slots(Vector2i(12, -7))
	var b2 := gen.get_spawn_slots(Vector2i(12, -7))
	check(a.size() == b2.size() and (a.is_empty() or a[0].key == b2[0].key), "spawn slots are deterministic")
	# Treasure spots.
	var kinds := {}
	var spots := 0
	for cx in range(-250, 250, 2):
		for cz in range(-250, 250, 2):
			var sp := TreasureSpots.spot_for(gen, Vector2i(cx, cz))
			if not sp.is_empty():
				spots += 1
				kinds[sp.kind] = int(kinds.get(sp.kind, 0)) + 1
	print("   treasure spots in 8x8 km (every 2nd chunk): %d %s" % [spots, kinds])
	check(kinds.has(&"camp") and kinds.has(&"buried") and kinds.has(&"shipwreck"), "camps, buried caches and shipwrecks all exist")
	check(TreasureSpots.spot_for(gen, Vector2i(3, 3)) == TreasureSpots.spot_for(gen, Vector2i(3, 3)), "treasure spots are deterministic")
	for t in [&"wild_camp", &"shipwreck", &"buried_cache"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var r := LootTables.roll(t, 2, rng)
		check(int(r.coins) > 0, "%s loot rolls coins" % t)
	# More POIs near spawn.
	check(Exploration.poi_chance(0.0) > 0.85 and is_equal_approx(Exploration.poi_chance(5000.0), Exploration.POI_CHANCE), "the starting region holds more POIs")
	var near := 0
	for cx in range(-10, 10):
		for cz in range(-10, 10):
			var p := gen.pois.get_cell(Vector2i(cx, cz))
			if p and p.rank <= 2 and Vector2(p.center).length() < 2500.0:
				near += 1
	print("   E/D/C POIs within 2.5 km: %d" % near)
	check(near >= 40, "plenty of E/D/C POIs within 2.5 km (%d)" % near)
	# Item quality.
	var fine := ItemDB.get_item(&"iron_sword@fine")
	var mw := ItemDB.get_item(&"crystal_ring@masterwork")
	var base := ItemDB.get_item(&"iron_sword")
	check(fine != null and fine.display_name == "Fine Iron Longsword" and float(fine.stat_bonuses.get(&"damage_bonus", 0.0)) > float(base.stat_bonuses.get(&"damage_bonus", 0.0)),
		"Fine Iron Sword hits harder than an Iron Sword")
	check(mw != null and int(mw.stat_bonuses[&"mana_control"]) == int(ItemDB.get_item(&"crystal_ring").stat_bonuses[&"mana_control"]) + 1
		and float(mw.stat_bonuses[&"spell_power"]) > float(ItemDB.get_item(&"crystal_ring").stat_bonuses[&"spell_power"]), "Masterwork: better stats, +1 skill")
	check(ItemDB.get_item(&"berries@fine") == null and not ItemDB.has_item(&"iron_sword@junk") and ItemDB.has_item(&"iron_sword@masterwork"),
		"only gear has quality")
	check(not ItemDB.all_ids().has(&"iron_sword@fine"), "quality items are not listed as separate items")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3
	var counts := [0, 0, 0]
	for i in 600:
		counts[ItemQuality.roll(100, rng2)] += 1
	var low := 0
	for i in 200:
		low += ItemQuality.roll(15, rng2)
	check(low == 0 and counts[1] > 0 and counts[2] > 0 and counts[0] > counts[1], "quality needs Crafting skill; Grandmasters roll Masterwork (%s)" % [counts])
	# New gear and the respec draught.
	for id in [&"mithril_gauntlets", &"mithril_greaves", &"wanderer_boots", &"ring_of_embers", &"ring_of_swiftness", &"draught_of_forgetting", &"wild_hide"]:
		check(ItemDB.has_item(id) and RecipeBook.get_recipe(id if id != &"wild_hide" else &"leather_from_hide") != null, "%s exists with a recipe" % id)
	check(ItemDB.get_item(&"draught_of_forgetting").is_consumable(), "the Draught of Forgetting can be drunk")


func test_m15_wilds_ingame() -> void:
	var world: World = await _boot_class(&"knight")
	var p := world.player
	p.health.invulnerable = true
	_clear_enemies(world)
	world.spawner.max_active = 60
	# Wolf pack: one wolf sees you and howls; the others come too.
	var wolves: Array[Monster] = []
	for k in 3:
		wolves.append(_spawn_monster(world, &"frost_wolf", Vector3(18.0 + k * 1.5, 0, 0)))
	await _frames(3)
	check(wolves.all(func(w: Monster) -> bool: return w.ai in [Monster.AI.IDLE, Monster.AI.WANDER]), "the pack rests")
	wolves[0]._alert(p)
	await _frames(3)
	check(wolves[1].ai != Monster.AI.IDLE and wolves[2].ai != Monster.AI.IDLE and wolves[1].target == p, "one howl and the whole pack hunts you")
	for w in wolves:
		_kill(w, world)
	# Sand scorpion: buried until you come close.
	var sc := _spawn_monster(world, &"sand_scorpion", Vector3(0, 0, 9))
	await _frames(3)
	check(sc.ai == Monster.AI.DORMANT and sc.model.position.y < -0.3, "the scorpion waits under the sand")
	sc.global_position = p.global_position + Vector3(0, 0, 3.5)
	await _frames(25)
	check(sc.ai != Monster.AI.DORMANT and sc.model.position.y > -0.1, "and bursts out when you step close")
	_kill(sc, world)
	# Deer: runs away, never fights.
	var deer := _spawn_monster(world, &"deer", Vector3(6, 0, 0))
	await _frames(3)
	var d0 := deer.global_position.distance_to(p.global_position)
	deer._alert(p)
	await _frames(60)
	check(deer.ai == Monster.AI.FLEE and deer.global_position.distance_to(p.global_position) > d0 + 1.0, "the deer flees (%.1f -> %.1f m)" % [d0, deer.global_position.distance_to(p.global_position)])
	var meat := func() -> int:
		var n := 0
		for c in world.pickup_pool.get_children():
			if c is Pickup and c.visible and (c as Pickup).item_id == &"raw_meat":
				n += 1
		return n + p.inventory.count_of(&"raw_meat")
	var meat_before: int = meat.call()
	_kill(deer, world)
	await _frames(5)
	check(int(meat.call()) > meat_before, "hunting a deer drops meat")
	# A treasure site: open its chest once.
	var site := TreasureSpots.build_site({"kind": &"buried", "position": p.global_position + Vector3(3, 0, 3), "key": "t:test", "rank": 1})
	world.add_child(site)
	await _frames(2)
	var chest: LootChest = null
	for c in site.get_children():
		if c is LootChest:
			chest = c
	var coins := p.coins
	chest.interact(p)
	check(chest.opened and p.coins > coins and world.exploration.has_state("open:t:test"), "the buried cache pays out once and is remembered")
	site.queue_free()
	# Respec.
	var ch := p.character
	ch.grant_xp(Progression.total_xp_for(8), Progression.Source.OTHER)
	var pts := ch.unspent_points
	for k in pts:
		ch.spend_point(Skill.STRENGTH)
	check(ch.unspent_points == 0 and ch.base_skill(Skill.STRENGTH) > ch.class_data.starting_skill(Skill.STRENGTH), "points spent on Strength")
	p.inventory.add_item(&"draught_of_forgetting", 1)
	for i in p.inventory.capacity:
		var s = p.inventory.get_slot(i)
		if s != null and s.id == &"draught_of_forgetting":
			p.use_slot(i)
			break
	check(ch.unspent_points == pts and ch.base_skill(Skill.STRENGTH) == ch.class_data.starting_skill(Skill.STRENGTH)
		and p.inventory.count_of(&"draught_of_forgetting") == 0, "the Draught of Forgetting gives back every point (%d)" % pts)
	# Crafting can give quality gear and it equips like any other item.
	p.equipment.equip(ItemDB.get_item(&"iron_sword@masterwork"))
	p._on_equipment_changed()
	check(p.equipment.weapon_type() == &"sword" and p.equipment.to_save().values().has("iron_sword@masterwork"), "quality gear equips and saves by id")
	world.queue_free()
	await _frames(2)
