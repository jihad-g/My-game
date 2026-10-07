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


## Items taken off by the last equip() because of two-handed weapons (M17a).
var displaced: Array[StringName] = []


## Puts the item in its slot. Returns the id previously in that slot (or &"").
## A two-handed weapon also takes off the off-hand item and an off-hand item
## takes off a two-handed weapon; those ids are listed in `displaced` (call
## take_displaced() to collect them).
func equip(item: ItemData) -> StringName:
	displaced.clear()
	var old := get_item_id(item.equip_slot)
	if item.is_two_handed() and get_item_id(ItemData.EquipSlot.OFF_HAND) != &"":
		displaced.append(get_item_id(ItemData.EquipSlot.OFF_HAND))
		slots.erase(ItemData.EquipSlot.OFF_HAND)
	elif item.equip_slot == ItemData.EquipSlot.OFF_HAND and weapon() and weapon().is_two_handed():
		displaced.append(weapon().id)
		slots.erase(ItemData.EquipSlot.MAIN_HAND)
	slots[item.equip_slot] = item.id
	changed.emit()
	return old


## Returns and clears the items the last equip() took off besides its own slot.
func take_displaced() -> Array[StringName]:
	var out := displaced.duplicate()
	displaced.clear()
	return out


## True if the off-hand item is a shield (wands and tomes never block).
func has_shield() -> bool:
	var o := offhand()
	return o != null and o.weapon_type == &"shield"


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


## --- Outfit (Milestone 14) -------------------------------------------------------------
## Each light piece shortens the range at which enemies notice you, each heavy
## piece lengthens it; the same weights change the stamina cost of a dodge.
const NOTICE_LIGHT := -0.06
const NOTICE_HEAVY := 0.08
const DODGE_LIGHT := -0.04
const DODGE_HEAVY := 0.06


## ArmorWeight -> number of equipped pieces with that weight.
func weight_counts() -> Dictionary:
	var out := {ItemData.ArmorWeight.LIGHT: 0, ItemData.ArmorWeight.MEDIUM: 0, ItemData.ArmorWeight.HEAVY: 0}
	for slot in slots:
		var item := get_item(slot)
		if item and item.armor_weight != ItemData.ArmorWeight.NONE:
			out[item.armor_weight] += 1
	return out


## Multiplier on how far away enemies notice you (1.0 = normal).
## `heavy_scale` shrinks the heavy-armour part (Heavy Armour Training, M17b).
func notice_mult(heavy_scale: float = 1.0) -> float:
	var w := weight_counts()
	return clampf(1.0 + NOTICE_LIGHT * w[ItemData.ArmorWeight.LIGHT] + NOTICE_HEAVY * heavy_scale * w[ItemData.ArmorWeight.HEAVY], 0.6, 1.5)


## Multiplier on the stamina cost of a dodge roll.
func dodge_cost_mult(heavy_scale: float = 1.0) -> float:
	var w := weight_counts()
	return clampf(1.0 + DODGE_LIGHT * w[ItemData.ArmorWeight.LIGHT] + DODGE_HEAVY * heavy_scale * w[ItemData.ArmorWeight.HEAVY], 0.7, 1.5)


## Short name of the overall outfit style: "Light", "Medium", "Heavy" or "Mixed".
func outfit_style() -> String:
	var w := weight_counts()
	var l: int = w[ItemData.ArmorWeight.LIGHT]
	var m: int = w[ItemData.ArmorWeight.MEDIUM]
	var h: int = w[ItemData.ArmorWeight.HEAVY]
	if l + m + h == 0:
		return "Clothes only"
	if l > m + h:
		return "Light"
	if h > l + m:
		return "Heavy"
	if m >= l and m >= h:
		return "Medium"
	return "Mixed"


## Item ids of the visible outfit pieces (for the model and for multiplayer).
func outfit_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for slot in ItemData.OUTFIT_SLOTS:
		var id := get_item_id(slot)
		if id != &"":
			out.append(String(id))
	return out


## Everything another machine needs to draw this character:
## [weapon type, has off-hand, "id,id,...", weapon id].
func look_args() -> Array:
	var w := weapon()
	return [String(weapon_type()), has_shield(), ",".join(outfit_ids()), String(w.id) if w else ""]


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
