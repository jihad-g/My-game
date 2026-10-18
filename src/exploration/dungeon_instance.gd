class_name DungeonInstance
extends Node3D
## One dungeon floor built from a DungeonPlan, far above the world (ORIGIN) so
## it never touches terrain. Owns its monsters, traps, chests, the boss fight
## (gate closes behind you, boss bar, loot + exit portal when it dies) and the
## ways out: the exit portal in the start room and stairs to the next floor.
##
## Milestone 31: fog of war - every room and corridor is covered in darkness
## (a black lid over it, its braziers out) until you step into it or near it;
## `explored` feeds the HUD mini-map. Rank D and up: the last room is locked
## behind gates, the key is carried by the Keeper (an elite in another room).
## Puzzle rooms hold a caged chest: levers to pull in order, or a pressure plate
## that opens the cage for PLATE_SECONDS.

const ORIGIN := Vector3(0, 800, 0)
const WALL_H := 3.5
const MONSTER_SCENE := preload("res://scenes/enemies/monster.tscn")

var poi: PoiInfo
var plan: DungeonPlan
var floor_index := 0
var return_position := Vector3.ZERO
var monsters: Array[Monster] = []
var boss: Monster
var cleared := false
var boss_started := false
## Milestone 22: every monster on this floor is beaten (a Delver's Cache appears).
var floor_cleared := false
var _gate: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _check := 0.0
## Milestone 31.
const PLATE_SECONDS := 6.0
## Milestone 33: a door mimic hides in this share of normal rooms (rank C and up),
## and B+ crypts keep a Bone Dragon by the stairs of their second-to-last floor.
const MIMIC_CHANCE := 0.3
const MIMIC_WAKE := 3.2
const DRAGON := &"bone_dragon"
const MIMIC := &"door_mimic"
const CORRIDOR_SIGHT := 3.0
## Explored rooms and corridors (index -> true).
var explored: Dictionary = {}
var explored_corridors: Dictionary = {}
var keeper: Monster
var gates: Array = []
## Puzzle room -> {"kind", "cage", "levers", "next", "chest", "timer"}
var puzzles: Dictionary = {}
var _lids: Dictionary = {}  # "r<i>" / "c<i>" -> MeshInstance3D
var _room_lights: Dictionary = {}  # room -> [OmniLight3D]
## The secret passage stays dark (and off the map) until its cracked wall breaks.
var secret_open := false


func setup(p: PoiInfo, p_floor: int, ret: Vector3) -> void:
	poi = p
	floor_index = p_floor
	return_position = ret
	name = "Dungeon"
	plan = DungeonPlan.generate(p, p_floor)
	_rng.seed = HashUtils.hash3(p.seed, p_floor, int(GameState.world_time))


## Ground height inside the dungeon (flat floors).
func floor_y() -> float:
	return ORIGIN.y


func start_position() -> Vector3:
	return ORIGIN + plan.room_center(plan.start_room) + Vector3(0, 0.3, 1.5)


func _ready() -> void:
	position = ORIGIN
	_build_geometry()
	_build_rooms()
	_build_locks()
	_build_fog()
	reveal_room(plan.start_room)


# --- Geometry --------------------------------------------------------------------------

