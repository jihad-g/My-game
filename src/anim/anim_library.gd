class_name AnimLibrary
extends RefCounted
## Builds the HumanoidModel clips (Milestone 18a). Clips are made from short
## tables so new moves are data: an attack is a wind-up, a strike that
## overshoots a little and a recovery; an ability pose is an anticipation, the
## pose (with a small overshoot), a hold and a release.

## Arm swing shapes: [ready, strike]; x = shoulder pitch (negative = up/forward),
## y = shoulder yaw, z = torso twist. Extra: torso lean forward on the strike,
## forward step and body dip.
const SWINGS := {
	&"slash_r": {"ready": Vector3(-2.2, 0.9, -0.5), "strike": Vector3(-1.3, -1.1, 0.6), "lean": 0.12, "step": 0.1, "dip": -0.03},
	&"slash_l": {"ready": Vector3(-1.4, -1.2, 0.6), "strike": Vector3(-1.5, 1.0, -0.6), "lean": 0.12, "step": 0.1, "dip": -0.03},
	&"thrust": {"ready": Vector3(-0.9, 0.2, -0.3), "strike": Vector3(-1.7, 0.0, 0.3), "lean": 0.22, "step": 0.18, "dip": -0.02},
	&"overhead": {"ready": Vector3(-3.0, 0.1, -0.2), "strike": Vector3(-0.6, 0.0, 0.2), "lean": 0.3, "step": 0.12, "dip": -0.08},
	&"spin": {"ready": Vector3(-1.6, 1.4, -0.9), "strike": Vector3(-1.6, -1.4, 0.9), "lean": 0.05, "step": 0.0, "dip": -0.04},
	&"plunge": {"ready": Vector3(-3.1, 0.0, -0.3), "strike": Vector3(-0.3, 0.0, 0.4), "lean": 0.35, "step": 0.0, "dip": -0.12},
	# Milestone 18b: the greatsword finisher jumps forward and slams down.
	&"leap_slam": {"ready": Vector3(-3.0, 0.1, -0.2), "strike": Vector3(-0.4, 0.0, 0.3), "lean": 0.35, "step": 0.0, "dip": -0.14, "jump": 0.9},
}
const REST_ARM := Vector3(-0.25, 0.0, 0.0)


