class_name SpellBook
extends RefCounted
## Advanced spells the player has learned from tomes (Milestone 7) and the
## spell slots (keys Y and H, plus N while a tome is held - Milestone 17b). Any class can learn spells; casting needs the
## spell's Mana Control requirement and its damage scales with spell power,
## so Wizards are by far the best casters.

signal changed

const DIR := "res://data/spells/"
const SLOTS := 3
const SLOT_KEYS := ["Y", "H", "N"]

static var _all: Dictionary = {}

var known: Array[StringName] = []
## Spell id per slot (&"" = empty).
var slots: Array[StringName] = [&"", &"", &""]
## The third slot only works while an off-hand tome is held (weapon_params spell_slot).
var extra_slot := false


## Number of slots that can be used right now.
func usable_slots() -> int:
	return SLOTS if extra_slot else SLOTS - 1


static func all() -> Dictionary:
	if _all.is_empty():
		var d := DirAccess.open(DIR)
		if d:
			for f in d.get_files():
				var file := f.trim_suffix(".remap")
				if file.ends_with(".tres"):
					var a := load(DIR + file) as AbilityData
					if a:
						_all[a.id] = a
	return _all


static func get_spell(id: StringName) -> AbilityData:
	return all().get(id, null)


## Spells sorted by their Mana Control requirement.
static func sorted_ids() -> Array:
	var ids: Array = all().keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_spell(a).required_mana_control < get_spell(b).required_mana_control)
	return ids


func knows(id: StringName) -> bool:
	return known.has(id)


## Learns a spell. It goes into the first empty slot. Returns false if already known.
func learn(id: StringName) -> bool:
	if knows(id) or get_spell(id) == null:
		return false
	known.append(id)
	for i in usable_slots():
		if slots[i] == &"":
			slots[i] = id
			break
	changed.emit()
	return true


## Puts a known spell into a slot (swapping if it's in the other slot).
func assign(slot: int, id: StringName) -> void:
	if slot < 0 or slot >= SLOTS or (id != &"" and not knows(id)):
		return
	var other := slots.find(id)
	if other >= 0 and id != &"":
		slots[other] = slots[slot]
	slots[slot] = id
	changed.emit()


func get_slot(slot: int) -> AbilityData:
	if slot < 0 or slot >= usable_slots() or slots[slot] == &"":
		return null
	return get_spell(slots[slot])


func to_save() -> Dictionary:
	return {"known": known.map(func(x: StringName) -> String: return String(x)),
		"slots": slots.map(func(x: StringName) -> String: return String(x))}


func from_save(d: Dictionary) -> void:
	known.clear()
	for id in d.get("known", []):
		if get_spell(StringName(id)):
			known.append(StringName(id))
	var sl: Array = d.get("slots", [])
	slots = [&"", &"", &""]
	for i in mini(sl.size(), SLOTS):
		if knows(StringName(sl[i])):
			slots[i] = StringName(sl[i])
	changed.emit()
