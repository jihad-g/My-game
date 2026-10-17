class_name BeastModel
extends Node3D
## Blocky non-humanoid monsters: wisp (floating arcane orb), crawler (six-legged
## thorn crawler) and thornmaw (giant crawler boss). Milestone 15 adds the wild
## animals: four-legged wolf, deer and rabbit, a scorpion with a curled tail
## and a sideways-walking crab.

const QUADRUPEDS := [&"wolf", &"deer", &"rabbit", &"fox", &"stag", &"hedgehog", &"cat"]
## Milestone 27: new looks (bee, phoenix and candle skull fly; the others walk).
const HOVER := {&"bee": 1.1, &"phoenix": 1.35, &"candle_skull": 1.35}

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
## Milestone 27: flapping wings and the hover height of flying looks.
var _wings: Array[Node3D] = []
var _hover := 0.0
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
	_wings.clear()
	_hover = float(HOVER.get(look, 0.0))
	_quad = look in QUADRUPEDS
	_body = Node3D.new()
	add_child(_body)
	match look:
		&"wolf", &"deer", &"rabbit", &"fox", &"stag", &"hedgehog", &"cat":
			_build_quadruped()
		&"bee":
			_build_bee()
		&"phoenix":
			_build_phoenix()
		&"candle_skull":
			_build_candle_skull()
		&"spider":
			_build_spider()
		&"pumpkin":
			_build_pumpkin()
		&"acorn":
			_build_acorn()
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
		&"fox": {"body": Vector3(0.4, 0.36, 0.78), "leg": 0.3, "head": Vector3(0.36, 0.32, 0.34)},
		&"stag": {"body": Vector3(0.52, 0.56, 1.12), "leg": 0.78, "head": Vector3(0.32, 0.36, 0.42)},
		&"hedgehog": {"body": Vector3(0.42, 0.3, 0.55), "leg": 0.07, "head": Vector3(0.24, 0.22, 0.24)},
		&"cat": {"body": Vector3(0.32, 0.3, 0.62), "leg": 0.24, "head": Vector3(0.34, 0.3, 0.3)},
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
		&"fox":
			# Ice fox: pointed snout, tall ears with pale insides, white ruff.
			_part(_head, Vector3(0, hd.y * 0.08, hd.z * 0.95), Vector3(0.16, 0.14, 0.26), light)
			_part(_head, Vector3(0, hd.y * 0.12, hd.z * 1.1), Vector3(0.07, 0.06, 0.04), Color(0.15, 0.18, 0.25))
			for sx in [-0.11, 0.11]:
				_part(_head, Vector3(sx, hd.y * 1.0, hd.z * 0.15), Vector3(0.11, 0.22, 0.07), tint)
				_part(_head, Vector3(sx, hd.y * 0.98, hd.z * 0.15 + 0.04), Vector3(0.06, 0.15, 0.02), accent)
			_part(_body, Vector3(0, -body.y * 0.05, body.z * 0.42), Vector3(body.x * 0.9, body.y * 0.7, 0.16), Color(0.96, 0.97, 1.0))
			_jaw = Node3D.new()
			_jaw.position = Vector3(0, 0.0, hd.z * 0.8)
			_head.add_child(_jaw)
			_part(_jaw, Vector3(0, -0.05, 0.1), Vector3(0.13, 0.05, 0.2), light)
		&"stag":
			# Blossom stag: long neck, branching dark antlers covered in pink blossom.
			_part(_head, Vector3(0, hd.y * 0.05, hd.z * 0.9), Vector3(0.2, 0.2, 0.22), tint.darkened(0.1))
			_head.position.y += 0.22
			_part(_body, Vector3(0, body.y * 0.45, body.z * 0.42), Vector3(0.22, 0.42, 0.22), tint)
			for sx in [-1.0, 1.0]:
				_part(_head, Vector3(sx * 0.2, hd.y * 0.75, hd.z * 0.1), Vector3(0.12, 0.08, 0.05), tint)  # ears
				var wood := Color(0.32, 0.22, 0.16)
				_part(_head, Vector3(sx * 0.12, hd.y * 1.15, hd.z * 0.2), Vector3(0.05, 0.38, 0.05), wood)
				_part(_head, Vector3(sx * 0.24, hd.y * 1.45, hd.z * 0.2), Vector3(0.22, 0.05, 0.05), wood)
				_part(_head, Vector3(sx * 0.32, hd.y * 1.7, hd.z * 0.2), Vector3(0.05, 0.28, 0.05), wood)
				_part(_head, Vector3(sx * 0.12, hd.y * 1.65, hd.z * 0.2), Vector3(0.05, 0.25, 0.05), wood)
				for b in [Vector3(0.36, 1.95, 0.2), Vector3(0.12, 1.88, 0.25), Vector3(0.3, 1.5, 0.12),
						Vector3(0.22, 1.75, 0.32), Vector3(0.42, 1.72, 0.18), Vector3(0.05, 1.45, 0.15)]:
					_part(_head, Vector3(sx * b.x, hd.y * b.y, hd.z * b.z), Vector3(0.12, 0.1, 0.12),
						accent if int(b.y * 10) % 2 == 0 else accent.lightened(0.3))
		&"hedgehog":
			# Hedgehog: little pointed nose and a coat of spines.
			_part(_head, Vector3(0, hd.y * 0.1, hd.z * 0.95), Vector3(0.1, 0.09, 0.14), light)
			_part(_head, Vector3(0, hd.y * 0.15, hd.z * 1.18), Vector3(0.06, 0.05, 0.04), Color(0.08, 0.06, 0.06))
			for i in 14:
				var sx := -body.x * 0.38 + (i % 4) * body.x * 0.25
				var sz := body.z * 0.4 - (i / 4) * body.z * 0.27
				var spine := _part(_body, Vector3(sx, body.y * 0.55, sz), Vector3(0.06, 0.2, 0.06),
					accent if i % 3 else accent.lightened(0.35))
				spine.rotation = Vector3(-0.6, 0, sx * 1.6)
		&"cat":
			# Witch cat: pointed ears and a crooked purple witch hat.
			for sx in [-0.11, 0.11]:
				_part(_head, Vector3(sx, hd.y * 0.95, hd.z * 0.2), Vector3(0.1, 0.16, 0.06), tint)
			_part(_head, Vector3(0, hd.y * 0.15, hd.z * 0.95), Vector3(0.14, 0.1, 0.1), tint.lightened(0.1))
			var hat := Color(0.36, 0.2, 0.46)
			_part(_head, Vector3(0, hd.y * 0.98, hd.z * 0.3), Vector3(0.5, 0.05, 0.46), hat)
			_part(_head, Vector3(0, hd.y * 1.16, hd.z * 0.3), Vector3(0.24, 0.3, 0.24), hat)
			_part(_head, Vector3(0, hd.y * 1.04, hd.z * 0.3), Vector3(0.25, 0.06, 0.25), Color(0.85, 0.65, 0.2))
			var tip := _part(_head, Vector3(0.06, hd.y * 1.5, hd.z * 0.2), Vector3(0.14, 0.18, 0.14), hat)
			tip.rotation.z = -0.5
			for sx in [-0.07, 0.07]:
				_part(_head, Vector3(sx, hd.y * 0.62, hd.z * 0.85), Vector3(0.07, 0.07, 0.02), Color(0.2, 0.08, 0.15))
	var eye := Color(0.08, 0.08, 0.1)
	for sx in [-0.06, 0.06]:
		if look == &"cat":
			_part(_head, Vector3(sx * hd.x * 2.4, hd.y * 0.5, hd.z * 0.86), Vector3(0.07, 0.07, 0.02), accent, true)  # glowing eyes
		else:
			_part(_head, Vector3(sx * hd.x * 2.4, hd.y * 0.5, hd.z * 0.85), Vector3(0.05, 0.05, 0.02), eye)  # eyes
	_tail = Node3D.new()
	_tail.position = Vector3(0, body.y * 0.3, -body.z * 0.5)
	_body.add_child(_tail)
	match look:
		&"wolf":
			_tail.rotation.x = 0.6
			_part(_tail, Vector3(0, 0, -0.25), Vector3(0.14, 0.14, 0.5), tint.darkened(0.05))
			_part(_tail, Vector3(0, 0, -0.5), Vector3(0.12, 0.12, 0.12), light)
		&"deer", &"rabbit", &"stag":
			_part(_tail, Vector3(0, 0.02, -0.04), Vector3(0.12, 0.12, 0.1) * (1.4 if look == &"rabbit" else 1.0), Color(0.95, 0.93, 0.88))
		&"fox":
			_tail.rotation.x = 0.5
			_part(_tail, Vector3(0, 0, -0.25), Vector3(0.2, 0.2, 0.5), tint)
			_part(_tail, Vector3(0, 0, -0.55), Vector3(0.18, 0.18, 0.16), Color(0.96, 0.97, 1.0))
		&"cat":
			_tail.rotation.x = -0.9
			_part(_tail, Vector3(0, 0, -0.22), Vector3(0.07, 0.07, 0.44), tint)
			_part(_tail, Vector3(0, 0, -0.46), Vector3(0.07, 0.07, 0.07), tint.lightened(0.15))
	var leg_w := 0.1 if look in [&"rabbit", &"hedgehog", &"cat"] else (0.12 if look in [&"deer", &"stag", &"fox"] else 0.15)
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
	var mesh: Mesh
	if PixelAuto.enabled:
		mesh = PixelAuto.mesh(size, color, glow)
	else:
		var b := BlockMesh.new()
		b.box(Vector3.ZERO, size, color)
		mesh = b.commit()
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
	if _hover > 0.0:
		# Milestone 27: flyers bob and beat their wings; the candle skull sways.
		_body.position.y = _hover + sin(_phase * 0.5) * 0.12
		var beat := 26.0 if look == &"bee" else 7.0
		for i in _wings.size():
			var side := -1.0 if _wings[i].position.x < 0.0 else 1.0
			_wings[i].rotation.z = side * sin(Time.get_ticks_msec() / 1000.0 * beat) * (0.6 if look == &"bee" else 0.55)
		_body.rotation.z = sin(_phase * 0.4) * 0.06
		if _tail:
			_tail.rotation.x = sin(_phase * 0.5) * 0.15
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
	elif _hover > 0.0:
		# Flyers dive forward at you.
		tw.tween_property(_body, "position:z", -0.3, windup)
		tw.tween_property(_body, "position:z", 0.6, active)
		tw.tween_property(_body, "position:z", 0.0, recovery)
		if _jaw:
			tw.parallel().tween_property(_jaw, "rotation:x", 0.0, recovery)
	elif _head and _jaw and look in [&"wolf", &"fox"]:
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
	if _body and _hover <= 0.0:
		_body.position.z = 0.0
	if _tail:
		_tail.rotation.x = {&"wolf": 0.6, &"fox": 0.5, &"cat": -0.9}.get(look, 0.0)


