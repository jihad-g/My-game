class_name RaidManager
extends Node
## Raids and settlement defense (Milestone 7).
##
## Base raids: once you have a home worth raiding (a land claim with at least
## BASE_MIN_PIECES pieces) bandits - or, on a blood moon, the restless dead -
## may attack it at night while you're near. You get a warning and a
## countdown (longer with an alarm bell), then 2-4 waves march in from one
## side. Raiders smash walls and doors in their way (brutes and bombers are
## siege specialists), fight you and your arrow towers. Beat every wave for
## raid spoils and XP. If you abandon the fight (die and stay away, or leave),
## the survivors plunder your chests and leave.
##
## Settlement raids: some mornings a rider warns that a village or town near
## you will be attacked in a few hours. Be there and the attack happens around
## you: villagers hide indoors, guards fight (they can be knocked down, never
## killed) and you defend the town for reputation and a reward. If you stay
## away the town's own guards may hold - or the town is plundered for two
## days (25% higher prices, gossip remembers).
##
## Everything is rolled from the world seed, day and hour, so it's repeatable.

const MONSTER_SCENE := preload("res://scenes/enemies/monster.tscn")
const BASE_MIN_PIECES := 8
const BASE_WARNING := 60.0
const BELL_BONUS := 45.0
const WAVE_GAP := 50.0
const RAID_TIMEOUT := 480.0
## Leaving the raid this far (m) for AWAY_LIMIT seconds abandons it.
const LEAVE_DISTANCE := 110.0
const AWAY_LIMIT := 30.0
## Base raid chance per night hour once allowed (blood moon: certain at 22:00).
const BASE_CHANCE := 0.18
const BASE_MIN_DAY := 3
const BASE_COOLDOWN_DAYS := 2
## Settlement raids: rolled at 10:00, strike TOWN_DELAY_HOURS later.
const TOWN_CHANCE := 0.4
const TOWN_RANGE := 750.0
const TOWN_DELAY_HOURS := 3.0
const TOWN_COOLDOWN_DAYS := 3
const PLUNDER_DAYS := 2
const PLUNDER_PRICE := 1.25
## Raid strength rolls per faction: tier -> pool of monster ids.
const BANDITS := [&"bandit_thug", &"bandit_thug", &"bandit_archer", &"bandit_bomber", &"bandit_brute", &"bandit_hexer"]
const UNDEAD := [&"skeleton_warrior", &"skeleton_warrior", &"skeleton_archer", &"thorn_crawler", &"grotto_cultist", &"arcane_sentinel"]

var world: World
## The raid in progress (warning or fighting), {} when none.
var raid: Dictionary = {}
var last_base_raid_day := -100
## Settlement id -> day it recovers from being plundered.
var plundered: Dictionary = {}
## Settlement id -> day the player defended it.
var defended: Dictionary = {}
## Settlement id -> last day it was raided (for cooldowns).
var raided: Dictionary = {}
## A settlement raid that has been announced: {id, at (world_time), tier}.
var pending_town: Dictionary = {}
var _counter := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if world and world.day_night:
		world.day_night.hour_changed.connect(_on_hour)


# --- Scheduling ---------------------------------------------------------------------------

func _on_hour(h: int) -> void:
	if world == null or not world.is_ready or world.player.is_dead:
		return
	var day := world.day_night.day
	_rng.seed = hash([GameState.world_seed, day, h, 77])
	if raid.is_empty() and world.layer == TerrainGenerator.Layer.SURFACE and world.dungeon == null:
		var night := h >= 21 or h <= 3
		var blood := world.events != null and world.events.is_active(&"blood_moon")
		if night and day >= BASE_MIN_DAY and day - last_base_raid_day >= BASE_COOLDOWN_DAYS or (blood and h == 22):
			var base := find_player_base()
			if not base.is_empty() and (blood and h == 22 or _rng.randf() < BASE_CHANCE):
				start_base_raid(base, &"undead" if blood else &"bandits")
				return
	if h == 10 and pending_town.is_empty() and day >= BASE_MIN_DAY:
		_roll_town_raid(day)


