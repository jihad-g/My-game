class_name WeatherSystem
extends Node3D
## Weather (Milestone 10): clear, cloudy, rain, storms with lightning and
## thunder, snow, fog and sandstorms.
##
## Weather comes in spells of SPELL_SECONDS of world time. Each spell rolls a
## front (seeded by world seed + spell number, so it is the same after loading)
## and the local climate decides what it means: rain falls as snow in the cold,
## dry hot lands get sandstorms instead, wet lands get more rain and fog. Values
## ease towards the target, so weather builds up and clears over ~half a minute.
##
## Effects: precipitation particles around the camera (they stop on roofs and
## terrain via a heightfield collider), sky cover, dimmer sun, closer fog,
## lightning flashes with delayed thunder, wind on foliage and water, ambience
## loops, colder air when wet, and the Wet status when you stand in the rain.

signal weather_changed(kind: StringName)

enum Kind { CLEAR, CLOUDY, RAIN, STORM, SNOW, FOG, SANDSTORM }
const KIND_IDS := [&"clear", &"cloudy", &"rain", &"storm", &"snow", &"fog", &"sandstorm"]
const KIND_NAMES := ["Clear", "Cloudy", "Rain", "Thunderstorm", "Snow", "Fog", "Sandstorm"]
## World seconds per weather spell (a quarter of a default 20-minute day).
const SPELL_SECONDS := 300.0
## How fast weather values move towards their target (per second).
const EASE := 1.0 / 25.0
## Air temperature change per kind at full strength (°C). Never lethal: the
## temperature system only applies debuffs.
const CHILL := {Kind.RAIN: -3.0, Kind.STORM: -5.0, Kind.SNOW: -4.0, Kind.FOG: -1.5, Kind.SANDSTORM: 2.0, Kind.CLOUDY: -1.0}

var world: World
## Current kind and how strongly it is happening (0..1).
var kind: int = Kind.CLEAR
var intensity := 0.0
var clouds := 0.25
var wind := 0.3
var fog := 0.0
## Precipitation particles visible (Settings).
var particles_enabled := true
## Forced weather (debug key / tests): -1 = natural.
var forced_kind := -1
var forced_intensity := 1.0
var lightning_strikes := 0

var _target := {"kind": Kind.CLEAR, "intensity": 0.0, "clouds": 0.25, "wind": 0.3, "fog": 0.0}
var _retarget_t := 0.0
var _flash := 0.0
var _next_strike := 8.0
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _sand: GPUParticles3D
var _collider: GPUParticlesCollisionHeightField3D
var _wet_t := 0.0
var _wind_dir := Vector2(1.0, 0.3).normalized()


