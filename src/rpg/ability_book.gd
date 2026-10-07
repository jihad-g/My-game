class_name AbilityBook
extends RefCounted
## Every class ability (Milestone 17b): the three starting abilities in
## ClassData.abilities plus the abilities in data/abilities/<class>/, learned
## one every two levels. Actives go on the 6-slot bar; passives are always on.

const DIR := "res://data/abilities/"

static var _by_id: Dictionary = {}
static var _by_class: Dictionary = {}


static func _load() -> void:
	if not _by_id.is_empty():
		return
	var shield := load(DIR + "temperature_shield.tres") as AbilityData
	_by_id[shield.id] = shield
	for c in ClassRegistry.all():
		var list: Array = []
		for a in c.abilities:
			list.append(a)
			_by_id[(a as AbilityData).id] = a
		var d := DirAccess.open(DIR + String(c.id))
		if d:
			for f in d.get_files():
				var file := f.trim_suffix(".remap")
				if file.ends_with(".tres"):
					var a := load(DIR + String(c.id) + "/" + file) as AbilityData
					if a:
						list.append(a)
						_by_id[a.id] = a
		list.sort_custom(func(x: AbilityData, y: AbilityData) -> bool:
			return x.unlock_level < y.unlock_level or (x.unlock_level == y.unlock_level and String(x.id) < String(y.id)))
		_by_class[c.id] = list


## The class's abilities in learning order (not the universal Temperature Shield).
static func for_class(class_id: StringName) -> Array:
	_load()
	return _by_class.get(class_id, [])


static func get_ability(id: StringName) -> AbilityData:
	_load()
	return _by_id.get(id, null)


## Abilities a class learns at exactly `level`.
static func learned_at(class_id: StringName, level: int) -> Array:
	return for_class(class_id).filter(func(a: AbilityData) -> bool: return a.unlock_level == level)