func _build_geometry() -> void:
	var statics: Array = []
	var boxes: Array = []
	for c: Vector2i in plan.cells:
		statics.append({"mesh": &"dungeon_floor", "xform": Transform3D(Basis.IDENTITY, Vector3(c.x + 0.5, 0, c.y + 0.5))})
	for r in plan.rooms:
		var rr: Rect2i = r.rect
		boxes.append({"size": Vector3(rr.size.x, 0.5, rr.size.y), "xform": Transform3D(Basis.IDENTITY, Vector3(rr.position.x + rr.size.x * 0.5, -0.25, rr.position.y + rr.size.y * 0.5))})
	for cr: Rect2i in plan.corridors:
		boxes.append({"size": Vector3(cr.size.x, 0.5, cr.size.y), "xform": Transform3D(Basis.IDENTITY, Vector3(cr.position.x + cr.size.x * 0.5, -0.25, cr.position.y + cr.size.y * 0.5))})
	# Walls on every floor edge that faces solid rock; collision merged into runs.
	var h_runs := {}  # z line -> Array[x]
	var v_runs := {}  # x line -> Array[z]
	for c: Vector2i in plan.cells:
		if not plan.cells.has(c + Vector2i(0, -1)):
			statics.append({"mesh": &"dungeon_wall", "xform": Transform3D(Basis.IDENTITY, Vector3(c.x + 0.5, 0, c.y)), "fade": true})
			h_runs.get_or_add(c.y, []).append(c.x)
		if not plan.cells.has(c + Vector2i(0, 1)):
			statics.append({"mesh": &"dungeon_wall", "xform": Transform3D(Basis.IDENTITY, Vector3(c.x + 0.5, 0, c.y + 1)), "fade": true})
			h_runs.get_or_add(c.y + 1, []).append(c.x)
		if not plan.cells.has(c + Vector2i(-1, 0)):
			statics.append({"mesh": &"dungeon_wall", "xform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(c.x, 0, c.y + 0.5)), "fade": true})
			v_runs.get_or_add(c.x, []).append(c.y)
		if not plan.cells.has(c + Vector2i(1, 0)):
			statics.append({"mesh": &"dungeon_wall", "xform": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(c.x + 1, 0, c.y + 0.5)), "fade": true})
			v_runs.get_or_add(c.x + 1, []).append(c.y)
	for z in h_runs:
		for run in _runs(h_runs[z]):
			boxes.append({"size": Vector3(run[1] - run[0], WALL_H, 0.5), "xform": Transform3D(Basis.IDENTITY, Vector3((run[0] + run[1]) * 0.5, WALL_H * 0.5, z))})
	for x in v_runs:
		for run in _runs(v_runs[x]):
			boxes.append({"size": Vector3(0.5, WALL_H, run[1] - run[0]), "xform": Transform3D(Basis.IDENTITY, Vector3(x, WALL_H * 0.5, (run[0] + run[1]) * 0.5))})
	StaticGeometry.attach(self, StaticGeometry.merge(statics, boxes))


## Contiguous [start, end) runs of sorted integer positions.
func _runs(values: Array) -> Array:
	values.sort()
	var out := []
	var start: int = values[0]
	var prev: int = values[0]
	for i in range(1, values.size()):
		var v: int = values[i]
		if v != prev + 1:
			out.append([start, prev + 1])
			start = v
		prev = v
	out.append([start, prev + 1])
	return out


# --- Rooms -------------------------------------------------------------------------------

func _build_rooms() -> void:
	var mons: Array = PoiLayout.THEME_MONSTERS[poi.theme]
	for i in plan.rooms.size():
		var room: Dictionary = plan.rooms[i]
		var center := plan.room_center(i)
		var rr: Rect2i = room.rect
		# Braziers in two corners.
		for corner in [Vector3(rr.position.x + 1.2, 0, rr.position.y + 1.2), Vector3(rr.end.x - 1.2, 0, rr.end.y - 1.2)]:
			_room_lights.get_or_add(i, []).append(_brazier(corner))
		match room.type:
			DungeonPlan.Room.START:
				_door(DungeonDoor.Kind.EXIT, center + Vector3(0, 0, -2.0))
			DungeonPlan.Room.NORMAL:
				if poi.rank >= 2 and i != plan.keeper_room and _rng.randf() < MIMIC_CHANCE:
					_spawn_mimic(i)
				for k in 2 + poi.rank / 2 + _rng.randi_range(0, 1):
					var pick: StringName = mons[0] if _rng.randf() < 0.6 else mons[1]
					if _rng.randf() < 0.15:
						pick = PoiLayout.THEME_EXTRAS[poi.theme]  # Milestone 27
					_monster(pick, plan.room_point(i, _rng), _rng.randf() < 0.08 * poi.rank)
			DungeonPlan.Room.TRAP:
				for x in range(rr.position.x + 1, rr.end.x - 1, 2):
					for z in range(rr.position.y + 1, rr.end.y - 1, 2):
						if (x + z) % 4 == 0:
							_trap(Vector3(x + 0.5, 0, z + 0.5))
				# Milestone 22: risk pays - a chest waits in the middle of the spikes.
				_chest(&"dungeon_chest", center, false)
				for k in 1 + poi.rank / 3:
					_monster(mons[1], plan.room_point(i, _rng), false)
			DungeonPlan.Room.TREASURE:
				_chest(&"dungeon_chest", center, false)
				_chest(&"dungeon_chest", center + Vector3(1.5, 0, 0), false)
				for k in 2:
					_monster(mons[0], plan.room_point(i, _rng), k == 0 and poi.rank >= 2)
			DungeonPlan.Room.END:
				_door(DungeonDoor.Kind.STAIRS, center)
				if has_dragon():
					_spawn_dragon(i)
				else:
					for k in 2 + poi.rank / 2:
						_monster(mons[k % 2], plan.room_point(i, _rng), k == 0)
			DungeonPlan.Room.BOSS:
				_spawn_boss(i)
			DungeonPlan.Room.SECRET:
				_chest(&"secret", center, true)
			DungeonPlan.Room.PUZZLE:
				_build_puzzle(i)
				for k in 1 + poi.rank / 3:
					_monster(mons[0], plan.room_point(i, _rng), false)
		if i == plan.keeper_room:
			_spawn_keeper(i)
	if not plan.secret.is_empty():
		var cb := CrackedBlock.new()
		cb.size = Vector3(3.2, WALL_H, 0.6)
		cb.hits_left = 3
		cb.position = plan.secret.block_pos
		cb.rotation.y = plan.secret.block_rot
		cb.broken.connect(func(_b: CrackedBlock) -> void:
			secret_open = true
			Events.toast.emit("A secret passage!", UITheme.GOLD)
			if World.instance:
				World.instance.player.character.grant_xp(40 + poi.rank * 10, Progression.Source.EXPLORATION))
		add_child(cb)


func _brazier(pos: Vector3) -> OmniLight3D:
	var st := [{"mesh": &"brazier", "xform": Transform3D(Basis.IDENTITY, pos), "box_size": Vector3(0.7, 1.2, 0.7), "box_center": Vector3(0, 0.6, 0)},
		{"mesh": &"brazier_fire", "xform": Transform3D(Basis.IDENTITY, pos), "glow": true}]
	StaticGeometry.attach(self, StaticGeometry.merge(st, []))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.8, 0)
	light.light_color = Color(1.0, 0.6, 0.3) if poi.theme != PoiInfo.DungeonTheme.ARCANE else Color(0.7, 0.55, 1.0)
	light.light_energy = 3.2
	light.omni_range = 12.0
	light.visible = false  # lit when the room is explored (Milestone 31)
	add_child(light)
	return light


