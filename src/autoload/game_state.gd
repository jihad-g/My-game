extends Node
## Session-wide game state: world seed, world clock and persistent world changes.
##
## Only *modifications* to the procedural world are stored (removed props, killed
## spawn slots). Everything else is regenerated deterministically from the seed.
## Per-chunk changes live in a RegionStore (region files next to save.json,
## Milestone 9); the rest is plain dictionaries serialized by to_dict / from_dict.

const DEFAULT_SEED := 20250101

var world_seed: int = DEFAULT_SEED
## Total simulated game time in seconds since the world was created.
var world_time: float = 0.0
## Removed props and killed spawn slots, by region (see RegionStore).
var regions := RegionStore.new()
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

func mark_prop_removed(chunk: Vector2i, prop_index: int, layer: int = 0) -> void:
	regions.mark_prop(chunk, layer, prop_index, world_time)


## True if the prop is currently removed. Props with a regrow time come back
## once enough world time has passed (their record is then deleted).
func is_prop_removed(chunk: Vector2i, prop_index: int, regrow_time: float, layer: int = 0) -> bool:
	var t := regions.prop_time(chunk, layer, prop_index)
	if t < 0.0:
		return false
	if regrow_time > 0.0 and world_time - t >= regrow_time:
		regions.erase_prop(chunk, layer, prop_index)
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
		regions.mark_death(slot_key, world_time)


func can_spawn_slot(slot_key: String, respawn_time: float) -> bool:
	var t := regions.death_time(slot_key)
	if t < 0.0:
		return true
	if world_time - t >= respawn_time:
		regions.erase_death(slot_key)
		return true
	return false


# --- Serialization (SaveManager) -------------------------------------------

## Region files hold the per-chunk changes of saved worlds; transient worlds
## (no region directory) keep them inline as before.
func to_dict() -> Dictionary:
	var d := {
		# Seeds are 64-bit; JSON numbers are doubles, so store as text.
		"world_seed": str(world_seed),
		"world_time": world_time,
		"discovered_biomes": discovered_biomes.duplicate(),
		"discovered_places": discovered_places.duplicate(),
	}
	if regions.directory == "":
		d.merge(regions.to_inline())
	else:
		d["regions"] = {"format": RegionStore.FORMAT, "region_chunks": RegionStore.REGION_CHUNKS}
	return d


## Loads the dictionary part. Inline changes (transient worlds, or saves made
## before Milestone 9) are imported into the region store.
func from_dict(data: Dictionary) -> void:
	world_seed = parse_seed(data.get("world_seed", DEFAULT_SEED))
	world_time = float(data.get("world_time", 0.0))
	regions.clear_memory()
	regions.import_inline(data.get("removed_props", {}), data.get("enemy_deaths", {}))
	discovered_biomes = (data.get("discovered_biomes", {}) as Dictionary).duplicate()
	discovered_places = (data.get("discovered_places", {}) as Dictionary).duplicate()


## Points the region store at a world folder ("" = memory only).
func set_region_directory(path: String) -> void:
	regions.directory = path
	regions.clear_memory()


func reset(new_seed: int) -> void:
	world_seed = new_seed
	world_time = 0.0
	regions = RegionStore.new()
	discovered_biomes.clear()
	discovered_places.clear()
