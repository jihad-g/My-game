class_name CombatDirector
## Group tactics for monsters (Milestone 7).
##
## Attack tokens: only MAX_MELEE monsters may swing at the same target at once
## (bosses always may). The others circle around the target at their own
## slot angle, so groups surround you instead of queueing in a line, and
## take over when a token frees up. Also keeps monsters from stacking on top
## of each other (separation) and lets packs alert each other.

const MAX_MELEE := 2
## Distance at which waiting monsters circle the target.
const RING := 3.6
const SEPARATION := 1.3

static var _attackers: Dictionary = {}  # target instance id -> Array of monster instance ids


## Claims an attack token on `target`. Returns false if enough monsters already attack it.
static func request(m: Node, target: Node) -> bool:
	if target == null:
		return true
	var key := target.get_instance_id()
	var list: Array = _attackers.get(key, [])
	_prune(list)
	if list.has(m.get_instance_id()):
		return true
	if list.size() >= MAX_MELEE:
		return false
	list.append(m.get_instance_id())
	_attackers[key] = list
	return true


## Gives back the token (attack finished, died, lost the target).
static func release(m: Node) -> void:
	var id := m.get_instance_id()
	for key in _attackers.keys():
		var list: Array = _attackers[key]
		list.erase(id)
		if list.is_empty():
			_attackers.erase(key)


static func attackers_of(target: Node) -> int:
	if target == null:
		return 0
	var list: Array = _attackers.get(target.get_instance_id(), [])
	_prune(list)
	return list.size()


static func clear() -> void:
	_attackers.clear()


static func _prune(list: Array) -> void:
	for i in range(list.size() - 1, -1, -1):
		var o := instance_from_id(list[i])
		if o == null or not is_instance_valid(o) or o.get("is_dead") == true or not (o as Node).is_inside_tree():
			list.remove_at(i)


## Where a waiting monster should stand: on a ring around the target at its slot angle.
static func circle_point(target_pos: Vector3, slot_angle: float, radius: float = RING) -> Vector3:
	return target_pos + Vector3(cos(slot_angle), 0, sin(slot_angle)) * radius


## Push away from nearby monsters so packs spread out.
## Milestone 36: a snapshot of where the live monsters are, rebuilt once per
## physics tick and bucketed in a grid of SEPARATION-sized cells. Each query
## looks at 9 cells instead of every enemy (40 monsters used to make 1600
## node lookups per tick).
static var _snap_frame := -1
static var _snap_grid: Dictionary = {}  # Vector2i -> PackedVector3Array


static func _snapshot(tree: SceneTree) -> void:
	var f := Engine.get_physics_frames()
	if f == _snap_frame:
		return
	_snap_frame = f
	_snap_grid.clear()
	for e in tree.get_nodes_in_group(&"enemies"):
		var o := e as Node3D
		if o == null or not o.is_visible_in_tree() or o.get("is_dead") == true:
			continue
		var p := o.global_position
		var c := Vector2i(floori(p.x / SEPARATION), floori(p.z / SEPARATION))
		var list: PackedVector3Array = _snap_grid.get(c, PackedVector3Array())
		list.append(p)
		_snap_grid[c] = list


static func separation(m: Node3D) -> Vector3:
	_snapshot(m.get_tree())
	var push := Vector3.ZERO
	var me := m.global_position
	var c := Vector2i(floori(me.x / SEPARATION), floori(me.z / SEPARATION))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var list: PackedVector3Array = _snap_grid.get(c + Vector2i(dx, dz), PackedVector3Array())
			for p in list:
				var d := me - p
				d.y = 0.0
				var l := d.length()
				# l > 0.01 also skips this monster's own entry in the snapshot.
				if l > 0.01 and l < SEPARATION:
					push += d / l * (SEPARATION - l) / SEPARATION
	return push
