class_name Settlements
extends RefCounted
## Deterministic placement of villages and kingdoms (Milestone 5).
##
## The world is divided into REGION x REGION regions. Each region holds at most
## one settlement whose centre stays at least MARGIN from the region border, so
## a column can only ever be affected by the settlement of its own region.
## Every KINGDOM_REGIONS x KINGDOM_REGIONS block of regions ("realm") may have a
## kingdom capital in one of its regions; the other regions may hold villages.
## Villages within MEMBERSHIP_RANGE of a capital belong to that kingdom.
##
## Thread-safe: terrain generation calls `column_info()` from worker threads.
## Results are cached behind a mutex; computing a site only reads raw terrain.

const REGION := 384
const KINGDOM_REGIONS := 4
const MARGIN := 72
const VILLAGE_RADIUS := 36.0
const VILLAGE_BLEND := 12.0
const KINGDOM_RADIUS := 50.0
const KINGDOM_BLEND := 16.0
const VILLAGE_CHANCE := 0.55
const KINGDOM_CHANCE := 0.85
const MEMBERSHIP_RANGE := 1400.0
## Settlement ground height limits (blocks).
const MIN_HEIGHT := TerrainGenerator.SEA_LEVEL + 3
const MAX_HEIGHT := 34
const MAX_ROUGHNESS := 6

const _NONE := -1  # cached "no settlement" marker

const _PREFIX := {
	&"forest": ["Oak", "Elm", "Fern", "Moss", "Birch", "Hazel", "Thorn", "Wood"],
	&"cold": ["Frost", "White", "Ice", "Pine", "Snow", "Winter", "Grey", "Rime"],
	&"hot": ["Sun", "Dune", "Amber", "Sand", "Ochre", "Salt", "Palm", "Red"],
	&"wet": ["Reed", "Fen", "Marsh", "Willow", "Moor", "Mist", "Bog", "Rain"],
	&"any": ["Stone", "Mill", "Bright", "Green", "Gold", "Fair", "Long", "High", "Black", "Silver", "Rose", "Ash"],
}
const _SUFFIX := ["ford", "brook", "hollow", "stead", "wick", "mere", "field", "haven", "dale", "ton", "bury", "well", "gate", "crest"]
const _KINGDOM_A := ["Val", "Ald", "Eld", "Mor", "Cas", "Ther", "Ar", "Bel", "Dun", "Kor", "Lys", "Rav", "Sel", "Tor"]
const _KINGDOM_B := ["dor", "mar", "win", "gard", "the", "var", "rion", "mont", "hal", "len", "ros", "ven"]
const _KINGDOM_C := ["ia", "a", "ium", "or", "ence", "heim", "is"]
const BANNER_COLORS := [Color(0.75, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.2, 0.6, 0.25), Color(0.6, 0.2, 0.7),
	Color(0.85, 0.6, 0.1), Color(0.1, 0.6, 0.65), Color(0.85, 0.85, 0.85), Color(0.2, 0.2, 0.25)]

var _gen_ref: WeakRef
var _seed: int
var _mutex := Mutex.new()
var _regions: Dictionary = {}   # Vector2i -> SettlementInfo or _NONE
var _realms: Dictionary = {}    # Vector2i -> Dictionary {region, center, height} or {}


func _init(gen: TerrainGenerator) -> void:
	_gen_ref = weakref(gen)
	_seed = gen.world_seed


func _gen() -> TerrainGenerator:
	return _gen_ref.get_ref() as TerrainGenerator


static func region_of(wx: int, wz: int) -> Vector2i:
	return Vector2i(floori(float(wx) / REGION), floori(float(wz) / REGION))


static func realm_of(region: Vector2i) -> Vector2i:
	return Vector2i(floori(float(region.x) / KINGDOM_REGIONS), floori(float(region.y) / KINGDOM_REGIONS))


# --- Queries ----------------------------------------------------------------------------

## The settlement of the region containing the column (or null).
func in_region_of(wx: int, wz: int) -> SettlementInfo:
	return get_region(region_of(wx, wz))


## Settlement whose flattened area (radius + blend) covers the column, or null.
func column_info(wx: int, wz: int) -> SettlementInfo:
	var s := in_region_of(wx, wz)
	if s == null:
		return null
	var dx := float(wx - s.center.x)
	var dz := float(wz - s.center.y)
	var r := s.radius + s.blend
	return s if dx * dx + dz * dz < r * r else null


