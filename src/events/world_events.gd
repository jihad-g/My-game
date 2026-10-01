class_name WorldEvents
extends Node
## Rare world events (Milestone 7), rolled from the world seed each hour:
##
##   blood_moon       night (21:00-05:00), ~1 in 8 nights from day 4: red sky,
##                    the dead roam in groups, elites are far more common,
##                    +50% combat XP, and your base WILL be raided at 22:00.
##   meteor_shower    night, ~1 in 6 from day 2: shooting stars; one meteor
##                    crashes 60-140 m away - mine it for star metal. 35% of
##                    the time a Starborn Colossus (world boss) guards it.
##   aurora           night in cold biomes, ~1 in 5: green sky, mana
##                    regenerates twice as fast and spells hit 15% harder.
##   treasure_goblin  daytime, rare: a goblin with a sack of gold appears near
##                    you and runs. Catch it within 45 s for gold, gems, tomes.
##   eclipse          noon, ~1 in 15 days from day 5: two hours of darkness
##                    in which the dead walk.
##
## Event monsters are untracked spawns, cleaned up when the event ends.

const MONSTER_SCENE := preload("res://scenes/enemies/monster.tscn")
const IDS: Array[StringName] = [&"blood_moon", &"meteor_shower", &"aurora", &"treasure_goblin", &"eclipse"]
const NAMES := {&"blood_moon": "Blood Moon", &"meteor_shower": "Meteor Shower", &"aurora": "Aurora",
	&"treasure_goblin": "Treasure Goblin", &"eclipse": "Eclipse"}
const BLOOD_MOON_CHANCE := 0.125
const METEOR_CHANCE := 0.17
const AURORA_CHANCE := 0.2
const GOBLIN_CHANCE := 0.06
const ECLIPSE_CHANCE := 0.07
const COLOSSUS_CHANCE := 0.35
const GOBLIN_TIME := 45.0
const HORDE_INTERVAL := 25.0
const MAX_EVENT_MONSTERS := 8
const UNDEAD := [&"skeleton_warrior", &"skeleton_warrior", &"skeleton_archer", &"thorn_crawler", &"grotto_cultist"]
const COLD_BIOMES := [&"snowy_tundra", &"frostpine_taiga", &"stonecrown_mountains"]

var world: World
## event id -> world_time when it ends
var active: Dictionary = {}
## Meteor craters that haven't been mined: id -> [x, y, z]
var craters: Dictionary = {}
var last_blood_moon_day := -100
var _monsters: Array = []
var _horde_t := 5.0
var _goblin: Monster
var _goblin_t := 0.0
var _goblin_day := -1
var _meteor_at := -1.0
var _star_t := 0.0
var _crater_nodes: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if world and world.day_night:
		world.day_night.hour_changed.connect(_on_hour)
	Events.enemy_killed.connect(_on_enemy_killed)


func is_active(id: StringName) -> bool:
	return active.has(id)


## Combat XP multiplier from events (blood moon +50%).
func xp_mult() -> float:
	return 1.5 if is_active(&"blood_moon") else 1.0


## Spell damage multiplier from events (aurora +15%).
func spell_mult() -> float:
	return 1.15 if is_active(&"aurora") else 1.0


## Extra elite chance for monsters spawned now.
func elite_bonus() -> float:
	return 0.15 if is_active(&"blood_moon") or is_active(&"eclipse") else 0.0


func _hours(h: float) -> float:
	return h / 24.0 * world.day_night.day_length


func _on_hour(h: int) -> void:
	if world == null or not world.is_ready:
		return
	var day := world.day_night.day
	_rng.seed = hash([GameState.world_seed, day, h, 91])
	var outside := world.layer == TerrainGenerator.Layer.SURFACE and world.dungeon == null
	match h:
		20:
			if day >= 4 and day - last_blood_moon_day > 1 and _rng.randf() < BLOOD_MOON_CHANCE:
				start(&"blood_moon")
		21:
			if day >= 2 and not is_active(&"blood_moon") and _rng.randf() < METEOR_CHANCE:
				start(&"meteor_shower")
			elif not is_active(&"blood_moon") and _in_cold_biome() and _rng.randf() < AURORA_CHANCE:
				start(&"aurora")
		12:
			if day >= 5 and outside and _rng.randf() < ECLIPSE_CHANCE:
				start(&"eclipse")
	if h >= 9 and h <= 17 and outside and _goblin_day != day and not is_active(&"treasure_goblin") and day >= 2 \
			and _rng.randf() < GOBLIN_CHANCE:
		start(&"treasure_goblin")