func _ready() -> void:
	Materials.ensure_globals()
	_rain = _make_particles(3000, Vector3(0.025, 0.7, 0.025), Color(0.75, 0.82, 0.95, 0.55), Vector3(0, -26, 0), 1.3)
	_snow = _make_particles(1800, Vector3(0.09, 0.09, 0.09), Color(1, 1, 1, 0.9), Vector3(0, -2.2, 0), 9.0)
	(_snow.process_material as ParticleProcessMaterial).turbulence_enabled = true
	(_snow.process_material as ParticleProcessMaterial).turbulence_noise_strength = 1.5
	_sand = _make_particles(2600, Vector3(0.2, 0.08, 0.2), Color(0.62, 0.42, 0.22, 0.7), Vector3(9, -0.3, 3), 4.0)
	(_sand.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(30, 4, 30)
	(_sand.process_material as ParticleProcessMaterial).turbulence_enabled = true
	_collider = GPUParticlesCollisionHeightField3D.new()
	_collider.size = Vector3(70, 60, 70)
	_collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_collider.follow_camera_enabled = true
	add_child(_collider)
	_retarget(true)


func _make_particles(amount: int, size: Vector3, color: Color, gravity: Vector3, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 1, 30)
	pm.gravity = gravity
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 1.0
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.material = mat
	p.draw_pass_1 = mesh
	add_child(p)
	return p


# --- Public ------------------------------------------------------------------------------

func kind_id() -> StringName:
	return KIND_IDS[kind]


func kind_name() -> String:
	return KIND_NAMES[kind] if intensity > 0.15 or kind == Kind.CLEAR or kind == Kind.CLOUDY else "Clearing"


## True while rain or snow is falling noticeably.
func is_precipitating() -> bool:
	return kind in [Kind.RAIN, Kind.STORM, Kind.SNOW] and intensity > 0.2


## Air temperature change from the weather right now (°C).
func temperature_offset() -> float:
	return float(CHILL.get(kind, 0.0)) * intensity


## Forces a weather kind (debug F2, tests). -1 returns to natural weather.
func force(p_kind: int, p_intensity: float = 1.0) -> void:
	forced_kind = p_kind
	forced_intensity = p_intensity
	_retarget(true)


## Jumps straight to the target (no easing): tests and screenshots.
func settle() -> void:
	kind = _target.kind
	intensity = _target.intensity
	clouds = _target.clouds
	wind = _target.wind
	fog = _target.fog
	_apply()


## Natural weather for a moment and place (pure: same inputs, same weather).
func roll(time: float, climate_t: float, climate_m: float, biome_id: StringName) -> Dictionary:
	var spell := floori(time / SPELL_SECONDS)
	var h := HashUtils.hash3(GameState.world_seed, spell, 0x7e47)
	var r := HashUtils.to_unit(h, 0)
	var strength := 0.45 + HashUtils.to_unit(h, 1) * 0.55
	var wet := climate_m
	var k: int = Kind.CLEAR
	var p_precip := 0.12 + wet * 0.38
	if r < p_precip:
		k = Kind.STORM if HashUtils.to_unit(h, 2) < 0.25 + wet * 0.2 else Kind.RAIN
	elif r < p_precip + 0.22:
		k = Kind.CLOUDY
	elif r < p_precip + 0.22 + 0.06 + wet * 0.08:
		k = Kind.FOG
	# The climate decides what falls.
	var cold := climate_t < 0.3 or biome_id in [&"snowy_tundra", &"frostpine_taiga"]
	var desert := biome_id == &"sunscorch_desert" or (climate_t > 0.68 and climate_m < 0.25)
	if (k == Kind.RAIN or k == Kind.STORM) and cold:
		k = Kind.SNOW
	elif (k == Kind.RAIN or k == Kind.STORM) and desert:
		k = Kind.SANDSTORM if HashUtils.to_unit(h, 3) < 0.6 else Kind.CLOUDY
	elif k == Kind.FOG and desert:
		k = Kind.CLEAR
	var out := {"kind": k, "intensity": strength if k != Kind.CLEAR else 0.0, "clouds": 0.2, "wind": 0.25, "fog": 0.0}
	match k:
		Kind.CLOUDY:
			out.clouds = 0.6 + strength * 0.25
			out.wind = 0.4
			out.intensity = strength * 0.5
		Kind.RAIN:
			out.clouds = 0.85
			out.wind = 0.5 + strength * 0.3
			out.fog = 0.15 * strength
		Kind.STORM:
			out.clouds = 1.0
			out.wind = 1.0 + strength * 0.5
			out.fog = 0.25 * strength
		Kind.SNOW:
			out.clouds = 0.85
			out.wind = 0.35 + strength * 0.4
			out.fog = 0.3 * strength
		Kind.FOG:
			out.clouds = 0.5
			out.wind = 0.1
			out.fog = 0.55 + strength * 0.35
		Kind.SANDSTORM:
			out.clouds = 0.35
			out.wind = 1.3 + strength * 0.5
			out.fog = 0.45 + strength * 0.35
		_:
			out.clouds = 0.1 + HashUtils.to_unit(h, 4) * 0.35
	return out


# --- Update ---------------------------------------------------------------------------------

func _retarget(snap: bool = false) -> void:
	var t := {"kind": Kind.CLEAR, "intensity": 0.0, "clouds": 0.2, "wind": 0.3, "fog": 0.0}
	if world and world.player and world.generator:
		var p := world.player.global_position
		var biome := world.current_biome.id if world.current_biome else &""
		t = roll(GameState.world_time, world.generator.temperature01(p.x, p.z), world.generator.moisture01(p.x, p.z), biome)
	if forced_kind >= 0:
		t = roll(0.0, 0.5, 0.5, &"")
		t.kind = forced_kind
		var base := {Kind.CLEAR: [0.1, 0.25, 0.0], Kind.CLOUDY: [0.8, 0.45, 0.0], Kind.RAIN: [0.9, 0.7, 0.15],
			Kind.STORM: [1.0, 1.4, 0.25], Kind.SNOW: [0.9, 0.6, 0.3], Kind.FOG: [0.5, 0.1, 0.85], Kind.SANDSTORM: [0.35, 1.7, 0.75]}
		var b: Array = base[forced_kind]
		t.intensity = forced_intensity if forced_kind != Kind.CLEAR else 0.0
		t.clouds = b[0]
		t.wind = b[1]
		t.fog = b[2] * forced_intensity
	_target = t
	if snap:
		settle()


func _process(delta: float) -> void:
	if world == null or not world.is_ready:
		return
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = 1.0
		_retarget()
	var outdoor := world.layer == TerrainGenerator.Layer.SURFACE and world.dungeon == null
	# A different kind first fades out the current one.
	var target_kind: int = _target.kind
	var target_int: float = _target.intensity
	if target_kind != kind:
		target_int = 0.0
		if intensity <= 0.05:
			kind = target_kind
			weather_changed.emit(kind_id())
	var step := delta * EASE
	intensity = move_toward(intensity, target_int, step)
	clouds = move_toward(clouds, _target.clouds, step)
	wind = move_toward(wind, _target.wind, step * 2.0)
	fog = move_toward(fog, _target.fog if target_kind == kind else 0.0, step)
	_update_lightning(delta, outdoor)
	_apply(outdoor)
	_update_gameplay(delta, outdoor)


func _update_lightning(delta: float, outdoor: bool) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	if kind != Kind.STORM or intensity < 0.4 or not outdoor:
		return
	_next_strike -= delta
	if _next_strike > 0.0:
		return
	_next_strike = randf_range(5.0, 16.0) / intensity
	strike()


## A lightning strike somewhere around the player: flash, a bolt in the
## distance, thunder after the light (sound travels slower).
func strike() -> void:
	lightning_strikes += 1
	# Reduced flashing (accessibility): a soft glow instead of a white-out.
	_flash = 0.15 if Settings.reduce_flashing() else 1.0
	var p := world.player.global_position if world and world.player else global_position
	var a := randf() * TAU
	var dist := randf_range(60.0, 220.0)
	var ground := p + Vector3(cos(a) * dist, 0, sin(a) * dist)
	if world and world.generator:
		ground.y = world.generator.get_height_at(ground)
	var pts := PackedVector3Array()
	var top := ground + Vector3(randf_range(-10, 10), 90, randf_range(-10, 10))
	for k in 8:
		pts.append(top.lerp(ground, k / 7.0) + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)) * (1.0 if k in [1, 2, 3, 4, 5, 6] else 0.0))
	VFX.bolt(get_parent(), pts, Color(0.9, 0.92, 1.0, 1.0), 0.25)
	var delay := dist / 340.0
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		Audio.play(&"thunder", lerpf(0.0, -10.0, dist / 220.0), 0.1))


