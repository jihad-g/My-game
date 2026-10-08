class_name AbilityUpgrades
extends RefCounted
## Ability upgrades (Milestone 17d, idea 5i). From level 30 every active class
## ability can get ONE of two upgrades. You choose (and change) them in the
## ability book (L) while resting at a bed or a campfire, like the ability bar.
##
## - The three starting abilities of every class have two special upgrades that
##   change how they work (Firebolt: "Split Bolt" or "Burning Ground").
## - Every other active ability gets the same pair:
##     A "Empowered": +30% damage, +25% duration, +15% area
##     B "Swift":     -30% cooldown, -25% cost
## - Ultimates, passives and the Temperature Shield have no upgrades.
##
## An option is {"name", "text", "mul": {field: x}, "add": {field: x}, "tag": StringName}.
## `mul`/`add` change the AbilityData numbers (PlayerAbilities uses an upgraded
## copy); `tag` names a special behaviour checked by the ability's code.

const UNLOCK_LEVEL := 30

const SPECIAL := {
	# Barbarian
	&"whirlwind": [
		{"name": "Cyclone", "text": "One more spin (3 hits).", "add": {"power": 1.0}},
		{"name": "Bloody Spin", "text": "Every spin makes enemies bleed.", "tag": &"bleed"},
	],
	&"battle_cry": [
		{"name": "Long Cry", "text": "The damage buff lasts 50% longer.", "mul": {"duration": 1.5}},
		{"name": "Terrifying Cry", "text": "Enemies near you are stunned for 1 s.", "tag": &"stun"},
	],
	&"berserk": [
		{"name": "Endless Fury", "text": "Berserk lasts 4 s longer.", "add": {"duration": 4.0}},
		{"name": "Blood Rage", "text": "Your hits heal 20% of the damage instead of 10%.", "tag": &"lifesteal"},
	],
	# Knight
	&"shield_bash": [
		{"name": "Wide Bash", "text": "Hits a much wider area in front of you.", "mul": {"radius": 1.4}, "tag": &"wide"},
		{"name": "Concussion", "text": "The stun lasts 1 s longer.", "add": {"duration": 1.0}},
	],
	&"guardian": [
		{"name": "Fortress", "text": "You take 60% less damage instead of 50%.", "tag": &"fortress"},
		{"name": "Mobile Guard", "text": "Guardian Stance no longer slows you.", "tag": &"mobile"},
	],
	&"rallying_charge": [
		{"name": "Long Charge", "text": "The charge goes 50% further.", "mul": {"range": 1.5}},
		{"name": "Healing Charge", "text": "The charge heals twice as much.", "mul": {"power": 2.0}},
	],
	# Wizard
	&"firebolt": [
		{"name": "Split Bolt", "text": "Shoots 3 bolts in a fan (the side bolts deal 60%).", "tag": &"split"},
		{"name": "Burning Ground", "text": "Leaves burning ground for 3 s where it hits.", "tag": &"ground"},
	],
	&"frost_nova": [
		{"name": "Wide Nova", "text": "40% bigger area.", "mul": {"radius": 1.4}},
		{"name": "Deep Freeze", "text": "+30% damage and enemies stay frozen 1.5 s longer.", "mul": {"damage": 1.3}, "add": {"duration": 1.5}},
	],
	&"chain_lightning": [
		{"name": "Forked", "text": "Jumps to 2 more enemies.", "add": {"power": 2.0}},
		{"name": "Overcharge", "text": "The damage no longer drops with each jump.", "tag": &"overcharge"},
	],
	# Assassin
	&"shadow_step": [
		{"name": "Shadow Strike", "text": "You also stab the target when you arrive.", "tag": &"strike"},
		{"name": "Fading Step", "text": "You stay hidden for 1.5 s after the step.", "tag": &"fade"},
	],
	&"poison_blade": [
		{"name": "Deadly Venom", "text": "The poison deals 50% more damage.", "mul": {"damage": 1.5}},
		{"name": "Long Coating", "text": "The poison stays on your blade 60% longer.", "mul": {"power": 1.6}},
	],
	&"vanish": [
		{"name": "Deep Shadows", "text": "Stealth lasts 50% longer.", "mul": {"duration": 1.5}},
		{"name": "Smoke Escape", "text": "Leaves a smoke cloud behind and heals you by 10%.", "tag": &"smoke"},
	],
}


## The two upgrade choices for an ability ([] = it can't be upgraded).
static func options(a: AbilityData) -> Array:
	if a == null or a.passive or a.ultimate or a.id == &"temperature_shield":
		return []
	if SPECIAL.has(a.id):
		return SPECIAL[a.id]
	var power := PackedStringArray()
	var mul := {}
	if a.damage > 0.0:
		power.append("+30% damage")
		mul["damage"] = 1.3
	if a.duration > 0.0:
		power.append("+25% duration")
		mul["duration"] = 1.25
	if a.radius > 0.0:
		power.append("+15% area")
		mul["radius"] = 1.15
	if power.is_empty():
		power.append("+25% range")
		mul["range"] = 1.25
	var swift := {"cooldown": 0.7}
	var swift_text := "-30% cooldown"
	if a.cost > 0.0:
		swift["cost"] = 0.75
		swift_text += ", -25% cost"
	return [
		{"name": "Empowered", "text": ", ".join(power) + ".", "mul": mul},
		{"name": "Swift", "text": swift_text + ".", "mul": swift},
	]


## A copy of `a` with the upgrade's numbers applied.
static func apply(a: AbilityData, option: Dictionary) -> AbilityData:
	var out := a.duplicate() as AbilityData
	var mul: Dictionary = option.get("mul", {})
	for k in mul:
		out.set(k, float(out.get(k)) * float(mul[k]))
	var add: Dictionary = option.get("add", {})
	for k in add:
		out.set(k, float(out.get(k)) + float(add[k]))
	return out
