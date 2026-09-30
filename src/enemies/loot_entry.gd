class_name LootEntry
extends Resource
## One possible drop in a loot table.

@export var item_id: StringName
@export var min_count: int = 1
@export var max_count: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0


func roll(rng: RandomNumberGenerator) -> int:
	if rng.randf() > chance:
		return 0
	return rng.randi_range(min_count, max_count)
