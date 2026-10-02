class_name BeastModel
extends Node3D
## Blocky non-humanoid monsters: wisp (floating arcane orb), crawler (six-legged
## thorn crawler) and thornmaw (giant crawler boss). Milestone 15 adds the wild
## animals: four-legged wolf, deer and rabbit, a scorpion with a curled tail
## and a sideways-walking crab.

const QUADRUPEDS := [&"wolf", &"deer", &"rabbit"]

var look: StringName = &"crawler"
var tint := Color(0.4, 0.5, 0.25)
var accent := Color(0.9, 0.3, 0.6)

var _body: Node3D
var _legs: Array[Node3D] = []
var _orbit: Node3D
var _jaw: Node3D
var _tail: Node3D
var _head: Node3D
## Quadrupeds swing legs forward/back (rotation.x) instead of side to side.
var _quad := false
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
	_orbit = null
	_jaw = null
	_tail = null
	_head = null
	_quad = look in QUADRUPEDS
	_body = Node3D.new()
	add_child(_body)
	match look:
		&"wolf", &"deer", &"rabbit":
			_build_quadruped()
		&"scorpion":
			_build_scorpion()
		&"crab":
			_build_crab()
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


## Wolf (long snout, ears, bushy tail), deer (long legs, antlers, white tail)
## or rabbit (small, long ears, round tail).
func _build_quadruped() -> void:
	var dims: Dictionary = {
		&"wolf": {"body": Vector3(0.55, 0.5, 1.15), "leg": 0.5, "head": Vector3(0.42, 0.4, 0.45)},
		&"deer": {"body": Vector3(0.5, 0.55, 1.1), "leg": 0.75, "head": Vector3(0.32, 0.36, 0.42)},
		&"rabbit": {"body": Vector3(0.3, 0.3, 0.45), "leg": 0.12, "head": Vector3(0.24, 0.24, 0.24)},
	}[look]
	var body: Vector3 = dims.body
	var leg_len: float = dims.leg
	var light := tint.lightened(0.35)
	_body.position.y = leg_len + body.y * 0.5
	_part(_body, Vector3.ZERO, body, tint)
	_part(_body, Vector3(0, -body.y * 0.3, 0.05), Vector3(body.x * 0.85, body.y * 0.4, body.z * 0.8), light)  # belly
	_head = Node3D.new()
	_head.position = Vector3(0, body.y * 0.45, body.z * 0.5)
	_body.add_child(_head)
	var hd: Vector3 = dims.head
	_part(_head, Vector3(0, hd.y * 0.3, hd.z * 0.35), hd, tint)
	match look:
		&"wolf":
			_part(_head, Vector3(0, hd.y * 0.1, hd.z * 0.95), Vector3(0.22, 0.2, 0.32), tint.darkened(0.1))  # snout
			_part(_head, Vector3(0, hd.y * 0.12, hd.z * 1.14), Vector3(0.1, 0.08, 0.04), Color(0.1, 0.1, 0.12))  # nose
			for sx in [-0.13, 0.13]:
				_part(_head, Vector3(sx, hd.y * 0.95, hd.z * 0.2), Vector3(0.1, 0.18, 0.08), tint.darkened(0.15))  # ears
			_jaw = Node3D.new()
			_jaw.position = Vector3(0, 0.0, hd.z * 0.8)
			_head.add_child(_jaw)
			_part(_jaw, Vector3(0, -0.06, 0.12), Vector3(0.18, 0.06, 0.26), light)
		&"deer":
			_part(_head, Vector3(0, hd.y * 0.05, hd.z * 0.9), Vector3(0.2, 0.2, 0.22), tint.darkened(0.1))  # muzzle
			for sx in [-1.0, 1.0]:
				_part(_head, Vector3(sx * 0.12, hd.y * 1.05, hd.z * 0.25), Vector3(0.05, 0.3, 0.05), accent)  # antlers
				_part(_head, Vector3(sx * 0.2, hd.y * 1.25, hd.z * 0.25), Vector3(0.18, 0.05, 0.05), accent)
				_part(_head, Vector3(sx * 0.2, hd.y * 0.75, hd.z * 0.1), Vector3(0.12, 0.08, 0.05), tint)  # ears
			_head.position.y += 0.2  # long neck
			_part(_body, Vector3(0, body.y * 0.45, body.z * 0.42), Vector3(0.22, 0.4, 0.22), tint)  # neck
		&"rabbit":
			for sx in [-0.06, 0.06]:
				_part(_head, Vector3(sx, hd.y * 1.2, hd.z * 0.1), Vector3(0.06, 0.26, 0.06), tint)  # long ears
				_part(_head, Vector3(sx, hd.y * 1.2, hd.z * 0.1 + 0.031), Vector3(0.03, 0.2, 0.01), accent)
	for sx in [-0.06, 0.06]:
		_part(_head, Vector3(sx * hd.x * 2.4, hd.y * 0.5, hd.z * 0.85), Vector3(0.05, 0.05, 0.02), Color(0.08, 0.08, 0.1))  # eyes
	_tail = Node3D.new()
	_tail.position = Vector3(0, body.y * 0.3, -body.z * 0.5)
	_body.add_child(_tail)
	match look:
		&"wolf":
			_tail.rotation.x = 0.6
			_part(_tail, Vector3(0, 0, -0.25), Vector3(0.14, 0.14, 0.5), tint.darkened(0.05))
			_part(_tail, Vector3(0, 0, -0.5), Vector3(0.12, 0.12, 0.12), light)
		&"deer", &"rabbit":
			_part(_tail, Vector3(0, 0.02, -0.04), Vector3(0.12, 0.12, 0.1) * (1.4 if look == &"rabbit" else 1.0), Color(0.95, 0.93, 0.88))
	var leg_w := 0.1 if look == &"rabbit" else (0.12 if look == &"deer" else 0.15)
	for fz in [body.z * 0.35, -body.z * 0.35]:
		for sx in [-body.x * 0.32, body.x * 0.32]:
			var leg := Node3D.new()
			leg.position = Vector3(sx, -body.y * 0.4, fz)
			_body.add_child(leg)
			_part(leg, Vector3(0, -leg_len * 0.5, 0), Vector3(leg_w, leg_len + body.y * 0.2, leg_w * 1.2), tint.darkened(0.1))
			_part(leg, Vector3(0, -leg_len - 0.02, 0.02), Vector3(leg_w * 1.1, 0.06, leg_w * 1.4), tint.darkened(0.45))  # paw / hoof
			_legs.append(leg)


