class_name PropRule
extends Resource
## Placement rule for one prop type inside a biome.
##
## The world is split into square cells of `cell_size` blocks; each cell gets at
## most one prop with probability `density` (modulated by clustering noise).
## Cells are aligned to world coordinates, so results never depend on which
## chunk is generated first - fully deterministic from the seed.

@export var prop_id: StringName
## Must divide the chunk size (16): 1, 2, 4, 8 or 16.
@export var cell_size: int = 4
@export_range(0.0, 1.0) var density: float = 0.2
## How strongly the biome's clustering noise affects density (0 = uniform).
@export_range(0.0, 1.0) var clustering: float = 0.5
@export var min_height: int = 1
@export var max_height: int = 999
## Maximum height difference (in blocks) to neighbouring columns.
@export var max_slope: int = 1
@export var min_scale: float = 0.85
@export var max_scale: float = 1.15
## Also placed in LOD1 chunks (visual only, no collision/interaction).
@export var show_in_lod1: bool = false
## Unique salt so rules sharing a cell size don't pick identical cells.
@export var salt: int = 1