## The player's home: the land claim with the most pieces, if it has enough and you're near.
func find_player_base() -> Dictionary:
	var best := {}
	var p := world.player.global_position
	for c in get_tree().get_nodes_in_group(&"land_claims"):
		var claim := c as BuildPiece
		if claim == null or claim.layer != TerrainGenerator.Layer.SURFACE:
			continue
		var r := claim.claim_radius()
		if Vector2(p.x - claim.global_position.x, p.z - claim.global_position.z).length() > r + 60.0:
			continue
		var n := world.building.pieces_near(claim.global_position, r).size()
		if n >= BASE_MIN_PIECES and (best.is_empty() or n > int(best.pieces)):
			best = {"center": claim.global_position, "radius": r, "pieces": n, "claim": claim}
	return best


func has_bell(center: Vector3, radius: float) -> bool:
	for b in get_tree().get_nodes_in_group(&"alarm_bells"):
		if (b as Node3D).global_position.distance_to(center) <= radius + 5.0:
			return true
	return false


## Raid strength from the player's level (0..5).
func tier_for_level(level: int) -> int:
	return clampi((level - 1) / 6, 0, 5)


func _roll_town_raid(day: int) -> void:
	if _rng.randf() >= TOWN_CHANCE:
		return
	var p := world.player.global_position
	var options: Array[SettlementInfo] = []
	for s in world.generator.settlements.near(p, TOWN_RANGE):
		if is_plundered(s.id) or day - int(raided.get(s.id, -100)) < TOWN_COOLDOWN_DAYS:
			continue
		options.append(s)
	if options.is_empty():
		return
	var s: SettlementInfo = options[_rng.randi() % options.size()]
	announce_town_raid(s, TOWN_DELAY_HOURS)


## Announces an attack on a settlement in `hours` game hours (also used by tests).
func announce_town_raid(s: SettlementInfo, hours: float) -> void:
	var secs := hours / 24.0 * world.day_night.day_length
	pending_town = {"id": s.id, "at": GameState.world_time + secs,
		"tier": tier_for_level(world.player.character.level) + (1 if s.is_kingdom() else 0)}
	var p := world.player.global_position
	GameState.discovered_places["heard:%s" % s.id] = GameState.world_time
	var text := "A rider brings word: bandits will attack %s in %d hours! It lies %s to the %s." % [
		s.short_title(), roundi(hours), Gossip.distance_text(s.distance_to(p)), Gossip.direction(p, s.world_center())]
	Events.toast.emit(text, Color(1, 0.55, 0.35))
	Events.raid_warning.emit("town:" + s.id, s.world_center(), secs)


# --- Starting raids -----------------------------------------------------------------------

func start_base_raid(base: Dictionary, faction: StringName) -> void:
	var tier := tier_for_level(world.player.character.level)
	var center: Vector3 = base.center
	var warning := BASE_WARNING + (BELL_BONUS if has_bell(center, float(base.radius)) else 0.0)
	_begin({"kind": "base", "target": "base", "name": "your base", "center": center, "radius": float(base.radius),
		"faction": faction, "tier": tier, "warning": warning})
	var who := "The dead rise under the blood moon and march" if faction == &"undead" else "A bandit warband is coming"
	Events.toast.emit("RAID WARNING: %s on your base from the %s! (%ds)" % [who, _dir_name(raid.dir), roundi(warning)], Color(1, 0.45, 0.3))


func start_town_raid(s: SettlementInfo, tier: int) -> void:
	_begin({"kind": "town", "target": s.id, "name": s.short_title(), "center": s.world_center(), "radius": s.radius,
		"faction": &"bandits", "tier": clampi(tier, 0, 5), "warning": 8.0})
	raided[s.id] = world.day_night.day
	var site := _site(s.id)
	if site:
		site.set_under_attack(true)
	Events.toast.emit("%s is under attack! Defend the town!" % s.short_title(), Color(1, 0.45, 0.3))


func _begin(cfg: Dictionary) -> void:
	_counter += 1
	var tier: int = cfg.tier
	raid = cfg.duplicate()
	raid.id = "raid%d" % _counter
	raid.phase = "warning"
	raid.t = float(cfg.warning)
	raid.waves = 2 + (1 if tier >= 2 else 0) + (1 if tier >= 4 else 0)
	raid.wave = 0
	raid.wave_t = 0.0
	raid.elapsed = 0.0
	raid.away = 0.0
	raid.monsters = []
	raid.killed = 0
	raid.dir = _pick_direction(cfg.center, float(cfg.radius))
	if cfg.kind == "base":
		last_base_raid_day = world.day_night.day
	Events.raid_warning.emit(raid.target, raid.center, raid.t)


