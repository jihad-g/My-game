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

const PIECE_DIR := "res://data/build_pieces/"
const WALL_HEIGHT := 2.6
const FLOOR_TOP := 0.13
const MAX_CLAIMS := 5
## Share of materials returned when deconstructing outside your land.
const UNCLAIMED_REFUND := 0.5

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


static func slot_kind(data: BuildPieceData) -> String:
	match data.placement:
		BuildPieceData.Placement.FLOOR:
			return "floor"
		BuildPieceData.Placement.ROOF:
			return "roof"
		BuildPieceData.Placement.EDGE:
			return "edge"
	return "object"


## Grid address under a world point for `data`: {cell, slot}.
func address_for(data: BuildPieceData, point: Vector3) -> Dictionary:
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
	return {"cell": cell, "slot": slot}


func _ground(cell: Vector2i) -> float:
	return world.generator.get_height_at(Vector3(cell.x + 0.5, 0, cell.y + 0.5), world.layer)


## World transform of a piece at an address.
func transform_for(data: BuildPieceData, cell: Vector2i, slot: String, rot: int) -> Transform3D:
	var g := _ground(cell)
	var pos := Vector3(cell.x + 0.5, g, cell.y + 0.5)
	var basis := Basis(Vector3.UP, rot * PI * 0.5)
	match slot:
		"edge_n":
			g = maxf(g, _ground(cell - Vector2i(0, 1)))
			pos = Vector3(cell.x + 0.5, g, cell.y)
			basis = Basis.IDENTITY
		"edge_w":
			g = maxf(g, _ground(cell - Vector2i(1, 0)))
			pos = Vector3(cell.x, g, cell.y + 0.5)
			basis = Basis(Vector3.UP, PI * 0.5)
		"roof":
			pos.y = g + WALL_HEIGHT
		"object":
			if pieces.has(key(cell, "floor", world.layer)):
				pos.y = g + FLOOR_TOP
	return Transform3D(basis, pos)


## "" if the piece can be placed there, otherwise why not.
func check_place(data: BuildPieceData, cell: Vector2i, slot: String, player: Player, pay: bool = true) -> String:
	if pieces.has(key(cell, slot, world.layer)):
		return "Something is already built here"
	var center := Vector3(cell.x + 0.5, 0, cell.y + 0.5)
	center.y = _ground(cell)
	if player:
		var flat := Vector2(center.x - player.global_position.x, center.z - player.global_position.z)
		if flat.length() > 9.0:
			return "Too far away"
		if player.character.level < data.required_level:
			return "Requires level %d" % data.required_level
		# Don't wall yourself in: solid pieces can't overlap the player.
		if data.blocks_movement and slot != "roof" and slot != "floor" and flat.length() < 0.7:
			return "You're standing there"
	if world.layer == TerrainGenerator.Layer.SURFACE and center.y < TerrainGenerator.WATER_Y and not slot.begins_with("edge"):
		return "Can't build in water"
	if world.layer == TerrainGenerator.Layer.SURFACE:
		var town := world.generator.settlements.in_region_of(cell.x, cell.y)
		var margin := data.claim_radius if data.behavior == BuildPieceData.Behavior.CLAIM else 2.0
		if town and town.contains(center, margin):
			return "This land belongs to %s" % town.name
	if slot != "roof":
		var blocker := _obstruction(data, cell, slot)
		if blocker != "":
			return "Blocked by %s" % blocker
	if slot == "roof" and not _roof_supported(cell):
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
func _obstruction(data: BuildPieceData, cell: Vector2i, slot: String) -> String:
	if not is_inside_tree():
		return ""
	var box := BoxShape3D.new()
	box.size = (data.collision_size * Vector3(0.9, 0.9, 0.9)).max(Vector3(0.3, 0.3, 0.3))
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = transform_for(data, cell, slot, 0).translated_local(data.collision_center)
	q.collision_mask = Layers.PROP
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		var body := hit.collider as PropBody
		if body and body.data:
			return body.data.display_name
	return ""


func _roof_supported(cell: Vector2i) -> bool:
	var l := world.layer
	for k in [key(cell, "edge_n", l), key(cell, "edge_w", l), key(cell + Vector2i(0, 1), "edge_n", l),
			key(cell + Vector2i(1, 0), "edge_w", l)]:
		if pieces.has(k):
			return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if pieces.has(key(cell + d, "roof", l)):
			return true
	return false


## Places a piece. `pay` consumes materials from the player's inventory.
func place(data: BuildPieceData, cell: Vector2i, slot: String, rot: int, player: Player, pay: bool = true) -> BuildPiece:
	if check_place(data, cell, slot, player, pay) != "":
		return null
	if pay and player:
		for item in data.cost:
			player.inventory.remove_item(item, int(data.cost[item]))
	return _spawn(data, cell, slot, rot, world.layer)


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
	pieces[key(cell, slot, layer)] = piece
	Events.building_changed.emit()
	return piece


## The piece under a world point (edges, then objects, floors, roofs).
func piece_at(point: Vector3) -> BuildPiece:
	var cell := Vector2i(floori(point.x), floori(point.z))
	var fx := point.x - cell.x
	var fz := point.z - cell.y
	var l := world.layer
	var edge_keys := []
	if fz < 0.3:
		edge_keys.append(key(cell, "edge_n", l))
	if fz > 0.7:
		edge_keys.append(key(cell + Vector2i(0, 1), "edge_n", l))
	if fx < 0.3:
		edge_keys.append(key(cell, "edge_w", l))
	if fx > 0.7:
		edge_keys.append(key(cell + Vector2i(1, 0), "edge_w", l))
	for k in edge_keys + [key(cell, "object", l), key(cell, "floor", l), key(cell, "roof", l)]:
		if pieces.has(k):
			return pieces[k]
	return null


## Deconstructs a piece, refunding materials (full refund on your own land).
func remove(piece: BuildPiece, player: Player) -> bool:
	if piece == null or not is_instance_valid(piece):
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
	pieces.erase(key(piece.cell, piece.slot, piece.layer))
	piece.queue_free()
	Events.building_changed.emit()
	return true


## Pieces (active layer) whose centre is within `r` metres of `pos` (flat distance).
func pieces_near(pos: Vector3, r: float) -> Array:
	var out := []
	var r2 := r * r
	var l := world.layer if world else 0
	for k in pieces:
		var p: BuildPiece = pieces[k]
		if p.layer != l or not is_instance_valid(p) or p.is_queued_for_deletion() or p.health <= 0.0:
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
	pieces.erase(key(piece.cell, piece.slot, piece.layer))
	Events.toast.emit("Your %s was destroyed!" % piece.data.display_name, Color(1, 0.5, 0.4))
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
	return pieces.has(key(Vector2i(floori(pos.x), floori(pos.z)), "roof", world.layer))


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
		for k in pieces:
			var piece: BuildPiece = pieces[k]
			if piece.slot == "roof" and piece.layer == world.layer:
				piece.visible = not (inside and piece.global_position.distance_to(p) < 16.0)


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
		out.append({"id": String(p.data.id), "x": p.cell.x, "z": p.cell.y, "slot": p.slot, "rot": p.rot,
			"layer": p.layer, "data": p.save_data()})
	return out


func from_save(list: Array) -> void:
	for e in list:
		var data := get_piece_data(StringName(e.get("id", "")))
		if data == null:
			continue
		var piece := _spawn(data, Vector2i(int(e.x), int(e.z)), String(e.slot), int(e.get("rot", 0)), int(e.get("layer", 0)))
		piece.load_data(e.get("data", {}))
	refresh_layer()
