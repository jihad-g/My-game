class_name ChunkManager
extends Node3D
## Streams chunks around a focus node (the player).
##
## - Desired chunks form rings around the focus with decreasing detail:
##   LOD0 (full detail + collision + props) -> LOD1 -> LOD2 (coarse, no props).
##   Beyond the rings, FarTerrain draws 64 m super-tiles out to the horizon.
## - ChunkData is generated on WorkerThreadPool threads (pure data), then turned
##   into nodes on the main thread within a per-frame time budget (ms), so a
##   burst of finished chunks never causes a hitch.
## - Generated data is kept in an LRU cache with a memory budget: walking back
##   into an area, or a chunk changing LOD back and forth, needs no regeneration.
## - Prefetch (Milestone 9): while the focus moves, the chunks that will be needed
##   around where it is heading are generated into the cache ahead of time, and
##   the work queue favours chunks in the direction of travel.
## - Chunks outside the outer radius are unloaded back into a node pool.
## - Only world *modifications* are persisted (GameState / RegionStore), so
##   unloaded chunks can be regenerated identically at any time.

signal chunk_ready(coord: Vector2i, lod: int, chunk: Chunk)
signal chunk_removed(coord: Vector2i)

## Chunk radius for each LOD level, ascending.
@export var lod_radii: PackedInt32Array = PackedInt32Array([3, 6, 9])
## Worker tasks in flight at once (0 = automatic from the CPU core count).
@export var max_concurrent_tasks: int = 0
## Main-thread time per frame for turning generated data into nodes (ms).
@export var apply_budget_ms: float = 4.0
## Hard cap on chunks built per frame (even when they are cheap).
@export var max_applies_per_frame: int = 8
## Extra radius before a chunk is unloaded (prevents thrashing at the edge).
@export var unload_margin: float = 1.5
## Memory budget of the generated-data cache (MB).
@export var cache_budget_mb: float = 48.0
## How far ahead (seconds of travel) prefetch looks.
@export var prefetch_seconds: float = 3.0
## Most chunks queued for prefetch at once.
@export var max_prefetch: int = 96
## Draws low-detail terrain to the horizon beyond the LOD rings.
@export var far_terrain_enabled: bool = true
## Settlements/POIs within this distance (m) are laid out in the background.
@export var prewarm_radius_m: int = 1500

var generator: TerrainGenerator
var library: PropLibrary
var focus: Node3D
## World layer being streamed (TerrainGenerator.Layer). Change with set_layer().
var layer: int = 0
## Horizon terrain (null when disabled).
var far: FarTerrain

var _chunks: Dictionary = {}  # Vector2i -> Chunk
var _desired: Dictionary = {}  # Vector2i -> lod
var _pending: Dictionary = {}  # Vector2i -> {"task": int, "lod": int, "prefetch": bool}
var _queue: Array[Vector2i] = []
var _prefetch_queue: Array = []  # of [Vector2i, lod]
var _results: Array[ChunkData] = []
var _results_mutex := Mutex.new()
var _cached_ready: Array[ChunkData] = []  # cache hits waiting to be built
var _center := Vector2i(0x7FFFFFFF, 0)
var _pool: Array[Chunk] = []
var _cache: Dictionary = {}  # Vector4i(x, z, lod, layer) -> ChunkData
var _cache_used: Dictionary = {}  # same key -> last-use tick
var _cache_bytes := 0
var _tick := 0
var _velocity := Vector3.ZERO
var _last_pos := Vector3.INF
var _threads := 4
var _prewarm_task := -1
var _prewarm_at := Vector2i(0x7FFFFFFF, 0)
var _stats := {"generated": 0, "discarded": 0, "cache_hits": 0, "prefetched": 0, "evicted": 0,
	"apply_ms": 0.0, "applied": 0, "apply_ms_max": 0.0, "prewarms": 0}


func setup(p_generator: TerrainGenerator, p_library: PropLibrary) -> void:
	generator = p_generator
	library = p_library
	_threads = max_concurrent_tasks if max_concurrent_tasks > 0 else clampi(OS.get_processor_count() - 1, 2, 8)
	if far_terrain_enabled and far == null:
		far = FarTerrain.new()
		far.name = "FarTerrain"
		add_child(far)
	if far:
		far.setup(generator)


func _process(delta: float) -> void:
	if generator == null or focus == null:
		return
	_track_velocity(delta)
	var c := TerrainGenerator.world_to_chunk(focus.global_position)
	if c != _center:
		_center = c
		_update_desired()
		if far:
			far.update_focus(_center, layer, lod_radii[lod_radii.size() - 1] - 1)
		_maybe_prewarm()
	_dispatch()
	_apply_results()


