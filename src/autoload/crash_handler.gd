extends Node
## Crash handling (Milestone 13).
##
## - A session lock (user://sessions/<pid>.lock) is written at start and refreshed
##   every HEARTBEAT seconds with what the game is doing (scene, world, player
##   position, frame rate). It is removed on a clean exit.
## - A lock whose process is no longer running means that session ended
##   unexpectedly (crash, power loss, killed process): a crash report is written
##   to user://crash_reports/<time>/ with the session info, system info and the
##   tail of the previous log, and the main menu tells the player.
## - When the engine reports an imminent crash (NOTIFICATION_CRASH, desktop
##   only) the live world is written to an emergency snapshot - never over the
##   regular save - so the menu's Recover screen can bring it back.

signal report_written(path: String)

const SESSIONS_DIR := "user://sessions"
const REPORTS_DIR := "user://crash_reports"
const LOGS_DIR := "user://logs"
const HEARTBEAT := 20.0
const MAX_REPORTS := 10
const LOG_TAIL_LINES := 200

var sessions_dir := SESSIONS_DIR
var lock_path := ""
var reports_dir := REPORTS_DIR
var logs_dir := LOGS_DIR
## True when the previous session didn't exit cleanly (set at startup).
var crashed_last_time := false
## The lock of that previous session (what it was doing).
var previous_session: Dictionary = {}
## Folder of the report written for it ("" if none).
var last_report := ""
var _started := 0.0
var _beat := 0.0
var _emergency_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started = Time.get_unix_time_from_system()
	lock_path = "%s/%s.lock" % [sessions_dir, _session_name()]
	check_previous_session()
	write_lock()


## Looks for locks of sessions that are no longer running (other running
## instances - e.g. a co-op guest on the same PC - are left alone) and turns
## each into a crash report.
func check_previous_session() -> void:
	var dir := DirAccess.open(sessions_dir)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".lock"):
			continue
		var path := "%s/%s" % [sessions_dir, f]
		if path == lock_path and not OS.has_feature("web"):
			continue
		# Browsers have no process ids: a lock left by an earlier visit is a crash.
		var pid := f.get_basename().to_int()
		if not OS.has_feature("web") and pid > 0 and pid != OS.get_process_id() and OS.is_process_running(pid):
			continue
		var text := FileAccess.get_file_as_string(path)
		var data = JSON.parse_string(text)
		previous_session = data if data is Dictionary else {"raw": text}
		crashed_last_time = true
		last_report = write_report(previous_session)
		DirAccess.remove_absolute(path)


func write_lock(extra: Dictionary = {}) -> void:
	var info := {
		"started": _started,
		"heartbeat": Time.get_unix_time_from_system(),
		"version": ProjectSettings.get_setting("application/config/version", "0"),
		"pid": 0 if OS.has_feature("web") else OS.get_process_id(),
		"scene": get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else "",
		"fps": Engine.get_frames_per_second(),
	}
	if SaveManager.is_persistent():
		info["world"] = SaveManager.current_world_id
	if World.instance and is_instance_valid(World.instance.player):
		var p := World.instance.player.global_position
		info["position"] = [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]
		info["level"] = World.instance.player.character.level
		info["in_dungeon"] = World.instance.dungeon != null
		info["online"] = Net.is_online()
	info.merge(extra, true)
	DirAccess.make_dir_recursive_absolute(sessions_dir)
	var f := FileAccess.open(lock_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(info))
		f.close()


func _process(delta: float) -> void:
	_beat -= delta
	if _beat <= 0.0:
		_beat = HEARTBEAT
		write_lock()


func _session_name() -> String:
	return "web" if OS.has_feature("web") else str(OS.get_process_id())


## Clean exit: no lock = no crash next time.
func clear_lock() -> void:
	if lock_path != "" and FileAccess.file_exists(lock_path):
		DirAccess.remove_absolute(lock_path)


func _exit_tree() -> void:
	clear_lock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_CRASH:
		emergency_save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# The world saves itself on close; the lock goes when the tree exits.
		pass


