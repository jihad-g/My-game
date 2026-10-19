class_name TravelManager
extends Node3D
## Travel (Milestone 29): waystones, wild horse herds and the whistle.
##
## Waystones stand in every village and capital (on the plaza) and in front of
## every dungeon entrance. They appear when you come near; touching one unlocks
## it for good (saved). From any unlocked waystone you can travel to another one
## for TRAVEL_BASE + 1 coin per TRAVEL_METRES_PER_COIN metres (at most TRAVEL_MAX;
## free in Creative mode).
##
## Wild horses live in herds of 2-3 on meadows and in forests: one possible herd
## per HERD_CELL metres. A tamed horse leaves its herd for good (`herds_taken`).

const TRAVEL_BASE := 3
const TRAVEL_METRES_PER_COIN := 120.0
const TRAVEL_MAX := 40
const WAYSTONE_RANGE := 150.0
const HERD_CELL := 192
const HERD_RANGE := 120.0
const HERD_CHANCE := 0.45
const HERD_BIOMES := [&"verdant_meadow", &"whispering_forest", &"sandy_beach"]
## Settlement plazas: the waystone stands here (from the centre; free of the well, stalls and benches).
const PLAZA_OFFSET := Vector3(3.0, 0, -3.0)
## Dungeon entrances: in front of the arch, between the braziers.
const DUNGEON_OFFSET := Vector3(0, 0, 4.6)

var world: World
## key -> {"title": String, "pos": [x, y, z]}
var unlocked: Dictionary = {}
## Herd slot keys whose horse was tamed ("x,z:i").
var herds_taken: Dictionary = {}
## Spawned waystones and wild horses near the player.
var _stones: Dictionary = {}
var _herds: Dictionary = {}
var _tick := 0.0


func _process(delta: float) -> void:
	if world == null or not world.is_ready or world.player == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	update_now()


## Spawns the waystones and herds near the player now (and frees far ones).
func update_now() -> void:
	var surface := world.layer == TerrainGenerator.Layer.SURFACE and world.dungeon == null
	var p := world.player.global_position
	_update_stones(p, surface)
	_update_herds(p, surface)


# --- Waystones ------------------------------------------------------------------------

## All waystone spots within `range_m` of `pos`: [key, title, position].
func spots_near(pos: Vector3, range_m: float) -> Array:
	var out := []
	if world.living:
		for s in world.living.settlements().near(pos, range_m):
			var q: Vector3 = s.world_center() + PLAZA_OFFSET
			q.y = s.ground_y()
			out.append(["s:" + s.id, s.name, q])
	if world.exploration:
		for poi in world.exploration.pois().near(pos, range_m):
			if poi.kind != PoiInfo.Kind.DUNGEON:
				continue
			var q: Vector3 = poi.world_center() + DUNGEON_OFFSET
			q.y = poi.ground_y()
			out.append(["d:" + poi.id, poi.title(), q])
	return out


func _update_stones(p: Vector3, surface: bool) -> void:
	var want := {}
	if surface:
		for spot in spots_near(p, WAYSTONE_RANGE):
			want[spot[0]] = spot
	for k in _stones.keys():
		if not want.has(k) or not is_instance_valid(_stones[k]):
			if is_instance_valid(_stones[k]):
				_stones[k].queue_free()
			_stones.erase(k)
	for k in want:
		if _stones.has(k):
			continue
		var spot: Array = want[k]
		var ws := Waystone.new()
		ws.setup(spot[0], spot[1])
		add_child(ws)
		var q: Vector3 = spot[2]
		q.y = maxf(q.y, world.get_ground_height(q))
		ws.global_position = q
		_stones[k] = ws


func waystone(key: String) -> Waystone:
	var w = _stones.get(key)
	return w if is_instance_valid(w) else null


func is_unlocked(key: String) -> bool:
	return unlocked.has(key)


func unlock(key: String, title: String, pos: Vector3) -> void:
	if unlocked.has(key):
		return
	unlocked[key] = {"title": title, "pos": [pos.x, pos.y, pos.z]}


func position_of(key: String) -> Vector3:
	var a: Array = unlocked.get(key, {}).get("pos", [0, 0, 0])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func travel_cost(from: Vector3, to_key: String) -> int:
	if world.player and world.player.creative:
		return 0
	var d := Vector2(from.x, from.z).distance_to(Vector2(position_of(to_key).x, position_of(to_key).z))
	return clampi(TRAVEL_BASE + int(d / TRAVEL_METRES_PER_COIN), TRAVEL_BASE, TRAVEL_MAX)


