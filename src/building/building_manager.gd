class_name BuildingManager
extends Node3D
## Owns every placed building piece and the building grid.
##
## Grid: 1 m cells aligned to terrain columns. Each cell has slots:
##   "floor"  - floors, spike traps
##   "object" - furniture, stations, lights, claims
##   "roof"   - roofs (2.6 m above the ground)
##   "edge_n" / "edge_w" - the cell's north (-Z) and west (-X) edges for walls,
##              doors, windows, fences, spike walls. A cell's south/east edges
##              are the north/west edges of its neighbours, so every edge has
##              exactly one address.
## Pieces are world objects (not chunk-bound) and are saved by World.
##
## Milestone 30 - multi-storey building. Every slot can be on a storey 0..MAX_STOREY:
## storey 0 keeps the old names; higher storeys add "@<n>" ("floor@1", "edge_n@2").
## A storey is WALL_HEIGHT above the one below. Upper floors rest on walls below
## (or reach out up to BALCONY_REACH cells from a floor that does: balconies);
## upper walls stand on a floor or on the wall below; furniture needs a floor.
## Stairs (3 cells long, behaviour STAIRS) and ladders (LADDER) lead up a storey.
## Foundations ("found" slot) level a cell on a slope: everything in that cell
## stands on the foundation's top instead of the ground.

const PIECE_DIR := "res://data/build_pieces/"
const WALL_HEIGHT := 2.6
const FLOOR_TOP := 0.13
const MAX_CLAIMS := 5
## Share of materials returned when deconstructing outside your land.
const UNCLAIMED_REFUND := 0.5
## Highest storey you can build on (0 = the ground floor).
const MAX_STOREY := 3
## Upper floors may reach this many cells out from a supported floor (balconies).
const BALCONY_REACH := 2
## Stairs climb one storey over this many cells.
const STAIR_CELLS := 3

static var _registry: Dictionary = {}

var world: World
## key -> BuildPiece
var pieces: Dictionary = {}
var _roofs_hidden := false
var _roof_check := 0.0


static func all_pieces() -> Dictionary:
	if _registry.is_empty():
		for file in ResourceLoader.list_directory(PIECE_DIR):
			if file.ends_with(".tres"):
				var r := load(PIECE_DIR + file)
				if r is BuildPieceData:
					_registry[r.id] = r
	return _registry


static func get_piece_data(id: StringName) -> BuildPieceData:
	return all_pieces().get(id)


static func key(cell: Vector2i, slot: String, layer: int) -> String:
	return "%d,%d,%s,%d" % [cell.x, cell.y, slot, layer]


## [base slot, storey] of a slot string: "edge_n@2" -> ["edge_n", 2].
static func split_slot(slot: String) -> Array:
	var i := slot.find("@")
	if i < 0:
		return [slot, 0]
	return [slot.substr(0, i), int(slot.substr(i + 1))]


static func slot_at(base: String, storey: int) -> String:
	return base if storey <= 0 else "%s@%d" % [base, storey]


static func storey_of(slot: String) -> int:
	return int(split_slot(slot)[1])


static func base_slot(slot: String) -> String:
	return String(split_slot(slot)[0])


## Direction a rotated piece faces (rot 0 = +Z, 1 = +X ... like Basis(UP, rot * PI/2) * +Z).
static func rot_dir(rot: int) -> Vector2i:
	return [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][posmod(rot, 4)]


static func slot_kind(data: BuildPieceData) -> String:
	if data.placement == BuildPieceData.Placement.FOUNDATION:
		return "found"
	match data.placement:
		BuildPieceData.Placement.FLOOR:
			return "floor"
		BuildPieceData.Placement.ROOF:
			return "roof"
		BuildPieceData.Placement.EDGE:
			return "edge"
	return "object"


