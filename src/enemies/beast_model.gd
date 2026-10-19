class_name BeastModel
extends Node3D
## Blocky non-humanoid monsters: wisp (floating arcane orb), crawler (six-legged
## thorn crawler) and thornmaw (giant crawler boss). Milestone 15 adds the wild
## animals: four-legged wolf, deer and rabbit, a scorpion with a curled tail
## and a sideways-walking crab.

const QUADRUPEDS := [&"wolf", &"deer", &"rabbit", &"fox", &"stag", &"hedgehog", &"cat", &"horse", &"ghost_cat", &"top_hat_bear"]
## Milestone 33: bodies that hop when they move.
const HOPPERS := [&"pumpkin", &"acorn", &"cupcake", &"berry_jelly", &"door_mimic"]
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
## Milestone 32: ear pivots (twitch, prick up, flatten), the front legs of
## spiders (raised before they strike) and the animation state.
var _ears: Array[Node3D] = []
## Milestone 33: serpent segments, parts hidden while asleep (door mimic), the
## float height of ghosts and two-legged walkers (turkey).
var _segments: Array[Node3D] = []
var _sleeping: Array[Node3D] = []
var _awake := true
var _float_y := 0.0
var _biped := false
var _hover := 0.0
var _phase := 0.0
var _move := 0.0
var parts: Array[MeshInstance3D] = []
## Milestone 29: the horse's saddle (shown when it wears one) and its colours.
var _saddle: Node3D


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
	_ears.clear()
	_segments.clear()
	_sleeping.clear()
	_awake = true
	_float_y = 0.0
	_biped = false
	_saddle = null
	_hover = float(HOVER.get(look, 0.0))
	_quad = look in QUADRUPEDS
	_body = Node3D.new()
	add_child(_body)
	match look:
		&"wolf", &"deer", &"rabbit", &"fox", &"stag", &"hedgehog", &"cat", &"horse", &"ghost_cat", &"top_hat_bear":
			_build_quadruped()
		&"bone_dragon":
			_build_bone_dragon()
		&"shadow_serpent":
			_build_serpent()
		&"door_mimic":
			_build_door_mimic()
		&"turkey":
			_build_turkey()
		&"cupcake":
			_build_cupcake()
		&"berry_jelly":
			_build_jelly()
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
	_store_rest()


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
		&"horse": {"body": Vector3(0.62, 0.7, 1.55), "leg": 0.92, "head": Vector3(0.3, 0.34, 0.62)},
		&"ghost_cat": {"body": Vector3(0.32, 0.3, 0.62), "leg": 0.24, "head": Vector3(0.34, 0.3, 0.3)},
		&"top_hat_bear": {"body": Vector3(0.85, 0.8, 1.35), "leg": 0.45, "head": Vector3(0.5, 0.45, 0.45)},
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
				_ear(Vector3(sx, hd.y * 0.95, hd.z * 0.2), Vector3(0.1, 0.18, 0.08), tint.darkened(0.15))
			_jaw = Node3D.new()
			_jaw.position = Vector3(0, 0.0, hd.z * 0.8)
			_head.add_child(_jaw)
			_part(_jaw, Vector3(0, -0.06, 0.12), Vector3(0.18, 0.06, 0.26), light)
		&"deer":
			_part(_head, Vector3(0, hd.y * 0.05, hd.z * 0.9), Vector3(0.2, 0.2, 0.22), tint.darkened(0.1))  # muzzle
			for sx in [-1.0, 1.0]:
				_part(_head, Vector3(sx * 0.12, hd.y * 1.05, hd.z * 0.25), Vector3(0.05, 0.3, 0.05), accent)  # antlers
				_part(_head, Vector3(sx * 0.2, hd.y * 1.25, hd.z * 0.25), Vector3(0.18, 0.05, 0.05), accent)
				_ear(Vector3(sx * 0.2, hd.y * 0.75, hd.z * 0.1), Vector3(0.12, 0.08, 0.05), tint, true)
			_head.position.y += 0.2  # long neck
			_part(_body, Vector3(0, body.y * 0.45, body.z * 0.42), Vector3(0.22, 0.4, 0.22), tint)  # neck
		&"rabbit":
			for sx in [-0.06, 0.06]:
				var ear := _ear(Vector3(sx, hd.y * 1.2, hd.z * 0.1), Vector3(0.06, 0.26, 0.06), tint)  # long ears
				_part(ear, Vector3(0, 0.13, 0.031), Vector3(0.03, 0.2, 0.01), accent)
		&"fox":
			# Ice fox: pointed snout, tall ears with pale insides, white ruff.
			_part(_head, Vector3(0, hd.y * 0.08, hd.z * 0.95), Vector3(0.16, 0.14, 0.26), light)
			_part(_head, Vector3(0, hd.y * 0.12, hd.z * 1.1), Vector3(0.07, 0.06, 0.04), Color(0.15, 0.18, 0.25))
			for sx in [-0.11, 0.11]:
				var ear := _ear(Vector3(sx, hd.y * 1.0, hd.z * 0.15), Vector3(0.11, 0.22, 0.07), tint)
				_part(ear, Vector3(0, 0.09, 0.04), Vector3(0.06, 0.15, 0.02), accent)
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
				_ear(Vector3(sx * 0.2, hd.y * 0.75, hd.z * 0.1), Vector3(0.12, 0.08, 0.05), tint, true)
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
		&"horse":
			# Horse (Milestone 29): long neck, mane in the accent colour, a blaze, and a saddle when tamed.
			_head.position = Vector3(0, body.y * 0.95, body.z * 0.56)
			_head.rotation.x = 0.55
			var neck := _part(_body, Vector3(0, body.y * 0.62, body.z * 0.47), Vector3(0.26, 0.62, 0.3), tint)
			neck.rotation.x = 0.5
			for i in 5:
				var m := _part(_body, Vector3(0, body.y * 0.68 + i * 0.07, body.z * 0.36 + i * 0.065), Vector3(0.1, 0.16, 0.12), accent)
				m.rotation.x = 0.5
			_part(_head, Vector3(0, hd.y * 0.05, hd.z * 0.95), Vector3(0.24, 0.24, 0.2), tint.darkened(0.12))  # muzzle
			_part(_head, Vector3(0, hd.y * 0.62, hd.z * 0.62), Vector3(0.08, 0.06, 0.34), Color(0.95, 0.94, 0.9))  # blaze
			_part(_head, Vector3(0, hd.y * 0.9, hd.z * 0.05), Vector3(0.1, 0.1, 0.14), accent)  # forelock
			for sx in [-0.09, 0.09]:
				_ear(Vector3(sx, hd.y * 1.0, hd.z * -0.05), Vector3(0.07, 0.16, 0.06), tint.darkened(0.08))
			_saddle = Node3D.new()
			_saddle.position = Vector3(0, body.y * 0.5, -0.05)
			_body.add_child(_saddle)
			var leather := Color(0.42, 0.24, 0.12)
			_part(_saddle, Vector3(0, 0.04, 0), Vector3(body.x + 0.06, 0.1, 0.62), leather)
			_part(_saddle, Vector3(0, 0.12, 0.26), Vector3(0.3, 0.14, 0.1), leather.darkened(0.15))  # pommel
			_part(_saddle, Vector3(0, 0.12, -0.27), Vector3(0.42, 0.12, 0.08), leather.darkened(0.15))  # cantle
			_part(_saddle, Vector3(0, -0.05, 0), Vector3(body.x + 0.1, 0.06, 0.7), Color(0.65, 0.18, 0.16))  # blanket
			for sx in [-1.0, 1.0]:
				_part(_saddle, Vector3(sx * (body.x * 0.5 + 0.05), -0.32, 0.04), Vector3(0.03, 0.5, 0.05), leather.darkened(0.3))
				_part(_saddle, Vector3(sx * (body.x * 0.5 + 0.06), -0.58, 0.04), Vector3(0.06, 0.06, 0.12), Color(0.7, 0.7, 0.72))  # stirrup
			_saddle.visible = false
		&"cat":
			# Witch cat: pointed ears and a crooked purple witch hat.
			for sx in [-0.11, 0.11]:
				_ear(Vector3(sx, hd.y * 0.95, hd.z * 0.2), Vector3(0.1, 0.16, 0.06), tint)
			_part(_head, Vector3(0, hd.y * 0.15, hd.z * 0.95), Vector3(0.14, 0.1, 0.1), tint.lightened(0.1))
			var hat := Color(0.36, 0.2, 0.46)
			_part(_head, Vector3(0, hd.y * 0.98, hd.z * 0.3), Vector3(0.5, 0.05, 0.46), hat)
			_part(_head, Vector3(0, hd.y * 1.16, hd.z * 0.3), Vector3(0.24, 0.3, 0.24), hat)
			_part(_head, Vector3(0, hd.y * 1.04, hd.z * 0.3), Vector3(0.25, 0.06, 0.25), Color(0.85, 0.65, 0.2))
			var tip := _part(_head, Vector3(0.06, hd.y * 1.5, hd.z * 0.2), Vector3(0.14, 0.18, 0.14), hat)
			tip.rotation.z = -0.5
			for sx in [-0.07, 0.07]:
				_part(_head, Vector3(sx, hd.y * 0.62, hd.z * 0.85), Vector3(0.07, 0.07, 0.02), Color(0.2, 0.08, 0.15))
		&"ghost_cat":
			# Ghost cat (Milestone 33): pointed ears, a pale nose and a ghostly frill instead of a hat.
			for sx in [-0.11, 0.11]:
				_ear(Vector3(sx, hd.y * 0.95, hd.z * 0.2), Vector3(0.1, 0.16, 0.06), tint)
			_part(_head, Vector3(0, hd.y * 0.15, hd.z * 0.95), Vector3(0.14, 0.1, 0.1), tint.lightened(0.2))
			_part(_body, Vector3(0, body.y * 0.1, body.z * 0.45), Vector3(body.x * 1.1, 0.12, 0.12), accent, true)  # glowing collar
		&"top_hat_bear":
			# Top-hat bear (Milestone 33): round ears, a muzzle, a black top hat, a monocle and a bow tie.
			_part(_head, Vector3(0, hd.y * 0.1, hd.z * 0.95), Vector3(0.26, 0.2, 0.22), tint.lightened(0.25))  # muzzle
			_part(_head, Vector3(0, hd.y * 0.22, hd.z * 1.12), Vector3(0.12, 0.08, 0.04), Color(0.08, 0.06, 0.06))  # nose
			for sx in [-0.17, 0.17]:
				_ear(Vector3(sx, hd.y * 0.85, hd.z * 0.15), Vector3(0.13, 0.12, 0.07), tint.darkened(0.12))
			var black := Color(0.08, 0.08, 0.1)
			_part(_head, Vector3(0, hd.y * 0.95, hd.z * 0.3), Vector3(0.5, 0.04, 0.44), black)  # brim
			_part(_head, Vector3(0, hd.y * 1.35, hd.z * 0.3), Vector3(0.32, 0.38, 0.3), black)  # crown
			_part(_head, Vector3(0, hd.y * 1.06, hd.z * 0.3), Vector3(0.33, 0.07, 0.31), accent)  # band
			_part(_head, Vector3(0.12, hd.y * 0.5, hd.z * 0.88), Vector3(0.13, 0.13, 0.02), Color(0.95, 0.8, 0.3))  # monocle rim
			_part(_head, Vector3(0.12, hd.y * 0.5, hd.z * 0.89), Vector3(0.08, 0.08, 0.02), Color(0.7, 0.85, 0.95))  # glass
			_part(_head, Vector3(0.2, hd.y * 0.15, hd.z * 0.8), Vector3(0.02, 0.32, 0.02), Color(0.95, 0.8, 0.3))  # chain
			_jaw = Node3D.new()
			_jaw.position = Vector3(0, 0.0, hd.z * 0.9)
			_head.add_child(_jaw)
			_part(_jaw, Vector3(0, -0.06, 0.08), Vector3(0.22, 0.06, 0.2), tint.lightened(0.15))
			for sx in [-1.0, 1.0]:
				_part(_body, Vector3(sx * 0.11, body.y * 0.3, body.z * 0.5), Vector3(0.16, 0.12, 0.06), Color(0.8, 0.1, 0.12))  # bow tie
			_part(_body, Vector3(0, body.y * 0.3, body.z * 0.51), Vector3(0.06, 0.08, 0.06), Color(0.6, 0.05, 0.08))
	var eye := Color(0.08, 0.08, 0.1)
	for sx in [-0.06, 0.06]:
		if look in [&"cat", &"ghost_cat"]:
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
		&"horse":
			_tail.rotation.x = 0.35
			_part(_tail, Vector3(0, -0.12, -0.1), Vector3(0.14, 0.3, 0.16), accent)
			_part(_tail, Vector3(0, -0.42, -0.16), Vector3(0.16, 0.42, 0.14), accent.darkened(0.08))
		&"top_hat_bear":
			_part(_tail, Vector3(0, 0, -0.06), Vector3(0.16, 0.16, 0.12), tint.darkened(0.1))
		&"cat", &"ghost_cat":
			_tail.rotation.x = -0.9
			_part(_tail, Vector3(0, 0, -0.22), Vector3(0.07, 0.07, 0.44), tint)
			_part(_tail, Vector3(0, 0, -0.46), Vector3(0.07, 0.07, 0.07), tint.lightened(0.15))
	var leg_w := 0.22 if look == &"top_hat_bear" else 0.1 if look in [&"rabbit", &"hedgehog", &"cat", &"ghost_cat"] else (0.12 if look in [&"deer", &"stag", &"fox"] else (0.17 if look == &"horse" else 0.15))
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


