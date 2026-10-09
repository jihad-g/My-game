class_name FX
## Milestone 18c: the VFX library v2 - spells and abilities that look like magic.
##
## - Soft glowing particles (round, additive) instead of cubes. GPUParticles3D on
##   Forward+/Mobile, CPUParticles3D on the compatibility renderer (browser, old PCs).
## - Emitters are pooled: a finished one is taken out of the scene and reused.
## - Building blocks: impact bursts, ground marks that fade, branching lightning
##   that flickers, beams from the sky, swirls, short light flashes.
## - One look per element (fire, frost, lightning, arcane, holy, poison, shadow,
##   physical). The element comes from a damage type, or is guessed from a colour
##   so every older effect gets a matching look.
## Respects Settings: "vfx_particles" (VFX.enabled) and "reduce_flashing".

const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"lightning", &"arcane", &"holy", &"poison", &"shadow", &"physical"]
const COLORS := {
	&"fire": Color(1.0, 0.5, 0.15), &"frost": Color(0.6, 0.9, 1.0), &"lightning": Color(0.82, 0.88, 1.0),
	&"arcane": Color(0.75, 0.5, 1.0), &"holy": Color(1.0, 0.92, 0.55), &"poison": Color(0.5, 0.9, 0.3),
	&"shadow": Color(0.25, 0.15, 0.35), &"physical": Color(0.85, 0.8, 0.72),
}
## Sound played when a spell of this element is cast.
const CAST_SOUNDS := {
	&"fire": &"fire", &"frost": &"frost", &"lightning": &"zap", &"arcane": &"cast", &"holy": &"heal",
	&"poison": &"poison", &"shadow": &"teleport",
}
const POOL_MAX := 24

static var _pool: Dictionary = {}  # key -> Array of idle emitters
static var _mats: Dictionary = {}
static var _soft_tex: GradientTexture2D
static var _use_gpu := -1
## Counts (tests and the debug overlay).
static var spawned := 0
static var reused := 0


# --- Elements ------------------------------------------------------------------------

## The element of a damage type (&"physical" when it has none).
static func element_of(damage_type: StringName) -> StringName:
	match damage_type:
		&"fire", &"frost", &"lightning", &"arcane", &"holy", &"poison", &"shadow":
			return damage_type
		&"true":
			return &"shadow"
	return &"physical"


## Guesses the element from an effect colour (so every older effect gets a look).
static func element_from_color(c: Color) -> StringName:
	if c.v < 0.4:
		return &"shadow"
	if c.s < 0.2:
		# Greys and whites: blue-white is lightning, warm or plain is physical.
		return &"lightning" if c.b > c.r and c.v > 0.85 else &"physical"
	var h := c.h * 360.0
	if h < 40.0 or h >= 340.0:
		return &"fire"
	if h < 65.0:
		return &"holy"
	if h < 160.0:
		return &"poison"
	if h < 215.0:
		return &"frost" if c.s > 0.25 else &"lightning"
	if h < 245.0:
		return &"lightning"
	return &"arcane"


static func color_of(element: StringName) -> Color:
	return COLORS.get(element, COLORS[&"physical"])


# --- Particles -------------------------------------------------------------------------

static func gpu() -> bool:
	if _use_gpu < 0:
		var method := RenderingServer.get_current_rendering_method()
		_use_gpu = 0 if method == "gl_compatibility" or method == "" else 1
	return _use_gpu == 1


## A soft round dot (white in the middle, clear at the edge).
static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.75))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 32
		_soft_tex.height = 32
	return _soft_tex


## Glowing billboard material (`add` = light adds up; off for smoke and shadow).
static func particle_material(add: bool) -> StandardMaterial3D:
	var key := &"add" if add else &"mix"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = soft_texture()
		m.disable_receive_shadows = true
		_mats[key] = m
	return _mats[key]


static func _quad() -> QuadMesh:
	if not _mats.has(&"quad"):
		var q := QuadMesh.new()
		q.size = Vector2(0.3, 0.3)
		_mats[&"quad"] = q
	return _mats[&"quad"]


