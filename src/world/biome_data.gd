class_name BiomeData
extends Resource
## Data definition of a biome: selection rules, colours, vegetation, resources, enemies.
##
## Terrain *shape* is global and continuous (WorldGenSettings); a biome decides
## what a column looks like and what grows/spawns on it.

## How the generator may pick this biome.
enum Role {
	LAND,         ## Chosen by temperature/moisture ranges (first match by list order).
	OCEAN,        ## Deep water far from continents.
	BEACH,        ## Low coastal land next to the sea.
	MOUNTAIN,     ## High or strongly mountainous terrain.
	RARE,         ## Rare land biome where its rarity noise exceeds rare_threshold.
	UNDERGROUND,  ## The cave layer.
}

@export var id: StringName
@export var display_name: String = ""
@export var role: Role = Role.LAND
## Colour on the world map.
@export var map_color: Color = Color(0.4, 0.7, 0.3)

@export_group("Selection (0..1 climate space)")
@export var temperature_min: float = 0.0
@export var temperature_max: float = 1.0
@export var moisture_min: float = 0.0
@export var moisture_max: float = 1.0
## RARE only: rarity noise threshold (higher = rarer).
@export var rare_threshold: float = 0.8

@export_group("Colours")
@export var top_color: Color = Color(0.36, 0.62, 0.27)
@export var top_color_alt: Color = Color(0.42, 0.67, 0.29)
@export var side_color: Color = Color(0.5, 0.35, 0.22)
@export var shore_color: Color = Color(0.93, 0.84, 0.55)
@export var underwater_color: Color = Color(0.72, 0.64, 0.45)
@export var rock_color: Color = Color(0.55, 0.52, 0.49)
@export var peak_color: Color = Color(0.95, 0.97, 1.0)
## Height (blocks) above which tops turn to rock / snow-capped peaks.
@export var rock_height: int = 60
@export var peak_height: int = 80
## Lakes/rivers freeze into walkable ice.
@export var frozen_water: bool = false
@export var ice_color: Color = Color(0.75, 0.9, 1.0)

@export_group("Content")
@export var prop_rules: Array = []  ## Array of PropRule
@export var enemy_spawns: Array = []  ## Array of EnemySpawnRule
