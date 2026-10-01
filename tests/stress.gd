class_name Stress
extends RefCounted
## World-generation stress test and in-game performance benchmarks
## (Milestone 12). Shared by tools/stress_test.tscn (writes docs/PERFORMANCE.md)
## and the test suite (test_m12_worldgen_stress, test_m12_performance), so the
## documented numbers and the enforced budgets come from the same code.

## Frame-time budgets (ms) the tests enforce. Headless runs measure CPU work
## only (scripts, physics, generation) - there is no GPU in the loop.
const BUDGET_AVG_MS := 16.7
const BUDGET_P95_MS := 33.3
const BUDGET_STREAM_SPIKE_MS := 250.0
const BUDGET_STREAM_READY_S := 12.0
const BUDGET_CHUNK_MS := 60.0


# --- World generation ------------------------------------------------------------------------

## Generates a world for one seed and checks everything a new game relies on:
## a spawn on land, towns and points of interest within reach, valid chunk
## meshes everywhere (centre, random far points, the world edge, caves),
## determinism and dungeon layouts.
static func worldgen_seed(seed_value: int, chunks: int = 24) -> Dictionary:
	var settings: WorldGenSettings = load("res://data/worldgen/default_worldgen.tres")
	var res := {"seed": seed_value, "errors": PackedStringArray()}
	var t0 := Time.get_ticks_usec()
	var gen := TerrainGenerator.new(seed_value, settings)
	res.init_ms = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var col := gen.find_spawn_column(Vector2i.ZERO)
	res.spawn_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var spawn := Vector3(col.x + 0.5, 0, col.y + 0.5)
	var h := gen.get_height_at(spawn)
	var biome := gen.get_biome_at(spawn)
	res.spawn = col
	res.spawn_biome = String(biome.id) if biome else "?"
	res.spawn_dist = Vector2(col).length()
	if not is_finite(h) or h < TerrainGenerator.SEA_LEVEL * TerrainGenerator.BLOCK_HEIGHT:
		res.errors.append("spawn in water or invalid (h=%.1f)" % h)
	# Towns and points of interest a new player can reach.
	var towns := gen.settlements.near(spawn, 2000.0)
	res.towns_2km = towns.size()
	var nearest := INF
	for t in towns:
		nearest = minf(nearest, t.world_center().distance_to(spawn))
	res.nearest_town = nearest
	if towns.is_empty():
		res.errors.append("no town within 2 km of spawn")
	var pois := gen.pois.near(spawn, 2500.0)
	var kinds := [0, 0, 0, 0, 0]
	var ranks := [0, 0, 0, 0, 0, 0]
	var dungeons: Array[PoiInfo] = []
	for q in pois:
		kinds[q.kind] += 1
		ranks[q.rank] += 1
		if q.kind == PoiInfo.Kind.DUNGEON:
			dungeons.append(q)
	res.pois_2_5km = pois.size()
	res.poi_kinds = kinds
	res.poi_ranks = ranks
	if kinds[PoiInfo.Kind.RUINS] == 0 or ranks[0] == 0:
		res.errors.append("no E-rank ruins near spawn")
	# Chunks: around spawn, random far points, the world edge, underground.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sc := Vector2i(floori(col.x / 16.0), floori(col.y / 16.0))
	var r := TerrainGenerator.WORLD_RADIUS_CHUNKS
	var jobs := []
	for i in chunks:
		var c: Vector2i
		var layer := TerrainGenerator.Layer.SURFACE
		match i % 4:
			0:
				c = sc + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
			1:
				c = Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
			2:
				var e := rng.randi_range(-r, r)
				c = [Vector2i(r, e), Vector2i(-r, e), Vector2i(e, r), Vector2i(e, -r)][rng.randi() % 4]
			3:
				c = sc + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
				layer = TerrainGenerator.Layer.UNDERGROUND
		jobs.append([c, layer])
	var total := 0.0
	var worst := 0.0
	var verts := 0
	for j in jobs:
		t0 = Time.get_ticks_usec()
		var d := gen.generate_chunk(j[0], 0, j[1])
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		worst = maxf(worst, ms)
		verts += d.vertices.size()
		var err := validate_chunk(d)
		if err != "":
			res.errors.append("chunk %s layer %d: %s" % [str(j[0]), j[1], err])
	res.chunk_avg_ms = total / jobs.size()
	res.chunk_max_ms = worst
	res.avg_verts = verts / jobs.size()
	# Determinism: a second generator with the same seed builds the same chunk.
	var gen2 := TerrainGenerator.new(seed_value, settings)
	var a := gen.generate_chunk(sc, 0)
	var b := gen2.generate_chunk(sc, 0)
	res.deterministic = a.vertices == b.vertices and a.colors == b.colors and a.props.size() == b.props.size()
	if not res.deterministic:
		res.errors.append("same seed produced a different chunk")
	# Dungeon layouts for the nearby dungeons, every floor.
	var floors := 0
	for dq in dungeons.slice(0, 4):
		for f in DungeonPlan.FLOORS[dq.rank]:
			var plan := DungeonPlan.generate(dq, f)
			floors += 1
			if plan.rooms.size() < 2 or plan.start_room == plan.end_room:
				res.errors.append("dungeon %s floor %d: %d rooms" % [dq.name, f, plan.rooms.size()])
	res.dungeon_floors = floors
	return res


