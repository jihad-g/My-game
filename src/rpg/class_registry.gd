class_name ClassRegistry
## Loads playable classes from res://data/classes/ (one ClassData .tres each).

const CLASS_DIR := "res://data/classes/"
const DEFAULT_CLASS := &"knight"
## Display order in menus.
const ORDER: Array[StringName] = [&"barbarian", &"knight", &"wizard", &"assassin"]


static func get_class_data(id: StringName) -> ClassData:
	var path := "%s%s.tres" % [CLASS_DIR, id]
	if ResourceLoader.exists(path):
		return load(path)
	return load("%s%s.tres" % [CLASS_DIR, DEFAULT_CLASS])


static func all() -> Array[ClassData]:
	var out: Array[ClassData] = []
	for id in ORDER:
		out.append(get_class_data(id))
	return out
