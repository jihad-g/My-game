class_name BeastModel
extends Node3D
## Blocky non-humanoid monsters: wisp (floating arcane orb), crawler (six-legged
## thorn crawler) and thornmaw (giant crawler boss).

var look: StringName = &"crawler"
var tint := Color(0.4, 0.5, 0.25)
var accent := Color(0.9, 0.3, 0.6)

var _body: Node3D
var _legs: Array[Node3D] = []
var _orbit: Node3D
var _jaw: Node3D
var _phase := 0.0
var _move := 0.0
var parts: Array[MeshInstance3D] = []


func build(p_look: StringName, p_tint: Color, p_accent: Color) -> void:
	look = p_look
	tint = p_tint
	accent = p_accent
	for c in get_children():
		c.free()
	parts.clear()
	_legs.clear()
	_body = Node3D.new()
	add_child(_body)
	match look:
		&"wisp":
			_body.position.y = 1.3
			_part(_body, Vector3.ZERO, Vector3(0.55, 0.55, 0.55), accent, true)
			_part(_body, Vector3.ZERO, Vector3(0.8, 0.2, 0.2), accent.lightened(0.3), true)
			_part(_body, Vector3.ZERO, Vector3(0.2, 0.8, 0.2), accent.lightened(0.3), true)
			_orbit = Node3D.new()
			_body.add_child(_orbit)
			for k in 3:
				var a := TAU * k / 3.0
				_part(_orbit, Vector3(cos(a) * 0.7, 0, sin(a) * 0.7), Vector3(0.16, 0.16, 0.16), tint, true)
		_:
			var big := look == &"thornmaw"
			var s := 1.1 if big else 1.0
			_body.position.y = 0.45 * s
			_part(_body, Vector3(0, 0, 0), Vector3(1.0, 0.45, 1.3) * s, tint)
			_part(_body, Vector3(0, 0.1, 0.8) * s, Vector3(0.7, 0.4, 0.5) * s, tint * 0.9)
			for k in 5:
				_part(_body, Vector3(-0.35 + k * 0.17, 0.3, -0.3 + (k % 2) * 0.35) * s, Vector3(0.08, 0.35, 0.08) * s, accent)
			_part(_body, Vector3(-0.18, 0.2, 1.06) * s, Vector3(0.1, 0.1, 0.05) * s, Color(1, 0.9, 0.3), true)
			_part(_body, Vector3(0.18, 0.2, 1.06) * s, Vector3(0.1, 0.1, 0.05) * s, Color(1, 0.9, 0.3), true)
			_jaw = Node3D.new()
			_jaw.position = Vector3(0, -0.05, 1.0) * s
			_body.add_child(_jaw)
			_part(_jaw, Vector3(0.2, -0.05, 0.12) * s, Vector3(0.1, 0.1, 0.35) * s, Color(0.95, 0.9, 0.8))
			_part(_jaw, Vector3(-0.2, -0.05, 0.12) * s, Vector3(0.1, 0.1, 0.35) * s, Color(0.95, 0.9, 0.8))
			for side in [-1, 1]:
				for k in 3:
					var leg := Node3D.new()
					leg.position = Vector3(side * 0.5, 0, -0.4 + k * 0.4) * s
					_body.add_child(leg)
					_part(leg, Vector3(side * 0.3, -0.15, 0) * s, Vector3(0.55, 0.1, 0.1) * s, tint * 0.8)
					_part(leg, Vector3(side * 0.58, -0.35, 0) * s, Vector3(0.1, 0.45, 0.1) * s, tint * 0.7)
					_legs.append(leg)


func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var b := BlockMesh.new()
	b.box(Vector3.ZERO, size, color)
	var mesh := b.commit()
	if glow:
		mesh.surface_set_material(0, Materials.vertex_color_emissive())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	parts.append(mi)
	return mi


func set_locomotion(speed_ratio: float, delta: float) -> void:
	_move = lerpf(_move, clampf(speed_ratio, 0.0, 1.5), 1.0 - exp(-10.0 * delta))
	_phase += delta * (3.0 + 12.0 * _move)
	if _orbit:
		_orbit.rotation.y += delta * 2.5
		_body.position.y = 1.3 + sin(_phase * 0.6) * 0.15
		return
	var m := minf(_move, 1.0)
	for i in _legs.size():
		_legs[i].rotation.y = sin(_phase + i * 1.3) * 0.5 * m
		# Lift each leg on its forward swing (Milestone 10).
		var side := -1.0 if _legs[i].position.x < 0.0 else 1.0
		_legs[i].rotation.z = maxf(0.0, sin(_phase + i * 1.3 + 1.57)) * 0.35 * m * side
	_body.rotation.z = sin(_phase) * 0.04 * m
	_body.scale = Vector3(1.0, 1.0 + sin(_phase * 0.25) * 0.03 * (1.0 - m), 1.0)


func play_attack(_anim: StringName, windup: float, active: float, recovery: float) -> void:
	var tw := create_tween()
	if _jaw:
		tw.tween_property(_jaw, "rotation:x", -0.6, windup)
		tw.tween_property(_jaw, "rotation:x", 0.3, active)
		tw.tween_property(_jaw, "rotation:x", 0.0, recovery)
	else:
		tw.tween_property(_body, "scale", Vector3.ONE * 1.3, windup)
		tw.tween_property(_body, "scale", Vector3.ONE, active + recovery)


func play_death() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.5)


func reset_pose() -> void:
	scale = Vector3.ONE
	if _body:
		_body.scale = Vector3.ONE
	if _jaw:
		_jaw.rotation = Vector3.ZERO
