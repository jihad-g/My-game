class_name World
extends Node3D
## Root of the game world scene. Wires systems together and offers world-level
## services: ground height, temperature, water, pickups, placing objects,
## travelling between layers, and saving/loading world state.
##
## Systems stay independent: ChunkManager streams terrain, EnemySpawner reacts
## to chunk signals, the HUD reads the player, etc. World only connects them.

static var instance: World

const FIRE_MAX_TEMPERATURE := 28.0
## Degrees of protection from standing under a roof.
const SHELTER_EFFECT := 10.0
## Coins (copper) a new character starts with.
const STARTING_COINS := 40
const AUTOSAVE_INTERVAL := 120.0
const BIOME_CHECK_INTERVAL := 0.5
## Debug (F10): a sample of every gear tier for testing equipment.
const DEBUG_GEAR: Array[StringName] = [&"iron_sword", &"iron_waraxe", &"copper_dagger", &"crystal_staff",
	&"iron_kite_shield", &"chainmail", &"fur_cap", &"fur_boots", &"copper_ring", &"tusk_charm", &"sun_hat"]

signal layer_changed(layer: int)
signal biome_changed(biome: BiomeData)

@export var worldgen: WorldGenSettings
@export var starting_items: Dictionary = {&"berries": 6, &"campfire_kit": 2}
@export var debug_enemy_scene: PackedScene

@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var day_night: DayNightCycle = $DayNightCycle
@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HUD = $HUD
@onready var pickup_pool: NodePool = $PickupPool
@onready var placed_root: Node3D = $Placed

var generator: TerrainGenerator
var props: PropLibrary
## Current layer the player is on (TerrainGenerator.Layer).
var layer: int = TerrainGenerator.Layer.SURFACE
## Added to air temperature (debug keys F6/F7) to test cold/heat effects.
var debug_temperature_offset: float = 0.0
## True once the terrain around the player is generated.
var is_ready: bool = false
var current_biome: BiomeData

var building: BuildingManager
var build_mode: BuildMode
## Villages, kingdoms, NPCs, shops, requests (Milestone 5).
var living: SettlementManager
## Ruins, towers, temples, dungeon entrances, groves (Milestone 6).
var exploration: ExplorationManager
## The dungeon floor the player is in (null on the surface/caves).
var dungeon: DungeonInstance
var _autosave_left := AUTOSAVE_INTERVAL
var _biome_check_left := 0.0
var _first_ready := true
var _new_world := true


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	generator = TerrainGenerator.new(GameState.world_seed, worldgen)
	building = BuildingManager.new()
	building.name = "Buildings"
	building.world = self
	add_child(building)
	build_mode = BuildMode.new()
	build_mode.name = "BuildMode"
	build_mode.world = self
	add_child(build_mode)
	living = SettlementManager.new()
	living.name = "Settlements"
	living.world = self
	add_child(living)
	exploration = ExplorationManager.new()
	exploration.name = "Exploration"
	exploration.world = self
	add_child(exploration)
	props = PropLibrary.new()
	chunk_manager.setup(generator, props)
	spawner.generator = generator
	player.camera_rig = camera_rig
	player.temperature.ambient_provider = func() -> float: return get_temperature_at(player.global_position)
	player.respawned.connect(_on_player_respawned)

	var save := SaveManager.pending
	SaveManager.pending = {}
	var player_save: Dictionary = save.get("player", {})
	var class_id := StringName((player_save.get("character", {}) as Dictionary).get("class", SaveManager.new_character_class))
	player.setup_class(ClassRegistry.get_class_data(class_id), save.is_empty())
	if save.is_empty():
		var col := generator.find_spawn_column(Vector2i.ZERO)
		var ground := generator.get_height_blocks(col.x, col.y) * TerrainGenerator.BLOCK_HEIGHT
		player.spawn_point = Vector3(col.x + 0.5, ground + 0.3, col.y + 0.5)
		player.global_position = player.spawn_point
		for id: StringName in starting_items:
			player.inventory.add_item(id, int(starting_items[id]))
		player.coins = STARTING_COINS
	else:
		_new_world = false
		from_save(save.get("world", {}))
		player.from_save(save.get("player", {}))
		building.from_save(save.get("world", {}).get("buildings", []))

	chunk_manager.layer = layer
	player.frozen = true
	camera_rig.target = player
	camera_rig.snap_to_target()
	chunk_manager.focus = player
	hud.bind(player, self)
	hud.set_loading(true, "Generating world...\nSeed: %d" % GameState.world_seed)
	_apply_layer_environment()