## Direction the raiders come from: the driest, most walkable approach to the
## target (water and steep steps along the line count against it).
func _pick_direction(center: Vector3, radius: float) -> float:
	var start := _rng.randf() * TAU
	var best := start
	var best_cost := INF
	for k in 16:
		var a := start + k * TAU / 16.0
		var dir := Vector3(cos(a), 0, sin(a))
		var cost := 0.0
		var prev := world.get_ground_height(center)
		var d := 2.0
		while d <= radius + 32.0:
			var h := world.get_ground_height(center + dir * d)
			if h < TerrainGenerator.WATER_Y + 0.2:
				cost += 4.0
			var step := absf(h - prev)
			if step > 1.1:
				cost += step * 2.0
			prev = h
			d += 2.0
		if cost < best_cost:
			best_cost = cost
			best = a
	return best


func _dir_name(a: float) -> String:
	var c: Vector3 = raid.center
	return Gossip.direction(c, c + Vector3(cos(a), 0, sin(a)) * 10.0)


## Ringing the alarm bell during a warning starts the fight right away.
func ring_bell(bell: Node3D) -> void:
	VFX.ring(bell.get_parent(), bell.global_position, 6.0, Color(1.0, 0.85, 0.4, 0.8), 0.6)
	if not raid.is_empty() and raid.phase == "warning" and raid.kind == "base":
		raid.t = 0.0
		Events.toast.emit("The bell rings out: to arms!", Color(1, 0.8, 0.4))
	else:
		Events.toast.emit("The bell rings out. All is quiet." if raid.is_empty() else "The bell rings out!", Color(1, 0.9, 0.6))


# --- Running raids ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or not world.is_ready:
		return
	if not pending_town.is_empty() and GameState.world_time >= float(pending_town.at):
		_resolve_pending_town()
	if raid.is_empty():
		return
	raid.elapsed = float(raid.elapsed) + delta
	match raid.phase:
		"warning":
			raid.t = float(raid.t) - delta
			if float(raid.t) <= 0.0:
				raid.phase = "fight"
				Events.raid_started.emit(raid.target)
				_spawn_wave()
		"fight":
			_update_fight(delta)


func _update_fight(delta: float) -> void:
	var alive := alive_raiders()
	raid.wave_t = float(raid.wave_t) + delta
	if int(raid.wave) < int(raid.waves) and (alive.size() <= 1 or float(raid.wave_t) >= WAVE_GAP):
		_spawn_wave()
		return
	if int(raid.wave) >= int(raid.waves) and alive.is_empty():
		_finish(true)
		return
	# Abandoned: the player is far away (or dead) for too long, or it took far too long.
	var p := world.player
	var far: bool = p.is_dead or world.dungeon != null or world.layer != TerrainGenerator.Layer.SURFACE \
		or p.global_position.distance_to(raid.center) > LEAVE_DISTANCE
	raid.away = float(raid.away) + delta if far else 0.0
	if float(raid.away) >= AWAY_LIMIT or float(raid.elapsed) >= RAID_TIMEOUT:
		_finish(false)


func alive_raiders() -> Array:
	var out := []
	for m in raid.get("monsters", []):
		if is_instance_valid(m) and not m.is_dead and m.is_inside_tree() and m.visible and m.get_meta(&"raid", "") == raid.id \
				and not out.has(m):
			out.append(m)
	return out


