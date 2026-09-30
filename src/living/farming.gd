class_name Farming
## Crop rules (Milestone 5). Growth is measured in world time
## (GameState.world_time), so crops keep growing while you are away or asleep.

## crop -> seed item, produce item, growth time (world seconds), yield range, seeds back
const CROPS := {
	&"wheat": {"seed": &"wheat_seeds", "produce": &"wheat", "grow": 900.0, "yield": [2, 4], "seeds": [1, 2]},
	&"carrot": {"seed": &"carrot_seeds", "produce": &"carrot", "grow": 600.0, "yield": [2, 3], "seeds": [1, 2]},
	&"pumpkin": {"seed": &"pumpkin_seeds", "produce": &"pumpkin", "grow": 1440.0, "yield": [1, 2], "seeds": [1, 2]},
}
const XP_PER_HARVEST := 6


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
