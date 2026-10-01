class_name Exploration
extends RefCounted
## Deterministic points of interest (Milestone 6).
##
## The world is split into CELL x CELL cells; each may hold one POI whose centre
## stays MARGIN away from the cell border (so a column is only ever affected by
## its own cell's POI). Kinds are weighted by biome; POIs keep clear of towns.
## Rank (E..S) grows with distance from the world origin, where players start.
## Thread-safe like Settlements (terrain generation reads it).

const CELL := 256
const MARGIN := 40
const POI_CHANCE := 0.6
## Distance per rank step (m): E < 700 <= D < 1400 ... S beyond 3500.
const RANK_STEP := 700.0
const SIZES := {  # kind -> [radius, blend]
	PoiInfo.Kind.RUINS: [11.0, 6.0], PoiInfo.Kind.TOWER: [7.0, 5.0], PoiInfo.Kind.TEMPLE: [15.0, 7.0],
	PoiInfo.Kind.DUNGEON: [8.0, 5.0], PoiInfo.Kind.GROVE: [10.0, 0.0],
}
## Kind weights: [ruins, tower, temple, dungeon, grove]
const WEIGHTS := {
	&"verdant_meadow": [3, 2, 1, 2.5, 1], &"whispering_forest": [3, 2, 0.5, 2.5, 2], &"emerald_jungle": [2, 1, 2, 2.5, 1.5],
	&"frostpine_taiga": [3, 2, 0.5, 2.5, 1], &"snowy_tundra": [3, 1.5, 0.5, 2.5, 0], &"sunscorch_desert": [3, 1, 2, 2.5, 0],
	&"murk_swamp": [2, 1, 0.5, 2.5, 1], &"crystal_glade": [1, 3, 1, 1.5, 2], &"stonecrown_mountains": [2, 2, 1, 2.5, 0],
}
## Dungeon theme per biome: 0 crypt, 1 arcane sanctum, 2 thornwild grotto (PoiInfo.DungeonTheme).
const THEMES := {
	&"snowy_tundra": 0, &"frostpine_taiga": 0, &"stonecrown_mountains": 0,
	&"sunscorch_desert": 1, &"crystal_glade": 1,
	&"whispering_forest": 2, &"emerald_jungle": 2, &"murk_swamp": 2,
}
const NAME_A := ["Ash", "Gloom", "Sun", "Moon", "Star", "Raven", "Thorn", "Frost", "Ember", "Shade", "Dusk", "Iron", "Silent", "Hollow", "Grim", "Old"]
const NAME_B := ["veil", "reach", "spire", "fall", "mourn", "watch", "deep", "crown", "barrow", "hold", "shard", "rest", "gate", "wood", "haunt", "vale"]
const _NONE := -1

var _gen_ref: WeakRef
var _seed: int
var _mutex := Mutex.new()
var _cells: Dictionary = {}


func _init(gen: TerrainGenerator) -> void:
	_gen_ref = weakref(gen)
	_seed = gen.world_seed


static func cell_of(wx: int, wz: int) -> Vector2i:
	return Vector2i(floori(float(wx) / CELL), floori(float(wz) / CELL))


func get_cell(c: Vector2i) -> PoiInfo:
	_mutex.lock()
	var cached = _cells.get(c, null)
	_mutex.unlock()
	if cached != null:
		return cached if cached is PoiInfo else null
	var p := _compute(c)
	_mutex.lock()
	if not _cells.has(c):
		_cells[c] = p if p else _NONE
	cached = _cells[c]
	_mutex.unlock()
	return cached if cached is PoiInfo else null


## POI whose flattened area covers the column (flattening POIs only).
func column_info(wx: int, wz: int) -> PoiInfo:
	var p := get_cell(cell_of(wx, wz))
	if p == null or not p.flatten:
		return null
	var r := p.radius + p.blend
	return p if Vector2(wx - p.center.x, wz - p.center.y).length_squared() < r * r else null