func _spawn_wave() -> void:
	raid.wave = int(raid.wave) + 1
	raid.wave_t = 0.0
	var w: int = raid.wave
	var tier: int = raid.tier
	var count := mini(3 + tier + w - 1, 9)
	var pool: Array = BANDITS if raid.faction == &"bandits" else UNDEAD
	var top := mini(pool.size(), 3 + tier)
	var ids: Array[StringName] = []
	for k in count:
		ids.append(pool[_rng.randi() % top])
	# Siege specialists from tier 1, a leader in the last wave of strong raids.
	if raid.faction == &"bandits":
		if tier >= 1 and not ids.has(&"bandit_brute"):
			ids[0] = &"bandit_brute" if tier >= 2 else &"bandit_bomber"
		if w == int(raid.waves) and (tier >= 4 or (tier >= 2 and _rng.randf() < 0.5)):
			ids.append(&"bandit_warlord")
	var blood := world.events != null and world.events.is_active(&"blood_moon")
	var center: Vector3 = raid.center
	var a0: float = raid.dir
	for k in ids.size():
		var a := a0 + _rng.randf_range(-0.45, 0.45)
		var dist := float(raid.radius) + _rng.randf_range(24.0, 32.0)
		var pos := center + Vector3(cos(a), 0, sin(a)) * dist
		# Prefer ground whose collision is loaded (closer to the target if needed).
		while dist > float(raid.radius) + 8.0 and not world.chunk_manager.is_collision_ready_at(pos):
			dist -= 4.0
			pos = center + Vector3(cos(a), 0, sin(a)) * dist
		pos.y = world.get_ground_height(pos) + 0.4
		var m := spawn_raider(ids[k], pos, tier, blood)
		if m and not raid.monsters.has(m):
			raid.monsters.append(m)
	Events.raid_wave.emit(raid.target, w, int(raid.waves))
	Events.toast.emit("Raid wave %d of %d!" % [w, int(raid.waves)], Color(1, 0.5, 0.35))


func spawn_raider(id: StringName, pos: Vector3, tier: int, blood: bool) -> Monster:
	var data := load("res://data/enemies/%s.tres" % id) as MonsterData
	if data == null:
		return null
	var m := world.spawner.spawn_enemy(MONSTER_SCENE, pos, "", data) as Monster
	if m == null:
		return null
	m.configure(1.0 + 0.3 * tier, 1.0 + 0.15 * tier, 2 * tier, 1.0 + 0.25 * tier)
	if data.can_be_elite and data.style != MonsterData.Style.BOSS and _rng.randf() < EliteAffixes.chance(tier, 0.04 + (0.15 if blood else 0.0)):
		m.make_elite(EliteAffixes.roll(_rng, 2 if tier >= 4 and _rng.randf() < 0.3 else 1, data.style != MonsterData.Style.MELEE))
	m.set_raid(raid.center, raid.id)
	m.set_meta(&"raid", raid.id)
	return m


func _finish(won: bool) -> void:
	var r := raid
	raid = {}
	var tier: int = r.tier
	var survivors := []
	for m in r.monsters:
		if is_instance_valid(m) and not m.is_dead and m.is_inside_tree() and m.get_meta(&"raid", "") == r.id:
			survivors.append(m)
	if r.kind == "base":
		if won:
			var roll := LootTables.roll(&"raid_spoils", tier, _rng)
			LootTables.give(roll, (r.center as Vector3) + Vector3(0, 0.5, 0))
			world.player.character.grant_xp(80 + 40 * tier, Progression.Source.COMBAT)
			Events.toast.emit("Raid repelled! The raiders' spoils are yours.", UITheme.GOLD)
		else:
			var lost := plunder_base(r.center, float(r.radius), mini(maxi(survivors.size(), 1), 4))
			Events.toast.emit("The raiders plundered your base%s and left." % (": lost " + ", ".join(lost) if not lost.is_empty() else ""), Color(1, 0.5, 0.4))
	else:
		var info := world.generator.settlements.find(r.target)
		var site := _site(r.target)
		if site:
			site.set_under_attack(false)
		if info:
			if won:
				defended[info.id] = world.day_night.day
				var coins := 60 * (1 + tier)
				world.player.coins += coins
				Events.coins_changed.emit(world.player.coins)
				world.player.reputation.add(info, 12.0 + 4.0 * tier)
				world.player.character.grant_xp(100 + 50 * tier, Progression.Source.QUEST)
				Events.toast.emit("%s is saved! The townsfolk reward you with %s." % [info.short_title(), Economy.format_coins(coins)], UITheme.GOLD)
			else:
				plundered[info.id] = world.day_night.day + PLUNDER_DAYS
				Events.toast.emit("%s was plundered by the raiders." % info.short_title(), Color(1, 0.5, 0.4))
	for m in survivors:
		NodePool.release_or_free(m)
	Events.raid_ended.emit(r.target, won)


