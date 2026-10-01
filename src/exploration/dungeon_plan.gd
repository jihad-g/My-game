class_name DungeonPlan
extends RefCounted
## Procedural dungeon floor (Milestone 6). Deterministic per (dungeon, floor).
##
## Rooms sit in a grid of SLOT x SLOT slots, centred, so neighbouring rooms line
## up and corridors (3 wide) are straight. A random spanning tree connects the
## rooms (plus a loop at higher ranks). Room roles: start (exit portal), normal
## (monsters), trap (spike floor), treasure (chest + guards), end (stairs down,
## or the boss arena on the last floor) and one secret room hidden behind a
## cracked wall.

const SLOT := 16
const CORRIDOR := 3
## Floors per rank E..S
const FLOORS := [1, 1, 2, 2, 3, 3]

enum Room { START, NORMAL, TRAP, TREASURE, END, BOSS, SECRET }

var rank := 0
var theme := 0
var floor_index := 0
var floor_count := 1
var is_final := true
## Vector2i cell -> true
var cells: Dictionary = {}
## {rect: Rect2i, type: Room, slot: Vector2i}
var rooms: Array = []
## Corridor rectangles (Rect2i) for floor collision.
var corridors: Array = []
## Secret passage: {rect: Rect2i (corridor), block_pos: Vector3, block_rot: float}
var secret: Dictionary = {}
var start_room := 0
var end_room := 0

var _rng := RandomNumberGenerator.new()


static func generate(poi: PoiInfo, p_floor: int) -> DungeonPlan:
	var d := DungeonPlan.new()
	d.rank = poi.rank
	d.theme = poi.theme
	d.floor_index = p_floor
	d.floor_count = FLOORS[poi.rank]
	d.is_final = p_floor >= d.floor_count - 1
	d._rng.seed = HashUtils.hash3(poi.seed, 6060, p_floor)
	d._build()
	return d


func _build() -> void:
	var gw := 3 + rank / 2
	var gh := 3 + (1 if rank >= 3 else 0)
	var target := clampi(4 + rank + floor_index, 4, gw * gh - 1)
	# Random tree growth from the start slot.
	var start := Vector2i(0, gh / 2)
	var used := {start: true}
	var order: Array[Vector2i] = [start]
	var edges: Array = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var guard := 0
	while order.size() < target and guard < 500:
		guard += 1
		var from: Vector2i = order[_rng.randi() % order.size()]
		var dir: Vector2i = dirs[_rng.randi() % 4]
		var to := from + dir
		if to.x < 0 or to.y < 0 or to.x >= gw or to.y >= gh or used.has(to):
			continue
		used[to] = true
		order.append(to)
		edges.append([from, to])
	# An extra loop at higher ranks.
	if rank >= 2:
		for from in order:
			for dir in dirs:
				var to: Vector2i = from + dir
				if used.has(to) and not _has_edge(edges, from, to) and _rng.randf() < 0.15:
					edges.append([from, to])
	# Distances from the start (BFS over edges) -> farthest room is the end.
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for e in edges:
			var o: Vector2i = e[1] if e[0] == c else (e[0] if e[1] == c else Vector2i(-99, -99))
			if o.x != -99 and not dist.has(o):
				dist[o] = dist[c] + 1
				queue.append(o)
	var end: Vector2i = start
	for s in order:
		if int(dist.get(s, 0)) > int(dist.get(end, 0)):
			end = s
	# Rooms
	var slot_to_room := {}
	for s in order:
		var big := s == end and is_final
		var w := 13 if big else _rng.randi_range(7, 11)
		var h := 13 if big else _rng.randi_range(7, 11)
		var cx := s.x * SLOT + SLOT / 2
		var cz := s.y * SLOT + SLOT / 2
		var rect := Rect2i(cx - w / 2, cz - h / 2, w, h)
		var type := Room.NORMAL
		if s == start:
			type = Room.START
		elif s == end:
			type = Room.BOSS if is_final else Room.END
		slot_to_room[s] = rooms.size()
		rooms.append({"rect": rect, "type": type, "slot": s})
	start_room = slot_to_room[start]
	end_room = slot_to_room[end]
	# Special rooms among the rest.
	var others: Array = []
	for i in rooms.size():
		if rooms[i].type == Room.NORMAL:
			others.append(i)
	_shuffle(others)
	if not others.is_empty():
		rooms[others.pop_back()].type = Room.TREASURE
	for t in (1 if rank >= 1 else 0) + (1 if rank >= 4 else 0):
		if not others.is_empty():
			rooms[others.pop_back()].type = Room.TRAP
	for i in rooms.size():
		_fill_rect(rooms[i].rect)
	for e in edges:
		_corridor(rooms[slot_to_room[e[0]]].rect, rooms[slot_to_room[e[1]]].rect)
	_secret_room(used, order, gw, gh, dirs, slot_to_room)


