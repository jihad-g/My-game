extends Node
## Creates, lists, saves, loads and deletes worlds.
##
## Layout on disk (user:// = the OS app-data folder, see README):
##   user://worlds/<world_id>/world.json   metadata: name, seed, versions, times
##   user://worlds/<world_id>/save.json    game state: player, placed objects, discoveries
##   user://worlds/<world_id>/regions/      per-chunk world changes (felled trees, mined
##                                          ores, killed spawn slots) in compressed
##                                          32x32-chunk region files (RegionStore)
##
## Only *changes* to the procedural world are saved (felled trees, mined ores,
## killed spawn slots, placed objects...). Terrain is regenerated from the seed,
## so saves stay small no matter how far the player explores.
##
## Writes are crash-safe: data goes to a .tmp file first, the previous save is
## kept as .bak, and loading falls back to the .bak if the main file is broken.
##
## Save recovery (Milestone 13):
## - every file starts with a SHA-256 header line, so damaged or truncated
##   saves are detected (old files without a header still load);
## - snapshots: user://worlds/<id>/backups/<stamp>/ hold save.json, world.json
##   and the region files - one when a world is loaded, then at most every
##   SNAPSHOT_INTERVAL of play, plus "crash" snapshots from the crash handler.
##   The newest MAX_SNAPSHOTS are kept;
## - loading tries save.json, then save.json.bak, then the snapshots newest
##   first (restoring that snapshot's region files too). `last_load` says what
##   happened so the game can tell the player;
## - list_backups(), restore_backup() and verify_world() back the menu's
##   Recover screen.

signal world_saved(world_id: String)

const BACKUPS_DIR := "backups"
const MAX_SNAPSHOTS := 6
## Seconds of play between automatic snapshots.
const SNAPSHOT_INTERVAL := 600.0
const HEADER := "#shardlands-save sha256="

## How the last load_world() went: {source: "save"|"bak"|"backup"|"none",
## backup: name, problems: PackedStringArray}.
var last_load: Dictionary = {}
var _last_snapshot_msec := -1

## 2 = per-chunk changes moved from save.json into region files (Milestone 9).
const SAVE_VERSION := 2
const REGIONS_DIR := "regions"
const META_FILE := "world.json"
const SAVE_FILE := "save.json"

## Root folder of all worlds (tests point this at a temporary folder).
var worlds_dir := "user://worlds"
## Id of the world being played ("" = transient world that is never saved).
var current_world_id := ""
var current_meta: Dictionary = {}
## Save data waiting to be applied by World._ready() (empty for new worlds).
var pending: Dictionary = {}
## Class for a brand-new character (set when creating/quick-playing a world).
var new_character_class: StringName = ClassRegistry.DEFAULT_CLASS
## Body for a brand-new character (CharacterLook dict; empty = class default).
var new_character_look: Dictionary = {}
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
func create_world(world_name: String, seed_value: int, class_id: StringName = ClassRegistry.DEFAULT_CLASS, look: Dictionary = {}) -> String:
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
		"class": String(class_id),
		"save_version": SAVE_VERSION,
		"generator_version": 3,
		"game_version": ProjectSettings.get_setting("application/config/version", "0"),
		"created": now,
		"last_played": now,
		"play_time": 0.0,
	}
	_write_json(_meta_path(id), current_meta)
	current_world_id = id
	pending = {}
	new_character_class = class_id
	new_character_look = look.duplicate()
	GameState.reset(seed_value)
	GameState.set_region_directory(regions_path(id))
	_session_start_msec = Time.get_ticks_msec()
	_last_snapshot_msec = -1  # the first save of a new world gets a backup
	last_load = {}
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
	new_character_class = StringName(meta.get("class", ClassRegistry.DEFAULT_CLASS))
	GameState.reset(GameState.parse_seed(meta.get("seed", GameState.DEFAULT_SEED)))
	GameState.set_region_directory(regions_path(id))
	pending = {}
	last_load = {"source": "none", "backup": "", "problems": PackedStringArray()}
	var save = _read_json(_save_path(id))
	if save is Dictionary:
		last_load.source = "save"
	elif FileAccess.file_exists(_save_path(id)) or FileAccess.file_exists(_save_path(id) + ".bak"):
		last_load.problems.append("save.json is damaged")
		save = _read_json(_save_path(id) + ".bak")
		if save is Dictionary:
			last_load.source = "bak"
		else:
			# Last resort: the newest snapshot that reads cleanly.
			for b in list_backups(id):
				var snap = _read_json("%s/%s" % [b.path, SAVE_FILE])
				if snap is Dictionary:
					_copy_regions(b.path + "/" + REGIONS_DIR, regions_path(id))
					save = snap
					last_load.source = "backup"
					last_load.backup = b.name
					break
			if not save is Dictionary:
				last_load.problems.append("no readable backup")
	if save is Dictionary:
		save = _migrate(save)
		GameState.from_dict(save.get("game_state", {}))
		GameState.world_seed = GameState.parse_seed(meta.get("seed", GameState.world_seed))
		pending = save
	_session_start_msec = Time.get_ticks_msec()
	_last_snapshot_msec = -1
	# A snapshot of the world as it was loaded (if the last one isn't recent).
	if last_load.source in ["save", "bak", "backup"]:
		var newest := list_backups(id)
		var fresh: bool = not newest.is_empty() and Time.get_unix_time_from_system() - float(newest[0].created) < SNAPSHOT_INTERVAL
		if not fresh:
			_snapshot_files(id, "loaded")
		_last_snapshot_msec = Time.get_ticks_msec()
	return true


