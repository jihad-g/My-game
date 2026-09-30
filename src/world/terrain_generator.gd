class_name TerrainGenerator
extends RefCounted
## Deterministic, thread-safe procedural world generation.
##
## The world is an infinite field of block columns (voxel-inspired) on two
## layers:
##   SURFACE      - continents, oceans, islands, mountains, lakes, rivers,
##                  11 biomes chosen from continuous climate fields.
##   UNDERGROUND  - a cave network under the whole world (tunnels + caverns),
##                  reached through cave entrances on the surface.
##
## Everything is a pure function of (seed, coordinates): the same seed produces
## the same world on any machine, in any load order. Terrain shape comes from
## continuous noise fields, so biome borders never create seams; biomes only
## classify columns (colours, vegetation, resources, enemies).
##
## Coordinates:
##   - 1 block = 1 m horizontally, BLOCK_HEIGHT m vertically.
##   - A chunk is CHUNK_SIZE x CHUNK_SIZE columns.
##   - World column (wx, wz) belongs to chunk floor(wx / CHUNK_SIZE).
##
## There is no world border. At the ~3,000,000 chunk target the world spans
## roughly +-14,000 m from the origin, within float precision limits.

enum Layer { SURFACE = 0, UNDERGROUND = 1 }

const CHUNK_SIZE := 16
const BLOCK_HEIGHT := 0.5
## Columns with a top below this block height are underwater.
const SEA_LEVEL := 0
const WATER_Y := -0.15
## Downward "skirt" on chunk edges to hide LOD seams.
const SKIRT_BLOCKS := 6
## Cave floor level in blocks (-120 m), far below any surface terrain.
const CAVE_FLOOR := -240
const CAVE_WALL_HEIGHT := 5
## Surface props/structures keep this distance (blocks) from cave entrances.
const ENTRANCE_CLEARANCE := 2.5

const _HEIGHT_BIAS := 1024

var world_seed: int
var settings: WorldGenSettings
var biomes: Array[BiomeData] = []

var _land_biomes: PackedInt32Array = PackedInt32Array()
var _rare_biomes: PackedInt32Array = PackedInt32Array()
var _ocean_biome := 0
var _beach_biome := 0
var _mountain_biome := 0
var _cave_biome := 0
var _fallback_biome := 0

var _continent := FastNoiseLite.new()
var _island := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _dune := FastNoiseLite.new()
var _lake := FastNoiseLite.new()
var _river := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _temperature := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _regional := FastNoiseLite.new()
var _rarity := FastNoiseLite.new()
var _cluster := FastNoiseLite.new()
var _cave_tunnel := FastNoiseLite.new()
var _cave_tunnel2 := FastNoiseLite.new()
var _cave_cavern := FastNoiseLite.new()
var _cave_floor := FastNoiseLite.new()


func _init(p_seed: int, p_settings: WorldGenSettings) -> void:
	world_seed = p_seed
	settings = p_settings
	var s := settings
	_setup_noise(_continent, 1, s.continent_frequency, 4)
	_setup_noise(_island, 2, s.island_frequency, 2)
	_setup_noise(_hills, 3, s.hill_frequency, 2)
	_setup_noise(_mountain, 4, s.mountain_mask_frequency, 2)
	_setup_noise(_ridge, 5, s.ridge_frequency, 3)
	_setup_noise(_detail, 6, s.detail_frequency, 1)
	_setup_noise(_dune, 7, s.dune_frequency, 1)
	_setup_noise(_lake, 8, s.lake_frequency, 2)
	_setup_noise(_river, 9, s.river_frequency, 1)
	_setup_noise(_warp, 10, s.river_frequency * 4.0, 2)
	_setup_noise(_temperature, 11, s.temperature_frequency, 3)
	_setup_noise(_moisture, 12, s.moisture_frequency, 3)
	_setup_noise(_regional, 13, 0.01, 1)
	_setup_noise(_rarity, 14, 0.004, 2)
	_setup_noise(_cluster, 15, 0.03, 2)
	# Single-octave noise gives smooth contours => continuous winding tunnels.
	_setup_noise(_cave_tunnel, 16, s.cave_tunnel_frequency, 1)
	_setup_noise(_cave_tunnel2, 17, s.cave_tunnel_frequency * 0.63, 1)
	_setup_noise(_cave_cavern, 18, s.cave_cavern_frequency, 1)
	_setup_noise(_cave_floor, 19, 0.06, 1)
	for b in s.biomes:
		biomes.append(b as BiomeData)
	for i in biomes.size():
		match biomes[i].role:
			BiomeData.Role.LAND:
				_land_biomes.append(i)
			BiomeData.Role.RARE:
				_rare_biomes.append(i)
			BiomeData.Role.OCEAN:
				_ocean_biome = i
			BiomeData.Role.BEACH:
				_beach_biome = i
			BiomeData.Role.MOUNTAIN:
				_mountain_biome = i
			BiomeData.Role.UNDERGROUND:
				_cave_biome = i
	# The last LAND biome is the catch-all (list it last with full ranges).
	if not _land_biomes.is_empty():
		_fallback_biome = _land_biomes[_land_biomes.size() - 1]


