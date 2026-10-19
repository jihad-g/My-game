class_name NavGrid
extends RefCounted
## Monster pathfinding (Milestone 25): A* on the 1 m building grid.
##
## The walk grid is made on demand in 16 x 16 tiles (one per terrain chunk)
## and kept for a few seconds:
##   - ground height of each 1 m column, from the loaded chunk data (the same
##     numbers the terrain mesh was built from), in blocks of 0.5 m;
##   - obstacles from physics: player buildings, village and ruin walls, trees,
##     rocks, dungeon doors and gates. Each solid shape marks the cells it
##     stands on, and thin walls mark the cell EDGES they stand on (a wall on
##     the north edge of a cell blocks walking north out of it);
##   - in a dungeon, only the floor cells of the dungeon plan are walkable.
## A step may go up at most STEP_UP blocks (monsters hop 1 m) and down at
## most STEP_DOWN blocks. Diagonal steps can't cut corners.
##
## Milestone 30 - storeys: a cell can also have walkable decks on storeys 1..3
## (upper floors, and the steps of a staircase, which climb to the next storey).
## A search node is (cell, level); level 0 is the ground (or a foundation's top).
## Stairs are walked like any slope; ladders are links between their foot and
## the cell they lead onto one storey up (monsters climb them).
##
## find_path() returns waypoints (cell centres, smoothed so straight runs are a
## single waypoint) and whether the goal was reached. If the goal can't be
## reached it returns the way to the closest cell. Raiders may plan through
## player buildings (at a high cost) - they smash what is in the way.

const TILE := 16
## Tiles are rebuilt after this long (buildings get placed and broken).
const TTL_MS := 3000
const STEP_UP := 2
const STEP_DOWN := 8
const MAX_NODES := 1800
## Node limit for close goals (under CLOSE_GOAL_M), Milestone 36.
const MAX_NODES_CLOSE := 1000
const CLOSE_GOAL_M := 20.0
const MAX_RADIUS := 56
## Obstacles grow by this much (monster body radius).
const INFLATE := 0.3
## Path searches allowed per physics frame (all monsters together).
const SEARCHES_PER_FRAME := 4
## Milestone 36: and at most this much time per physics frame (the first search
## always runs) - a search that has to scan new tiles can take a few ms, and a
## crowd asking at once made 10+ ms frames.
const SEARCH_BUDGET_US := 1500
const TILE_BUILDS_PER_FRAME := 6

const F_SOLID := 1
const F_WALL_N := 2
const F_WALL_W := 4
const F_BREAK := 8
const F_WATER := 16
const F_SOLID_HARD := 32   # a solid that is NOT a player building (raiders can't break it)
const F_EDGE_HARD := 64    # an edge wall that is NOT a player building
const F_NONE := 128        # no deck on this level (upper levels only)
## Upper levels (storeys) a cell can have.
const LEVELS := 3
const NO_DECK := Vector2i(0, F_SOLID | F_SOLID_HARD | F_NONE)
## Levels a search tries from each level (same as _levels_to_try, precomputed).
const TRIES := [[0, 1], [1, 2, 0], [2, 3, 1, 0], [3, 2, 0]]
const GROUND_ONLY := [0]
## Extra cost of climbing a ladder (in cells).
const LADDER_COST := 4.0

const OBSTACLE_MASK := Layers.BUILDING | Layers.PROP
const ORTHO := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

## Switch off to get the old straight-line steering (tests, comparisons).
static var enabled := true
## Creative mode's "Show monster paths".
static var debug_draw := false

static var _tiles: Dictionary = {}  # Vector2i -> {"t": msec, "h": PackedInt32Array, "f": PackedByteArray}
static var _context := ""
static var _frame := -1
static var _searches := 0
static var _spent_us := 0
static var _builds := 0
static var stats := {"searches": 0, "tiles_built": 0, "nodes": 0, "reached": 0, "partial": 0, "ms": 0.0}


# --- Budget -------------------------------------------------------------------------

static func _tick_frame() -> void:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_searches = 0
		_builds = 0
		_spent_us = 0


## True if a search may run this frame (and counts it).
static func take_search() -> bool:
	_tick_frame()
	if _searches >= SEARCHES_PER_FRAME or (_searches > 0 and _spent_us >= SEARCH_BUDGET_US):
		return false
	_searches += 1
	return true


static func clear() -> void:
	_tiles.clear()


