class_name Inventory
extends RefCounted
## Slot-based inventory with stacking.
##
## Slots hold `null` or a Dictionary {"id": StringName, "count": int}. Plain
## data makes the inventory trivially serializable (save system, multiplayer).
## The first HOTBAR_SIZE slots double as the hotbar.

signal changed

const HOTBAR_SIZE := 8

var capacity: int
var slots: Array = []
## Multiplayer guest (Milestone 11): the server owns this inventory. Local
## changes are refused; from_array() applies the server's snapshots, and slot
## moves go to `remote_mover` (a request to the server).
var remote := false
var remote_mover: Callable


func _init(p_capacity: int = 24) -> void:
	capacity = p_capacity
	slots.resize(capacity)


static func max_stack_of(id: StringName) -> int:
	var item: ItemData = ItemDB.get_item(id)
	return item.max_stack if item else 1


## Adds items, filling existing stacks first. Returns the amount that did NOT fit.
func add_item(id: StringName, count: int) -> int:
	if remote or count <= 0 or not ItemDB.has_item(id):
		return count
	var max_stack := max_stack_of(id)
	var remaining := count
	for i in capacity:
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s.id == id and s.count < max_stack:
			var take := mini(max_stack - s.count, remaining)
			s.count += take
			remaining -= take
	for i in capacity:
		if remaining <= 0:
			break
		if slots[i] == null:
			var take := mini(max_stack, remaining)
			slots[i] = {"id": id, "count": take}
			remaining -= take
	if remaining != count:
		changed.emit()
	return remaining


## Removes `count` items of `id` from anywhere. All-or-nothing.
func remove_item(id: StringName, count: int) -> bool:
	if remote or count_of(id) < count:
		return false
	var remaining := count
	# Take from the last stacks first so the hotbar keeps its items longest.
	for i in range(capacity - 1, -1, -1):
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s.id == id:
			var take := mini(s.count, remaining)
			s.count -= take
			remaining -= take
			if s.count <= 0:
				slots[i] = null
	changed.emit()
	return true


## Removes up to `count` from one slot. Returns the amount removed.
func remove_from_slot(index: int, count: int) -> int:
	var s = get_slot(index)
	if s == null or remote:
		return 0
	var take := mini(count, s.count)
	s.count -= take
	if s.count <= 0:
		slots[index] = null
	changed.emit()
	return take


func count_of(id: StringName) -> int:
	var total := 0
	for s in slots:
		if s != null and s.id == id:
			total += s.count
	return total


func get_slot(index: int):
	if index < 0 or index >= capacity:
		return null
	return slots[index]


## Moves slot `from` onto slot `to`: merges equal stacks, otherwise swaps.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= capacity or to >= capacity:
		return
	if remote:
		if remote_mover.is_valid():
			remote_mover.call(from, to)
		return
	var a = slots[from]
	var b = slots[to]
	if a != null and b != null and a.id == b.id:
		var max_stack := max_stack_of(a.id)
		var moved := mini(max_stack - b.count, a.count)
		b.count += moved
		a.count -= moved
		if a.count <= 0:
			slots[from] = null
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()


func free_slot_count() -> int:
	var n := 0
	for s in slots:
		if s == null:
			n += 1
	return n


func clear() -> void:
	if remote:
		return
	for i in capacity:
		slots[i] = null
	changed.emit()


func to_array() -> Array:
	var out := []
	for s in slots:
		out.append(null if s == null else {"id": String(s.id), "count": s.count})
	return out


func from_array(data: Array) -> void:
	for i in capacity:
		var s = data[i] if i < data.size() else null
		slots[i] = null if s == null else {"id": StringName(s.id), "count": int(s.count)}
	changed.emit()