## A weapon swing: wind-up to `ready`, strike and recovery. Milestone 38: shaped
## like the reference clip (anticipation, 2-3 frame strike, follow-through).
## `hold`: the swing waits at the end of the wind-up (charged heavy, bow draw).
static func attack(anim: StringName, windup: float, active: float, recovery: float, two_handed: bool,
		bow: bool, hold: bool) -> AnimClip:
	windup = maxf(windup, 0.02)
	active = maxf(active, 0.05)
	recovery = maxf(recovery, 0.05)
	if anim == &"aim" and bow:
		return _bow_draw(windup, active, recovery, hold)
	var s: Dictionary = SWINGS.get(anim, SWINGS[&"slash_r"])
	var ready: Vector3 = s.ready
	var strike: Vector3 = s.strike
	if anim == &"aim":
		ready = Vector3(-1.55, 0.25, -0.35)
		strike = Vector3(-1.5, 0.0, 0.1)
	var t_strike := windup + active
	var total := t_strike + recovery
	var c := AnimClip.new(anim, total)
	c.legs_when_moving = false
	c.fade_in = minf(0.06, windup * 0.6)
	c.fade_out = recovery * 0.45
	if hold:
		c.hold_at = windup
	# Milestone 38: the measured swing shape (see CombatFeel). Inside the attack's own
	# times: wind up past the ready pose (anticipation), hang there on heavy swings,
	# snap through the strike in 2-3 frames, carry on past it (follow-through), settle.
	var heavy := CombatFeel.is_heavy_windup(windup)
	var ant := (ready - strike) * CombatFeel.ANTICIPATION
	var over := strike + (strike - ready) * (CombatFeel.HEAVY_OVERSHOOT if heavy else CombatFeel.OVERSHOOT)
	var t_ant := windup * (0.55 if heavy else 0.7)
	var ready_end := ready + ant * (0.6 if heavy else 0.0)
	var t_hit := windup + minf(active, CombatFeel.sec(CombatFeel.HEAVY_STRIKE_FRAMES if heavy else CombatFeel.STRIKE_FRAMES))
	var follow := over.lerp(strike, 0.3)
	var arm_r := func(v: Vector3) -> Vector3: return Vector3(v.x, v.y, 0.0)
	var arm_keys := [[0.0, ready.lerp(REST_ARM, 0.5), AnimClip.LINEAR], [t_ant, ready + ant, AnimClip.IN_OUT],
		[windup, ready_end, AnimClip.IN_OUT], [t_hit, over, AnimClip.LINEAR]]
	if t_strike > t_hit + 0.005:
		arm_keys.append([t_strike, follow, AnimClip.EASE_OUT])
	arm_keys.append([t_strike + recovery * 0.35, strike, AnimClip.IN_OUT])
	arm_keys.append([total, REST_ARM, AnimClip.IN_OUT])
	for k in arm_keys:
		c.key(&"arm_r", float(k[0]), arm_r.call(k[1]) if float(k[0]) < total else REST_ARM, k[2])
	c.key(&"fore_r", 0.0, -0.4).key(&"fore_r", windup, -0.5, AnimClip.EASE_OUT).key(&"fore_r", t_strike, -0.05, AnimClip.EASE_OUT) \
		.key(&"fore_r", total, -0.3)
	c.key(&"weapon", 0.0, Vector3.ZERO).key(&"weapon", total, Vector3.ZERO)
	# The torso twists with the arm and leans into the strike.
	var lean: float = s.lean
	c.key(&"torso", 0.0, Vector3(0.0, ready.z * 0.5, 0.0))
	c.key(&"torso", t_ant, Vector3(-lean * 0.5, ready.z * 1.1, 0.0), AnimClip.EASE_OUT)
	c.key(&"torso", windup, Vector3(-lean * 0.4, ready.z, 0.0), AnimClip.IN_OUT)
	c.key(&"torso", t_hit, Vector3(lean * 1.15, strike.z * 1.2, 0.0), AnimClip.LINEAR)
	if t_strike > t_hit + 0.005:
		c.key(&"torso", t_strike, Vector3(lean, strike.z * 1.1, 0.0), AnimClip.EASE_OUT)
	c.key(&"torso", total, Vector3.ZERO, AnimClip.IN_OUT)
	# Body: a small forward step and dip on the strike (legs only while standing).
	c.key(&"step", 0.0, 0.0).key(&"step", t_hit, float(s.step), AnimClip.EASE_OUT).key(&"step", total, 0.0)
	if s.has("jump"):
		# A jump during the wind-up that lands on the strike.
		c.key(&"lift", 0.0, -0.06).key(&"lift", windup * 0.55, float(s.jump), AnimClip.EASE_OUT) \
			.key(&"lift", windup, float(s.jump) * 0.6, AnimClip.EASE_IN).key(&"lift", t_strike, float(s.dip), AnimClip.EASE_IN) \
			.key(&"lift", total, 0.0)
		c.legs_when_moving = true
	else:
		c.key(&"lift", 0.0, 0.0).key(&"lift", windup, 0.02).key(&"lift", t_hit, float(s.dip) * 1.3, AnimClip.EASE_OUT) \
			.key(&"lift", t_strike + recovery * 0.35, float(s.dip), AnimClip.EASE_OUT).key(&"lift", total, 0.0)
	c.key(&"leg_l", 0.0, -0.1).key(&"leg_l", t_strike, -0.45, AnimClip.EASE_OUT).key(&"leg_l", total, 0.0)
	c.key(&"leg_r", 0.0, 0.05).key(&"leg_r", t_strike, 0.3, AnimClip.EASE_OUT).key(&"leg_r", total, 0.0)
	c.key(&"shin_l", 0.0, 0.1).key(&"shin_l", t_strike, 0.35, AnimClip.EASE_OUT).key(&"shin_l", total, 0.05)
	c.key(&"shin_r", 0.0, 0.1).key(&"shin_r", t_strike, 0.25, AnimClip.EASE_OUT).key(&"shin_r", total, 0.05)
	if two_handed:
		# Both hands on the handle: the left arm follows the right one.
		var off := Vector3(0.15, 0.7, 0.0)
		c.key(&"arm_l", 0.0, arm_r.call(ready.lerp(REST_ARM, 0.5)) + off)
		c.key(&"arm_l", t_ant, arm_r.call(ready + ant) + off, AnimClip.IN_OUT)
		c.key(&"arm_l", windup, arm_r.call(ready_end) + off, AnimClip.IN_OUT)
		c.key(&"arm_l", t_hit, arm_r.call(over) + off, AnimClip.LINEAR)
		if t_strike > t_hit + 0.005:
			c.key(&"arm_l", t_strike, arm_r.call(follow) + off, AnimClip.EASE_OUT)
		c.key(&"arm_l", t_strike + recovery * 0.35, arm_r.call(strike) + off)
		c.key(&"arm_l", total, Vector3(-0.75, 0.55, 0.0))
		c.key(&"fore_l", 0.0, -0.5).key(&"fore_l", total, -0.6)
	else:
		# The free arm swings back for balance.
		c.key(&"arm_l", 0.0, Vector3(-0.2, 0.0, -0.1))
		c.key(&"arm_l", windup, Vector3(-0.6, 0.0, -0.2), AnimClip.EASE_OUT)
		c.key(&"arm_l", t_hit, Vector3(0.4, 0.0, -0.3), AnimClip.LINEAR)
		c.key(&"arm_l", t_strike + 0.001, Vector3(0.35, 0.0, -0.3), AnimClip.EASE_OUT)
		c.key(&"arm_l", total, Vector3(0.0, 0.0, -0.04))
	c.event(windup, &"trail_on").event(windup, &"hit").event(t_strike, &"trail_off")
	return c


