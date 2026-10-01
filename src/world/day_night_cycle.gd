class_name DayNightCycle
extends Node
## Drives the sun and moon, the sky, fog and ambient light, and the
## time-of-day temperature swing.
##
## Milestone 10: a sky shader (assets/shaders/sky.gdshader) with a real sun and
## moon arc, dawn/dusk colours, moon phases (8-day cycle), stars and drifting
## clouds. WeatherSystem feeds cloud cover, dimming, fog and lightning in
## through `weather_*` fields; world events tint the sky through `sky_tint`.

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
## Weather (Milestone 10, set by WeatherSystem every frame).
var weather_clouds := 0.3
var weather_dim := 0.0  # 0..1 of sunlight blocked
var weather_fog := 0.0  # 0..1: fog closes in
var weather_fog_color := Color(0.7, 0.72, 0.75)
var weather_flash := 0.0  # lightning 0..1
var weather_storm := 0.0  # dark clouds 0..1

const DAY_ZENITH := Color(0.22, 0.48, 0.95)
const DAY_HORIZON := Color(0.62, 0.8, 1.0)
const DUSK_ZENITH := Color(0.3, 0.3, 0.62)
const DUSK_HORIZON := Color(1.0, 0.58, 0.38)
const NIGHT_ZENITH := Color(0.02, 0.03, 0.09)
const NIGHT_HORIZON := Color(0.07, 0.09, 0.2)
const OVERCAST := Color(0.55, 0.58, 0.63)
## Surface fog (m): the horizon terrain (FarTerrain, ~520 m) fades out before its edge.
const FOG_BEGIN := 150.0
const FOG_END := 470.0
const SUN_DAY := Color(1.0, 0.96, 0.86)
const SUN_DUSK := Color(1.0, 0.62, 0.4)
const MOON := Color(0.55, 0.62, 1.0)
## Days per moon cycle.
const MOON_CYCLE := 8
## Lowest light elevation (degrees) so shadows never stretch to infinity.
const MIN_LIGHT_ELEVATION := 18.0

var _sky_mat: ShaderMaterial


func _ready() -> void:
	hour = start_hour
	_setup_sky()
	_apply()


func _setup_sky() -> void:
	if environment == null or environment.environment == null:
		return
	var shader := load("res://assets/shaders/sky.gdshader") as Shader
	if shader == null:
		return
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.environment.sky = sky


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


## 0 = new moon, 0.5 = full moon.
func moon_phase() -> float:
	return fposmod(float(day - 1) + hour / 24.0, MOON_CYCLE) / MOON_CYCLE


func moon_phase_name() -> String:
	var p := moon_phase()
	const NAMES := ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon",
		"Waning gibbous", "Last quarter", "Waning crescent"]
	return NAMES[int(round(p * 8.0)) % 8]


func time_string() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "Day %d  %02d:%02d" % [day, h, m]


## Direction towards the sun (rises in the east at 06:00, sets in the west at 18:00).
func sun_direction() -> Vector3:
	var angle := (hour - 6.0) / 24.0 * TAU
	return (Basis(Vector3.UP, deg_to_rad(30.0)) * Vector3(cos(angle), sin(angle), 0.35)).normalized()


## The moon rides opposite the sun.
func moon_direction() -> Vector3:
	var s := sun_direction()
	return Vector3(-s.x, -s.y, s.z).normalized()


