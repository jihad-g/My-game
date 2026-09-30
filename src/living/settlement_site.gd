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
var _task := -1
var _roof_nodes: Dictionary = {}  # building index -> MeshInstance3D
var _hidden_roof := -1
var _roof_check := 0.0
## Street graph: node id -> Vector3 (local); adjacency id -> Array[int]
var _nodes: Array[Vector3] = []
var _adj: Dictionary = {}
var _blockers: Array[Rect2] = []


func setup(p_info: SettlementInfo, p_manager: Node, day: int) -> void:
	info = p_info
	manager = p_manager
	name = "Site_%s" % info.id.replace(":", "_").replace(",", "_")
	layout = SettlementLayout.build(info, day)


func _ready() -> void:
	position = Vector3(info.center.x, info.ground_y(), info.center.y)
	# Merging a kingdom's ~2800 pieces takes 100+ ms: do it on a worker thread
	# (pure array work), then attach the nodes on the main thread.
	load("res://src/building/build_meshes.gd")
	_task = WorkerThreadPool.add_task(_build_threaded, false, "settlement_site")


func _build_threaded() -> void:
	_build_static()
	_build_graph()


func _finish_build() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_attach_static()
	_build_interactive()
	_spawn_npcs()
	is_built = true


## Blocks until the site is ready (tests, teleports).
func finish_now() -> void:
	if not is_built and _task != -1:
		_finish_build()


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# --- Geometry --------------------------------------------------------------------------

## Worker thread: merge every static piece into a few BlockMeshes (pure arrays).
var _arrays: Dictionary = {}   # "solid"/"walls"/"glow"/"roof_<i>" -> surface arrays
var _boxes: Array = []         # [size, transform]


func _build_static() -> void:
	var groups := {&"solid": BlockMesh.new(), &"walls": BlockMesh.new(), &"glow": BlockMesh.new()}
	for s in layout.statics:
		var g: BlockMesh = groups[&"glow"] if s.get("glow", false) else (groups[&"walls"] if s.fade else groups[&"solid"])
		g.xform = s.xform
		BuildMeshes.build_into(g, s.mesh, info.color)
		var size: Vector3 = s.box_size
		if size != Vector3.ZERO:
			_boxes.append([size, (s.xform as Transform3D) * Transform3D(Basis.IDENTITY, s.box_center)])
	for b in layout.boxes:
		_boxes.append([b.size, b.xform])
	for k in groups:
		if not groups[k].is_empty():
			_arrays[String(k)] = groups[k].to_arrays()
	for idx in layout.roofs:
		var rb := BlockMesh.new()
		for r in layout.roofs[idx]:
			rb.xform = r.xform
			BuildMeshes.build_into(rb, r.mesh)
		_arrays["roof_%d" % idx] = rb.to_arrays()


## Main thread: turn the merged arrays and boxes into nodes.
func _attach_static() -> void:
	var mats := {"solid": Materials.vertex_color(), "walls": Materials.vertex_color_occluder(), "glow": Materials.vertex_color_emissive()}
	for key: String in _arrays:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays[key])
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize().replace(" ", "")
		mi.mesh = mesh
		mi.material_override = mats.get(key, Materials.vertex_color())
		if key == "glow":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		if key.begins_with("roof_"):
			_roof_nodes[int(key.substr(5))] = mi
	_arrays.clear()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Layers.BUILDING
	body.collision_mask = 0
	var shapes := {}  # one shared BoxShape3D per size
	for b in _boxes:
		var size: Vector3 = b[0]
		var key := size.snapped(Vector3(0.001, 0.001, 0.001))
		if not shapes.has(key):
			var box := BoxShape3D.new()
			box.size = size
			shapes[key] = box
		var cs := CollisionShape3D.new()
		cs.shape = shapes[key]
		cs.transform = b[1]
		body.add_child(cs)
	add_child(body)
	_boxes.clear()


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
		_blockers.append(r.grow(0.25))
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

func _spawn_npcs() -> void:
	for d in layout.npcs:
		var n := NPC.new()
		n.setup(self, d)
		add_child(n)
		npcs.append(n)
	refresh_trader()


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


# --- Per frame --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_built:
		if _task != -1 and WorkerThreadPool.is_task_completed(_task):
			_finish_build()
		return
	_roof_check -= delta
	if _roof_check > 0.0 or World.instance == null or World.instance.player == null:
		return
	_roof_check = 0.2
	var p := to_local(World.instance.player.global_position)
	var inside := building_at(p)
	if inside != _hidden_roof:
		if _roof_nodes.has(_hidden_roof):
			_roof_nodes[_hidden_roof].visible = true
		_hidden_roof = inside
		if _roof_nodes.has(inside):
			_roof_nodes[inside].visible = false


## Index of the building containing a local point (or -1).
func building_at(local: Vector3) -> int:
	for b in layout.buildings:
		var r: Rect2 = b.rect
		if r.has_point(Vector2(local.x, local.z)):
			return b.id
	return -1