func _apply(outdoor: bool = true) -> void:
	var rain := intensity if kind in [Kind.RAIN, Kind.STORM] else 0.0
	var snow := intensity if kind == Kind.SNOW else 0.0
	var sand := intensity if kind == Kind.SANDSTORM else 0.0
	if not outdoor:
		rain = 0.0
		snow = 0.0
		sand = 0.0
	var vis := particles_enabled and outdoor
	_set_emitter(_rain, rain, vis)
	_set_emitter(_snow, snow, vis)
	_set_emitter(_sand, sand, vis)
	# Wind slowly turns; sandstorms blow hard.
	_wind_dir = _wind_dir.rotated(0.02 * get_process_delta_time()).normalized()
	RenderingServer.global_shader_parameter_set(&"wind_strength", wind if outdoor else 0.1)
	RenderingServer.global_shader_parameter_set(&"wind_dir", _wind_dir)
	RenderingServer.global_shader_parameter_set(&"rain_amount", rain)
	if world and world.day_night:
		var dn := world.day_night
		dn.weather_clouds = clouds
		dn.weather_dim = clampf((clouds - 0.5) * 1.1, 0.0, 0.7) * (1.0 if kind != Kind.CLEAR else 0.4) + (0.15 if kind == Kind.STORM else 0.0) * intensity
		dn.weather_fog = fog
		dn.weather_fog_color = Color(0.86, 0.7, 0.48) if kind == Kind.SANDSTORM else Color(0.72, 0.74, 0.78)
		dn.weather_flash = _flash * 0.9
		dn.weather_storm = intensity if kind == Kind.STORM else (intensity * 0.4 if kind == Kind.RAIN else 0.0)
	# Follow the camera's focus.
	var focus: Vector3 = world.camera_rig.global_position if world and world.camera_rig else global_position
	for e in [_rain, _snow, _sand]:
		e.global_position = focus + Vector3(0, 22 if e != _sand else 2.5, 0)
	_collider.global_position = focus
	# Ambience.
	if outdoor:
		Audio.set_ambience(&"rain", rain * (1.0 - clampf((intensity - 0.75) * 4.0, 0.0, 1.0) * float(kind == Kind.STORM)))
		Audio.set_ambience(&"rain_heavy", rain * float(kind == Kind.STORM))
		Audio.set_ambience(&"wind_strong", clampf(wind - 0.9, 0.0, 1.0))
	else:
		for l in [&"rain", &"rain_heavy", &"wind_strong"]:
			Audio.set_ambience(l, 0.0)


func _set_emitter(p: GPUParticles3D, amount: float, visible_ok: bool) -> void:
	var on := visible_ok and amount > 0.01
	p.amount_ratio = clampf(amount, 0.0, 1.0)
	if on != p.emitting:
		p.emitting = on
	p.visible = on


func _update_gameplay(delta: float, outdoor: bool) -> void:
	if not outdoor or world.player == null or world.player.is_dead:
		return
	_wet_t -= delta
	if _wet_t > 0.0:
		return
	_wet_t = 1.0
	if kind in [Kind.RAIN, Kind.STORM] and intensity > 0.3:
		var p := world.player.global_position
		if not (world.building and world.building.is_sheltered(p)):
			world.player.refresh_status(&"wet", 4.0)