## Wolf howl: head thrown back for a moment (Milestone 15).
func play_howl(duration: float = 0.9) -> void:
	if _head == null:
		return
	var tw := create_tween()
	tw.tween_property(_head, "rotation:x", -0.9, 0.2)
	tw.tween_interval(maxf(duration - 0.45, 0.1))
	tw.tween_property(_head, "rotation:x", 0.0, 0.25)


# --- Milestone 27: new looks ------------------------------------------------------------

## Meadow bumblebee: round striped body, see-through wings, a little sting.
func _build_bee() -> void:
	_body.position.y = _hover
	var yellow := tint
	var black := Color(0.12, 0.1, 0.1)
	_part(_body, Vector3(0, 0, 0.05), Vector3(0.5, 0.46, 0.56), yellow)
	for z in [-0.1, 0.12]:
		_part(_body, Vector3(0, 0, z), Vector3(0.52, 0.48, 0.1), black)
	_part(_body, Vector3(0, 0.0, -0.3), Vector3(0.36, 0.34, 0.2), yellow.darkened(0.1))
	_part(_body, Vector3(0, -0.02, -0.44), Vector3(0.07, 0.07, 0.12), black)  # sting
	_head = Node3D.new()
	_head.position = Vector3(0, 0.02, 0.38)
	_body.add_child(_head)
	_part(_head, Vector3.ZERO, Vector3(0.36, 0.32, 0.22), black)
	for sx in [-0.1, 0.1]:
		_part(_head, Vector3(sx, 0.04, 0.11), Vector3(0.1, 0.12, 0.03), Color(1, 1, 1))
		_part(_head, Vector3(sx + 0.02, 0.03, 0.125), Vector3(0.05, 0.07, 0.02), black)
		_part(_head, Vector3(sx * 0.8, 0.24, 0.02), Vector3(0.03, 0.18, 0.03), black)  # feelers
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.15, 0.24, 0.05)
		_body.add_child(w)
		_part(w, Vector3(sx * 0.25, 0.04, 0), Vector3(0.45, 0.03, 0.3), Color(0.92, 0.96, 1.0))
		_wings.append(w)


## Ember phoenix: a fire bird with a crest, burning wing tips and a long tail.
func _build_phoenix() -> void:
	_body.position.y = _hover
	var red := tint
	var gold := accent
	_part(_body, Vector3.ZERO, Vector3(0.42, 0.42, 0.7), red)
	_part(_body, Vector3(0, -0.06, 0.12), Vector3(0.36, 0.3, 0.42), gold)  # chest
	_head = Node3D.new()
	_head.position = Vector3(0, 0.28, 0.4)
	_body.add_child(_head)
	_part(_head, Vector3.ZERO, Vector3(0.28, 0.28, 0.3), red)
	_part(_head, Vector3(0, -0.04, 0.2), Vector3(0.1, 0.08, 0.16), Color(1.0, 0.85, 0.3))  # beak
	for sx in [-0.1, 0.1]:
		_part(_head, Vector3(sx, 0.05, 0.13), Vector3(0.05, 0.05, 0.03), Color(0.15, 0.05, 0.05))
	for k in 3:
		_part(_head, Vector3(0, 0.2 + k * 0.08, -0.05 - k * 0.07), Vector3(0.05, 0.14, 0.05), gold, true)  # crest
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.2, 0.12, 0.0)
		_body.add_child(w)
		for k in 4:
			var c := red.lerp(gold, k / 3.0)
			_part(w, Vector3(sx * (0.2 + k * 0.2), 0.0 - k * 0.02, -k * 0.05), Vector3(0.22, 0.05, 0.42 - k * 0.06), c, k == 3)
		_wings.append(w)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, -0.35)
	_body.add_child(_tail)
	for k in 3:
		_part(_tail, Vector3((k - 1) * 0.1, -0.05 - k * 0.02, -0.35), Vector3(0.07, 0.04, 0.6), red.lerp(gold, k * 0.4), k == 1)


## Candle skull: a floating skull with burning purple candles on top.
func _build_candle_skull() -> void:
	_body.position.y = _hover
	var bone := tint
	_part(_body, Vector3.ZERO, Vector3(0.5, 0.44, 0.48), bone)
	for sx in [-0.11, 0.11]:
		_part(_body, Vector3(sx, 0.02, 0.24), Vector3(0.13, 0.13, 0.02), Color(0.1, 0.06, 0.12))
		_part(_body, Vector3(sx, 0.02, 0.25), Vector3(0.06, 0.06, 0.02), accent, true)  # eye glow
	_part(_body, Vector3(0, -0.08, 0.245), Vector3(0.06, 0.06, 0.02), Color(0.15, 0.1, 0.12))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.22, 0.05)
	_body.add_child(_jaw)
	_part(_jaw, Vector3(0, -0.05, 0.04), Vector3(0.38, 0.1, 0.34), bone.darkened(0.08))
	for k in 4:
		_part(_jaw, Vector3(-0.12 + k * 0.08, 0.02, 0.2), Vector3(0.04, 0.05, 0.02), Color(0.96, 0.94, 0.85))
	var wax := Color(0.92, 0.86, 0.74)
	for c in [[Vector3(-0.12, 0.3, -0.05), 0.22], [Vector3(0.1, 0.28, 0.06), 0.16], [Vector3(0.02, 0.36, -0.14), 0.3]]:
		var pos: Vector3 = c[0]
		var h: float = c[1]
		_part(_body, pos, Vector3(0.09, h, 0.09), wax)
		_part(_body, pos + Vector3(0.05, h * 0.2, 0), Vector3(0.03, h * 0.6, 0.03), wax.darkened(0.08))  # drip
		_part(_body, pos + Vector3(0, h * 0.5 + 0.07, 0), Vector3(0.06, 0.1, 0.06), accent, true)  # flame
		_part(_body, pos + Vector3(0, h * 0.5 + 0.03, 0), Vector3(0.03, 0.05, 0.03), Color(1, 0.95, 1), true)


## Cave spider: eight long legs, a big round abdomen and a cluster of glowing eyes.
func _build_spider() -> void:
	_body.position.y = 0.42
	_part(_body, Vector3(0, 0, 0.15), Vector3(0.42, 0.28, 0.4), tint)
	_part(_body, Vector3(0, 0.08, -0.35), Vector3(0.62, 0.5, 0.62), tint.darkened(0.08))
	_part(_body, Vector3(0, 0.34, -0.35), Vector3(0.3, 0.04, 0.4), tint.lightened(0.12))
	for p in [Vector3(-0.09, 0.06, 0.36), Vector3(0.09, 0.06, 0.36), Vector3(-0.15, 0.1, 0.33), Vector3(0.15, 0.1, 0.33)]:
		_part(_body, p, Vector3(0.07, 0.07, 0.03), accent, true)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.08, 0.36)
	_body.add_child(_jaw)
	for sx in [-0.07, 0.07]:
		_part(_jaw, Vector3(sx, -0.05, 0.04), Vector3(0.05, 0.12, 0.05), Color(0.2, 0.12, 0.1))
	for side in [-1, 1]:
		for k in 4:
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.2, 0.0, 0.3 - k * 0.15)
			leg.rotation.y = side * (0.4 - k * 0.3)
			_body.add_child(leg)
			_part(leg, Vector3(side * 0.28, 0.12, 0), Vector3(0.5, 0.06, 0.06), tint.darkened(0.15))
			_part(leg, Vector3(side * 0.55, -0.16, 0), Vector3(0.06, 0.56, 0.06), tint.darkened(0.25))
			_legs.append(leg)


## Pumpkin creeper: a carved, glowing pumpkin on a nest of leaves and creeping vines.
func _build_pumpkin() -> void:
	_body.position.y = 0.5
	var orange := tint
	for k in 5:
		var x := -0.36 + k * 0.18
		var h := 0.62 if k in [1, 2, 3] else 0.52
		_part(_body, Vector3(x, 0, 0), Vector3(0.17, h, 0.72 if k in [1, 2, 3] else 0.6), orange.darkened(0.12 if k % 2 else 0.0))
	_part(_body, Vector3(0, 0.36, 0), Vector3(0.1, 0.18, 0.1), Color(0.35, 0.45, 0.18))  # stem
	_part(_body, Vector3(0.12, 0.42, 0.02), Vector3(0.2, 0.04, 0.12), Color(0.36, 0.6, 0.22))  # leaf
	for sx in [-0.16, 0.16]:
		_part(_body, Vector3(sx, 0.08, 0.37), Vector3(0.14, 0.12, 0.02), accent, true)  # eyes
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.12, 0.37)
	_body.add_child(_jaw)
	_part(_jaw, Vector3(0, 0, 0), Vector3(0.36, 0.08, 0.02), accent, true)
	for k in 3:
		_part(_jaw, Vector3(-0.12 + k * 0.12, 0.05, 0.005), Vector3(0.05, 0.05, 0.02), accent, true)
	var vine := Color(0.42, 0.55, 0.2)
	for k in 6:
		var a := TAU * k / 6.0
		var leg := Node3D.new()
		leg.position = Vector3(cos(a) * 0.3, -0.38, sin(a) * 0.3)
		leg.rotation.y = -a
		_body.add_child(leg)
		_part(leg, Vector3(0.3, -0.06, 0), Vector3(0.55, 0.06, 0.08), vine)
		_part(leg, Vector3(0.45, -0.04, 0.08), Vector3(0.2, 0.03, 0.16), vine.lightened(0.15))  # leaf
		_legs.append(leg)


## Acorn sprout: a walking acorn with a cap, a stalk, stubby arms and legs.
func _build_acorn() -> void:
	_body.position.y = 0.42
	var nut := tint
	var cap := accent
	_part(_body, Vector3(0, 0.05, 0), Vector3(0.5, 0.5, 0.46), nut)
	_part(_body, Vector3(0, -0.24, 0), Vector3(0.34, 0.08, 0.32), nut.darkened(0.12))
	_part(_body, Vector3(0, 0.34, 0), Vector3(0.6, 0.18, 0.56), cap)
	_part(_body, Vector3(0, 0.44, 0), Vector3(0.44, 0.06, 0.4), cap.lightened(0.12))
	_part(_body, Vector3(0, 0.52, 0), Vector3(0.06, 0.12, 0.06), cap.darkened(0.2))  # stalk
	for sx in [-0.1, 0.1]:
		_part(_body, Vector3(sx, 0.1, 0.235), Vector3(0.07, 0.09, 0.02), Color(0.98, 0.97, 0.94))
		_part(_body, Vector3(sx, 0.09, 0.245), Vector3(0.04, 0.05, 0.02), Color(0.08, 0.06, 0.06))
	_part(_body, Vector3(0, -0.06, 0.235), Vector3(0.14, 0.04, 0.02), Color(0.25, 0.14, 0.08))  # frown
	for sx in [-1.0, 1.0]:
		_part(_body, Vector3(sx * 0.3, 0.0, 0.05), Vector3(0.08, 0.2, 0.08), nut.darkened(0.2))  # arms
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.13, -0.26, 0)
		_body.add_child(leg)
		_part(leg, Vector3(0, -0.07, 0), Vector3(0.1, 0.16, 0.12), nut.darkened(0.25))
		_legs.append(leg)