## Drawing a bow (held in the left hand): pull to the chest, release, relax.
static func _bow_draw(windup: float, active: float, recovery: float, hold: bool) -> AnimClip:
	var total := windup + active + recovery
	var c := AnimClip.new(&"aim", total)
	c.fade_in = 0.05
	c.fade_out = recovery * 0.5
	if hold:
		c.hold_at = windup
	var pose := func(p: float, release: float) -> Dictionary:
		return {&"arm_l": Vector3(-1.55 * p, 0.2 * p, 0.0), &"fore_l": 0.0,
			&"arm_r": Vector3(-1.45 * p, -0.55 * p + release * 0.4, 0.0), &"fore_r": -1.7 * p + release * 1.2,
			&"shield": Vector3(1.55 * p, 0.0, 0.0), &"weapon": Vector3.ZERO, &"torso": Vector3(0.0, -0.35 * p, 0.0)}
	var keys := [[0.0, pose.call(0.35, 0.0), AnimClip.IN_OUT], [windup, pose.call(1.0, 0.0), AnimClip.EASE_OUT],
		[windup + active, pose.call(1.0, 1.0), AnimClip.EASE_OUT], [total, pose.call(0.0, 0.0), AnimClip.IN_OUT]]
	for k in keys:
		var d: Dictionary = k[1]
		for part in d:
			c.key(part, float(k[0]), d[part], k[2])
	c.event(windup + active, &"release")
	return c


## Spell casting: both hands raised forward with a tremble of power.
static func cast(duration: float) -> AnimClip:
	var c := AnimClip.new(&"cast", maxf(duration, 0.2))
	var l := c.length
	var lift := minf(0.12, l * 0.3)
	c.fade_in = 0.06
	c.fade_out = 0.1
	c.shake = 0.04
	c.key(&"arm_l", 0.0, Vector3(-1.0, 0.25, 0.0)).key(&"arm_l", lift, Vector3(-1.55, 0.35, 0.0), AnimClip.BACK).hold(&"arm_l", lift, l, Vector3(-1.5, 0.35, 0.0))
	c.key(&"arm_r", 0.0, Vector3(-1.0, -0.25, 0.0)).key(&"arm_r", lift, Vector3(-1.55, -0.35, 0.0), AnimClip.BACK).hold(&"arm_r", lift, l, Vector3(-1.5, -0.35, 0.0))
	c.hold(&"fore_l", 0.0, l, -0.5)
	c.hold(&"fore_r", 0.0, l, -0.5)
	c.key(&"torso", 0.0, Vector3(0.08, 0.0, 0.0)).key(&"torso", lift, Vector3(-0.08, 0.0, 0.0), AnimClip.EASE_OUT).key(&"torso", l, Vector3.ZERO)
	return c


