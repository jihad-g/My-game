class_name Equipment
extends RefCounted
## Equipped items per slot and their combined stat bonuses.

signal changed

## ItemData.EquipSlot -> item id
var slots: Dictionary = {}


func get_item_id(slot: int) -> StringName:
	return slots.get(slot, &"")


func get_item(slot: int) -> ItemData:
	var id := get_item_id(slot)
	return ItemDB.get_item(id) if id != &"" else null


func weapon() -> ItemData:
	return get_item(ItemData.EquipSlot.MAIN_HAND)


func weapon_type() -> StringName:
	var w := weapon()
	return w.weapon_type if w else &"unarmed"


func offhand() -> ItemData:
	return get_item(ItemData.EquipSlot.OFF_HAND)


## Why `item` can't be equipped at `level` ("" if it can).
static func check_requirements(item: ItemData, level: int) -> String:
	if item == null or not item.is_equippable():
		return "That can't be equipped"
	if level < item.required_level:
		return "Requires level %d" % item.required_level
	return ""


## Puts the item in its slot. Returns the id previously in that slot (or &"").
func equip(item: ItemData) -> StringName:
	var old := get_item_id(item.equip_slot)
	slots[item.equip_slot] = item.id
	changed.emit()
	return old


func unequip(slot: int) -> StringName:
	var old := get_item_id(slot)
	if old != &"":
		slots.erase(slot)
		changed.emit()
	return old


## Sum of a stat over the worn items plus active set bonuses.
func total(stat: StringName) -> float:
	var t := 0.0
	for slot in slots:
		var item := get_item(slot)
		if item:
			t += float(item.stat_bonuses.get(stat, 0.0))
	var counts := set_counts()
	for set_id in counts:
		t += float(GearSets.active_bonuses(set_id, counts[set_id]).get(stat, 0.0))
	return t


## Set id -> number of its pieces worn (Milestone 14).
func set_counts() -> Dictionary:
	var out := {}
	for slot in slots:
		var item := get_item(slot)
		if item and item.set_id != &"":
			out[item.set_id] = int(out.get(item.set_id, 0)) + 1
	return out


## Worn armour/clothing by slot (HEAD, CHEST, HANDS, FEET) for the character model.
func outfit() -> Dictionary:
	var out := {}
	for slot in [ItemData.EquipSlot.HEAD, ItemData.EquipSlot.CHEST, ItemData.EquipSlot.HANDS, ItemData.EquipSlot.FEET]:
		var item := get_item(slot)
		if item:
			out[slot] = item
	return out


func clear() -> void:
	slots.clear()
	changed.emit()


func to_save() -> Dictionary:
	var out := {}
	for slot in slots:
		out[str(slot)] = String(slots[slot])
	return out


func from_save(data: Dictionary) -> void:
	slots.clear()
	for k in data:
		var id := StringName(data[k])
		if ItemDB.has_item(id):
			slots[int(k)] = id
	changed.emit()