func _in_cold_biome() -> bool:
	return world.current_biome != null and world.current_biome.id in COLD_BIOMES


## Starts an event now (also used by tests and the F12 debug key). Returns false if it can't run.
func start(id: StringName) -> bool:
	if is_active(id) or world == null:
		return false
	match id:
		&"blood_moon":
			active[id] = GameState.world_time + _hours(fposmod(5.0 - world.day_night.hour, 24.0))
			last_blood_moon_day = world.day_night.day
			_horde_t = 8.0
			Events.toast.emit("The moon turns red... a Blood Moon rises. The dead will walk tonight.", Color(1, 0.3, 0.25))
		&"meteor_shower":
			active[id] = GameState.world_time + _hours(5.0)
			_meteor_at = GameState.world_time + _hours(_rng.randf_range(0.8, 3.0))
			Events.toast.emit("Shooting stars streak across the sky - a meteor shower!", Color(0.7, 0.8, 1.0))
		&"aurora":
			active[id] = GameState.world_time + _hours(6.0)
			world.player.stats.set_source(&"aurora", {Stats.MANA_REGEN: 2.0})
			Events.toast.emit("An aurora lights the sky. Your magic feels stronger.", Color(0.5, 1.0, 0.8))
		&"treasure_goblin":
			if not _spawn_goblin():
				return false
			active[id] = GameState.world_time + GOBLIN_TIME
			_goblin_day = world.day_night.day
			Events.toast.emit("You hear jingling coins... a Treasure Goblin! Catch it before it escapes!", UITheme.GOLD)
		&"eclipse":
			active[id] = GameState.world_time + _hours(2.0)
			_horde_t = 10.0
			Events.toast.emit("The sun goes dark - an eclipse! The dead stir.", Color(0.8, 0.6, 1.0))
		_:
			return false
	_apply_sky()
	Events.world_event_started.emit(id)
	return true


func stop(id: StringName) -> void:
	if not active.erase(id):
		return
	match id:
		&"aurora":
			world.player.stats.set_source(&"aurora", {})
		&"treasure_goblin":
			if _goblin and is_instance_valid(_goblin) and not _goblin.is_dead and _goblin.get_meta(&"event", &"") == &"goblin":
				VFX.burst(_goblin.get_parent(), _goblin.global_position + Vector3(0, 1, 0), 1.5, Color(1, 0.9, 0.3, 0.8))
				NodePool.release_or_free(_goblin)
				Events.toast.emit("The Treasure Goblin escaped with its loot!", Color(0.9, 0.8, 0.5))
			_goblin = null
		&"blood_moon", &"eclipse":
			if not is_active(&"blood_moon") and not is_active(&"eclipse"):
				_cleanup_monsters(30.0)
			Events.toast.emit("The %s is over." % NAMES[id], Color(0.85, 0.85, 0.9))
	_apply_sky()
	Events.world_event_ended.emit(id)


func _apply_sky() -> void:
	var dn := world.day_night
	if is_active(&"blood_moon"):
		dn.sky_tint = Color(0.75, 0.08, 0.06, 0.55)
	elif is_active(&"eclipse"):
		dn.sky_tint = Color(0.25, 0.15, 0.35, 0.5)
	elif is_active(&"aurora"):
		dn.sky_tint = Color(0.15, 0.85, 0.55, 0.4)
	else:
		dn.sky_tint = Color(0, 0, 0, 0)
	dn.eclipse = 0.85 if is_active(&"eclipse") else 0.0
	dn.advance_hours(0.0)


# --- Per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or not world.is_ready:
		return
	for id in active.keys():
		if GameState.world_time >= float(active[id]):
			stop(id)
	var outside := world.layer == TerrainGenerator.Layer.SURFACE and world.dungeon == null
	if (is_active(&"blood_moon") or is_active(&"eclipse")) and outside:
		_horde_t -= delta
		if _horde_t <= 0.0:
			_horde_t = HORDE_INTERVAL * (1.6 if is_active(&"eclipse") else 1.0)
			_spawn_horde()
	if is_active(&"meteor_shower") and outside:
		_star_t -= delta
		if _star_t <= 0.0:
			_star_t = randf_range(0.6, 1.8)
			_shooting_star()
		if _meteor_at > 0.0 and GameState.world_time >= _meteor_at:
			_meteor_at = -1.0
			drop_meteor()
	if is_active(&"treasure_goblin") and (_goblin == null or not is_instance_valid(_goblin) or _goblin.is_dead):
		active.erase(&"treasure_goblin")
		Events.world_event_ended.emit(&"treasure_goblin")