## Forgets the tiles that touch `pos` (a building piece was placed or broken).
static func invalidate_at(pos: Vector3) -> void:
	var c := Vector2i(floori(pos.x / TILE), floori(pos.z / TILE))
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			_tiles.erase(c + Vector2i(dx, dz))


# --- The grid -----------------------------------------------------------------------

## Tiles belong to one place: the surface, the caves or one dungeon floor.
static func _check_context(world: World) -> void:
	var ctx := "W%d L%d" % [world.get_instance_id(), world.layer]
	if world.dungeon:
		ctx = "D%d" % world.dungeon.get_instance_id()
	if ctx != _context:
		_context = ctx
		_tiles.clear()


static func _tile(world: World, t: Vector2i, may_build: bool = true) -> Dictionary:
	var tile: Dictionary = _tiles.get(t, {})
	var now := Time.get_ticks_msec()
	if not tile.is_empty() and (now - int(tile.t) < TTL_MS or not may_build):
		return tile
	if not may_build:
		return tile
	_tick_frame()
	if _builds >= TILE_BUILDS_PER_FRAME and not tile.is_empty():
		return tile  # over budget: an old tile is better than nothing
	_builds += 1
	tile = _build_tile(world, t)
	_tiles[t] = tile
	stats.tiles_built += 1
	return tile


static func _build_tile(world: World, t: Vector2i) -> Dictionary:
	var h := PackedInt32Array()
	var f := PackedByteArray()
	h.resize(TILE * TILE)
	f.resize(TILE * TILE)
	var ox := t.x * TILE
	var oz := t.y * TILE
	var d := world.dungeon
	if d:
		var floor_h := roundi(d.floor_y() / TerrainGenerator.BLOCK_HEIGHT)
		for j in TILE:
			for i in TILE:
				var k := j * TILE + i
				h[k] = floor_h
				var local := Vector2i(ox + i - floori(d.position.x), oz + j - floori(d.position.z))
				if not d.plan.cells.has(local):
					f[k] = F_SOLID | F_SOLID_HARD
	else:
		var data: ChunkData = world.chunk_manager.cached_data(t, 0, world.layer)
		if data and data.step == 1:
			var w := TILE + 2
			for j in TILE:
				for i in TILE:
					h[j * TILE + i] = data.heights[(j + 1) * w + i + 1]
		else:
			for j in TILE:
				for i in TILE:
					h[j * TILE + i] = roundi(world.generator.get_height_at(Vector3(ox + i + 0.5, 0, oz + j + 0.5), world.layer)
						/ TerrainGenerator.BLOCK_HEIGHT)
		if world.layer == TerrainGenerator.Layer.SURFACE:
			var deep := floori((TerrainGenerator.WATER_Y - 1.0) / TerrainGenerator.BLOCK_HEIGHT)
			for k in TILE * TILE:
				if h[k] < deep:
					f[k] = F_WATER
	var tile := {"t": Time.get_ticks_msec(), "h": h, "f": f, "uh": [], "uf": []}
	for l in LEVELS:
		var uh := PackedInt32Array()
		uh.resize(TILE * TILE)
		var uf := PackedByteArray()
		uf.resize(TILE * TILE)
		uf.fill(F_NONE)
		tile.uh.append(uh)
		tile.uf.append(uf)
	var mine := _pieces_in_tile(world, t) if d == null else []
	_add_foundations(world, mine, ox, oz, h)
	_add_obstacles(world, t, h, f)
	_add_storeys(world, mine, ox, oz, h, f, tile.uh, tile.uf)
	# Searches skip the upper levels of tiles without any deck (most of the world).
	var decks := false
	for l in LEVELS:
		var lf: PackedByteArray = tile.uf[l]
		for k in TILE * TILE:
			if not (lf[k] & F_NONE):
				decks = true
				break
		if decks:
			break
	tile["decks"] = decks
	return tile


## Player building pieces with their cell in tile `t` (each piece once).
static func _pieces_in_tile(world: World, t: Vector2i) -> Array:
	var out := []
	if world.building == null:
		return out
	var x0 := t.x * TILE
	var z0 := t.y * TILE
	for k in world.building.pieces:
		var p: BuildPiece = world.building.pieces[k]
		if not is_instance_valid(p) or p.layer != world.layer or p.is_queued_for_deletion():
			continue
		if k != BuildingManager.key(p.cell, p.slot, p.layer):
			continue
		if p.cell.x >= x0 and p.cell.x < x0 + TILE and p.cell.y >= z0 and p.cell.y < z0 + TILE:
			out.append(p)
	return out


