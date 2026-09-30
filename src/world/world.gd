class_name World
extends Node3D
## Root of the game world scene. Wires systems together and offers world-level
## services: ground height, temperature, pickups, placing objects.
##
## Systems stay independent: ChunkManager streams terrain, EnemySpawner reacts
## to chunk signals, the HUD reads the player, etc. World only connects them.

static var instance: World

const FIRE_MAX_TEMPERATURE := 28.0

@export var default_biome: BiomeData
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
## Added to air temperature (debug keys F6/F7) to test cold/heat effects.
var debug_temperature_offset: float = 0.0
## True once the terrain around the spawn point is generated.
var is_ready: bool = false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	generator = TerrainGenerator.new(GameState.world_seed, default_biome)
	props = PropLibrary.new()
	chunk_manager.setup(generator, props)
	spawner.generator = generator

	var col := generator.find_spawn_column(Vector2i.ZERO)
	var ground := generator.get_height_blocks(col.x, col.y) * TerrainGenerator.BLOCK_HEIGHT
	player.spawn_point = Vector3(col.x + 0.5, ground + 0.3, col.y + 0.5)
	player.global_position = player.spawn_point
	player.frozen = true
	player.camera_rig = camera_rig
	player.temperature.ambient_provider = func() -> float: return get_temperature_at(player.global_position)
	camera_rig.target = player
	camera_rig.snap_to_target()
	chunk_manager.focus = player
	hud.bind(player, self)
	hud.set_loading(true)
	for id: StringName in starting_items:
		player.inventory.add_item(id, int(starting_items[id]))


func _process(_delta: float) -> void:
	if not is_ready and chunk_manager.is_near_area_ready():
		is_ready = true
		# Place the player exactly on the generated surface before unfreezing.
		var p := player.global_position
		p.y = get_ground_height(p) + 0.3
		player.global_position = p
		player.temperature.snap_to_ambient()
		player.frozen = false
		hud.set_loading(false)
		Events.toast.emit("Welcome to the Verdant Meadows", Color(0.8, 1.0, 0.7))


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


# --- World services -------------------------------------------------------------------

func get_ground_height(pos: Vector3) -> float:
	return generator.get_height_at(pos)


## Air temperature from biome, time of day, regional climate, altitude, water.
func get_air_temperature(pos: Vector3) -> float:
	var biome := generator.get_biome(floori(pos.x), floori(pos.z))
	var t := biome.base_temperature
	t += day_night.get_temperature_factor() * biome.day_night_swing
	t += generator.get_climate_noise(pos) * biome.regional_variation
	t -= maxf(0.0, pos.y - 2.0) * biome.altitude_lapse
	if pos.y < TerrainGenerator.WATER_Y - 0.25:
		t -= 5.0  # wet and chilled while wading
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
	var heat := get_heat_at(pos)
	if heat <= 0.0 or air >= FIRE_MAX_TEMPERATURE:
		return air
	return minf(air + heat, FIRE_MAX_TEMPERATURE)


func spawn_pickup(item_id: StringName, count: int, pos: Vector3, auto_collect: bool = true) -> Pickup:
	var p := pickup_pool.acquire() as Pickup
	if p == null:
		return null
	p.setup(item_id, count, pos, maxf(get_ground_height(pos), TerrainGenerator.WATER_Y - 1.0), auto_collect)
	return p


## Places a scene (campfire, later buildings) on the ground at `pos`.
func place_object(scene: PackedScene, pos: Vector3) -> bool:
	if scene == null:
		return false
	var ground := get_ground_height(pos)
	if ground < TerrainGenerator.WATER_Y:
		Events.toast.emit("Can't place that in water", Color(1, 0.6, 0.5))
		return false
	var node := scene.instantiate() as Node3D
	placed_root.add_child(node)
	node.global_position = Vector3(pos.x, ground, pos.z)
	return true


func debug_spawn_enemy() -> Enemy:
	if debug_enemy_scene == null:
		return null
	var pos := player.global_position + player.get_facing() * 8.0
	pos.y = get_ground_height(pos) + 0.5
	var e := spawner.spawn_enemy(debug_enemy_scene, pos, "")
	if e:
		Events.toast.emit("Debug: spawned %s" % e.display_name(), Color(1, 0.8, 0.6))
	return e