## Milestone 32: an ear on a pivot at its base, so it can twitch, prick up and flatten.
## `side`: the ear sticks out sideways (deer, stag) instead of up.
func _ear(pos: Vector3, size: Vector3, color: Color, side: bool = false) -> Node3D:
	var pivot := Node3D.new()
	var sx := signf(pos.x) if pos.x != 0.0 else 1.0
	if side:
		pivot.position = pos - Vector3(sx * size.x * 0.5, 0, 0)
		_part(pivot, Vector3(sx * size.x * 0.5, 0, 0), size, color)
	else:
		pivot.position = pos - Vector3(0, size.y * 0.5, 0)
		_part(pivot, Vector3(0, size.y * 0.5, 0), size, color)
	pivot.set_meta(&"side", sx)
	pivot.set_meta(&"sideways", side)
	_head.add_child(pivot)
	_ears.append(pivot)
	return pivot


## Horses: show or hide the saddle.
func set_saddle(on: bool) -> void:
	if _saddle:
		_saddle.visible = on


func set_locomotion(speed_ratio: float, delta: float) -> void:
	_move = lerpf(_move, clampf(speed_ratio, 0.0, 1.5), 1.0 - exp(-10.0 * delta))


# --- Milestone 32: animation ----------------------------------------------------------
# The body moves procedurally every frame (walk cycle, breathing, wings, tails,
# ears); attacks, hurts and the hit frame add offsets on top through tweens, so
# the two never fight. Death stops the procedural part and tweens the body down.

