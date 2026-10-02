extends Node
## Registry of every ItemData resource, keyed by item id.
##
## Items are data files in res://data/items/. Adding a new item = adding a new
## .tres file; no code changes needed.

const ITEM_DIRS: Array[String] = ["res://data/items/"]

var _items: Dictionary = {}  # StringName -> ItemData


func _ready() -> void:
	load_all()


func load_all() -> void:
	_items.clear()
	for dir in ITEM_DIRS:
		for file in ResourceLoader.list_directory(dir):
			if not (file.ends_with(".tres") or file.ends_with(".res")):
				continue
			var res := load(dir + file)
			if res is ItemData:
				register(res)
			else:
				push_warning("ItemDB: %s is not an ItemData resource" % file)


func register(item: ItemData) -> void:
	if item.id == &"":
		push_error("ItemDB: item without id: %s" % item.resource_path)
		return
	if _items.has(item.id):
		push_warning("ItemDB: duplicate item id '%s' (%s)" % [item.id, item.resource_path])
	_items[item.id] = item


func get_item(id: StringName) -> ItemData:
	var item: ItemData = _items.get(id)
	if item == null and String(id).contains("@"):
		item = _variant(id)
	return item


func has_item(id: StringName) -> bool:
	return _items.has(id) or (String(id).contains("@") and _variant(id) != null)


## Base items only (quality variants are made on demand, see ItemQuality).
func all_ids() -> Array:
	var out := []
	for id in _items:
		if not String(id).contains("@"):
			out.append(id)
	return out


## Fine / Masterwork version of an item ("iron_sword@fine"), cached once built.
func _variant(id: StringName) -> ItemData:
	var q := ItemQuality.quality_of(id)
	var base: ItemData = _items.get(ItemQuality.base_id(id))
	if q == ItemQuality.NORMAL or not ItemQuality.can_have_quality(base):
		return null
	var v := ItemQuality.make_variant(base, q)
	if v.id != id:
		return null
	_items[id] = v
	return v