## Plays a world that is never written to disk (quick play, tests, --seed=).
func start_transient(seed_value: int, class_id: StringName = ClassRegistry.DEFAULT_CLASS, look: Dictionary = {}) -> void:
	current_world_id = ""
	current_meta = {}
	pending = {}
	new_character_class = class_id
	new_character_look = look.duplicate()
	GameState.reset(seed_value)
	_last_snapshot_msec = -1
	last_load = {}


## Writes the current world. Returns false for transient worlds or on errors.
func save_world(world: World) -> bool:
	if not is_persistent() or world == null:
		return false
	# Region files first: save.json never refers to changes that aren't on disk.
	if not GameState.regions.flush():
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
	current_meta["level"] = world.player.character.level
	_write_json(_meta_path(current_world_id), current_meta)
	if _last_snapshot_msec < 0 or now_msec - _last_snapshot_msec >= SNAPSHOT_INTERVAL * 1000.0:
		_snapshot_files(current_world_id, "autosave")
		_last_snapshot_msec = now_msec
	world_saved.emit(current_world_id)
	return true


# --- Backups & recovery (Milestone 13) ----------------------------------------------------

func backups_path(id: String) -> String:
	return "%s/%s/%s" % [worlds_dir, id, BACKUPS_DIR]


## Snapshots of a world, newest first: {name, path, created, reason, level, play_time, valid}.
func list_backups(id: String) -> Array:
	var out := []
	var dir := DirAccess.open(backups_path(id))
	if dir == null:
		return out
	for name in dir.get_directories():
		var path := "%s/%s" % [backups_path(id), name]
		var info = _read_json(path + "/snapshot.json")
		if not info is Dictionary:
			info = {}
		out.append({"name": name, "path": path, "created": float(info.get("created", 0.0)), "reason": String(info.get("reason", "?")),
			"level": int(info.get("level", 0)), "play_time": float(info.get("play_time", 0.0)),
			"valid": _read_json(path + "/" + SAVE_FILE) is Dictionary})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.created > b.created if a.created != b.created else String(a.name) > String(b.name))
	return out


## Copies the world's current files into a new snapshot. Returns its name ("" on failure).
func _snapshot_files(id: String, reason: String) -> String:
	if not FileAccess.file_exists(_save_path(id)):
		return ""
	var meta = _read_json(_meta_path(id))
	var name := _snapshot_name(id)
	var dest := "%s/%s" % [backups_path(id), name]
	DirAccess.make_dir_recursive_absolute(dest)
	if DirAccess.copy_absolute(_save_path(id), dest + "/" + SAVE_FILE) != OK:
		_remove_tree(dest)
		return ""
	if FileAccess.file_exists(_meta_path(id)):
		DirAccess.copy_absolute(_meta_path(id), dest + "/" + META_FILE)
	_copy_regions(regions_path(id), dest + "/" + REGIONS_DIR)
	_write_json(dest + "/snapshot.json", {"created": Time.get_unix_time_from_system(), "reason": reason,
		"level": int((meta as Dictionary).get("level", 1)) if meta is Dictionary else 1,
		"play_time": float((meta as Dictionary).get("play_time", 0.0)) if meta is Dictionary else 0.0,
		"game_version": ProjectSettings.get_setting("application/config/version", "0")})
	_prune_backups(id)
	return name


## Writes the live game into a new snapshot without touching save.json -
## used by the crash handler ("crash") so a half-broken session can't
## overwrite a good save.
func snapshot_world(world: World, reason: String) -> String:
	if not is_persistent() or world == null or not is_instance_valid(world.player):
		return ""
	var id := current_world_id
	var name := _snapshot_name(id)
	var dest := "%s/%s" % [backups_path(id), name]
	DirAccess.make_dir_recursive_absolute(dest)
	GameState.regions.flush()
	var data := {
		"save_version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
		"player": world.player.to_save(),
		"world": world.to_save(),
	}
	if not _write_json(dest + "/" + SAVE_FILE, data):
		_remove_tree(dest)
		return ""
	_write_json(dest + "/" + META_FILE, current_meta)
	_copy_regions(regions_path(id), dest + "/" + REGIONS_DIR)
	_write_json(dest + "/snapshot.json", {"created": Time.get_unix_time_from_system(), "reason": reason,
		"level": world.player.character.level, "play_time": float(current_meta.get("play_time", 0.0)),
		"game_version": ProjectSettings.get_setting("application/config/version", "0")})
	_prune_backups(id)
	return name