## A wind-up at least this long is a "big" attack: a deeper crouch, flattened ears.
const BIG_WINDUP := 0.5

var _lean := 0.0       # body pitch (negative = front up / rearing back)
var _lunge := 0.0      # body forward offset (m)
var _hop := 0.0        # body up offset (m)
var _head_off := 0.0   # head pitch
var _jaw_open := 0.0   # jaw / claws / pincers
var _tail_off := 0.0   # tail pitch (scorpion sting)
var _front_raise := 0.0  # spider front legs
var _squash := 1.0     # body height scale (wide when < 1)
var _ear_mood := 0.0   # -1 flat, 0 relaxed, 1 pricked up
var _mood_t := 0.0
var _twitch_i := -1
var _twitch := 0.0
var _twitch_t := 1.0
var _beat_mult := 1.0  # wing beat speed
var _dead := false
var _atk_tween: Tween
var _hit_tween: Tween
var _rest := {}  # node -> Transform3D at build time
var _rest_rot := {}  # node -> rotation at build time
var _rest_y := 0.0
## Milliseconds when the last attack's strike pose was reached / is due, and the
## last hit frame (tests check they match).
var strike_ms := 0
var last_hit_ms := 0


## Remembers the built pose of the moving parts (reset_pose goes back to it).
func _store_rest() -> void:
	_rest.clear()
	_rest_rot.clear()
	for n: Node3D in [_body, _head, _jaw, _tail, _orbit] + Array(_legs) + Array(_wings) + Array(_ears) + Array(_segments):
		if n:
			_rest[n] = n.transform
			_rest_rot[n] = n.rotation
	_rest_y = _body.position.y
	_twitch_t = randf_range(0.5, 2.5)
	if look == &"ghost_cat":
		for p in parts:
			p.transparency = 0.45


func _rest_of(n: Node3D) -> Transform3D:
	return _rest.get(n, Transform3D.IDENTITY)


## The built rotation of a part (Euler angles).
func _rr(n: Node3D) -> Vector3:
	return _rest_rot.get(n, Vector3.ZERO)


