class_name RecipeBook
extends RefCounted
## Loads every recipe and tracks which ones a character knows.
##
## Learning: STARTING recipes are known immediately; DISCOVERY recipes are
## learned the first time the character obtains their `discovered_by` item;
## BOOK recipes come from using recipe books/scrolls (ItemData.teaches_recipes).

signal learned(recipe: RecipeData)

const RECIPE_DIR := "res://data/recipes/"

static var _all: Dictionary = {}  # id -> RecipeData (shared cache)

var known: Dictionary = {}  # id -> true


static func all() -> Dictionary:
	if _all.is_empty():
		for file in ResourceLoader.list_directory(RECIPE_DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var r := load(RECIPE_DIR + file)
				if r is RecipeData:
					_all[r.id] = r
	return _all


static func get_recipe(id: StringName) -> RecipeData:
	return all().get(id)


static func sorted_list() -> Array:
	var list := all().values()
	list.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		if a.station != b.station:
			return a.station < b.station
		if a.tier != b.tier:
			return a.tier < b.tier
		return String(a.id) < String(b.id))
	return list


func learn_starting() -> void:
	for r: RecipeData in all().values():
		if r.source == RecipeData.Source.STARTING:
			known[r.id] = true


func knows(id: StringName) -> bool:
	return known.has(id)


## Returns true if it was new.
func learn(id: StringName) -> bool:
	if known.has(id) or not all().has(id):
		return false
	known[id] = true
	learned.emit(all()[id])
	return true


## Called when an item enters the inventory: learns discovery recipes.
func on_item_obtained(item_id: StringName) -> Array:
	var out := []
	for r: RecipeData in all().values():
		if r.source == RecipeData.Source.DISCOVERY and r.discovered_by == item_id and learn(r.id):
			out.append(r)
	return out


func to_save() -> Array:
	var out := []
	for id in known:
		out.append(String(id))
	return out


func from_save(data: Array) -> void:
	known.clear()
	for id in data:
		if all().has(StringName(id)):
			known[StringName(id)] = true