func _exit_tree() -> void:
	# Never leave worker tasks running against freed data.
	if _prewarm_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_prewarm_task)
		_prewarm_task = -1
	for coord in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[coord].task)
	_pending.clear()


# --- Public queries --------------------------------------------------------------

func get_chunk(coord: Vector2i) -> Chunk:
	return _chunks.get(coord)


func is_collision_ready_at(pos: Vector3) -> bool:
	var chunk: Chunk = _chunks.get(TerrainGenerator.world_to_chunk(pos))
	return chunk != null and chunk.has_collision()


## True when every LOD0 chunk around the focus is built.
func is_near_area_ready() -> bool:
	if focus == null or TerrainGenerator.world_to_chunk(focus.global_position) != _center:
		return false  # focus moved; desired set not refreshed yet
	for coord in _desired:
		if _desired[coord] == 0:
			var chunk: Chunk = _chunks.get(coord)
			if chunk == null or chunk.lod != 0:
				return false
	return not _desired.is_empty()


func loaded_count() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _pending.size() + _queue.size() + _cached_ready.size()


func cache_count() -> int:
	return _cache.size()


## Smoothed focus velocity (m/s, horizontal) used for prefetching.
func focus_velocity() -> Vector3:
	return _velocity


func get_debug_stats() -> Dictionary:
	var per_lod := [0, 0, 0, 0]
	for coord in _chunks:
		var l: int = _chunks[coord].lod
		if l >= 0 and l < per_lod.size():
			per_lod[l] += 1
	var out := {
		"loaded": _chunks.size(), "lod0": per_lod[0], "lod1": per_lod[1], "lod2": per_lod[2],
		"pending": _pending.size(), "queued": _queue.size(), "pooled": _pool.size(),
		"generated": _stats.generated, "discarded": _stats.discarded,
		"cache": _cache.size(), "cache_mb": _cache_bytes / 1048576.0, "cache_hits": _stats.cache_hits,
		"evicted": _stats.evicted, "prefetch_queued": _prefetch_queue.size(), "prefetched": _stats.prefetched,
		"threads": _threads, "apply_ms_avg": _stats.apply_ms / maxf(1.0, _stats.applied),
		"apply_ms_max": _stats.apply_ms_max,
		"far_tiles": 0, "far_pending": 0, "prewarms": _stats.prewarms,
	}
	if far:
		out.far_tiles = far.tile_count()
		out.far_pending = far.pending_count()
	return out


## Forces an immediate refresh (e.g. after teleporting the focus).
func force_refresh() -> void:
	_center = Vector2i(0x7FFFFFFF, 0)
	_last_pos = Vector3.INF


## Switches the streamed layer: every loaded chunk is unloaded and the new
## layer streams in around the focus. In-flight results for the old layer are
## discarded when they arrive (but still cached).
func set_layer(new_layer: int) -> void:
	if new_layer == layer:
		return
	layer = new_layer
	for coord: Vector2i in _chunks.keys():
		_unload(coord)
	_desired.clear()
	_queue.clear()
	_prefetch_queue.clear()
	_cached_ready.clear()
	force_refresh()


# --- Streaming -------------------------------------------------------------------

func lod_for_distance(dist: float) -> int:
	for i in lod_radii.size():
		if dist <= lod_radii[i] + 0.5:
			return i
	return -1


func _track_velocity(delta: float) -> void:
	var p := focus.global_position
	p.y = 0.0
	if _last_pos == Vector3.INF or delta <= 0.0:
		_last_pos = p
		return
	var d := p - _last_pos
	_last_pos = p
	if d.length() > TerrainGenerator.CHUNK_SIZE * 2.0:
		_velocity = Vector3.ZERO  # teleport, not travel
		return
	_velocity = _velocity.lerp(d / delta, 1.0 - exp(-3.0 * delta))


## Chunk the focus will be near in `prefetch_seconds` (its own chunk when still).
func predicted_center() -> Vector2i:
	if _velocity.length() < 2.0:
		return _center
	var r_max: int = lod_radii[lod_radii.size() - 1]
	var lead := (_velocity * prefetch_seconds).limit_length(float(r_max * TerrainGenerator.CHUNK_SIZE))
	return _center + Vector2i(roundi(lead.x / TerrainGenerator.CHUNK_SIZE), roundi(lead.z / TerrainGenerator.CHUNK_SIZE))


