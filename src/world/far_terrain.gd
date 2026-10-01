class_name FarTerrain
extends Node3D
## Horizon terrain beyond the chunk LOD rings (Milestone 9).
##
## The surface is drawn out to `radius_chunks` with 64 m super-tiles (4 x 4
## chunks), one 8 x 8 m column per cell: coastlines, mountains, lakes and biome
## colours stay visible far past the streamed chunks. Each tile is a single
## mesh (terrain + water) without collision, props or shadows.
##
## The cells under the near chunks are cut out (the "hole"), and tiles sit
## SINK metres lower so where they overlap the outermost chunk ring the real
## chunk always wins. Tile heights are sampled on worker threads and cached,
## so moving only re-meshes the tiles along the hole's edge.

const TILE_CHUNKS := 4
const TILE_SIZE := TILE_CHUNKS * TerrainGenerator.CHUNK_SIZE
const STEP := 8
const CELLS := TILE_SIZE / STEP
const W := CELLS + 2
## Far tiles sit this far below the real surface (m).
const SINK := 1.0
const WATER_Y := TerrainGenerator.WATER_Y - 0.3
const HOLE_SKIRT_BLOCKS := 6
## Tile height grids kept in memory (~0.5 KB each).
const HEIGHT_CACHE_MAX := 4096
const MAX_TASKS := 3

## Horizon distance in chunks (32 chunks = 512 m).
@export var radius_chunks: int = 32

var generator: TerrainGenerator

var _tiles: Dictionary = {}  # Vector2i -> {"mi": MeshInstance3D, "holed": bool, "hole": Vector2i}
var _heights: Dictionary = {}  # Vector2i -> [PackedInt32Array heights, PackedByteArray biomes]
var _queue: Array[Vector2i] = []
var _pending: Dictionary = {}  # Vector2i -> task id
var _results: Array = []
var _mutex := Mutex.new()
var _pool: Array[MeshInstance3D] = []
var _center := Vector2i(0x7FFFFFFF, 0)
var _hole_r := 8
var _active := false
var _built := 0


func setup(p_generator: TerrainGenerator) -> void:
	generator = p_generator


func _exit_tree() -> void:
	for t in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[t])
	_pending.clear()


func tile_count() -> int:
	return _tiles.size()


func pending_count() -> int:
	return _queue.size() + _pending.size()


func built_count() -> int:
	return _built


static func tile_of_chunk(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / TILE_CHUNKS), floori(float(c.y) / TILE_CHUNKS))


## Nearest and farthest chunk distance from `center` to any chunk of tile `t`.
static func tile_distance_range(t: Vector2i, center: Vector2i) -> Vector2:
	var lo := t * TILE_CHUNKS
	var hi := lo + Vector2i(TILE_CHUNKS - 1, TILE_CHUNKS - 1)
	var nx := clampi(center.x, lo.x, hi.x)
	var nz := clampi(center.y, lo.y, hi.y)
	var fx := lo.x if absi(center.x - lo.x) > absi(center.x - hi.x) else hi.x
	var fz := lo.y if absi(center.y - lo.y) > absi(center.y - hi.y) else hi.y
	return Vector2(Vector2(nx - center.x, nz - center.y).length(), Vector2(fx - center.x, fz - center.y).length())


## Called by ChunkManager when the focus enters a new chunk (or changes layer).
## `hole_r`: chunks within this distance (+0.5) are left to the chunk rings.
func update_focus(center: Vector2i, layer: int, hole_r: int) -> void:
	_center = center
	_hole_r = hole_r
	_active = layer == TerrainGenerator.Layer.SURFACE and generator != null
	visible = _active
	if not _active:
		for t: Vector2i in _tiles.keys():
			_release(t)
		_queue.clear()
		return
	var tc := tile_of_chunk(center)
	var rt := ceili(float(radius_chunks) / TILE_CHUNKS) + 1
	# Drop tiles that left the horizon or vanished under the chunk rings.
	for t: Vector2i in _tiles.keys():
		var dr := tile_distance_range(t, center)
		if dr.x > radius_chunks + TILE_CHUNKS or dr.y < hole_r - 0.5:
			_release(t)
	_queue.clear()
	for tz in range(tc.y - rt, tc.y + rt + 1):
		for tx in range(tc.x - rt, tc.x + rt + 1):
			var t := Vector2i(tx, tz)
			var dr := tile_distance_range(t, center)
			if dr.x > radius_chunks or dr.y < hole_r - 0.5:
				continue
			var tile: Dictionary = _tiles.get(t, {})
			if tile.is_empty():
				_queue.append(t)
			elif tile.hole != center and (tile.holed or dr.x <= hole_r + 1.5):
				_queue.append(t)  # the hole moved across this tile: re-cut it
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return tile_distance_range(a, center).x < tile_distance_range(b, center).x)


