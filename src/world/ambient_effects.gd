class_name AmbientEffects
extends Node3D
## Environmental effects and the soundscape (Milestone 10).
##
## Particles around the camera that belong to the place and time: fireflies on
## warm nights, falling leaves in forests, pollen over meadows, desert dust,
## crystal sparkles, swamp mist, drifting snow on the tundra and dust motes in
## caves. Each emitter fades in/out with its conditions.
##
## Every second it also picks the music (Audio.pick_music: menu/day/night/town/
## combat/dungeon/boss) and sets the ambience beds (wind, birds, crickets, sea,
## cave, town) from biome, time, layer and what is happening.

const LEAFY := [&"whispering_forest", &"frostpine_taiga", &"emerald_jungle", &"murk_swamp"]
const FIREFLY := [&"verdant_meadow", &"whispering_forest", &"emerald_jungle", &"murk_swamp", &"crystal_glade"]
const BIRDS := [&"verdant_meadow", &"whispering_forest", &"emerald_jungle", &"frostpine_taiga", &"crystal_glade", &"sandy_beach"]
const COMBAT_RANGE := 20.0

var world: World
var particles_enabled := true
## Name -> {"p": GPUParticles3D, "level": float}
var emitters: Dictionary = {}
var _boss: Node
var _tick := 0.0
var in_combat := false


func _ready() -> void:
	_add(&"fireflies", 70, Vector3(0.07, 0.07, 0.07), Color(0.85, 1.0, 0.35), true, Vector3(26, 3, 26), Vector3(0, 0.05, 0), 6.0, 1.2, 1.0)
	_add(&"leaves", 60, Vector3(0.14, 0.03, 0.12), Color(0.85, 0.55, 0.2), false, Vector3(30, 1, 30), Vector3(0.3, -0.7, 0.1), 12.0, 0.8, 11.0)
	_add(&"pollen", 50, Vector3(0.05, 0.05, 0.05), Color(1.0, 0.95, 0.7), true, Vector3(24, 3, 24), Vector3(0.1, 0.02, 0), 8.0, 0.4, 1.5)
	_add(&"dust", 70, Vector3(0.06, 0.06, 0.06), Color(0.9, 0.78, 0.55, 0.7), false, Vector3(30, 2, 30), Vector3(0.8, 0, 0.2), 6.0, 0.6, 1.0)
	_add(&"sparkles", 70, Vector3(0.06, 0.06, 0.06), Color(0.6, 0.95, 1.0), true, Vector3(24, 3, 24), Vector3(0, 0.3, 0), 3.0, 0.5, 1.0)
	_add(&"mist", 26, Vector3(3.0, 0.35, 3.0), Color(0.62, 0.7, 0.66, 0.07), false, Vector3(26, 0.3, 26), Vector3(0.2, 0, 0.1), 14.0, 0.2, 0.4)
	_add(&"snowdrift", 60, Vector3(0.06, 0.06, 0.06), Color(1, 1, 1, 0.85), false, Vector3(28, 2, 28), Vector3(1.5, -0.3, 0.4), 5.0, 0.8, 0.8)
	_add(&"cave_motes", 50, Vector3(0.04, 0.04, 0.04), Color(0.8, 0.75, 0.6, 0.6), true, Vector3(16, 3, 16), Vector3(0, 0.02, 0), 8.0, 0.2, 1.5)
	Events.boss_started.connect(func(b: Node) -> void: _boss = b)
	Events.boss_ended.connect(func(_b: Node) -> void: _boss = null)


