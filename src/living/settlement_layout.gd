class_name SettlementLayout
extends RefCounted
## Deterministic plan of a settlement: buildings, decorations, stations, doors,
## farms, waypoints and the NPC roster. Built from a SettlementInfo; turned into
## nodes by SettlementSite.
##
## Coordinates are local to the settlement origin (centre column corner at the
## flattened ground height). Cell (x, z) spans [x, x+1] x [z, z+1]. Lots are
## LOT x LOT cells: villages use a 5x5 lot grid, kingdoms 7x7 inside a wall.

const LOT := 10
const FLOOR_TOP := 0.13
const ROOF_Y := 2.6

const FIRST_NAMES := ["Ada", "Bram", "Cora", "Dain", "Edda", "Finn", "Greta", "Hal", "Ines", "Jory", "Kara", "Lorn",
	"Mira", "Ned", "Olga", "Pim", "Quill", "Rosa", "Sten", "Tilda", "Ulf", "Vera", "Wim", "Yara", "Zeb", "Ansel",
	"Brin", "Cleo", "Dov", "Elin", "Fenna", "Gil", "Hanne", "Ivo", "Juna", "Kip", "Lena", "Milo", "Nora", "Otto",
	"Petra", "Rurik", "Saga", "Tomas", "Una", "Vik", "Wren", "Ysolde"]

enum Side { NORTH, EAST, SOUTH, WEST }

var info: SettlementInfo
## {mesh: StringName or Mesh, xform: Transform3D, box_size: Vector3, box_center: Vector3, fade: bool, glow: bool}
var statics: Array = []
## Collision-only boxes {size, xform}.
var boxes: Array = []
## building index -> Array of {mesh, xform}
var roofs: Dictionary = {}
## {id, kind, rect: Rect2 (local metres), door_out: Vector3, inside: Vector3, sleep: Array[Vector3]}
var buildings: Array = []
## Door transforms (interactive BuildPiece doors).
var doors: Array = []
## {piece: StringName, xform}
var stations: Array = []
var lights: Array = []
## Notice board transform (requests).
var board := Transform3D.IDENTITY
## {id, cells: Array[Vector2i], crop: StringName, work: Array[Vector3]}
var farms: Array = []
## Named waypoint lists.
var points := {"plaza": [], "wander": [], "patrol": [], "gate_guard": [], "stall": [], "trader": []}
## {name, role, home, work: Vector3, work_rot: float, farm, seed}
var npcs: Array = []


static func build(p_info: SettlementInfo, day: int = 1) -> SettlementLayout:
	var l := SettlementLayout.new()
	l.info = p_info
	if p_info.is_kingdom():
		l._build_kingdom(day)
	else:
		l._build_village(day)
	return l


func _r(salt: int) -> float:
	return HashUtils.to_unit(info.seed, salt)


# --- Primitives ------------------------------------------------------------------------

func _deco(mesh, xform: Transform3D, box_size: Vector3 = Vector3.ZERO, box_center: Vector3 = Vector3.ZERO, fade: bool = false) -> void:
	statics.append({"mesh": mesh, "xform": xform, "box_size": box_size, "box_center": box_center, "fade": fade, "glow": false})


func _piece(id: StringName, xform: Transform3D) -> void:
	var d := BuildingManager.get_piece_data(id)
	_deco(d.mesh, xform, d.collision_size if d.blocks_movement else Vector3.ZERO, d.collision_center, d.fade_near_camera)
	if id == &"torch":
		_deco(&"torch_flame", xform)
		statics[-1].glow = true


static func _rot(r: int) -> Basis:
	return Basis(Vector3.UP, posmod(r, 4) * PI * 0.5)


static func _edge_n(x: int, z: int) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0, z))


static func _edge_w(x: int, z: int) -> Transform3D:
	return Transform3D(_rot(1), Vector3(x, 0, z + 0.5))