## A group of 2-3 undead 22-30 m from the player (never on claimed land or in towns).
func _spawn_horde() -> void:
	_monsters = _monsters.filter(func(m) -> bool: return is_instance_valid(m) and not m.is_dead and m.is_inside_tree() and m.get_meta(&"event", &"") == &"horde")
	if _monsters.size() >= MAX_EVENT_MONSTERS:
		return
	var p := world.player.global_position
	var a := _rng.randf() * TAU
	var c := p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(22.0, 30.0)
	if world.building.is_claimed(c) or world.generator.settlements.is_inside(floori(c.x), floori(c.z), 20.0):
		return
	if world.get_ground_height(c) < TerrainGenerator.WATER_Y + 0.3:
		return
	var tier := clampi((world.player.character.level - 1) / 6, 0, 5)
	for k in _rng.randi_range(2, 3):
		var pos := c + Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
		pos.y = world.get_ground_height(pos) + 0.4
		var data := load("res://data/enemies/%s.tres" % UNDEAD[_rng.randi() % mini(UNDEAD.size(), 3 + tier)]) as MonsterData
		var m := world.spawner.spawn_enemy(MONSTER_SCENE, pos, "", data) as Monster
		if m == null:
			continue
		m.configure(1.0 + 0.3 * tier, 1.0 + 0.15 * tier, 2 * tier, 1.0 + 0.25 * tier)
		if _rng.randf() < EliteAffixes.chance(tier, elite_bonus()):
			m.make_elite(EliteAffixes.roll(_rng, 1, data.style != MonsterData.Style.MELEE))
		m.leash_mult = 3.0
		m.set_meta(&"event", &"horde")
		_monsters.append(m)


func _cleanup_monsters(keep_within: float) -> void:
	var p := world.player.global_position
	for m in _monsters:
		if is_instance_valid(m) and not m.is_dead and m.is_inside_tree() and m.get_meta(&"event", &"") == &"horde" \
				and m.global_position.distance_to(p) > keep_within:
			NodePool.release_or_free(m)
	_monsters.clear()


func _spawn_goblin() -> bool:
	var p := world.player.global_position
	for k in 8:
		var a := _rng.randf() * TAU
		var pos := p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(16.0, 22.0)
		if world.get_ground_height(pos) < TerrainGenerator.WATER_Y + 0.3:
			continue
		pos.y = world.get_ground_height(pos) + 0.4
		var data := load("res://data/enemies/treasure_goblin.tres") as MonsterData
		_goblin = world.spawner.spawn_enemy(MONSTER_SCENE, pos, "", data) as Monster
		if _goblin:
			var tier := clampi((world.player.character.level - 1) / 6, 0, 5)
			_goblin.configure(1.0 + 0.4 * tier, 1.0, 2 * tier, 1.0 + 0.3 * tier)
			_goblin.leash_mult = 20.0
			_goblin.set_meta(&"event", &"goblin")
			_goblin_t = GOBLIN_TIME
			return true
	return false


func _on_enemy_killed(enemy: Node, _id: StringName, pos: Vector3) -> void:
	if enemy == _goblin and enemy.get_meta(&"event", &"") == &"goblin":
		var tier := clampi((world.player.character.level - 1) / 6, 0, 5)
		LootTables.give(LootTables.roll(&"treasure_goblin", tier, _rng), pos)
		Events.toast.emit("You caught the Treasure Goblin!", UITheme.GOLD)
		_goblin = null


func _shooting_star() -> void:
	var p := world.player.global_position
	var a := randf() * TAU
	var start := p + Vector3(cos(a) * 40.0, 45.0, sin(a) * 40.0 - 30.0)
	var end := start + Vector3(randf_range(-25, 25), -22.0, randf_range(10, 25))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.25, 2.5)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = start
	mi.look_at(end, Vector3.UP)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", end, 0.9)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)