## An ability pose (HumanoidModel.POSES): a short anticipation, the pose with a
## small overshoot, a hold and a release. Values: al/ar arm rotations, fl/fr
## forearm bends, tx torso lean, ry body height, jump (an arc), shake.
static func pose(id: StringName, p: Dictionary, duration: float) -> AnimClip:
	var c := AnimClip.new(id, maxf(duration, 0.2))
	var l := c.length
	var t_in := minf(0.16, l * 0.3)
	var t_out := maxf(l - minf(0.15, l * 0.25), t_in + 0.01)
	c.fade_in = 0.05
	c.fade_out = 0.14
	c.shake = 0.05 if p.get("shake", false) else 0.0
	var al: Vector3 = p.al
	var ar: Vector3 = p.ar
	var tx := float(p.tx)
	# Anticipation: the body winds back a little before the move.
	c.key(&"arm_l", 0.0, al * 0.3).key(&"arm_l", t_in, al, AnimClip.BACK).hold(&"arm_l", t_in, t_out, al).key(&"arm_l", l, al * 0.6)
	c.key(&"arm_r", 0.0, ar * 0.3).key(&"arm_r", t_in, ar, AnimClip.BACK).hold(&"arm_r", t_in, t_out, ar).key(&"arm_r", l, ar * 0.6)
	c.key(&"fore_l", 0.0, -0.3).key(&"fore_l", t_in, float(p.fl), AnimClip.EASE_OUT).hold(&"fore_l", t_in, l, float(p.fl))
	c.key(&"fore_r", 0.0, -0.3).key(&"fore_r", t_in, float(p.fr), AnimClip.EASE_OUT).hold(&"fore_r", t_in, l, float(p.fr))
	c.key(&"torso", 0.0, Vector3(-tx * 0.3, 0.0, 0.0)).key(&"torso", t_in, Vector3(tx, 0.0, 0.0), AnimClip.BACK) \
		.hold(&"torso", t_in, t_out, Vector3(tx, 0.0, 0.0)).key(&"torso", l, Vector3(tx * 0.5, 0.0, 0.0))
	var ry := float(p.get("ry", 0.0))
	var jump := float(p.get("jump", 0.0))
	c.key(&"lift", 0.0, -0.05 if jump > 0.0 else 0.0)
	if jump > 0.0:
		var mid := (t_in + t_out) * 0.5
		c.key(&"lift", t_in, ry + jump * 0.6, AnimClip.EASE_OUT)
		c.key(&"lift", mid, ry + jump, AnimClip.EASE_OUT)
		c.key(&"lift", t_out, ry + 0.05, AnimClip.EASE_IN)
	else:
		c.hold(&"lift", t_in, t_out, ry)
	c.key(&"lift", l, 0.0)
	if ry < -0.1:
		# Crouching and kneeling poses bend the legs too.
		var bend := clampf(-ry * 2.5, 0.0, 1.2)
		c.key(&"leg_l", 0.0, 0.0).key(&"leg_l", t_in, -bend * 0.8, AnimClip.EASE_OUT).hold(&"leg_l", t_in, t_out, -bend * 0.8).key(&"leg_l", l, 0.0)
		c.key(&"leg_r", 0.0, 0.0).key(&"leg_r", t_in, -bend * 0.2, AnimClip.EASE_OUT).hold(&"leg_r", t_in, t_out, -bend * 0.2).key(&"leg_r", l, 0.0)
		c.key(&"shin_l", 0.0, 0.0).key(&"shin_l", t_in, bend, AnimClip.EASE_OUT).hold(&"shin_l", t_in, t_out, bend).key(&"shin_l", l, 0.0)
		c.key(&"shin_r", 0.0, 0.0).key(&"shin_r", t_in, bend * 1.4, AnimClip.EASE_OUT).hold(&"shin_r", t_in, t_out, bend * 1.4).key(&"shin_r", l, 0.0)
	elif jump > 0.0:
		c.key(&"leg_l", 0.0, 0.2).key(&"leg_l", t_in, -0.6, AnimClip.EASE_OUT).key(&"leg_l", t_out, -0.2).key(&"leg_l", l, 0.0)
		c.key(&"leg_r", 0.0, 0.2).key(&"leg_r", t_in, 0.35, AnimClip.EASE_OUT).key(&"leg_r", t_out, 0.1).key(&"leg_r", l, 0.0)
		c.key(&"shin_l", 0.0, 0.4).key(&"shin_l", t_in, 0.9, AnimClip.EASE_OUT).key(&"shin_l", t_out, 0.3).key(&"shin_l", l, 0.05)
		c.key(&"shin_r", 0.0, 0.4).key(&"shin_r", t_in, 0.25, AnimClip.EASE_OUT).key(&"shin_r", l, 0.05)
	c.event(t_in, &"peak")
	return c