## Writes the live world to an emergency snapshot (once).
func emergency_save() -> String:
	if _emergency_done:
		return ""
	_emergency_done = true
	if World.instance == null or not World.instance.is_ready or not SaveManager.is_persistent():
		return ""
	var name := SaveManager.snapshot_world(World.instance, "crash")
	write_lock({"emergency_snapshot": name})
	return name


# --- Reports -------------------------------------------------------------------------------

## Writes a crash report for a previous session. Returns its folder.
func write_report(session: Dictionary) -> String:
	var t := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	var dir := "%s/%s" % [reports_dir, stamp]
	var n := 2
	while DirAccess.dir_exists_absolute(dir):
		dir = "%s/%s-%d" % [reports_dir, stamp, n]
		n += 1
	DirAccess.make_dir_recursive_absolute(dir)
	var lines := PackedStringArray()
	lines.append("Shardlands crash report")
	lines.append("=======================")
	lines.append("The previous session did not exit cleanly (crash, freeze, power loss or a killed process).")
	lines.append("")
	lines.append("Session")
	var started := float(session.get("started", 0.0))
	var beat := float(session.get("heartbeat", 0.0))
	lines.append("  game version:   %s" % session.get("version", "?"))
	lines.append("  started:        %s" % (Time.get_datetime_string_from_unix_time(int(started), true) if started > 0 else "?"))
	lines.append("  last heartbeat: %s (%s into the session)" % [Time.get_datetime_string_from_unix_time(int(beat), true) if beat > 0 else "?",
		_duration(beat - started) if beat > 0 and started > 0 else "?"])
	for k in ["scene", "world", "level", "position", "in_dungeon", "online", "fps", "emergency_snapshot"]:
		if session.has(k):
			lines.append("  %-15s %s" % [k + ":", str(session[k])])
	lines.append("")
	lines.append("System")
	lines.append("  OS:        %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("  CPU:       %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	lines.append("  GPU:       %s" % RenderingServer.get_video_adapter_name())
	lines.append("  renderer:  %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
	lines.append("  memory:    %d MB physical" % int(OS.get_memory_info().get("physical", 0) / 1048576))
	lines.append("  engine:    %s" % Engine.get_version_info().string)
	var log_file := previous_log()
	lines.append("")
	lines.append("Log: %s" % (log_file.get_file() if log_file != "" else "(no previous log found)"))
	var f := FileAccess.open(dir + "/report.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	if log_file != "":
		var tail := log_tail(log_file, LOG_TAIL_LINES)
		var lf := FileAccess.open(dir + "/log_tail.txt", FileAccess.WRITE)
		if lf:
			lf.store_string(tail)
			lf.close()
	_prune_reports()
	report_written.emit(dir)
	return dir


## The log of the previous run: Godot rotates godot.log to godot<time>.log
## at startup, so it's the newest rotated file.
func previous_log() -> String:
	var dir := DirAccess.open(logs_dir)
	if dir == null:
		return ""
	var best := ""
	var best_time := -1
	for f in dir.get_files():
		if not f.ends_with(".log") or f == "godot.log":
			continue
		var mt := FileAccess.get_modified_time("%s/%s" % [logs_dir, f])
		if mt > best_time:
			best_time = mt
			best = "%s/%s" % [logs_dir, f]
	return best


static func log_tail(path: String, n: int) -> String:
	var text := FileAccess.get_file_as_string(path)
	var all := text.split("\n")
	return "\n".join(all.slice(maxi(0, all.size() - n)))


func list_reports() -> Array:
	var out := []
	var dir := DirAccess.open(reports_dir)
	if dir == null:
		return out
	for d in dir.get_directories():
		out.append("%s/%s" % [reports_dir, d])
	out.sort()
	out.reverse()
	return out


func _prune_reports() -> void:
	var all := list_reports()
	for i in range(MAX_REPORTS, all.size()):
		var d := DirAccess.open(all[i])
		if d:
			for f in d.get_files():
				d.remove(f)
		DirAccess.remove_absolute(all[i])


static func _duration(sec: float) -> String:
	var s := int(sec)
	return "%dh %02dm %02ds" % [s / 3600, (s / 60) % 60, s % 60]