func _add(id: StringName, amount: int, size: Vector3, color: Color, glow: bool, box: Vector3, drift: Vector3,
		life: float, turbulence: float, height: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 25, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box * 0.5
	pm.gravity = drift
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.4
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	if turbulence > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = turbulence
		pm.turbulence_noise_scale = 3.0
	# Fade in and out over each particle's life.
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.15, 1))
	curve.add_point(Vector2(0.85, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	if id == &"leaves":
		var g := Gradient.new()
		g.set_color(0, Color(0.55, 0.75, 0.25))
		g.set_color(1, Color(0.9, 0.5, 0.15))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_initial_ramp = gt
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 1.5
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.set_meta(&"height", height)
	add_child(p)
	emitters[id] = {"p": p, "level": 0.0}


## How strongly each effect should show right now (0..1).
func targets() -> Dictionary:
	var t := {}
	for id in emitters:
		t[id] = 0.0
	if world == null:
		return t
	if world.dungeon or world.layer == TerrainGenerator.Layer.UNDERGROUND:
		t[&"cave_motes"] = 1.0
		return t
	var biome: StringName = world.current_biome.id if world.current_biome else &""
	var daylight := world.day_night.get_daylight()
	var weather := world.weather
	var raining := weather != null and weather.is_precipitating()
	var dry := 0.0 if raining else 1.0
	if biome in FIREFLY and daylight < 0.35:
		t[&"fireflies"] = (1.0 - daylight / 0.35) * dry
	if biome in LEAFY:
		t[&"leaves"] = 0.6 + (weather.wind * 0.4 if weather else 0.0)
	if biome == &"verdant_meadow" and daylight > 0.5:
		t[&"pollen"] = dry
	if biome in [&"sunscorch_desert", &"sandy_beach"] and (weather == null or weather.kind != WeatherSystem.Kind.SANDSTORM):
		t[&"dust"] = 0.7
	if biome == &"crystal_glade":
		t[&"sparkles"] = 1.0
	if biome == &"murk_swamp":
		t[&"mist"] = 1.0 if daylight < 0.6 else 0.6
	if biome in [&"snowy_tundra", &"stonecrown_mountains"] and not raining:
		t[&"snowdrift"] = 0.6 + (weather.wind * 0.3 if weather else 0.0)
	return t


func _process(delta: float) -> void:
	if world == null or not world.is_ready:
		return
	var focus: Vector3 = world.camera_rig.global_position if world.camera_rig else world.player.global_position
	var t := targets()
	for id in emitters:
		var e: Dictionary = emitters[id]
		e.level = move_toward(e.level, float(t.get(id, 0.0)) if particles_enabled else 0.0, delta * 0.5)
		var p: GPUParticles3D = e.p
		p.amount_ratio = e.level
		var on: bool = e.level > 0.01
		if on != p.emitting:
			p.emitting = on
		p.visible = on
		if on:
			p.global_position = focus + Vector3(0, float(p.get_meta(&"height")), 0)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_update_sound()


## Music context right now.
func music_context() -> Dictionary:
	var p := world.player.global_position
	in_combat = false
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var en := e as Enemy
		if en and en.visible and not en.is_dead and en.target == world.player and en.global_position.distance_to(p) < COMBAT_RANGE:
			in_combat = true
			break
	return {
		"boss": is_instance_valid(_boss) and _boss is Node3D and (_boss as Node3D).global_position.distance_to(p) < 60.0,
		"combat": in_combat or (world.raids != null and world.raids.has_method("is_active") and world.raids.is_active()),
		"dungeon": world.dungeon != null,
		"underground": world.layer == TerrainGenerator.Layer.UNDERGROUND,
		"town": world.living != null and world.living.current != null,
		"night": world.day_night.is_night(),
	}


func _update_sound() -> void:
	Audio.set_music(Audio.pick_music(music_context()))
	var under := world.dungeon != null or world.layer == TerrainGenerator.Layer.UNDERGROUND
	Audio.set_cave_reverb(under)
	var biome: StringName = world.current_biome.id if world.current_biome else &""
	var daylight := world.day_night.get_daylight()
	var raining := world.weather != null and world.weather.is_precipitating()
	var wind := world.weather.wind if world.weather else 0.3
	var town := world.living != null and world.living.current != null
	var near_sea := biome in [&"deep_ocean", &"sandy_beach"] or world.is_in_water(world.player.global_position)
	var cold := biome in [&"snowy_tundra", &"frostpine_taiga", &"stonecrown_mountains"]
	if under:
		for l in [&"wind", &"birds", &"crickets", &"sea", &"town"]:
			Audio.set_ambience(l, 0.0)
		Audio.set_ambience(&"cave", 0.9)
		return
	Audio.set_ambience(&"cave", 0.0)
	Audio.set_ambience(&"wind", clampf(0.25 + wind * 0.45 + (0.25 if cold else 0.0), 0.0, 1.0))
	Audio.set_ambience(&"birds", (daylight if biome in BIRDS and not raining else 0.0) * 0.8)
	Audio.set_ambience(&"crickets", (1.0 - daylight) * 0.7 if not cold and not raining else 0.0)
	Audio.set_ambience(&"sea", 0.8 if near_sea else 0.0)
	Audio.set_ambience(&"town", 0.6 if town and daylight > 0.3 else 0.0)