## The dodge roll: a short crouch, the body tucks into a ball while the model
## turns over (HumanoidModel.roll_angle), then it lands low and stands up.
static func dodge(duration: float) -> AnimClip:
	var c := AnimClip.new(&"dodge", maxf(duration, 0.2))
	var l := c.length
	c.fade_in = 0.03
	c.fade_out = 0.1
	var tuck := l * 0.22   # fully tucked just as the fast part of the turn starts
	var open := l * 0.66   # legs reach for the ground before the turn ends
	var land := l * 0.8    # feet down, knees bent
	for part in [&"leg_l", &"leg_r"]:
		c.key(part, 0.0, -0.5).key(part, tuck, -1.5, AnimClip.EASE_OUT).hold(part, tuck, open, -1.5) \
			.key(part, land, -0.7, AnimClip.EASE_OUT).key(part, l, -0.05, AnimClip.IN_OUT)
	for part in [&"shin_l", &"shin_r"]:
		c.key(part, 0.0, 0.7).key(part, tuck, 2.0, AnimClip.EASE_OUT).hold(part, tuck, open, 2.0) \
			.key(part, land, 1.2, AnimClip.EASE_OUT).key(part, l, 0.1, AnimClip.IN_OUT)
	# Arms reach forward, then hug the knees, then swing out for balance.
	c.key(&"arm_l", 0.0, Vector3(-1.1, 0.0, -0.25)).key(&"arm_l", tuck, Vector3(-1.5, 0.35, 0.0), AnimClip.EASE_OUT) \
		.hold(&"arm_l", tuck, open, Vector3(-1.5, 0.35, 0.0)).key(&"arm_l", land, Vector3(-0.9, 0.0, -0.45), AnimClip.EASE_OUT) \
		.key(&"arm_l", l, Vector3(-0.25, 0.0, -0.1), AnimClip.IN_OUT)
	c.key(&"arm_r", 0.0, Vector3(-1.1, 0.0, 0.25)).key(&"arm_r", tuck, Vector3(-1.5, -0.35, 0.0), AnimClip.EASE_OUT) \
		.hold(&"arm_r", tuck, open, Vector3(-1.5, -0.35, 0.0)).key(&"arm_r", land, Vector3(-0.9, 0.0, 0.45), AnimClip.EASE_OUT) \
		.key(&"arm_r", l, Vector3(-0.25, 0.0, 0.1), AnimClip.IN_OUT)
	for part in [&"fore_l", &"fore_r"]:
		c.key(part, 0.0, -0.6).key(part, tuck, -1.8, AnimClip.EASE_OUT).hold(part, tuck, open, -1.8) \
			.key(part, land, -0.7).key(part, l, -0.35, AnimClip.IN_OUT)
	# Chin to chest and a rounded back while turning; a little forward lean on landing.
	c.key(&"torso", 0.0, Vector3(0.35, 0.0, 0.0)).key(&"torso", tuck, Vector3(0.65, 0.0, 0.0), AnimClip.EASE_OUT) \
		.hold(&"torso", tuck, open, Vector3(0.65, 0.0, 0.0)).key(&"torso", land, Vector3(0.4, 0.0, 0.0), AnimClip.EASE_OUT) \
		.key(&"torso", l, Vector3(0.05, 0.0, 0.0), AnimClip.IN_OUT)
	c.key(&"head", 0.0, Vector3(0.25, 0.0, 0.0)).key(&"head", tuck, Vector3(0.55, 0.0, 0.0), AnimClip.EASE_OUT) \
		.hold(&"head", tuck, open, Vector3(0.55, 0.0, 0.0)).key(&"head", land, Vector3(-0.1, 0.0, 0.0)) \
		.key(&"head", l, Vector3.ZERO, AnimClip.IN_OUT)
	c.key(&"lift", 0.0, -0.18).key(&"lift", tuck, -0.04, AnimClip.EASE_OUT).hold(&"lift", tuck, open, -0.04) \
		.key(&"lift", land, -0.2, AnimClip.EASE_OUT).key(&"lift", l, 0.0, AnimClip.IN_OUT)
	return c


