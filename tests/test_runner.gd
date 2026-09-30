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


func _biome() -> BiomeData:
	return load("res://data/biomes/verdant_meadow.tres")


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
	var a := TerrainGenerator.new(42, _biome())
	var b := TerrainGenerator.new(42, _biome())
	var c := TerrainGenerator.new(43, _biome())
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
	var g := TerrainGenerator.new(GameState.DEFAULT_SEED, _biome())
	var hmin := 99999
	var hmax := -99999
	var water := 0
	var n := 0
	for z in range(-600, 600, 12):
		for x in range(-600, 600, 12):
			var h := g.get_height_blocks(x, z)
			hmin = mini(hmin, h)
			hmax = maxi(hmax, h)
			if h < TerrainGenerator.SEA_LEVEL:
				water += 1
			n += 1
	var wf := float(water) / n
	print("   heights: min %d max %d (blocks), water %.1f%%" % [hmin, hmax, wf * 100.0])
	check(wf > 0.01 and wf < 0.45, "some lakes but mostly land")
	check(hmax > 20, "there are hills (max %d blocks)" % hmax)
	check(hmax < 120, "no absurd spikes")


func test_chunk_generation() -> void:
	var g := TerrainGenerator.new(7, _biome())
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
	var g1 := TerrainGenerator.new(99, _biome())
	var g2 := TerrainGenerator.new(99, _biome())
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
	check(ItemDB.all_ids().size() >= 10, "ItemDB loaded %d items" % ItemDB.all_ids().size())
	var lib := PropLibrary.new()
	var biome := _biome()
	var ok := true
	for rule in biome.prop_rules:
		var pd := lib.get_prop(rule.prop_id)
		if pd == null:
			ok = false
			print("   missing prop %s" % rule.prop_id)
			continue
		if lib.get_mesh(rule.prop_id) == null:
			ok = false
		for loot in pd.drops:
			if not ItemDB.has_item(loot.item_id):
				ok = false
				print("   prop %s drops unknown item %s" % [pd.id, loot.item_id])
		if TerrainGenerator.CHUNK_SIZE % rule.cell_size != 0:
			ok = false
	check(ok, "all biome props exist, have meshes and valid drops")
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
	GameState.reset(GameState.DEFAULT_SEED)
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