## Grid address under a world point for `data`: {cell, slot}. `storey` > 0
## builds on an upper storey (foundations always sit on the ground).
func address_for(data: BuildPieceData, point: Vector3, storey: int = 0) -> Dictionary:
	var cell := Vector2i(floori(point.x), floori(point.z))
	var slot := slot_kind(data)
	if slot == "edge":
		var fx := point.x - cell.x
		var fz := point.z - cell.y
		var d := {"n": fz, "s": 1.0 - fz, "w": fx, "e": 1.0 - fx}
		var best := "n"
		for k in d:
			if d[k] < d[best]:
				best = k
		match best:
			"n":
				slot = "edge_n"
			"s":
				slot = "edge_n"
				cell += Vector2i(0, 1)
			"w":
				slot = "edge_w"
			"e":
				slot = "edge_w"
				cell += Vector2i(1, 0)
	if slot != "found":
		slot = slot_at(slot, clampi(storey, 0, MAX_STOREY))
	return {"cell": cell, "slot": slot}


func _ground(cell: Vector2i) -> float:
	return world.generator.get_height_at(Vector3(cell.x + 0.5, 0, cell.y + 0.5), world.layer)


## What pieces in a cell stand on: a foundation's top, or the ground.
func _base(cell: Vector2i) -> float:
	var f: BuildPiece = pieces.get(key(cell, "found", world.layer))
	if f and is_instance_valid(f):
		return f.found_top
	return _ground(cell)


## Height a new foundation in `cell` levels out to: level with a foundation next to
## it, else a little above the highest ground around it.
func foundation_top(cell: Vector2i) -> float:
	var bh := TerrainGenerator.BLOCK_HEIGHT
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var f: BuildPiece = pieces.get(key(cell + d, "found", world.layer))
		if f and is_instance_valid(f) and f.found_top >= _ground(cell) + 0.2:
			return f.found_top
	var top := _ground(cell)
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			top = maxf(top, _ground(cell + Vector2i(dx, dz)))
	return ceilf((top + 0.25) / bh) * bh


## Height of a storey's floor in a cell.
func storey_y(cell: Vector2i, storey: int) -> float:
	return _base(cell) + storey * WALL_HEIGHT


## Milestone 37: a bed is two cells long - its own cell and the one at its feet
## (local +Z). The old 1.9 m bed sat in one 1 m cell and stuck into both neighbours.
static func bed_dir(rot: int) -> Vector2i:
	return [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][posmod(rot, 4)]


static func is_two_cell(data: BuildPieceData, slot: String) -> bool:
	return data.behavior == BuildPieceData.Behavior.BED and base_slot(slot) == "object"


## World transform of a piece at an address.
func transform_for(data: BuildPieceData, cell: Vector2i, slot: String, rot: int) -> Transform3D:
	var parts := split_slot(slot)
	var base: String = parts[0]
	var up: float = int(parts[1]) * WALL_HEIGHT
	var g := _base(cell)
	var pos := Vector3(cell.x + 0.5, g + up, cell.y + 0.5)
	var basis := Basis(Vector3.UP, rot * PI * 0.5)
	match base:
		"edge_n":
			g = maxf(g, _base(cell - Vector2i(0, 1)))
			pos = Vector3(cell.x + 0.5, g + up, cell.y)
			basis = Basis.IDENTITY
		"edge_w":
			g = maxf(g, _base(cell - Vector2i(1, 0)))
			pos = Vector3(cell.x, g + up, cell.y + 0.5)
			basis = Basis(Vector3.UP, PI * 0.5)
		"roof":
			pos.y = g + up + WALL_HEIGHT
		"found":
			pos.y = _ground(cell) if not pieces.has(key(cell, "found", world.layer)) else pieces[key(cell, "found", world.layer)].found_base
		"object":
			if pieces.has(key(cell, slot_at("floor", int(parts[1])), world.layer)):
				pos.y = g + up + FLOOR_TOP
			if is_two_cell(data, slot):
				var d := bed_dir(rot)
				pos += Vector3(d.x, 0, d.y) * 0.5  # spans this cell and the next
	return Transform3D(basis, pos)


