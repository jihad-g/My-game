extends Node
## Platform layer (Milestone 13): achievements, stats, rich presence and the
## store overlay, behind one API so the game never talks to a store directly.
##
## Backends: SteamBackend when the GodotSteam extension is installed and an
## app id is set, otherwise the local backend. Achievements and stats are
## always also kept in the player profile (user://profile.cfg), so progress
## shows in the game's own Achievements list on every platform and carries over
## when a store backend becomes available (stats are re-sent on start).

signal achievement_unlocked(id: StringName)

const PROFILE_PATH := "user://profile.cfg"
const PRESENCE_INTERVAL := 10.0
const STORE_INTERVAL := 30.0

var backend: PlatformBackend
var profile_path := PROFILE_PATH
var unlocked: Dictionary = {}  # id -> unix time
var stats: Dictionary = {}  # stat -> int
var presence := ""
## Pause the game while the store overlay is open (single player only).
var pause_on_overlay := true
var _presence_left := 0.0
var _store_left := 0.0
var _dirty := false
var _dungeon_rank := -1
var _last_pos := Vector3.INF
var _distance := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()
	backend = _pick_backend()
	for s in stats:
		backend.set_stat(s, int(stats[s]))
	for a in unlocked:
		backend.unlock(a)
	backend.store()
	_connect_events()


func _pick_backend() -> PlatformBackend:
	var app_id := int(ProjectSettings.get_setting("shardlands/platform/steam_app_id", 0))
	if FileAccess.file_exists("res://steam_appid.txt"):
		app_id = FileAccess.get_file_as_string("res://steam_appid.txt").strip_edges().to_int()
	if "--no-steam" not in OS.get_cmdline_user_args() and Engine.has_singleton("Steam") and app_id > 0:
		var sb := SteamBackend.new(Engine.get_singleton("Steam"), app_id)
		if sb.init():
			sb.overlay_changed.connect(_on_overlay)
			print("Platform: Steam (app %d) as %s" % [app_id, sb.user_name()])
			return sb
	return PlatformBackend.new()


## Replaces the backend (tests use a fake Steam).
func use_backend(b: PlatformBackend) -> void:
	if backend:
		backend.shutdown()
	backend = b
	if b is SteamBackend:
		(b as SteamBackend).overlay_changed.connect(_on_overlay)


func backend_id() -> String:
	return backend.id() if backend else "none"


func _process(delta: float) -> void:
	if backend:
		backend.poll()
	_presence_left -= delta
	if _presence_left <= 0.0:
		_presence_left = PRESENCE_INTERVAL
		update_presence()
		_check_state()
	_store_left -= delta
	if _store_left <= 0.0 and _dirty:
		_store_left = STORE_INTERVAL
		flush()
	# Distance walked (for the stats page).
	var w := World.instance
	if w and w.is_ready and is_instance_valid(w.player) and w.dungeon == null:
		var p := w.player.global_position
		if _last_pos != Vector3.INF:
			var d := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
			if d < 20.0:  # ignore teleports
				_distance += d
				if _distance >= 1000.0:
					_distance -= 1000.0
					add_stat(&"distance_km")
		_last_pos = p
	else:
		_last_pos = Vector3.INF


# --- Achievements & stats ------------------------------------------------------------------

func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func unlock(id: StringName) -> bool:
	if unlocked.has(id) or Achievements.get_def(id).is_empty():
		return false
	if Player.creative_used:
		return false  # Creative mode was used this session (Milestone 18c)
	unlocked[id] = Time.get_unix_time_from_system()
	backend.unlock(id)
	_dirty = true
	flush()
	achievement_unlocked.emit(id)
	Events.toast.emit("Achievement unlocked: %s" % Achievements.display_name(id), Color(1, 0.85, 0.35))
	Audio.play_ui(&"level_up", -6.0)
	return true


func stat(name: StringName) -> int:
	return int(stats.get(name, 0))


func add_stat(name: StringName, amount: int = 1) -> void:
	set_stat(name, stat(name) + amount)


func set_stat(name: StringName, value: int) -> void:
	stats[name] = value
	backend.set_stat(name, value)
	_dirty = true
	for a in Achievements.LIST:
		if a[Achievements.STAT] == name and value >= int(a[Achievements.GOAL]):
			unlock(a[Achievements.ID])


## Progress toward an achievement: [current, goal].
func progress(id: StringName) -> Array:
	var d := Achievements.get_def(id)
	if d.is_empty():
		return [0, 1]
	var goal := int(d[Achievements.GOAL])
	if is_unlocked(id):
		return [goal, goal]
	if d[Achievements.STAT] != &"":
		return [mini(stat(d[Achievements.STAT]), goal), goal]
	return [0, goal]


