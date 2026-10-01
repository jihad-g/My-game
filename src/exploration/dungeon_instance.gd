class_name DungeonInstance
extends Node3D
## One dungeon floor built from a DungeonPlan, far above the world (ORIGIN) so
## it never touches terrain. Owns its monsters, traps, chests, the boss fight
## (gate closes behind you, boss bar, loot + exit portal when it dies) and the
## ways out: the exit portal in the start room and stairs to the next floor.

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
var _gate: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _check := 0.0


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
			_brazier(corner)
		match room.type:
			DungeonPlan.Room.START:
				_door(DungeonDoor.Kind.EXIT, center + Vector3(0, 0, -2.0))
			DungeonPlan.Room.NORMAL:
				for k in 2 + poi.rank / 2 + _rng.randi_range(0, 1):
					_monster(mons[0] if _rng.randf() < 0.6 else mons[1], plan.room_point(i, _rng), _rng.randf() < 0.08 * poi.rank)
			DungeonPlan.Room.TRAP:
				for x in range(rr.position.x + 1, rr.end.x - 1, 2):
					for z in range(rr.position.y + 1, rr.end.y - 1, 2):
						if (x + z) % 4 == 0:
							_trap(Vector3(x + 0.5, 0, z + 0.5))
				for k in 1 + poi.rank / 3:
					_monster(mons[1], plan.room_point(i, _rng), false)
			DungeonPlan.Room.TREASURE:
				_chest(&"dungeon_chest", center, false)
				_chest(&"dungeon_chest", center + Vector3(1.5, 0, 0), false)
				for k in 2:
					_monster(mons[0], plan.room_point(i, _rng), k == 0 and poi.rank >= 2)
			DungeonPlan.Room.END:
				_door(DungeonDoor.Kind.STAIRS, center)
				for k in 2 + poi.rank / 2:
					_monster(mons[k % 2], plan.room_point(i, _rng), k == 0)
			DungeonPlan.Room.BOSS:
				_spawn_boss(i)
			DungeonPlan.Room.SECRET:
				_chest(&"secret", center, true)
	if not plan.secret.is_empty():
		var cb := CrackedBlock.new()
		cb.size = Vector3(3.2, WALL_H, 0.6)
		cb.hits_left = 3
		cb.position = plan.secret.block_pos
		cb.rotation.y = plan.secret.block_rot
		cb.broken.connect(func(_b: CrackedBlock) -> void:
			Events.toast.emit("A secret passage!", UITheme.GOLD)
			if World.instance:
				World.instance.player.character.grant_xp(40 + poi.rank * 10, Progression.Source.EXPLORATION))
		add_child(cb)


func _brazier(pos: Vector3) -> void:
	var st := [{"mesh": &"brazier", "xform": Transform3D(Basis.IDENTITY, pos), "box_size": Vector3(0.7, 1.2, 0.7), "box_center": Vector3(0, 0.6, 0)},
		{"mesh": &"brazier_fire", "xform": Transform3D(Basis.IDENTITY, pos), "glow": true}]
	StaticGeometry.attach(self, StaticGeometry.merge(st, []))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.8, 0)
	light.light_color = Color(1.0, 0.6, 0.3) if poi.theme != PoiInfo.DungeonTheme.ARCANE else Color(0.7, 0.55, 1.0)
	light.light_energy = 1.8
	light.omni_range = 9.0
	add_child(light)


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


func _spawn_boss(room: int) -> void:
	var mons: Array = PoiLayout.THEME_MONSTERS[poi.theme]
	boss = _monster(mons[2], plan.room_center(room) + Vector3(0, 0, -2.5), false)
	if boss == null:
		return
	boss.leash_mult = 3.0
	boss.make_dormant(7.5)
	boss.enemy_died.connect(_on_boss_died, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if World.instance == null or boss == null or boss_started or cleared:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
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


func _on_boss_died(_e: Enemy) -> void:
	cleared = true
	if _gate and is_instance_valid(_gate):
		_gate.queue_free()
	var room := plan.end_room
	var center := plan.room_center(room)
	_chest(&"dungeon_boss", center + Vector3(0, 0, -3.5), true)
	_door(DungeonDoor.Kind.EXIT, center + Vector3(0, 0, 2.5))
	if World.instance:
		World.instance.exploration.set_state("dungeon:" + poi.id)
		World.instance.player.character.grant_xp(100 + poi.rank * 80, Progression.Source.DUNGEON)
	Events.toast.emit("%s cleared! A portal home has opened." % poi.title(), UITheme.GOLD)


func _exit_tree() -> void:
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