func _door(kind: int, pos: Vector3) -> DungeonDoor:
	var d := DungeonDoor.new()
	d.kind = kind
	d.dungeon = self
	d.position = pos
	add_child(d)
	return d


func _trap(pos: Vector3) -> void:
	var t := DungeonTrap.new()
	t.damage = 14.0 * PoiLayout.RANK_DAMAGE[poi.rank]
	t.phase = _rng.randf() * 3.0
	t.position = pos
	add_child(t)


func _chest(table: StringName, pos: Vector3, golden: bool) -> LootChest:
	var c := LootChest.new()
	c.table = table
	c.rank = poi.rank
	c.golden = golden
	c.position = pos
	add_child(c)
	return c


func _monster(data_id: StringName, local: Vector3, elite: bool) -> Monster:
	var w := World.instance
	var data := load("res://data/enemies/%s.tres" % data_id) as MonsterData
	var m := w.spawner.spawn_enemy(MONSTER_SCENE, to_global(local + Vector3(0, 0.3, 0)), "", data) as Monster
	if m == null:
		return null
	var r := poi.rank
	m.configure(PoiLayout.RANK_POWER[r], PoiLayout.RANK_DAMAGE[r], PoiLayout.RANK_LEVELS[r], PoiLayout.RANK_XP[r])
	m.leash_mult = 2.0
	# Elite rooms always hold an elite; any other monster may roll one (Milestone 7 affixes).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%s" % [poi.id, floor_index, local])
	if data.can_be_elite and data.style != MonsterData.Style.BOSS and (elite or rng.randf() < EliteAffixes.chance(r)):
		var count := 2 if elite and r >= 3 else 1
		m.make_elite(EliteAffixes.roll(rng, count, data.style != MonsterData.Style.MELEE))
	monsters.append(m)
	return m