## One burst of soft particles. `cfg`: amount, life, speed, spread (deg), gravity
## (negative = rises), size, dir, radius (emission sphere), add (glow), explosive
## (0..1), color. Returns the emitter (or null when particles are off).
static func particles(parent: Node, pos: Vector3, cfg: Dictionary) -> Node3D:
	if not VFX.enabled or parent == null or not parent.is_inside_tree():
		return null
	var key := "%s_%s" % ["gpu" if gpu() else "cpu", "add" if cfg.get("add", true) else "mix"]
	var e: Node3D = null
	var idle: Array = _pool.get(key, [])
	while not idle.is_empty() and e == null:
		var c = idle.pop_back()
		if is_instance_valid(c):
			e = c
	if e == null:
		e = _make_emitter(cfg.get("add", true))
		e.set_meta(&"fx_key", key)
		spawned += 1
	else:
		reused += 1
	_configure(e, cfg)
	parent.add_child(e)
	e.global_position = pos
	e.set(&"emitting", true)
	if e.has_method("restart"):
		e.restart()
	return e


static func _make_emitter(add: bool) -> Node3D:
	var e: Node3D
	if gpu():
		var g := GPUParticles3D.new()
		g.process_material = ParticleProcessMaterial.new()
		g.draw_pass_1 = _quad()
		g.material_override = particle_material(add)
		e = g
	else:
		var c := CPUParticles3D.new()
		c.mesh = _quad()
		c.material_override = particle_material(add)
		e = c
	e.set(&"one_shot", true)
	(e as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.connect(&"finished", func() -> void: _recycle(e))
	return e


static func _configure(e: Node3D, cfg: Dictionary) -> void:
	var color: Color = cfg.get("color", Color.WHITE)
	var amount := maxi(1, int(cfg.get("amount", 12)))
	var life := float(cfg.get("life", 0.6))
	var speed := float(cfg.get("speed", 2.0))
	var spread := float(cfg.get("spread", 180.0))
	var grav := float(cfg.get("gravity", 0.0))
	var size := float(cfg.get("size", 1.0))
	var dir: Vector3 = cfg.get("dir", Vector3.UP)
	var radius := float(cfg.get("radius", 0.0))
	var grad := Gradient.new()
	grad.set_color(0, Color(color.lightened(0.35), color.a))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.6))
	scale_curve.add_point(Vector2(0.25, 1.0))
	scale_curve.add_point(Vector2(1, 0.2))
	e.set(&"amount", amount)
	e.set(&"lifetime", life)
	e.set(&"explosiveness", float(cfg.get("explosive", 0.85)))
	if e is GPUParticles3D:
		var m := (e as GPUParticles3D).process_material as ParticleProcessMaterial
		m.direction = dir
		m.spread = spread
		m.initial_velocity_min = minf(speed * 0.5, speed)
		m.initial_velocity_max = maxf(speed * 0.5, speed)
		m.gravity = Vector3(0, -grav, 0)
		m.scale_min = size * 0.7
		m.scale_max = size * 1.3
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		m.color_ramp = gt
		var ct := CurveTexture.new()
		ct.curve = scale_curve
		m.scale_curve = ct
		m.damping_min = float(cfg.get("damping", 0.0))
		m.damping_max = float(cfg.get("damping", 0.0))
		if radius > 0.0:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = radius
		else:
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		(e as GPUParticles3D).visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 10, 12))
	else:
		var c := e as CPUParticles3D
		c.direction = dir
		c.spread = spread
		c.initial_velocity_min = minf(speed * 0.5, speed)
		c.initial_velocity_max = maxf(speed * 0.5, speed)
		c.gravity = Vector3(0, -grav, 0)
		c.scale_amount_min = size * 0.7
		c.scale_amount_max = size * 1.3
		c.color_ramp = grad
		c.scale_amount_curve = scale_curve
		c.damping_min = float(cfg.get("damping", 0.0))
		c.damping_max = float(cfg.get("damping", 0.0))
		if radius > 0.0:
			c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			c.emission_sphere_radius = radius
		else:
			c.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT


static func _recycle(e: Node3D) -> void:
	if not is_instance_valid(e) or e.get(&"one_shot") == false:
		return
	if e.get_parent():
		e.get_parent().remove_child(e)
	var key: String = e.get_meta(&"fx_key", "")
	var idle: Array = _pool.get(key, [])
	if idle.size() >= POOL_MAX:
		e.queue_free()  # not free(): we are inside its own "finished" signal
		return
	idle.append(e)
	_pool[key] = idle


## How many idle emitters wait in the pool (tests).
static func pooled() -> int:
	var n := 0
	for k in _pool:
		n += (_pool[k] as Array).size()
	return n


