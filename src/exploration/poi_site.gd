class_name PoiSite
extends Node3D
## A point of interest streamed in near the player: structure geometry, chests,
## cracked floors (hidden vaults), lecterns/altars/entrances, magical plants,
## lights and guardians. Rebuilt from PoiLayout; progress lives in
## ExplorationManager.state.

const MONSTER_SCENE := preload("res://scenes/enemies/monster.tscn")

var poi: PoiInfo
var layout: PoiLayout
var manager: Node
var guardians: Array[Monster] = []
var chests: Array[LootChest] = []

var _roofs: Dictionary = {}
var _hidden_roof := false
var _check := 0.0
## Milestone 36: the layout and the merged meshes are made on a worker thread,
## then the nodes are added a few at a time (about STEP_BUDGET_MS per frame).
## A temple used to cost one 20-40 ms frame.
const STEP_BUDGET_MS := 3.0
const BOXES_PER_STEP := 200
var is_built := false
var _task := -1
var _merged: Dictionary = {}
var _steps: Array[Callable] = []
var _steps_queued := false
var _body: StaticBody3D
var _shapes := {}


func setup(p: PoiInfo, m: Node) -> void:
	poi = p
	manager = m
	name = "Poi_%s" % p.id.replace(":", "_").replace(",", "_")


func _ready() -> void:
	position = Vector3(poi.center.x + 0.5, poi.ground_y(), poi.center.y + 0.5)
	BuildingManager.all_pieces()  # fill the piece registry on the main thread first
	load("res://src/building/build_meshes.gd")
	var gen: TerrainGenerator = World.instance.generator if World.instance else null
	_task = WorkerThreadPool.add_task(_build_threaded.bind(gen), false, "poi_site")


## Worker thread: layout and merged meshes (pure data).
func _build_threaded(gen: TerrainGenerator) -> void:
	layout = PoiLayout.build(poi, (func(pos: Vector3) -> float: return gen.get_height_at(pos)) if gen else Callable())
	_merged = StaticGeometry.merge(layout.statics, layout.boxes, layout.roofs, poi.color)


func _queue_steps() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _steps_queued:
		return
	_steps_queued = true
	for key: String in _merged.arrays.keys():
		_steps.append(_attach_mesh.bind(key))
	_steps.append(func() -> void: _body = StaticGeometry.make_body(self))
	var boxes: Array = _merged.boxes
	for i in range(0, boxes.size(), BOXES_PER_STEP):
		_steps.append(func() -> void: StaticGeometry.add_boxes(_body, boxes, i, mini(i + BOXES_PER_STEP, boxes.size()), _shapes))
	_steps.append(_add_doors_and_chests)
	_steps.append(_add_objects_and_lights)
	for g in layout.guardians:
		_steps.append(_spawn_guardian.bind(g))
	_steps.append(func() -> void:
		_merged.clear()
		is_built = true)