func _process(delta: float) -> void:
	if not is_ready and chunk_manager.is_near_area_ready():
		_on_area_ready()
	if not is_ready:
		return
	_biome_check_left -= delta
	if _biome_check_left <= 0.0:
		_biome_check_left = BIOME_CHECK_INTERVAL
		_update_biome()
	if SaveManager.is_persistent():
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			save_now(false)


func _on_area_ready() -> void:
	is_ready = true
	# Place the player exactly on the generated ground before unfreezing.
	var p := player.global_position
	var ground := get_ground_height(p)
	if p.y < ground + 0.1 or p.y > ground + 3.0 or not _first_ready:
		p.y = ground + 0.3
		if is_deep_water(p):
			p.y = TerrainGenerator.WATER_Y - 1.0
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.temperature.snap_to_ambient()
	player.frozen = false
	hud.set_loading(false)
	_update_biome()
	if _first_ready:
		_first_ready = false
		if _new_world:
			Events.toast.emit("A new world awaits. Seed %d" % GameState.world_seed, Color(0.8, 1.0, 0.7))
			if SaveManager.is_persistent():
				save_now(false)
		else:
			Events.toast.emit("Welcome back", Color(0.8, 1.0, 0.7))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_ready and SaveManager.is_persistent():
		save_now(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_ready:
		return
	if event.is_action_pressed(&"debug_temp_down"):
		debug_temperature_offset -= 10.0
		Events.toast.emit("Debug: air temperature offset %+d°C" % roundi(debug_temperature_offset), Color(0.6, 0.8, 1))
	elif event.is_action_pressed(&"debug_temp_up"):
		debug_temperature_offset += 10.0
		Events.toast.emit("Debug: air temperature offset %+d°C" % roundi(debug_temperature_offset), Color(1, 0.7, 0.5))
	elif event.is_action_pressed(&"debug_spawn_enemy"):
		debug_spawn_enemy()
	elif event.is_action_pressed(&"debug_time_skip"):
		day_night.advance_hours(2.0)
		Events.toast.emit("Debug: +2 hours (%s)" % day_night.time_string(), Color(0.9, 0.9, 1))
	elif event.is_action_pressed(&"quick_save"):
		save_now(true)
	elif event.is_action_pressed(&"debug_give_gear"):
		for id in DEBUG_GEAR:
			player.give_item(id, 1)
	elif event.is_action_pressed(&"debug_give_xp"):
		player.character.grant_xp(player.character.xp_needed(), Progression.Source.OTHER)


# --- Layers (surface / underground) ---------------------------------------------------

## Moves the player to the other layer at the same XZ position (cave passages).
func travel_to_layer(target_layer: int, at: Vector3) -> void:
	if not is_ready:
		return  # already travelling / still loading
	is_ready = false
	player.frozen = true
	player.set_lock_target(null)
	spawner.despawn_all()
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Enemy and e.visible:
			NodePool.release_or_free(e)
	pickup_pool.release_all()
	layer = target_layer
	chunk_manager.set_layer(target_layer)
	if target_layer == TerrainGenerator.Layer.UNDERGROUND:
		var key := "cave:%d,%d" % [floori(at.x), floori(at.z)]
		if GameState.discover_place(key):
			Events.toast.emit("Discovered a new cave", Color(1.0, 0.85, 0.4))
			Events.place_discovered.emit(key)
	# Step off the passage so we don't land inside it.
	var dest := Vector3(at.x + 1.8, 0.0, at.z + 0.6)
	dest.y = get_ground_height(dest) + 0.3
	player.global_position = dest
	camera_rig.snap_to_target()
	hud.set_loading(true, "Descending into the Deeps..." if target_layer == TerrainGenerator.Layer.UNDERGROUND
		else "Climbing to the surface...")
	_apply_layer_environment()
	building.refresh_layer()
	build_mode.set_active(false)
	layer_changed.emit(layer)


# --- Dungeons (Milestone 6) --------------------------------------------------------------

## Enters a dungeon from its entrance on the surface.
func enter_dungeon(poi: PoiInfo) -> bool:
	if dungeon or not is_ready or layer != TerrainGenerator.Layer.SURFACE:
		return false
	var left := exploration.dungeon_cleared_left(poi)
	if left > 0.0:
		Events.toast.emit("%s lies empty. Its dead stir again in %d hours." % [poi.title(), ceili(left / 50.0)], Color(0.85, 0.85, 0.85))
		return false
	_load_dungeon_floor(poi, 0, player.global_position + Vector3(0, 0.3, 2.5))
	Events.toast.emit("Entered %s" % poi.title(), Color(1.0, 0.8, 0.5))
	return true


func next_dungeon_floor() -> void:
	if dungeon == null:
		return
	var poi := dungeon.poi
	var f := dungeon.floor_index + 1
	var ret := dungeon.return_position
	_load_dungeon_floor(poi, f, ret)
	Events.toast.emit("Floor %d of %d" % [f + 1, dungeon.plan.floor_count], Color(1.0, 0.8, 0.5))


func _load_dungeon_floor(poi: PoiInfo, floor_index: int, ret: Vector3) -> void:
	player.set_lock_target(null)
	if dungeon:
		dungeon.queue_free()
		remove_child(dungeon)
	else:
		spawner.despawn_all()
		spawner.set_process(false)
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Enemy and e.visible:
				NodePool.release_or_free(e)
		pickup_pool.release_all()
		chunk_manager.process_mode = Node.PROCESS_MODE_DISABLED
		chunk_manager.visible = false
	dungeon = DungeonInstance.new()
	dungeon.setup(poi, floor_index, ret)
	add_child(dungeon)
	living.update_now()
	exploration.update_now()
	player.global_position = dungeon.start_position()
	player.velocity = Vector3.ZERO
	camera_rig.snap_to_target()
	_apply_layer_environment()
	Events.dungeon_entered.emit(poi.id, floor_index)


## Leaves the dungeon (portal, death). `to` defaults to the entrance.
func exit_dungeon(to: Vector3 = Vector3.INF) -> void:
	if dungeon == null:
		return
	var poi := dungeon.poi
	var cleared := dungeon.cleared
	var dest := dungeon.return_position if to == Vector3.INF else to
	dungeon.queue_free()
	remove_child(dungeon)
	dungeon = null
	pickup_pool.release_all()
	chunk_manager.process_mode = Node.PROCESS_MODE_INHERIT
	chunk_manager.visible = true
	spawner.set_process(true)
	is_ready = false
	player.frozen = true
	player.global_position = dest
	camera_rig.snap_to_target()
	hud.set_loading(true, "Returning to the surface...")
	_apply_layer_environment()
	Events.dungeon_left.emit(poi.id, cleared)


func _apply_layer_environment() -> void:
	var underground := layer == TerrainGenerator.Layer.UNDERGROUND or dungeon != null
	day_night.underground = underground
	day_night.advance_hours(0.0)  # re-apply lighting now
	player.set_lantern(underground)


func _on_player_respawned() -> void:
	if dungeon:
		exit_dungeon(player.spawn_point)
		Events.toast.emit("You were carried out of the dungeon...", Color(1, 0.7, 0.5))
		return
	if layer != TerrainGenerator.Layer.SURFACE:
		travel_to_layer(TerrainGenerator.Layer.SURFACE, player.spawn_point - Vector3(1.8, 0, 0.6))


func _update_biome() -> void:
	if dungeon:
		return
	var b := generator.get_biome_at(player.global_position, layer)
	if b == current_biome:
		return
	current_biome = b
	biome_changed.emit(b)
	if GameState.discover_biome(b.id):
		Events.toast.emit("Discovered: %s" % b.display_name, Color(1.0, 0.85, 0.4))
		Events.biome_discovered.emit(b.id)


# --- World services -------------------------------------------------------------------

func get_ground_height(pos: Vector3) -> float:
	if dungeon:
		return dungeon.floor_y()
	return generator.get_height_at(pos, layer)


## Air temperature from climate fields, time of day, altitude and water.
## Continuous across biome borders. Caves keep a steady, mild temperature.
func get_air_temperature(pos: Vector3) -> float:
	if layer == TerrainGenerator.Layer.UNDERGROUND or dungeon:
		return worldgen.cave_temperature + debug_temperature_offset
	var climate := generator.get_climate(pos)
	var t := climate.x + day_night.get_temperature_factor() * climate.y
	t -= maxf(0.0, pos.y - 2.0) * worldgen.altitude_lapse
	if is_in_water(pos):
		t -= 5.0  # wet and chilled while wading or swimming
	return t + debug_temperature_offset


## Extra warmth from nearby heat sources (campfires; later forges, lava, magic).
func get_heat_at(pos: Vector3) -> float:
	var total := 0.0
	for source in get_tree().get_nodes_in_group(&"heat_sources"):
		if source.has_method("heat_at"):
			total += source.heat_at(pos)
	return total


## Air plus local heat. A fire warms you up to FIRE_MAX_TEMPERATURE at most:
## it counters cold, but standing in it on a hot day doesn't cook you.
func get_temperature_at(pos: Vector3) -> float:
	var air := get_air_temperature(pos)
	# Shelter: under a roof you are protected by SHELTER_EFFECT degrees.
	if building and building.is_sheltered(pos):
		if air < TemperatureComponent.COMFORT_MIN:
			air = minf(air + SHELTER_EFFECT, TemperatureComponent.COMFORT_MIN)
		elif air > TemperatureComponent.COMFORT_MAX:
			air = maxf(air - SHELTER_EFFECT, TemperatureComponent.COMFORT_MAX)
	var heat := get_heat_at(pos)
	if heat <= 0.0 or air >= FIRE_MAX_TEMPERATURE:
		return air
	return minf(air + heat, FIRE_MAX_TEMPERATURE)


## Beds: set the respawn point; at night (and with no enemies close) sleep until morning.
func use_bed(bed: Node3D, _who: Node) -> void:
	player.spawn_point = bed.global_position + Vector3(0, 0.7, 1.2)
	if not day_night.is_night():
		Events.toast.emit("Respawn point set. You can only sleep at night.", Color(0.8, 0.9, 1.0))
		return
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Enemy and e.visible and not e.is_dead and e.global_position.distance_to(player.global_position) < 20.0:
			Events.toast.emit("You can't sleep with enemies nearby!", Color(1, 0.6, 0.5))
			return
	var hours := fposmod(7.0 - day_night.hour, 24.0)
	day_night.advance_hours(hours)
	GameState.world_time += hours / 24.0 * day_night.day_length
	player.stamina.refill()
	player.health.heal(player.health.max_health * 0.5)
	player.hunger.eat(-10.0)
	Events.toast.emit("You slept until morning. Respawn point set.", Color(0.8, 0.9, 1.0))


func is_in_water(pos: Vector3) -> bool:
	return layer == TerrainGenerator.Layer.SURFACE and pos.y < TerrainGenerator.WATER_Y - 0.25 \
		and not get_biome_at(pos).frozen_water


## Water too deep to stand in (you swim).
func is_deep_water(pos: Vector3) -> bool:
	return layer == TerrainGenerator.Layer.SURFACE and get_ground_height(pos) < TerrainGenerator.WATER_Y - 1.3 \
		and not get_biome_at(pos).frozen_water


func get_biome_at(pos: Vector3) -> BiomeData:
	return generator.get_biome_at(pos, layer)


func spawn_pickup(item_id: StringName, count: int, pos: Vector3, auto_collect: bool = true) -> Pickup:
	var p := pickup_pool.acquire() as Pickup
	if p == null:
		return null
	var ground := get_ground_height(pos)
	if layer == TerrainGenerator.Layer.SURFACE:
		ground = maxf(ground, TerrainGenerator.WATER_Y - 1.0)
	p.setup(item_id, count, pos, ground, auto_collect)
	return p


## Places a scene (campfire, later buildings) on the ground at `pos`.
func place_object(scene: PackedScene, pos: Vector3) -> Node3D:
	if scene == null:
		return null
	var ground := get_ground_height(pos)
	if layer == TerrainGenerator.Layer.SURFACE and ground < TerrainGenerator.WATER_Y:
		Events.toast.emit("Can't place that in water", Color(1, 0.6, 0.5))
		return null
	var node := scene.instantiate() as Node3D
	placed_root.add_child(node)
	node.global_position = Vector3(pos.x, ground, pos.z)
	return node


func debug_spawn_enemy() -> Enemy:
	if debug_enemy_scene == null:
		return null
	var pos := player.global_position + player.get_facing() * 8.0
	pos.y = get_ground_height(pos) + 0.5
	var e := spawner.spawn_enemy(debug_enemy_scene, pos, "")
	if e:
		Events.toast.emit("Debug: spawned %s" % e.display_name(), Color(1, 0.8, 0.6))
	return e


# --- Save / load -------------------------------------------------------------------------

## Saves the world if it is persistent. `notify` shows a toast.
func save_now(notify: bool = true) -> bool:
	_autosave_left = AUTOSAVE_INTERVAL
	if not SaveManager.is_persistent():
		if notify:
			Events.toast.emit("This world is temporary (quick play) - it can't be saved", Color(1, 0.7, 0.5))
		return false
	var ok := SaveManager.save_world(self)
	if notify or not ok:
		Events.toast.emit("World saved" if ok else "Saving FAILED - see log", Color(0.7, 1, 0.7) if ok else Color(1, 0.4, 0.4))
	return ok


func to_save() -> Dictionary:
	var placed := []
	for node in placed_root.get_children():
		if node is Node3D and node.scene_file_path != "" and not node.is_queued_for_deletion():
			var entry := {
				"scene": node.scene_file_path,
				"position": _vec_to_array(node.global_position),
				"rotation_y": node.rotation.y,
			}
			if node.has_method("save_data"):
				entry["data"] = node.save_data()
			placed.append(entry)
	return {
		"buildings": building.to_save(),
		"living": living.to_save(),
		"exploration": exploration.to_save(),
		"layer": layer,
		"day": day_night.day,
		"hour": day_night.hour,
		"placed": placed,
	}


func from_save(data: Dictionary) -> void:
	layer = int(data.get("layer", TerrainGenerator.Layer.SURFACE))
	living.from_save(data.get("living", {}))
	exploration.from_save(data.get("exploration", {}))
	day_night.day = int(data.get("day", 1))
	day_night.hour = float(data.get("hour", day_night.start_hour))
	for entry in data.get("placed", []):
		var path: String = entry.get("scene", "")
		if path == "" or not ResourceLoader.exists(path):
			continue
		var node := (load(path) as PackedScene).instantiate() as Node3D
		placed_root.add_child(node)
		node.global_position = _array_to_vec(entry.get("position", [0, 0, 0]))
		node.rotation.y = float(entry.get("rotation_y", 0.0))
		if entry.has("data") and node.has_method("load_data"):
			node.load_data(entry.data)


static func _vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _array_to_vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Vector3.ZERO
