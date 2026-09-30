class_name ChunkManager
extends Node3D
## Streams chunks around a focus node (the player).
##
## - Desired chunks form rings around the focus with decreasing detail:
##   LOD0 (full detail + collision + props) -> LOD1 -> LOD2 (coarse, no props).
## - ChunkData is generated on WorkerThreadPool threads (pure data), then turned
##   into nodes on the main thread with a per-frame budget to avoid hitches.
## - Chunks outside the outer radius are unloaded back into a node pool.
## - Only world *modifications* are persisted (GameState), so unloaded chunks
##   can be regenerated identically at any time.

signal chunk_ready(coord: Vector2i, lod: int, chunk: Chunk)
signal chunk_removed(coord: Vector2i)

## Chunk radius for each LOD level, ascending.
@export var lod_radii: PackedInt32Array = PackedInt32Array([3, 6, 9])
@export var max_concurrent_tasks: int = 4
@export var max_applies_per_frame: int = 3
## Extra radius before a chunk is unloaded (prevents thrashing at the edge).
@export var unload_margin: float = 1.5

var generator: TerrainGenerator
var library: PropLibrary
var focus: Node3D

var _chunks: Dictionary = {}  # Vector2i -> Chunk
var _desired: Dictionary = {}  # Vector2i -> lod
var _pending: Dictionary = {}  # Vector2i -> {"task": int, "lod": int}
var _queue: Array[Vector2i] = []
var _results: Array[ChunkData] = []
var _results_mutex := Mutex.new()
var _center := Vector2i(0x7FFFFFFF, 0)
var _pool: Array[Chunk] = []
var _stats := {"generated": 0, "discarded": 0}


func setup(p_generator: TerrainGenerator, p_library: PropLibrary) -> void:
	generator = p_generator
	library = p_library


func _process(_delta: float) -> void:
	if generator == null or focus == null:
		return
	var c := TerrainGenerator.world_to_chunk(focus.global_position)
	if c != _center:
		_center = c
		_update_desired()
	_dispatch()
	_apply_results()


func _exit_tree() -> void:
	# Never leave worker tasks running against freed data.
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
	return _pending.size() + _queue.size()


func get_debug_stats() -> Dictionary:
	var per_lod := [0, 0, 0, 0]
	for coord in _chunks:
		var l: int = _chunks[coord].lod
		if l >= 0 and l < per_lod.size():
			per_lod[l] += 1
	return {
		"loaded": _chunks.size(), "lod0": per_lod[0], "lod1": per_lod[1], "lod2": per_lod[2],
		"pending": _pending.size(), "queued": _queue.size(), "pooled": _pool.size(),
		"generated": _stats.generated, "discarded": _stats.discarded,
	}


## Forces an immediate refresh (e.g. after teleporting the focus).
func force_refresh() -> void:
	_center = Vector2i(0x7FFFFFFF, 0)


# --- Streaming -------------------------------------------------------------------

func lod_for_distance(dist: float) -> int:
	for i in lod_radii.size():
		if dist <= lod_radii[i] + 0.5:
			return i
	return -1


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

	# Rebuild the work queue sorted by distance (closest first).
	_queue.clear()
	for coord: Vector2i in _desired:
		var chunk: Chunk = _chunks.get(coord)
		if chunk != null and chunk.lod == _desired[coord]:
			continue
		if _pending.has(coord) and _pending[coord].lod == _desired[coord]:
			continue
		_queue.append(coord)
	var center := _center
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared())


func _dispatch() -> void:
	var i := 0
	while _pending.size() < max_concurrent_tasks and i < _queue.size():
		var coord := _queue[i]
		if _pending.has(coord):
			i += 1  # still generating an older LOD; retried when it completes
			continue
		_queue.remove_at(i)
		if not _desired.has(coord):
			continue
		var lod: int = _desired[coord]
		var chunk: Chunk = _chunks.get(coord)
		if chunk != null and chunk.lod == lod:
			continue
		var task := WorkerThreadPool.add_task(_generate_task.bind(coord, lod), false, "chunk_gen")
		_pending[coord] = {"task": task, "lod": lod}


## Runs on a worker thread.
func _generate_task(coord: Vector2i, lod: int) -> void:
	var data := generator.generate_chunk(coord, lod)
	_results_mutex.lock()
	_results.append(data)
	_results_mutex.unlock()


func _apply_results() -> void:
	var batch: Array[ChunkData] = []
	_results_mutex.lock()
	while not _results.is_empty() and batch.size() < max_applies_per_frame:
		batch.append(_results.pop_front())
	_results_mutex.unlock()

	for data in batch:
		if _pending.has(data.coord):
			WorkerThreadPool.wait_for_task_completion(_pending[data.coord].task)
			_pending.erase(data.coord)
		_stats.generated += 1
		var want: int = _desired.get(data.coord, -1)
		if want != data.lod:
			_stats.discarded += 1
			var existing: Chunk = _chunks.get(data.coord)
			if want >= 0 and (existing == null or existing.lod != want) and not _queue.has(data.coord):
				_queue.push_front(data.coord)
			continue
		var chunk: Chunk = _chunks.get(data.coord)
		if chunk == null:
			chunk = _take_chunk()
			_chunks[data.coord] = chunk
		chunk.build(data)
		chunk_ready.emit(data.coord, data.lod, chunk)


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
