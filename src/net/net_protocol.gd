class_name NetProtocol
## Shared constants and pure helpers of the multiplayer protocol (Milestone 11).
##
## Everything a peer sends is plain Variant data (no Objects), so it travels
## through Godot's RPC encoding safely and can be validated field by field.

## Bumped whenever messages change; peers with a different version are refused.
const VERSION := 1
const DEFAULT_PORT := 24565
const MAX_PLAYERS := 8
## Player state packets per second (client -> server, server -> clients).
const STATE_RATE := 20.0
## Remote players are drawn this far in the past to interpolate smoothly (s).
const INTERP_DELAY := 0.1
## Fastest legitimate movement (m/s): sprinting, dashes, knockback, falling.
const MAX_SPEED := 32.0
## Server-checked reach for harvesting, picking up and building (m).
const REACH := 8.0
const BUILD_REACH := 10.0
## Chunk regions sent around each player (RegionStore regions, radius in regions).
const REGION_RADIUS := 1

## Player state flags.
const F_BLOCKING := 1
const F_SWIMMING := 2
const F_AIRBORNE := 4
const F_DEAD := 8
const F_TELEPORT := 16


## [x, y, z, yaw, vx, vz, move_ratio, flags, layer, health_ratio]
static func encode_state(pos: Vector3, yaw: float, vel: Vector3, move: float, flags: int, layer: int, hp: float) -> Array:
	return [pos.x, pos.y, pos.z, yaw, vel.x, vel.z, move, flags, layer, hp]


static func decode_state(a: Variant) -> Dictionary:
	if not a is Array or (a as Array).size() < 10:
		return {}
	var s: Array = a
	for i in 10:
		if not (s[i] is float or s[i] is int):
			return {}
	var pos := Vector3(float(s[0]), float(s[1]), float(s[2]))
	if not pos.is_finite():
		return {}
	return {"pos": pos, "yaw": float(s[3]), "vel": Vector3(float(s[4]), 0, float(s[5])), "move": clampf(float(s[6]), 0.0, 2.0),
		"flags": int(s[7]), "layer": clampi(int(s[8]), 0, 1), "hp": clampf(float(s[9]), 0.0, 1.0)}


## Fingerprint of world generation for a seed: every peer must compute the same
## value, or they would see different worlds (different game versions, mods...).
static func world_checksum(gen: TerrainGenerator) -> int:
	var h := HashUtils.hash3(gen.world_seed & 0x7FFFFFFF, gen.world_seed >> 31, TerrainGenerator.CHUNK_SIZE)
	for c: Vector2i in [Vector2i(0, 0), Vector2i(5, -3), Vector2i(-17, 9), Vector2i(40, 40), Vector2i(-300, 120)]:
		var d := gen.generate_chunk(c, 0)
		for k in range(0, d.heights.size(), 7):
			h = HashUtils.hash3(h, d.heights[k], d.biomes[k])
		h = HashUtils.hash3(h, d.props.size(), d.spawns.size())
	for c in [Vector2i(0, 0), Vector2i(2, 1)]:
		var st := gen.settlements.get_region(c)
		h = HashUtils.hash3(h, st.center.x if st else 0, st.center.y if st else 1)
	h = HashUtils.hash3(h, ItemDB.all_ids().size(), BuildingManager.all_pieces().size())
	return h


## Clean player name (letters, digits, spaces, _ -), 1..16 characters.
static func clean_name(n: String) -> String:
	var out := ""
	for ch in n.strip_edges():
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in [" ", "_", "-"]:
			out += ch
	out = out.strip_edges().substr(0, 16)
	return out if out != "" else "Player"


## A slot index from the network, or -1.
static func slot_arg(v: Variant, capacity: int) -> int:
	if not (v is int or v is float):
		return -1
	var i := int(v)
	return i if i >= 0 and i < capacity else -1


static func vec2i_arg(v: Variant) -> Variant:
	if v is Vector2i:
		return v
	if v is Array and (v as Array).size() == 2:
		return Vector2i(int(v[0]), int(v[1]))
	return null
