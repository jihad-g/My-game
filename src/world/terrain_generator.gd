class_name TerrainGenerator
extends RefCounted
## Deterministic, thread-safe procedural terrain.
##
## The world is an infinite heightfield of block columns (voxel-inspired).
## Heights come from layered noise seeded by the world seed, so the same seed
## always produces the same world, on any machine, in any load order.
##
## Coordinates:
##   - 1 block = 1 m horizontally, BLOCK_HEIGHT m vertically.
##   - A chunk is CHUNK_SIZE x CHUNK_SIZE columns.
##   - World column (wx, wz) belongs to chunk floor(wx / CHUNK_SIZE).
##
## There is no hard world border. At the ~3,000,000 chunk target the world spans
## roughly +-14,000 m from the origin, which is within float precision limits.
## (Beyond that a floating origin would be needed - see docs/ARCHITECTURE.md.)

const CHUNK_SIZE := 16
const BLOCK_HEIGHT := 0.5
## Columns with a top below this block height are underwater.
const SEA_LEVEL := 0
const WATER_Y := -0.15
## Downward "skirt" on chunk edges to hide LOD seams.
const SKIRT_BLOCKS := 6

var world_seed: int
## Phase 1 has a single biome; get_biome() is the hook for multi-biome worlds.
var default_biome: BiomeData

var _continent := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _climate := FastNoiseLite.new()
var _cluster := FastNoiseLite.new()


func _init(p_seed: int, p_default_biome: BiomeData) -> void:
	world_seed = p_seed
	default_biome = p_default_biome
	_setup_noise(_continent, 1, 0.0022, 4)
	_setup_noise(_hills, 2, 0.0065, 2)
	_setup_noise(_ridge, 3, 0.016, 2)
	_setup_noise(_detail, 4, 0.08, 1)
	_setup_noise(_climate, 5, 0.0025, 2)
	_setup_noise(_cluster, 6, 0.03, 2)


func _setup_noise(n: FastNoiseLite, salt: int, frequency: float, octaves: int) -> void:
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = HashUtils.hash3(world_seed, salt, 0x51ed)
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves


# --- Queries -----------------------------------------------------------------

static func world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK_SIZE), floori(pos.z / CHUNK_SIZE))


static func column_to_chunk(wx: int, wz: int) -> Vector2i:
	return Vector2i(floori(float(wx) / CHUNK_SIZE), floori(float(wz) / CHUNK_SIZE))


func get_biome(_wx: int, _wz: int) -> BiomeData:
	# Multi-biome selection (temperature/moisture maps) arrives in Phase 3.
	return default_biome


## Surface height of column (wx, wz) in blocks.
func get_height_blocks(wx: int, wz: int) -> int:
	var b := get_biome(wx, wz)
	var x := float(wx)
	var z := float(wz)
	var h := b.base_height + _continent.get_noise_2d(x, z) * b.continent_amplitude
	var hill := clampf(_hills.get_noise_2d(x, z) * 1.8 + 0.1, 0.0, 1.0)
	var ridge := 1.0 - absf(_ridge.get_noise_2d(x, z))
	h += hill * hill * (b.hill_amplitude + ridge * ridge * b.ridge_amplitude)
	h += _detail.get_noise_2d(x, z) * b.detail_amplitude
	return floori(h)


## Surface height in metres at a world position (top of the column).
func get_height_at(pos: Vector3) -> float:
	return get_height_blocks(floori(pos.x), floori(pos.z)) * BLOCK_HEIGHT


## Regional climate variation in [-1, 1].
func get_climate_noise(pos: Vector3) -> float:
	return _climate.get_noise_2d(pos.x, pos.z)


# --- Chunk generation (thread-safe: reads only immutable state) --------------

func generate_chunk(coord: Vector2i, lod: int) -> ChunkData:
	var data := ChunkData.new()
	data.coord = coord
	data.lod = lod
	data.step = 1 << lod
	var step := data.step
	var n := CHUNK_SIZE / step
	var w := n + 2
	var ox := coord.x * CHUNK_SIZE
	var oz := coord.y * CHUNK_SIZE
	var biome := get_biome(ox, oz)

	data.heights.resize(w * w)
	var hmin := 1 << 30
	var hmax := -(1 << 30)
	for j in w:
		for i in w:
			var h := get_height_blocks(ox + (i - 1) * step, oz + (j - 1) * step)
			data.heights[j * w + i] = h
			if i > 0 and j > 0 and i <= n and j <= n:
				hmin = mini(hmin, h)
				hmax = maxi(hmax, h)
	data.min_height = hmin
	data.max_height = hmax

	_build_surface(data, biome, n, w, ox, oz)
	if lod == 0:
		_build_collision(data)
	if lod <= 1:
		_place_props(data, biome, n, w, ox, oz)
	if lod == 0:
		_place_spawns(data, biome, ox, oz)
	return data


func _build_surface(data: ChunkData, biome: BiomeData, n: int, w: int, ox: int, oz: int) -> void:
	var step := data.step
	var bh := BLOCK_HEIGHT
	var verts := data.vertices
	var norms := data.normals
	var cols := data.colors
	var idx := data.indices
	var wv := data.water_vertices
	var wi := data.water_indices
	var water_y := WATER_Y
	for j in n:
		for i in n:
			var h := data.heights[(j + 1) * w + (i + 1)]
			var x0 := float(i * step)
			var x1 := x0 + step
			var z0 := float(j * step)
			var z1 := z0 + step
			var y := h * bh
			var wx := ox + i * step
			var wz := oz + j * step
			var top := _top_color(biome, h, wx, wz)
			_quad(verts, norms, cols, idx,
				Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
				Vector3.UP, top)
			# Side walls where the neighbour is lower; always on chunk borders (skirt).
			_side(data, biome, h, data.heights[(j + 1) * w + (i + 2)], i == n - 1,
				Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.RIGHT, wx, wz)
			_side(data, biome, h, data.heights[(j + 1) * w + i], i == 0,
				Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.LEFT, wx, wz)
			_side(data, biome, h, data.heights[(j + 2) * w + (i + 1)], j == n - 1,
				Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.BACK, wx, wz)
			_side(data, biome, h, data.heights[j * w + (i + 1)], j == 0,
				Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.FORWARD, wx, wz)
			if h < SEA_LEVEL:
				var base := wv.size()
				wv.append_array([Vector3(x0, water_y, z0), Vector3(x1, water_y, z0),
					Vector3(x1, water_y, z1), Vector3(x0, water_y, z1)])
				BlockMesh.append_quad_indices(wi, base, wv[base], wv[base + 1], wv[base + 2], Vector3.UP)


func _side(data: ChunkData, biome: BiomeData, h: int, nh: int, border: bool,
		a: Vector3, b: Vector3, normal: Vector3, wx: int, wz: int) -> void:
	var bottom := nh
	if border:
		bottom = mini(nh, h) - SKIRT_BLOCKS
	if bottom >= h:
		return
	var bh := BLOCK_HEIGHT
	var top_y := h * bh
	var shade := 0.72 if normal.z != 0.0 else 0.8
	# Top band: one block of "grass edge" (or rock/sand), rest dirt/stone below.
	var edge_col := _top_color(biome, h, wx, wz) * shade
	var body_col := _side_color(biome, h) * shade
	var band_bottom := maxi(bottom, h - 1)
	_quad(data.vertices, data.normals, data.colors, data.indices,
		Vector3(a.x, top_y, a.z), Vector3(b.x, top_y, b.z),
		Vector3(b.x, band_bottom * bh, b.z), Vector3(a.x, band_bottom * bh, a.z),
		normal, edge_col)
	if band_bottom > bottom:
		_quad(data.vertices, data.normals, data.colors, data.indices,
			Vector3(a.x, band_bottom * bh, a.z), Vector3(b.x, band_bottom * bh, b.z),
			Vector3(b.x, bottom * bh, b.z), Vector3(a.x, bottom * bh, a.z),
			normal, body_col)


func _top_color(biome: BiomeData, h: int, wx: int, wz: int) -> Color:
	var c: Color
	if h < SEA_LEVEL:
		c = biome.underwater_color
	elif h <= SEA_LEVEL + 1:
		c = biome.shore_color
	elif h >= biome.peak_height:
		c = biome.peak_color
	elif h >= biome.rock_height:
		c = biome.rock_color
	else:
		# Two-tone checker-ish variation gives the voxel look.
		var t := HashUtils.to_unit(HashUtils.hash3(wx, wz, world_seed), 3)
		c = biome.top_color.lerp(biome.top_color_alt, t * t)
	# Subtle per-column brightness jitter.
	var jitter := 0.97 + HashUtils.to_unit(HashUtils.hash3(wz, wx, 77), 1) * 0.06
	return Color(c.r * jitter, c.g * jitter, c.b * jitter)


func _side_color(biome: BiomeData, h: int) -> Color:
	if h >= biome.rock_height - 4:
		return biome.rock_color * 0.9
	if h <= SEA_LEVEL + 1:
		return biome.shore_color * 0.85
	return biome.side_color


static func _quad(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray,
		idx: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c, d])
	norms.append_array([normal, normal, normal, normal])
	cols.append_array([color, color, color, color])
	BlockMesh.append_quad_indices(idx, base, a, b, c, normal)


func _build_collision(data: ChunkData) -> void:
	var faces := PackedVector3Array()
	faces.resize(data.indices.size())
	for k in data.indices.size():
		faces[k] = data.vertices[data.indices[k]]
	data.collision_faces = faces


func _column_height_local(data: ChunkData, w: int, lx: int, lz: int) -> int:
	# lx/lz in blocks relative to chunk origin, converted to LOD column space.
	var i := clampi(lx / data.step, 0, w - 3)
	var j := clampi(lz / data.step, 0, w - 3)
	return data.heights[(j + 1) * w + (i + 1)]


func _max_slope_local(data: ChunkData, w: int, lx: int, lz: int) -> int:
	var i := clampi(lx / data.step, 0, w - 3) + 1
	var j := clampi(lz / data.step, 0, w - 3) + 1
	var h := data.heights[j * w + i]
	var s := 0
	s = maxi(s, absi(h - data.heights[j * w + i + 1]))
	s = maxi(s, absi(h - data.heights[j * w + i - 1]))
	s = maxi(s, absi(h - data.heights[(j + 1) * w + i]))
	s = maxi(s, absi(h - data.heights[(j - 1) * w + i]))
	return s


func _max_slope_world(wx: int, wz: int, h: int) -> int:
	var s := absi(h - get_height_blocks(wx + 1, wz))
	s = maxi(s, absi(h - get_height_blocks(wx - 1, wz)))
	s = maxi(s, absi(h - get_height_blocks(wx, wz + 1)))
	s = maxi(s, absi(h - get_height_blocks(wx, wz - 1)))
	return s


func _place_props(data: ChunkData, biome: BiomeData, _n: int, w: int, ox: int, oz: int) -> void:
	for r in biome.prop_rules.size():
		var rule: PropRule = biome.prop_rules[r]
		if data.lod > 0 and not rule.show_in_lod1:
			continue
		var cell := rule.cell_size
		var cells := CHUNK_SIZE / cell
		for cz in cells:
			for cx in cells:
				var wx := ox + cx * cell
				var wz := oz + cz * cell
				var hsh := HashUtils.hash4(world_seed, rule.salt, wx, wz)
				var density := rule.density
				if rule.clustering > 0.0:
					var cl := _cluster.get_noise_2d(float(wx), float(wz)) * 0.5 + 0.5
					density *= lerpf(1.0, cl * 2.0, rule.clustering)
				if HashUtils.to_unit(hsh, 0) >= density:
					continue
				var lx := cx * cell + int(HashUtils.to_unit(hsh, 1) * cell)
				var lz := cz * cell + int(HashUtils.to_unit(hsh, 2) * cell)
				lx = clampi(lx, 0, CHUNK_SIZE - 1)
				lz = clampi(lz, 0, CHUNK_SIZE - 1)
				# Props always use full-resolution heights so they sit on LOD0 terrain.
				var h := get_height_blocks(ox + lx, oz + lz) if data.lod > 0 else _column_height_local(data, w, lx, lz)
				if h < rule.min_height or h > rule.max_height:
					continue
				var slope := _max_slope_local(data, w, lx, lz) if data.lod == 0 else _max_slope_world(ox + lx, oz + lz, h)
				if slope > rule.max_slope:
					continue
				var scale := lerpf(rule.min_scale, rule.max_scale, HashUtils.to_unit(hsh, 3))
				data.props.append({
					"prop_id": rule.prop_id,
					"index": r * 4096 + cz * cells + cx,
					"position": Vector3(lx + 0.5, h * BLOCK_HEIGHT, lz + 0.5),
					"rotation": floorf(HashUtils.to_unit(hsh, 4) * 4.0) * PI * 0.5,
					"scale": scale,
				})


func _place_spawns(data: ChunkData, biome: BiomeData, ox: int, oz: int) -> void:
	for r in biome.enemy_spawns.size():
		var rule: EnemySpawnRule = biome.enemy_spawns[r]
		var hsh := HashUtils.hash4(world_seed, rule.salt + 1000, data.coord.x, data.coord.y)
		if HashUtils.to_unit(hsh, 0) >= rule.chance_per_chunk:
			continue
		var lx := 2 + int(HashUtils.to_unit(hsh, 1) * (CHUNK_SIZE - 4))
		var lz := 2 + int(HashUtils.to_unit(hsh, 2) * (CHUNK_SIZE - 4))
		var h := get_height_blocks(ox + lx, oz + lz)
		if h < rule.min_height or h > rule.max_height:
			continue
		data.spawns.append({
			"key": "%d,%d:%d" % [data.coord.x, data.coord.y, r],
			"rule_index": r,
			"position": Vector3(ox + lx + 0.5, h * BLOCK_HEIGHT + 0.2, oz + lz + 0.5),
		})


## Enemy spawn slots of a chunk without generating its mesh (cheap).
func get_spawn_slots(coord: Vector2i) -> Array:
	var d := ChunkData.new()
	d.coord = coord
	var ox := coord.x * CHUNK_SIZE
	var oz := coord.y * CHUNK_SIZE
	_place_spawns(d, get_biome(ox, oz), ox, oz)
	return d.spawns


## Finds a dry, fairly flat column near `around` for the player to spawn on.
func find_spawn_column(around: Vector2i, max_radius: int = 256) -> Vector2i:
	for r in range(0, max_radius, 3):
		var steps := maxi(1, r * 2)
		for k in steps:
			var a := TAU * float(k) / float(steps)
			var c := around + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
			var h := get_height_blocks(c.x, c.y)
			if h < SEA_LEVEL + 2 or h > 20:
				continue
			var flat := true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if absi(get_height_blocks(c.x + d.x, c.y + d.y) - h) > 1:
					flat = false
					break
			if flat:
				return c
	return around