# --- Milestone 33: door mimics and the bone dragon ---------------------------------------

var dragon: Monster
var mimics: Array[Monster] = []


func has_dragon() -> bool:
	return poi.theme == PoiInfo.DungeonTheme.CRYPT and poi.rank >= 3 and plan.floor_count >= 2 \
		and floor_index == plan.floor_count - 2


## A door mimic stands against a wall of the room, asleep until you come close.
func _spawn_mimic(room: int) -> void:
	var rr: Rect2i = plan.rooms[room].rect
	var side := _rng.randi() % 4
	var c := plan.room_center(room)
	var spots := [Vector3(c.x, 0, rr.position.y + 0.5), Vector3(c.x, 0, rr.end.y - 0.5),
		Vector3(rr.position.x + 0.5, 0, c.z + 1.5), Vector3(rr.end.x - 0.5, 0, c.z - 1.5)]
	var m := _monster(MIMIC, spots[side], false)
	if m == null:
		return
	# Face into the room, flat against the wall like a door.
	m.face_toward(Vector3(c.x - spots[side].x, 0, c.z - spots[side].z))
	m.make_dormant(MIMIC_WAKE)
	mimics.append(m)


func _spawn_dragon(room: int) -> void:
	dragon = _monster(DRAGON, plan.room_center(room) + Vector3(0, 0, -3.0), false)
	if dragon:
		dragon.leash_mult = 3.0
		dragon.make_dormant(8.0)


# --- Milestone 31: the Keeper, locked gates and puzzles -----------------------------------

func _spawn_keeper(room: int) -> void:
	var mons: Array = PoiLayout.THEME_MONSTERS[poi.theme]
	keeper = _monster(mons[0], plan.room_center(room), false)
	if keeper == null:
		return
	if keeper.affixes.is_empty() and keeper.mdata.can_be_elite:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("keeper:%s:%d" % [poi.id, floor_index])
		keeper.make_elite(EliteAffixes.roll(rng, 2 if poi.rank >= 3 else 1, keeper.mdata.style != MonsterData.Style.MELEE))
	keeper.set_meta(&"keeper", true)
	keeper.enemy_died.connect(_on_keeper_died, CONNECT_ONE_SHOT)


func _on_keeper_died(e: Enemy) -> void:
	e.remove_meta(&"keeper")
	if World.instance:
		World.instance.spawn_pickup(DungeonGate.KEY_ITEM, 1, e.global_position + Vector3(0, 0.8, 0))
	Events.toast.emit("The Keeper dropped the Dungeon Key!", UITheme.GOLD)


func _build_locks() -> void:
	if plan.keeper_room < 0:
		return
	for cr: Rect2i in plan.corridors_into(plan.end_room):
		var m := plan.mouth(plan.end_room, cr)
		var g := DungeonGate.new()
		g.size = m.size
		g.horizontal = m.horizontal
		g.position = m.pos
		add_child(g)
		gates.append(g)
	for g in gates:
		g.group = gates.filter(func(o: Node) -> bool: return o != g)


