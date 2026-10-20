class_name SettlementSite
extends Node3D
## A settlement instantiated in the world near the player: merged static meshes,
## collision, interactive doors and crafting stations, lights, the notice board
## and the townsfolk (NPC). Created and freed by SettlementManager as the
## player approaches/leaves; everything is rebuilt from the deterministic
## layout, so nothing here is saved except shop/reputation state elsewhere.

var info: SettlementInfo
var layout: SettlementLayout
var manager: Node
var npcs: Array[NPC] = []
var trader: NPC

## True once geometry is attached and townsfolk exist.
var is_built := false
## A raid is attacking this settlement (Milestone 7): villagers hide, guards fight.
var under_attack := false
var _task := -1
## Milestone 36: the main-thread part of the build (meshes, collision, doors,
## lights, townsfolk) runs as small steps over several frames, about
## STEP_BUDGET_MS per frame. A capital used to cost one ~120 ms frame.
const STEP_BUDGET_MS := 3.0
## Collision boxes added per step.
const BOXES_PER_STEP := 200
var _steps: Array[Callable] = []
var _steps_queued := false
## Frames the staged build took (tests, debug).
var build_frames := 0
var _roof_nodes: Dictionary = {}  # building index -> MeshInstance3D
var _hidden_roof := -1
var _roof_check := 0.0
## Street graph: node id -> Vector3 (local); adjacency id -> Array[int]
var _nodes: Array[Vector3] = []
var _adj: Dictionary = {}
var _blockers: Array[Rect2] = []
var _day := 0
## Size of the mesh tiles a settlement is split into (metres, Milestone 36).
const MESH_TILE := 32.0


func setup(p_info: SettlementInfo, p_manager: Node, day: int) -> void:
	info = p_info
	manager = p_manager
	name = "Site_%s" % info.id.replace(":", "_").replace(",", "_")
	_day = day
	# Milestone 36: a capital's layout takes ~10 ms, so it is built on the worker
	# thread with the meshes (see _build_threaded); villages too, for simplicity.
	BuildingManager.all_pieces()  # fill the piece registry on the main thread first


func _ready() -> void:
	position = Vector3(info.center.x, info.ground_y(), info.center.y)
	# Merging a kingdom's ~2800 pieces takes 100+ ms: do it on a worker thread
	# (pure array work), then attach the nodes on the main thread.
	load("res://src/building/build_meshes.gd")
	_task = WorkerThreadPool.add_task(_build_threaded, false, "settlement_site")


func _build_threaded() -> void:
	layout = SettlementLayout.build(info, _day)
	_build_static()
	_build_graph()


## Turns the worker's result into the list of main-thread build steps.
func _queue_steps() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _steps_queued:
		return
	_steps_queued = true
	for key: String in _arrays.keys():
		_steps.append(_attach_mesh.bind(key))
	_steps.append(_make_collision_body)
	for i in range(0, _boxes.size(), BOXES_PER_STEP):
		_steps.append(_add_boxes.bind(i, mini(i + BOXES_PER_STEP, _boxes.size())))
	_steps.append(func() -> void: _boxes.clear())
	_steps.append(_build_interactive)
	for d in layout.npcs:
		_steps.append(_spawn_npc.bind(d))
	_steps.append(_finish_steps)