## A looping emitter that follows its parent (projectile trails). Call `stop_trail`
## to let it fade instead of vanishing.
static func trail(parent: Node3D, element: StringName, size: float = 1.0) -> Node3D:
	if not VFX.enabled or parent == null:
		return null
	var col := color_of(element)
	var e := _make_emitter(element != &"shadow")
	e.set(&"one_shot", false)
	_configure(e, {"color": Color(col.r, col.g, col.b, 0.85), "amount": 20, "life": 0.45, "speed": 0.4,
		"spread": 180.0, "gravity": -1.5 if element == &"fire" else (1.5 if element == &"frost" else 0.0),
		"size": size * (1.2 if element == &"shadow" else 0.9), "explosive": 0.0})
	if e is GPUParticles3D:
		(e as GPUParticles3D).local_coords = false
	else:
		(e as CPUParticles3D).local_coords = false
	parent.add_child(e)
	e.set(&"emitting", true)
	return e


static func stop_trail(e: Node3D) -> void:
	if e == null or not is_instance_valid(e):
		return
	var world_parent := e.get_tree().current_scene if e.is_inside_tree() else null
	var host := e.get_parent()
	if host and host.get_parent():
		var keep := e.global_transform
		host.remove_child(e)
		host.get_parent().add_child(e)
		e.global_transform = keep
	elif world_parent == null:
		e.queue_free()
		return
	e.set(&"emitting", false)
	e.get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
		if is_instance_valid(e):
			e.queue_free())


# --- Building blocks -----------------------------------------------------------------------

## A short flash of coloured light (smaller with "reduce flashing").
static func light_flash(parent: Node, pos: Vector3, color: Color, energy: float = 2.5, radius: float = 6.0, time: float = 0.22) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy * (0.35 if Settings.reduce_flashing() else 1.0)
	l.omni_range = radius
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## A soft mark on the ground that fades out (scorch, frost, holy light, poison, runes).
static func ground_mark(parent: Node, pos: Vector3, radius: float, element: StringName, time: float = 2.0) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var col := color_of(element)
	if element == &"fire":
		col = Color(0.15, 0.08, 0.05)  # scorch
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = soft_texture()
	m.albedo_color = Color(col.r, col.g, col.b, 0.75 if element == &"fire" else 0.55)
	if element != &"fire" and element != &"shadow":
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(&"fx_marks")
	parent.add_child(mi)
	var y := pos.y
	if World.instance:
		y = World.instance.get_ground_height(pos)
	mi.global_position = Vector3(pos.x, y + 0.04, pos.z)
	mi.scale = Vector3(radius, 1, radius)
	if element == &"arcane":
		_rune_ring(mi, col)
	var tw := mi.create_tween()
	tw.tween_interval(time * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, time * 0.4)
	tw.tween_callback(mi.queue_free)
	return mi


## Arcane runes: a thin ring and little blocks that turn slowly.
static func _rune_ring(mark: Node3D, col: Color) -> void:
	var b := BlockMesh.new()
	for i in 8:
		var a := TAU * i / 8.0
		b.box(Vector3(cos(a), 0.02, sin(a)) * 0.8, Vector3(0.12, 0.01, 0.06), col.lightened(0.3))
	var r := MeshInstance3D.new()
	r.mesh = b.commit()
	r.mesh.surface_set_material(0, Materials.vertex_color_emissive())
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(r)
	var tw := r.create_tween().set_loops()
	tw.tween_property(r, "rotation:y", TAU, 6.0).from(0.0)