func _update_desired() -> void:
	_desired.clear()
	var r_max: int = lod_radii[lod_radii.size() - 1]
	for dz in range(-r_max, r_max + 1):
		for dx in range(-r_max, r_max + 1):
			var lod := lod_for_distance(Vector2(dx, dz).length())
			if lod >= 0:
				_desired[_center + Vector2i(dx, dz)] = lod

	# Unload chunks well outside the view.
	var unload_dist := r_max + unload_margin
	for coord: Vector2i in _chunks.keys():
		if not _desired.has(coord) and Vector2(coord - _center).length() > unload_dist:
			_unload(coord)

	# Rebuild the work queue. Closest first, nudged towards the direction of
	# travel so the area ahead appears before the area behind.
	_queue.clear()
	for coord: Vector2i in _desired:
		var chunk: Chunk = _chunks.get(coord)
		if chunk != null and chunk.lod == _desired[coord]:
			continue
		if _pending.has(coord) and _pending[coord].lod == _desired[coord] and not _pending[coord].prefetch:
			continue
		_queue.append(coord)
	var bias := Vector2(predicted_center() - _center).limit_length(2.0)
	var focus_pt := Vector2(_center) + bias
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(focus_pt) < Vector2(b).distance_squared_to(focus_pt))
	_update_prefetch()


## Queues data for the rings around the predicted centre that the current rings
## don't already cover at that detail.
func _update_prefetch() -> void:
	_prefetch_queue.clear()
	var pc := predicted_center()
	if pc == _center:
		return
	var r_max: int = lod_radii[lod_radii.size() - 1]
	var list := []
	for dz in range(-r_max, r_max + 1):
		for dx in range(-r_max, r_max + 1):
			var lod := lod_for_distance(Vector2(dx, dz).length())
			if lod < 0:
				continue
			var coord := pc + Vector2i(dx, dz)
			var now: int = _desired.get(coord, 99)
			if lod >= now or _cache.has(Vector4i(coord.x, coord.y, lod, layer)):
				continue
			list.append([coord, lod, Vector2(dx, dz).length_squared()])
	# Nearest to where the focus is heading first.
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	for i in mini(list.size(), max_prefetch):
		_prefetch_queue.append([list[i][0], list[i][1]])


func _dispatch() -> void:
	var i := 0
	while _pending.size() < _threads and i < _queue.size():
		var coord := _queue[i]
		if _pending.has(coord):
			i += 1  # still generating another LOD; retried when it completes
			continue
		_queue.remove_at(i)
		if not _desired.has(coord):
			continue
		var lod: int = _desired[coord]
		var chunk: Chunk = _chunks.get(coord)
		if chunk != null and chunk.lod == lod:
			continue
		var cached := _cache_get(coord, lod, layer)
		if cached:
			_stats.cache_hits += 1
			_cached_ready.append(cached)
			continue
		_start_task(coord, lod, false)
	# Prefetch only with spare workers: never slows down what is needed now.
	while _pending.size() < _threads - 1 and not _prefetch_queue.is_empty() and _queue.size() <= i:
		var item: Array = _prefetch_queue.pop_front()
		var coord: Vector2i = item[0]
		var lod: int = item[1]
		if _pending.has(coord) or _cache.has(Vector4i(coord.x, coord.y, lod, layer)):
			continue
		_start_task(coord, lod, true)
	if far:
		far.dispatch(maxi(1, _threads - _pending.size()))


func _start_task(coord: Vector2i, lod: int, prefetch: bool) -> void:
	var task := WorkerThreadPool.add_task(_generate_task.bind(coord, lod, layer), false, "chunk_gen")
	_pending[coord] = {"task": task, "lod": lod, "prefetch": prefetch}


## Runs on a worker thread.
func _generate_task(coord: Vector2i, lod: int, p_layer: int) -> void:
	var data := generator.generate_chunk(coord, lod, p_layer)
	_results_mutex.lock()
	_results.append(data)
	_results_mutex.unlock()