## Runs build steps until `budget_ms` is used (at least one step). Returns true when done.
func _run_steps(budget_ms: float) -> bool:
	var t0 := Time.get_ticks_usec()
	while not _steps.is_empty():
		var step: Callable = _steps.pop_front()
		step.call()
		if budget_ms >= 0.0 and (Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			break
	return _steps.is_empty()


func _finish_steps() -> void:
	is_built = true
	_trader_due = true  # next frame: the wagon and trader are a step of their own


var _trader_due := false


## Blocks until the site is ready (tests, teleports).
func finish_now() -> void:
	if is_built or (_task == -1 and not _steps_queued):
		return  # built already, or not in the tree yet (nothing started)
	_queue_steps()
	_run_steps(-1.0)


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# --- Geometry --------------------------------------------------------------------------

## Worker thread: merge every static piece into tiled BlockMeshes (pure arrays).
var _arrays: Dictionary = {}   # "solid@x_z"/"walls@x_z"/"glow@x_z"/"roof_<i>" -> surface arrays
var _boxes: Array = []         # [size, transform]


func _build_static() -> void:
	var merged := StaticGeometry.merge(layout.statics, layout.boxes, layout.roofs, info.color, MESH_TILE)
	_arrays = merged.arrays
	_boxes = merged.boxes


## Main thread: one merged mesh becomes a node (a build step).
func _attach_mesh(key: String) -> void:
	if not _arrays.has(key):
		return
	var mi := StaticGeometry.attach_mesh(self, key, _arrays[key])
	if key.begins_with("roof_"):
		_roof_nodes[int(key.substr(5))] = mi
	_arrays.erase(key)


var _collision_body: StaticBody3D
var _box_shapes := {}  # one shared BoxShape3D per size


func _make_collision_body() -> void:
	_collision_body = StaticGeometry.make_body(self, Layers.BUILDING)


func _add_boxes(from: int, to: int) -> void:
	StaticGeometry.add_boxes(_collision_body, _boxes, from, to, _box_shapes)


## Number of collision boxes on the site (tests).
func collision_box_count() -> int:
	return _collision_body.get_shape_owners().size() if _collision_body else 0


func _build_interactive() -> void:
	var door_data := BuildingManager.get_piece_data(&"wood_door")
	for xf: Transform3D in layout.doors:
		var d := BuildPiece.new()
		d.setup(door_data)
		d.transform = xf
		add_child(d)
	for st in layout.stations:
		var p := BuildPiece.new()
		p.setup(BuildingManager.get_piece_data(st.piece))
		p.transform = st.xform
		add_child(p)
	for l: Vector3 in layout.lights:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.4)
		light.light_energy = 1.6
		light.omni_range = 8.0
		light.position = l
		add_child(light)
	var board := NoticeBoard.new()
	board.site = self
	board.transform = layout.board
	add_child(board)


# --- Streets (NPC pathfinding) --------------------------------------------------------------

func _build_graph() -> void:
	for b in layout.buildings:
		var r: Rect2 = b.rect
		_blockers.append(r.grow(0.75))  # Milestone 40: the wall shell sits 0.5 m outside the floor
	for o: Rect2 in layout.obstacles:
		_blockers.append(o.grow(0.25))
	for f in layout.farms:
		var fr: Rect2 = f.rect
		_blockers.append(fr.grow(0.25))
	# Streets run along lot boundaries (x or z = 5 + 10k), between the buildings.
	var lines: Array[int] = [-25, -15, -5, 5, 15, 25]
	var ids := {}
	for z in lines:
		for x in lines:
			ids[Vector2i(x, z)] = _nodes.size()
			_nodes.append(Vector3(x, 0, z))
	for key: Vector2i in ids:
		var a: int = ids[key]
		_adj[a] = []
		for d: Vector2i in [Vector2i(SettlementLayout.LOT, 0), Vector2i(0, SettlementLayout.LOT), Vector2i(-SettlementLayout.LOT, 0), Vector2i(0, -SettlementLayout.LOT)]:
			if ids.has(key + d) and _segment_clear(_nodes[a], _nodes[ids[key + d]]):
				_adj[a].append(ids[key + d])


func _segment_clear(a: Vector3, b: Vector3) -> bool:
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	for r in _blockers:
		# Axis-aligned segments: test the thin rectangle they sweep.
		var seg := Rect2(p.min(q), (q - p).abs()).grow(0.05)
		if seg.intersects(r):
			return false
	return true


