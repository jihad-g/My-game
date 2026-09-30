extends Node
## Session-wide game state: world seed, world clock and persistent world changes.
##
## Only *modifications* to the procedural world are stored (removed props, killed
## spawn slots). Everything else is regenerated deterministically from the seed.
## All containers are plain dictionaries so a future save system can serialize
## them directly (see to_dict / from_dict).

const DEFAULT_SEED := 20250101

var world_seed: int = DEFAULT_SEED
## Total simulated game time in seconds since the world was created.
var world_time: float = 0.0
## Vector3i(chunk.x, chunk.y, layer) -> { prop_index:int -> world_time when removed }
var removed_props: Dictionary = {}
## Spawn slot key (String) -> world_time when the occupant was killed.
var enemy_deaths: Dictionary = {}
## Biome id (String) -> world_time of first discovery.
var discovered_biomes: Dictionary = {}
## Place key (String, e.g. "cave:x,z") -> world_time of first discovery.
var discovered_places: Dictionary = {}


func _ready() -> void:
	_parse_command_line()


func _process(delta: float) -> void:
	if not get_tree().paused:
		world_time += delta


func _parse_command_line() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			world_seed = seed_from_string(arg.substr(7))


## Converts user text into a seed. Numeric strings map to themselves so seeds
## can be shared as plain numbers; other text is hashed.
static func seed_from_string(text: String) -> int:
	text = text.strip_edges()
	if text.is_valid_int():
		return text.to_int()
	return text.hash()


static func parse_seed(v: Variant) -> int:
	if v is String:
		return (v as String).to_int()
	return int(v)


# --- Props -----------------------------------------------------------------

static func _prop_key(chunk: Vector2i, layer: int) -> Vector3i:
	return Vector3i(chunk.x, chunk.y, layer)


func mark_prop_removed(chunk: Vector2i, prop_index: int, layer: int = 0) -> void:
	var key := _prop_key(chunk, layer)
	if not removed_props.has(key):
		removed_props[key] = {}
	removed_props[key][prop_index] = world_time


## True if the prop is currently removed. Props with a regrow time come back
## once enough world time has passed (their record is then deleted).
func is_prop_removed(chunk: Vector2i, prop_index: int, regrow_time: float, layer: int = 0) -> bool:
	var key := _prop_key(chunk, layer)
	var chunk_dict: Dictionary = removed_props.get(key, {})
	if not chunk_dict.has(prop_index):
		return false
	if regrow_time > 0.0 and world_time - float(chunk_dict[prop_index]) >= regrow_time:
		chunk_dict.erase(prop_index)
		if chunk_dict.is_empty():
			removed_props.erase(key)
		return false
	return true


## Records a place discovery (caves, later landmarks). Returns true the first time.
func discover_place(key: String) -> bool:
	if discovered_places.has(key):
		return false
	discovered_places[key] = world_time
	return true


## Records a biome discovery. Returns true the first time.
func discover_biome(id: StringName) -> bool:
	if discovered_biomes.has(String(id)):
		return false
	discovered_biomes[String(id)] = world_time
	return true


# --- Enemy spawn slots -----------------------------------------------------

func mark_enemy_killed(slot_key: String) -> void:
	if slot_key != "":
		enemy_deaths[slot_key] = world_time


func can_spawn_slot(slot_key: String, respawn_time: float) -> bool:
	if not enemy_deaths.has(slot_key):
		return true
	if world_time - float(enemy_deaths[slot_key]) >= respawn_time:
		enemy_deaths.erase(slot_key)
		return true
	return false


# --- Serialization (used by the future save system) ------------------------

func to_dict() -> Dictionary:
	var props := {}
	for key: Vector3i in removed_props:
		props["%d,%d,%d" % [key.x, key.y, key.z]] = removed_props[key].duplicate()
	return {
		# Seeds are 64-bit; JSON numbers are doubles, so store as text.
		"world_seed": str(world_seed),
		"world_time": world_time,
		"removed_props": props,
		"enemy_deaths": enemy_deaths.duplicate(),
		"discovered_biomes": discovered_biomes.duplicate(),
		"discovered_places": discovered_places.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	world_seed = parse_seed(data.get("world_seed", DEFAULT_SEED))
	world_time = float(data.get("world_time", 0.0))
	removed_props.clear()
	var props: Dictionary = data.get("removed_props", {})
	for key: String in props:
		var parts := key.split(",")
		var layer := parts[2].to_int() if parts.size() > 2 else 0
		var entries := {}
		var raw: Dictionary = props[key]
		for idx in raw:
			entries[int(idx)] = float(raw[idx])
		removed_props[Vector3i(parts[0].to_int(), parts[1].to_int(), layer)] = entries
	enemy_deaths.clear()
	var deaths: Dictionary = data.get("enemy_deaths", {})
	for k in deaths:
		enemy_deaths[String(k)] = float(deaths[k])
	discovered_biomes = (data.get("discovered_biomes", {}) as Dictionary).duplicate()
	discovered_places = (data.get("discovered_places", {}) as Dictionary).duplicate()


func reset(new_seed: int) -> void:
	world_seed = new_seed
	world_time = 0.0
	removed_props.clear()
	enemy_deaths.clear()
	discovered_biomes.clear()
	discovered_places.clear()