## "" when a chunk mesh is sound, otherwise what is wrong.
static func validate_chunk(d: ChunkData) -> String:
	if d.vertices.size() != d.normals.size() or d.vertices.size() != d.colors.size():
		return "attribute sizes differ"
	if d.indices.size() % 3 != 0:
		return "indices are not whole triangles"
	for i in d.indices:
		if i < 0 or i >= d.vertices.size():
			return "index out of range"
	for v in d.vertices:
		if not v.is_finite() or absf(v.y) > 2000.0:
			return "bad vertex %s" % str(v)
	return ""


# --- In-game performance ---------------------------------------------------------------------

## Frame times (ms) over `frames` frames: avg, p95, max.
static func frame_times(tree: SceneTree, frames: int) -> Dictionary:
	var times := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for i in frames:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	return summarize(times)


static func summarize(times: PackedFloat64Array) -> Dictionary:
	if times.is_empty():
		return {"avg": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := times.duplicate()
	sorted.sort()
	var sum := 0.0
	for t in times:
		sum += t
	return {"avg": sum / times.size(), "p95": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "max": sorted[sorted.size() - 1]}


## Runs the benchmark scenarios in a booted world. Returns scenario -> stats.
static func benchmark(tree: SceneTree, world: World, scale: float = 1.0) -> Dictionary:
	var p := world.player
	p.health.invulnerable = true
	var out := {}
	await tree.process_frame
	out.idle = await frame_times(tree, roundi(180 * scale))
	out.idle.nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	# 1. A crowd of fighting monsters around the player.
	var md_ids := [&"skeleton_warrior", &"thorn_crawler", &"bandit_thug", &"grotto_cultist"]
	var spawned := []
	var n_enemies := roundi(40 * scale)
	for i in n_enemies:
		var ang := TAU * i / n_enemies
		var pos := p.global_position + Vector3(cos(ang), 0, sin(ang)) * (8.0 + (i % 4) * 3.0)
		pos.y = world.get_ground_height(pos) + 0.3
		var md: MonsterData = load("res://data/enemies/%s.tres" % md_ids[i % md_ids.size()])
		var m := world.spawner.spawn_enemy(PoiSite.MONSTER_SCENE, pos, "", md)
		if m:
			spawned.append(m)
	out.enemies = await frame_times(tree, roundi(240 * scale))
	out.enemies.count = spawned.size()
	for m in spawned:
		if is_instance_valid(m):
			m.queue_free()
	await tree.process_frame
	# 2. A large base: a grid of floors with walls around it.
	var placed := 0
	var floor_data := BuildingManager.get_piece_data(&"wood_floor")
	var wall_data := BuildingManager.get_piece_data(&"wood_wall")
	var origin := Vector2i(floori(p.global_position.x) + 6, floori(p.global_position.z) + 6)
	var side := roundi(18 * sqrt(scale))
	for x in side:
		for z in side:
			# No player: the reach limit doesn't apply (a base built over time).
			if world.building.place(floor_data, origin + Vector2i(x, z), "floor", 0, null, false):
				placed += 1
			if (x % 3 == 0 or z % 3 == 0) and world.building.place(wall_data, origin + Vector2i(x, z), "edge_n", 0, null, false):
				placed += 1
	out.buildings = await frame_times(tree, roundi(180 * scale))
	out.buildings.count = placed
	# 3. Particle bursts every frame (spells, hits, weather).
	var bursts := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for i in roundi(180 * scale):
		for k in 3:
			VFX.burst(world, p.global_position + Vector3(randf_range(-6, 6), 1.0, randf_range(-6, 6)), 1.2, Color(1, 0.6, 0.2, 0.8))
		await tree.process_frame
		var now := Time.get_ticks_usec()
		bursts.append((now - last) / 1000.0)
		last = now
	out.particles = summarize(bursts)
	# 4. Streaming: travel far in one jump (fast travel / teleport) four times.
	var spikes := PackedFloat64Array()
	var ready_s := 0.0
	var start := p.global_position
	for leg in 4:
		var target := start + Vector3(700.0 * (leg + 1), 0, 350.0 * (leg % 2))
		target.y = world.get_ground_height(target) + 2.0
		p.global_position = target
		p.velocity = Vector3.ZERO
		var t0 := Time.get_ticks_usec()
		var lastf := t0
		var waited := 0
		while (not world.chunk_manager.is_near_area_ready()) and waited < 3000:
			await tree.process_frame
			var now := Time.get_ticks_usec()
			spikes.append((now - lastf) / 1000.0)
			lastf = now
			waited += 1
		ready_s = maxf(ready_s, (Time.get_ticks_usec() - t0) / 1000000.0)
		# Keep walking a little while the rest of the view distance streams in.
		for i in roundi(90 * scale):
			p.global_position += Vector3(0.12, 0, 0)
			await tree.process_frame
			var now := Time.get_ticks_usec()
			spikes.append((now - lastf) / 1000.0)
			lastf = now
	out.streaming = summarize(spikes)
	out.streaming.ready_s = ready_s
	out.memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	return out