func _process(delta: float) -> void:
	if _body == null or _dead or _rest.is_empty():
		return
	if not _awake:
		return  # a sleeping door mimic is just a door
	_phase += delta * (3.0 + 12.0 * _move)
	_animate_ears(delta)
	if not _segments.is_empty():
		_animate_serpent()
		return
	if _biped:
		_animate_biped()
		return
	if _orbit:
		_orbit.rotation.y += delta * 2.5 * _beat_mult
		_body.position = Vector3(0, 1.3 + sin(_phase * 0.6) * 0.15 + _hop, _lunge)
		_body.scale = Vector3.ONE * (2.0 - _squash)
		return
	if _hover > 0.0:
		# Flyers bob and beat their wings (faster while winding up); the candle skull sways.
		_body.position = Vector3(0, _hover + sin(_phase * 0.5) * 0.12 + _hop, _lunge)
		var beat := (26.0 if look == &"bee" else 7.0) * _beat_mult
		var amp := 0.6 if look == &"bee" else 0.55
		for w in _wings:
			var side := -1.0 if w.position.x < 0.0 else 1.0
			w.rotation.z = _rr(w).z + side * sin(Time.get_ticks_msec() / 1000.0 * beat) * amp
		_body.rotation = Vector3(_lean, 0, sin(_phase * 0.4) * 0.06)
		if _tail:
			_tail.rotation.x = _rr(_tail).x + sin(_phase * 0.5) * 0.15 + _tail_off
		if _jaw:
			_jaw.rotation.x = _jaw_open
		return
	var m := minf(_move, 1.0)
	var bob := 0.0
	if look in HOPPERS:
		bob = absf(sin(_phase * 0.5)) * 0.18 * m  # Milestone 33: hops along
	if _float_y > 0.0:
		bob = _float_y + sin(_phase * 0.3) * 0.06  # ghosts float
	_body.position = Vector3(0, _rest_y + _hop + bob, _lunge)
	if _quad:
		# Gallop: diagonal legs together, the body bobs and the tail sways (even standing still).
		for i in _legs.size():
			var off := 0.0 if i in [0, 3] else PI
			_legs[i].rotation = Vector3(sin(_phase + off) * 0.7 * m, 0, 0)
		_body.rotation = Vector3(sin(_phase * 2.0) * 0.04 * m + _lean, 0, 0)
		_body.scale = Vector3(2.0 - _squash, _squash + sin(_phase * 0.25) * 0.02 * (1.0 - m), 2.0 - _squash)
		if _tail:
			var tr := _rr(_tail)
			_tail.rotation = Vector3(tr.x + _tail_off + sin(_phase * 0.35) * 0.05, sin(_phase * 0.7) * (0.2 + 0.3 * m), 0)
		if _head:
			var hr := _rr(_head)
			_head.rotation = Vector3(hr.x + sin(_phase * 0.3) * 0.08 * (1.0 - m) + _head_off, sin(_phase * 0.13) * 0.12 * (1.0 - m), 0)
		if _jaw:
			_jaw.rotation.x = _jaw_open
		for w in _wings:
			# Bone dragon: folded wings that stir, and spread before an attack.
			var ws := -1.0 if w.position.x < 0.0 else 1.0
			w.rotation.z = _rr(w).z + ws * (sin(_phase * 0.4) * 0.12 + (_beat_mult - 1.0) * 0.4)
		return
	for i in _legs.size():
		var lr := _rr(_legs[i])
		var side := -1.0 if _legs[i].position.x < 0.0 else 1.0
		var raise := _front_raise * side if (look == &"spider" and i % 4 == 0) else 0.0
		# Lift each leg on its forward swing (Milestone 10).
		_legs[i].rotation = Vector3(lr.x, lr.y + sin(_phase + i * 1.3) * 0.5 * m,
			lr.z + maxf(0.0, sin(_phase + i * 1.3 + 1.57)) * 0.35 * m * side + raise)
	_body.rotation = Vector3(_lean, 0, sin(_phase) * 0.04 * m)
	_body.scale = Vector3(2.0 - _squash, _squash * (1.0 + sin(_phase * 0.25) * 0.03 * (1.0 - m)), 2.0 - _squash)
	if _jaw:
		_jaw.rotation.x = _jaw_open
	if _head:
		_head.rotation.x = _rr(_head).x + _head_off
	if _tail:
		var tr2 := _rr(_tail)
		_tail.rotation = Vector3(tr2.x + _tail_off + sin(_phase * 0.4) * 0.08, sin(_phase * 0.23) * 0.15, 0)


## Milestone 33: the serpent slithers in a wave; the head rears up before it strikes.
func _animate_serpent() -> void:
	var m := minf(_move, 1.0)
	var amp := 0.06 + 0.16 * m
	for k in _segments.size():
		var seg := _segments[k]
		var rest := _rest_of(seg).origin
		seg.position = Vector3(sin(_phase * 0.7 - k * 0.75) * amp, rest.y, rest.z)
		seg.rotation.y = cos(_phase * 0.7 - k * 0.75) * amp * 1.5
	_body.position = Vector3(0, _rest_y, 0)
	_body.scale = Vector3(2.0 - _squash, _squash, 2.0 - _squash)
	var hr := _rest_of(_head).origin
	var rear := maxf(0.0, -_lean) * 1.4
	_head.position = Vector3(_segments[0].position.x, hr.y + rear + _hop, hr.z + _lunge - rear * 0.4)
	_head.rotation = Vector3(_rr(_head).x + _head_off + _lean * 0.6, sin(_phase * 0.2) * 0.2, 0)
	if _jaw:
		_jaw.rotation.x = _jaw_open


## Milestone 33: two-legged walk (turkey): legs swing in turn, the head bobs and
## pecks, the fan tail opens before an attack.
func _animate_biped() -> void:
	var m := minf(_move, 1.0)
	for i in _legs.size():
		_legs[i].rotation = Vector3(sin(_phase + i * PI) * 0.6 * m, 0, 0)
	_body.position = Vector3(0, _rest_y + _hop + absf(sin(_phase)) * 0.04 * m, _lunge)
	_body.rotation = Vector3(_lean, 0, sin(_phase) * 0.05 * m)
	_body.scale = Vector3(2.0 - _squash, _squash, 2.0 - _squash)
	if _head:
		var peck := maxf(0.0, sin(_phase * 0.35)) * 0.5 * (1.0 - m)
		_head.rotation.x = _rr(_head).x + peck + sin(_phase * 2.0) * 0.08 * m + _head_off
		_head.position.z = _rest_of(_head).origin.z + sin(_phase * 2.0) * 0.04 * m
	if _tail:
		var fan := 1.0 + maxf(0.0, -_tail_off) * 0.6
		_tail.scale = Vector3(fan, fan, 1.0)
		_tail.rotation = Vector3(_rr(_tail).x + _tail_off * 0.3, sin(_phase * 0.3) * 0.1, 0)


## Ears relax, twitch now and then, prick up before an attack and flatten when hurt.
func _animate_ears(delta: float) -> void:
	if _ears.is_empty():
		return
	if _mood_t > 0.0:
		_mood_t -= delta
		if _mood_t <= 0.0:
			_ear_mood = 0.0
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(1.2, 3.5)
		_twitch_i = randi() % _ears.size()
		_twitch = 0.6
	_twitch = move_toward(_twitch, 0.0, delta * 4.0)
	var k := 1.0 - exp(-14.0 * delta)
	for i in _ears.size():
		var e := _ears[i]
		var er := _rr(e)
		var tw := _twitch if i == _twitch_i else 0.0
		# Up ears tip back (flat) or forward (pricked); side ears droop or lift.
		var side: float = e.get_meta(&"side", 1.0)
		var tx := er.x
		var tz := er.z + side * tw * 0.3
		if e.get_meta(&"sideways", false):
			tz += side * (-0.5 if _ear_mood < 0.0 else 0.2 * _ear_mood)
		else:
			tx += (-0.9 if _ear_mood < 0.0 else 0.25 * _ear_mood) - tw * 0.5 - _move * 0.15
		e.rotation = Vector3(lerpf(e.rotation.x, tx, k), 0, lerpf(e.rotation.z, tz, k))


func _set_mood(mood: float, seconds: float) -> void:
	_ear_mood = mood
	_mood_t = seconds


func play_attack(_anim: StringName, windup: float, active: float, recovery: float) -> void:
	if _dead:
		return
	if not _awake:
		set_awake(true)  # a door mimic that attacks is awake
	var big := windup >= BIG_WINDUP
	strike_ms = Time.get_ticks_msec() + int(windup * 1000.0)
	_set_mood(-1.0 if big else 1.0, windup + active + recovery)
	if _atk_tween and _atk_tween.is_valid():
		_atk_tween.kill()
	var tw := create_tween()
	_atk_tween = tw
	var deep := 2.0 if big else 1.0
	# 1) Wind-up: crouch and rear back. 2) Strike (the hit frame). 3) Recover.
	var wind := {}
	var hit := {}
	if look == &"scorpion":
		wind = {"_tail_off": -0.5 * deep, "_jaw_open": -0.35, "_lean": -0.08 * deep}
		hit = {"_tail_off": 0.9, "_jaw_open": 0.25, "_lunge": 0.15}
	elif _orbit:
		wind = {"_squash": 0.8, "_hop": 0.15 * deep}
		hit = {"_squash": 1.35, "_lunge": 0.35}
		_beat_mult = 3.0
	elif _hover > 0.0:
		wind = {"_lunge": -0.3 * deep, "_hop": 0.15 * deep, "_lean": -0.25, "_jaw_open": -0.4}
		hit = {"_lunge": 0.6, "_hop": -0.15, "_lean": 0.35, "_jaw_open": 0.2}
		_beat_mult = 1.8
	elif look == &"spider":
		wind = {"_front_raise": 0.9, "_lean": -0.25 * deep, "_lunge": -0.1, "_jaw_open": -0.4}
		hit = {"_front_raise": -0.2, "_lean": 0.2, "_lunge": 0.3, "_jaw_open": 0.4}
	elif look == &"crab":
		wind = {"_jaw_open": -0.8 * deep, "_squash": 0.92, "_lunge": -0.05}
		hit = {"_jaw_open": 0.4, "_squash": 1.05, "_lunge": 0.2}
	elif look == &"shadow_serpent":
		wind = {"_lean": -0.5 * deep, "_jaw_open": 0.5, "_lunge": -0.1}
		hit = {"_lean": 0.1, "_jaw_open": 0.1, "_lunge": 0.6}
	elif look == &"door_mimic":
		# The top half swings open like a mouth, then it lunges and slams shut.
		wind = {"_head_off": -0.8 * deep, "_jaw_open": 0.4, "_squash": 0.92}
		hit = {"_head_off": 0.05, "_jaw_open": 0.0, "_lunge": 0.45, "_hop": 0.25, "_squash": 1.05}
	elif look == &"turkey":
		wind = {"_tail_off": -0.9, "_lean": -0.25, "_head_off": -0.4}
		hit = {"_tail_off": -0.6, "_lean": 0.3, "_head_off": 0.7, "_lunge": 0.3}
	elif look in [&"pumpkin", &"acorn", &"cupcake", &"berry_jelly"]:
		wind = {"_squash": 0.7 if big else 0.8, "_lean": -0.1}
		hit = {"_squash": 1.15, "_hop": 0.3, "_lunge": 0.35, "_lean": 0.2}
	elif _quad and look in [&"deer", &"stag", &"horse", &"top_hat_bear"]:
		# Antler butt / rear up and stamp.
		wind = {"_head_off": -0.35 * deep, "_lean": -0.2 * deep, "_lunge": -0.1}
		hit = {"_head_off": 0.55, "_lean": 0.12, "_lunge": 0.35}
	elif _quad and look in [&"rabbit", &"hedgehog"]:
		wind = {"_squash": 0.75, "_lunge": -0.05}
		hit = {"_squash": 1.15, "_hop": 0.25, "_lunge": 0.35}
	elif _quad:
		# Wolf, fox, cat: head back and jaws open, then the snap.
		wind = {"_head_off": -0.4, "_jaw_open": 0.5, "_lean": -0.12 * deep, "_squash": 0.9, "_lunge": -0.12 * deep}
		hit = {"_head_off": 0.3, "_jaw_open": 0.0, "_lean": 0.1, "_squash": 1.0, "_lunge": 0.4}
	elif _jaw:
		# Crawler, thornmaw: rear back, jaws wide, lunge.
		wind = {"_jaw_open": -0.6, "_lean": -0.15 * deep, "_lunge": -0.12 * deep, "_squash": 0.9}
		hit = {"_jaw_open": 0.3, "_lean": 0.12, "_lunge": 0.35, "_squash": 1.05}
	else:
		wind = {"_squash": 0.8}
		hit = {"_squash": 1.3}
	# Milestone 38: the measured swing shape. Big attacks rear back early and hang
	# there (the "hold"); the strike snaps in 2-3 frames, carries on past the pose
	# (follow-through) and settles back to it.
	if big:
		_tween_props(tw, wind, windup * 0.55, Tween.TRANS_SINE, Tween.EASE_OUT)
		tw.tween_interval(windup * 0.45)
	else:
		_tween_props(tw, wind, windup, Tween.TRANS_SINE, Tween.EASE_OUT)
	var snap := minf(maxf(active, 0.05), CombatFeel.sec(CombatFeel.HEAVY_STRIKE_FRAMES if big else CombatFeel.STRIKE_FRAMES))
	var over := {}
	for k: String in hit:
		var rest := 1.0 if k == "_squash" else 0.0
		over[k] = float(hit[k]) + (float(hit[k]) - rest) * (CombatFeel.HEAVY_OVERSHOOT if big else CombatFeel.OVERSHOOT)
	_tween_props(tw, over, snap, Tween.TRANS_LINEAR, Tween.EASE_IN)
	_tween_props(tw, hit, maxf(active - snap, 0.06), Tween.TRANS_QUAD, Tween.EASE_OUT)
	var back := {}
	for k in wind.keys() + hit.keys():
		back[k] = 1.0 if k == "_squash" else 0.0
	_tween_props(tw, back, maxf(recovery, 0.1), Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _beat_mult = 1.0)


## One step of a tween that moves several offsets together.
func _tween_props(tw: Tween, props: Dictionary, time: float, trans: int, ease: int) -> void:
	var first := true
	for k: String in props:
		var t := tw.tween_property(self, k, props[k], time) if first else tw.parallel().tween_property(self, k, props[k], time)
		t.set_trans(trans).set_ease(ease)
		first = false
	if first:
		tw.tween_interval(time)