func flush() -> void:
	_dirty = false
	backend.store()
	save_profile()


func _connect_events() -> void:
	Events.item_crafted.connect(func(id: StringName, n: int) -> void:
		add_stat(&"items_crafted", n)
		var it := ItemDB.get_item(id)
		if it and it.rarity >= ItemData.Rarity.LEGENDARY and it.is_equippable():
			unlock(&"legendary"))
	Events.resource_harvested.connect(func(prop_id: StringName, _xp: int) -> void:
		if String(prop_id).contains("tree") or String(prop_id).contains("pine") or String(prop_id).contains("oak") or String(prop_id).contains("palm"):
			add_stat(&"trees_felled"))
	Events.enemy_killed.connect(func(e: Node, _id: StringName, _p: Vector3) -> void:
		add_stat(&"monsters_killed")
		if e and e.has_method("is_boss") and e.is_boss():
			add_stat(&"bosses_killed"))
	Events.dungeon_entered.connect(func(_id: String, _f: int) -> void:
		if World.instance and World.instance.dungeon:
			_dungeon_rank = World.instance.dungeon.poi.rank)
	Events.dungeon_left.connect(func(_id: String, cleared: bool) -> void:
		if cleared:
			add_stat(&"dungeons_cleared")
			if _dungeon_rank >= 5:
				unlock(&"s_rank")
		_dungeon_rank = -1)
	Events.biome_discovered.connect(func(_b: StringName) -> void: add_stat(&"biomes_discovered"))
	Events.poi_discovered.connect(func(_p: String) -> void: add_stat(&"pois_discovered"))
	Events.trade_done.connect(func(_s: String, copper: int) -> void: add_stat(&"copper_traded", copper))
	Events.raid_ended.connect(func(_t: String, won: bool) -> void:
		if won:
			add_stat(&"raids_repelled"))
	Events.player_died.connect(func() -> void: add_stat(&"deaths"))
	Events.level_up.connect(func(_l: int) -> void: _check_state())
	Events.spell_learned.connect(func(_s: StringName) -> void: _check_state())
	Events.building_changed.connect(_check_state)


## Achievements that depend on the character or world state.
func _check_state() -> void:
	var w := World.instance
	if w == null or not is_instance_valid(w.player) or w.player.character == null:
		return
	var lvl: int = w.player.character.level
	for pair in [[&"level_10", 10], [&"level_50", 50], [&"level_100", 100]]:
		if lvl >= pair[1]:
			unlock(pair[0])
	if w.player.character.skill_level(Skill.CRAFTING) >= 100:
		unlock(&"crafting_100")
	if w.player.spells and w.player.spells.known.size() >= 4:
		unlock(&"spellbinder")
	if w.building and w.building.pieces.size() >= 25:
		unlock(&"homestead")
	if Net.is_online() and Net.players.size() >= 2:
		unlock(&"together")


# --- Presence & overlay --------------------------------------------------------------------

## "Level 12 Knight · Whispering Forest" / "Main menu" ...
func update_presence() -> void:
	var w := World.instance
	var text := "In the main menu"
	if w and w.is_ready and is_instance_valid(w.player) and w.player.character:
		var c := w.player.character
		text = "Level %d %s" % [c.level, c.class_data.display_name if c.class_data else ""]
		if w.dungeon:
			text += " · %s" % w.dungeon.poi.title()
		elif w.current_biome:
			text += " · %s" % w.current_biome.display_name
		if Net.is_online():
			text += " · co-op (%d)" % Net.players.size()
	if text != presence:
		presence = text
		backend.set_presence(text)


func _on_overlay(active: bool) -> void:
	var w := World.instance
	if not pause_on_overlay or w == null or not w.is_ready or Net.is_online():
		return
	if active and not get_tree().paused:
		w.hud.set_paused(true)


# --- Profile ----------------------------------------------------------------------------------

func load_profile() -> void:
	unlocked.clear()
	stats.clear()
	var cf := ConfigFile.new()
	if cf.load(profile_path) != OK:
		return
	var a = cf.get_value("achievements", "unlocked", {})
	if a is Dictionary:
		for k in a:
			unlocked[StringName(k)] = float(a[k])
	var s = cf.get_value("stats", "values", {})
	if s is Dictionary:
		for k in s:
			stats[StringName(k)] = int(s[k])


func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.load(profile_path)  # keep the tutorial section
	var a := {}
	for k in unlocked:
		a[String(k)] = unlocked[k]
	var s := {}
	for k in stats:
		s[String(k)] = stats[k]
	cf.set_value("achievements", "unlocked", a)
	cf.set_value("stats", "values", s)
	cf.save(profile_path)


func _exit_tree() -> void:
	if _dirty:
		flush()
	if backend:
		backend.shutdown()