## Lightning: a jagged main bolt with a few branches that flickers, plus a flash.
static func lightning(parent: Node, points: PackedVector3Array, color: Color = COLORS[&"lightning"], time: float = 0.25, branches: int = 2) -> void:
	if parent == null or not parent.is_inside_tree() or points.size() < 2:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var fork_at: Array[Vector3] = []
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := maxi(5, int(a.distance_to(b) / 0.8))
		var prev := a
		for k in range(1, seg + 1):
			var p := a.lerp(b, float(k) / seg)
			if k < seg:
				p += Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
				if randf() < 0.25 and fork_at.size() < branches * (points.size() - 1):
					fork_at.append(p)
			# Two slightly offset lines read as a thicker bolt.
			im.surface_add_vertex(prev)
			im.surface_add_vertex(p)
			im.surface_add_vertex(prev + Vector3(0.04, 0.04, 0))
			im.surface_add_vertex(p + Vector3(0.04, 0.04, 0))
			prev = p
	for f in fork_at:
		var d := Vector3(randf_range(-1, 1), randf_range(-1.0, 0.2), randf_range(-1, 1)).normalized() * randf_range(0.6, 1.4)
		var prev := f
		for k in 3:
			var p := f + d * (k + 1) / 3.0 + Vector3(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15), randf_range(-0.15, 0.15))
			im.surface_add_vertex(prev)
			im.surface_add_vertex(p)
			prev = p
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# Flicker: off and on a few times, then fade.
	var tw := mi.create_tween()
	var flicker := 1 if Settings.reduce_flashing() else 3
	for i in flicker:
		tw.tween_property(mi, "visible", false, time * 0.08)
		tw.tween_property(mi, "visible", true, time * 0.08)
	tw.tween_property(m, "albedo_color:a", 0.0, time * 0.5)
	tw.tween_callback(mi.queue_free)
	var end := points[points.size() - 1]
	light_flash(parent, end, color, 3.0, 7.0, time)
	particles(parent, end, {"color": color, "amount": 10, "life": 0.35, "speed": 5.0, "spread": 120.0, "gravity": 10.0, "size": 0.45})


## A beam of light from the sky (holy, sunfire, smite).
static func sky_beam(parent: Node, pos: Vector3, color: Color, width: float = 0.6, time: float = 0.45) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = width
	c.bottom_radius = width * 0.7
	c.height = 16.0
	c.radial_segments = 12
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.6)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 8.0, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, time * 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time * 0.8)
	tw.tween_callback(mi.queue_free)
	light_flash(parent, pos + Vector3(0, 1, 0), color, 3.0, 8.0, time)


# --- Element looks -------------------------------------------------------------------------