func _apply_results() -> void:
	var t0 := Time.get_ticks_usec()
	var budget_us := int(apply_budget_ms * 1000.0)
	var applied := 0
	# Finished worker results: always cached; built only if still wanted.
	while true:
		_results_mutex.lock()
		var data: ChunkData = null if _results.is_empty() else _results.pop_front()
		_results_mutex.unlock()
		if data == null:
			break
		if _pending.has(data.coord):
			var p: Dictionary = _pending[data.coord]
			WorkerThreadPool.wait_for_task_completion(p.task)
			_pending.erase(data.coord)
			if p.prefetch:
				_stats.prefetched += 1
		_stats.generated += 1
		_cache_put(data)
		var want: int = _desired.get(data.coord, -1) if data.layer == layer else -1
		if want != data.lod:
			_stats.discarded += 1
			var existing: Chunk = _chunks.get(data.coord)
			if want >= 0 and (existing == null or existing.lod != want) and not _queue.has(data.coord):
				_queue.push_front(data.coord)
			continue
		_cached_ready.push_front(data)
		if Time.get_ticks_usec() - t0 > budget_us:
			break
	# Build chunks within the frame budget (at least one per frame).
	while not _cached_ready.is_empty() and applied < max_applies_per_frame:
		if applied > 0 and Time.get_ticks_usec() - t0 > budget_us:
			break
		var data: ChunkData = _cached_ready.pop_front()
		if data.layer != layer or _desired.get(data.coord, -1) != data.lod:
			continue
		var existing: Chunk = _chunks.get(data.coord)
		if existing != null and existing.lod == data.lod:
			continue
		var tb := Time.get_ticks_usec()
		_build(data)
		var ms := (Time.get_ticks_usec() - tb) / 1000.0
		_stats.apply_ms += ms
		_stats.applied += 1
		_stats.apply_ms_max = maxf(_stats.apply_ms_max, ms)
		applied += 1
	if far:
		var left_ms := maxf(0.5, apply_budget_ms - (Time.get_ticks_usec() - t0) / 1000.0)
		far.apply_results(left_ms)


func _build(data: ChunkData) -> void:
	var chunk: Chunk = _chunks.get(data.coord)
	if chunk == null:
		chunk = _take_chunk()
		_chunks[data.coord] = chunk
	chunk.build(data)
	chunk_ready.emit(data.coord, data.lod, chunk)


## Background generation: lays out the towns and POIs around where the focus
## is heading whenever it has moved a third of the prewarm radius.
func _maybe_prewarm() -> void:
	if layer != TerrainGenerator.Layer.SURFACE or prewarm_radius_m <= 0:
		return
	if _prewarm_task >= 0:
		if not WorkerThreadPool.is_task_completed(_prewarm_task):
			return
		WorkerThreadPool.wait_for_task_completion(_prewarm_task)
		_prewarm_task = -1
	var at := predicted_center()
	if _prewarm_at.x != 0x7FFFFFFF and Vector2(at - _prewarm_at).length() * TerrainGenerator.CHUNK_SIZE < prewarm_radius_m / 3.0:
		return
	_prewarm_at = at
	_stats.prewarms += 1
	var col := at * TerrainGenerator.CHUNK_SIZE
	_prewarm_task = WorkerThreadPool.add_task(generator.prewarm.bind(col, prewarm_radius_m), false, "world_prewarm")


# --- Data cache ------------------------------------------------------------------

func _cache_get(coord: Vector2i, lod: int, p_layer: int) -> ChunkData:
	var key := Vector4i(coord.x, coord.y, lod, p_layer)
	var data: ChunkData = _cache.get(key)
	if data:
		_tick += 1
		_cache_used[key] = _tick
	return data


func _cache_put(data: ChunkData) -> void:
	var key := Vector4i(data.coord.x, data.coord.y, data.lod, data.layer)
	_tick += 1
	if not _cache.has(key):
		_cache_bytes += data.estimate_bytes()
	_cache[key] = data
	_cache_used[key] = _tick
	if _cache_bytes > cache_budget_mb * 1048576.0:
		_evict()


## Drops least-recently-used entries until the cache is at 85% of its budget.
## Data of loaded chunks is kept (it is cheap to keep and likely reused).
func _evict() -> void:
	var keys := _cache_used.keys()
	keys.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return _cache_used[a] < _cache_used[b])
	var target := cache_budget_mb * 1048576.0 * 0.85
	for key: Vector4i in keys:
		if _cache_bytes <= target:
			break
		var chunk: Chunk = _chunks.get(Vector2i(key.x, key.y))
		if chunk != null and chunk.lod == key.z and key.w == layer:
			continue
		_cache_bytes -= (_cache[key] as ChunkData).estimate_bytes()
		_cache.erase(key)
		_cache_used.erase(key)
		_stats.evicted += 1


## Empties the data cache (tests, or after something changes generation).
func clear_cache() -> void:
	_cache.clear()
	_cache_used.clear()
	_cache_bytes = 0


# --- Node pool -------------------------------------------------------------------

func _take_chunk() -> Chunk:
	var chunk: Chunk
	if _pool.is_empty():
		chunk = Chunk.new()
		chunk.library = library
		add_child(chunk)
	else:
		chunk = _pool.pop_back()
	return chunk


func _unload(coord: Vector2i) -> void:
	var chunk: Chunk = _chunks.get(coord)
	if chunk == null:
		return
	_chunks.erase(coord)
	chunk.release()
	_pool.append(chunk)
	chunk_removed.emit(coord)
