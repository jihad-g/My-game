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
static func separation(m: Node3D) -> Vector3:
	var push := Vector3.ZERO
	for e in m.get_tree().get_nodes_in_group(&"enemies"):
		var o := e as Node3D
		if o == null or o == m or not o.is_visible_in_tree() or o.get("is_dead") == true:
			continue
		var d := m.global_position - o.global_position
		d.y = 0.0
		var l := d.length()
		if l > 0.01 and l < SEPARATION:
			push += d / l * (SEPARATION - l) / SEPARATION
	return push
