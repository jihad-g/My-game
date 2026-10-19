class_name FarImpostors
extends RefCounted
## Milestone 18d: cheap stand-ins for things that are too far away to stream.
##
## - Tree clumps: one leafy box per 8 x 8 m cell, as many as the biome's tree
##   rules ask for. Drawn in LOD2 chunks (which have no props) and in the far
##   horizon tiles, so forests don't vanish between the props and the horizon.
## - Landmarks: a few houses and a keep for towns, a tower, temple, ruins or
##   dungeon gate for points of interest. They only show beyond the distance
##   where the real buildings are spawned (visibility_range_begin).
##
## Everything is a pure function of the generator, so it is thread-safe.

## Prop id -> [leaf colour, tree height (m), crown width (m)].
const TREE_LOOK := {
	&"tree_oak": [Color(0.19, 0.46, 0.18), 4.4, 2.6],
	&"tree_pine": [Color(0.13, 0.34, 0.2), 6.0, 2.2],
	&"tree_snowy_pine": [Color(0.82, 0.88, 0.9), 6.0, 2.2],
	&"tree_jungle": [Color(0.12, 0.44, 0.19), 5.6, 3.4],
	&"tree_palm": [Color(0.25, 0.55, 0.22), 5.0, 2.6],
	&"tree_swamp": [Color(0.3, 0.42, 0.2), 3.6, 2.8],
	&"tree_dead": [Color(0.4, 0.32, 0.22), 3.5, 1.2],
	&"cactus": [Color(0.35, 0.55, 0.3), 2.5, 0.8],
	&"mushroom_giant": [Color(0.75, 0.25, 0.25), 4.0, 3.0],
	# Milestone 40 ("Many Trees")
	&"tree_oak_young": [Color(0.24, 0.52, 0.2), 2.5, 1.3],
	&"tree_oak_big": [Color(0.17, 0.42, 0.16), 6.0, 3.8],
	&"tree_birch": [Color(0.42, 0.62, 0.2), 4.8, 1.6],
	&"tree_autumn": [Color(0.86, 0.42, 0.13), 4.7, 2.6],
	&"tree_pine_tall": [Color(0.13, 0.36, 0.22), 7.6, 2.6],
	&"tree_pine_young": [Color(0.2, 0.5, 0.32), 2.5, 1.2],
	&"tree_snowy_pine_tall": [Color(0.82, 0.88, 0.9), 7.6, 2.6],
	&"tree_snowy_pine_young": [Color(0.82, 0.88, 0.9), 2.5, 1.2],
	&"tree_frozen_dead": [Color(0.62, 0.66, 0.72), 3.4, 1.4],
	&"tree_jungle_giant": [Color(0.1, 0.4, 0.17), 8.2, 4.4],
	&"tree_palm_bent": [Color(0.3, 0.66, 0.26), 4.3, 2.6],
	&"tree_palm_short": [Color(0.28, 0.6, 0.24), 2.3, 2.4],
	&"tree_willow": [Color(0.36, 0.5, 0.22), 4.1, 3.6],
	&"tree_mangrove": [Color(0.22, 0.4, 0.18), 4.3, 2.6],
	&"cactus_tall": [Color(0.32, 0.56, 0.28), 3.6, 1.4],
	&"tree_acacia": [Color(0.42, 0.52, 0.22), 3.4, 3.2],
	&"tree_crystal": [Color(0.74, 0.48, 1.0), 4.9, 2.4],
	&"tree_crystal_spire": [Color(0.42, 0.8, 1.0), 7.0, 1.8],
	&"tree_crystal_young": [Color(0.78, 0.55, 1.0), 2.3, 1.2],
}
## Cell size (m) of one tree clump.
const CELL := 8
## Landmarks show only beyond this camera distance (the real town is spawned
## within SettlementManager.SPAWN_RANGE = 170 m of the player).
const LANDMARK_NEAR := 185.0

static var _cover_cache: Dictionary = {}  # generator instance id -> Array per biome
static var _cover_mutex := Mutex.new()


