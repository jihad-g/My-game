class_name BiomeData
extends Resource
## Data definition of a biome: terrain shape, colours, climate, props, enemies.

@export var id: StringName
@export var display_name: String = ""

@export_group("Terrain shape (in blocks)")
@export var base_height: float = 6.0
@export var continent_amplitude: float = 16.0
@export var hill_amplitude: float = 10.0
@export var ridge_amplitude: float = 34.0
@export var detail_amplitude: float = 1.5

@export_group("Colours")
@export var top_color: Color = Color(0.36, 0.62, 0.27)
@export var top_color_alt: Color = Color(0.42, 0.67, 0.29)
@export var side_color: Color = Color(0.5, 0.35, 0.22)
@export var shore_color: Color = Color(0.93, 0.84, 0.55)
@export var underwater_color: Color = Color(0.72, 0.64, 0.45)
@export var rock_color: Color = Color(0.56, 0.56, 0.6)
@export var peak_color: Color = Color(0.95, 0.97, 1.0)
## Height (blocks) above which tops turn to rock / snow-capped peaks.
@export var rock_height: int = 30
@export var peak_height: int = 44

@export_group("Climate (degrees C)")
@export var base_temperature: float = 16.0
## Half the day/night temperature difference.
@export var day_night_swing: float = 8.0
## Random regional variation amplitude.
@export var regional_variation: float = 4.0
## Degrees lost per metre above sea level.
@export var altitude_lapse: float = 0.8

@export_group("Content")
@export var prop_rules: Array = []  ## Array of PropRule
@export var enemy_spawns: Array = []  ## Array of EnemySpawnRule
