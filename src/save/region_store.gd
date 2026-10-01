class_name RegionStore
extends RefCounted
## Region files for per-chunk world changes (Milestone 9).
##
## Felled trees, mined ores and killed spawn slots used to live in one big
## dictionary inside save.json, which grows with everything the player ever
## touches. Now they are split into regions of REGION_CHUNKS x REGION_CHUNKS
## chunks, each stored as its own ZSTD-compressed file:
##
##   user://worlds/<id>/regions/r.<rx>.<rz>.<layer>.dat
##
## - Regions load lazily the first time a chunk inside them is queried.
## - Changes mark a region dirty; flush() (on every save) writes dirty regions
##   atomically (.tmp then rename) and deletes files of regions that became empty.
## - Clean regions beyond `max_loaded` are dropped from memory, least recently
##   used first, so memory stays bounded however far the player travels.
## - Without a directory (transient worlds, tests) everything stays in memory.
##
## Spawn-slot keys that are not chunk based (POI guardians, "poi:...") go to a
## shared MISC region.

const REGION_CHUNKS := 32
const FORMAT := 1
const MISC := Vector3i(0x7FFFFFF, 0x7FFFFFF, 0)

## Folder of the region files ("" = memory only).
var directory := ""
## Clean regions kept in memory.
var max_loaded := 64

var _regions: Dictionary = {}  # Vector3i -> {"props": {Vector2i: {idx: t}}, "deaths": {key: t}, "dirty": bool, "used": int}
var _tick := 0
var _file_count := -1  # cached; recounted after a flush
var stats := {"loaded": 0, "written": 0, "deleted": 0, "evicted": 0, "corrupt": 0}


static func region_of(chunk: Vector2i, layer: int) -> Vector3i:
	return Vector3i(floori(float(chunk.x) / REGION_CHUNKS), floori(float(chunk.y) / REGION_CHUNKS), layer)


## Region of a spawn-slot key ("cx,cz:biome:rule" for chunk slots).
static func region_of_slot(slot_key: String) -> Vector3i:
	var head := slot_key.get_slice(":", 0)
	var parts := head.split(",")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return region_of(Vector2i(parts[0].to_int(), parts[1].to_int()), 0)
	return MISC


func file_path(key: Vector3i) -> String:
	if key == MISC:
		return "%s/misc.dat" % directory
	return "%s/r.%d.%d.%d.dat" % [directory, key.x, key.y, key.z]


func loaded_count() -> int:
	return _regions.size()


func dirty_count() -> int:
	var n := 0
	for k in _regions:
		if _regions[k].dirty:
			n += 1
	return n


## Forgets everything in memory (the files stay).
func clear_memory() -> void:
	_regions.clear()
	_file_count = -1


# --- Props ---------------------------------------------------------------------------

func mark_prop(chunk: Vector2i, layer: int, index: int, time: float) -> void:
	var r := _region(region_of(chunk, layer), true)
	if not r.props.has(chunk):
		r.props[chunk] = {}
	r.props[chunk][index] = time
	r.dirty = true


## World time the prop was removed, or -1.0 if it is there.
func prop_time(chunk: Vector2i, layer: int, index: int) -> float:
	var r := _region(region_of(chunk, layer))
	var c: Dictionary = r.props.get(chunk, {})
	return float(c.get(index, -1.0))


func erase_prop(chunk: Vector2i, layer: int, index: int) -> void:
	var r := _region(region_of(chunk, layer))
	var c: Dictionary = r.props.get(chunk, {})
	if c.erase(index):
		if c.is_empty():
			r.props.erase(chunk)
		r.dirty = true


## All removed props of a chunk: index -> time (a copy).
func props_of(chunk: Vector2i, layer: int) -> Dictionary:
	return (_region(region_of(chunk, layer)).props.get(chunk, {}) as Dictionary).duplicate()


# --- Spawn slots ---------------------------------------------------------------------

func mark_death(slot_key: String, time: float) -> void:
	var r := _region(region_of_slot(slot_key), true)
	r.deaths[slot_key] = time
	r.dirty = true


func death_time(slot_key: String) -> float:
	return float(_region(region_of_slot(slot_key)).deaths.get(slot_key, -1.0))


func erase_death(slot_key: String) -> void:
	var r := _region(region_of_slot(slot_key))
	if r.deaths.erase(slot_key):
		r.dirty = true


# --- Disk ------------------------------------------------------------------------------

## The region record, loading it on first use. Reads (`write` false) of a
## memory-only store don't create records for untouched regions.
func _region(key: Vector3i, write: bool = false) -> Dictionary:
	_tick += 1
	var r: Dictionary = _regions.get(key, {})
	if r.is_empty():
		if not write and directory == "":
			return {"props": {}, "deaths": {}, "dirty": false, "used": _tick}
		# Make room before inserting, so the region being touched is never evicted.
		if _regions.size() >= max_loaded + 16:
			evict()
		r = _load(key)
		_regions[key] = r
	r.used = _tick
	return r