## Starts up to `slots` worker jobs (shared with chunk generation).
func dispatch(slots: int) -> void:
	if not _active:
		return
	var n := mini(slots, MAX_TASKS - _pending.size())
	var i := 0
	while n > 0 and i < _queue.size():
		var t := _queue[i]
		if _pending.has(t):
			i += 1
			continue
		_queue.remove_at(i)
		var cached: Array = _heights.get(t, [])
		var task := WorkerThreadPool.add_task(_job.bind(t, _center, _hole_r, cached), false, "far_tile")
		_pending[t] = task
		n -= 1


## Builds finished tiles within `budget_ms` of main-thread time.
func apply_results(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while true:
		_mutex.lock()
		var r: Dictionary = {} if _results.is_empty() else _results.pop_front()
		_mutex.unlock()
		if r.is_empty():
			return
		var t: Vector2i = r.tile
		if _pending.has(t):
			WorkerThreadPool.wait_for_task_completion(_pending[t])
			_pending.erase(t)
		_store_heights(t, r.heights, r.biomes)
		if not _active:
			continue
		var dr := tile_distance_range(t, _center)
		if dr.x > radius_chunks + TILE_CHUNKS or dr.y < _hole_r - 0.5:
			continue
		_apply_mesh(t, r)
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			return


func _store_heights(t: Vector2i, h: PackedInt32Array, b: PackedByteArray) -> void:
	if _heights.size() >= HEIGHT_CACHE_MAX and not _heights.has(t):
		# Forget grids of tiles that are not on screen.
		for k: Vector2i in _heights.keys():
			if not _tiles.has(k):
				_heights.erase(k)
	_heights[t] = [h, b]


func _apply_mesh(t: Vector2i, r: Dictionary) -> void:
	var tile: Dictionary = _tiles.get(t, {})
	if tile.is_empty():
		var mi: MeshInstance3D = _pool.pop_back() if not _pool.is_empty() else null
		if mi == null:
			mi = MeshInstance3D.new()
			mi.mesh = ArrayMesh.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
		mi.visible = true
		mi.position = Vector3(t.x * TILE_SIZE, -SINK, t.y * TILE_SIZE)
		tile = {"mi": mi, "holed": false, "hole": r.hole}
		_tiles[t] = tile
	tile.holed = r.holed
	tile.hole = r.hole
	var mesh: ArrayMesh = tile.mi.mesh
	mesh.clear_surfaces()
	var terrain: Array = r.terrain
	if not (terrain[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, terrain)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Materials.vertex_color())
	var water: Array = r.water
	if not (water[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Materials.water())
	_built += 1


func _release(t: Vector2i) -> void:
	var tile: Dictionary = _tiles.get(t, {})
	if tile.is_empty():
		return
	_tiles.erase(t)
	var mi: MeshInstance3D = tile.mi
	(mi.mesh as ArrayMesh).clear_surfaces()
	mi.visible = false
	_pool.append(mi)


# --- Worker side ---------------------------------------------------------------------

## Runs on a worker thread: samples the tile (unless cached) and builds its mesh.
func _job(t: Vector2i, hole_center: Vector2i, hole_r: int, cached: Array) -> void:
	var r := build_tile(t, hole_center, hole_r, cached)
	_mutex.lock()
	_results.append(r)
	_mutex.unlock()


## Pure function (thread-safe): mesh arrays for tile `t` with the hole cut out.
func build_tile(t: Vector2i, hole_center: Vector2i, hole_r: int, cached: Array = []) -> Dictionary:
	var ox := t.x * TILE_SIZE
	var oz := t.y * TILE_SIZE
	var heights: PackedInt32Array
	var biome_ids: PackedByteArray
	if cached.size() == 2:
		heights = cached[0]
		biome_ids = cached[1]
	else:
		heights.resize(W * W)
		biome_ids.resize(W * W)
		for j in W:
			for i in W:
				# Each cell is represented by the column at its centre.
				var smp := generator.sample_column(ox + (i - 1) * STEP + STEP / 2, oz + (j - 1) * STEP + STEP / 2)
				heights[j * W + i] = TerrainGenerator.unpack_height(smp)
				biome_ids[j * W + i] = TerrainGenerator.unpack_biome(smp)
	var skip := PackedByteArray()
	skip.resize(W * W)
	var holed := false
	var limit := float(hole_r) + 0.5
	for j in W:
		for i in W:
			var cx := floori(float(ox + (i - 1) * STEP + STEP / 2) / TerrainGenerator.CHUNK_SIZE)
			var cz := floori(float(oz + (j - 1) * STEP + STEP / 2) / TerrainGenerator.CHUNK_SIZE)
			if Vector2(cx - hole_center.x, cz - hole_center.y).length() <= limit:
				skip[j * W + i] = 1
				if i > 0 and j > 0 and i <= CELLS and j <= CELLS:
					holed = true
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wi := PackedInt32Array()
	var bh := TerrainGenerator.BLOCK_HEIGHT
	for j in range(1, CELLS + 1):
		for i in range(1, CELLS + 1):
			var k := j * W + i
			if skip[k] == 1:
				continue
			var h := heights[k]
			var biome: BiomeData = generator.biomes[biome_ids[k]]
			var x0 := float((i - 1) * STEP)
			var z0 := float((j - 1) * STEP)
			var x1 := x0 + STEP
			var z1 := z0 + STEP
			var y := h * bh
			var top := generator._top_color(biome, h, ox + (i - 1) * STEP, oz + (j - 1) * STEP, true)
			TerrainGenerator._quad(v, nrm, col, idx, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1),
				Vector3(x0, y, z1), Vector3.UP, top)
			_side(v, nrm, col, idx, biome, h, heights[k + 1], skip[k + 1] == 1, Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.RIGHT, top)
			_side(v, nrm, col, idx, biome, h, heights[k - 1], skip[k - 1] == 1, Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.LEFT, top)
			_side(v, nrm, col, idx, biome, h, heights[k + W], skip[k + W] == 1, Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.BACK, top)
			_side(v, nrm, col, idx, biome, h, heights[k - W], skip[k - W] == 1, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.FORWARD, top)
			if h < TerrainGenerator.SEA_LEVEL:
				if biome.frozen_water:
					TerrainGenerator._quad(v, nrm, col, idx, Vector3(x0, WATER_Y, z0), Vector3(x1, WATER_Y, z0),
						Vector3(x1, WATER_Y, z1), Vector3(x0, WATER_Y, z1), Vector3.UP, biome.ice_color)
				else:
					var base := wv.size()
					wv.append_array([Vector3(x0, WATER_Y, z0), Vector3(x1, WATER_Y, z0), Vector3(x1, WATER_Y, z1), Vector3(x0, WATER_Y, z1)])
					for _n in 4:
						wn.push_back(Vector3.UP)
					BlockMesh.append_quad_indices(wi, base, wv[base], wv[base + 1], wv[base + 2], Vector3.UP)
	var terrain := []
	terrain.resize(Mesh.ARRAY_MAX)
	terrain[Mesh.ARRAY_VERTEX] = v
	terrain[Mesh.ARRAY_NORMAL] = nrm
	terrain[Mesh.ARRAY_COLOR] = col
	terrain[Mesh.ARRAY_INDEX] = idx
	var water := []
	water.resize(Mesh.ARRAY_MAX)
	water[Mesh.ARRAY_VERTEX] = wv
	water[Mesh.ARRAY_NORMAL] = wn
	water[Mesh.ARRAY_INDEX] = wi
	return {"tile": t, "heights": heights, "biomes": biome_ids, "terrain": terrain, "water": water,
		"hole": hole_center, "holed": holed}


## Wall down to a lower neighbour; a skirt where the neighbour is cut out.
func _side(v: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array,
		biome: BiomeData, h: int, nh: int, neighbour_cut: bool, a: Vector3, b: Vector3, normal: Vector3, top: Color) -> void:
	var bottom := mini(nh, h) - HOLE_SKIRT_BLOCKS if neighbour_cut else nh
	if bottom >= h:
		return
	var bh := TerrainGenerator.BLOCK_HEIGHT
	var shade := 0.72 if normal.z != 0.0 else 0.8
	var band := maxi(bottom, h - 2)
	TerrainGenerator._quad(v, nrm, col, idx, Vector3(a.x, h * bh, a.z), Vector3(b.x, h * bh, b.z),
		Vector3(b.x, band * bh, b.z), Vector3(a.x, band * bh, a.z), normal, top * shade)
	if band > bottom:
		TerrainGenerator._quad(v, nrm, col, idx, Vector3(a.x, band * bh, a.z), Vector3(b.x, band * bh, b.z),
			Vector3(b.x, bottom * bh, b.z), Vector3(a.x, bottom * bh, a.z), normal, generator._side_color(biome, h, true) * shade)
