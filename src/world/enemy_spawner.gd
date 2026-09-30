class_name EnemySpawner
extends Node
## Spawns pooled enemies into LOD0 chunks using the deterministic spawn slots
## produced by TerrainGenerator, and despawns them when chunks unload.
##
## Kills are remembered per slot (GameState.enemy_deaths) so a cleared area
## stays cleared until the enemy type's respawn time has passed.

@export var chunk_manager: ChunkManager
## Never spawn enemies this close to the player (avoids popping in on top of them).
@export var min_spawn_distance: float = 14.0
@export var max_active: int = 24
## Seconds between retries for slots that were too close to the player.
@export var retry_interval: float = 3.0

var generator: TerrainGenerator
var _pools: Dictionary = {}  # PackedScene -> NodePool
var _by_chunk: Dictionary = {}  # Vector2i -> Array[Enemy]
var _waiting: Dictionary = {}  # Vector2i -> Array of spawn dicts not yet spawned
var _retry_left := 0.0


func _ready() -> void:
	chunk_manager.chunk_ready.connect(_on_chunk_ready)
	chunk_manager.chunk_removed.connect(_on_chunk_removed)


func _process(delta: float) -> void:
	_retry_left -= delta
	if _retry_left > 0.0 or _waiting.is_empty():
		return
	_retry_left = retry_interval
	for coord: Vector2i in _waiting.keys():
		var chunk := chunk_manager.get_chunk(coord)
		if chunk == null or chunk.lod != 0:
			_waiting.erase(coord)
			continue
		var remaining: Array = []
		for s: Dictionary in _waiting[coord]:
			if not _try_spawn(coord, s):
				remaining.append(s)
		if remaining.is_empty():
			_waiting.erase(coord)
		else:
			_waiting[coord] = remaining


## Despawns everything (used when the player changes layer).
func despawn_all() -> void:
	for coord: Vector2i in _by_chunk.keys():
		_despawn_chunk(coord)
	_waiting.clear()


func active_count() -> int:
	var n := 0
	for coord in _by_chunk:
		n += _by_chunk[coord].size()
	return n


func _on_chunk_ready(coord: Vector2i, lod: int, chunk: Chunk) -> void:
	if lod != 0 or chunk.layer != TerrainGenerator.Layer.SURFACE:
		_despawn_chunk(coord)
		return
	if _by_chunk.has(coord) or _waiting.has(coord):
		return
	var data_spawns := _spawns_for(coord)
	var waiting: Array = []
	for s: Dictionary in data_spawns:
		if not _try_spawn(coord, s):
			waiting.append(s)
	if not waiting.is_empty():
		_waiting[coord] = waiting


func _on_chunk_removed(coord: Vector2i) -> void:
	_despawn_chunk(coord)


## Spawn slots are a pure function of seed + coord (see TerrainGenerator).
func _spawns_for(coord: Vector2i) -> Array:
	return generator.get_spawn_slots(coord)


func _try_spawn(coord: Vector2i, s: Dictionary) -> bool:
	var rule: EnemySpawnRule = s.rule
	var respawn := rule.enemy_data.respawn_time if rule.enemy_data else 300.0
	if not GameState.can_spawn_slot(s.key, respawn):
		return true  # dead: nothing to do, don't retry until chunk reloads
	if active_count() >= max_active:
		return false
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and player.global_position.distance_to(s.position) < min_spawn_distance:
		return false
	var enemy := spawn_enemy(rule.enemy_scene, s.position, s.key, rule.enemy_data)
	if enemy == null:
		return false
	if not _by_chunk.has(coord):
		_by_chunk[coord] = []
	_by_chunk[coord].append(enemy)
	enemy.enemy_died.connect(_on_enemy_died.bind(coord), CONNECT_ONE_SHOT)
	return true


## Spawns an enemy from a pool. Also used by debug tools (empty key = untracked).
## `data_override` lets one scene serve several enemy variants (EnemySpawnRule.enemy_data).
func spawn_enemy(scene: PackedScene, pos: Vector3, key: String, data_override: EnemyData = null) -> Enemy:
	if scene == null:
		return null
	if not _pools.has(scene):
		var pool := NodePool.new()
		pool.name = "Pool_%s" % scene.resource_path.get_file().get_basename()
		pool.scene = scene
		add_child(pool)
		_pools[scene] = pool
	var enemy := (_pools[scene] as NodePool).acquire() as Enemy
	if enemy:
		if data_override:
			enemy.data = data_override
		enemy.spawn_at(pos, key)
	return enemy


func _on_enemy_died(enemy: Enemy, coord: Vector2i) -> void:
	if _by_chunk.has(coord):
		_by_chunk[coord].erase(enemy)


func _despawn_chunk(coord: Vector2i) -> void:
	_waiting.erase(coord)
	if not _by_chunk.has(coord):
		return
	for enemy: Enemy in _by_chunk[coord]:
		if is_instance_valid(enemy):
			for c in enemy.enemy_died.get_connections():
				var cb: Callable = c.callable
				if cb.get_object() == self:
					enemy.enemy_died.disconnect(cb)
			if not enemy.is_dead:
				NodePool.release_or_free(enemy)
	_by_chunk.erase(coord)