## "" if the piece can be placed there, otherwise why not.
func check_place(data: BuildPieceData, cell: Vector2i, slot: String, player: Player, pay: bool = true, rot: int = 0) -> String:
	if player and player.creative:
		pay = false  # Creative mode (Milestone 24): building is free
	if pieces.has(key(cell, slot, world.layer)):
		return "Something is already built here"
	var storey := storey_of(slot)
	var base := base_slot(slot)
	if storey > MAX_STOREY:
		return "Too high (at most %d storeys up)" % MAX_STOREY
	var multi := _storey_rules(data, cell, base, storey, slot)
	if multi != "":
		return multi
	# Milestone 37: two-cell beds.
	if is_two_cell(data, slot):
		var c2 := cell + bed_dir(rot)
		if pieces.has(key(c2, slot, world.layer)):
			return "No room for the bed (something is at its foot)"
		if _edge_between(cell, c2, storey):
			return "A wall is in the way of the bed"
		if storey > 0 and not pieces.has(key(c2, slot_at("floor", storey), world.layer)):
			return "The bed needs a floor under both cells"
	if base.begins_with("edge") and _bed_across(cell, base, storey):
		return "A bed is in the way"
	var center := Vector3(cell.x + 0.5, 0, cell.y + 0.5)
	center.y = _ground(cell)
	if player:
		var flat := Vector2(center.x - player.global_position.x, center.z - player.global_position.z)
		if flat.length() > 9.0:
			return "Too far away"
		if player.character.level < data.required_level and not player.creative:
			return "Requires level %d" % data.required_level
		# Don't wall yourself in: solid pieces can't overlap the player.
		if data.blocks_movement and base != "roof" and base != "floor" and base != "found" and flat.length() < 0.7 \
				and absf(player.global_position.y - (center.y + storey * WALL_HEIGHT)) < 1.5:
			return "You're standing there"
	if world.layer == TerrainGenerator.Layer.SURFACE and center.y < TerrainGenerator.WATER_Y and not base.begins_with("edge") \
			and storey == 0:
		return "Can't build in water"
	if world.layer == TerrainGenerator.Layer.SURFACE:
		var town := world.generator.settlements.in_region_of(cell.x, cell.y)
		var margin := data.claim_radius if data.behavior == BuildPieceData.Behavior.CLAIM else 2.0
		if town and town.contains(center, margin):
			return "This land belongs to %s" % town.name
	if base != "roof" and storey == 0:
		var blocker := _obstruction(data, cell, slot, rot)
		if blocker != "":
			return "Blocked by %s" % blocker
	if base == "roof" and not _roof_supported(cell, storey):
		return "Roofs need a wall or another roof next to them"
	if data.behavior == BuildPieceData.Behavior.CLAIM:
		var claims := get_tree().get_nodes_in_group(&"land_claims")
		if claims.size() >= MAX_CLAIMS:
			return "You can own at most %d claims" % MAX_CLAIMS
		for c in claims:
			if (c as Node3D).global_position.distance_to(center) < c.claim_radius() + data.claim_radius:
				return "Overlaps land you already claimed"
	if pay and player:
		for item in data.cost:
			if player.inventory.count_of(item) < int(data.cost[item]):
				var d: ItemData = ItemDB.get_item(item)
				return "Missing %s" % (d.display_name if d else String(item))
	return ""


## Name of a tree/rock/ore in the way of a piece, or "".
func _obstruction(data: BuildPieceData, cell: Vector2i, slot: String, rot: int = 0) -> String:
	if not is_inside_tree():
		return ""
	var box := BoxShape3D.new()
	box.size = (data.collision_size * Vector3(0.9, 0.9, 0.9)).max(Vector3(0.3, 0.3, 0.3))
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = transform_for(data, cell, slot, rot).translated_local(data.collision_center)
	q.collision_mask = Layers.PROP
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		var body := hit.collider as PropBody
		if body and body.data:
			return body.data.display_name
	return ""


## A wall, door, window or fence on the edge between two neighbouring cells.
func _edge_between(a: Vector2i, b: Vector2i, storey: int) -> bool:
	var l := world.layer
	var d := b - a
	if d == Vector2i(0, 1):
		return pieces.has(key(b, slot_at("edge_n", storey), l))
	if d == Vector2i(0, -1):
		return pieces.has(key(a, slot_at("edge_n", storey), l))
	if d == Vector2i(1, 0):
		return pieces.has(key(b, slot_at("edge_w", storey), l))
	if d == Vector2i(-1, 0):
		return pieces.has(key(a, slot_at("edge_w", storey), l))
	return false