func _load(key: Vector3i) -> Dictionary:
	var r := {"props": {}, "deaths": {}, "dirty": false, "used": _tick}
	if directory == "":
		return r
	var path := file_path(key)
	if not FileAccess.file_exists(path):
		return r
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var data = f.get_var() if f else null
	if not data is Dictionary or int((data as Dictionary).get("format", 0)) < 1:
		push_warning("RegionStore: unreadable region %s (ignored)" % path)
		stats.corrupt += 1
		return r
	stats.loaded += 1
	var props: Dictionary = data.get("props", {})
	for c in props:
		if c is Vector2i and props[c] is Dictionary:
			r.props[c] = props[c]
	var deaths: Dictionary = data.get("deaths", {})
	for k in deaths:
		r.deaths[String(k)] = float(deaths[k])
	return r


## Writes every dirty region. Returns false if any write failed.
func flush() -> bool:
	if directory == "":
		return true
	DirAccess.make_dir_recursive_absolute(directory)
	var ok := true
	for key: Vector3i in _regions:
		var r: Dictionary = _regions[key]
		if not r.dirty:
			continue
		if _write(key, r):
			r.dirty = false
		else:
			ok = false
	_file_count = -1
	evict()
	return ok


func _write(key: Vector3i, r: Dictionary) -> bool:
	var path := file_path(key)
	if r.props.is_empty() and r.deaths.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
			stats.deleted += 1
		return true
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("RegionStore: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_var({"format": FORMAT, "region": key, "props": r.props, "deaths": r.deaths})
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	stats.written += 1
	return DirAccess.rename_absolute(tmp, path) == OK


## Drops clean regions beyond max_loaded, least recently used first.
## Memory-only stores never drop anything (it would be lost).
func evict() -> void:
	if directory == "" or _regions.size() <= max_loaded:
		return
	var clean := []
	for key in _regions:
		if not _regions[key].dirty:
			clean.append(key)
	clean.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return _regions[a].used < _regions[b].used)
	var n := _regions.size() - max_loaded
	for i in mini(n, clean.size()):
		_regions.erase(clean[i])
		stats.evicted += 1


## Number of region files on disk.
func file_count() -> int:
	if directory == "":
		return 0
	if _file_count >= 0:
		return _file_count
	var dir := DirAccess.open(directory)
	if dir == null:
		return 0
	var n := 0
	for f in dir.get_files():
		if f.ends_with(".dat"):
			n += 1
	_file_count = n
	return n


# --- Inline form (transient worlds, legacy saves) ----------------------------------------

## Everything in memory as the old JSON-friendly dictionaries.
func to_inline() -> Dictionary:
	var props := {}
	var deaths := {}
	for key: Vector3i in _regions:
		var r: Dictionary = _regions[key]
		for c: Vector2i in r.props:
			var entries := {}
			for idx in r.props[c]:
				entries[str(idx)] = r.props[c][idx]
			props["%d,%d,%d" % [c.x, c.y, key.z]] = entries
		for k in r.deaths:
			deaths[k] = r.deaths[k]
	return {"removed_props": props, "enemy_deaths": deaths}


## Imports the old save.json dictionaries (saves from before Milestone 9).
func import_inline(props: Dictionary, deaths: Dictionary) -> int:
	var n := 0
	for key in props:
		var parts := String(key).split(",")
		if parts.size() < 2:
			continue
		var chunk := Vector2i(parts[0].to_int(), parts[1].to_int())
		var layer := parts[2].to_int() if parts.size() > 2 else 0
		var raw: Dictionary = props[key]
		for idx in raw:
			mark_prop(chunk, layer, int(idx), float(raw[idx]))
			n += 1
	for k in deaths:
		mark_death(String(k), float(deaths[k]))
		n += 1
	return n


# --- Multiplayer (Milestone 11) ----------------------------------------------------------

## One region's data for sending to a guest: {"props": {chunk: {index: t}}, "deaths": {key: t}}.
func export_region(key: Vector3i) -> Dictionary:
	var r := _region(key)
	return {"props": (r.props as Dictionary).duplicate(true), "deaths": (r.deaths as Dictionary).duplicate()}


## Replaces one region with the server's copy (guests).
func import_region(key: Vector3i, props: Dictionary, deaths: Dictionary) -> void:
	var r := _region(key, true)
	r.props.clear()
	for c in props:
		if c is Vector2i and props[c] is Dictionary:
			var entries := {}
			for idx in props[c]:
				entries[int(idx)] = float(props[c][idx])
			r.props[c] = entries
	r.deaths.clear()
	for k in deaths:
		r.deaths[String(k)] = float(deaths[k])
