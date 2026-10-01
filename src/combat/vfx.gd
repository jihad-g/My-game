class_name VFX
## Small code-built visual effects (no particle assets needed).


static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Expanding flat ring (shockwaves, novas, battle cries).
static func ring(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	mi.mesh = mesh
	mi.material_override = _unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.2, 0)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Glowing sphere burst (impacts, blinks).
static func burst(parent: Node, pos: Vector3, radius: float, color: Color, time: float = 0.25) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = _unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.4
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 2.0, time)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Jagged lightning line through points.
static func bolt(parent: Node, points: PackedVector3Array, color: Color, time: float = 0.2) -> void:
	if points.size() < 2:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var prev := a
		for k in range(1, 6):
			var p := a.lerp(b, k / 5.0)
			if k < 5:
				p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			im.surface_add_vertex(prev)
			im.surface_add_vertex(p)
			prev = p
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, time)
	tw.tween_callback(mi.queue_free)


## Red danger zone on the ground that fills up over `time` (boss slams).
static func danger_zone(parent: Node, pos: Vector3, radius: float, time: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.08, 0)
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 3
	edge.mesh = torus
	edge.scale = Vector3(radius, 0.2, radius)
	edge.material_override = _unshaded(Color(1, 0.2, 0.1, 0.8))
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(edge)
	var fill := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	fill.mesh = disc
	fill.material_override = _unshaded(Color(1, 0.15, 0.1, 0.35))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3(radius, 1, radius), time)
	tw.tween_callback(root.queue_free)
	return root


# --- Particle effects (Milestone 10) -----------------------------------------------------
## One-shot CPU particles made of little cubes (voxel debris), freed when done.
## CPU particles keep these cheap to spawn and identical on every renderer.

static var _cube_mesh: BoxMesh
static var enabled := true


static func _cube() -> BoxMesh:
	if _cube_mesh == null:
		_cube_mesh = BoxMesh.new()
		_cube_mesh.size = Vector3.ONE * 0.12
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.9
		_cube_mesh.material = m
	return _cube_mesh


static func _emit(parent: Node, pos: Vector3, color: Color, amount: int, speed: float, life: float, gravity: float,
		spread: float = 180.0, size: float = 1.0, dir := Vector3.UP, unshaded := false) -> CPUParticles3D:
	if not enabled or parent == null or not parent.is_inside_tree() or amount <= 0:
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = life
	p.mesh = _cube()
	if unshaded:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p.material_override = m
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	var grad := Gradient.new()
	grad.set_color(0, color.lightened(0.15))
	grad.set_color(1, Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, color.a))
	p.color_ramp = grad
	p.hue_variation_min = -0.03
	p.hue_variation_max = 0.03
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Chips flying off a hit (wood, stone, bone...).
static func debris(parent: Node, pos: Vector3, color: Color, amount: int = 8, speed: float = 4.0) -> void:
	_emit(parent, pos, color, amount, speed, 0.7, 14.0, 70.0, 1.0)


## Soft puff at the feet (landing, dodging, running).
static func dust(parent: Node, pos: Vector3, color: Color = Color(0.72, 0.66, 0.55, 0.8), amount: int = 6) -> void:
	_emit(parent, pos + Vector3(0, 0.05, 0), color, amount, 1.4, 0.5, -0.6, 85.0, 1.3)


## Bright sparks (metal on metal, parries, crits).
static func sparks(parent: Node, pos: Vector3, color: Color = Color(1.0, 0.85, 0.4), amount: int = 10) -> void:
	_emit(parent, pos, color, amount, 6.5, 0.35, 12.0, 120.0, 0.45, Vector3.UP, true)


## Water droplets (entering water, swimming strokes).
static func splash(parent: Node, pos: Vector3, amount: int = 14) -> void:
	_emit(parent, pos, Color(0.75, 0.88, 1.0, 0.85), amount, 4.0, 0.6, 14.0, 35.0, 0.7, Vector3.UP, true)


## Rising motes (healing, level up, magic).
static func motes(parent: Node, pos: Vector3, color: Color, amount: int = 16, radius: float = 0.6) -> void:
	var p := _emit(parent, pos, color, amount, 1.2, 1.1, -2.5, 25.0, 0.55, Vector3.UP, true)
	if p:
		p.explosiveness = 0.4
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
