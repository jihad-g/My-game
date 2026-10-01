class_name ExplorationManager
extends Node3D
## Runs points of interest (Milestone 6): streams PoiSites around the player,
## discovery (hidden groves stay off the map until found), and the persistent
## exploration state (opened chests, broken vaults, cleansed temples, read
## tomes, picked plants, dungeon clears).

const SPAWN_RANGE := 140.0
const DESPAWN_RANGE := 190.0
## Cleared dungeons repopulate after this much world time (3 in-game days).
const DUNGEON_RESET := 3600.0

var world: World
var sites: Dictionary = {}   # poi id -> PoiSite
## key -> world_time
var state: Dictionary = {}
var current: PoiInfo
var _tick := 0.0


func pois() -> Exploration:
	return world.generator.pois


func has_state(key: String) -> bool:
	return state.has(key)


func get_state(key: String, default: float = 0.0) -> float:
	return float(state.get(key, default))


func set_state(key: String, value: float = -1.0) -> void:
	state[key] = GameState.world_time if value < 0.0 else value


func is_discovered(id: String) -> bool:
	return GameState.discovered_places.has("poi:%s" % id)


func _process(delta: float) -> void:
	if world == null or world.player == null or not world.is_ready:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.4
	update_now()


func update_now(spawn_all: bool = false) -> void:
	var p := world.player.global_position
	if world.layer != TerrainGenerator.Layer.SURFACE or world.dungeon != null:
		for id in sites.keys():
			_free(id)
		current = null
		return
	var near := pois().near(p, SPAWN_RANGE)
	var spawned := 0
	for poi in near:
		if not sites.has(poi.id) and (spawn_all or spawned == 0):
			var site := PoiSite.new()
			site.setup(poi, self)
			add_child(site)
			sites[poi.id] = site
			spawned += 1
	for id in sites.keys():
		if (sites[id] as PoiSite).poi.distance_to(p) > DESPAWN_RANGE:
			_free(id)
	var inside: PoiInfo = null
	for poi in near:
		if poi.contains(p, 8.0):
			inside = poi
			break
	if inside != current:
		current = inside
		if inside and GameState.discover_place("poi:%s" % inside.id):
			_on_discovered(inside)


func _free(id: String) -> void:
	var s: PoiSite = sites[id]
	sites.erase(id)
	s.queue_free()


func _on_discovered(poi: PoiInfo) -> void:
	var xp := 120 if poi.is_hidden() else 30 + poi.rank * 10
	world.player.character.grant_xp(xp, Progression.Source.DISCOVERY)
	if poi.is_hidden():
		Events.toast.emit("You found a hidden place: %s!" % poi.title(), UITheme.GOLD)
	else:
		Events.toast.emit("Discovered: %s" % poi.title(), UITheme.GOLD)
	Events.poi_discovered.emit(poi.id)


func site_of(poi: PoiInfo) -> PoiSite:
	return sites.get(poi.id)


func finish_sites() -> void:
	pass  # POI sites build synchronously


## Dungeon state: cleared and when it repopulates.
func dungeon_cleared_left(poi: PoiInfo) -> float:
	if not has_state("dungeon:" + poi.id):
		return 0.0
	return maxf(0.0, DUNGEON_RESET - (GameState.world_time - get_state("dungeon:" + poi.id)))


func entrance_text(poi: PoiInfo) -> String:
	var left := dungeon_cleared_left(poi)
	if left > 0.0:
		return "Enter %s (cleared - the dead stir again in %d h)" % [poi.title(), ceili(left / 50.0)]
	return "Enter %s" % poi.title()


func to_save() -> Dictionary:
	return {"state": state.duplicate()}


func from_save(d: Dictionary) -> void:
	state = d.get("state", {}).duplicate()