func _setup_noise(n: FastNoiseLite, salt: int, frequency: float, octaves: int) -> void:
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = HashUtils.hash3(world_seed, salt, 0x51ed)
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves


static func _ss(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# --- Coordinates -------------------------------------------------------------

static func world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK_SIZE), floori(pos.z / CHUNK_SIZE))


static func column_to_chunk(wx: int, wz: int) -> Vector2i:
	return Vector2i(floori(float(wx) / CHUNK_SIZE), floori(float(wz) / CHUNK_SIZE))


static func layer_of_height(y: float) -> int:
	return Layer.UNDERGROUND if y < CAVE_FLOOR * BLOCK_HEIGHT * 0.5 else Layer.SURFACE


# --- Climate -------------------------------------------------------------------

## 0 (arctic) .. 1 (tropical)
func temperature01(x: float, z: float) -> float:
	return clampf(_temperature.get_noise_2d(x, z) * settings.climate_contrast + 0.5, 0.0, 1.0)


## 0 (arid) .. 1 (soaked)
func moisture01(x: float, z: float) -> float:
	return clampf(_moisture.get_noise_2d(x, z) * settings.climate_contrast + 0.5, 0.0, 1.0)


## Air temperature at sea level (deg C) and day/night half-swing at a position.
## Continuous everywhere, so walking across a biome border never jumps.
func get_climate(pos: Vector3) -> Vector2:
	var t := temperature01(pos.x, pos.z)
	var m := moisture01(pos.x, pos.z)
	var s := settings
	var base := lerpf(s.coldest_temperature, s.hottest_temperature, t)
	base += _regional.get_noise_2d(pos.x, pos.z) * s.regional_variation
	var swing := lerpf(s.dry_day_night_swing, s.wet_day_night_swing, m)
	return Vector2(base, swing)


# --- Surface sampling ----------------------------------------------------------