## True when the column is inside a settlement (+ margin metres).
func is_inside(wx: int, wz: int, margin: float = 0.0) -> bool:
	var s := in_region_of(wx, wz)
	if s == null:
		return false
	var r := s.radius + margin
	return Vector2(wx - s.center.x, wz - s.center.y).length_squared() < r * r


## All settlements whose centre is within `range_m` of `pos`, nearest first.
func near(pos: Vector3, range_m: float) -> Array[SettlementInfo]:
	var out: Array[SettlementInfo] = []
	var r0 := region_of(floori(pos.x - range_m), floori(pos.z - range_m))
	var r1 := region_of(floori(pos.x + range_m), floori(pos.z + range_m))
	for rz in range(r0.y, r1.y + 1):
		for rx in range(r0.x, r1.x + 1):
			var s := get_region(Vector2i(rx, rz))
			if s and s.distance_to(pos) <= range_m:
				out.append(s)
	out.sort_custom(func(a: SettlementInfo, b: SettlementInfo) -> bool: return a.distance_to(pos) < b.distance_to(pos))
	return out


## Settlement by id ("v:rx,rz" or "k:rx,rz").
func find(id: String) -> SettlementInfo:
	var parts := id.substr(2).split(",")
	if parts.size() != 2:
		return null
	var s := get_region(Vector2i(int(parts[0]), int(parts[1])))
	return s if s and s.id == id else null


# --- Generation ---------------------------------------------------------------------------

func get_region(r: Vector2i) -> SettlementInfo:
	_mutex.lock()
	var cached = _regions.get(r, null)
	_mutex.unlock()
	if cached != null:
		return cached if cached is SettlementInfo else null
	var s := _compute_region(r)
	_mutex.lock()
	if not _regions.has(r):
		_regions[r] = s if s else _NONE
	cached = _regions[r]
	_mutex.unlock()
	return cached if cached is SettlementInfo else null


func _realm(k: Vector2i) -> Dictionary:
	_mutex.lock()
	var cached = _realms.get(k, null)
	_mutex.unlock()
	if cached != null:
		return cached
	var d := _compute_realm(k)
	_mutex.lock()
	if not _realms.has(k):
		_realms[k] = d
	d = _realms[k]
	_mutex.unlock()
	return d


func _compute_realm(k: Vector2i) -> Dictionary:
	var hsh := HashUtils.hash4(_seed, 5151, k.x, k.y)
	if HashUtils.to_unit(hsh, 0) >= KINGDOM_CHANCE:
		return {}
	# Try the realm's regions in a seeded order; the first good site is the capital.
	var order: Array = []
	for i in KINGDOM_REGIONS * KINGDOM_REGIONS:
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := int(HashUtils.to_unit(hsh, 10 + i) * (i + 1))
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	for idx in order:
		var region := Vector2i(k.x * KINGDOM_REGIONS + idx % KINGDOM_REGIONS, k.y * KINGDOM_REGIONS + idx / KINGDOM_REGIONS)
		for attempt in 2:
			var c := _candidate(region, 6000 + attempt)
			var h := _site_height(c, KINGDOM_RADIUS, KINGDOM_BLEND)
			if h != _NONE_HEIGHT:
				return {"region": region, "center": c, "height": h}
	return {}


const _NONE_HEIGHT := -99999


func _candidate(region: Vector2i, salt: int) -> Vector2i:
	var hsh := HashUtils.hash4(_seed, salt, region.x, region.y)
	var span := REGION - 2 * MARGIN
	return Vector2i(region.x * REGION + MARGIN + int(HashUtils.to_unit(hsh, 1) * span),
		region.y * REGION + MARGIN + int(HashUtils.to_unit(hsh, 2) * span))


## Flattened height (blocks) if the site is dry, not too rough and on ordinary land.
func _site_height(c: Vector2i, radius: float, blend: float) -> int:
	var gen := _gen()
	var smp := gen._sample_raw(c.x, c.y)
	var h0 := TerrainGenerator.unpack_height(smp)
	if h0 < MIN_HEIGHT or h0 > MAX_HEIGHT:
		return _NONE_HEIGHT
	if gen.biomes[TerrainGenerator.unpack_biome(smp)].role != BiomeData.Role.LAND:
		return _NONE_HEIGHT
	for ring in [0.35, 0.7, 1.0, 1.0 + blend * 0.6 / radius]:
		for k in 12:
			var a: float = TAU * k / 12.0 + ring
			var x: int = c.x + roundi(cos(a) * radius * ring)
			var z: int = c.y + roundi(sin(a) * radius * ring)
			var h := TerrainGenerator.unpack_height(gen._sample_raw(x, z))
			if h < TerrainGenerator.SEA_LEVEL + 2 or absi(h - h0) > MAX_ROUGHNESS:
				return _NONE_HEIGHT
	return h0