func _apply() -> void:
	if underground:
		_apply_underground()
		return
	var daylight := get_daylight() * (1.0 - eclipse)
	var sdir := sun_direction()
	var sun_height := sdir.y
	var dusk := clampf(1.0 - absf(sun_height) * 3.0, 0.0, 1.0)
	var dim := clampf(weather_dim, 0.0, 0.85)
	if sun:
		sun.visible = true
		# Light from the sun by day, from the moon by night, never too flat.
		var ldir := sdir if sun_height > -0.05 else moon_direction()
		var flat := Vector2(ldir.x, ldir.z)
		var elev := maxf(asin(clampf(ldir.y, -1.0, 1.0)), deg_to_rad(MIN_LIGHT_ELEVATION))
		var l := Vector3(flat.normalized().x * cos(elev), sin(elev), flat.normalized().y * cos(elev)) if flat.length() > 0.001 else Vector3.UP
		sun.global_transform.basis = Basis.looking_at(-l, Vector3.UP if absf(l.y) < 0.99 else Vector3.FORWARD)
		var day_col := SUN_DAY.lerp(SUN_DUSK, dusk * dusk)
		var moon_light := 0.12 + 0.14 * (1.0 - absf(moon_phase() - 0.5) * 2.0)
		sun.light_color = MOON.lerp(day_col, daylight)
		sun.light_energy = lerpf(moon_light, 1.2, daylight) * (1.0 - dim) + weather_flash * 1.5
		sun.shadow_opacity = 1.0 - dim * 0.7
		if sky_tint.a > 0.0:
			sun.light_color = sun.light_color.lerp(Color(sky_tint.r, sky_tint.g, sky_tint.b), sky_tint.a * 0.6)
	if environment and environment.environment:
		var env := environment.environment
		var zen := NIGHT_ZENITH.lerp(DAY_ZENITH, daylight).lerp(DUSK_ZENITH, dusk * 0.5 * daylight)
		var hor := NIGHT_HORIZON.lerp(DAY_HORIZON, daylight).lerp(DUSK_HORIZON, dusk * 0.6)
		# Overcast skies wash out towards grey (darker at night).
		var grey := OVERCAST * lerpf(0.18, 1.0, daylight)
		zen = zen.lerp(grey * 0.9, dim)
		hor = hor.lerp(grey, dim)
		if sky_tint.a > 0.0:
			var tint := Color(sky_tint.r, sky_tint.g, sky_tint.b)
			zen = zen.lerp(tint * 0.7, sky_tint.a)
			hor = hor.lerp(tint, sky_tint.a)
		env.background_mode = Environment.BG_SKY if _sky_mat else Environment.BG_COLOR
		env.background_color = hor
		if _sky_mat:
			_sky_mat.set_shader_parameter(&"zenith_color", zen)
			_sky_mat.set_shader_parameter(&"horizon_color", hor)
			_sky_mat.set_shader_parameter(&"ground_color", hor * 0.6)
			_sky_mat.set_shader_parameter(&"sun_dir", sdir)
			_sky_mat.set_shader_parameter(&"sun_color", SUN_DAY.lerp(SUN_DUSK, dusk))
			_sky_mat.set_shader_parameter(&"moon_dir", moon_direction())
			_sky_mat.set_shader_parameter(&"moon_phase", moon_phase())
			_sky_mat.set_shader_parameter(&"night", 1.0 - get_daylight())
			_sky_mat.set_shader_parameter(&"cloud_cover", clampf(weather_clouds, 0.0, 1.0))
			_sky_mat.set_shader_parameter(&"cloud_color", Color(1, 1, 1).lerp(hor, 0.35) * lerpf(0.25, 1.0, daylight))
			_sky_mat.set_shader_parameter(&"storm", weather_storm)
			_sky_mat.set_shader_parameter(&"flash", weather_flash)
		var fog_col := hor.lerp(Color.WHITE, 0.15)
		fog_col = fog_col.lerp(weather_fog_color * lerpf(0.25, 1.0, daylight), clampf(weather_fog, 0.0, 1.0) * 0.8)
		env.fog_light_color = fog_col
		env.ambient_light_color = Color(0.4, 0.45, 0.8).lerp(Color(0.85, 0.88, 1.0), daylight)
		if sky_tint.a > 0.0:
			env.ambient_light_color = env.ambient_light_color.lerp(Color(sky_tint.r, sky_tint.g, sky_tint.b), sky_tint.a * 0.5)
		env.ambient_light_energy = lerpf(0.28, 0.55, daylight) * (1.0 - dim * 0.45) + weather_flash * 0.6
		# Overcast: duller, darker colours.
		env.adjustment_saturation = 1.05 - dim * 0.4
		env.adjustment_brightness = 1.0 - dim * 0.22 + weather_flash * 0.3
		var f := clampf(weather_fog, 0.0, 1.0)
		env.fog_depth_begin = lerpf(FOG_BEGIN, 0.0, sqrt(f))
		env.fog_depth_end = lerpf(FOG_END, 48.0, sqrt(f))
		env.fog_depth_curve = lerpf(1.4, 0.75, f)


func _apply_underground() -> void:
	if sun:
		sun.visible = false
	if environment and environment.environment:
		var env := environment.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.01, 0.01, 0.02)
		env.fog_light_color = Color(0.02, 0.02, 0.04)
		env.fog_depth_curve = 1.4
		env.adjustment_saturation = 1.05
		env.adjustment_brightness = 1.0
		env.fog_depth_begin = 16.0
		env.fog_depth_end = 55.0
		env.ambient_light_color = Color(0.5, 0.5, 0.7)
		env.ambient_light_energy = 0.55