## Nearest graph nodes reachable from `p` by a clear straight segment.
func _entries(p: Vector3) -> Array[int]:
	var out: Array[int] = []
	var order := range(_nodes.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _nodes[a].distance_squared_to(p) < _nodes[b].distance_squared_to(p))
	for i in order:
		if _segment_clear_any(p, _nodes[i]):
			out.append(i)
			if out.size() >= 2:
				break
	return out


## Straight line (not axis-aligned) clearance test by sampling.
func _segment_clear_any(a: Vector3, b: Vector3) -> bool:
	var n := maxi(2, int(a.distance_to(b) / 0.5))
	for k in n + 1:
		var q := a.lerp(b, float(k) / n)
		var p2 := Vector2(q.x, q.z)
		for r in _blockers:
			if r.has_point(p2):
				return false
	return true


## Walking route between two local points (outside buildings), along the streets.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	if _segment_clear_any(from, to):
		path.append(to)
		return path
	var starts := _entries(from)
	var goals := _entries(to)
	if starts.is_empty() or goals.is_empty():
		path.append(to)
		return path
	# Dijkstra over the small street grid.
	var dist := {}
	var prev := {}
	var open: Array[int] = []
	for s in starts:
		dist[s] = from.distance_to(_nodes[s])
		open.append(s)
	var best_goal := -1
	var best_total := INF
	while not open.is_empty():
		open.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b])
		var cur: int = open.pop_front()
		if goals.has(cur):
			var total: float = dist[cur] + _nodes[cur].distance_to(to)
			if total < best_total:
				best_total = total
				best_goal = cur
		for nb: int in _adj.get(cur, []):
			var nd: float = dist[cur] + _nodes[cur].distance_to(_nodes[nb])
			if nd < dist.get(nb, INF):
				dist[nb] = nd
				prev[nb] = cur
				if not open.has(nb):
					open.append(nb)
	if best_goal < 0:
		path.append(to)
		return path
	var chain: Array[int] = []
	var c := best_goal
	while true:
		chain.push_front(c)
		if not prev.has(c):
			break
		c = prev[c]
	for id in chain:
		path.append(_nodes[id])
	path.append(to)
	return path


# --- People --------------------------------------------------------------------------------

func _spawn_npc(d: Dictionary) -> void:
	var n := NPC.new()
	n.setup(self, d)
	add_child(n)
	npcs.append(n)


func set_under_attack(on: bool) -> void:
	if on == under_attack:
		return
	under_attack = on
	for n in npcs:
		if is_instance_valid(n):
			if on:
				n._update_activity(false)
			else:
				n.recover()


func is_trader_day(day: int) -> bool:
	return posmod(day + int(HashUtils.to_unit(info.seed, 55) * 3.0), 3) == 0


## The travelling trader visits every third day (08:00-18:00).
func refresh_trader() -> void:
	if not is_built:
		return
	var dn: DayNightCycle = World.instance.day_night if World.instance else null
	var here := dn != null and is_trader_day(dn.day) and dn.hour >= 8.0 and dn.hour < 18.0
	if here and trader == null and not layout.points.trader.is_empty():
		var at: Vector3 = layout.points.trader[0]
		var wagon := MeshInstance3D.new()
		wagon.name = "Wagon"
		wagon.mesh = BuildMeshes.get_mesh(&"wagon")
		wagon.material_override = Materials.vertex_color()
		wagon.position = at + Vector3(1.8, 0, 0)
		add_child(wagon)
		trader = NPC.new()
		trader.setup(self, {"name": SettlementLayout.FIRST_NAMES[HashUtils.hash3(info.seed, dn.day, 5) % SettlementLayout.FIRST_NAMES.size()],
			"role": &"trader", "home": -1, "work": at, "work_rot": -PI * 0.5, "farm": -1,
			"seed": HashUtils.hash3(info.seed, dn.day, 9), "index": 1000})
		add_child(trader)
		npcs.append(trader)
	elif not here and trader != null:
		npcs.erase(trader)
		trader.queue_free()
		trader = null
		var w := get_node_or_null("Wagon")
		if w:
			w.queue_free()