## Foundations raise the ground of their cell to their top.
static func _add_foundations(_world: World, mine: Array, ox: int, oz: int, h: PackedInt32Array) -> void:
	var bh := TerrainGenerator.BLOCK_HEIGHT
	for p: BuildPiece in mine:
		if p.data.behavior == BuildPieceData.Behavior.FOUNDATION:
			h[(p.cell.y - oz) * TILE + (p.cell.x - ox)] = roundi(p.found_top / bh)


## Upper floors, their walls and furniture, and the steps of staircases.
## (Packed arrays inside an Array are copied when read, so each level is read
## into a local, changed and written back at the end.)
static func _add_storeys(world: World, mine: Array, ox: int, oz: int, h: PackedInt32Array, f: PackedByteArray,
		uh: Array, uf: Array) -> void:
	if mine.is_empty():
		return
	var bh := TerrainGenerator.BLOCK_HEIGHT
	var bm := world.building
	var lh: Array[PackedInt32Array] = []
	var lf: Array[PackedByteArray] = []
	for l in LEVELS:
		lh.append(uh[l])
		lf.append(uf[l])
	# Floors first (they make the decks), then what stands on them.
	for p: BuildPiece in mine:
		var parts := BuildingManager.split_slot(p.slot)
		var st: int = parts[1]
		if parts[0] == "floor" and st >= 1 and st <= LEVELS:
			var k := (p.cell.y - oz) * TILE + (p.cell.x - ox)
			lh[st - 1][k] = roundi((bm.storey_y(p.cell, st) + BuildingManager.FLOOR_TOP) / bh)
			lf[st - 1][k] = 0
	for p: BuildPiece in mine:
		var parts := BuildingManager.split_slot(p.slot)
		var base: String = parts[0]
		var st: int = parts[1]
		if p.data.behavior == BuildPieceData.Behavior.STAIRS:
			# The steps: decks of the next storey rising cell by cell; the cells
			# they stand on can't be walked under.
			var rise := BuildingManager.WALL_HEIGHT / 6.0
			var cells: Array[Vector2i] = bm.stair_cells(p.cell, p.rot)
			for i in cells.size():
				var c: Vector2i = cells[i]
				if c.x < ox or c.x >= ox + TILE or c.y < oz or c.y >= oz + TILE:
					continue  # NOT IMPLEMENTED: a staircase that crosses into the next tile only counts its own tile's steps
				var k := (c.y - oz) * TILE + (c.x - ox)
				if st + 1 <= LEVELS:
					lh[st][k] = roundi((bm.storey_y(p.cell, st) + (2 * i + 1.5) * rise) / bh)
					lf[st][k] = 0
				if st == 0:
					f[k] |= F_SOLID | F_BREAK
				elif st <= LEVELS:
					lf[st - 1][k] |= F_SOLID | F_BREAK
			continue
		if st < 1 or st > LEVELS:
			continue
		var k := (p.cell.y - oz) * TILE + (p.cell.x - ox)
		if base == "edge_n" or base == "edge_w":
			if p.data.behavior == BuildPieceData.Behavior.DOOR and p.is_open:
				continue
			if p.data.blocks_movement:
				lf[st - 1][k] |= (F_WALL_N if base == "edge_n" else F_WALL_W) | F_BREAK
		elif base == "object" and p.data.blocks_movement and p.data.behavior != BuildPieceData.Behavior.LADDER:
			lf[st - 1][k] |= F_SOLID | F_BREAK
	for l in LEVELS:
		uh[l] = lh[l]
		uf[l] = lf[l]


## Marks solid cells and walled edges from the physics shapes in the tile.
static func _add_obstacles(world: World, t: Vector2i, h: PackedInt32Array, f: PackedByteArray) -> void:
	if not world.is_inside_tree():
		return
	var hmin := h[0]
	var hmax := h[0]
	for v in h:
		hmin = mini(hmin, v)
		hmax = maxi(hmax, v)
	var bh := TerrainGenerator.BLOCK_HEIGHT
	var y0 := hmin * bh
	var y1 := hmax * bh + 2.0
	var box := BoxShape3D.new()
	box.size = Vector3(TILE + 2.0, y1 - y0 + 1.0, TILE + 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, Vector3(t.x * TILE + TILE * 0.5, (y0 + y1) * 0.5, t.y * TILE + TILE * 0.5))
	q.collision_mask = OBSTACLE_MASK
	var hits := world.get_world_3d().direct_space_state.intersect_shape(q, 512)
	var ox := t.x * TILE
	var oz := t.y * TILE
	for hit in hits:
		var body := hit.collider as CollisionObject3D
		if body == null:
			continue
		var owner_id := body.shape_find_owner(int(hit.shape))
		var cs := body.shape_owner_get_owner(owner_id) as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var breakable := body is BuildPiece
		if breakable and (body as BuildPiece).data.behavior in [BuildPieceData.Behavior.STAIRS, BuildPieceData.Behavior.FOUNDATION]:
			continue  # walkable: handled by _add_storeys / _add_foundations
		_rasterize(cs.shape, cs.global_transform, breakable, ox, oz, h, f)


