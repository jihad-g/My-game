class_name StatBlock
extends Node
## Aggregates multiplicative stat modifiers from many sources.
##
## Each source (e.g. &"temperature", &"hunger", later &"equipment", &"buff_x")
## owns a set of {stat: multiplier}. The final value of a stat is the product of
## all sources. Sources replace their whole set at once, so stale modifiers
## never linger.

signal modifiers_changed

var _sources: Dictionary = {}  # StringName source -> Dictionary {StringName stat -> float}


## Replaces every modifier owned by `source`.
func set_source(source: StringName, mults: Dictionary) -> void:
	if mults.is_empty():
		clear_source(source)
		return
	if _sources.get(source, {}) == mults:
		return
	_sources[source] = mults.duplicate()
	modifiers_changed.emit()


func clear_source(source: StringName) -> void:
	if _sources.erase(source):
		modifiers_changed.emit()


func get_mult(stat: StringName) -> float:
	var result := 1.0
	for source: StringName in _sources:
		result *= float(_sources[source].get(stat, 1.0))
	return result


func get_source(source: StringName) -> Dictionary:
	return _sources.get(source, {})


func has_source(source: StringName) -> bool:
	return _sources.has(source)
