extends Node
## Automated test suite: unit tests for core systems + integration tests that
## boot the real main scene and play it with simulated input.
##
## Run headless:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all passed, 1 = failures.

var _passed := 0
var _failed := 0
var _current := ""


func _ready() -> void:
	print("\n=== Shardlands test suite ===")
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
	print("\n=== %d passed, %d failed (%.1fs) ===" % [_passed, _failed, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(1 if _failed > 0 else 0)


func _run(test: StringName) -> void:
	_current = test
	print("\n-- %s" % test)
	call(test)


func _run_async(test: StringName) -> void:
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
	fire.interact(player)
	check(player.inventory.count_of(&"cooked_meat") == 1 and player.inventory.count_of(&"raw_meat") == raw - 1, "cooking converts raw meat")
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
	check(total > 5000000, "reaching level 100 takes millions of XP (endgame not trivial)")
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
	check(wiz100 < kn_start, "a max-Strength Wizard hits softer than a starting Knight")
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
	check(ch.armor > armor_now + 10.0 and player.inventory.count_of(&"padded_vest") == 1, "armor rises and old chest piece returns to the inventory")
	var dmg_sword := ch.weapon_mult(&"sword")
	check(dmg_sword > ch.weapon_mult(&"staff"), "Knights are proficient with swords, not staves")
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
