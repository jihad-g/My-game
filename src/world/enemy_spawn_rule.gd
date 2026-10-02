class_name EnemySpawnRule
extends Resource
## Chance for a chunk to contain a spawn slot for an enemy type.

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export_range(0.0, 1.0) var chance_per_chunk: float = 0.2
@export var min_height: int = 1
@export var max_height: int = 999
@export var salt: int = 1
## Milestone 15: spawn a group (packs, herds) - extra members stand around the slot.
@export var group_min: int = 1
@export var group_max: int = 1