## Sand scorpion: flat armoured body, two pincers, six legs, a curled tail
## with a glowing sting.
func _build_scorpion() -> void:
	_body.position.y = 0.32
	_part(_body, Vector3.ZERO, Vector3(0.8, 0.28, 1.0), tint)
	for k in 3:
		_part(_body, Vector3(0, 0.15, -0.3 + k * 0.3), Vector3(0.7, 0.04, 0.22), tint.darkened(0.2))  # plates
	_part(_body, Vector3(0, 0.02, 0.6), Vector3(0.5, 0.22, 0.3), tint.darkened(0.1))  # head
	for sx in [-0.12, 0.12]:
		_part(_body, Vector3(sx, 0.12, 0.76), Vector3(0.06, 0.06, 0.03), Color(0.1, 0.05, 0.05))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0, 0.7)
	_body.add_child(_jaw)
	for sx in [-1.0, 1.0]:
		_part(_jaw, Vector3(sx * 0.35, 0, 0.2), Vector3(0.12, 0.1, 0.4), tint.darkened(0.1))  # arm
		_part(_jaw, Vector3(sx * 0.38, 0, 0.48), Vector3(0.22, 0.14, 0.24), tint)  # claw
		_part(_jaw, Vector3(sx * 0.3, 0, 0.62), Vector3(0.06, 0.08, 0.14), tint.darkened(0.3))
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.1, -0.5)
	_body.add_child(_tail)
	var y := 0.0
	var z := 0.0
	for k in 5:
		y += 0.14 + k * 0.03
		z -= 0.12 - k * 0.07
		_part(_tail, Vector3(0, y, z), Vector3(0.16 - k * 0.015, 0.16, 0.16), tint.darkened(0.05 * k))
	_part(_tail, Vector3(0, y + 0.05, z + 0.14), Vector3(0.08, 0.08, 0.2), accent, true)  # sting
	for side in [-1, 1]:
		for k in 3:
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.4, 0, -0.3 + k * 0.28)
			_body.add_child(leg)
			_part(leg, Vector3(side * 0.2, -0.05, 0), Vector3(0.4, 0.07, 0.07), tint.darkened(0.25))
			_part(leg, Vector3(side * 0.4, -0.2, 0), Vector3(0.07, 0.3, 0.07), tint.darkened(0.3))
			_legs.append(leg)