func _run_steps(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not _steps.is_empty():
		var step: Callable = _steps.pop_front()
		step.call()
		if budget_ms >= 0.0 and (Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			break


## Blocks until the site is complete (tests, teleports, update_now(true)).
func finish_now() -> void:
	if is_built or (_task == -1 and not _steps_queued):
		return
	_queue_steps()
	_run_steps(-1.0)


func _attach_mesh(key: String) -> void:
	var mi := StaticGeometry.attach_mesh(self, key, _merged.arrays[key])
	if key.begins_with("roof_"):
		_roofs[int(key.substr(5))] = mi


func _add_doors_and_chests() -> void:
	var door_data := BuildingManager.get_piece_data(&"wood_door")
	for xf: Transform3D in layout.doors:
		var d := BuildPiece.new()
		d.setup(door_data)
		d.transform = xf
		add_child(d)
	for c in layout.chests:
		_add_chest(c)
	for c in layout.cracked:
		if manager.has_state(c.key):
			_add_chest(c.reveals)  # the vault was already opened
			continue
		var cb := CrackedBlock.new()
		cb.size = c.size
		cb.is_floor = c.is_floor
		cb.persist_key = c.key
		cb.transform = c.xform
		var reveal: Dictionary = c.reveals
		cb.broken.connect(func(_b: CrackedBlock) -> void:
			_add_chest(reveal)
			Events.toast.emit("A hidden vault!", UITheme.GOLD)
			if World.instance:
				World.instance.player.character.grant_xp(40, Progression.Source.EXPLORATION))
		add_child(cb)


func _add_objects_and_lights() -> void:
	for o in layout.objects:
		var po := PoiObject.new()
		po.kind = o.kind
		po.poi = poi
		po.persist_key = o.key
		po.item_id = o.get("item", &"")
		po.mesh_name = o.get("mesh", &"")
		po.transform = o.xform
		add_child(po)
	for l in layout.lights:
		var light := OmniLight3D.new()
		light.position = l[0]
		light.light_color = l[1]
		light.light_energy = 1.5
		light.omni_range = 7.0
		add_child(light)
	if poi.kind == PoiInfo.Kind.DUNGEON:
		var sign := Label3D.new()
		sign.text = "Rank %s" % poi.rank_letter()
		sign.font_size = 72
		sign.outline_size = 12
		sign.modulate = [Color(0.7, 1, 0.7), Color(0.6, 0.85, 1), Color(1, 1, 0.6), Color(1, 0.75, 0.4), Color(1, 0.5, 0.4), Color(1, 0.35, 0.8)][poi.rank]
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.position = Vector3(0, 5.3, -1.0)
		add_child(sign)


func _add_chest(c: Dictionary) -> LootChest:
	var ch := LootChest.new()
	ch.table = c.table
	ch.rank = poi.rank
	ch.persist_key = c.key
	ch.golden = c.get("golden", false)
	if c.get("sealed", false) and not manager.has_state("cleared:" + poi.id):
		ch.locked_reason = "Sealed by the guardian"
	ch.transform = c.xform
	add_child(ch)
	chests.append(ch)
	return ch


## One guardian (a build step).
func _spawn_guardian(g: Dictionary) -> void:
	var w := World.instance
	if w == null:
		return
	if poi.kind == PoiInfo.Kind.TEMPLE and manager.has_state("cleared:" + poi.id):
		return
	var data := load("res://data/enemies/%s.tres" % g.data) as MonsterData
	if data == null or not GameState.can_spawn_slot(g.key, 1800.0):
		return
	var m := w.spawner.spawn_enemy(MONSTER_SCENE, to_global(g.pos), g.key, data) as Monster
	if m == null:
		return
	m.configure(PoiLayout.RANK_POWER[poi.rank], PoiLayout.RANK_DAMAGE[poi.rank], PoiLayout.RANK_LEVELS[poi.rank], PoiLayout.RANK_XP[poi.rank])
	m.leash_mult = 0.6
	if float(g.dormant) > 0.0:
		m.make_dormant(float(g.dormant))
	if poi.kind == PoiInfo.Kind.TEMPLE:
		m.enemy_died.connect(_on_guardian_died, CONNECT_ONE_SHOT)
	guardians.append(m)


func _on_guardian_died(_e: Enemy) -> void:
	manager.set_state("cleared:" + poi.id)
	for ch in chests:
		if is_instance_valid(ch):
			ch.locked_reason = ""
	Events.toast.emit("The temple is cleansed. The altar and the guardian's chest are open to you.", UITheme.GOLD)


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for m in guardians:
		if is_instance_valid(m) and m.enemy_died.is_connected(_on_guardian_died):
			m.enemy_died.disconnect(_on_guardian_died)
		if is_instance_valid(m) and not m.is_dead and m.spawn_key != "":
			NodePool.release_or_free(m)
	guardians.clear()


func _process(delta: float) -> void:
	if not is_built:
		if _task != -1:
			if not WorkerThreadPool.is_task_completed(_task):
				return
			_queue_steps()
		elif not _steps_queued:
			return
		_run_steps(STEP_BUDGET_MS)
		return
	if _roofs.is_empty() or World.instance == null:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var p := to_local(World.instance.player.global_position)
	var inside := false
	for b in layout.buildings:
		inside = inside or (b.rect as Rect2).has_point(Vector2(p.x, p.z))
	if inside != _hidden_roof:
		_hidden_roof = inside
		for k in _roofs:
			_roofs[k].visible = not inside