## Frame of a building whose door is on `side`: front = outward, across = along the door wall.
static func _frame(x0: int, z0: int, w: int, d: int, side: int) -> Dictionary:
	match side:
		Side.SOUTH:
			return {"rot": 0, "origin": Vector3(x0, 0, z0 + d), "across": Vector3(1, 0, 0), "inward": Vector3(0, 0, -1), "width": w, "depth": d}
		Side.EAST:
			return {"rot": 1, "origin": Vector3(x0 + w, 0, z0 + d), "across": Vector3(0, 0, -1), "inward": Vector3(-1, 0, 0), "width": d, "depth": w}
		Side.NORTH:
			return {"rot": 2, "origin": Vector3(x0 + w, 0, z0), "across": Vector3(-1, 0, 0), "inward": Vector3(0, 0, 1), "width": w, "depth": d}
	return {"rot": 3, "origin": Vector3(x0, 0, z0), "across": Vector3(0, 0, 1), "inward": Vector3(1, 0, 0), "width": d, "depth": w}


static func _at(f: Dictionary, u: float, v: float, y: float = 0.0) -> Vector3:
	return f.origin + f.across * u + f.inward * v + Vector3(0, y, 0)


## Door side facing the plaza for a lot at (i, j).
static func _side_toward_center(i: int, j: int) -> int:
	if absi(i) >= absi(j) and i != 0:
		return Side.WEST if i > 0 else Side.EAST
	return Side.NORTH if j > 0 else Side.SOUTH


# --- Buildings -------------------------------------------------------------------------

## Walled building. `open_front` leaves the door wall out (smithy). Returns its index.
func _building(kind: StringName, x0: int, z0: int, w: int, d: int, side: int, stone: bool, open_front: bool = false) -> int:
	var idx := buildings.size()
	var f := _frame(x0, z0, w, d, side)
	var wall := &"stone_wall" if stone else &"wood_wall"
	var door_u := int(f.width) / 2
	# Floor
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			_deco(&"stone_floor" if stone or open_front else &"wood_floor", Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0, z + 0.5)))
	boxes.append({"size": Vector3(w, FLOOR_TOP, d), "xform": Transform3D(Basis.IDENTITY, Vector3(x0 + w * 0.5, FLOOR_TOP * 0.5, z0 + d * 0.5))})
	# Walls: walk the perimeter edge by edge in the building frame.
	for side_i in 4:
		var sf := _frame(x0, z0, w, d, (side + side_i) % 4)
		for u in int(sf.width):
			var p: Vector3 = _at(sf, u + 0.5, 0.0)
			var xf := Transform3D(_rot(sf.rot), p)
			if side_i == 0:
				if open_front:
					continue
				if u == door_u:
					doors.append(xf)
					continue
			var piece := wall
			if int(sf.width) >= 4 and side_i != 0 and u == int(sf.width) / 2 and side_i != 2:
				piece = &"wood_window"
			_piece(piece, xf)
	# Roof
	var roof_piece := &"wood_roof" if stone else &"thatch_roof"
	var rd := BuildingManager.get_piece_data(roof_piece)
	var list: Array = []
	for x in range(x0, x0 + w):
		for z in range(z0, z0 + d):
			list.append({"mesh": rd.mesh, "xform": Transform3D(Basis.IDENTITY, Vector3(x + 0.5, ROOF_Y, z + 0.5))})
	roofs[idx] = list
	var inside: Vector3 = _at(f, f.width * 0.5, f.depth * 0.5, FLOOR_TOP)
	buildings.append({
		"id": idx, "kind": kind, "rect": Rect2(x0, z0, w, d), "side": side, "frame": f,
		"door_out": _at(f, door_u + 0.5, -1.4), "door_in": _at(f, door_u + 0.5, 1.0, FLOOR_TOP),
		"inside": inside, "sleep": [],
	})
	return idx


func _furnish_home(idx: int, beds: int) -> void:
	var b: Dictionary = buildings[idx]
	var f: Dictionary = b.frame
	var r: int = f.rot
	for k in beds:
		var u := 0.5 + k * 1.0
		_piece(&"bed", Transform3D(_rot(r), _at(f, u, f.depth - 1.0, FLOOR_TOP)))
		b.sleep.append(_at(f, u, f.depth - 1.0, FLOOR_TOP + 0.3))
	_piece(&"table", Transform3D(_rot(r), _at(f, f.width - 1.5, f.depth - 2.0, FLOOR_TOP)))
	_piece(&"chair", Transform3D(_rot(r), _at(f, f.width - 1.5, f.depth - 2.8, FLOOR_TOP)))
	_piece(&"storage_chest", Transform3D(_rot(r + 2), _at(f, f.width - 0.5, f.depth - 0.5, FLOOR_TOP)))
	_deco(&"barrel", Transform3D(Basis.IDENTITY, _at(f, 0.5, 1.5, FLOOR_TOP)), Vector3(0.55, 0.8, 0.55), Vector3(0, 0.4, 0))


func _house(i: int, j: int, stone: bool, beds: int = 2) -> int:
	var side := _side_toward_center(i, j)
	var w := 6 if side == Side.NORTH or side == Side.SOUTH else 5
	var d := 5 if side == Side.NORTH or side == Side.SOUTH else 6
	var x0 := i * LOT - w / 2
	var z0 := j * LOT - d / 2
	var idx := _building(&"house", x0, z0, w, d, side, stone)
	_furnish_home(idx, beds)
	return idx


func _shop(i: int, j: int, stone: bool) -> int:
	var idx := _house(i, j, stone, 1)
	buildings[idx].kind = &"shop"
	var f: Dictionary = buildings[idx].frame
	var u: float = int(f.width) / 2 + 2.3
	_deco(&"market_stall", Transform3D(_rot(f.rot), _at(f, u, -1.7)), Vector3(1.8, 1.0, 0.7), Vector3(0, 0.5, 0))
	buildings[idx]["work"] = _at(f, u, -0.9)
	buildings[idx]["work_rot"] = f.rot * PI * 0.5
	buildings[idx]["counter"] = _at(f, u, -2.7)
	_deco(&"crate", Transform3D(Basis.IDENTITY, _at(f, u + 1.3, -1.0)), Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0))
	return idx


func _smithy(i: int, j: int) -> int:
	var side := _side_toward_center(i, j)
	var x0 := i * LOT - 3
	var z0 := j * LOT - 3
	var idx := _building(&"smithy", x0, z0, 6, 6, side, true, true)
	var f: Dictionary = buildings[idx].frame
	var r: int = f.rot
	stations.append({"piece": &"forge", "xform": Transform3D(_rot(r), _at(f, 3.0, f.depth - 1.0, FLOOR_TOP))})
	stations.append({"piece": &"workbench", "xform": Transform3D(_rot(r + 1), _at(f, 0.9, f.depth - 2.5, FLOOR_TOP))})
	_deco(&"anvil", Transform3D(_rot(r), _at(f, 3.0, 2.6, FLOOR_TOP)), Vector3(0.7, 0.8, 0.45), Vector3(0, 0.4, 0))
	_deco(&"barrel", Transform3D(Basis.IDENTITY, _at(f, 5.4, 1.0, FLOOR_TOP)), Vector3(0.55, 0.8, 0.55), Vector3(0, 0.4, 0))
	_deco(&"crate", Transform3D(Basis.IDENTITY, _at(f, 5.3, 4.8, FLOOR_TOP)), Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0))
	buildings[idx]["work"] = _at(f, 3.0, 1.7, FLOOR_TOP)
	buildings[idx]["work_rot"] = (r + 2) * PI * 0.5
	buildings[idx]["counter"] = _at(f, 3.0, 0.4, FLOOR_TOP)
	return idx


func _farm(i: int, j: int, salt: int, day: int) -> void:
	var side := _side_toward_center(i, j)
	var x0 := i * LOT - 4
	var z0 := j * LOT - 4
	var crops := [&"wheat", &"carrot", &"pumpkin"]
	var crop: StringName = crops[int(_r(salt) * 3.0) % 3]
	var cells: Array[Vector2i] = []
	var work: Array = []
	var stage := clampi(int(posmod(day + int(_r(salt + 1) * 7.0), 5)), 0, 3)
	for x in range(x0 + 1, x0 + 8):
		for z in range(z0 + 1, z0 + 8):
			if (z - z0) % 2 == 1:
				cells.append(Vector2i(x, z))
				_deco(&"farmland", Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0, z + 0.5)))
				_deco(StringName("crop_%s_%d" % [crop, stage]), Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 0.1, z + 0.5)))
			elif x % 2 == 0:
				work.append(Vector3(x + 0.5, 0, z + 0.5))
	# Fence with a gate toward the plaza.
	for s in 4:
		var f := _frame(x0, z0, 8, 8, (side + s) % 4)
		for u in int(f.width):
			if s == 0 and (u == 3 or u == 4):
				continue
			_piece(&"wood_fence", Transform3D(_rot(f.rot), _at(f, u + 0.5, 0.0)))
	_deco(&"hay_bale", Transform3D(Basis.IDENTITY, Vector3(x0 + 7.0, 0, z0 + 0.8)), Vector3(1.0, 0.6, 0.6), Vector3(0, 0.3, 0))
	farms.append({"id": farms.size(), "cells": cells, "crop": crop, "stage": stage, "work": work,
		"rect": Rect2(x0, z0, 8, 8),
		"gate": _at(_frame(x0, z0, 8, 8, side), 4.0, -1.0)})


func _plaza(half: int, stalls: int) -> void:
	_deco(&"well", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), Vector3(1.9, 1.0, 1.9), Vector3(0, 0.5, 0))
	board = Transform3D(_rot(0), Vector3(-3.5, 0, 3.5))
	_deco(&"notice_board", board, Vector3(1.6, 1.8, 0.2), Vector3(0, 0.9, 0))
	for k in stalls:
		var x := 3.5 if k % 2 == 0 else -6.5
		var z := 3.5 + (k / 2) * 3.0 if k % 2 == 0 else -3.5
		var rot := 0 if k % 2 == 0 else 2
		var xf := Transform3D(_rot(rot), Vector3(x, 0, z))
		_deco(&"market_stall", xf, Vector3(1.8, 1.0, 0.7), Vector3(0, 0.5, 0))
		points.stall.append({"work": xf * Vector3(0, 0, -0.8), "rot": (rot + 2) * PI * 0.5, "counter": xf * Vector3(0, 0, 1.0)})
	var th := half + 0.5
	for p: Vector2 in [Vector2(-th, -th), Vector2(th, -th), Vector2(-th, th), Vector2(th, th)]:
		_piece(&"torch", Transform3D(Basis.IDENTITY, Vector3(p.x, 0, p.y)))
		lights.append(Vector3(p.x, 1.45, p.y))
	_deco(&"bench", Transform3D(_rot(1), Vector3(-2.8, 0, -0.5)), Vector3(0.4, 0.5, 1.6), Vector3(0, 0.25, 0))
	_deco(&"bench", Transform3D(_rot(3), Vector3(2.8, 0, -0.5)), Vector3(0.4, 0.5, 1.6), Vector3(0, 0.25, 0))
	if info.kingdom_id != "":
		_deco(&"banner_pole", Transform3D(Basis.IDENTITY, Vector3(0, 0, -3.2)), Vector3(0.2, 3.6, 0.2), Vector3(0, 1.8, 0))
		_deco(&"banner_cloth", Transform3D(Basis.IDENTITY, Vector3(0, 0, -3.2)))
	for k in 8:
		var a := TAU * k / 8.0
		points.plaza.append(Vector3(cos(a) * 3.0, 0, sin(a) * 3.0))
	points.trader.append(Vector3(half + 1.5, 0, 0))


# --- Village ------------------------------------------------------------------------------

func _build_village(day: int) -> void:
	_plaza(4, 1)
	var ring1: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	var start := int(_r(3) * 8.0) % 8
	var homes: Array[int] = []
	var shop := -1
	var smithy := -1
	for n in 8:
		var lot: Vector2i = ring1[(start + n) % 8]
		if n == 0:
			shop = _shop(lot.x, lot.y, false)
			homes.append(shop)
		elif n == 4:
			smithy = _smithy(lot.x, lot.y)
		else:
			homes.append(_house(lot.x, lot.y, false, 2 if _r(20 + n) < 0.6 else 1))
	var farm_ids: Array[int] = []
	var n_farms := 0
	for j in range(-2, 3):
		for i in range(-2, 3):
			if absi(i) < 2 and absi(j) < 2:
				continue
			var roll := _r(100 + (i + 2) * 5 + (j + 2))
			if roll < 0.32 and n_farms < 5:
				_farm(i, j, 200 + i * 7 + j, day)
				farm_ids.append(farms.size() - 1)
				n_farms += 1
			elif roll < 0.5:
				homes.append(_house(i, j, false, 1))
			elif roll < 0.62:
				_deco(&"hay_bale", Transform3D(_rot(int(roll * 10)), Vector3(i * LOT, 0, j * LOT)), Vector3(1.0, 0.6, 0.6), Vector3(0, 0.3, 0))
	for j in range(-2, 3):
		for i in range(-2, 3):
			points.wander.append(Vector3(i * LOT + (LOT * 0.5 if i >= 0 else -LOT * 0.5), 0, j * LOT * 0.5))
	_roster(homes, shop, smithy, farm_ids, [], -1)


# --- Kingdom ------------------------------------------------------------------------------

func _build_kingdom(day: int) -> void:
	_plaza(6, 3)
	# The keep: a great stone hall north of the plaza.
	var keep := _building(&"keep", -7, -20, 14, 10, Side.SOUTH, true)
	var kf: Dictionary = buildings[keep].frame
	_deco(&"throne", Transform3D(_rot(0), _at(kf, 7.0, 8.8, FLOOR_TOP)), Vector3(1.2, 1.0, 1.0), Vector3(0, 0.5, 0))
	for v in range(1, 8):
		_deco(&"carpet", Transform3D(Basis.IDENTITY, _at(kf, 7.0, v + 0.5)))
	for u in [3.0, 11.0]:
		_piece(&"table", Transform3D(_rot(1), _at(kf, u, 5.0, FLOOR_TOP)))
		_piece(&"chair", Transform3D(_rot(1), _at(kf, u - 0.9, 4.5, FLOOR_TOP)))
		_piece(&"chair", Transform3D(_rot(3), _at(kf, u + 0.9, 5.5, FLOOR_TOP)))
		_deco(&"barrel", Transform3D(Basis.IDENTITY, _at(kf, u + (-2.0 if u < 7 else 2.0), 8.8, FLOOR_TOP)), Vector3(0.55, 0.8, 0.55), Vector3(0, 0.4, 0))
	for u in [3.0, 11.0]:
		_piece(&"torch", Transform3D(Basis.IDENTITY, _at(kf, u, 1.5, FLOOR_TOP)))
		lights.append(_at(kf, u, 1.5, FLOOR_TOP + 1.45))
		_deco(&"banner_pole", Transform3D(Basis.IDENTITY, _at(kf, u + (-1.5 if u < 7 else 1.5), -1.0)), Vector3(0.2, 3.6, 0.2), Vector3(0, 1.8, 0))
		_deco(&"banner_cloth", Transform3D(Basis.IDENTITY, _at(kf, u + (-1.5 if u < 7 else 1.5), -1.0)))
	for k in 3:
		buildings[keep].sleep.append(_at(kf, 2.0 + k * 1.5, 8.0, FLOOR_TOP + 0.3))
		_piece(&"bed", Transform3D(_rot(0), _at(kf, 1.0 + k * 1.2, 9.0, FLOOR_TOP)))
	buildings[keep]["work"] = _at(kf, 7.0, 7.9, FLOOR_TOP)
	buildings[keep]["work_rot"] = 0.0
	buildings[keep]["counter"] = _at(kf, 7.0, 6.0, FLOOR_TOP)
	# Barracks
	var barracks := _building(&"barracks", -24, -23, 8, 6, Side.EAST, true)
	for k in 4:
		var bf: Dictionary = buildings[barracks].frame
		_piece(&"bed", Transform3D(_rot(bf.rot), _at(bf, 0.6 + k * 1.3, bf.depth - 1.0, FLOOR_TOP)))
		buildings[barracks].sleep.append(_at(bf, 0.6 + k * 1.3, bf.depth - 1.0, FLOOR_TOP + 0.3))
	var homes: Array[int] = []
	var shop := _shop(2, -1, true)
	homes.append(shop)
	var smithy := _smithy(-2, 1)
	var farm_ids: Array[int] = []
	for j in range(-3, 4):
		for i in range(-3, 4):
			if absi(i) <= 1 and j >= -2 and j <= 0:
				continue  # keep + plaza
			if Vector2i(i, j) in [Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -2)]:
				continue
			var outer := absi(i) == 3 or absi(j) == 3
			var roll := _r(300 + (i + 3) * 7 + (j + 3))
			if outer and roll < 0.3 and farm_ids.size() < 6:
				_farm(i, j, 400 + i * 7 + j, day)
				farm_ids.append(farms.size() - 1)
			elif not outer or roll < 0.75:
				homes.append(_house(i, j, true, 2 if roll < 0.7 else 1))
	_walls()
	for j in range(-3, 4):
		for i in range(-3, 4):
			points.wander.append(Vector3(i * LOT + LOT * 0.5, 0, j * LOT + LOT * 0.5))
	_roster(homes, shop, smithy, farm_ids, [keep], barracks)