## True when one bed lies across the given edge (it covers the cells on both sides).
func _bed_across(cell: Vector2i, base: String, storey: int) -> bool:
	var other := cell - (Vector2i(0, 1) if base == "edge_n" else Vector2i(1, 0))
	var l := world.layer
	var a: BuildPiece = pieces.get(key(cell, slot_at("object", storey), l))
	var b: BuildPiece = pieces.get(key(other, slot_at("object", storey), l))
	return a != null and a == b and a.data.behavior == BuildPieceData.Behavior.BED


func _roof_supported(cell: Vector2i, storey: int = 0) -> bool:
	var l := world.layer
	if _has_wall_around(cell, storey):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if pieces.has(key(cell + d, slot_at("roof", storey), l)):
			return true
	return false


## A wall (or door, window, fence) on any of the 4 edges of a cell, on a storey.
func _has_wall_around(cell: Vector2i, storey: int) -> bool:
	var l := world.layer
	for k in [key(cell, slot_at("edge_n", storey), l), key(cell, slot_at("edge_w", storey), l),
			key(cell + Vector2i(0, 1), slot_at("edge_n", storey), l), key(cell + Vector2i(1, 0), slot_at("edge_w", storey), l)]:
		if pieces.has(k):
			return true
	return false


## An upper floor rests on walls below, or reaches out from such a floor (balcony).
func floor_supported(cell: Vector2i, storey: int) -> bool:
	if storey <= 0:
		return true
	if _has_wall_around(cell, storey - 1) or _stairs_top_at(cell, storey):
		return true
	var l := world.layer
	var seen := {cell: 0}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var d0: int = seen[c]
		if d0 >= BALCONY_REACH:
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n) or not pieces.has(key(n, slot_at("floor", storey), l)):
				continue
			if _has_wall_around(n, storey - 1):
				return true
			seen[n] = d0 + 1
			queue.append(n)
	return false


## A staircase whose top end arrives at `cell` on `storey`.
func _stairs_top_at(cell: Vector2i, storey: int) -> bool:
	for p in get_tree().get_nodes_in_group(&"stairs"):
		var bp := p as BuildPiece
		if bp and bp.layer == world.layer and storey_of(bp.slot) + 1 == storey and bp.stairs_top_cell() == cell:
			return true
	return false


## Storey rules (Milestone 30). "" or why not.
func _storey_rules(data: BuildPieceData, cell: Vector2i, base: String, storey: int, slot: String) -> String:
	var l := world.layer
	var behavior := data.behavior
	if base == "found":
		if pieces.has(key(cell, "floor", l)):
			return "Remove the floor first"
		if foundation_top(cell) - _ground(cell) > 2.6:
			return "Too steep here for a foundation"
		return ""
	if behavior == BuildPieceData.Behavior.STAIRS:
		return ""  # the cells are checked with the rotation in check_stairs()
	if storey == 0:
		return ""
	match base:
		"floor":
			if pieces.has(key(cell, slot_at("roof", storey - 1), l)):
				return "Remove the roof below first"
			if not floor_supported(cell, storey):
				return "Upper floors need walls below them (or a floor within %d cells that has)" % BALCONY_REACH
		"edge_n", "edge_w":
			var other := cell - (Vector2i(0, 1) if base == "edge_n" else Vector2i(1, 0))
			if not (pieces.has(key(cell, slot_at("floor", storey), l)) or pieces.has(key(other, slot_at("floor", storey), l))
					or pieces.has(key(cell, slot_at(base, storey - 1), l))):
				return "Upper walls need a floor next to them or a wall below"
		"object":
			if not pieces.has(key(cell, slot_at("floor", storey), l)):
				return "Put a floor here first"
		"roof":
			pass
	return ""