## The moment the attack's damage lands: a short impact jolt.
func on_hit_frame() -> void:
	last_hit_ms = Time.get_ticks_msec()
	if _dead:
		return
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "scale", Vector3(1.08, 0.92, 1.08), 0.04)
	_hit_tween.tween_property(self, "scale", Vector3.ONE, 0.12)


## Hurt: the body jerks away from the blow, the ears flatten and the tail tucks.
func play_flinch(strength: float, side: float) -> void:
	if _dead:
		return
	if not _awake:
		set_awake(true)
	_set_mood(-1.0, 0.7)
	var s := clampf(strength, 0.3, 1.5)
	var tw := create_tween()
	tw.tween_property(self, "rotation", Vector3(-0.3 * s, 0.0, side * 0.2 * s), 0.07).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_head_off", -0.35 * s, 0.07)
	tw.parallel().tween_property(self, "_tail_off", 0.35 * s, 0.07)
	tw.tween_property(self, "rotation", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(self, "_head_off", 0.0, 0.28)
	tw.parallel().tween_property(self, "_tail_off", 0.0, 0.28)


## Death: four-legged animals topple onto their side, crawlers flip over and curl
## their legs, flyers drop out of the air, the wisp fades away.
func play_death() -> void:
	_dead = true
	if _atk_tween and _atk_tween.is_valid():
		_atk_tween.kill()
	var tw := create_tween()
	var side := -1.0 if randf() < 0.5 else 1.0
	if _orbit:
		tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	elif _hover > 0.0:
		for w in _wings:
			tw.parallel().tween_property(w, "rotation:z", 1.2 if w.position.x > 0.0 else -1.2, 0.3)
		tw.parallel().tween_property(_body, "position:y", 0.25, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_body, "rotation:z", side * 1.3, 0.45)
	elif look == &"door_mimic":
		tw.tween_property(self, "rotation:x", -PI * 0.5, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	elif _quad or _biped:
		tw.tween_property(self, "rotation:z", side * PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "position:y", -0.08, 0.45)
		for i in _legs.size():
			tw.parallel().tween_property(_legs[i], "rotation:x", 0.35 if i < 2 else -0.35, 0.4)
		if _head:
			tw.parallel().tween_property(_head, "rotation:x", _rr(_head).x + 0.3, 0.4)
		if _jaw:
			tw.parallel().tween_property(_jaw, "rotation:x", 0.4, 0.4)
	elif look in [&"pumpkin", &"acorn", &"cupcake", &"berry_jelly"]:
		tw.tween_property(_body, "scale", Vector3(1.25, 0.25, 1.25), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_body, "rotation:z", side * 0.3, 0.45)
	else:
		# Flip over, legs curled up.
		tw.tween_property(_body, "position:y", _rest_y + 0.35, 0.18).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_body, "rotation:z", side * PI, 0.4)
		tw.tween_property(_body, "position:y", _rest_y + 0.1, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		for leg in _legs:
			var ls := -1.0 if leg.position.x < 0.0 else 1.0
			tw.parallel().tween_property(leg, "rotation:z", _rr(leg).z - ls * 0.9, 0.35)
		if _tail:
			tw.parallel().tween_property(_tail, "rotation:x", _rr(_tail).x + 0.8, 0.35)


func reset_pose() -> void:
	_dead = false
	for t in [_atk_tween, _hit_tween]:
		if t and t.is_valid():
			t.kill()
	_lean = 0.0
	_lunge = 0.0
	_hop = 0.0
	_head_off = 0.0
	_jaw_open = 0.0
	_tail_off = 0.0
	_front_raise = 0.0
	_squash = 1.0
	_ear_mood = 0.0
	_beat_mult = 1.0
	transform = Transform3D.IDENTITY
	for n: Node3D in _rest:
		if is_instance_valid(n):
			n.transform = _rest[n]


## Wolf howl: head thrown back for a moment (Milestone 15).
func play_howl(duration: float = 0.9) -> void:
	if _head == null:
		return
	var tw := create_tween()
	tw.tween_property(self, "_head_off", -0.9, 0.2)
	tw.tween_interval(maxf(duration - 0.45, 0.1))
	tw.tween_property(self, "_head_off", 0.0, 0.25)


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


# --- Milestone 33: more creatures (our own designs in the style of the owner's sheets) ---

## Bone dragon: a skeletal dragon - ribcage, a long neck of vertebrae, a horned skull
## with glowing eyes, bony wings with torn dark membranes and a whip of a tail.
func _build_bone_dragon() -> void:
	_quad = true
	var bone := tint
	var dark := tint.darkened(0.35)
	var leg_len := 0.9
	_body.position.y = leg_len + 0.35
	_part(_body, Vector3(0, 0.25, 0), Vector3(0.18, 0.14, 1.9), bone)  # spine
	for k in 6:
		var z := 0.6 - k * 0.22
		for sx in [-1.0, 1.0]:
			var rib := _part(_body, Vector3(sx * 0.3, 0.0, z), Vector3(0.08, 0.55, 0.08), bone)
			rib.rotation.z = sx * 0.35
		_part(_body, Vector3(0, -0.28, z), Vector3(0.52, 0.06, 0.08), dark)
	_part(_body, Vector3(0, 0.0, -0.75), Vector3(0.7, 0.3, 0.4), bone)  # hips
	_part(_body, Vector3(0, -0.02, 0.0), Vector3(0.3, 0.3, 0.3), accent, true)  # soul fire in the ribs
	# Neck: vertebrae rising to the skull.
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.3, 0.9)
	_body.add_child(neck)
	for k in 4:
		_part(neck, Vector3(0, k * 0.17, k * 0.15), Vector3(0.2 - k * 0.01, 0.16, 0.16), bone)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.75, 0.62)
	neck.add_child(_head)
	_part(_head, Vector3(0, 0.05, 0.15), Vector3(0.42, 0.34, 0.55), bone)  # skull
	_part(_head, Vector3(0, -0.02, 0.5), Vector3(0.3, 0.2, 0.35), bone)  # snout
	for sx in [-1.0, 1.0]:
		_part(_head, Vector3(sx * 0.12, 0.12, 0.38), Vector3(0.1, 0.08, 0.04), accent, true)  # eyes
		var horn := _part(_head, Vector3(sx * 0.16, 0.3, -0.1), Vector3(0.08, 0.38, 0.08), dark)
		horn.rotation.x = -0.7
		horn.rotation.z = sx * 0.25
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.14, 0.2)
	_head.add_child(_jaw)
	_part(_jaw, Vector3(0, -0.04, 0.3), Vector3(0.26, 0.08, 0.5), bone)
	for k in 4:
		_part(_jaw, Vector3(-0.09 + (k % 2) * 0.18, 0.04, 0.15 + k * 0.1), Vector3(0.04, 0.08, 0.04), Color(0.98, 0.96, 0.9))
	# Wings: finger bones with torn membranes.
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.25, 0.3, 0.35)
		_body.add_child(w)
		_part(w, Vector3(sx * 0.55, 0.15, 0), Vector3(1.1, 0.08, 0.08), bone)
		for f in 3:
			var fb := _part(w, Vector3(sx * (0.5 + f * 0.25), -0.15, -0.25 - f * 0.12), Vector3(0.06, 0.06, 0.7 - f * 0.12), bone)
			fb.rotation.y = sx * (0.3 + f * 0.25)
		var mem := _part(w, Vector3(sx * 0.6, 0.0, -0.35), Vector3(0.95, 0.03, 0.6), Color(0.18, 0.12, 0.22))
		mem.rotation.z = sx * -0.15
		_wings.append(w)
	# Tail.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.15, -0.95)
	_body.add_child(_tail)
	for k in 6:
		_part(_tail, Vector3(0, -k * 0.05, -0.2 - k * 0.24), Vector3(0.16 - k * 0.018, 0.14 - k * 0.012, 0.22), bone)
	_part(_tail, Vector3(0, -0.32, -1.68), Vector3(0.28, 0.06, 0.2), dark)  # tail blade
	for fz in [0.55, -0.7]:
		for sx in [-0.32, 0.32]:
			var leg := Node3D.new()
			leg.position = Vector3(sx, -0.1, fz)
			_body.add_child(leg)
			_part(leg, Vector3(0, -leg_len * 0.45, 0), Vector3(0.12, leg_len * 0.9, 0.12), bone)
			_part(leg, Vector3(0, -leg_len * 0.95, 0.08), Vector3(0.26, 0.08, 0.3), dark)  # claws
			_legs.append(leg)


## Shadow serpent: a long snake of dark segments that slithers in a wave, purple
## belly, glowing eyes and a hood that flares when it strikes.
func _build_serpent() -> void:
	_body.position.y = 0.2
	var n := 9
	for k in n:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0, -k * 0.28)
		_body.add_child(seg)
		var w := 0.34 - absf(k - 2.0) * 0.025
		_part(seg, Vector3.ZERO, Vector3(w, 0.26 - k * 0.012, 0.3), tint if k % 2 == 0 else tint.lightened(0.08))
		_part(seg, Vector3(0, -0.1, 0), Vector3(w * 0.8, 0.06, 0.28), accent.darkened(0.3))  # belly
		if k % 3 == 1:
			_part(seg, Vector3(0, 0.14, 0), Vector3(0.1, 0.04, 0.12), accent, true)  # glowing scale
		_segments.append(seg)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.12, 0.25)
	_body.add_child(_head)
	_part(_head, Vector3(0, 0.05, 0.12), Vector3(0.36, 0.22, 0.38), tint.darkened(0.15))
	for sx in [-1.0, 1.0]:
		_part(_head, Vector3(sx * 0.12, 0.13, 0.25), Vector3(0.07, 0.05, 0.05), accent, true)
		_ear(Vector3(sx * 0.22, 0.05, -0.02), Vector3(0.22, 0.3, 0.04), tint.darkened(0.25), true)  # hood flaps
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.04, 0.05)
	_head.add_child(_jaw)
	_part(_jaw, Vector3(0, -0.04, 0.16), Vector3(0.28, 0.06, 0.3), accent.darkened(0.4))
	_part(_jaw, Vector3(0, -0.02, 0.36), Vector3(0.04, 0.02, 0.12), Color(0.9, 0.2, 0.3))  # forked tongue


## Door mimic: an old dungeon door with iron bands. Awake, it opens a toothy mouth
## down the middle, rolls a red tongue and shows yellow eyes; it hops after you.
func _build_door_mimic() -> void:
	_body.position.y = 0.0
	var wood := tint
	var iron := Color(0.3, 0.3, 0.33)
	# Lower half (fixed) and upper half (the "head", hinged at the back so it opens like a mouth).
	_part(_body, Vector3(0, 0.55, 0), Vector3(1.3, 1.1, 0.24), wood)
	_part(_body, Vector3(0, 0.3, 0.13), Vector3(1.34, 0.1, 0.04), iron)
	_part(_body, Vector3(0.45, 0.75, 0.14), Vector3(0.1, 0.1, 0.06), Color(0.75, 0.6, 0.25))  # handle
	for k in 5:
		_sleeping.append(_part(_body, Vector3(-0.5 + k * 0.25, 1.08, 0.1), Vector3(0.08, 0.14, 0.08), Color(0.97, 0.94, 0.85)))  # lower teeth
	_head = Node3D.new()
	_head.position = Vector3(0, 1.1, -0.12)
	_body.add_child(_head)
	_part(_head, Vector3(0, 0.55, 0.12), Vector3(1.3, 1.1, 0.24), wood.darkened(0.06))
	_part(_head, Vector3(0, 0.85, 0.25), Vector3(1.34, 0.1, 0.04), iron)
	_part(_head, Vector3(0, 1.12, 0.12), Vector3(1.0, 0.1, 0.26), wood.darkened(0.15))  # rounded top
	for k in 5:
		_sleeping.append(_part(_head, Vector3(-0.5 + k * 0.25, 0.02, 0.22), Vector3(0.08, 0.14, 0.08), Color(0.97, 0.94, 0.85)))  # upper teeth
	var eyes := Node3D.new()
	_head.add_child(eyes)
	for sx in [-0.3, 0.3]:
		_part(eyes, Vector3(sx, 0.55, 0.25), Vector3(0.18, 0.12, 0.02), Color(1, 0.85, 0.2), true)
	_sleeping.append(eyes)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 1.05, 0.0)
	_body.add_child(_jaw)
	var tongue := _part(_jaw, Vector3(0, 0.0, 0.25), Vector3(0.3, 0.06, 0.5), Color(0.85, 0.2, 0.3))
	_sleeping.append(tongue)
	for sx in [-0.42, 0.42]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.05, 0)
		_body.add_child(leg)
		_part(leg, Vector3(0, -0.02, 0.05), Vector3(0.22, 0.1, 0.3), iron)  # iron feet
		_legs.append(leg)
	set_awake(false)


## Turkey: a round bird on two legs with a fan tail that opens in a display.
func _build_turkey() -> void:
	_biped = true
	_body.position.y = 0.5
	_part(_body, Vector3.ZERO, Vector3(0.5, 0.5, 0.6), tint)
	_part(_body, Vector3(0, -0.05, 0.12), Vector3(0.42, 0.38, 0.42), tint.lightened(0.12))  # breast
	for sx in [-1.0, 1.0]:
		_part(_body, Vector3(sx * 0.26, 0.02, -0.02), Vector3(0.06, 0.32, 0.44), tint.darkened(0.15))  # wings
	_head = Node3D.new()
	_head.position = Vector3(0, 0.3, 0.28)
	_body.add_child(_head)
	_part(_head, Vector3(0, 0.12, 0.02), Vector3(0.1, 0.28, 0.1), Color(0.55, 0.62, 0.75))  # neck
	_part(_head, Vector3(0, 0.3, 0.06), Vector3(0.16, 0.16, 0.18), Color(0.6, 0.68, 0.82))  # head
	_part(_head, Vector3(0, 0.28, 0.18), Vector3(0.06, 0.05, 0.08), Color(0.95, 0.75, 0.3))  # beak
	_part(_head, Vector3(0.0, 0.18, 0.15), Vector3(0.06, 0.14, 0.04), Color(0.85, 0.15, 0.15))  # wattle
	for sx in [-0.06, 0.06]:
		_part(_head, Vector3(sx, 0.33, 0.14), Vector3(0.03, 0.03, 0.02), Color(0.05, 0.05, 0.05))
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.1, -0.3)
	_tail.rotation.x = 0.25
	_body.add_child(_tail)
	for k in 7:
		var a := -0.9 + k * 0.3
		var f := Node3D.new()
		f.rotation.z = a
		_tail.add_child(f)
		_part(f, Vector3(0, 0.42, 0), Vector3(0.14, 0.7, 0.04), tint.darkened(0.1))
		_part(f, Vector3(0, 0.62, 0.005), Vector3(0.13, 0.12, 0.04), accent)
		_part(f, Vector3(0, 0.74, 0.01), Vector3(0.12, 0.06, 0.04), Color(0.95, 0.92, 0.85))
	for sx in [-0.12, 0.12]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, -0.22, 0.05)
		_body.add_child(leg)
		_part(leg, Vector3(0, -0.15, 0), Vector3(0.05, 0.3, 0.05), Color(0.85, 0.6, 0.3))
		_part(leg, Vector3(0, -0.3, 0.05), Vector3(0.14, 0.03, 0.16), Color(0.85, 0.6, 0.3))
		_legs.append(leg)


## Cupcake critter: a pink-frosted cupcake in a striped paper cup with a cherry on top.
func _build_cupcake() -> void:
	_body.position.y = 0.0
	for k in 8:
		var a := TAU * k / 8.0
		_part(_body, Vector3(cos(a) * 0.24, 0.2, sin(a) * 0.24), Vector3(0.12, 0.4, 0.12), Color(0.95, 0.9, 0.75) if k % 2 == 0 else accent)
	_part(_body, Vector3(0, 0.2, 0), Vector3(0.5, 0.38, 0.5), Color(0.75, 0.5, 0.3))  # cake
	_part(_body, Vector3(0, 0.48, 0), Vector3(0.62, 0.18, 0.62), tint)  # frosting
	_part(_body, Vector3(0, 0.62, 0), Vector3(0.46, 0.14, 0.46), tint.lightened(0.12))
	_part(_body, Vector3(0, 0.74, 0), Vector3(0.26, 0.12, 0.26), tint.lightened(0.2))
	_part(_body, Vector3(0, 0.88, 0), Vector3(0.14, 0.14, 0.14), Color(0.85, 0.08, 0.12))  # cherry
	_part(_body, Vector3(0.03, 0.98, 0), Vector3(0.02, 0.1, 0.02), Color(0.3, 0.5, 0.2))
	for p in [Vector3(-0.18, 0.56, 0.22), Vector3(0.2, 0.6, 0.14), Vector3(0.05, 0.66, -0.2)]:
		_part(_body, p, Vector3(0.05, 0.03, 0.05), [Color(0.4, 0.8, 1.0), Color(1, 0.9, 0.3), Color(0.6, 1, 0.5)][int(p.z * 10) % 3])  # sprinkles
	for sx in [-0.1, 0.1]:
		_part(_body, Vector3(sx, 0.28, 0.27), Vector3(0.07, 0.09, 0.02), Color(0.1, 0.06, 0.06))  # eyes
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0.16, 0.26)
	_body.add_child(_jaw)
	_part(_jaw, Vector3(0, 0, 0), Vector3(0.1, 0.04, 0.02), Color(0.5, 0.15, 0.2))  # smile


## Berry jelly: a wobbly see-through jelly cube with berries floating inside.
func _build_jelly() -> void:
	_body.position.y = 0.0
	var cube := _part(_body, Vector3(0, 0.3, 0), Vector3(0.62, 0.6, 0.62), tint)
	cube.transparency = 0.35
	for p in [Vector3(-0.12, 0.22, 0.08), Vector3(0.14, 0.36, -0.1), Vector3(0.02, 0.42, 0.14), Vector3(-0.1, 0.4, -0.12)]:
		_part(_body, p, Vector3(0.11, 0.11, 0.11), accent)
	_part(_body, Vector3(0, 0.62, 0), Vector3(0.5, 0.04, 0.5), tint.lightened(0.3))  # shine
	for sx in [-0.12, 0.12]:
		_part(_body, Vector3(sx, 0.38, 0.32), Vector3(0.08, 0.1, 0.02), Color(0.1, 0.05, 0.08))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0.24, 0.32)
	_body.add_child(_jaw)
	_part(_jaw, Vector3.ZERO, Vector3(0.12, 0.05, 0.02), Color(0.45, 0.08, 0.15))


## Door mimics sleep as plain doors: no eyes, no tongue.
func set_awake(on: bool) -> void:
	for n in _sleeping:
		if is_instance_valid(n):
			n.visible = on
	_awake = on