## Unlocked waystones, nearest first: [{key, title, cost, distance}].
func destinations(from: Vector3, except_key: String = "") -> Array:
	var out := []
	for k in unlocked:
		if k == except_key:
			continue
		var q := position_of(k)
		out.append({"key": k, "title": String(unlocked[k].title), "cost": travel_cost(from, k),
			"distance": Vector2(from.x, from.z).distance_to(Vector2(q.x, q.z))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	return out


## Travels to an unlocked waystone. Returns "" or why not.
func travel(to_key: String) -> String:
	var p := world.player
	if p == null or p.is_dead:
		return "You can't travel now"
	if not unlocked.has(to_key):
		return "That waystone isn't unlocked"
	if world.dungeon or world.layer != TerrainGenerator.Layer.SURFACE:
		return "Waystones only work on the surface"
	if Net.is_online():
		return "Waystones don't work in co-op yet"
	var cost := travel_cost(p.global_position, to_key)
	if p.coins < cost:
		return "You need %d coins" % cost
	p.coins -= cost
	Events.coins_changed.emit(p.coins)
	# Your horse comes with you (a boat stays where it is).
	var horse: Horse = p.mount as Horse
	p.stop_riding(false, true)
	var dest := position_of(to_key) + Vector3(0, 0, 1.6)
	Audio.play(&"teleport", -2.0)
	Audio.play(&"waystone", -6.0)  # Milestone 37: the stone's hum as you arrive
	VFX.motes(world, p.global_position + Vector3(0, 1, 0), Color(0.45, 0.85, 1.0), 24, 0.8)
	world.teleport_to(dest)
	if horse:
		var hq := dest + Vector3(2.0, 0, 0.5)
		hq.y = world.get_ground_height(hq) + 0.2
		horse.global_position = hq
		horse.velocity = Vector3.ZERO
		horse.on_dismounted(hq, 0.0)
	Events.toast.emit("You travel to %s%s" % [String(unlocked[to_key].title), "" if cost == 0 else " (%d coins)" % cost],
		Color(0.6, 0.9, 1.0))
	return ""


# --- Wild horses ------------------------------------------------------------------------

## Herd cells around `pos` that have a herd: [cell key, centre, count].
func herds_near(pos: Vector3, range_m: float) -> Array:
	var out := []
	var c0 := Vector2i(floori(pos.x / HERD_CELL), floori(pos.z / HERD_CELL))
	var reach := ceili(range_m / HERD_CELL) + 1
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := c0 + Vector2i(dx, dz)
			var h := HashUtils.hash3(GameState.world_seed, c.x, c.y * 7919 + 0x40125)
			if HashUtils.to_unit(h, 0) > HERD_CHANCE:
				continue
			var centre := Vector3((c.x + 0.2 + HashUtils.to_unit(h, 1) * 0.6) * HERD_CELL, 0,
				(c.y + 0.2 + HashUtils.to_unit(h, 2) * 0.6) * HERD_CELL)
			if Vector2(centre.x - pos.x, centre.z - pos.z).length() > range_m:
				continue
			var biome := world.generator.get_biome_at(centre)
			if not biome.id in HERD_BIOMES:
				continue
			if world.generator.get_height_at(centre) < TerrainGenerator.WATER_Y + 0.5:
				continue
			if world.living and world.living.settlements().is_inside(int(centre.x), int(centre.z), 20.0):
				continue
			centre.y = world.generator.get_height_at(centre)
			out.append(["%d,%d" % [c.x, c.y], centre, 2 + int(HashUtils.to_unit(h, 3) * 2.0)])
	return out


func _update_herds(p: Vector3, surface: bool) -> void:
	var want := {}
	if surface:
		for herd in herds_near(p, HERD_RANGE):
			want[herd[0]] = herd
	for k in _herds.keys():
		if not want.has(k):
			for h in _herds[k]:
				if is_instance_valid(h) and not h.tame and h.get_parent() == self:
					h.queue_free()
			_herds.erase(k)
	for k in want:
		if _herds.has(k):
			continue
		var herd: Array = want[k]
		var list := []
		for i in int(herd[2]):
			var slot := "%s:%d" % [k, i]
			if herds_taken.has(slot):
				continue
			var a := TAU * i / 3.0
			var q: Vector3 = herd[1] + Vector3(cos(a) * 3.0, 0, sin(a) * 3.0)
			q.y = world.get_ground_height(q) + 0.2
			var horse := (load(Horse.SCENE_PATH) as PackedScene).instantiate() as Horse
			horse.setup_wild(hash(slot), q, slot)
			add_child(horse)
			horse.global_position = q
			horse.home = q
			list.append(horse)
		_herds[k] = list


func mark_herd_taken(slot: String) -> void:
	herds_taken[slot] = true


## The player's tame horses.
func tame_horses() -> Array:
	var out := []
	for h in get_tree().get_nodes_in_group(&"horses"):
		if h.tame:
			out.append(h)
	return out


## Whistle (H): the nearest tame horse comes running. Returns the horse or null.
func whistle() -> Horse:
	var p := world.player
	if p == null:
		return null
	var best: Horse = null
	for h: Horse in tame_horses():
		if h.rider == null and (best == null or h.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
			best = h
	Audio.play(&"notify", -4.0)
	if best == null:
		Events.toast.emit("You whistle, but you have no horse (tame a wild one with carrots or wheat)", Color(1, 0.85, 0.55))
		return null
	if not best.call_to(p):
		Events.toast.emit("%s is too far away to hear you (%.0f m)" % [best.horse_name, best.global_position.distance_to(p.global_position)],
			Color(1, 0.85, 0.55))
		return null
	Events.toast.emit("%s is coming" % best.horse_name, Color(0.8, 1, 0.7))
	return best


# --- Save ------------------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"unlocked": unlocked.duplicate(true), "herds_taken": herds_taken.keys()}


func from_save(d: Dictionary) -> void:
	unlocked = (d.get("unlocked", {}) as Dictionary).duplicate(true)
	herds_taken.clear()
	for k in d.get("herds_taken", []):
		herds_taken[String(k)] = true
	for ws in _stones.values():
		if is_instance_valid(ws):
			ws.refresh()