func is_inside(wx: int, wz: int, margin: float = 0.0) -> bool:
	var p := get_cell(cell_of(wx, wz))
	if p == null:
		return false
	var r := p.radius + margin
	return Vector2(wx - p.center.x, wz - p.center.y).length_squared() < r * r


func near(pos: Vector3, range_m: float) -> Array[PoiInfo]:
	var out: Array[PoiInfo] = []
	var c0 := cell_of(floori(pos.x - range_m), floori(pos.z - range_m))
	var c1 := cell_of(floori(pos.x + range_m), floori(pos.z + range_m))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var p := get_cell(Vector2i(cx, cz))
			if p and p.distance_to(pos) <= range_m:
				out.append(p)
	out.sort_custom(func(a: PoiInfo, b: PoiInfo) -> bool: return a.distance_to(pos) < b.distance_to(pos))
	return out


func find(id: String) -> PoiInfo:
	var parts := id.substr(2).split(",")
	if parts.size() != 2:
		return null
	var p := get_cell(Vector2i(int(parts[0]), int(parts[1])))
	return p if p and p.id == id else null


func _compute(c: Vector2i) -> PoiInfo:
	var gen: TerrainGenerator = _gen_ref.get_ref()
	var hsh := HashUtils.hash4(_seed, 3131, c.x, c.y)
	if HashUtils.to_unit(hsh, 0) >= POI_CHANCE:
		return null
	var span := CELL - 2 * MARGIN
	var center := Vector2i(c.x * CELL + MARGIN + int(HashUtils.to_unit(hsh, 1) * span),
		c.y * CELL + MARGIN + int(HashUtils.to_unit(hsh, 2) * span))
	var smp := gen._sample_raw(center.x, center.y)
	var h0 := TerrainGenerator.unpack_height(smp)
	var bi := TerrainGenerator.unpack_biome(smp)
	var biome := gen.biomes[bi]
	var weights: Array = WEIGHTS.get(biome.id, [])
	if weights.is_empty() or h0 < TerrainGenerator.SEA_LEVEL + 2 or h0 > 70:
		return null
	# Keep away from towns (they have their own flattened area).
	if gen.settlements.is_inside(center.x, center.y, 70.0):
		return null
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := HashUtils.to_unit(hsh, 3) * total
	var kind := 0
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			kind = i
			break
	var size: Array = SIZES[kind]
	var radius: float = size[0]
	var blend: float = size[1]
	# Dry, not too rough ground (groves may be rough; they aren't flattened).
	for ring in [0.5, 1.0, 1.0 + blend / radius]:
		for k in 8:
			var a: float = TAU * k / 8.0
			var x: int = center.x + roundi(cos(a) * radius * ring)
			var z: int = center.y + roundi(sin(a) * radius * ring)
			var h := TerrainGenerator.unpack_height(gen._sample_raw(x, z))
			if h < TerrainGenerator.SEA_LEVEL + 1 or (kind != PoiInfo.Kind.GROVE and absi(h - h0) > 5):
				return null
	var p := PoiInfo.new()
	p.kind = kind
	p.id = "p:%d,%d" % [c.x, c.y]
	p.center = center
	p.height = h0
	p.radius = radius
	p.blend = blend
	p.flatten = kind != PoiInfo.Kind.GROVE
	p.biome_index = bi
	p.biome_id = biome.id
	p.seed = HashUtils.hash4(_seed, 3232, center.x, center.y)
	p.name = NAME_A[p.seed % NAME_A.size()] + NAME_B[(p.seed / 16) % NAME_B.size()]
	var d := Vector2(center).length()
	var shift := int(HashUtils.to_unit(hsh, 4) * 3.0) - 1  # -1, 0, +1
	p.rank = clampi(int(d / RANK_STEP) + shift, 0, 5)
	p.theme = THEMES.get(biome.id, 0 if p.seed % 2 == 0 else 1)
	return p