func _build_puzzle(room: int) -> void:
	var center := plan.room_center(room)
	var rr: Rect2i = plan.rooms[room].rect
	var chest := _chest(&"dungeon_chest", center, true)
	var cage := ChestCage.new()
	cage.chest = chest
	cage.position = center
	add_child(cage)
	var kind: int = plan.puzzles.get(room, DungeonPlan.Puzzle.LEVERS)
	var st := {"kind": kind, "cage": cage, "levers": [], "next": 1, "chest": chest, "timer": 0.0}
	puzzles[room] = st
	if kind == DungeonPlan.Puzzle.LEVERS:
		# Three levers by the walls, their numbers shuffled around the room.
		var spots := [Vector3(rr.position.x + 1.0, 0, center.z), Vector3(rr.end.x - 1.0, 0, center.z),
			Vector3(center.x, 0, rr.position.y + 1.0), Vector3(center.x, 0, rr.end.y - 1.0)]
		var nums := [1, 2, 3]
		for k in range(nums.size() - 1, 0, -1):
			var j := _rng.randi() % (k + 1)
			var t = nums[k]
			nums[k] = nums[j]
			nums[j] = t
		for k in 3:
			var lv := DungeonLever.new()
			lv.number = nums[k]
			lv.position = spots[k]
			lv.pulled.connect(_on_lever_pulled.bind(room))
			add_child(lv)
			st.levers.append(lv)
	else:
		var plate := PressurePlate.new()
		plate.position = Vector3(rr.position.x + 1.5, 0.0, rr.position.y + 1.5)
		plate.pressed.connect(_on_plate_pressed.bind(room))
		add_child(plate)
		st["plate"] = plate


## Creative mode: opens every gate and puzzle cage on the floor. Returns how many.
func open_all_locks() -> int:
	var n := 0
	for g in gates:
		if is_instance_valid(g) and not g.is_open:
			g.open()
			n += 1
	for room in puzzles:
		var cage: ChestCage = puzzles[room].cage
		if is_instance_valid(cage) and not cage.is_open:
			cage.open()
			puzzles[room].timer = 0.0
			n += 1
	return n


func _on_lever_pulled(lever: DungeonLever, room: int) -> void:
	var st: Dictionary = puzzles[room]
	if lever.number == int(st.next):
		st.next = int(st.next) + 1
		if int(st.next) > 3:
			st.cage.open()
			Events.toast.emit("Click! The cage rises.", UITheme.GOLD)
		return
	Events.toast.emit("Wrong order - the levers reset (look at their runes)", Color(1, 0.7, 0.45))
	st.next = 1
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		for lv: DungeonLever in st.levers:
			if is_instance_valid(lv):
				lv.set_down(false))


func _on_plate_pressed(room: int) -> void:
	var st: Dictionary = puzzles[room]
	st.cage.open()
	st.timer = PLATE_SECONDS
	Events.toast.emit("The cage rises - hurry, it falls in %d seconds!" % int(PLATE_SECONDS), UITheme.GOLD)


func _update_puzzles(dt: float) -> void:
	for room in puzzles:
		var st: Dictionary = puzzles[room]
		if float(st.timer) <= 0.0:
			continue
		st.timer = float(st.timer) - dt
		if float(st.timer) <= 0.0 and is_instance_valid(st.chest) and not st.chest.opened:
			st.cage.close()


# --- Milestone 31: fog of war ------------------------------------------------------------

func _build_fog() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.02, 0.03)
	for i in plan.rooms.size():
		var rr: Rect2i = plan.rooms[i].rect
		_lids["r%d" % i] = _lid(Rect2(rr.position, rr.size).grow(0.3), mat)
	for i in plan.corridors.size():
		var cr: Rect2i = plan.corridors[i]
		_lids["c%d" % i] = _lid(Rect2(cr.position, cr.size).grow(0.3), mat)