## Survivors carry off up to `n` stacks from chests in the base. Returns what was taken.
func plunder_base(center: Vector3, radius: float, n: int) -> PackedStringArray:
	var out := PackedStringArray()
	var chests: Array = []
	for p in world.building.pieces_near(center, radius):
		if p.storage and p.storage.free_slot_count() < p.storage.capacity:
			chests.append(p)
	while n > 0 and not chests.is_empty():
		var c: BuildPiece = chests[_rng.randi() % chests.size()]
		var filled := []
		for i in c.storage.capacity:
			if c.storage.get_slot(i) != null:
				filled.append(i)
		if filled.is_empty():
			chests.erase(c)
			continue
		var i: int = filled[_rng.randi() % filled.size()]
		var st = c.storage.get_slot(i)
		var d: ItemData = ItemDB.get_item(st.id)
		out.append("%d %s" % [int(st.count), d.display_name if d else String(st.id)])
		c.storage.remove_from_slot(i, int(st.count))
		n -= 1
	return out


## The announced settlement attack begins: fight it if you're there, otherwise the guards decide.
func _resolve_pending_town() -> void:
	var info := world.generator.settlements.find(String(pending_town.id))
	var tier := int(pending_town.tier)
	pending_town = {}
	if info == null:
		return
	var near := world.dungeon == null and world.layer == TerrainGenerator.Layer.SURFACE \
		and info.distance_to(world.player.global_position) < info.radius + 90.0
	if near and raid.is_empty() and not world.player.is_dead:
		start_town_raid(info, tier)
		return
	raided[info.id] = world.day_night.day
	var hold := 0.85 if info.is_kingdom() else 0.5
	_rng.seed = hash([GameState.world_seed, info.id, world.day_night.day])
	if _rng.randf() < hold:
		Events.toast.emit("Word reaches you: the guards of %s drove off the raiders." % info.short_title(), Color(0.8, 0.9, 1.0))
	else:
		plundered[info.id] = world.day_night.day + PLUNDER_DAYS
		Events.toast.emit("Word reaches you: %s was plundered by bandits." % info.short_title(), Color(1, 0.55, 0.45))


func _site(id: String) -> SettlementSite:
	return world.living.sites.get(id, null) if world.living else null


## Called when a settlement streams in mid-raid.
func on_site_spawned(site: SettlementSite) -> void:
	if not raid.is_empty() and raid.kind == "town" and raid.target == site.info.id:
		site.set_under_attack(true)


func is_plundered(id: String) -> bool:
	return int(plundered.get(id, -1)) >= (world.day_night.day if world and world.day_night else 0)


func is_active() -> bool:
	return not raid.is_empty()


## One-line HUD status ("" when nothing is happening).
func status_text() -> String:
	if not raid.is_empty():
		if raid.phase == "warning":
			return "RAID on %s in %ds - from the %s" % [raid.name, ceili(float(raid.t)), _dir_name(raid.dir)]
		return "RAID on %s · wave %d/%d · %d raiders left" % [raid.name, int(raid.wave), int(raid.waves), alive_raiders().size()]
	if not pending_town.is_empty():
		var info := world.generator.settlements.find(String(pending_town.id))
		if info:
			return "%s will be attacked in %ds" % [info.short_title(), ceili(float(pending_town.at) - GameState.world_time)]
	return ""


# --- Save ---------------------------------------------------------------------------------

func to_save() -> Dictionary:
	var pend := {}
	if not pending_town.is_empty():
		pend = {"id": pending_town.id, "in": float(pending_town.at) - GameState.world_time, "tier": pending_town.tier}
	return {"last_base": last_base_raid_day, "plundered": plundered.duplicate(), "defended": defended.duplicate(),
		"raided": raided.duplicate(), "pending": pend}


func from_save(d: Dictionary) -> void:
	last_base_raid_day = int(d.get("last_base", -100))
	plundered = {}
	for k in d.get("plundered", {}):
		plundered[k] = int(d.plundered[k])
	defended = {}
	for k in d.get("defended", {}):
		defended[k] = int(d.defended[k])
	raided = {}
	for k in d.get("raided", {}):
		raided[k] = int(d.raided[k])
	var pend: Dictionary = d.get("pending", {})
	pending_town = {}
	if not pend.is_empty():
		pending_town = {"id": String(pend.id), "at": GameState.world_time + float(pend.get("in", 0.0)), "tier": int(pend.get("tier", 0))}
