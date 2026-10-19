class_name CombatFeel
extends RefCounted
## Milestone 38: the combat feel measured frame by frame from the reference clip
## (an isometric dungeon crawler, recorded at 30 fps). Every number the new swing
## shapes, hit feel, damage numbers and blasts use lives here.
##
## Times are in frames at 30 fps; sec() turns them into seconds.
## "measured" = counted on the clip. "pick" = hidden by effects in the clip, so chosen
## to match the rest.

const FPS := 30.0

# --- Swings (measured) ---------------------------------------------------------------
## Light swing: wind-up 2, strike 2, follow-through 3, settle 1 (an 8 frame cadence).
## Heavy swing: hold 5 (measured 4-6), slam 3, follow-through 5, settle 3.
## Shardlands keeps each weapon's own wind-up / active / recovery times (so the
## balance and the combo speed stay the same); these numbers shape the motion inside them.
const STRIKE_FRAMES := 2.0
const HEAVY_STRIKE_FRAMES := 3.0
## A wind-up this long (seconds) or longer is a heavy swing: it reaches the ready pose
## early and hangs there (the measured "hold") before the slam.
const HEAVY_WINDUP := 0.3
## How far past the strike pose the swing carries (the follow-through).
const OVERSHOOT := 0.16
const HEAVY_OVERSHOOT := 0.22
## The small pull back past the ready pose just before the strike (anticipation).
const ANTICIPATION := 0.07

# --- Hit feel (measured unless marked) ----------------------------------------------------
## Hit-stop on heavy hits: 3 frames (the clip shows one 3-5 frame freeze).
const HITSTOP_HEAVY_FRAMES := 3.0
## Light hits: 1 frame (pick, keeps the light chain snappy).
const HITSTOP_LIGHT_FRAMES := 1.0
## The light pop where a hit lands: on at once, 1 frame, fade over 2.
const POP_UP := 0.0
const POP_HOLD := 1.0
const POP_DOWN := 2.0
## Enemy body flash: white 2 frames, then fades over 2 (pick).
const ENEMY_FLASH_FRAMES := 2.0
const ENEMY_FLASH_FADE := 2.0
## Hero hurt flash: 1 warm frame, 4 white frames, 1 fade (measured).
const HURT_WARM := Color("f7e7d0")
const HURT_WARM_HALO := Color("ff5a3a")
const HURT_WHITE := Color("e9f6f9")
const HURT_WHITE_HALO := Color("b49cff")
const HURT_FRAMES := [1.0, 4.0, 1.0]
## Death: tip over 8 frames, poof at frame 12 (pick), the body is gone right after.
const DEATH_POOF_FRAMES := 12.0

# --- Damage numbers (measured) ---------------------------------------------------------
## Pop out sideways 4 frames (ease-out, about 0.6-0.85 m), shrink 115% -> 100%
## over 8, hold 16, fade 5 (33 frames = 1.1 s). Red for heavy hits, white for normal.
const NUM_POP := 4.0
const NUM_SHRINK := 8.0
const NUM_HOLD := 16.0
const NUM_FADE := 5.0
const NUM_SIDE := Vector2(0.6, 0.85)
const NUM_RED := Color("d43426")
const NUM_WHITE := Color(1, 1, 1)

# --- Blasts (measured) ------------------------------------------------------------------
## Whole-screen brightness jumps: fire +40% (0 up, 10 hold, 5 down), fire pillar +27%,
## magic +24% (5 up, 6 down).
const FLASH_FIRE := 0.40
const FLASH_PILLAR := 0.27
const FLASH_MAGIC := 0.24


static func sec(frames: float) -> float:
	return frames / FPS


static func is_heavy_windup(windup: float) -> bool:
	return windup >= HEAVY_WINDUP


static func ease_out_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func ease_out_quad(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func ease_in_out_quad(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 2.0 * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0


static func ease_out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# --- Body flashes -----------------------------------------------------------------------
## Enemy hit flash (white, then fades) and hero hurt flash (warm, white, fade).
enum Flash { HIT, HURT }


## How long a flash lasts (seconds).
static func flash_length(kind: int) -> float:
	if kind == Flash.HURT:
		return sec(HURT_FRAMES[0] + HURT_FRAMES[1] + HURT_FRAMES[2])
	return sec(ENEMY_FLASH_FRAMES + ENEMY_FLASH_FADE)


## The flash `t` seconds after it started: [body colour (alpha = strength), halo colour].
## An empty array when it is over.
static func flash_at(kind: int, t: float) -> Array:
	var f := t * FPS
	if t < 0.0 or t >= flash_length(kind):
		return []
	if kind == Flash.HURT:
		var a: float = HURT_FRAMES[0]
		var b: float = a + HURT_FRAMES[1]
		if f < a:
			return [Color(HURT_WARM, 0.85), Color(HURT_WARM_HALO, 0.75)]
		if f < b:
			return [Color(HURT_WHITE, 0.75), Color(HURT_WHITE_HALO, 0.6)]
		var k := 1.0 - (f - b) / float(HURT_FRAMES[2])
		return [Color(HURT_WHITE, 0.75 * k), Color(HURT_WHITE_HALO, 0.6 * k)]
	var s := 1.0 if f < ENEMY_FLASH_FRAMES else 1.0 - (f - ENEMY_FLASH_FRAMES) / ENEMY_FLASH_FADE
	return [Color(1, 1, 1, 0.8 * s), Color(1, 1, 1, 0.0)]


## A body flash material with a halo (an outline drawn a little bigger behind the body).
static func make_flash_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.8)
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.cull_mode = BaseMaterial3D.CULL_FRONT
	halo.grow = true
	halo.grow_amount = 0.05
	halo.albedo_color = Color(1, 1, 1, 0.0)
	m.next_pass = halo
	return m


## Sets a flash material to the flash at `t`. False when the flash is over.
static func update_flash_material(m: StandardMaterial3D, kind: int, t: float) -> bool:
	var st := flash_at(kind, t)
	if st.is_empty():
		return false
	m.albedo_color = st[0]
	(m.next_pass as StandardMaterial3D).albedo_color = st[1]
	return true