## Per biome: [trees per m², leaf colour, height, width] of its main tree (or []).
static func tree_cover(gen: TerrainGenerator) -> Array:
	var key := gen.get_instance_id()
	_cover_mutex.lock()
	var out: Array = _cover_cache.get(key, [])
	if out.is_empty():
		for b: BiomeData in gen.biomes:
			var cover := 0.0
			var best := 0.0
			var look: Array = []
			for r in b.prop_rules:
				var rule := r as PropRule
				if rule == null or not TREE_LOOK.has(rule.prop_id):
					continue
				var per_m2 := rule.density / float(rule.cell_size * rule.cell_size)
				cover += per_m2
				if per_m2 > best:
					best = per_m2
					look = TREE_LOOK[rule.prop_id]
			out.append([cover, look[0], look[1], look[2]] if not look.is_empty() else [])
		_cover_cache[key] = out
	_cover_mutex.unlock()
	return out


## True and the clump's spot/scale when cell (cx, cz) (world cells of CELL m)
## has a far tree clump. Returns [] when it has none.
static func clump_at(gen: TerrainGenerator, cover: Array, cx: int, cz: int, biome: int, h: int) -> Array:
	if h <= TerrainGenerator.SEA_LEVEL + 1:
		return []
	var info: Array = cover[biome] if biome < cover.size() else []
	if info.is_empty():
		return []
	var wx := cx * CELL + CELL / 2
	var wz := cz * CELL + CELL / 2
	if gen.settlements.is_inside(wx, wz, 6.0) or gen.pois.is_inside(wx, wz, 4.0):
		return []
	var expected: float = info[0] * CELL * CELL
	var hsh := HashUtils.hash3(cx, cz, gen.world_seed + 4441)
	if HashUtils.to_unit(hsh, 0) >= minf(0.9, expected * 0.55):
		return []
	var ox := (HashUtils.to_unit(hsh, 1) - 0.5) * (CELL - 3.0)
	var oz := (HashUtils.to_unit(hsh, 2) - 0.5) * (CELL - 3.0)
	var s := 0.8 + HashUtils.to_unit(hsh, 3) * 0.5
	return [ox, oz, s, info[1], info[2], info[3]]


## Adds a tree clump (crown box) standing on ground height `y` at local (x, z).
static func add_clump(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		x: float, z: float, y: float, clump: Array) -> void:
	var s: float = clump[2]
	var leaf: Color = clump[3]
	var hgt: float = clump[4] * s
	var w: float = clump[5] * s * 1.2
	# Two tiers (wide below, narrow on top) so a far forest reads as trees, not boxes.
	add_box(v, n, c, idx, Vector3(x - w * 0.5, y + hgt * 0.3, z - w * 0.5), Vector3(x + w * 0.5, y + hgt * 0.75, z + w * 0.5), leaf * 0.9)
	add_box(v, n, c, idx, Vector3(x - w * 0.3, y + hgt * 0.75, z - w * 0.3), Vector3(x + w * 0.3, y + hgt, z + w * 0.3), leaf)


## Axis-aligned box from `lo` to `hi` (no bottom face), top lit, sides shaded.
static func add_box(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		lo: Vector3, hi: Vector3, col: Color) -> void:
	TerrainGenerator._quad(v, n, c, idx, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z),
		Vector3(lo.x, hi.y, hi.z), Vector3.UP, col)
	var sx := col * TerrainGenerator.side_shade(Vector3.RIGHT)
	var sz := col * TerrainGenerator.side_shade(Vector3.BACK)
	TerrainGenerator._quad(v, n, c, idx, Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z),
		Vector3(hi.x, lo.y, lo.z), Vector3.RIGHT, sx)
	TerrainGenerator._quad(v, n, c, idx, Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3.LEFT, sx)
	TerrainGenerator._quad(v, n, c, idx, Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(hi.x, lo.y, hi.z), Vector3.BACK, sz)
	TerrainGenerator._quad(v, n, c, idx, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, lo.y, lo.z),
		Vector3(lo.x, lo.y, lo.z), Vector3.FORWARD, sz)


# --- Landmarks -------------------------------------------------------------------