## Samples one surface column: height (blocks) and biome index, packed into an
## int (see unpack helpers). This is the single source of truth for terrain.
func sample_column(wx: int, wz: int) -> int:
	var s := settings
	var x := float(wx)
	var z := float(wz)
	var c := _continent.get_noise_2d(x, z)
	var land := _ss(s.coast_start, s.coast_end, c)
	var h := lerpf(s.ocean_depth, s.land_base, land) + maxf(c - s.coast_end, 0.0) * s.continent_amplitude

	# Islands scattered through the oceans.
	if land < 1.0:
		var isl := _island.get_noise_2d(x, z)
		if isl > s.island_threshold:
			var it := _ss(s.island_threshold, s.island_threshold + 0.15, isl) * (1.0 - land)
			h = lerpf(h, 3.0 + (isl - s.island_threshold) * 30.0, it)
			land = maxf(land, it)

	var hills := _hills.get_noise_2d(x, z) * 0.5 + 0.5
	h += hills * hills * s.hill_amplitude * land

	var mm := _ss(s.mountain_mask_start, s.mountain_mask_end, _mountain.get_noise_2d(x, z)) * land
	if mm > 0.0:
		var r := 1.0 - absf(_ridge.get_noise_2d(x, z))
		h += mm * (0.3 + 0.7 * r * r) * s.mountain_amplitude

	var t := temperature01(x, z)
	var m := moisture01(x, z)
	var detail := _detail.get_noise_2d(x, z)

	# Swamps: warm + wet lowlands flatten to just above the water line.
	var sw := _ss(0.62, 0.74, m) * _ss(0.46, 0.58, t) * (1.0 - mm) * land
	if sw > 0.0:
		# Target hovers around the water line: pools, mud flats and hummocks.
		h = lerpf(h, -0.2 + detail * 2.4, sw)
	# Deserts: hot + dry lands get dunes.
	var ar := _ss(0.34, 0.22, m) * _ss(0.58, 0.7, t) * land
	if ar > 0.0:
		h += (_dune.get_noise_2d(x, z) * 0.5 + 0.5) * s.dune_amplitude * ar
	# Lakes.
	var lk := _ss(s.lake_threshold, s.lake_threshold + 0.14, _lake.get_noise_2d(x, z)) * (1.0 - mm) * land
	if lk > 0.0:
		h = lerpf(h, -4.0, lk)
	# Rivers: meandering channels at sea level; they fade out in high mountains.
	var rmask := land * (1.0 - _ss(0.2, 0.5, mm))
	if rmask > 0.0:
		var warp_x := _warp.get_noise_2d(x, z) * s.river_warp
		var warp_z := _warp.get_noise_2d(z + 913.0, x - 377.0) * s.river_warp
		var rv := absf(_river.get_noise_2d(x + warp_x, z + warp_z))
		var rt := _ss(s.river_valley_width, s.river_width, rv) * rmask
		if rt > 0.0:
			h = lerpf(h, -3.0, rt)
			if rv < s.river_width * 0.55 and rmask > 0.6:
				h = minf(h, -5.0)

	h += detail * s.detail_amplitude
	var hb := floori(h)
	# Small-scale jitter so biome borders wiggle instead of following the
	# (locally almost straight) climate contours.
	var jitter := _regional.get_noise_2d(z * 1.7, x * 1.7) * 0.035
	var biome := _pick_biome(hb, land, mm, t + jitter, m - jitter, x, z)
	return (hb + _HEIGHT_BIAS) | (biome << 16)


static func unpack_height(sample: int) -> int:
	return (sample & 0xFFFF) - _HEIGHT_BIAS


static func unpack_biome(sample: int) -> int:
	return sample >> 16


func _pick_biome(h: int, land: float, mm: float, t: float, m: float, x: float, z: float) -> int:
	if h < SEA_LEVEL - 5 and land < 0.6:
		return _ocean_biome
	if h <= SEA_LEVEL + 1 and land < 0.95 and t > 0.3:
		return _beach_biome
	if h >= 52 or (mm > 0.55 and h > 26):
		return _mountain_biome
	if h > SEA_LEVEL + 1 and not _rare_biomes.is_empty():
		var rarity := _rarity.get_noise_2d(x, z) * 0.5 + 0.5
		for i in _rare_biomes:
			if rarity > biomes[i].rare_threshold:
				return i
	for i in _land_biomes:
		var b := biomes[i]
		if t >= b.temperature_min and t <= b.temperature_max and m >= b.moisture_min and m <= b.moisture_max:
			return i
	return _fallback_biome


## Surface height of column (wx, wz) in blocks.
func get_height_blocks(wx: int, wz: int) -> int:
	return unpack_height(sample_column(wx, wz))


func get_biome_index(wx: int, wz: int) -> int:
	return unpack_biome(sample_column(wx, wz))


func get_biome(wx: int, wz: int) -> BiomeData:
	return biomes[get_biome_index(wx, wz)]


func get_biome_at(pos: Vector3, layer: int = Layer.SURFACE) -> BiomeData:
	if layer == Layer.UNDERGROUND:
		return biomes[_cave_biome]
	return get_biome(floori(pos.x), floori(pos.z))


## Ground height in metres (top of the column) on the given layer.
func get_height_at(pos: Vector3, layer: int = Layer.SURFACE) -> float:
	var wx := floori(pos.x)
	var wz := floori(pos.z)
	if layer == Layer.UNDERGROUND:
		return get_cave_height_blocks(wx, wz, get_cave_entrances_near(wx, wz, wx, wz)) * BLOCK_HEIGHT
	return get_height_blocks(wx, wz) * BLOCK_HEIGHT


# --- Caves ---------------------------------------------------------------------------

## Cave entrances (world column positions) whose cells overlap the given
## column rectangle expanded by the room radius.
func get_cave_entrances_near(min_x: int, min_z: int, max_x: int, max_z: int) -> Array[Vector2i]:
	var cell := settings.cave_entrance_cell
	var margin := ceili(settings.cave_room_radius) + 2
	var out: Array[Vector2i] = []
	for cz in range(floori(float(min_z - margin) / cell), floori(float(max_z + margin) / cell) + 1):
		for cx in range(floori(float(min_x - margin) / cell), floori(float(max_x + margin) / cell) + 1):
			var e := _entrance_in_cell(cx, cz)
			if e.x != 0x7FFFFFFF:
				out.append(e)
	return out


## Returns the entrance column of an entrance cell, or (0x7FFFFFFF, 0) if none.
func _entrance_in_cell(cx: int, cz: int) -> Vector2i:
	var none := Vector2i(0x7FFFFFFF, 0)
	var cell := settings.cave_entrance_cell
	var hsh := HashUtils.hash4(world_seed, 7777, cx, cz)
	if HashUtils.to_unit(hsh, 0) >= settings.cave_entrance_chance:
		return none
	var ex := cx * cell + 8 + int(HashUtils.to_unit(hsh, 1) * (cell - 16))
	var ez := cz * cell + 8 + int(HashUtils.to_unit(hsh, 2) * (cell - 16))
	var smp := sample_column(ex, ez)
	var h := unpack_height(smp)
	var b := biomes[unpack_biome(smp)]
	if h < SEA_LEVEL + 2 or h > 70 or b.role == BiomeData.Role.OCEAN or b.role == BiomeData.Role.BEACH:
		return none
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if absi(get_height_blocks(ex + d.x, ez + d.y) - h) > 1:
			return none
	return Vector2i(ex, ez)


func is_cave_open(wx: int, wz: int, entrances: Array[Vector2i]) -> bool:
	var r2 := settings.cave_room_radius * settings.cave_room_radius
	for e in entrances:
		var dx := float(wx - e.x)
		var dz := float(wz - e.y)
		if dx * dx + dz * dz <= r2:
			return true
	var x := float(wx)
	var z := float(wz)
	var w := settings.cave_tunnel_width
	if absf(_cave_tunnel.get_noise_2d(x, z)) < w * 0.5:
		return true
	if absf(_cave_tunnel2.get_noise_2d(x, z)) < w * 0.4:
		return true
	return _cave_cavern.get_noise_2d(x, z) > settings.cave_cavern_threshold


func get_cave_height_blocks(wx: int, wz: int, entrances: Array[Vector2i]) -> int:
	var v := int((_cave_floor.get_noise_2d(float(wx), float(wz)) * 0.5 + 0.5) * 2.0)
	if is_cave_open(wx, wz, entrances):
		return CAVE_FLOOR + v
	return CAVE_FLOOR + CAVE_WALL_HEIGHT + v


# --- Chunk generation (thread-safe: reads only immutable state) --------------

func generate_chunk(coord: Vector2i, lod: int, layer: int = Layer.SURFACE) -> ChunkData:
	var data := ChunkData.new()
	data.coord = coord
	data.lod = lod
	data.layer = layer
	data.step = 1 << lod
	var step := data.step
	var n := CHUNK_SIZE / step
	var w := n + 2
	var ox := coord.x * CHUNK_SIZE
	var oz := coord.y * CHUNK_SIZE
	var entrances := get_cave_entrances_near(ox - step, oz - step, ox + CHUNK_SIZE + step, oz + CHUNK_SIZE + step)

	data.heights.resize(w * w)
	data.biomes.resize(w * w)
	var hmin := 1 << 30
	var hmax := -(1 << 30)
	for j in w:
		for i in w:
			var wx := ox + (i - 1) * step
			var wz := oz + (j - 1) * step
			var h: int
			var b: int
			if layer == Layer.UNDERGROUND:
				h = get_cave_height_blocks(wx, wz, entrances)
				b = _cave_biome
			else:
				var smp := sample_column(wx, wz)
				h = unpack_height(smp)
				b = unpack_biome(smp)
			data.heights[j * w + i] = h
			data.biomes[j * w + i] = b
			if i > 0 and j > 0 and i <= n and j <= n:
				hmin = mini(hmin, h)
				hmax = maxi(hmax, h)
	data.min_height = hmin
	data.max_height = hmax

	_build_surface(data, n, w, ox, oz)
	if lod == 0:
		_build_collision(data)
		_place_features(data, entrances, ox, oz)
	if lod <= 1:
		_place_props(data, w, ox, oz, entrances)
	if lod == 0 and layer == Layer.SURFACE:
		data.spawns = get_spawn_slots(coord)
	return data


func _build_surface(data: ChunkData, n: int, w: int, ox: int, oz: int) -> void:
	var step := data.step
	var bh := BLOCK_HEIGHT
	var surface := data.layer == Layer.SURFACE
	for j in n:
		for i in n:
			var k := (j + 1) * w + (i + 1)
			var h := data.heights[k]
			var biome := biomes[data.biomes[k]]
			var x0 := float(i * step)
			var x1 := x0 + step
			var z0 := float(j * step)
			var z1 := z0 + step
			var y := h * bh
			var wx := ox + i * step
			var wz := oz + j * step
			var top := _top_color(biome, h, wx, wz, surface)
			_quad(data.vertices, data.normals, data.colors, data.indices,
				Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
				Vector3.UP, top)
			# Side walls where the neighbour is lower; always on chunk borders (skirt).
			_side(data, biome, h, data.heights[k + 1], i == n - 1,
				Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.RIGHT, wx, wz, surface)
			_side(data, biome, h, data.heights[k - 1], i == 0,
				Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.LEFT, wx, wz, surface)
			_side(data, biome, h, data.heights[k + w], j == n - 1,
				Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.BACK, wx, wz, surface)
			_side(data, biome, h, data.heights[k - w], j == 0,
				Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.FORWARD, wx, wz, surface)
			if surface and h < SEA_LEVEL:
				if biome.frozen_water:
					# Walkable ice sheet: part of the terrain mesh (and collision).
					var ice := biome.ice_color * (0.97 + HashUtils.to_unit(HashUtils.hash3(wx, wz, 5), 1) * 0.06)
					_quad(data.vertices, data.normals, data.colors, data.indices,
						Vector3(x0, WATER_Y, z0), Vector3(x1, WATER_Y, z0), Vector3(x1, WATER_Y, z1), Vector3(x0, WATER_Y, z1),
						Vector3.UP, ice)
				else:
					var wv := data.water_vertices
					var base := wv.size()
					wv.append_array([Vector3(x0, WATER_Y, z0), Vector3(x1, WATER_Y, z0),
						Vector3(x1, WATER_Y, z1), Vector3(x0, WATER_Y, z1)])
					BlockMesh.append_quad_indices(data.water_indices, base, wv[base], wv[base + 1], wv[base + 2], Vector3.UP)


