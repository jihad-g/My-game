class_name TreasureSpots
extends Node3D
## Wild treasure (Milestone 15): small, deterministic finds out in the open -
## abandoned camps (tent, cold fire pit, a chest), shipwrecks on beaches and
## buried caches (a mound with a cross of sticks). One loot chest each, opened
## once per world (state kept like POI chests, key "t:<chunk>").
##
## A chunk holds a spot with CHANCE (a pure function of seed + chunk), never in
## towns, POIs or water. Loot rank follows the distance from the origin.

const CHANCE := 0.012
const KINDS := [&"camp", &"shipwreck", &"buried"]
const TABLES := {&"camp": &"wild_camp", &"shipwreck": &"shipwreck", &"buried": &"buried_cache"}
const NAMES := {&"camp": "Abandoned camp", &"shipwreck": "Shipwreck", &"buried": "Buried cache"}

var chunk_manager: ChunkManager
var generator: TerrainGenerator
var _sites: Dictionary = {}  # Vector2i -> Node3D


func _ready() -> void:
	chunk_manager.chunk_ready.connect(_on_chunk_ready)
	chunk_manager.chunk_removed.connect(_free_site)


## The treasure spot in a chunk, or {} - {kind, position (Vector3), key, rank}.
static func spot_for(gen: TerrainGenerator, coord: Vector2i) -> Dictionary:
	var hsh := HashUtils.hash4(gen.world_seed, 7717, coord.x, coord.y)
	if HashUtils.to_unit(hsh, 0) >= CHANCE:
		return {}
	var cs := TerrainGenerator.CHUNK_SIZE
	var wx := coord.x * cs + 3 + int(HashUtils.to_unit(hsh, 1) * (cs - 6))
	var wz := coord.y * cs + 3 + int(HashUtils.to_unit(hsh, 2) * (cs - 6))
	var h := gen.get_height_blocks(wx, wz)
	if h < TerrainGenerator.SEA_LEVEL + 1 or h > 60:
		return {}
	for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		if absi(gen.get_height_blocks(wx + d.x, wz + d.y) - h) > 1:
			return {}  # too rough
	if gen.settlements.is_inside(wx, wz, 30.0) or gen.pois.is_inside(wx, wz, 20.0):
		return {}
	var biome: StringName = gen.biomes[gen.get_biome_index(wx, wz)].id
	if biome == &"deep_ocean":
		return {}
	var kind: StringName = &"camp"
	if biome == &"sandy_beach":
		kind = &"shipwreck"
	elif biome in [&"sunscorch_desert", &"snowy_tundra"] or HashUtils.to_unit(hsh, 3) < 0.3:
		kind = &"buried"
	var pos := Vector3(wx + 0.5, h * TerrainGenerator.BLOCK_HEIGHT, wz + 0.5)
	return {"kind": kind, "position": pos, "key": "t:%d,%d" % [coord.x, coord.y],
		"rank": EnemySpawner.wild_rank(pos), "yaw": HashUtils.to_unit(hsh, 4) * TAU}


func _on_chunk_ready(coord: Vector2i, lod: int, chunk: Chunk) -> void:
	if lod != 0 or chunk.layer != TerrainGenerator.Layer.SURFACE:
		_free_site(coord)
		return
	if _sites.has(coord):
		return
	var spot := spot_for(generator, coord)
	if spot.is_empty():
		return
	var site := build_site(spot)
	add_child(site)
	_sites[coord] = site


func _free_site(coord: Vector2i) -> void:
	if _sites.has(coord):
		var n: Node = _sites[coord]
		if is_instance_valid(n):
			n.queue_free()
		_sites.erase(coord)


func clear_all() -> void:
	for coord in _sites.keys():
		_free_site(coord)


func active_sites() -> Array:
	return _sites.values()