## Stairs (Milestone 30): the cells a staircase covers, from its foot.
func stair_cells(cell: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := rot_dir(rot)
	for i in STAIR_CELLS:
		out.append(cell + d * i)
	return out


## "" if a staircase fits at `cell` facing `rot` on `storey`.
func check_stairs(cell: Vector2i, rot: int, storey: int) -> String:
	var l := world.layer
	if storey >= MAX_STOREY:
		return "No higher storey to reach"
	for c in stair_cells(cell, rot):
		if pieces.has(key(c, slot_at("object", storey), l)) or pieces.has(key(c, slot_at("stair", storey), l)):
			return "Stairs need %d free cells in a row" % STAIR_CELLS
		if storey > 0 and not pieces.has(key(c, slot_at("floor", storey), l)):
			return "Upper stairs stand on a floor"
		if absf(_base(c) - _base(cell)) > 0.6:
			return "Stairs need flat ground"
		if pieces.has(key(c, slot_at("floor", storey + 1), l)) and c != cell + rot_dir(rot) * (STAIR_CELLS - 1):
			return "There is a floor above the stairs (leave a hole)"
	return ""


## Places a piece. `pay` consumes materials from the player's inventory.
func place(data: BuildPieceData, cell: Vector2i, slot: String, rot: int, player: Player, pay: bool = true) -> BuildPiece:
	if check_place(data, cell, slot, player, pay, rot) != "":
		return null
	if data.behavior == BuildPieceData.Behavior.STAIRS and check_stairs(cell, rot, storey_of(slot)) != "":
		return null
	if player and player.creative:
		pay = false
	if pay and player:
		for item in data.cost:
			player.inventory.remove_item(item, int(data.cost[item]))
	var piece := _spawn(data, cell, slot, rot, world.layer)
	if player:
		piece.set_meta(&"owner", Net.player_name)
	if Net.is_server():
		Net.server.broadcast_build("add", NetServer.piece_entry(piece))
	return piece


func _spawn(data: BuildPieceData, cell: Vector2i, slot: String, rot: int, layer: int) -> BuildPiece:
	var piece := BuildPiece.new()
	piece.cell = cell
	piece.slot = slot
	piece.rot = rot
	piece.layer = layer
	piece.setup(data)
	add_child(piece)
	var saved_layer := world.layer
	world.layer = layer
	piece.global_transform = transform_for(data, cell, slot, rot)
	world.layer = saved_layer
	piece.visible = layer == world.layer
	var k1 := key(cell, slot, layer)
	var under: BuildPiece = pieces.get(k1)
	if under != null and is_instance_valid(under) and k1 in under.extra_keys and is_two_cell(under.data, under.slot):
		# Something takes a bed's foot (older saves): that bed goes back to one cell.
		under.extra_keys.erase(k1)
		var ud := bed_dir(under.rot)
		under.global_position -= Vector3(ud.x, 0, ud.y) * 0.5
	pieces[k1] = piece
	if is_two_cell(data, slot):
		var k2 := key(cell + bed_dir(rot), slot, layer)
		if pieces.has(k2):
			# An older save with something at the bed's foot: keep the old one-cell bed.
			var d := bed_dir(rot)
			piece.global_position -= Vector3(d.x, 0, d.y) * 0.5
		else:
			pieces[k2] = piece
			piece.extra_keys.append(k2)
	if data.behavior == BuildPieceData.Behavior.STAIRS:
		# The other cells of the staircase are taken too (Milestone 30).
		var st := storey_of(slot)
		for c in stair_cells(cell, rot):
			if c != cell:
				var k := key(c, slot_at("stair", st), layer)
				pieces[k] = piece
				piece.extra_keys.append(k)
	if data.behavior == BuildPieceData.Behavior.FOUNDATION:
		piece.set_foundation(_ground(cell), foundation_top(cell) if not piece.has_meta(&"top") else float(piece.get_meta(&"top")))
	NavGrid.invalidate_at(piece.global_position)  # monsters path around it now
	Events.building_changed.emit()
	return piece


## The piece under a world point (edges, then objects, floors, roofs) on a storey.
func piece_at(point: Vector3, storey: int = 0) -> BuildPiece:
	var cell := Vector2i(floori(point.x), floori(point.z))
	var fx := point.x - cell.x
	var fz := point.z - cell.y
	var l := world.layer
	var s := storey
	var edge_keys := []
	if fz < 0.3:
		edge_keys.append(key(cell, slot_at("edge_n", s), l))
	if fz > 0.7:
		edge_keys.append(key(cell + Vector2i(0, 1), slot_at("edge_n", s), l))
	if fx < 0.3:
		edge_keys.append(key(cell, slot_at("edge_w", s), l))
	if fx > 0.7:
		edge_keys.append(key(cell + Vector2i(1, 0), slot_at("edge_w", s), l))
	for k in edge_keys + [key(cell, slot_at("object", s), l), key(cell, slot_at("stair", s), l), key(cell, slot_at("floor", s), l),
			key(cell, slot_at("roof", s), l), key(cell, "found", l)]:
		if pieces.has(k):
			return pieces[k]
	return null


func _erase_keys(piece: BuildPiece) -> void:
	pieces.erase(key(piece.cell, piece.slot, piece.layer))
	for k in piece.extra_keys:
		pieces.erase(k)


## Deconstructs a piece, refunding materials (full refund on your own land).
func remove(piece: BuildPiece, player: Player) -> bool:
	if piece == null or not is_instance_valid(piece):
		return false
	var why := _holds_up(piece)
	if why != "":
		Events.toast.emit(why, Color(1, 0.7, 0.5))
		return false
	if piece.storage and piece.storage.free_slot_count() < piece.storage.capacity:
		Events.toast.emit("Empty the %s first" % piece.data.display_name, Color(1, 0.7, 0.5))
		return false
	var share := 1.0 if (is_claimed(piece.global_position) or piece.data.behavior == BuildPieceData.Behavior.CLAIM) else UNCLAIMED_REFUND
	if player:
		for item in piece.data.cost:
			var n := floori(int(piece.data.cost[item]) * share)
			if n > 0:
				player.give_or_drop(item, n)
	_erase_keys(piece)
	if Net.is_server():
		Net.server.broadcast_build("remove", NetServer.piece_entry(piece))
	piece.collision_layer = 0  # gone for monster pathfinding at once
	NavGrid.invalidate_at(piece.global_position)
	piece.queue_free()
	Events.building_changed.emit()
	return true


## Milestone 30 (Creative mode, screenshots): a two-storey house at `c` (its
## north-west corner cell): a 4 x 4 stone room with a door, a timber upper storey
## with windows, a balcony with a railing, stairs outside and a roof. Free, no checks.
func build_demo_house(c: Vector2i) -> int:
	var l := world.layer
	var n0 := pieces.size()
	var put := func(id: StringName, cell: Vector2i, slot: String, rot: int = 0) -> void:
		if not pieces.has(key(cell, slot, l)):
			_spawn(get_piece_data(id), cell, slot, rot, l)
	for x in range(c.x, c.x + 4):
		for z in range(c.y, c.y + 4):
			put.call(&"stone_floor", Vector2i(x, z), "floor")
	for i in 4:
		put.call(&"stone_wall", Vector2i(c.x + i, c.y), "edge_n")
		put.call(&"wood_door" if i == 1 else &"stone_wall", Vector2i(c.x + i, c.y + 4), "edge_n")
		put.call(&"stone_wall", Vector2i(c.x, c.y + i), "edge_w")
		put.call(&"stone_wall", Vector2i(c.x + 4, c.y + i), "edge_w")
	for x in range(c.x, c.x + 4):
		for z in range(c.y, c.y + 4):
			if not (x == c.x + 3 and z == c.y + 3):
				put.call(&"wood_floor", Vector2i(x, z), "floor@1")
	# Balcony on the south side, with a railing.
	for x in range(c.x, c.x + 6):
		put.call(&"wood_floor", Vector2i(x, c.y + 4), "floor@1")
		if x != c.x + 5:
			put.call(&"wood_fence", Vector2i(x, c.y + 5), "edge_n@1")
	put.call(&"wood_fence", Vector2i(c.x, c.y + 4), "edge_w@1")
	put.call(&"wood_fence", Vector2i(c.x + 6, c.y + 4), "edge_w@1")
	# Upper walls with windows and a door onto the balcony.
	for i in 4:
		put.call(&"wood_window" if i == 2 else &"wood_wall", Vector2i(c.x + i, c.y), "edge_n@1")
		put.call(&"wood_door" if i == 2 else &"wood_wall", Vector2i(c.x + i, c.y + 4), "edge_n@1")
		put.call(&"wood_window" if i == 1 else &"wood_wall", Vector2i(c.x, c.y + i), "edge_w@1")
		put.call(&"wood_window" if i == 1 else &"wood_wall", Vector2i(c.x + 4, c.y + i), "edge_w@1")
	put.call(&"bed", Vector2i(c.x + 1, c.y + 1), "object@1")
	put.call(&"storage_chest", Vector2i(c.x + 2, c.y + 1), "object@1")
	for x in range(c.x, c.x + 4):
		for z in range(c.y, c.y + 4):
			put.call(&"wood_roof", Vector2i(x, z), "roof@1")
	# Stairs up the east side, arriving on the balcony.
	put.call(&"wood_stairs", Vector2i(c.x + 5, c.y + 1), "object", 0)
	put.call(&"wood_ladder", Vector2i(c.x - 1, c.y + 2), "object", 1)
	return pieces.size() - n0


## Milestone 30: you can't take away what holds up the storey above.
func _holds_up(piece: BuildPiece) -> String:
	var l := piece.layer
	var parts := split_slot(piece.slot)
	var base: String = parts[0]
	var st: int = parts[1]
	if base == "found":
		for k in [key(piece.cell, "floor", l), key(piece.cell, "object", l), key(piece.cell, "edge_n", l), key(piece.cell, "edge_w", l)]:
			if pieces.has(k):
				return "Remove what stands on the foundation first"
	if base == "floor":
		if pieces.has(key(piece.cell, slot_at("object", st), l)):
			return "Remove the furniture on it first"
	if base.begins_with("edge") and st < MAX_STOREY:
		if pieces.has(key(piece.cell, slot_at(base, st + 1), l)):
			return "A wall above stands on this one"
	return ""


## Pieces (active layer) whose centre is within `r` metres of `pos` (flat distance).
func pieces_near(pos: Vector3, r: float) -> Array:
	var out := []
	var r2 := r * r
	var l := world.layer if world else 0
	for k in pieces:
		var p: BuildPiece = pieces[k]
		if p.layer != l or not is_instance_valid(p) or p.is_queued_for_deletion() or p.health <= 0.0:
			continue
		if k != key(p.cell, p.slot, p.layer):
			continue
		if Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length_squared() <= r2 \
				and absf(p.global_position.y - pos.y) < 6.0:
			out.append(p)
	return out


## A piece broke (raiders): no refund, but a chest spills its contents.
func destroy(piece: BuildPiece) -> void:
	if piece == null or not is_instance_valid(piece) or piece.is_queued_for_deletion():
		return
	if piece.storage and world:
		for i in piece.storage.capacity:
			var st = piece.storage.get_slot(i)
			if st != null:
				world.spawn_pickup(st.id, int(st.count), piece.global_position + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)), false)
	VFX.burst(piece.get_parent(), piece.global_position + Vector3(0, 1.0, 0), 1.8, Color(0.55, 0.45, 0.35, 0.8), 0.35)
	_erase_keys(piece)
	if Net.is_server():
		Net.server.broadcast_build("remove", NetServer.piece_entry(piece))
	Events.toast.emit("Your %s was destroyed!" % piece.data.display_name, Color(1, 0.5, 0.4))
	piece.collision_layer = 0  # gone for monster pathfinding at once
	NavGrid.invalidate_at(piece.global_position)
	piece.queue_free()
	Events.building_changed.emit()


## Repairs a damaged piece to full health, paying the materials. Returns "" or why not.
func repair(piece: BuildPiece, player: Player) -> String:
	if piece == null or not piece.is_damaged():
		return "Nothing to repair"
	var cost := piece.repair_cost()
	for item in cost:
		if player.inventory.count_of(item) < int(cost[item]):
			var d: ItemData = ItemDB.get_item(item)
			return "Repair needs %d %s" % [int(cost[item]), d.display_name if d else String(item)]
	for item in cost:
		player.inventory.remove_item(item, int(cost[item]))
	piece.repair_full()
	return ""


## Repairs every damaged piece you can afford within `r` metres. Returns how many.
func repair_all_near(pos: Vector3, r: float, player: Player) -> int:
	var n := 0
	for p in pieces_near(pos, r):
		if p.is_damaged() and repair(p, player) == "":
			n += 1
	return n


# --- Land & shelter ----------------------------------------------------------------------

func is_claimed(pos: Vector3) -> bool:
	for c in get_tree().get_nodes_in_group(&"land_claims"):
		var n := c as BuildPiece
		if n and n.layer == world.layer and Vector2(pos.x - n.global_position.x, pos.z - n.global_position.z).length() <= n.claim_radius():
			return true
	return false


## A roof directly overhead.
func is_sheltered(pos: Vector3) -> bool:
	var cell := Vector2i(floori(pos.x), floori(pos.z))
	var l := world.layer
	for st in MAX_STOREY + 1:
		var y := storey_y(cell, st) if st > 0 else 0.0
		# A roof on any storey, or an upper floor above you, keeps the rain off.
		if pieces.has(key(cell, slot_at("roof", st), l)) and (st == 0 or storey_y(cell, st + 1) > pos.y + 0.5):
			return true
		if st > 0 and pieces.has(key(cell, slot_at("floor", st), l)) and y > pos.y + 1.0:
			return true
	return false


## The storey the point is on (0 = ground floor), from its height over the cell's base.
func storey_at(pos: Vector3) -> int:
	var cell := Vector2i(floori(pos.x), floori(pos.z))
	return clampi(floori((pos.y - _base(cell) + 0.6) / WALL_HEIGHT), 0, MAX_STOREY)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_roof_check -= delta
	if _roof_check > 0.0:
		return
	_roof_check = 0.2
	# Roofs over you disappear so the top-down camera can see inside.
	var inside := is_sheltered(world.player.global_position)
	if inside != _roofs_hidden or inside:
		_roofs_hidden = inside
		var p := world.player.global_position
		# Milestone 30: also everything on the storeys above you.
		var my_storey := storey_at(p)
		for k in pieces:
			var piece: BuildPiece = pieces[k]
			if piece.layer != world.layer:
				continue
			var parts := split_slot(piece.slot)
			var above: bool = parts[0] == "roof" or int(parts[1]) > my_storey
			if above:
				piece.visible = not (inside and piece.global_position.distance_to(p) < 16.0 and piece.global_position.y > p.y + 1.0)


## Shows only the pieces of the active layer.
func refresh_layer() -> void:
	for k in pieces:
		var piece: BuildPiece = pieces[k]
		piece.visible = piece.layer == world.layer
		piece.process_mode = Node.PROCESS_MODE_INHERIT if piece.layer == world.layer else Node.PROCESS_MODE_DISABLED


# --- Save ------------------------------------------------------------------------------

func to_save() -> Array:
	var out := []
	for k in pieces:
		var p: BuildPiece = pieces[k]
		if k != key(p.cell, p.slot, p.layer):
			continue  # the other cells of a staircase
		out.append({"id": String(p.data.id), "x": p.cell.x, "z": p.cell.y, "slot": p.slot, "rot": p.rot,
			"layer": p.layer, "data": p.save_data(), "owner": String(p.get_meta(&"owner", ""))})
	return out


func from_save(list: Array) -> void:
	# Foundations first, then storey by storey (upper pieces stand on what is below).
	var order := {"found": 0, "floor": 1, "edge_n": 2, "edge_w": 2, "object": 3, "stair": 3, "roof": 4}
	list = list.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := split_slot(String(a.get("slot", "")))
		var pb := split_slot(String(b.get("slot", "")))
		var ka: int = int(pa[1]) * 10 + int(order.get(pa[0], 5))
		var kb: int = int(pb[1]) * 10 + int(order.get(pb[0], 5))
		return ka < kb)
	for e in list:
		var data := get_piece_data(StringName(e.get("id", "")))
		if data == null:
			continue
		var piece := _spawn(data, Vector2i(int(e.x), int(e.z)), String(e.slot), int(e.get("rot", 0)), int(e.get("layer", 0)))
		piece.load_data(e.get("data", {}))
		if String(e.get("owner", "")) != "":
			piece.set_meta(&"owner", String(e.owner))
	refresh_layer()
