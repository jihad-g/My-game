class_name Seasons
## The four seasons (Milestone 28).
##
## A season lasts DAYS_PER_SEASON in-game days: day 1 starts spring, then
## summer, autumn and winter, then spring again. The last half day of each
## season blends into the next one, so leaves turn and snow comes slowly.
##
## Seasons change:
##   - the look of the world (shader globals season_mix and snow_cover):
##     spring blossoms, golden autumn leaves, snow on the grass in winter;
##   - the air temperature (OFFSET; never lethal - temperature only slows you);
##   - which crops grow (Farming.SEASONS).
##
## Everything is worked out from the day and hour, so a loaded save shows the
## right season. Creative mode can force one (`forced`, not saved).

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
const NAMES := ["Spring", "Summer", "Autumn", "Winter"]
const IDS := [&"spring", &"summer", &"autumn", &"winter"]
## In-game days per season (a default day is 20 minutes: a season is 80 minutes).
const DAYS_PER_SEASON := 4
## Hours at the end of a season spent blending into the next one.
const BLEND_HOURS := 12.0
## Air temperature change per season (°C).
const OFFSET := [-1.0, 3.0, -2.0, -7.0]

## -1 = natural; 0..3 = forced season (Creative mode, tests).
static var forced := -1


static func season_of(day: int) -> int:
	if forced >= 0:
		return forced
	return int(floori(float(maxi(day, 1) - 1) / DAYS_PER_SEASON)) % 4


static func season_name(s: int) -> String:
	return NAMES[clampi(s, 0, 3)]


## Day of the season, 1..DAYS_PER_SEASON.
static func day_in_season(day: int) -> int:
	return (maxi(day, 1) - 1) % DAYS_PER_SEASON + 1


## Weights of (spring, summer, autumn, winter), summing to 1.
static func blend(day: int, hour: float) -> Vector4:
	var s := season_of(day)
	var w := [0.0, 0.0, 0.0, 0.0]
	if forced >= 0:
		w[s] = 1.0
		return Vector4(w[0], w[1], w[2], w[3])
	var hours_left := float(DAYS_PER_SEASON - day_in_season(day)) * 24.0 + (24.0 - hour)
	var k := 0.0
	if hours_left < BLEND_HOURS:
		k = smoothstep(0.0, 1.0, 1.0 - hours_left / BLEND_HOURS)
	w[s] = 1.0 - k
	w[(s + 1) % 4] += k
	return Vector4(w[0], w[1], w[2], w[3])


## Temperature change for the blended season (°C).
static func temperature_offset(day: int, hour: float) -> float:
	var b := blend(day, hour)
	return b.x * OFFSET[0] + b.y * OFFSET[1] + b.z * OFFSET[2] + b.w * OFFSET[3]


## Snow lying on the grass (0..1): winter in a cold enough place, more while it snows.
## `climate_t` is the 0..1 temperature of the place (TerrainGenerator.temperature01).
static func snow_cover(day: int, hour: float, climate_t: float, snowing: float) -> float:
	var winter := blend(day, hour).w
	# Warm lands (jungle, desert, savanna) never get snow.
	var cold := 1.0 - smoothstep(0.5, 0.68, climate_t)
	return clampf(winter * cold * (0.75 + 0.25 * snowing) + snowing * 0.5 * (1.0 - smoothstep(0.3, 0.55, climate_t)), 0.0, 1.0)


## Pushes the look of the season to the shaders.
static func apply_globals(mix: Vector4, snow: float) -> void:
	RenderingServer.global_shader_parameter_set(&"season_mix", mix)
	RenderingServer.global_shader_parameter_set(&"snow_cover", snow)
