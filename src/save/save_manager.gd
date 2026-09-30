extends Node
## Creates, lists, saves, loads and deletes worlds.
##
## Layout on disk (user:// = the OS app-data folder, see README):
##   user://worlds/<world_id>/world.json   metadata: name, seed, versions, times
##   user://worlds/<world_id>/save.json    game state: world changes, player, placed objects
##
## Only *changes* to the procedural world are saved (felled trees, mined ores,
## killed spawn slots, placed objects...). Terrain is regenerated from the seed,
## so saves stay small no matter how far the player explores.
##
## Writes are crash-safe: data goes to a .tmp file first, the previous save is
## kept as .bak, and loading falls back to the .bak if the main file is broken.

signal world_saved(world_id: String)

const SAVE_VERSION := 1
const META_FILE := "world.json"
const SAVE_FILE := "save.json"

## Root folder of all worlds (tests point this at a temporary folder).
var worlds_dir := "user://worlds"
## Id of the world being played ("" = transient world that is never saved).
var current_world_id := ""
var current_meta: Dictionary = {}
## Save data waiting to be applied by World._ready() (empty for new worlds).
var pending: Dictionary = {}
var _session_start_msec := 0


func is_persistent() -> bool:
	return current_world_id != ""


# --- World list -------------------------------------------------------------------

## All worlds, most recently played first. Each entry is its world.json dict.
func list_worlds() -> Array:
	var out := []
	var dir := DirAccess.open(worlds_dir)
	if dir == null:
		return out
	for id in dir.get_directories():
		var meta = _read_json("%s/%s/%s" % [worlds_dir, id, META_FILE])
		if meta is Dictionary:
			meta["id"] = id
			out.append(meta)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("last_played", 0)) > float(b.get("last_played", 0)))
	return out


func world_exists(id: String) -> bool:
	return FileAccess.file_exists("%s/%s/%s" % [worlds_dir, id, META_FILE])


## Creates a new world folder and makes it the current world. Returns its id.
func create_world(world_name: String, seed_value: int) -> String:
	world_name = world_name.strip_edges()
	if world_name == "":
		world_name = "New World"
	var id := _unique_id(world_name)
	DirAccess.make_dir_recursive_absolute("%s/%s" % [worlds_dir, id])
	var now := Time.get_unix_time_from_system()
	current_meta = {
		"id": id,
		"name": world_name,
		"seed": str(seed_value),
		"save_version": SAVE_VERSION,
		"generator_version": 2,
		"game_version": ProjectSettings.get_setting("application/config/version", "0"),
		"created": now,
		"last_played": now,
		"play_time": 0.0,
	}
	_write_json(_meta_path(id), current_meta)
	current_world_id = id
	pending = {}
	GameState.reset(seed_value)
	_session_start_msec = Time.get_ticks_msec()
	return id


## Loads a world's metadata and save into GameState / `pending`.
func load_world(id: String) -> bool:
	var meta = _read_json(_meta_path(id))
	if not meta is Dictionary:
		push_error("SaveManager: world '%s' has no readable metadata" % id)
		return false
	current_meta = meta
	current_meta["id"] = id
	current_world_id = id
	GameState.reset(GameState.parse_seed(meta.get("seed", GameState.DEFAULT_SEED)))
	pending = {}
	var save = _read_json_with_backup(_save_path(id))
	if save is Dictionary:
		save = _migrate(save)
		GameState.from_dict(save.get("game_state", {}))
		GameState.world_seed = GameState.parse_seed(meta.get("seed", GameState.world_seed))
		pending = save
	_session_start_msec = Time.get_ticks_msec()
	return true


## Plays a world that is never written to disk (quick play, tests, --seed=).
func start_transient(seed_value: int) -> void:
	current_world_id = ""
	current_meta = {}
	pending = {}
	GameState.reset(seed_value)


## Writes the current world. Returns false for transient worlds or on errors.
func save_world(world: World) -> bool:
	if not is_persistent() or world == null:
		return false
	var data := {
		"save_version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
		"player": world.player.to_save(),
		"world": world.to_save(),
	}
	if not _write_json(_save_path(current_world_id), data, true):
		return false
	var now_msec := Time.get_ticks_msec()
	current_meta["play_time"] = float(current_meta.get("play_time", 0.0)) + (now_msec - _session_start_msec) / 1000.0
	_session_start_msec = now_msec
	current_meta["last_played"] = Time.get_unix_time_from_system()
	_write_json(_meta_path(current_world_id), current_meta)
	world_saved.emit(current_world_id)
	return true


func delete_world(id: String) -> bool:
	var path := "%s/%s" % [worlds_dir, id]
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	for f in dir.get_files():
		dir.remove(f)
	if id == current_world_id:
		current_world_id = ""
	return DirAccess.remove_absolute(path) == OK


# --- Helpers ----------------------------------------------------------------------------

func _meta_path(id: String) -> String:
	return "%s/%s/%s" % [worlds_dir, id, META_FILE]


func _save_path(id: String) -> String:
	return "%s/%s/%s" % [worlds_dir, id, SAVE_FILE]


func _unique_id(world_name: String) -> String:
	var base := ""
	for ch in world_name.to_lower():
		base += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	base = base.strip_edges().substr(0, 24)
	if base.replace("_", "") == "":
		base = "world"
	var id := base
	var n := 2
	while DirAccess.dir_exists_absolute("%s/%s" % [worlds_dir, id]):
		id = "%s_%d" % [base, n]
		n += 1
	return id


## Upgrades older save dictionaries to the current format.
func _migrate(save: Dictionary) -> Dictionary:
	var v := int(save.get("save_version", 1))
	# v1 is the first format; future versions add steps here.
	if v > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer game version (%d)" % v)
	return save


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveManager: corrupt JSON in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data


func _read_json_with_backup(path: String) -> Variant:
	var data = _read_json(path)
	if data == null:
		data = _read_json(path + ".bak")
	return data


func _write_json(path: String, data: Variant, keep_backup: bool = false) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		if keep_backup:
			if FileAccess.file_exists(path + ".bak"):
				DirAccess.remove_absolute(path + ".bak")
			DirAccess.rename_absolute(path, path + ".bak")
		else:
			DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK
