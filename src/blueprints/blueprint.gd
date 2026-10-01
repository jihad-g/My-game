class_name Blueprint
extends RefCounted
## A building design (Milestone 8): a list of build pieces at grid addresses
## relative to an anchor cell (0, 0). Shared with the external web designer
## (web/blueprint-designer) through a small JSON format:
##
##   {
##     "format": "shardlands-blueprint", "version": 1,
##     "name": "Starter Hut", "author": "...", "description": "...",
##     "pieces": [ {"id": "wood_wall", "x": 0, "z": -2, "slot": "edge_n", "rot": 0}, ... ]
##   }
##
## Slots are the building grid's ("floor", "object", "roof", "edge_n",
## "edge_w" - see BuildingManager). `rot` (0-3 quarter turns) matters for
## floor/object/roof pieces; edge pieces take their direction from the slot.

const FORMAT := "shardlands-blueprint"
const VERSION := 1
const MAX_PIECES := 2000
const SLOTS := ["floor", "object", "roof", "edge_n", "edge_w"]
## Build order: floors, then walls/doors, then furniture, then roofs (they need walls).
const ORDER := {"floor": 0, "edge_n": 1, "edge_w": 1, "object": 2, "roof": 3}

var name := "Untitled"
var author := ""
var description := ""
## Array of {id: StringName, x: int, z: int, slot: String, rot: int}
var pieces: Array = []
## Problems found while parsing (unknown pieces, bad slots...). Empty = clean.
var warnings: PackedStringArray = []


# --- Serialization --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var list := []
	for e in pieces:
		list.append({"id": String(e.id), "x": int(e.x), "z": int(e.z), "slot": String(e.slot), "rot": int(e.rot)})
	return {"format": FORMAT, "version": VERSION, "name": name, "author": author, "description": description, "pieces": list}


func to_json() -> String:
	return JSON.stringify(to_dict(), "  ")


## Parses JSON text. Returns null if it isn't a blueprint at all; otherwise a
## Blueprint whose `warnings` list anything that had to be dropped.
static func from_json(text: String) -> Blueprint:
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return null
	return from_dict(data)


static func from_dict(d: Dictionary) -> Blueprint:
	if String(d.get("format", "")) != FORMAT:
		return null
	var bp := Blueprint.new()
	bp.name = String(d.get("name", "Untitled")).strip_edges().substr(0, 48)
	if bp.name == "":
		bp.name = "Untitled"
	bp.author = String(d.get("author", "")).substr(0, 48)
	bp.description = String(d.get("description", "")).substr(0, 400)
	if int(d.get("version", 1)) > VERSION:
		bp.warnings.append("Made with a newer version (%d); some parts may be ignored" % int(d.version))
	var seen := {}
	var raw = d.get("pieces", [])
	if not raw is Array:
		bp.warnings.append("No piece list")
		return bp
	for e in raw:
		if bp.pieces.size() >= MAX_PIECES:
			bp.warnings.append("Too many pieces: only the first %d were kept" % MAX_PIECES)
			break
		if not e is Dictionary:
			continue
		var id := StringName(String(e.get("id", "")))
		var data := BuildingManager.get_piece_data(id)
		if data == null:
			bp.warnings.append("Unknown piece '%s' skipped" % id)
			continue
		var slot := String(e.get("slot", ""))
		var kind := BuildingManager.slot_kind(data)
		if slot == "" or slot == "edge":
			slot = "edge_n" if kind == "edge" else kind
		if not slot in SLOTS or (kind == "edge") != slot.begins_with("edge") or (kind != "edge" and slot != kind):
			bp.warnings.append("%s can't go in slot '%s' - skipped" % [data.display_name, slot])
			continue
		var entry := {"id": id, "x": int(e.get("x", 0)), "z": int(e.get("z", 0)), "slot": slot, "rot": posmod(int(e.get("rot", 0)), 4)}
		var k := entry_key(entry)
		if seen.has(k):
			bp.warnings.append("Two pieces in the same spot at %d,%d (%s) - kept the first" % [entry.x, entry.z, slot])
			continue
		seen[k] = true
		bp.pieces.append(entry)
	return bp


static func entry_key(e: Dictionary) -> String:
	return "%d,%d,%s" % [int(e.x), int(e.z), String(e.slot)]


func duplicate_bp() -> Blueprint:
	var bp := Blueprint.from_dict(to_dict())
	return bp


# --- Geometry ---------------------------------------------------------------------------------

## The entry rotated by `q` quarter turns (90° each, same direction as piece rotation)
## around the anchor cell's centre.
static func rotate_entry(e: Dictionary, q: int) -> Dictionary:
	var out := e.duplicate()
	for i in posmod(q, 4):
		var x := int(out.x)
		var z := int(out.z)
		match String(out.slot):
			"edge_n":
				# Edge along X centred at (x+0.5, z) -> along Z at (z, -x-0.5): west edge of cell (z, -x-1)
				out.slot = "edge_w"
				out.x = z
				out.z = -x - 1
			"edge_w":
				# Edge along Z centred at (x, z+0.5) -> along X at (z+0.5, -x): north edge of cell (z, -x)
				out.slot = "edge_n"
				out.x = z
				out.z = -x
			_:
				# Cell centre (x+0.5, z+0.5) -> (z+0.5, -x-0.5): cell (z, -x-1)
				out.x = z
				out.z = -x - 1
				out.rot = (int(out.rot) + 1) % 4
	return out


func rotated(q: int) -> Blueprint:
	var bp := Blueprint.new()
	bp.name = name
	bp.author = author
	bp.description = description
	for e in pieces:
		bp.pieces.append(rotate_entry(e, q))
	return bp


## Bounding box of the cells the design covers: Rect2i (position = min cell).
func bounds() -> Rect2i:
	if pieces.is_empty():
		return Rect2i()
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for e in pieces:
		var c := Vector2i(int(e.x), int(e.z))
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Pieces sorted into build order (floors, walls, furniture, roofs; near the anchor first).
func build_order() -> Array:
	var list := pieces.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = ORDER.get(String(a.slot), 2)
		var ob: int = ORDER.get(String(b.slot), 2)
		if oa != ob:
			return oa < ob
		var da := absi(int(a.x)) + absi(int(a.z))
		var db := absi(int(b.x)) + absi(int(b.z))
		if da != db:
			return da < db
		return entry_key(a) < entry_key(b))
	return list


# --- Resources --------------------------------------------------------------------------------

## Total materials: item id -> count.
func total_cost() -> Dictionary:
	var out := {}
	for e in pieces:
		var data := BuildingManager.get_piece_data(StringName(e.id))
		if data:
			for item in data.cost:
				out[item] = int(out.get(item, 0)) + int(data.cost[item])
	return out


## What's still needed given `available` (item -> count): item -> missing count.
func missing(available: Dictionary) -> Dictionary:
	var out := {}
	var cost := total_cost()
	for item in cost:
		var short := int(cost[item]) - int(available.get(item, 0))
		if short > 0:
			out[item] = short
	return out


## Highest character level any piece needs.
func required_level() -> int:
	var lv := 1
	for e in pieces:
		var data := BuildingManager.get_piece_data(StringName(e.id))
		if data:
			lv = maxi(lv, data.required_level)
	return lv


## Piece counts per id (for the UI).
func counts() -> Dictionary:
	var out := {}
	for e in pieces:
		out[e.id] = int(out.get(e.id, 0)) + 1
	return out


# --- Capture ----------------------------------------------------------------------------------

## A blueprint of the pieces built around `center` (within `radius` m), relative to its cell.
static func capture(manager: BuildingManager, center: Vector3, radius: float, layer: int, p_name: String) -> Blueprint:
	var bp := Blueprint.new()
	bp.name = p_name
	var anchor := Vector2i(floori(center.x), floori(center.z))
	for k in manager.pieces:
		var piece: BuildPiece = manager.pieces[k]
		if not is_instance_valid(piece) or piece.layer != layer:
			continue
		if Vector2(piece.cell.x + 0.5 - center.x, piece.cell.y + 0.5 - center.z).length() > radius:
			continue
		if piece.data.behavior == BuildPieceData.Behavior.CLAIM:
			continue  # land claims are personal; designs don't carry them
		bp.pieces.append({"id": piece.data.id, "x": piece.cell.x - anchor.x, "z": piece.cell.y - anchor.y,
			"slot": piece.slot, "rot": piece.rot})
	bp.pieces = bp.build_order()
	return bp