func npc_by_role(role: StringName) -> NPC:
	for n in npcs:
		if n.role == role:
			return n
	return null


# --- Crowd (Milestone 37) -----------------------------------------------------------------

## Grid cell size for finding people near a townsperson (metres).
const CROWD_CELL := 2.0
var _crowd: Dictionary = {}  # Vector2i -> Array of [node, radius, is_npc]
var _crowd_tick := -1
var _near: Array = []


## People near a local point: townsfolk who are out and about, the player and
## the other players, each as [node, radius, is_npc]. The grid is rebuilt once
## per physics tick. The returned array is reused - read it before calling again.
func people_near(local: Vector3, exclude: Node) -> Array:
	var tick := Engine.get_physics_frames()
	if tick != _crowd_tick:
		_crowd_tick = tick
		_rebuild_crowd()
	_near.clear()
	var c := Vector2i(floori(local.x / CROWD_CELL), floori(local.z / CROWD_CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c + Vector2i(dx, dz)
			if _crowd.has(k):
				for e in _crowd[k]:
					if e[0] != exclude:
						_near.append(e)
	return _near


## Where a crowd entry stands now, in this site's local space.
func person_pos(e: Array) -> Vector3:
	var n: Node3D = e[0]
	if not is_instance_valid(n):
		return Vector3.INF
	return n.position if e[2] else to_local(n.global_position)


func _rebuild_crowd() -> void:
	_crowd.clear()
	for n in npcs:
		if is_instance_valid(n) and n.visible and not n.asleep and not n.downed:
			_crowd_add(n.position, n, NPC.BODY_RADIUS, true)
	var w := World.instance
	if w and w.player and not w.player.is_dead and w.player.is_inside_tree():
		var r := NPC.MOUNTED_RADIUS if w.player.is_riding() else NPC.BODY_RADIUS
		_crowd_add(to_local(w.player.global_position), w.player, r, false)
	for rp in get_tree().get_nodes_in_group(&"remote_players"):
		var r3 := rp as Node3D
		if r3 and r3.visible:
			_crowd_add(to_local(r3.global_position), r3, NPC.BODY_RADIUS, false)


func _crowd_add(local: Vector3, node: Node3D, radius: float, is_npc: bool) -> void:
	var c := Vector2i(floori(local.x / CROWD_CELL), floori(local.z / CROWD_CELL))
	if not _crowd.has(c):
		_crowd[c] = []
	_crowd[c].append([node, radius, is_npc])


# --- Per frame --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_built:
		if _task != -1:
			if not WorkerThreadPool.is_task_completed(_task):
				return
			_queue_steps()
		elif not _steps_queued:
			return
		build_frames += 1
		_run_steps(STEP_BUDGET_MS)
		return
	if _trader_due:
		_trader_due = false
		refresh_trader()
	_roof_check -= delta
	if _roof_check > 0.0 or World.instance == null or World.instance.player == null:
		return
	_roof_check = 0.2
	var p := to_local(World.instance.player.global_position)
	# v0.49.0: in first person you are inside, so the roof stays (you see the ceiling).
	var inside := -1 if CameraRig.first_person_active() else building_at(p)
	if inside != _hidden_roof:
		if _roof_nodes.has(_hidden_roof):
			_roof_nodes[_hidden_roof].visible = true
		_hidden_roof = inside
		if _roof_nodes.has(inside):
			_roof_nodes[inside].visible = false


## Index of the building containing a local point (or -1).
func building_at(local: Vector3) -> int:
	if layout == null:
		return -1  # still being laid out on the worker thread
	for b in layout.buildings:
		var r: Rect2 = b.rect
		if r.has_point(Vector2(local.x, local.z)):
			return b.id
	return -1