func _side(data: ChunkData, biome: BiomeData, h: int, nh: int, border: bool,
		a: Vector3, b: Vector3, normal: Vector3, wx: int, wz: int, surface: bool) -> void:
	var bottom := nh
	if border:
		bottom = mini(nh, h) - SKIRT_BLOCKS
	if bottom >= h:
		return
	var bh := BLOCK_HEIGHT
	var top_y := h * bh
	var shade := 0.72 if normal.z != 0.0 else 0.8
	# Top band: one block of "grass edge" (or rock/sand), rest dirt/stone below.
	var edge_col := _top_color(biome, h, wx, wz, surface) * shade
	var body_col := _side_color(biome, h, surface) * shade
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


func _top_color(biome: BiomeData, h: int, wx: int, wz: int, surface: bool) -> Color:
	var c: Color
	if not surface:
		c = biome.rock_color if h > CAVE_FLOOR + 2 else biome.top_color.lerp(biome.top_color_alt,
			HashUtils.to_unit(HashUtils.hash3(wx, wz, world_seed), 3))
	elif h < SEA_LEVEL:
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


func _side_color(biome: BiomeData, h: int, surface: bool) -> Color:
	if not surface:
		return biome.rock_color * 0.8
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


func _place_features(data: ChunkData, entrances: Array[Vector2i], ox: int, oz: int) -> void:
	for e in entrances:
		if e.x < ox or e.x >= ox + CHUNK_SIZE or e.y < oz or e.y >= oz + CHUNK_SIZE:
			continue
		var lx := e.x - ox
		var lz := e.y - oz
		var h := data.heights[(lz + 1) * (CHUNK_SIZE + 2) + (lx + 1)]
		data.features.append({
			"type": &"cave_entrance" if data.layer == Layer.SURFACE else &"cave_exit",
			"position": Vector3(lx + 0.5, h * BLOCK_HEIGHT, lz + 0.5),
			"key": "%d,%d" % [e.x, e.y],
		})


static func _near_entrance(wx: int, wz: int, entrances: Array[Vector2i], radius: float) -> bool:
	for e in entrances:
		if Vector2(wx - e.x, wz - e.y).length() <= radius:
			return true
	return false


func _column_height_local(data: ChunkData, w: int, lx: int, lz: int) -> int:
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


func _column_height_any(layer: int, wx: int, wz: int, entrances: Array[Vector2i]) -> int:
	if layer == Layer.UNDERGROUND:
		return get_cave_height_blocks(wx, wz, entrances)
	return get_height_blocks(wx, wz)


func _max_slope_world(layer: int, wx: int, wz: int, h: int, entrances: Array[Vector2i]) -> int:
	var s := absi(h - _column_height_any(layer, wx + 1, wz, entrances))
	s = maxi(s, absi(h - _column_height_any(layer, wx - 1, wz, entrances)))
	s = maxi(s, absi(h - _column_height_any(layer, wx, wz + 1, entrances)))
	s = maxi(s, absi(h - _column_height_any(layer, wx, wz - 1, entrances)))
	return s


## Stable id of a biome's prop rule, used in prop indices (persisted in saves).
static func rule_uid(biome_index: int, rule_index: int) -> int:
	return biome_index * 64 + rule_index


func _place_props(data: ChunkData, w: int, ox: int, oz: int, entrances: Array[Vector2i]) -> void:
	# Biomes present in this chunk (at this LOD's resolution).
	var present := {}
	for j in range(1, w - 1):
		for i in range(1, w - 1):
			present[data.biomes[j * w + i]] = true
	for b: int in present:
		var biome := biomes[b]
		for r in biome.prop_rules.size():
			var rule: PropRule = biome.prop_rules[r]
			if data.lod > 0 and not rule.show_in_lod1:
				continue
			_place_rule(data, w, ox, oz, entrances, b, r, rule)