## A meteor crashes 60-140 m from the player. Returns the crater.
func drop_meteor(at: Vector3 = Vector3.INF) -> MeteorCrater:
	var p := world.player.global_position
	var pos := at
	if pos == Vector3.INF:
		for k in 12:
			var a := _rng.randf() * TAU
			pos = p + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(60.0, 140.0)
			if world.get_ground_height(pos) > TerrainGenerator.WATER_Y + 0.5 and not world.generator.settlements.is_inside(floori(pos.x), floori(pos.z), 15.0) \
					and not world.building.is_claimed(pos):
				break
	pos.y = world.get_ground_height(pos)
	var id := "meteor:%d,%d" % [floori(pos.x), floori(pos.z)]
	craters[id] = [pos.x, pos.y, pos.z]
	var c := _make_crater(id, pos)
	Events.camera_shake.emit(0.5)
	Events.toast.emit("A meteor crashed %s to the %s! It's on your map." % [Gossip.distance_text(Vector2(pos.x - p.x, pos.z - p.z).length()), Gossip.direction(p, pos)],
		Color(0.7, 0.8, 1.0))
	if _rng.randf() < COLOSSUS_CHANCE:
		spawn_colossus(pos)
	return c


func spawn_colossus(pos: Vector3) -> Monster:
	var data := load("res://data/enemies/starborn_colossus.tres") as MonsterData
	var spot := pos + Vector3(4.0, 0.4, 0)
	spot.y = world.get_ground_height(spot) + 0.4
	var m := world.spawner.spawn_enemy(MONSTER_SCENE, spot, "", data) as Monster
	if m:
		var tier := clampi((world.player.character.level - 1) / 6, 0, 5)
		m.configure(1.0 + 0.25 * tier, 1.0 + 0.1 * tier, 2 * tier, 1.0 + 0.2 * tier)
		m.leash_mult = 1.5
		m.make_dormant(14.0)
		m.set_meta(&"event", &"colossus")
		Events.toast.emit("Something enormous stirs in the crater...", Color(0.75, 0.8, 1.0))
	return m


func _make_crater(id: String, pos: Vector3) -> MeteorCrater:
	var c := MeteorCrater.new()
	c.crater_id = id
	world.add_child(c)
	c.global_position = pos
	c.mined.connect(func(cr: MeteorCrater) -> void:
		craters.erase(cr.crater_id))
	_crater_nodes[id] = c
	return c


## Craters are only kept in the world while on the surface (rebuilt from save data).
func refresh_craters() -> void:
	for id in _crater_nodes.keys():
		var n: MeteorCrater = _crater_nodes[id]
		if not is_instance_valid(n) or not craters.has(id):
			_crater_nodes.erase(id)
			if is_instance_valid(n):
				n.queue_free()
	for id in craters:
		if not _crater_nodes.has(id):
			var a: Array = craters[id]
			_make_crater(id, Vector3(float(a[0]), float(a[1]), float(a[2])))
	var surface := world.layer == TerrainGenerator.Layer.SURFACE and world.dungeon == null
	for id in _crater_nodes:
		var n: MeteorCrater = _crater_nodes[id]
		n.visible = surface
		n.process_mode = Node.PROCESS_MODE_INHERIT if surface else Node.PROCESS_MODE_DISABLED
		n.collision_layer = (Layers.INTERACTABLE | Layers.PROP) if surface else 0


## One-line HUD status for active events.
func status_text() -> String:
	var parts := PackedStringArray()
	for id in active:
		var left := float(active[id]) - GameState.world_time
		if id == &"treasure_goblin":
			parts.append("Treasure Goblin! %ds" % ceili(left))
		else:
			parts.append(NAMES.get(id, String(id)))
	return " · ".join(parts)


# --- Save ---------------------------------------------------------------------------------

func to_save() -> Dictionary:
	var act := {}
	for id in active:
		if id != &"treasure_goblin":
			act[String(id)] = float(active[id]) - GameState.world_time
	return {"active": act, "craters": craters.duplicate(true), "last_blood_moon": last_blood_moon_day,
		"meteor_in": (_meteor_at - GameState.world_time) if _meteor_at > 0.0 else -1.0}


func from_save(d: Dictionary) -> void:
	craters = d.get("craters", {}).duplicate(true)
	last_blood_moon_day = int(d.get("last_blood_moon", -100))
	active = {}
	var act: Dictionary = d.get("active", {})
	for id in act:
		active[StringName(id)] = GameState.world_time + float(act[id])
	var mi := float(d.get("meteor_in", -1.0))
	_meteor_at = GameState.world_time + mi if mi >= 0.0 else -1.0
	if is_active(&"aurora") and world:
		world.player.stats.set_source(&"aurora", {Stats.MANA_REGEN: 2.0})
	if world:
		_apply_sky()