## One shape: which cells does it fill, which edges does it cross?
static func _rasterize(shape: Shape3D, xf: Transform3D, breakable: bool, ox: int, oz: int,
		h: PackedInt32Array, f: PackedByteArray) -> void:
	var aabb := xf * _local_aabb(shape)
	var c := Vector2(xf.origin.x, xf.origin.z)
	# 2D footprint: an oriented box (u, v axes, half sizes) or a circle (radius).
	var round_r := -1.0
	var u := Vector2.RIGHT
	var v := Vector2.DOWN
	var hu := 0.0
	var hv := 0.0
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		var ax := Vector2(xf.basis.x.x, xf.basis.x.z)
		var az := Vector2(xf.basis.z.x, xf.basis.z.z)
		hu = half.x * ax.length() + INFLATE
		hv = half.z * az.length() + INFLATE
		u = ax.normalized() if ax.length() > 0.001 else Vector2.RIGHT
		v = az.normalized() if az.length() > 0.001 else Vector2.DOWN
	elif shape is CylinderShape3D or shape is CapsuleShape3D or shape is SphereShape3D:
		var r: float = shape.radius
		round_r = r * Vector2(xf.basis.x.x, xf.basis.x.z).length() + INFLATE
	else:
		u = Vector2.RIGHT
		v = Vector2.DOWN
		c = Vector2(aabb.get_center().x, aabb.get_center().z)
		hu = aabb.size.x * 0.5 + INFLATE
		hv = aabb.size.z * 0.5 + INFLATE
	var reach := round_r if round_r > 0.0 else Vector2(hu, hv).length()
	var x0 := maxi(floori(c.x - reach) - 1, ox)
	var x1 := mini(floori(c.x + reach) + 1, ox + TILE - 1)
	var z0 := maxi(floori(c.y - reach) - 1, oz)
	var z1 := mini(floori(c.y + reach) + 1, oz + TILE - 1)
	var bh := TerrainGenerator.BLOCK_HEIGHT
	var solid_bits := F_SOLID | (F_BREAK if breakable else F_SOLID_HARD)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var k := (z - oz) * TILE + (x - ox)
			var g := h[k] * bh
			# Only shapes at body height matter (floors and roofs don't block).
			if aabb.end.y < g + 0.55 or aabb.position.y > g + 1.7:
				continue
			var p := Vector2(x + 0.5, z + 0.5)
			if _inside(p, c, u, v, hu, hv, round_r):
				f[k] |= solid_bits
				continue
			var bits := 0
			if _crosses(p, p + Vector2(0, -1), c, u, v, hu, hv, round_r):
				bits |= F_WALL_N
			if _crosses(p, p + Vector2(-1, 0), c, u, v, hu, hv, round_r):
				bits |= F_WALL_W
			if bits:
				f[k] |= bits | (F_BREAK if breakable else F_EDGE_HARD)