## Builds the decor and the chest for a spot.
static func build_site(spot: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Treasure_%s" % String(spot.key).replace(":", "_").replace(",", "_")
	root.position = spot.position
	root.rotation.y = float(spot.get("yaw", 0.0))
	root.set_meta(&"treasure_kind", spot.kind)
	var b := BlockMesh.new()
	var chest := LootChest.new()
	chest.table = TABLES[spot.kind]
	chest.rank = int(spot.rank)
	chest.persist_key = spot.key
	match spot.kind:
		&"camp":
			var canvas := Color(0.72, 0.64, 0.48)
			b.box(Vector3(-0.42, 0.6, -1.6), Vector3(0.1, 1.45, 2.2), canvas, Basis.from_euler(Vector3(0, 0, -0.6)))  # tent sides lean together
			b.box(Vector3(0.42, 0.6, -1.6), Vector3(0.1, 1.45, 2.2), canvas * 0.92, Basis.from_euler(Vector3(0, 0, 0.6)))
			b.box(Vector3(0, 1.2, -1.6), Vector3(0.08, 0.08, 2.4), Color(0.4, 0.28, 0.16))  # ridge pole
			for k in 6:  # cold fire pit
				var a := TAU * k / 6.0
				b.box(Vector3(1.6 + cos(a) * 0.45, 0.08, 0.4 + sin(a) * 0.45), Vector3(0.22, 0.16, 0.22), Color(0.45, 0.45, 0.47))
			b.box(Vector3(1.6, 0.05, 0.4), Vector3(0.5, 0.06, 0.5), Color(0.15, 0.13, 0.12))  # ash
			b.box(Vector3(-1.6, 0.15, 0.8), Vector3(1.4, 0.3, 0.3), Color(0.45, 0.3, 0.18))  # log seat
			chest.position = Vector3(0, 0, 0.6)
		&"shipwreck":
			var wood := Color(0.42, 0.3, 0.2)
			b.box(Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 5.0), wood * 0.85)  # hull bottom
			b.box(Vector3(-1.2, 0.7, 0.3), Vector3(0.15, 0.9, 4.2), wood, Basis.from_euler(Vector3(0, 0, 0.25)))  # sides
			b.box(Vector3(1.2, 0.55, -0.4), Vector3(0.15, 0.6, 3.0), wood * 0.9, Basis.from_euler(Vector3(0, 0, -0.3)))
			b.box(Vector3(0.3, 1.6, -0.8), Vector3(0.18, 3.0, 0.18), wood * 1.1, Basis.from_euler(Vector3(0.3, 0, 0.5)))  # broken mast
			b.box(Vector3(0.9, 2.6, -0.4), Vector3(1.4, 0.9, 0.05), Color(0.85, 0.82, 0.72), Basis.from_euler(Vector3(0.3, 0, 0.5)))  # torn sail
			chest.position = Vector3(0, 0.5, 1.2)
		&"buried":
			b.box(Vector3(0, 0.12, 0), Vector3(1.6, 0.24, 1.6), Color(0.52, 0.4, 0.26))  # mound
			b.box(Vector3(0, 0.28, 0), Vector3(1.2, 0.08, 0.16), Color(0.35, 0.22, 0.12), Basis.from_euler(Vector3(0, 0.785, 0)))  # X marks the spot
			b.box(Vector3(0, 0.28, 0), Vector3(1.2, 0.08, 0.16), Color(0.35, 0.22, 0.12), Basis.from_euler(Vector3(0, -0.785, 0)))
			b.box(Vector3(1.0, 0.5, -0.6), Vector3(0.08, 1.0, 0.08), Color(0.4, 0.28, 0.16))  # shovel handle
			b.box(Vector3(1.0, 0.06, -0.6), Vector3(0.3, 0.12, 0.05), Color(0.55, 0.55, 0.58))
			chest.position = Vector3(0, -0.3, 0)  # half buried
	var decor := MeshInstance3D.new()
	decor.mesh = b.commit()
	root.add_child(decor)
	root.add_child(chest)
	return root