## Settlements and points of interest whose centre lies in the column rectangle
## [x0, x1) x [z0, z1). Hidden groves are left out (they are secret).
static func landmarks_in(gen: TerrainGenerator, x0: int, z0: int, x1: int, z1: int) -> Array[SettlementInfo]:
	var out: Array[SettlementInfo] = []
	var r0 := Settlements.region_of(x0, z0)
	var r1 := Settlements.region_of(x1 - 1, z1 - 1)
	for rz in range(r0.y, r1.y + 1):
		for rx in range(r0.x, r1.x + 1):
			var st := gen.settlements.get_region(Vector2i(rx, rz))
			if st and st.center.x >= x0 and st.center.x < x1 and st.center.y >= z0 and st.center.y < z1:
				out.append(st)
	var c0 := Exploration.cell_of(x0, z0)
	var c1 := Exploration.cell_of(x1 - 1, z1 - 1)
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var poi := gen.pois.get_cell(Vector2i(cx, cz))
			if poi and not poi.is_hidden() and poi.center.x >= x0 and poi.center.x < x1 \
					and poi.center.y >= z0 and poi.center.y < z1:
				out.append(poi)
	return out


## Unique key of a landmark (stable across tiles).
static func landmark_key(info: SettlementInfo) -> String:
	return "%s@%d,%d" % [info.id, info.center.x, info.center.y]


## Mesh arrays of a landmark, around its centre (local origin = centre on the ground).
static func landmark_arrays(info: SettlementInfo) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var stone := Color(0.62, 0.6, 0.56)
	var wall := Color(0.86, 0.8, 0.66)
	var roofs := [Color(0.62, 0.28, 0.2), Color(0.45, 0.3, 0.22), Color(0.36, 0.38, 0.5)]
	if info is PoiInfo:
		var poi := info as PoiInfo
		match poi.kind:
			PoiInfo.Kind.TOWER:
				add_box(v, n, c, idx, Vector3(-3, 0, -3), Vector3(3, 16, 3), Color(0.5, 0.48, 0.6))
				add_box(v, n, c, idx, Vector3(-3.6, 16, -3.6), Vector3(3.6, 19, 3.6), Color(0.4, 0.3, 0.6))
			PoiInfo.Kind.TEMPLE:
				add_box(v, n, c, idx, Vector3(-7, 0, -5), Vector3(7, 5, 5), Color(0.9, 0.88, 0.8))
				add_box(v, n, c, idx, Vector3(-8, 5, -6), Vector3(8, 6.5, 6), Color(0.78, 0.72, 0.55))
			PoiInfo.Kind.DUNGEON:
				add_box(v, n, c, idx, Vector3(-4, 0, -2), Vector3(-2, 6, 2), Color(0.32, 0.3, 0.34))
				add_box(v, n, c, idx, Vector3(2, 0, -2), Vector3(4, 6, 2), Color(0.32, 0.3, 0.34))
				add_box(v, n, c, idx, Vector3(-4, 6, -2), Vector3(4, 7.5, 2), Color(0.28, 0.26, 0.3))
			_:  # ruins: broken walls
				for k in 5:
					var a := k * 1.3 + float(info.seed % 7)
					var p := Vector3(cos(a), 0, sin(a)) * 6.0
					var hh := 2.0 + float((info.seed >> k) & 3)
					add_box(v, n, c, idx, p + Vector3(-1.2, 0, -1.2), p + Vector3(1.2, hh, 1.2), stone)
	else:
		var houses := 14 if info.is_kingdom() else 6
		var r := info.radius * 0.7
		for k in houses:
			var hsh := HashUtils.hash3(info.seed, k, 991)
			var a := HashUtils.to_unit(hsh, 0) * TAU
			var d := r * (0.35 + 0.65 * HashUtils.to_unit(hsh, 1))
			var p := Vector3(cos(a) * d, 0, sin(a) * d)
			var s := 2.2 + HashUtils.to_unit(hsh, 2) * 1.2
			add_box(v, n, c, idx, p + Vector3(-s, 0, -s), p + Vector3(s, 3.0, s), wall)
			add_box(v, n, c, idx, p + Vector3(-s - 0.4, 3.0, -s - 0.4), p + Vector3(s + 0.4, 4.6, s + 0.4), roofs[k % roofs.size()])
		if info.is_kingdom():
			add_box(v, n, c, idx, Vector3(-6, 0, -6), Vector3(6, 12, 6), stone)
			add_box(v, n, c, idx, Vector3(-2, 12, -2), Vector3(2, 18, 2), stone * 0.9)
			add_box(v, n, c, idx, Vector3(-0.2, 18, -0.2), Vector3(0.2, 21, 0.2), info.color)
		else:
			add_box(v, n, c, idx, Vector3(-1.5, 0, -1.5), Vector3(1.5, 7, 1.5), stone)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays
