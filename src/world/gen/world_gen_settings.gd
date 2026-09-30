class_name WorldGenSettings
extends Resource
## All tunable world-generation parameters plus the biome list.
##
## Terrain shape comes from *continuous* noise fields (continentalness,
## mountains, temperature, moisture...), so there are never seams between
## biomes. Biomes then classify each column (colours, vegetation, resources,
## enemies). Changing these values changes every world generated from a seed,
## so treat them like a save-format version (see `generator_version`).

## Bump when changes would alter existing worlds; stored in saves.
@export var generator_version: int = 2

@export_group("Continents & oceans (blocks)")
@export var continent_frequency: float = 0.00035
## Continentalness below coast_start is ocean, above coast_end is full land.
@export var coast_start: float = -0.24
@export var coast_end: float = -0.04
@export var ocean_depth: float = -16.0
@export var land_base: float = 3.0
@export var continent_amplitude: float = 16.0
@export var island_frequency: float = 0.004
@export var island_threshold: float = 0.52

@export_group("Hills & mountains (blocks)")
@export var hill_frequency: float = 0.0065
@export var hill_amplitude: float = 10.0
@export var mountain_mask_frequency: float = 0.0009
@export var mountain_mask_start: float = 0.12
@export var mountain_mask_end: float = 0.5
@export var ridge_frequency: float = 0.009
@export var mountain_amplitude: float = 95.0
@export var detail_frequency: float = 0.08
@export var detail_amplitude: float = 1.2
@export var dune_frequency: float = 0.035
@export var dune_amplitude: float = 4.0

@export_group("Water")
@export var lake_frequency: float = 0.009
@export var lake_threshold: float = 0.6
@export var river_frequency: float = 0.0011
## |river noise| below this is the channel, below valley width the banks slope down.
@export var river_width: float = 0.011
@export var river_valley_width: float = 0.035
@export var river_warp: float = 45.0

@export_group("Climate")
@export var temperature_frequency: float = 0.00022
@export var moisture_frequency: float = 0.0003
## Stretches the climate noise toward the extremes (higher = more extreme
## climates, sharper transitions between them).
@export var climate_contrast: float = 1.15
## Air temperature (deg C) at temperature=0 and temperature=1.
@export var coldest_temperature: float = -14.0
@export var hottest_temperature: float = 36.0
## Day/night half-swing for wet and dry climates (deserts swing more).
@export var wet_day_night_swing: float = 4.0
@export var dry_day_night_swing: float = 12.0
@export var regional_variation: float = 2.5
## Degrees lost per metre above sea level.
@export var altitude_lapse: float = 0.45
@export var cave_temperature: float = 12.0

@export_group("Caves")
@export var cave_tunnel_frequency: float = 0.02
@export var cave_tunnel_width: float = 0.2
@export var cave_cavern_frequency: float = 0.012
@export var cave_cavern_threshold: float = 0.42
@export var cave_entrance_cell: int = 64
@export_range(0.0, 1.0) var cave_entrance_chance: float = 0.22
@export var cave_room_radius: float = 5.5

@export_group("Biomes")
## All biomes. Order matters for save compatibility of harvested props:
## append new biomes / rules at the END of lists.
@export var biomes: Array = []  ## Array of BiomeData