## Puts a snapshot back as the world's save (the current files become a
## "before restore" snapshot first, so a restore can be undone).
func restore_backup(id: String, name: String) -> bool:
	var src := "%s/%s" % [backups_path(id), name]
	if not _read_json(src + "/" + SAVE_FILE) is Dictionary:
		return false
	_snapshot_files(id, "before restore")
	if DirAccess.copy_absolute(src + "/" + SAVE_FILE, _save_path(id) + ".tmp") != OK:
		return false
	if FileAccess.file_exists(_save_path(id)):
		DirAccess.remove_absolute(_save_path(id))
	DirAccess.rename_absolute(_save_path(id) + ".tmp", _save_path(id))
	if FileAccess.file_exists(_save_path(id) + ".bak"):
		DirAccess.remove_absolute(_save_path(id) + ".bak")
	_remove_tree(regions_path(id))
	_copy_regions(src + "/" + REGIONS_DIR, regions_path(id))
	var meta = _read_json(_meta_path(id))
	var snap = _read_json(src + "/" + META_FILE)
	if snap is Dictionary:
		# Keep the world's name/id; take level and play time from the snapshot.
		var m: Dictionary = meta if meta is Dictionary else snap
		m["level"] = snap.get("level", m.get("level", 1))
		m["play_time"] = snap.get("play_time", m.get("play_time", 0.0))
		_write_json(_meta_path(id), m)
	elif not meta is Dictionary:
		return false
	if id == current_world_id:
		GameState.set_region_directory(regions_path(id))
	return true


## Health of a world's files: {ok, save, bak, meta, backups, valid_backups, problems}.
func verify_world(id: String) -> Dictionary:
	var r := {"save": _read_json(_save_path(id)) is Dictionary, "bak": _read_json(_save_path(id) + ".bak") is Dictionary,
		"meta": _read_json(_meta_path(id)) is Dictionary, "backups": 0, "valid_backups": 0, "problems": PackedStringArray()}
	for b in list_backups(id):
		r.backups += 1
		if b.valid:
			r.valid_backups += 1
	if not r.meta:
		r.problems.append("world.json is damaged")
	if not r.save and FileAccess.file_exists(_save_path(id)):
		r.problems.append("save.json is damaged" + (" (the previous save is fine)" if r.bak else ""))
	r.ok = r.problems.is_empty()
	return r


func _snapshot_name(id: String) -> String:
	var t := Time.get_datetime_dict_from_system()
	var base := "%04d%02d%02d-%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	var name := base
	var n := 2
	while DirAccess.dir_exists_absolute("%s/%s" % [backups_path(id), name]):
		name = "%s-%d" % [base, n]
		n += 1
	return name


func _prune_backups(id: String) -> void:
	var all := list_backups(id)
	for i in range(MAX_SNAPSHOTS, all.size()):
		_remove_tree(all[i].path)


func _copy_regions(from: String, to: String) -> void:
	var dir := DirAccess.open(from)
	if dir == null:
		return
	DirAccess.make_dir_recursive_absolute(to)
	for f in dir.get_files():
		if not f.ends_with(".tmp"):
			DirAccess.copy_absolute("%s/%s" % [from, f], "%s/%s" % [to, f])


func delete_world(id: String) -> bool:
	var path := "%s/%s" % [worlds_dir, id]
	if not DirAccess.dir_exists_absolute(path):
		return false
	if id == current_world_id:
		current_world_id = ""
		GameState.set_region_directory("")
	return _remove_tree(path)


func _remove_tree(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	for sub in dir.get_directories():
		_remove_tree("%s/%s" % [path, sub])
	for f in dir.get_files():
		dir.remove(f)
	return DirAccess.remove_absolute(path) == OK


## Folder of a world's region files.
func regions_path(id: String) -> String:
	return "%s/%s/%s" % [worlds_dir, id, REGIONS_DIR]


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
	# v1 -> v2: removed_props / enemy_deaths inside game_state are imported into
	# the region store by GameState.from_dict and written out on the next save.
	if v > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer game version (%d)" % v)
	return save


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return null
	if text.begins_with(HEADER):
		var nl := text.find("\n")
		if nl < 0:
			push_warning("SaveManager: truncated file %s" % path)
			return null
		var expected := text.substr(HEADER.length(), nl - HEADER.length()).strip_edges()
		text = text.substr(nl + 1)
		if text.sha256_text() != expected:
			push_warning("SaveManager: checksum mismatch in %s (damaged or edited)" % path)
			return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveManager: corrupt JSON in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data


func _write_json(path: String, data: Variant, keep_backup: bool = false) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	var text := JSON.stringify(data, "\t")
	f.store_string(HEADER + text.sha256_text() + "\n" + text)
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		push_error("SaveManager: writing %s failed (%s) - keeping the previous file" % [tmp, error_string(write_error)])
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if keep_backup:
			if FileAccess.file_exists(path + ".bak"):
				DirAccess.remove_absolute(path + ".bak")
			DirAccess.rename_absolute(path, path + ".bak")
		else:
			DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK
