extends SceneTree
## Writes the Steamworks configuration that comes from game data (Milestone 13):
##   platform/steam/achievements.csv     API name, display name, description, hidden,
##                                       progress stat and goal - enter these in
##                                       Steamworks → Stats & Achievements
##   platform/steam/stats.csv            the INT stats the game reports
##   platform/steam/rich_presence.vdf    localization file for "#Status" rich presence
##
##   godot --headless --path . -s tools/export_steam_config.gd


func _init() -> void:
	var dir := "res://platform/steam"
	DirAccess.make_dir_recursive_absolute(dir)
	var lines := PackedStringArray(["api_name,display_name,description,hidden,progress_stat,goal"])
	for a in Achievements.LIST:
		# a = [id, name, description, stat, goal, hidden]
		lines.append("%s,\"%s\",\"%s\",%d,%s,%d" % [a[0], a[1], a[2], 1 if a[5] else 0, String(a[3]), int(a[4])])
	_write(dir + "/achievements.csv", lines)
	var stats := PackedStringArray(["api_name,type,set_by"])
	for s in Achievements.STATS:
		stats.append("%s,INT,Client" % s)
	_write(dir + "/stats.csv", stats)
	_write(dir + "/rich_presence.vdf", PackedStringArray([
		"\"lang\"", "{", "\t\"Language\"\t\"english\"", "\t\"Tokens\"", "\t{",
		"\t\t\"#Status\"\t\"{%status%}\"", "\t}", "}"]))
	print("Steam config written to ", ProjectSettings.globalize_path(dir))
	quit()


func _write(path: String, lines: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
