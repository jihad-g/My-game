class_name Farming
## Crop rules (Milestone 5). Growth is measured in world time
## (GameState.world_time), so crops keep growing while you are away or asleep.
## Milestone 28: a plot keeps its own growth (0..1) and adds to it at a speed set by
## the season, rain and shelter (rate()); progress()/stage() are the plain
## clock without seasons.

## crop -> seed item, produce item, growth time (world seconds), yield range, seeds back
const CROPS := {
	&"wheat": {"seed": &"wheat_seeds", "produce": &"wheat", "grow": 900.0, "yield": [2, 4], "seeds": [1, 2]},
	&"carrot": {"seed": &"carrot_seeds", "produce": &"carrot", "grow": 600.0, "yield": [2, 3], "seeds": [1, 2]},
	&"pumpkin": {"seed": &"pumpkin_seeds", "produce": &"pumpkin", "grow": 1440.0, "yield": [1, 2], "seeds": [1, 2]},
}
const XP_PER_HARVEST := 6

# --- Milestone 28: seasons and rain -------------------------------------------------------
## Seasons each crop grows in (Seasons.Season). Out of season a crop rests: it
## keeps its progress but doesn't grow until its season comes back.
const SEASONS := {
	&"wheat": [Seasons.Season.SPRING, Seasons.Season.SUMMER],
	&"carrot": [Seasons.Season.SPRING, Seasons.Season.AUTUMN, Seasons.Season.WINTER],
	&"pumpkin": [Seasons.Season.SUMMER, Seasons.Season.AUTUMN],
}
## Extra growth while rain falls on the plot (+60% at full rain).
const RAIN_BONUS := 0.6
## Under a roof (a greenhouse) crops grow in every season, at this speed, but get no rain.
const SHELTER_RATE := 0.6


static func grows_in(crop: StringName, season: int) -> bool:
	return season in SEASONS.get(crop, [0, 1, 2, 3])


## Growth speed (1 = normal) for a crop in a season, with rain 0..1, under a roof or not.
static func rate(crop: StringName, season: int, rain: float, sheltered: bool) -> float:
	if sheltered:
		return SHELTER_RATE
	if not grows_in(crop, season):
		return 0.0
	return 1.0 + RAIN_BONUS * clampf(rain, 0.0, 1.0)


## "Spring, Summer"
static func season_text(crop: StringName) -> String:
	var names := PackedStringArray()
	for s: int in SEASONS.get(crop, []):
		names.append(Seasons.season_name(s))
	return ", ".join(names) if not names.is_empty() else "all year"


## Growth (0..1) after `dt` world seconds at speed `p_rate`.
static func grow(crop: StringName, growth: float, dt: float, p_rate: float) -> float:
	if not CROPS.has(crop):
		return growth
	return clampf(growth + dt / float(CROPS[crop].grow) * p_rate, 0.0, 1.0)


static func stage_of(growth: float) -> int:
	return 3 if growth >= 1.0 else mini(2, int(growth * 3.0))


## Crop planted by a seed item (or &"").
static func crop_for_seed(item_id: StringName) -> StringName:
	for c in CROPS:
		if CROPS[c].seed == item_id:
			return c
	return &""


## 0..1 growth of a crop planted at `planted_at`.
static func progress(crop: StringName, planted_at: float, now: float) -> float:
	if not CROPS.has(crop):
		return 0.0
	return clampf((now - planted_at) / float(CROPS[crop].grow), 0.0, 1.0)


## Visual stage 0..3 (3 = ripe).
static func stage(crop: StringName, planted_at: float, now: float) -> int:
	var p := progress(crop, planted_at, now)
	return 3 if p >= 1.0 else mini(2, int(p * 3.0))