static func _local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s: Vector3 = (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is CylinderShape3D or shape is CapsuleShape3D:
		var r: float = shape.radius
		var hh: float = shape.height * 0.5
		return AABB(Vector3(-r, -hh, -r), Vector3(r * 2.0, hh * 2.0, r * 2.0))
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	return shape.get_debug_mesh().get_aabb()


static func _inside(p: Vector2, c: Vector2, u: Vector2, v: Vector2, hu: float, hv: float, round_r: float) -> bool:
	var d := p - c
	if round_r > 0.0:
		return d.length() < round_r
	return absf(d.dot(u)) < hu and absf(d.dot(v)) < hv


## Does the segment a-b pass through the footprint?
static func _crosses(a: Vector2, b: Vector2, c: Vector2, u: Vector2, v: Vector2, hu: float, hv: float, round_r: float) -> bool:
	if round_r > 0.0:
		var ab := b - a
		var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		return (a + ab * t).distance_to(c) < round_r
	# Slab test in the box's own axes.
	var la := Vector2((a - c).dot(u), (a - c).dot(v))
	var lb := Vector2((b - c).dot(u), (b - c).dot(v))
	var dir := lb - la
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var s := la[axis]
		var ds := dir[axis]
		var lim := hu if axis == 0 else hv
		if absf(ds) < 0.00001:
			if absf(s) >= lim:
				return false
		else:
			var e0 := (-lim - s) / ds
			var e1 := (lim - s) / ds
			if e0 > e1:
				var tmp := e0
				e0 = e1
				e1 = tmp
			t0 = maxf(t0, e0)
			t1 = minf(t1, e1)
			if t0 > t1:
				return false
	return true


# --- Cell queries (used by the search) -----------------------------------------------

## [height, flags] of a cell, or [0, F_SOLID] when unknown.
static func cell(world: World, x: int, z: int) -> Vector2i:
	var t := Vector2i(floori(float(x) / TILE), floori(float(z) / TILE))
	var tile := _tile(world, t)
	if tile.is_empty():
		return Vector2i(0, F_SOLID | F_SOLID_HARD)
	var k := (z - t.y * TILE) * TILE + (x - t.x * TILE)
	return Vector2i((tile.h as PackedInt32Array)[k], (tile.f as PackedByteArray)[k])


## [height, flags] of a cell on a level (0 = ground); NO_DECK if that level has no deck there.
static func cell_at(world: World, x: int, z: int, level: int) -> Vector2i:
	if level <= 0:
		return cell(world, x, z)
	var t := Vector2i(floori(float(x) / TILE), floori(float(z) / TILE))
	var tile := _tile(world, t)
	if tile.is_empty() or not tile.has("uh") or level > LEVELS:
		return NO_DECK
	var k := (z - t.y * TILE) * TILE + (x - t.x * TILE)
	var fl: int = (tile.uf[level - 1] as PackedByteArray)[k]
	if fl & F_NONE:
		return NO_DECK
	return Vector2i((tile.uh[level - 1] as PackedInt32Array)[k], fl)


## Can a walker step from a to the next cell b (orthogonal)? `breaker` walks
## through player buildings.
static func _step_ok(ca: Vector2i, cb: Vector2i, a: Vector2i, b: Vector2i, breaker: bool, goal: Vector2i) -> bool:
	if cb.y & F_SOLID and b != goal:
		if not breaker or cb.y & F_SOLID_HARD:
			return false
	var dh := cb.x - ca.x
	if dh > STEP_UP or dh < -STEP_DOWN:
		return false
	# Edge walls: north edge of the cell with the smaller z, west edge of the one with the smaller x.
	var edge := 0
	if b.y < a.y:
		edge = ca.y & F_WALL_N
		if edge and (not breaker or ca.y & F_EDGE_HARD):
			return false
	elif b.y > a.y:
		edge = cb.y & F_WALL_N
		if edge and (not breaker or cb.y & F_EDGE_HARD):
			return false
	elif b.x < a.x:
		edge = ca.y & F_WALL_W
		if edge and (not breaker or ca.y & F_EDGE_HARD):
			return false
	else:
		edge = cb.y & F_WALL_W
		if edge and (not breaker or cb.y & F_EDGE_HARD):
			return false
	return true


# --- A* -------------------------------------------------------------------------------

static func _key(c: Vector2i) -> int:
	return ((c.x + 0x40000) << 20) | (c.y + 0x40000)


static func _unkey(k: int) -> Vector2i:
	return Vector2i((k >> 20) - 0x40000, (k & 0xFFFFF) - 0x40000)


## Node key: cell and level (Milestone 30).
static func _nkey(c: Vector2i, level: int) -> int:
	return (_key(c) << 2) | level


static func _nunkey(k: int) -> Vector3i:
	var c := _unkey(k >> 2)
	return Vector3i(c.x, c.y, k & 3)


## The level at a cell whose walking height is closest to `y` (ground if none is close).
static func level_for(world: World, c: Vector2i, y: float) -> int:
	var bh := TerrainGenerator.BLOCK_HEIGHT
	var best := 0
	var bd := absf(float(cell(world, c.x, c.y).x) * bh - y)
	for l in range(1, LEVELS + 1):
		var cl := cell_at(world, c.x, c.y, l)
		if cl.y & F_NONE:
			continue
		var dd := absf(float(cl.x) * bh - y)
		if dd < bd:
			bd = dd
			best = l
	return best


## Ladders near `centre`: node key -> [node keys], both ways (foot <-> top).
static func _ladder_links(world: World, centre: Vector2i) -> Dictionary:
	var out := {}
	if world.dungeon or world.building == null or not world.is_inside_tree():
		return out
	for n in world.get_tree().get_nodes_in_group(&"ladders"):
		var lad := n as BuildPiece
		if lad == null or lad.layer != world.layer or lad.is_queued_for_deletion():
			continue
		if absi(lad.cell.x - centre.x) > MAX_RADIUS + 2 or absi(lad.cell.y - centre.y) > MAX_RADIUS + 2:
			continue
		var st := BuildingManager.storey_of(lad.slot)
		if st >= LEVELS:
			continue
		var foot := _nkey(lad.cell, st)
		var top := _nkey(lad.cell + BuildingManager.rot_dir(lad.rot), st + 1)
		if not out.has(foot):
			out[foot] = []
		if not out.has(top):
			out[top] = []
		out[foot].append(top)
		out[top].append(foot)
	return out


## {"points": PackedVector3Array, "reached": bool, "breach": bool}.
## `breaker`: raiders - player buildings cost a lot but can be passed.
## `max_nodes` (Milestone 36): monsters chasing something close pass a smaller
## limit (MAX_NODES_CLOSE) - a search that exhausts 1800 nodes takes ~9 ms.
static func find_path(world: World, from: Vector3, to: Vector3, breaker: bool = false, max_nodes: int = MAX_NODES) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	_check_context(world)
	stats.searches += 1
	var s := Vector2i(floori(from.x), floori(from.z))
	var g := Vector2i(floori(to.x), floori(to.z))
	var out := {"points": PackedVector3Array(), "reached": false, "breach": false}
	var cells := {}  # node key -> Vector2i(height, flags), per search
	var sl := level_for(world, s, from.y)
	var gl := level_for(world, g, to.y)
	if s == g and sl == gl:
		out.points.append(to)
		out.reached = true
		return out
	var links := _ladder_links(world, s)
	var open_f: Array[float] = []
	var open_k: Array[int] = []
	var g_cost := {}
	var came := {}
	var closed := {}
	var sk := _nkey(s, sl)
	var gk := _nkey(g, gl)
	g_cost[sk] = 0.0
	_push(open_f, open_k, _octile(s, g), sk)
	var best_k := sk
	var best_h := _octile(s, g) + absi(sl - gl)
	var nodes := 0
	while not open_k.is_empty() and nodes < max_nodes:
		var ck := _pop(open_f, open_k)
		if closed.has(ck):
			continue
		closed[ck] = true
		nodes += 1
		if ck == gk:
			best_k = gk
			break
		var cn := _nunkey(ck)
		var cpos := Vector2i(cn.x, cn.y)
		var cl := cn.z
		var hc := _octile(cpos, g) + absi(cl - gl) * 2.0
		if hc < best_h:
			best_h = hc
			best_k = ck
		var ccell := _cached_l(world, cells, cpos, cl)
		var cg: float = g_cost[ck]
		var ctile := Vector2i(floori(float(cpos.x) / TILE), floori(float(cpos.y) / TILE))
		var cdecks := _decks_in(world, ctile)
		# Ladders.
		for lk: int in links.get(ck, []):
			if closed.has(lk):
				continue
			var ln := _nunkey(lk)
			if _cached_l(world, cells, Vector2i(ln.x, ln.y), ln.z).y & F_NONE:
				continue
			var lg := cg + LADDER_COST
			if lg < float(g_cost.get(lk, INF)):
				g_cost[lk] = lg
				came[lk] = ck
				_push(open_f, open_k, lg + _octile(Vector2i(ln.x, ln.y), g) * 1.001, lk)
		for dir: Vector2i in ORTHO + DIAG:
			var npos := cpos + dir
			if absi(npos.x - s.x) > MAX_RADIUS or absi(npos.y - s.y) > MAX_RADIUS:
				continue
			var diag := dir.x != 0 and dir.y != 0
			# Which level of the next cell? The same, one up or down (stairs), or the ground (a drop).
			var tries: Array = TRIES[cl]
			if cl == 0:
				var ntile := Vector2i(floori(float(npos.x) / TILE), floori(float(npos.y) / TILE))
				if not (cdecks if ntile == ctile else _decks_in(world, ntile)):
					tries = GROUND_ONLY
			for nl: int in tries:
				if diag and nl != cl:
					continue
				var nk := _nkey(npos, nl)
				if closed.has(nk):
					continue
				var ncell := _cached_l(world, cells, npos, nl)
				if ncell.y & F_NONE:
					continue
				var cost := 1.0
				if diag:
					# No corner cutting: both L-shaped routes must be open.
					var ax := cpos + Vector2i(dir.x, 0)
					var az := cpos + Vector2i(0, dir.y)
					var cax := _cached_l(world, cells, ax, cl)
					var caz := _cached_l(world, cells, az, cl)
					if (cax.y | caz.y) & F_NONE:
						continue
					if not (_step_ok(ccell, cax, cpos, ax, breaker, g) and _step_ok(cax, ncell, ax, npos, breaker, g)
							and _step_ok(ccell, caz, cpos, az, breaker, g) and _step_ok(caz, ncell, az, npos, breaker, g)):
						continue
					if cax.y & F_SOLID or caz.y & F_SOLID:
						continue
					if breaker and (ccell.y | ncell.y | cax.y | caz.y) & F_BREAK:
						continue  # raiders break walls head-on, never slip past a corner
					cost = 1.4142
				elif not _step_ok(ccell, ncell, cpos, npos, breaker, g):
					continue
				var dh := ncell.x - ccell.x
				if dh > 0:
					cost += 0.35 * dh
				if ncell.y & F_WATER:
					cost *= 3.0
				if breaker and (ncell.y | ccell.y) & F_BREAK:
					cost += 12.0
				var ng := cg + cost
				if ng < float(g_cost.get(nk, INF)):
					g_cost[nk] = ng
					came[nk] = ck
					_push(open_f, open_k, ng + _octile(npos, g) * 1.001 + absi(nl - gl) * 0.5, nk)
	stats.nodes += nodes
	out.reached = best_k == gk
	if out.reached:
		stats.reached += 1
	else:
		stats.partial += 1
	# Walk back from the best node.
	var chain: Array[Vector3i] = []
	var k := best_k
	while k != sk:
		chain.push_front(_nunkey(k))
		if not came.has(k):
			break
		k = came[k]
	chain.push_front(Vector3i(s.x, s.y, sl))
	for c in chain:
		if breaker and int(_cached_l(world, cells, Vector2i(c.x, c.y), c.z).y) & F_BREAK:
			out.breach = true
	out.points = _smooth(world, cells, chain, breaker, g)
	if out.reached and out.points.size() > 0:
		out.points[out.points.size() - 1] = Vector3(to.x, out.points[out.points.size() - 1].y, to.z)
	stats.ms += (Time.get_ticks_usec() - t_start) / 1000.0
	_spent_us += Time.get_ticks_usec() - t_start
	return out


## Does this tile have any upper deck (floor, stair step) at all?
static func _decks_in(world: World, t: Vector2i) -> bool:
	return bool(_tile(world, t).get("decks", false))


## Levels worth trying from level `l`: the same, one up and one down (stairs), the ground (drops).
static func _levels_to_try(l: int) -> Array[int]:
	var out: Array[int] = [l]
	if l + 1 <= LEVELS:
		out.append(l + 1)
	if l - 1 >= 0:
		out.append(l - 1)
	if l >= 2:
		out.append(0)
	return out


static func _cached(world: World, cells: Dictionary, c: Vector2i) -> Vector2i:
	return _cached_l(world, cells, c, 0)


static func _cached_l(world: World, cells: Dictionary, c: Vector2i, level: int) -> Vector2i:
	var k := _nkey(c, level)
	if cells.has(k):
		return cells[k]
	var v := cell_at(world, c.x, c.y, level)
	cells[k] = v
	return v


static func _octile(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dz := absi(a.y - b.y)
	return float(maxi(dx, dz)) + 0.4142 * float(mini(dx, dz))


# Binary heap on two parallel arrays (lowest f on top).
static func _push(fs: Array[float], ks: Array[int], fv: float, k: int) -> void:
	fs.append(fv)
	ks.append(k)
	var i := fs.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if fs[p] <= fs[i]:
			break
		var tf := fs[p]
		fs[p] = fs[i]
		fs[i] = tf
		var tk := ks[p]
		ks[p] = ks[i]
		ks[i] = tk
		i = p


static func _pop(fs: Array[float], ks: Array[int]) -> int:
	var top := ks[0]
	var last_f: float = fs.pop_back()
	var last_k: int = ks.pop_back()
	if fs.is_empty():
		return top
	fs[0] = last_f
	ks[0] = last_k
	var i := 0
	var n := fs.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and fs[l] < fs[m]:
			m = l
		if r < n and fs[r] < fs[m]:
			m = r
		if m == i:
			break
		var tf := fs[m]
		fs[m] = fs[i]
		fs[i] = tf
		var tk := ks[m]
		ks[m] = ks[i]
		ks[i] = tk
		i = m
	return top


# --- Smoothing ---------------------------------------------------------------------------

## Keeps only the cells where the path has to turn: from each kept cell, jump
## to the farthest later cell that can be walked to in a straight line (on the
## same level - stairs and ladders always keep their points).
static func _smooth(world: World, cells: Dictionary, chain: Array[Vector3i], breaker: bool, goal: Vector2i) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var bh := TerrainGenerator.BLOCK_HEIGHT
	var i := 0
	while i < chain.size() - 1:
		var j := chain.size() - 1
		while j > i + 1 and not _straight(world, cells, chain, i, j, breaker, goal):
			j -= 1
		var c := chain[j]
		pts.append(Vector3(c.x + 0.5, _cached_l(world, cells, Vector2i(c.x, c.y), c.z).x * bh, c.y + 0.5))
		i = j
	if pts.is_empty():
		var c := chain[0]
		pts.append(Vector3(c.x + 0.5, _cached_l(world, cells, Vector2i(c.x, c.y), c.z).x * bh, c.y + 0.5))
	return pts


## Half the width of the walking body checked along shortcuts (so they don't
## graze wall corners).
const BODY_HALF := 0.35


## A straight walk from chain[i] to chain[j], checked cell by cell along the
## centre line and both sides of the body. Only on one level.
static func _straight(world: World, cells: Dictionary, chain: Array[Vector3i], i: int, j: int, breaker: bool, goal: Vector2i) -> bool:
	var level := chain[i].z
	for m in range(i, j + 1):
		if chain[m].z != level:
			return false
		if m > i and absi(chain[m].x - chain[m - 1].x) + absi(chain[m].y - chain[m - 1].y) > 2:
			return false  # a ladder jump
	var a := Vector2i(chain[i].x, chain[i].y)
	var b := Vector2i(chain[j].x, chain[j].y)
	var p := Vector2(a.x + 0.5, a.y + 0.5)
	var q := Vector2(b.x + 0.5, b.y + 0.5)
	var side := (q - p).orthogonal().normalized() * BODY_HALF
	for off in [Vector2.ZERO, side, -side]:
		if not _line_ok(world, cells, p + off, q + off, breaker, goal, level):
			return false
	return true


static func _line_ok(world: World, cells: Dictionary, p: Vector2, q: Vector2, breaker: bool, goal: Vector2i, level: int = 0) -> bool:
	var a := Vector2i(floori(p.x), floori(p.y))
	var n := ceili(p.distance_to(q) / 0.25)
	var prev := a
	var pc := _cached_l(world, cells, a, level)
	for s in range(1, n + 1):
		var m := p.lerp(q, float(s) / n)
		var c := Vector2i(floori(m.x), floori(m.y))
		if c == prev:
			continue
		var cc := _cached_l(world, cells, c, level)
		if cc.y & F_NONE:
			return false
		if c.x != prev.x and c.y != prev.y:
			# Crossed a corner: both side cells must be open too.
			var sx := Vector2i(c.x, prev.y)
			var sz := Vector2i(prev.x, c.y)
			var csx := _cached_l(world, cells, sx, level)
			var csz := _cached_l(world, cells, sz, level)
			if (csx.y | csz.y) & F_NONE:
				return false
			if not (_step_ok(pc, csx, prev, sx, breaker, goal) and _step_ok(csx, cc, sx, c, breaker, goal)
					and _step_ok(pc, csz, prev, sz, breaker, goal) and _step_ok(csz, cc, sz, c, breaker, goal)):
				return false
		elif not _step_ok(pc, cc, prev, c, breaker, goal):
			return false
		# Straight runs stay off the water and away from long climbs.
		if cc.y & F_WATER and not (pc.y & F_WATER):
			return false
		if breaker and cc.y & F_BREAK:
			return false
		prev = c
		pc = cc
	return true