## Perimeter wall with four gates and towers.
func _walls() -> void:
	var half := 35
	for x in range(-half, half):
		if absi(x) > 1 and x != -2:
			_piece(&"stone_wall", _edge_n(x, -half))
			_piece(&"stone_wall", _edge_n(x, half))
	for z in range(-half, half):
		if absi(z) > 1 and z != -2:
			_piece(&"stone_wall", _edge_w(-half, z))
			_piece(&"stone_wall", _edge_w(half, z))
	var towers: Array[Vector2] = [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half),
		Vector2(-3.2, half), Vector2(3.2, half), Vector2(-3.2, -half), Vector2(3.2, -half),
		Vector2(half, -3.2), Vector2(half, 3.2), Vector2(-half, -3.2), Vector2(-half, 3.2)]
	for t in towers:
		_deco(&"stone_tower", Transform3D(Basis.IDENTITY, Vector3(t.x, 0, t.y)), Vector3(2.4, 6.0, 2.4), Vector3(0, 2.5, 0), true)
	for g: Vector2 in [Vector2(0, half), Vector2(0, -half)]:
		for sx in [-3.2, 3.2]:
			lights.append(Vector3(g.x + sx, 3.5, g.y + (-1.5 if g.y > 0 else 1.5)))
		points.gate_guard.append(Vector3(g.x + 1.6, 0, g.y + (-2.0 if g.y > 0 else 2.0)))
		points.gate_guard.append(Vector3(g.x - 1.6, 0, g.y + (-2.0 if g.y > 0 else 2.0)))
	var inner := half - 3.0
	for p: Vector2 in [Vector2(-inner, -inner), Vector2(0, -inner), Vector2(inner, -inner), Vector2(inner, 0),
			Vector2(inner, inner), Vector2(0, inner), Vector2(-inner, inner), Vector2(-inner, 0)]:
		points.patrol.append(Vector3(p.x, 0, p.y))


# --- People --------------------------------------------------------------------------------

func _npc(role: StringName, home: int, work: Vector3, work_rot: float, farm: int = -1) -> void:
	var k := npcs.size()
	var h := HashUtils.hash3(info.seed, 77, k)
	npcs.append({"name": FIRST_NAMES[h % FIRST_NAMES.size()], "role": role, "home": home, "work": work,
		"work_rot": work_rot, "farm": farm, "seed": h, "index": k})


func _roster(homes: Array[int], shop: int, smithy: int, farm_ids: Array[int], nobles: Array, barracks: int) -> void:
	var home_i := 0
	var next_home := func() -> int:
		var hid: int = homes[home_i % homes.size()]
		home_i += 1
		return hid
	# Merchant lives above the shop.
	var sb: Dictionary = buildings[shop]
	_npc(&"merchant", shop, sb.work, sb.work_rot)
	home_i = 1
	if smithy >= 0:
		var smb: Dictionary = buildings[smithy]
		_npc(&"blacksmith", next_home.call(), smb.work, smb.work_rot)
	for fid in farm_ids:
		var farm: Dictionary = farms[fid]
		_npc(&"farmer", next_home.call(), farm.work[0] if not farm.work.is_empty() else farm.gate, 0.0, fid)
	for n in nobles:
		var nb: Dictionary = buildings[n]
		_npc(&"noble", n, nb.work, nb.work_rot)
	if barracks >= 0:
		var bb: Dictionary = buildings[barracks]
		for g in points.gate_guard.size():
			_npc(&"guard", barracks, points.gate_guard[g], 0.0)
		for g in 2:
			_npc(&"guard", barracks, points.patrol[g * 4], 0.0)
		# Royal market: the kingdom's plaza stalls get a second merchant.
		if not points.stall.is_empty():
			var st: Dictionary = points.stall[0]
			_npc(&"royal_merchant", next_home.call(), st.work, st.rot)
	var villagers := 3 + int(_r(900) * 3.0) + (4 if info.is_kingdom() else 0)
	for v in villagers:
		_npc(&"villager", next_home.call(), points.plaza[v % points.plaza.size()], 0.0)


## World transform of a local point.
func to_world(p: Vector3) -> Vector3:
	return p + Vector3(info.center.x, info.ground_y(), info.center.y)