func _compute_region(r: Vector2i) -> SettlementInfo:
	var realm := _realm(realm_of(r))
	if not realm.is_empty() and realm.region == r:
		return _make(SettlementInfo.Type.KINGDOM, r, realm.center, realm.height)
	var hsh := HashUtils.hash4(_seed, 4242, r.x, r.y)
	if HashUtils.to_unit(hsh, 0) >= VILLAGE_CHANCE:
		return null
	for attempt in 3:
		var c := _candidate(r, 7000 + attempt)
		var h := _site_height(c, VILLAGE_RADIUS, VILLAGE_BLEND)
		if h != _NONE_HEIGHT:
			return _make(SettlementInfo.Type.VILLAGE, r, c, h)
	return null


func _make(type: int, r: Vector2i, c: Vector2i, h: int) -> SettlementInfo:
	var gen := _gen()
	var s := SettlementInfo.new()
	s.type = type
	s.id = "%s:%d,%d" % ["k" if type == SettlementInfo.Type.KINGDOM else "v", r.x, r.y]
	s.center = c
	s.height = h
	s.seed = HashUtils.hash4(_seed, 9090, c.x, c.y)
	s.biome_index = TerrainGenerator.unpack_biome(gen._sample_raw(c.x, c.y))
	s.biome_id = gen.biomes[s.biome_index].id
	if type == SettlementInfo.Type.KINGDOM:
		s.radius = KINGDOM_RADIUS
		s.blend = KINGDOM_BLEND
		s.kingdom_name = kingdom_name_for(realm_of(r))
		s.kingdom_id = s.id
		s.name = capital_name_for(realm_of(r))
		s.color = BANNER_COLORS[HashUtils.hash3(_seed, r.x, r.y) % BANNER_COLORS.size()]
	else:
		s.radius = VILLAGE_RADIUS
		s.blend = VILLAGE_BLEND
		s.name = _village_name(s)
		_assign_kingdom(s)
	return s


func kingdom_name_for(realm: Vector2i) -> String:
	var hsh := HashUtils.hash4(_seed, 8181, realm.x, realm.y)
	return _pick(_KINGDOM_A, hsh, 1) + _pick(_KINGDOM_B, hsh, 2) + _pick(_KINGDOM_C, hsh, 3)


## The capital shares the kingdom's root: Kingdom of Valdoria -> Valdor.
func capital_name_for(realm: Vector2i) -> String:
	var hsh := HashUtils.hash4(_seed, 8181, realm.x, realm.y)
	return _pick(_KINGDOM_A, hsh, 1) + _pick(_KINGDOM_B, hsh, 2)


func _village_name(s: SettlementInfo) -> String:
	var group := &"any"
	match s.biome_id:
		&"whispering_forest", &"emerald_jungle":
			group = &"forest"
		&"frostpine_taiga", &"snowy_tundra":
			group = &"cold"
		&"sunscorch_desert":
			group = &"hot"
		&"murk_swamp":
			group = &"wet"
	var pool: Array = _PREFIX[group] if HashUtils.to_unit(s.seed, 1) < 0.6 else _PREFIX[&"any"]
	return _pick(pool, s.seed, 2) + _pick(_SUFFIX, s.seed, 3)


static func _pick(list: Array, hsh: int, salt: int) -> String:
	return list[int(HashUtils.to_unit(hsh, salt) * list.size()) % list.size()]


## Villages belong to the nearest kingdom capital within MEMBERSHIP_RANGE.
func _assign_kingdom(s: SettlementInfo) -> void:
	var k0 := realm_of(region_of(s.center.x, s.center.y))
	var best := MEMBERSHIP_RANGE
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := k0 + Vector2i(dx, dz)
			var realm := _realm(k)
			if realm.is_empty():
				continue
			var d := Vector2(realm.center - s.center).length()
			if d < best:
				best = d
				s.kingdom_id = "k:%d,%d" % [realm.region.x, realm.region.y]
				s.kingdom_name = kingdom_name_for(k)
				s.color = BANNER_COLORS[HashUtils.hash3(_seed, realm.region.x, realm.region.y) % BANNER_COLORS.size()]
