class_name DayNightCycle
extends Node
## Drives the sun, sky colours and the time-of-day temperature swing.

signal hour_changed(hour: int)

## Real seconds per in-game day.
@export var day_length: float = 1200.0
@export var start_hour: float = 8.0
@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment

## Underground there is no sun or sky: dark ambient, black fog.
var underground: bool = false
## 0..24
var hour: float = 8.0
var day: int = 1
var _last_hour := -1
## World events (Milestone 7): sky colour override (alpha = strength) and
## eclipse darkness (0..1 of daylight removed).
var sky_tint := Color(0, 0, 0, 0)
var eclipse := 0.0

const SKY_DAY := Color(0.45, 0.72, 1.0)
const SKY_DUSK := Color(0.95, 0.55, 0.4)
const SKY_NIGHT := Color(0.08, 0.1, 0.25)
const SUN_DAY := Color(1.0, 0.96, 0.86)
const SUN_DUSK := Color(1.0, 0.62, 0.4)
const MOON := Color(0.55, 0.62, 1.0)


func _ready() -> void:
	hour = start_hour
	_apply()


func _process(delta: float) -> void:
	advance_hours(delta / day_length * 24.0)


func advance_hours(h: float) -> void:
	hour += h
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	_apply()
	var ih := int(hour)
	if ih != _last_hour:
		_last_hour = ih
		hour_changed.emit(ih)


## -1 at the coldest point (~03:00), +1 at the warmest (~15:00).
func get_temperature_factor() -> float:
	return -cos((hour - 3.0) / 24.0 * TAU)


## 0 = full night, 1 = full day.
func get_daylight() -> float:
	return smoothstep(-0.15, 0.25, sin((hour - 6.0) / 24.0 * TAU))


func is_night() -> bool:
	return get_daylight() < 0.3


func time_string() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "Day %d  %02d:%02d" % [day, h, m]


func _apply() -> void:
	if underground:
		_apply_underground()
		return
	if sun:
		sun.visible = true
	var daylight := get_daylight() * (1.0 - eclipse)
	var sun_height := sin((hour - 6.0) / 24.0 * TAU)
	if sun:
		# Sun travels east -> west; at night the "moon" light comes from the opposite side.
		var angle := (hour - 6.0) / 24.0 * TAU
		var elevation := maxf(absf(sin(angle)), 0.25) * 70.0
		var azimuth := rad_to_deg(angle) + (180.0 if sun_height < 0.0 else 0.0)
		sun.rotation_degrees = Vector3(-elevation, azimuth + 30.0, 0.0)
		var dusk := 1.0 - absf(sun_height)
		var day_col := SUN_DAY.lerp(SUN_DUSK, clampf(dusk * dusk, 0.0, 1.0))
		sun.light_color = MOON.lerp(day_col, daylight)
		sun.light_energy = lerpf(0.22, 1.2, daylight)
		if sky_tint.a > 0.0:
			sun.light_color = sun.light_color.lerp(Color(sky_tint.r, sky_tint.g, sky_tint.b), sky_tint.a * 0.6)
	if environment and environment.environment:
		var env := environment.environment
		var dusk_amount := clampf(1.0 - absf(sun_height) * 3.0, 0.0, 1.0)
		var sky := SKY_NIGHT.lerp(SKY_DAY, daylight).lerp(SKY_DUSK, dusk_amount * 0.45)
		if sky_tint.a > 0.0:
			sky = sky.lerp(Color(sky_tint.r, sky_tint.g, sky_tint.b), sky_tint.a)
		env.background_color = sky
		env.fog_light_color = sky.lerp(Color.WHITE, 0.15)
		env.ambient_light_color = Color(0.4, 0.45, 0.8).lerp(Color(0.85, 0.88, 1.0), daylight)
		if sky_tint.a > 0.0:
			env.ambient_light_color = env.ambient_light_color.lerp(Color(sky_tint.r, sky_tint.g, sky_tint.b), sky_tint.a * 0.5)
		env.ambient_light_energy = lerpf(0.28, 0.55, daylight)
		env.fog_depth_begin = 70.0
		env.fog_depth_end = 160.0


func _apply_underground() -> void:
	if sun:
		sun.visible = false
	if environment and environment.environment:
		var env := environment.environment
		env.background_color = Color(0.01, 0.01, 0.02)
		env.fog_light_color = Color(0.02, 0.02, 0.04)
		env.fog_depth_begin = 16.0
		env.fog_depth_end = 55.0
		env.ambient_light_color = Color(0.5, 0.5, 0.7)
		env.ambient_light_energy = 0.55