func _place_rule(data: ChunkData, w: int, ox: int, oz: int, entrances: Array[Vector2i],
		b: int, r: int, rule: PropRule) -> void:
	var cell := rule.cell_size
	var cells := CHUNK_SIZE / cell
	var uid := rule_uid(b, r)
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
			var lx := clampi(cx * cell + int(HashUtils.to_unit(hsh, 1) * cell), 0, CHUNK_SIZE - 1)
			var lz := clampi(cz * cell + int(HashUtils.to_unit(hsh, 2) * cell), 0, CHUNK_SIZE - 1)
			# Props always use full-resolution columns so they sit on LOD0 terrain.
			var h: int
			var col_biome: int
			if data.lod == 0:
				var k := (lz + 1) * w + (lx + 1)
				h = data.heights[k]
				col_biome = data.biomes[k]
			elif data.layer == Layer.UNDERGROUND:
				h = get_cave_height_blocks(ox + lx, oz + lz, entrances)
				col_biome = _cave_biome
			else:
				var smp := sample_column(ox + lx, oz + lz)
				h = unpack_height(smp)
				col_biome = unpack_biome(smp)
			if col_biome != b:
				continue
			if h < rule.min_height or h > rule.max_height:
				continue
			if rule.on_water and h >= SEA_LEVEL:
				continue
			var slope := _max_slope_local(data, w, lx, lz) if data.lod == 0 \
				else _max_slope_world(data.layer, ox + lx, oz + lz, h, entrances)
			if slope > rule.max_slope and not rule.on_water:
				continue
			if _near_entrance(ox + lx, oz + lz, entrances, ENTRANCE_CLEARANCE):
				continue
			var y := WATER_Y + 0.02 if rule.on_water else h * BLOCK_HEIGHT
			data.props.append({
				"prop_id": rule.prop_id,
				"index": uid * 4096 + cz * cells + cx,
				"position": Vector3(lx + 0.5, y, lz + 0.5),
				"rotation": floorf(HashUtils.to_unit(hsh, 4) * 4.0) * PI * 0.5,
				"scale": lerpf(rule.min_scale, rule.max_scale, HashUtils.to_unit(hsh, 3)),
			})


## Enemy spawn slots of a surface chunk without generating its mesh (cheap).
## Slots use the biome at the chunk centre.
func get_spawn_slots(coord: Vector2i) -> Array:
	var out := []
	var ox := coord.x * CHUNK_SIZE
	var oz := coord.y * CHUNK_SIZE
	var b := get_biome_index(ox + CHUNK_SIZE / 2, oz + CHUNK_SIZE / 2)
	var biome := biomes[b]
	for r in biome.enemy_spawns.size():
		var rule: EnemySpawnRule = biome.enemy_spawns[r]
		var hsh := HashUtils.hash4(world_seed, rule.salt + 1000, coord.x, coord.y)
		if HashUtils.to_unit(hsh, 0) >= rule.chance_per_chunk:
			continue
		var lx := 2 + int(HashUtils.to_unit(hsh, 1) * (CHUNK_SIZE - 4))
		var lz := 2 + int(HashUtils.to_unit(hsh, 2) * (CHUNK_SIZE - 4))
		var h := get_height_blocks(ox + lx, oz + lz)
		if h < rule.min_height or h > rule.max_height:
			continue
		out.append({
			"key": "%d,%d:%d:%d" % [coord.x, coord.y, b, r],
			"rule": rule,
			"position": Vector3(ox + lx + 0.5, h * BLOCK_HEIGHT + 0.2, oz + lz + 0.5),
		})
	return out


## Finds a dry, fairly flat column near `around` for the player to spawn on,
## preferring friendly starting biomes.
func find_spawn_column(around: Vector2i, preferred: Array = [&"verdant_meadow", &"whispering_forest"], max_radius: int = 3000) -> Vector2i:
	for pass_i in 2:
		for r in range(0, max_radius, 12):
			var steps := maxi(1, r / 6)
			for k in steps:
				var a := TAU * float(k) / float(steps)
				var c := around + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
				var smp := sample_column(c.x, c.y)
				var h := unpack_height(smp)
				if h < SEA_LEVEL + 2 or h > 24:
					continue
				if pass_i == 0 and not biomes[unpack_biome(smp)].id in preferred:
					continue
				var flat := true
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if absi(get_height_blocks(c.x + d.x, c.y + d.y) - h) > 1:
						flat = false
						break
				if flat:
					return c
	return around