## An impact in the element's look. `size` ~ the radius in metres.
static func impact(parent: Node, pos: Vector3, element: StringName, size: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var col := color_of(element)
	var s := clampf(size, 0.3, 6.0)
	var n := clampi(int(10 + s * 8), 8, 48)
	match element:
		&"fire":
			# Embers that rise and a scorch mark.
			particles(parent, pos, {"color": col, "amount": n, "life": 0.9, "speed": 3.0 * s, "gravity": -3.0, "size": 0.9 * s, "radius": 0.3 * s, "damping": 2.0})
			particles(parent, pos, {"color": Color(1, 0.85, 0.4), "amount": n / 2, "life": 1.2, "speed": 1.2, "gravity": -2.5, "size": 0.35, "radius": 0.5 * s, "explosive": 0.4})
			light_flash(parent, pos + Vector3(0, 0.5, 0), col, 3.0, 4.0 + 2.0 * s)
			if s >= 1.0:
				ground_mark(parent, pos, s, &"fire", 3.0)
		&"frost":
			# Sharp shards that fall, cold mist on the ground, a frost mark.
			particles(parent, pos, {"color": Color(0.85, 0.97, 1.0), "amount": n, "life": 0.6, "speed": 5.0 * s, "spread": 80.0, "gravity": 14.0, "size": 0.45})
			particles(parent, pos, {"color": Color(col.r, col.g, col.b, 0.5), "amount": n / 2, "life": 1.3, "speed": 0.8, "spread": 90.0, "dir": Vector3(0, 0.2, 0), "gravity": 0.3, "size": 1.6 * s, "radius": 0.4 * s, "add": false, "explosive": 0.6})
			light_flash(parent, pos + Vector3(0, 0.5, 0), col, 2.0, 4.0 + s)
			if s >= 1.0:
				ground_mark(parent, pos, s * 1.1, &"frost", 3.5)
		&"lightning":
			particles(parent, pos, {"color": col, "amount": n, "life": 0.3, "speed": 7.0 * s, "gravity": 12.0, "size": 0.4})
			lightning(parent, PackedVector3Array([pos + Vector3(0, 0.3, 0), pos + Vector3(randf_range(-1, 1), -0.2, randf_range(-1, 1)) * s]), col, 0.18, 1)
		&"arcane":
			# A swirl of motes and runes on the ground.
			particles(parent, pos, {"color": col, "amount": n, "life": 0.9, "speed": 2.0 * s, "gravity": -1.0, "size": 0.7, "radius": 0.6 * s, "damping": 3.0})
			light_flash(parent, pos + Vector3(0, 0.6, 0), col, 2.2, 4.0 + 2.0 * s)
			if s >= 1.0:
				ground_mark(parent, pos, s, &"arcane", 2.5)
		&"holy":
			sky_beam(parent, pos, col, 0.25 + 0.15 * s, 0.4)
			particles(parent, pos, {"color": col, "amount": n, "life": 1.1, "speed": 1.5, "gravity": -2.5, "size": 0.5, "radius": 0.5 * s, "explosive": 0.5})
			if s >= 1.0:
				ground_mark(parent, pos, s, &"holy", 2.0)
		&"poison":
			# Bubbles and a low green cloud.
			particles(parent, pos, {"color": col, "amount": n, "life": 1.0, "speed": 1.2, "gravity": -1.2, "size": 0.5, "radius": 0.5 * s, "explosive": 0.4})
			particles(parent, pos, {"color": Color(0.3, 0.55, 0.2, 0.55), "amount": n / 2, "life": 1.6, "speed": 0.6, "spread": 90.0, "dir": Vector3(0, 0.1, 0), "size": 1.8 * s, "radius": 0.5 * s, "add": false})
			if s >= 1.0:
				ground_mark(parent, pos, s, &"poison", 3.0)
		&"shadow":
			# Black smoke that pulls inward.
			particles(parent, pos, {"color": Color(0.08, 0.05, 0.12, 0.8), "amount": n, "life": 0.7, "speed": -2.0 * s, "radius": 1.0 * s, "size": 1.5, "add": false})
			particles(parent, pos, {"color": Color(0.5, 0.3, 0.7), "amount": n / 3, "life": 0.6, "speed": 1.0, "size": 0.35})
		_:
			particles(parent, pos, {"color": col, "amount": n / 2, "life": 0.45, "speed": 3.0 * s, "gravity": 8.0, "size": 0.5})


## The hands glow and gather the element while a spell or ability is cast
## (the "charge-up"), with the element's sound.
static func cast_glow(model: Node3D, element: StringName, sound: bool = true) -> void:
	if model == null or not model.is_inside_tree():
		return
	var col := color_of(element)
	var parent := model.get_parent()
	var hands: Array = []
	if model.has_method("hand_position"):
		hands = [model.hand_position(true), model.hand_position(false)]
	else:
		hands = [model.global_position + Vector3(0, 1.2, 0)]
	for h in hands:
		particles(parent, h, {"color": col, "amount": 10, "life": 0.4, "speed": -1.4, "radius": 0.45, "size": 0.45, "explosive": 0.3})
	light_flash(parent, (hands[0] as Vector3), col, 1.6, 3.0, 0.35)
	if sound and CAST_SOUNDS.has(element):
		Audio.play(CAST_SOUNDS[element], -6.0, 0.08, &"SFX", 90)


# --- Ultimates -------------------------------------------------------------------------------

## A short slow-motion moment, a screen flash, a big mark on the ground and a
## sound for the level-100 ultimates. Slow motion only when playing alone.
static func ultimate(caster: Node3D, element: StringName, sound: StringName) -> void:
	if caster == null or not caster.is_inside_tree():
		return
	var parent := caster.get_parent()
	var col := color_of(element)
	ground_mark(parent, caster.global_position, 8.0, element, 4.0)
	impact(parent, caster.global_position + Vector3(0, 0.3, 0), element, 3.0)
	light_flash(parent, caster.global_position + Vector3(0, 2, 0), col, 6.0, 16.0, 0.6)
	Audio.play(sound, 0.0, 0.03)
	screen_flash(caster.get_tree(), col)
	slow_motion(caster.get_tree(), 0.35, 0.3)


## A full-screen coloured flash (weaker with "reduce flashing").
static func screen_flash(tree: SceneTree, color: Color, time: float = 0.35) -> void:
	if tree == null or tree.root == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.add_to_group(&"fx_screen_flash")
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.12 if Settings.reduce_flashing() else 0.4)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	tree.root.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, time)
	tw.tween_callback(layer.queue_free)


## Slows the game to `scale` for `seconds` of real time. Only when playing alone
## (in co-op the time must stay the same for everyone) and not with "reduce motion".
static func slow_motion(tree: SceneTree, scale: float, seconds: float) -> bool:
	if tree == null or Net.is_online() or Settings.reduce_motion() or Engine.time_scale < 0.99:
		return false
	Engine.time_scale = scale
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
	return true
