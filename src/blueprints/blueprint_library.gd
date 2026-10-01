class_name BlueprintLibrary
## Where blueprints live (Milestone 8):
##   res://data/blueprints/*.json  - built-in designs (read-only)
##   user://blueprints/*.json      - your own (captured in game or imported
##                                   from the web designer / clipboard)

const BUILTIN_DIR := "res://data/blueprints/"
static var user_dir := "user://blueprints/"


static func builtin() -> Array[Blueprint]:
	return _load_dir(BUILTIN_DIR)


static func user() -> Array[Blueprint]:
	return _load_dir(user_dir)


## Built-ins first, then yours. Each has meta "builtin" and "path".
static func all() -> Array[Blueprint]:
	var out := builtin()
	out.append_array(user())
	return out


static func _load_dir(dir: String) -> Array[Blueprint]:
	var out: Array[Blueprint] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var files := d.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var path := dir.path_join(f)
		var bp := load_file(path)
		if bp:
			bp.set_meta(&"builtin", dir == BUILTIN_DIR)
			bp.set_meta(&"path", path)
			out.append(bp)
	return out


static func load_file(path: String) -> Blueprint:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return Blueprint.from_json(f.get_as_text())


## A file name from the blueprint's name ("My Hut!" -> "my_hut").
static func slug(text: String) -> String:
	var s := ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			s += ch
		elif not s.ends_with("_"):
			s += "_"
	s = s.strip_edges().trim_prefix("_").trim_suffix("_")
	return s if s != "" else "blueprint"


## Saves to the user folder (never overwrites another design: adds _2, _3...). Returns the path or "".
static func save(bp: Blueprint, overwrite_path: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(user_dir)
	var path := overwrite_path
	if path == "":
		var base := slug(bp.name)
		path = user_dir.path_join(base + ".json")
		var n := 2
		while FileAccess.file_exists(path):
			path = user_dir.path_join("%s_%d.json" % [base, n])
			n += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(bp.to_json())
	f.close()
	bp.set_meta(&"path", path)
	bp.set_meta(&"builtin", false)
	return path


static func delete(bp: Blueprint) -> bool:
	if bp.get_meta(&"builtin", false) or not bp.has_meta(&"path"):
		return false
	return DirAccess.remove_absolute(String(bp.get_meta(&"path"))) == OK


## Imports blueprint JSON text (from the clipboard or the web designer). Returns the
## saved Blueprint (check `warnings`) or null if the text isn't a blueprint.
static func import_text(text: String) -> Blueprint:
	var bp := Blueprint.from_json(text.strip_edges())
	if bp == null or bp.pieces.is_empty():
		return null
	save(bp)
	return bp
