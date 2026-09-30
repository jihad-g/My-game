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