func _has_edge(edges: Array, a: Vector2i, b: Vector2i) -> bool:
	for e in edges:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return true
	return false


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _fill_rect(r: Rect2i) -> void:
	for x in range(r.position.x, r.end.x):
		for z in range(r.position.y, r.end.y):
			cells[Vector2i(x, z)] = true


## Straight corridor between two rooms in neighbouring slots.
func _corridor(a: Rect2i, b: Rect2i) -> Rect2i:
	var ca := a.get_center()
	var cb := b.get_center()
	var r: Rect2i
	if ca.y == cb.y:
		var x0 := mini(a.end.x, b.end.x)
		var x1 := maxi(a.position.x, b.position.x)
		r = Rect2i(x0, ca.y - CORRIDOR / 2, x1 - x0, CORRIDOR)
	else:
		var z0 := mini(a.end.y, b.end.y)
		var z1 := maxi(a.position.y, b.position.y)
		r = Rect2i(ca.x - CORRIDOR / 2, z0, CORRIDOR, z1 - z0)
	_fill_rect(r)
	corridors.append(r)
	return r


## One secret room in a free slot next to a normal room, behind a cracked wall.
func _secret_room(used: Dictionary, order: Array[Vector2i], gw: int, gh: int, dirs: Array[Vector2i], slot_to_room: Dictionary) -> void:
	var candidates: Array = []
	for s in order:
		var ri: int = slot_to_room[s]
		if rooms[ri].type != Room.NORMAL and rooms[ri].type != Room.TREASURE:
			continue
		for dir in dirs:
			var to: Vector2i = s + dir
			if to.x >= 0 and to.y >= 0 and to.x < gw + 1 and to.y < gh and not used.has(to):
				candidates.append([s, to])
	if candidates.is_empty():
		return
	var pick: Array = candidates[_rng.randi() % candidates.size()]
	var from_room: int = slot_to_room[pick[0]]
	var s: Vector2i = pick[1]
	var rect := Rect2i(s.x * SLOT + SLOT / 2 - 3, s.y * SLOT + SLOT / 2 - 3, 7, 7)
	var idx := rooms.size()
	rooms.append({"rect": rect, "type": Room.SECRET, "slot": s})
	_fill_rect(rect)
	var cor := _corridor(rooms[from_room].rect, rect)
	# The cracked wall seals the corridor where it leaves the known room.
	var fr: Rect2i = rooms[from_room].rect
	var pos: Vector3
	var rot := 0.0
	if cor.size.x > cor.size.y:  # horizontal corridor
		var x := cor.position.x if cor.position.x >= fr.end.x else cor.end.x
		pos = Vector3(x, 0, cor.position.y + cor.size.y * 0.5)
		rot = PI * 0.5
	else:
		var z := cor.position.y if cor.position.y >= fr.end.y else cor.end.y
		pos = Vector3(cor.position.x + cor.size.x * 0.5, 0, z)
	secret = {"room": idx, "rect": cor, "block_pos": pos, "block_rot": rot}


## Centre of a room (local metres).
func room_center(i: int) -> Vector3:
	var r: Rect2i = rooms[i].rect
	return Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)


## Random interior point of a room, away from its walls.
func room_point(i: int, rng: RandomNumberGenerator, margin: float = 1.5) -> Vector3:
	var r: Rect2i = rooms[i].rect
	return Vector3(rng.randf_range(r.position.x + margin, r.end.x - margin), 0, rng.randf_range(r.position.y + margin, r.end.y - margin))


func room_at(local: Vector3) -> int:
	var c := Vector2i(floori(local.x), floori(local.z))
	for i in rooms.size():
		if (rooms[i].rect as Rect2i).has_point(c):
			return i
	return -1