## Additive hit flinch (added on top of whatever the body does). `side`: -1 hit
## from the left, 1 from the right, 0 from the front.
static func flinch(strength: float, side: float = 0.0) -> AnimClip:
	var c := AnimClip.new(&"flinch", 0.38)
	var s := clampf(strength, 0.2, 1.5)
	c.key(&"torso", 0.0, Vector3.ZERO).key(&"torso", 0.07, Vector3(-0.45 * s, side * 0.25 * s, side * 0.2 * s), AnimClip.EASE_OUT) \
		.key(&"torso", 0.38, Vector3.ZERO, AnimClip.IN_OUT)
	c.key(&"head", 0.0, Vector3.ZERO).key(&"head", 0.06, Vector3(-0.3 * s, 0.0, 0.0), AnimClip.EASE_OUT).key(&"head", 0.38, Vector3.ZERO)
	c.key(&"step", 0.0, 0.0).key(&"step", 0.07, -0.12 * s, AnimClip.EASE_OUT).key(&"step", 0.38, 0.0)
	return c


## Additive jump push-off: a quick dip, then the legs push and the arms swing up.
static func jump() -> AnimClip:
	var c := AnimClip.new(&"jump", 0.3)
	c.key(&"lift", 0.0, -0.08).key(&"lift", 0.06, -0.1, AnimClip.EASE_OUT).key(&"lift", 0.3, 0.0, AnimClip.EASE_OUT)
	c.key(&"shin_l", 0.0, 0.4).key(&"shin_l", 0.08, -0.1, AnimClip.EASE_OUT).key(&"shin_l", 0.3, 0.0)
	c.key(&"shin_r", 0.0, 0.4).key(&"shin_r", 0.08, -0.1, AnimClip.EASE_OUT).key(&"shin_r", 0.3, 0.0)
	c.key(&"arm_l", 0.0, Vector3(0.3, 0, 0)).key(&"arm_l", 0.1, Vector3(-0.8, 0, -0.2), AnimClip.EASE_OUT).key(&"arm_l", 0.3, Vector3.ZERO)
	c.key(&"arm_r", 0.0, Vector3(0.3, 0, 0)).key(&"arm_r", 0.1, Vector3(-0.8, 0, 0.2), AnimClip.EASE_OUT).key(&"arm_r", 0.3, Vector3.ZERO)
	c.key(&"torso", 0.0, Vector3(0.15, 0, 0)).key(&"torso", 0.1, Vector3(-0.1, 0, 0), AnimClip.EASE_OUT).key(&"torso", 0.3, Vector3.ZERO)
	return c


## Additive landing squash on the knees (the root also squashes).
static func land(strength: float) -> AnimClip:
	var c := AnimClip.new(&"land", 0.32)
	var s := clampf(strength, 0.0, 1.0)
	c.key(&"lift", 0.0, 0.0).key(&"lift", 0.07, -0.12 * s, AnimClip.EASE_OUT).key(&"lift", 0.32, 0.0, AnimClip.IN_OUT)
	c.key(&"shin_l", 0.0, 0.0).key(&"shin_l", 0.07, 0.5 * s, AnimClip.EASE_OUT).key(&"shin_l", 0.32, 0.0)
	c.key(&"shin_r", 0.0, 0.0).key(&"shin_r", 0.07, 0.5 * s, AnimClip.EASE_OUT).key(&"shin_r", 0.32, 0.0)
	c.key(&"leg_l", 0.0, 0.0).key(&"leg_l", 0.07, -0.25 * s, AnimClip.EASE_OUT).key(&"leg_l", 0.32, 0.0)
	c.key(&"leg_r", 0.0, 0.0).key(&"leg_r", 0.07, -0.25 * s, AnimClip.EASE_OUT).key(&"leg_r", 0.32, 0.0)
	c.key(&"torso", 0.0, Vector3.ZERO).key(&"torso", 0.07, Vector3(0.2 * s, 0, 0), AnimClip.EASE_OUT).key(&"torso", 0.32, Vector3.ZERO)
	return c