func _lid(r: Rect2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(r.size.x, 0.1, r.size.y)
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(r.position.x + r.size.x * 0.5, WALL_H + 0.08, r.position.y + r.size.y * 0.5)
	add_child(mi)
	return mi


## Lifts the darkness off a room and lights its braziers.
func reveal_room(i: int) -> void:
	if i < 0 or explored.has(i):
		return
	explored[i] = true
	var lid: MeshInstance3D = _lids.get("r%d" % i)
	if lid and is_instance_valid(lid):
		var tw := create_tween()
		tw.tween_property(lid, "position:y", WALL_H + 8.0, 0.6)
		tw.tween_callback(lid.queue_free)
	for l in _room_lights.get(i, []):
		l.visible = true
	# The corridors leading out of it come into view too.
	for ci in plan.corridors.size():
		if Rect2i((plan.rooms[i].rect as Rect2i).position - Vector2i(1, 1), (plan.rooms[i].rect as Rect2i).size + Vector2i(2, 2)).intersects(plan.corridors[ci]):
			reveal_corridor(ci)


func reveal_corridor(ci: int, force := false) -> void:
	if explored_corridors.has(ci) or (not force and not secret_open and is_secret_corridor(ci)):
		return
	explored_corridors[ci] = true
	var lid: MeshInstance3D = _lids.get("c%d" % ci)
	if lid and is_instance_valid(lid):
		lid.queue_free()


## True when the cell is in a room or corridor you have seen (the maps draw only these).
func is_cell_known(c: Vector2i) -> bool:
	var room := plan.room_at(Vector3(c.x + 0.5, 0, c.y + 0.5))
	if room >= 0:
		return explored.has(room)
	for ci in explored_corridors:
		if (plan.corridors[ci] as Rect2i).has_point(c):
			return true
	return false


func is_secret_corridor(ci: int) -> bool:
	return not plan.secret.is_empty() and plan.corridors[ci] == plan.secret.rect


## Creative mode: the whole floor, secret room included.
func reveal_all() -> void:
	for i in plan.rooms.size():
		reveal_room(i)
	for ci in plan.corridors.size():
		reveal_corridor(ci, true)


func _update_fog(local: Vector3) -> void:
	var idx := plan.room_at(local)
	if idx >= 0:
		reveal_room(idx)
	var c := Vector2(local.x, local.z)
	for ci in plan.corridors.size():
		if not explored_corridors.has(ci) and Rect2(plan.corridors[ci].position, plan.corridors[ci].size).grow(CORRIDOR_SIGHT).has_point(c):
			reveal_corridor(ci)
	# Rooms you look into from a corridor mouth.
	for i in plan.rooms.size():
		if not explored.has(i) and Rect2((plan.rooms[i].rect as Rect2i).position, (plan.rooms[i].rect as Rect2i).size).grow(1.2).has_point(c):
			reveal_room(i)


func _spawn_boss(room: int) -> void:
	var mons: Array = PoiLayout.THEME_MONSTERS[poi.theme]
	boss = _monster(mons[2], plan.room_center(room) + Vector3(0, 0, -2.5), false)
	if boss == null:
		return
	boss.leash_mult = 3.0
	boss.make_dormant(7.5)
	boss.enemy_died.connect(_on_boss_died, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if World.instance == null:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	_update_puzzles(0.25)
	if World.instance.player:
		_update_fog(to_local(World.instance.player.global_position))
	if not floor_cleared and not plan.is_final and not monsters.is_empty() and alive_count() == 0:
		_on_floor_cleared()
	if boss == null or boss_started or cleared:
		return
	# Entering the arena seals the way back until the boss falls.
	var local := to_local(World.instance.player.global_position)
	var idx := plan.room_at(local)
	if idx >= 0 and plan.rooms[idx].type == DungeonPlan.Room.BOSS:
		var rr: Rect2i = plan.rooms[idx].rect
		if Rect2(rr.position + Vector2i(2, 2), rr.size - Vector2i(4, 4)).has_point(Vector2(local.x, local.z)):
			boss_started = true
			_close_gate(idx)


func _close_gate(room: int) -> void:
	var rr: Rect2i = plan.rooms[room].rect
	_gate = StaticBody3D.new()
	_gate.collision_layer = Layers.BUILDING
	add_child(_gate)
	var b := BlockMesh.new()
	# Bars across every corridor mouth of the arena.
	for cr: Rect2i in plan.corridors:
		var touches := Rect2i(rr.position - Vector2i(1, 1), rr.size + Vector2i(2, 2)).intersects(cr)
		if not touches:
			continue
		var horizontal := cr.size.x > cr.size.y
		var pos: Vector3
		var size: Vector3
		if horizontal:
			var x := rr.position.x if cr.position.x < rr.position.x else rr.end.x
			pos = Vector3(x, 0, cr.position.y + cr.size.y * 0.5)
			size = Vector3(0.3, WALL_H, cr.size.y)
		else:
			var z := rr.position.y if cr.position.y < rr.position.y else rr.end.y
			pos = Vector3(cr.position.x + cr.size.x * 0.5, 0, z)
			size = Vector3(cr.size.x, WALL_H, 0.3)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.position = pos + Vector3(0, WALL_H * 0.5, 0)
		_gate.add_child(cs)
		for k in 7:
			var off := Vector3(0, 0, (k - 3) * 0.45) if horizontal else Vector3((k - 3) * 0.45, 0, 0)
			b.box(pos + off + Vector3(0, WALL_H * 0.5, 0), Vector3(0.1, WALL_H, 0.1), Color(0.35, 0.33, 0.38))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	_gate.add_child(mi)
	Events.toast.emit("The gate slams shut behind you!", Color(1, 0.5, 0.4))
	Events.camera_shake.emit(0.3)


## Milestone 22: a floor with every monster beaten leaves a Delver's Cache by the stairs.
func _on_floor_cleared() -> void:
	floor_cleared = true
	var center := plan.room_center(plan.end_room)
	_chest(&"dungeon_cache", center + Vector3(2.0, 0, 1.5), true)
	if World.instance:
		World.instance.player.character.grant_xp(30 + poi.rank * 25, Progression.Source.DUNGEON)
	Events.toast.emit("Floor cleared! A Delver's Cache waits by the stairs.", UITheme.GOLD)


func _on_boss_died(_e: Enemy) -> void:
	cleared = true
	if _gate and is_instance_valid(_gate):
		_gate.queue_free()
	var room := plan.end_room
	var center := plan.room_center(room)
	_chest(&"dungeon_boss", center + Vector3(0, 0, -3.5), true)
	_door(DungeonDoor.Kind.EXIT, center + Vector3(0, 0, 2.5))
	# Everything on the last floor beaten too: a Delver's Cache next to the boss chest.
	var full := alive_count() == 0
	if full:
		floor_cleared = true
		_chest(&"dungeon_cache", center + Vector3(2.0, 0, -3.5), true)
	var xp := 100 + poi.rank * 80
	var w := World.instance
	var first := w != null and w.exploration.is_first_clear(poi)
	if w:
		w.exploration.set_state("dungeon:" + poi.id)
		if first:
			# First clear of this dungeon: double XP, a purse of coins and Delver's Marks.
			w.exploration.set_state("first_clear:" + poi.id)
			xp *= 2
			var coins := 150 * (poi.rank + 1)
			w.player.coins += coins
			Events.coins_changed.emit(w.player.coins)
			w.player.give_item(&"delvers_mark", 2 + poi.rank)
			Events.toast.emit("First clear! +%s and %d Delver's Marks" % [Economy.format_coins(coins), 2 + poi.rank], UITheme.GOLD)
		w.player.character.grant_xp(xp, Progression.Source.DUNGEON)
	Events.toast.emit("%s cleared%s! A portal home has opened." % [poi.title(), " - every foe beaten" if full else ""], UITheme.GOLD)


func _exit_tree() -> void:
	if keeper and is_instance_valid(keeper):
		if keeper.has_meta(&"keeper"):
			keeper.remove_meta(&"keeper")
		if keeper.enemy_died.is_connected(_on_keeper_died):
			keeper.enemy_died.disconnect(_on_keeper_died)
	if boss and is_instance_valid(boss) and boss.enemy_died.is_connected(_on_boss_died):
		boss.enemy_died.disconnect(_on_boss_died)
	for m in monsters:
		if is_instance_valid(m) and m.is_inside_tree():
			if m.is_boss():
				Events.boss_ended.emit(m)
			NodePool.release_or_free(m)
	monsters.clear()


func alive_count() -> int:
	var n := 0
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead and m.is_inside_tree():
			n += 1
	return n