## Shore crab: wide shell, eye stalks, two big claws, walks sideways.
func _build_crab() -> void:
	_body.position.y = 0.32
	_part(_body, Vector3.ZERO, Vector3(0.9, 0.3, 0.6), tint)
	_part(_body, Vector3(0, 0.15, 0), Vector3(0.7, 0.08, 0.45), tint.lightened(0.15))
	for sx in [-0.15, 0.15]:
		_part(_body, Vector3(sx, 0.3, 0.25), Vector3(0.05, 0.2, 0.05), tint)
		_part(_body, Vector3(sx, 0.42, 0.25), Vector3(0.09, 0.09, 0.09), Color(0.08, 0.08, 0.1))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0, 0.3)
	_body.add_child(_jaw)
	for sx in [-1.0, 1.0]:
		_part(_jaw, Vector3(sx * 0.5, 0.05, 0.15), Vector3(0.3, 0.22, 0.26), accent)  # claws
		_part(_jaw, Vector3(sx * 0.58, 0.05, 0.34), Vector3(0.12, 0.12, 0.14), accent.darkened(0.2))
	for side in [-1, 1]:
		for k in 3:
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.45, 0, -0.2 + k * 0.18)
			_body.add_child(leg)
			_part(leg, Vector3(side * 0.18, -0.05, 0), Vector3(0.36, 0.06, 0.06), tint.darkened(0.2))
			_part(leg, Vector3(side * 0.36, -0.2, 0), Vector3(0.06, 0.3, 0.06), tint.darkened(0.25))
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
	if _quad:
		# Gallop: diagonal legs together, the body bobs and the tail sways.
		for i in _legs.size():
			var off := 0.0 if i in [0, 3] else PI
			_legs[i].rotation.x = sin(_phase + off) * 0.7 * m
		_body.rotation.x = sin(_phase * 2.0) * 0.04 * m
		if _tail:
			_tail.rotation.y = sin(_phase * 0.7) * (0.2 + 0.3 * m)
		if _head:
			_head.rotation.x = sin(_phase * 0.3) * 0.08 * (1.0 - m)  # grazing nod when idle
		return
	for i in _legs.size():
		_legs[i].rotation.y = sin(_phase + i * 1.3) * 0.5 * m
		# Lift each leg on its forward swing (Milestone 10).
		var side := -1.0 if _legs[i].position.x < 0.0 else 1.0
		_legs[i].rotation.z = maxf(0.0, sin(_phase + i * 1.3 + 1.57)) * 0.35 * m * side
	_body.rotation.z = sin(_phase) * 0.04 * m
	_body.scale = Vector3(1.0, 1.0 + sin(_phase * 0.25) * 0.03 * (1.0 - m), 1.0)


func play_attack(_anim: StringName, windup: float, active: float, recovery: float) -> void:
	var tw := create_tween()
	if _tail and look == &"scorpion":
		# The sting arcs over the back and strikes forward.
		tw.tween_property(_tail, "rotation:x", -0.5, windup)
		tw.tween_property(_tail, "rotation:x", 0.9, active)
		tw.tween_property(_tail, "rotation:x", 0.0, recovery)
	elif _head and look == &"wolf":
		tw.tween_property(_head, "rotation:x", -0.4, windup)
		tw.parallel().tween_property(_jaw, "rotation:x", 0.5, windup)
		tw.tween_property(_head, "rotation:x", 0.3, active)
		tw.parallel().tween_property(_jaw, "rotation:x", 0.0, active)
		tw.tween_property(_head, "rotation:x", 0.0, recovery)
	elif _jaw:
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
	if _head:
		_head.rotation = Vector3.ZERO
	if _tail:
		_tail.rotation.x = 0.6 if look == &"wolf" else 0.0


## Wolf howl: head thrown back for a moment (Milestone 15).
func play_howl(duration: float = 0.9) -> void:
	if _head == null:
		return
	var tw := create_tween()
	tw.tween_property(_head, "rotation:x", -0.9, 0.2)
	tw.tween_interval(maxf(duration - 0.45, 0.1))
	tw.tween_property(_head, "rotation:x", 0.0, 0.25)
