class_name AnimClip
extends RefCounted
## A short body animation for HumanoidModel (Milestone 18a, "compact animation system").
##
## A clip is a set of keyframe tracks, one per body part. Each key is
## [time, value, ease]; the ease shapes the move INTO that key. Values:
##   Vector3 rotations: arm_l, arm_r, torso, head, weapon, shield
##   float x-rotations: fore_l, fore_r, leg_l, leg_r, shin_l, shin_r
##   float offsets:     lift (body up/down), step (body forward/back)
## HumanoidModel mixes clips on three layers (base locomotion, action, additive)
## with cross-fades, so nothing snaps. Events ([time, name]) fire once when the
## clip passes their time (weapon trails, the hit frame).

const VEC_PARTS: Array[StringName] = [&"arm_l", &"arm_r", &"torso", &"head", &"weapon", &"shield"]
const FLOAT_PARTS: Array[StringName] = [&"fore_l", &"fore_r", &"leg_l", &"leg_r", &"shin_l", &"shin_r", &"lift", &"step"]
const LEG_PARTS: Array[StringName] = [&"leg_l", &"leg_r", &"shin_l", &"shin_r", &"lift", &"step"]

## Ease of the move into a key.
const LINEAR := &"linear"
const EASE_IN := &"in"
const EASE_OUT := &"out"
const IN_OUT := &"inout"
## Overshoots a little and settles (snappy strikes and poses).
const BACK := &"back"

var name: StringName = &""
var length := 0.5
var loop := false
## part -> Array of [time, value, ease]
var tracks: Dictionary = {}
## [time, StringName]
var events: Array = []
## Seconds to blend in from whatever the body was doing, and back out at the end.
var fade_in := 0.08
var fade_out := 0.12
## Held swings (charged heavy, bow draw) stop at this time until released (-1 = never).
var hold_at := -1.0
## Legs belong to the clip only while standing; while running the legs keep running.
var legs_when_moving := false
## A small tremble of power on the arms (spells, channels).
var shake := 0.0


func _init(p_name: StringName = &"", p_length: float = 0.5) -> void:
	name = p_name
	length = maxf(p_length, 0.01)


## Adds a key. Keys may be added in any order; they are kept sorted by time.
func key(part: StringName, time: float, value: Variant, ease: StringName = IN_OUT) -> AnimClip:
	var list: Array = tracks.get(part, [])
	list.append([clampf(time, 0.0, length), value, ease])
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	tracks[part] = list
	return self


## The same value for a part from `t0` to `t1` (a hold).
func hold(part: StringName, t0: float, t1: float, value: Variant, ease: StringName = IN_OUT) -> AnimClip:
	key(part, t0, value, ease)
	key(part, t1, value, LINEAR)
	return self


func event(time: float, ev: StringName) -> AnimClip:
	events.append([clampf(time, 0.0, length), ev])
	events.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return self


func has_part(part: StringName) -> bool:
	return tracks.has(part)


func parts() -> Array:
	return tracks.keys()


## The value of `part` at time `t` (null if the clip doesn't move that part).
func sample(part: StringName, t: float) -> Variant:
	var list: Array = tracks.get(part, [])
	if list.is_empty():
		return null
	if loop and length > 0.0:
		t = fposmod(t, length)
	if t <= float(list[0][0]):
		return list[0][1]
	for i in range(1, list.size()):
		var k1: Array = list[i]
		if t <= float(k1[0]):
			var k0: Array = list[i - 1]
			var span := float(k1[0]) - float(k0[0])
			var f := 1.0 if span <= 0.0 else (t - float(k0[0])) / span
			return blend(k0[1], k1[1], apply_ease(f, k1[2]))
	return list[list.size() - 1][1]


## Events between `t0` (excluded) and `t1` (included).
func events_between(t0: float, t1: float) -> Array:
	var out: Array = []
	for e in events:
		var et := float(e[0])
		if et > t0 and et <= t1:
			out.append(e[1])
	return out


static func apply_ease(f: float, ease: StringName) -> float:
	f = clampf(f, 0.0, 1.0)
	match ease:
		EASE_IN:
			return f * f * f
		EASE_OUT:
			return 1.0 - pow(1.0 - f, 3.0)
		IN_OUT:
			return f * f * (3.0 - 2.0 * f)
		BACK:
			# Overshoot by ~10% and settle.
			var c := 1.70158
			var g := f - 1.0
			return 1.0 + (c + 1.0) * g * g * g + c * g * g
	return f


## Lerps two values of the same kind (Vector3 or float).
static func blend(a: Variant, b: Variant, f: float) -> Variant:
	if a is Vector3:
		return (a as Vector3).lerp(b as Vector3, f)
	return lerpf(float(a), float(b), f)


static func add(a: Variant, b: Variant) -> Variant:
	if a is Vector3:
		return (a as Vector3) + (b as Vector3)
	return float(a) + float(b)


static func zero_of(part: StringName) -> Variant:
	return Vector3.ZERO if part in VEC_PARTS else 0.0
