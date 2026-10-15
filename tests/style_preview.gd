extends RefCounted
## Style preview only (not used by the game): pixel-textured box models built
## after the owner's reference pictures, so the look can be judged in the real
## world. Used by tests/screenshot_runner.gd --only=pixelstyle.
##
## Every model stands on its origin and faces +Z.

const SHADER := preload("res://tests/style_preview.gdshader")

enum P { PLAIN, METAL, WOOD, BONE, CLOTH, LEATHER, HAIR, GLOW, CURSED, TEETH, TATTOO, WRAP, PATINA, STRAW }

# Palette.
const BONE := Color(0.93, 0.88, 0.7)
const BONE_D := Color(0.72, 0.64, 0.46)
const STEEL := Color(0.8, 0.84, 0.88)
const STEEL_D := Color(0.5, 0.55, 0.63)
const IRON := Color(0.36, 0.38, 0.44)
const IRON_D := Color(0.22, 0.23, 0.28)
const TEAL := Color(0.58, 0.78, 0.82)
const TEAL_D := Color(0.33, 0.48, 0.56)
const WOOD := Color(0.58, 0.38, 0.22)
const WOOD_D := Color(0.42, 0.26, 0.14)
const LEATHER := Color(0.42, 0.26, 0.17)
const LEATHER_D := Color(0.26, 0.15, 0.1)
const SOCKET := Color(0.13, 0.08, 0.07)

static var _seed := 0


## One textured box. `rot` in degrees.
static func box(parent: Node3D, pos: Vector3, size: Vector3, pat: int, col: Color,
		dark := Color(-1, 0, 0), rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"half_size", size * 0.5)
	m.set_shader_parameter(&"base_color", col)
	m.set_shader_parameter(&"dark_color", col * 0.68 if dark.r < 0.0 else dark)
	m.set_shader_parameter(&"accent_color", opts.get("accent", col.lightened(0.45)))
	m.set_shader_parameter(&"pattern", float(pat))
	_seed += 1
	m.set_shader_parameter(&"seed", float(_seed % 97))
	m.set_shader_parameter(&"glow", opts.get("glow", 2.5 if pat == P.GLOW else 1.6))
	m.set_shader_parameter(&"metal", 1.0 if pat == P.METAL else 0.0)
	m.set_shader_parameter(&"rag", opts.get("rag", 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	return n


## A pivot at `from` whose local -Y points at `to` (an arm reaching for a spot).
static func aim(parent: Node3D, from: Vector3, to: Vector3) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var y := (from - to).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	n.transform = Transform3D(Basis(x, y, z), from)
	return n


# --- Skeleton warrior (reference 2) ----------------------------------------------

static func skeleton() -> Node3D:
	var root := Node3D.new()
	for s: float in [-1.0, 1.0]:
		var x := s * 0.16
		# Boots with a cuff and a strap, bony toes poking out.
		box(root, Vector3(x, 0.12, 0.02), Vector3(0.2, 0.24, 0.24), P.LEATHER, Color(0.4, 0.17, 0.13), Color(0.24, 0.1, 0.08))
		box(root, Vector3(x, 0.27, 0.0), Vector3(0.24, 0.07, 0.27), P.LEATHER, Color(0.3, 0.13, 0.1))
		box(root, Vector3(x, 0.16, 0.0), Vector3(0.22, 0.04, 0.26), P.METAL, IRON, IRON_D)
		box(root, Vector3(x, 0.04, 0.17), Vector3(0.16, 0.07, 0.09), P.BONE, BONE, BONE_D)
		# Leg bones and knee.
		box(root, Vector3(x, 0.44, 0.0), Vector3(0.08, 0.3, 0.08), P.BONE, BONE, BONE_D)
		box(root, Vector3(x, 0.61, 0.01), Vector3(0.13, 0.1, 0.12), P.BONE, BONE, BONE_D)
		box(root, Vector3(x, 0.78, 0.0), Vector3(0.09, 0.26, 0.09), P.BONE, BONE, BONE_D)
	# Ragged crimson skirt and a belt with a buckle.
	box(root, Vector3(0, 0.88, 0), Vector3(0.52, 0.32, 0.34), P.CLOTH, Color(0.62, 0.13, 0.32), Color(0.4, 0.07, 0.2), Vector3.ZERO, {"rag": 0.45})
	box(root, Vector3(0, 1.04, 0), Vector3(0.56, 0.08, 0.38), P.LEATHER, LEATHER, LEATHER_D)
	box(root, Vector3(0, 1.04, 0.195), Vector3(0.14, 0.11, 0.02), P.METAL, Color(0.6, 0.64, 0.72), IRON)
	box(root, Vector3(0, 1.04, 0.205), Vector3(0.06, 0.04, 0.01), P.PLAIN, SOCKET)
	# Spine, ribs, breastbone.
	box(root, Vector3(0, 1.3, -0.08), Vector3(0.08, 0.5, 0.08), P.BONE, BONE, BONE_D)
	_ribcage(root, Vector3(0, 1.2, 0), 4, 0.44)
	# Collarbone, shoulders, neck.
	box(root, Vector3(0, 1.6, 0), Vector3(0.62, 0.07, 0.12), P.BONE, BONE, BONE_D)
	box(root, Vector3(0, 1.67, -0.02), Vector3(0.08, 0.1, 0.08), P.BONE, BONE, BONE_D)
	_skull(root, Vector3(0, 1.93, 0.0), Color(1.0, 0.55, 0.12))
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.33, 1.58, 0), Vector3(0.13, 0.13, 0.13), P.BONE, BONE, BONE_D)
		var sh := pivot(root, Vector3(s * 0.36, 1.55, 0), Vector3(0, 0, s * 22.0))
		_bone_arm(sh, s)
	return root


static func _ribcage(root: Node3D, base: Vector3, count: int, width: float) -> void:
	for i in count:
		var y := base.y + i * 0.1
		var w := width - absf(i - 1.5) * 0.04
		for s: float in [-1.0, 1.0]:
			box(root, base + Vector3(s * (w * 0.25 + 0.03), y - base.y, 0.1), Vector3(w * 0.4, 0.05, 0.04), P.BONE, BONE, BONE_D)
			box(root, base + Vector3(s * w * 0.5, y - base.y, 0.0), Vector3(0.04, 0.05, 0.24), P.BONE, BONE, BONE_D)
		box(root, base + Vector3(0, y - base.y, -0.1), Vector3(w, 0.05, 0.04), P.BONE, BONE, BONE_D)
	box(root, base + Vector3(0, 0.16, 0.11), Vector3(0.05, 0.3, 0.035), P.BONE, BONE, BONE_D)


static func _skull(root: Node3D, c: Vector3, eye: Color) -> void:
	box(root, c + Vector3(0, 0.02, 0), Vector3(0.5, 0.42, 0.46), P.BONE, BONE, BONE_D)
	box(root, c + Vector3(0, -0.23, 0.03), Vector3(0.38, 0.1, 0.36), P.BONE, BONE, BONE_D)
	box(root, c + Vector3(0, -0.165, 0.211), Vector3(0.3, 0.05, 0.01), P.TEETH, BONE, SOCKET)
	box(root, c + Vector3(0, -0.06, 0.231), Vector3(0.06, 0.05, 0.01), P.PLAIN, SOCKET)
	for s: float in [-1.0, 1.0]:
		box(root, c + Vector3(s * 0.11, 0.03, 0.231), Vector3(0.14, 0.12, 0.01), P.PLAIN, SOCKET)
		box(root, c + Vector3(s * 0.11, 0.02, 0.237), Vector3(0.06, 0.06, 0.01), P.GLOW, eye, Color(-1, 0, 0), Vector3.ZERO, {"glow": 3.0})


static func _bone_arm(sh: Node3D, s: float) -> void:
	box(sh, Vector3(0, -0.17, 0), Vector3(0.08, 0.32, 0.08), P.BONE, BONE, BONE_D)
	box(sh, Vector3(0, -0.34, 0), Vector3(0.11, 0.1, 0.11), P.BONE, BONE, BONE_D)
	var el := pivot(sh, Vector3(0, -0.34, 0), Vector3(-25, 0, -s * 14.0))
	box(el, Vector3(-0.025, -0.15, 0), Vector3(0.04, 0.28, 0.05), P.BONE, BONE, BONE_D)
	box(el, Vector3(0.025, -0.15, 0), Vector3(0.04, 0.28, 0.05), P.BONE, BONE, BONE_D)
	box(el, Vector3(0, -0.33, 0), Vector3(0.11, 0.08, 0.1), P.BONE, BONE, BONE_D)
	for k in 3:
		box(el, Vector3((k - 1) * 0.035, -0.43, 0.02), Vector3(0.025, 0.13, 0.03), P.BONE, BONE, BONE_D)
	box(el, Vector3(-s * 0.06, -0.38, 0.04), Vector3(0.025, 0.09, 0.03), P.BONE, BONE, BONE_D)


# --- Skeleton centaur with spear and shield (reference 4) ------------------------

static func centaur() -> Node3D:
	var root := Node3D.new()
	var hide := Color(0.55, 0.38, 0.33)
	var hide_d := Color(0.38, 0.24, 0.21)
	# Horse spine, rib rings, pelvis, tail.
	box(root, Vector3(0, 1.36, -0.05), Vector3(0.1, 0.1, 1.5), P.BONE, BONE, BONE_D)
	for i in 6:
		var z := 0.42 - i * 0.16
		var drop := 0.34 - absf(i - 2.0) * 0.03
		for s: float in [-1.0, 1.0]:
			box(root, Vector3(s * 0.14, 1.32, z), Vector3(0.2, 0.05, 0.06), P.BONE, BONE, BONE_D)
			box(root, Vector3(s * 0.25, 1.32 - drop * 0.5, z), Vector3(0.05, drop, 0.06), P.BONE, BONE, BONE_D)
		if i < 4:
			box(root, Vector3(0, 1.32 - drop, z), Vector3(0.44, 0.05, 0.06), P.BONE, BONE, BONE_D)
	box(root, Vector3(0, 1.32, -0.72), Vector3(0.44, 0.2, 0.26), P.BONE, BONE, BONE_D)
	for k in 5:
		box(root, Vector3(0, 1.28 - k * 0.11, -0.86 - k * 0.04), Vector3(0.07 - k * 0.006, 0.08, 0.07), P.BONE, BONE, BONE_D)
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.23, 1.22, 0.58), Vector3(0.06, 0.32, 0.22), P.BONE, BONE, BONE_D)
	# Four legs with leather wraps and hooves.
	for leg in [Vector2(-0.18, 0.58), Vector2(0.18, 0.58), Vector2(-0.18, -0.66), Vector2(0.18, -0.66)]:
		var x: float = leg.x
		var z: float = leg.y
		box(root, Vector3(x, 1.08, z), Vector3(0.1, 0.3, 0.1), P.BONE, BONE, BONE_D)
		box(root, Vector3(x, 0.88, z), Vector3(0.14, 0.14, 0.14), P.LEATHER, hide, hide_d)
		box(root, Vector3(x, 0.55, z), Vector3(0.08, 0.5, 0.08), P.BONE, BONE, BONE_D)
		box(root, Vector3(x, 0.26, z), Vector3(0.13, 0.11, 0.13), P.LEATHER, hide, hide_d)
		box(root, Vector3(x, 0.08, z + 0.02), Vector3(0.15, 0.16, 0.17), P.BONE, BONE * 0.86, BONE_D * 0.8)
	# Rider torso on the front of the horse.
	var t := Vector3(0, 0, 0.62)
	box(root, t + Vector3(0, 1.7, -0.06), Vector3(0.08, 0.6, 0.08), P.BONE, BONE, BONE_D)
	_ribcage(root, t + Vector3(0, 1.55, 0), 4, 0.42)
	box(root, t + Vector3(0, 1.97, 0), Vector3(0.62, 0.07, 0.12), P.BONE, BONE, BONE_D)
	box(root, t + Vector3(0, 1.6, 0.0), Vector3(0.5, 0.05, 0.3), P.LEATHER, hide, hide_d)  # sash
	for s: float in [-1.0, 1.0]:
		box(root, t + Vector3(s * 0.33, 2.0, 0), Vector3(0.26, 0.12, 0.3), P.LEATHER, hide, hide_d)
		box(root, t + Vector3(s * 0.36, 1.92, 0), Vector3(0.24, 0.1, 0.26), P.LEATHER, hide * 0.9, hide_d)
	_skull(root, t + Vector3(0, 2.3, 0.02), Color(0.95, 0.3, 0.35))
	# Hide helmet with two curled horns.
	box(root, t + Vector3(0, 2.47, 0.0), Vector3(0.54, 0.14, 0.5), P.LEATHER, hide, hide_d)
	box(root, t + Vector3(0, 2.36, -0.22), Vector3(0.54, 0.2, 0.08), P.LEATHER, hide, hide_d)
	for s: float in [-1.0, 1.0]:
		var segs := [[Vector3(0.24, 2.55, 0.0), 0.16], [Vector3(0.3, 2.65, -0.03), 0.15], [Vector3(0.34, 2.76, -0.08), 0.13],
			[Vector3(0.34, 2.87, -0.14), 0.12], [Vector3(0.3, 2.96, -0.21), 0.1], [Vector3(0.24, 3.02, -0.28), 0.08]]
		for sg in segs:
			var p: Vector3 = sg[0]
			box(root, t + Vector3(s * p.x, p.y, p.z), Vector3.ONE * float(sg[1]), P.LEATHER, Color(0.62, 0.45, 0.38), hide_d)
	# Right arm raised, gripping the spear; left arm holds the diamond shield.
	var hand_r := t + Vector3(0.6, 2.36, 0.3)
	var ra := aim(root, t + Vector3(0.36, 1.94, 0), hand_r)
	var arm_len := (hand_r - (t + Vector3(0.36, 1.94, 0))).length()
	box(ra, Vector3(0, -arm_len * 0.25, 0), Vector3(0.08, arm_len * 0.5, 0.08), P.BONE, BONE, BONE_D)
	box(ra, Vector3(0, -arm_len * 0.5, 0), Vector3(0.12, 0.12, 0.12), P.LEATHER, hide, hide_d)
	box(ra, Vector3(0, -arm_len * 0.75, 0), Vector3(0.08, arm_len * 0.5, 0.08), P.BONE, BONE, BONE_D)
	box(ra, Vector3(0, -arm_len, 0), Vector3(0.12, 0.1, 0.12), P.BONE, BONE, BONE_D)
	var spear := pivot(root, hand_r, Vector3(14, 0, -6))
	box(spear, Vector3(0, 0.15, 0), Vector3(0.07, 2.9, 0.07), P.WOOD, Color(0.45, 0.25, 0.45), Color(0.3, 0.15, 0.32))
	box(spear, Vector3(0, -0.8, 0), Vector3(0.1, 0.22, 0.1), P.LEATHER, hide, hide_d)
	box(spear, Vector3(0, 0.75, 0), Vector3(0.1, 0.2, 0.1), P.LEATHER, hide, hide_d)
	box(spear, Vector3(0, 1.64, 0), Vector3(0.1, 0.12, 0.1), P.METAL, IRON, IRON_D)
	box(spear, Vector3(0, 1.94, 0), Vector3(0.05, 0.5, 0.15), P.METAL, STEEL, STEEL_D)
	box(spear, Vector3(0, 2.24, 0.0), Vector3(0.04, 0.14, 0.08), P.METAL, STEEL, STEEL_D)
	box(spear, Vector3(0, 1.84, -0.1), Vector3(0.04, 0.16, 0.06), P.METAL, STEEL, STEEL_D)
	var hand_l := t + Vector3(-0.5, 1.62, 0.32)
	var la := aim(root, t + Vector3(-0.36, 1.94, 0), hand_l)
	var l_len := (hand_l - (t + Vector3(-0.36, 1.94, 0))).length()
	box(la, Vector3(0, -l_len * 0.25, 0), Vector3(0.08, l_len * 0.5, 0.08), P.BONE, BONE, BONE_D)
	box(la, Vector3(0, -l_len * 0.5, 0), Vector3(0.12, 0.12, 0.12), P.LEATHER, hide, hide_d)
	box(la, Vector3(0, -l_len * 0.75, 0), Vector3(0.08, l_len * 0.5, 0.08), P.BONE, BONE, BONE_D)
	var shield := pivot(root, hand_l + Vector3(-0.08, 0, 0.12), Vector3(0, -25, 45))
	box(shield, Vector3.ZERO, Vector3(0.7, 0.7, 0.05), P.METAL, Color(0.62, 0.55, 0.62), Color(0.38, 0.32, 0.4))
	box(shield, Vector3(0, 0, 0.02), Vector3(0.58, 0.58, 0.05), P.LEATHER, Color(0.48, 0.2, 0.38), Color(0.3, 0.1, 0.24))
	box(shield, Vector3(0, 0, 0.05), Vector3(0.14, 0.14, 0.04), P.METAL, STEEL, STEEL_D)
	return root


# --- Knight on an armoured horse (reference 1) -----------------------------------

static func knight_rider() -> Node3D:
	var root := Node3D.new()
	var coat := Color(0.5, 0.33, 0.22)
	var coat_d := Color(0.34, 0.21, 0.13)
	var mane := Color(0.2, 0.13, 0.1)
	var plate := Color(0.75, 0.77, 0.8)
	var plate_d := Color(0.42, 0.44, 0.5)
	var red := Color(0.55, 0.14, 0.17)
	# Horse body, barding and saddle cloth.
	box(root, Vector3(0, 1.25, -0.1), Vector3(0.6, 0.6, 1.7), P.HAIR, coat, coat_d)
	box(root, Vector3(0, 1.22, 0.74), Vector3(0.66, 0.56, 0.1), P.METAL, plate, plate_d)
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.32, 1.3, 0.38), Vector3(0.05, 0.42, 0.62), P.METAL, plate, plate_d)
		box(root, Vector3(s * 0.32, 1.35, -0.1), Vector3(0.04, 0.32, 0.5), P.CLOTH, red, red * 0.6, Vector3.ZERO, {"rag": 0.3})
	box(root, Vector3(0, 1.58, -0.05), Vector3(0.62, 0.05, 0.56), P.CLOTH, red, red * 0.6)
	box(root, Vector3(0, 1.62, -0.05), Vector3(0.36, 0.08, 0.42), P.LEATHER, LEATHER, LEATHER_D)
	box(root, Vector3(0, 1.48, -0.55), Vector3(0.64, 0.14, 0.44), P.METAL, plate, plate_d)
	var tail := pivot(root, Vector3(0, 1.45, -0.76), Vector3(-30, 0, 0))
	box(tail, Vector3(0, -0.32, 0), Vector3(0.14, 0.66, 0.14), P.HAIR, mane, mane * 0.6)
	# Neck and head (armoured face with a spike).
	var neck := pivot(root, Vector3(0, 1.38, 0.66), Vector3(48, 0, 0))
	box(neck, Vector3(0, 0.36, 0), Vector3(0.32, 0.78, 0.4), P.HAIR, coat, coat_d)
	for k in 3:
		box(neck, Vector3(0, 0.14 + k * 0.24, 0.2), Vector3(0.36, 0.22, 0.08), P.METAL, plate, plate_d)
	box(neck, Vector3(0, 0.42, -0.2), Vector3(0.12, 0.76, 0.1), P.HAIR, mane, mane * 0.6)
	var head := pivot(neck, Vector3(0, 0.78, -0.02), Vector3(70, 0, 0))
	box(head, Vector3(0, 0.28, 0), Vector3(0.3, 0.62, 0.32), P.HAIR, coat, coat_d)
	box(head, Vector3(0, 0.26, -0.17), Vector3(0.34, 0.56, 0.06), P.METAL, plate, plate_d)
	box(head, Vector3(0, 0.1, -0.24), Vector3(0.06, 0.06, 0.12), P.METAL, STEEL, STEEL_D)
	box(head, Vector3(0, 0.6, 0.0), Vector3(0.26, 0.06, 0.28), P.PLAIN, coat_d)
	for s: float in [-1.0, 1.0]:
		box(head, Vector3(s * 0.1, -0.02, -0.2), Vector3(0.07, 0.07, 0.16), P.HAIR, coat, coat_d)
		box(head, Vector3(s * 0.155, 0.12, -0.04), Vector3(0.01, 0.06, 0.06), P.PLAIN, SOCKET)
	# Legs: front right raised; steel greaves, white feathering, dark hooves.
	var legs := [[Vector3(-0.2, 1.0, 0.55), Vector3(-10, 0, 0)], [Vector3(0.2, 1.0, 0.55), Vector3(-70, 0, 0)],
		[Vector3(-0.2, 1.0, -0.55), Vector3(8, 0, 0)], [Vector3(0.2, 1.0, -0.55), Vector3(-6, 0, 0)]]
	for i in legs.size():
		var hip := pivot(root, legs[i][0], legs[i][1])
		box(hip, Vector3(0, -0.2, 0), Vector3(0.18, 0.42, 0.2), P.HAIR, coat, coat_d)
		var knee := pivot(hip, Vector3(0, -0.4, 0), Vector3(55 if i == 1 else 0, 0, 0))
		box(knee, Vector3(0, -0.22, 0), Vector3(0.14, 0.44, 0.15), P.HAIR, coat, coat_d)
		if i < 2:
			box(knee, Vector3(0, -0.18, 0.02), Vector3(0.17, 0.3, 0.17), P.METAL, plate, plate_d)
		box(knee, Vector3(0, -0.46, 0), Vector3(0.19, 0.08, 0.21), P.HAIR, Color(0.86, 0.84, 0.8), Color(0.66, 0.64, 0.6))
		box(knee, Vector3(0, -0.55, 0.01), Vector3(0.18, 0.1, 0.2), P.PLAIN, Color(0.22, 0.19, 0.17))
	# Knight: legs astride, plate body, red tabard, helmet with a visor.
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.3, 1.66, 0.08), Vector3(0.17, 0.17, 0.42), P.METAL, plate, plate_d)
		box(root, Vector3(s * 0.34, 1.36, 0.24), Vector3(0.15, 0.46, 0.17), P.METAL, plate, plate_d)
		box(root, Vector3(s * 0.34, 1.1, 0.3), Vector3(0.16, 0.1, 0.26), P.METAL, IRON, IRON_D)
	box(root, Vector3(0, 2.0, -0.05), Vector3(0.5, 0.62, 0.32), P.METAL, plate, plate_d)
	box(root, Vector3(0, 1.84, 0.12), Vector3(0.3, 0.58, 0.04), P.CLOTH, red, red * 0.6, Vector3.ZERO, {"rag": 0.25})
	box(root, Vector3(0, 1.76, -0.05), Vector3(0.54, 0.08, 0.36), P.LEATHER, LEATHER, LEATHER_D)
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.33, 2.28, -0.05), Vector3(0.28, 0.12, 0.38), P.METAL, plate, plate_d)
		box(root, Vector3(s * 0.36, 2.2, -0.05), Vector3(0.26, 0.1, 0.36), P.METAL, plate_d, IRON_D)
	box(root, Vector3(0, 2.36, -0.05), Vector3(0.24, 0.08, 0.24), P.LEATHER, LEATHER, LEATHER_D)
	box(root, Vector3(0, 2.6, -0.04), Vector3(0.44, 0.46, 0.44), P.METAL, plate, plate_d)
	box(root, Vector3(0, 2.61, 0.185), Vector3(0.34, 0.05, 0.02), P.PLAIN, SOCKET)
	box(root, Vector3(0, 2.86, -0.04), Vector3(0.08, 0.08, 0.46), P.LEATHER, Color(0.6, 0.42, 0.26))
	box(root, Vector3(0, 2.5, 0.19), Vector3(0.2, 0.12, 0.03), P.METAL, plate_d, IRON_D)
	var ra := pivot(root, Vector3(0.36, 2.18, -0.05), Vector3(-150, 0, -18))
	box(ra, Vector3(0, -0.15, 0), Vector3(0.17, 0.3, 0.18), P.METAL, plate, plate_d)
	box(ra, Vector3(0, -0.42, 0), Vector3(0.16, 0.26, 0.17), P.METAL, plate, plate_d)
	box(ra, Vector3(0, -0.6, 0), Vector3(0.18, 0.12, 0.19), P.LEATHER, LEATHER, LEATHER_D)
	var sw := pivot(ra, Vector3(0, -0.6, 0), Vector3(180, 0, 0))
	_sword_simple(sw)
	var la := pivot(root, Vector3(-0.36, 2.18, -0.05), Vector3(-55, 0, 12))
	box(la, Vector3(0, -0.15, 0), Vector3(0.17, 0.3, 0.18), P.METAL, plate, plate_d)
	box(la, Vector3(0, -0.42, 0), Vector3(0.16, 0.26, 0.17), P.METAL, plate, plate_d)
	box(la, Vector3(0, -0.58, 0), Vector3(0.18, 0.12, 0.19), P.LEATHER, LEATHER, LEATHER_D)
	return root


static func _sword_simple(p: Node3D) -> void:
	box(p, Vector3(0, -0.12, 0), Vector3(0.08, 0.08, 0.08), P.METAL, STEEL, STEEL_D)
	box(p, Vector3(0, 0.0, 0), Vector3(0.06, 0.2, 0.06), P.WRAP, LEATHER, LEATHER_D)
	box(p, Vector3(0, 0.13, 0), Vector3(0.32, 0.06, 0.08), P.METAL, STEEL, STEEL_D)
	box(p, Vector3(0, 0.62, 0), Vector3(0.12, 0.9, 0.04), P.METAL, STEEL, STEEL_D)
	box(p, Vector3(0, 1.1, 0), Vector3(0.07, 0.08, 0.04), P.METAL, STEEL, STEEL_D)


# --- Weapon rack (reference 3) ---------------------------------------------------

## Eleven weapons standing in a row (each one's pommel on the ground).
static func weapons() -> Node3D:
	var root := Node3D.new()
	var builders := [&"_w_greatsword", &"_w_pick", &"_w_double_axe", &"_w_hammer", &"_w_club", &"_w_shortsword",
		&"_w_wavy", &"_w_claw", &"_w_glaive", &"_w_spear"]
	for i in builders.size():
		var w := pivot(root, Vector3((i - 4.5) * 0.62, 0, -absf(i - 4.5) * 0.08))
		_call_builder(builders[i], w)
	_bomb(pivot(root, Vector3(-3.4, 0, 0.5)), Color(0.9, 0.25, 0.3))
	_bomb(pivot(root, Vector3(-2.6, 0, 0.9)), Color(0.3, 0.9, 0.7))
	return root


static func _call_builder(name: StringName, w: Node3D) -> void:
	match name:
		&"_w_greatsword": _w_greatsword(w)
		&"_w_pick": _w_pick(w)
		&"_w_double_axe": _w_double_axe(w)
		&"_w_hammer": _w_hammer(w)
		&"_w_club": _w_club(w)
		&"_w_shortsword": _w_shortsword(w)
		&"_w_wavy": _w_wavy(w)
		&"_w_claw": _w_claw(w)
		&"_w_glaive": _w_glaive(w)
		&"_w_spear": _w_spear(w)


static func _w_greatsword(w: Node3D) -> void:
	box(w, Vector3(0, 0.05, 0), Vector3(0.1, 0.1, 0.1), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0, 0.27, 0), Vector3(0.07, 0.34, 0.07), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 0.47, 0), Vector3(0.5, 0.08, 0.1), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0, 1.17, 0), Vector3(0.22, 1.32, 0.05), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0, 1.89, 0), Vector3(0.16, 0.12, 0.05), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0, 1.99, 0), Vector3(0.09, 0.08, 0.05), P.METAL, STEEL, STEEL_D)


static func _w_pick(w: Node3D) -> void:
	box(w, Vector3(0, 0.03, 0), Vector3(0.08, 0.06, 0.08), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0, 0.62, 0), Vector3(0.06, 1.2, 0.06), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 0.2, 0), Vector3(0.08, 0.06, 0.08), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0.06, 1.22, 0), Vector3(0.32, 0.07, 0.08), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0.2, 1.12, 0), Vector3(0.06, 0.16, 0.07), P.METAL, STEEL, STEEL_D)


static func _w_double_axe(w: Node3D) -> void:
	box(w, Vector3(0, 0.03, 0), Vector3(0.08, 0.06, 0.08), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0, 0.65, 0), Vector3(0.06, 1.3, 0.06), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 1.2, 0), Vector3(0.12, 0.16, 0.1), P.METAL, IRON, IRON_D)
	for s: float in [-1.0, 1.0]:
		box(w, Vector3(s * 0.14, 1.2, 0), Vector3(0.12, 0.26, 0.04), P.METAL, STEEL, STEEL_D)
		box(w, Vector3(s * 0.22, 1.2, 0), Vector3(0.05, 0.4, 0.04), P.METAL, Color(0.93, 0.95, 0.97), STEEL_D)


static func _w_hammer(w: Node3D) -> void:
	box(w, Vector3(0, 0.03, 0), Vector3(0.09, 0.06, 0.09), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0, 0.62, 0), Vector3(0.07, 1.2, 0.07), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 1.3, 0), Vector3(0.46, 0.26, 0.28), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0, 1.3, 0.145), Vector3(0.32, 0.1, 0.01), P.TEETH, TEAL * 1.1, TEAL_D * 0.7)
	box(w, Vector3(0, 1.3, -0.145), Vector3(0.32, 0.1, 0.01), P.TEETH, TEAL * 1.1, TEAL_D * 0.7)
	box(w, Vector3(0, 1.15, 0), Vector3(0.1, 0.06, 0.1), P.METAL, TEAL_D, IRON_D)


static func _w_club(w: Node3D) -> void:
	box(w, Vector3(0, 0.5, 0), Vector3(0.07, 1.0, 0.07), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 1.08, 0), Vector3(0.09, 0.2, 0.09), P.WOOD, WOOD, WOOD_D)
	var leaf := Color(0.45, 0.75, 0.25)
	box(w, Vector3(0, 0.3, 0), Vector3(0.1, 0.05, 0.1), P.PLAIN, leaf)
	box(w, Vector3(0.08, 0.34, 0), Vector3(0.09, 0.03, 0.04), P.PLAIN, leaf)
	box(w, Vector3(-0.07, 0.27, 0.02), Vector3(0.07, 0.03, 0.04), P.PLAIN, leaf * 0.85)


static func _w_shortsword(w: Node3D) -> void:
	var slate := Color(0.5, 0.6, 0.68)
	box(w, Vector3(0, 0.04, 0), Vector3(0.08, 0.08, 0.08), P.METAL, slate, IRON_D)
	box(w, Vector3(0, 0.22, 0), Vector3(0.07, 0.28, 0.07), P.WRAP, Color(0.62, 0.44, 0.26), Color(0.36, 0.42, 0.52))
	box(w, Vector3(0, 0.39, 0), Vector3(0.28, 0.06, 0.08), P.METAL, slate, IRON_D)
	box(w, Vector3(0, 0.85, 0), Vector3(0.11, 0.86, 0.04), P.METAL, slate, Color(0.32, 0.38, 0.46))
	box(w, Vector3(0, 1.31, 0), Vector3(0.06, 0.06, 0.04), P.METAL, slate, IRON_D)


static func _w_wavy(w: Node3D) -> void:
	box(w, Vector3(0, 0.04, 0), Vector3(0.1, 0.08, 0.08), P.METAL, STEEL, STEEL_D)
	box(w, Vector3(0, 0.22, 0), Vector3(0.07, 0.28, 0.07), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 0.39, 0), Vector3(0.38, 0.07, 0.09), P.METAL, STEEL, STEEL_D)
	for k in 10:
		box(w, Vector3(0.025 if k % 2 == 0 else -0.025, 0.48 + k * 0.1, 0), Vector3(0.13, 0.1, 0.04), P.METAL, Color(0.92, 0.94, 0.97), STEEL_D)
	box(w, Vector3(0, 1.47, 0), Vector3(0.05, 0.06, 0.04), P.METAL, STEEL, STEEL_D)


static func _w_claw(w: Node3D) -> void:
	box(w, Vector3(0, 0.5, 0), Vector3(0.07, 1.0, 0.07), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0.05, 1.06, 0), Vector3(0.07, 0.2, 0.07), P.WOOD, WOOD, WOOD_D, Vector3(0, 0, -30))
	box(w, Vector3(0.1, 1.4, 0), Vector3(0.07, 0.56, 0.07), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0.1, 1.2, 0), Vector3(0.1, 0.12, 0.1), P.LEATHER, Color(0.75, 0.5, 0.3), LEATHER_D)
	box(w, Vector3(0.1, 1.7, 0), Vector3(0.12, 0.06, 0.12), P.METAL, TEAL, TEAL_D)
	for a: float in [-28.0, 0.0, 28.0]:
		var prong := pivot(w, Vector3(0.1, 1.72, 0), Vector3(0, 0, a))
		box(prong, Vector3(0, 0.15, 0), Vector3(0.05, 0.3, 0.05), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0.1, 1.98, 0), Vector3(0.3, 0.05, 0.06), P.METAL, TEAL, TEAL_D)


static func _w_glaive(w: Node3D) -> void:
	box(w, Vector3(0, 0.85, 0), Vector3(0.06, 1.7, 0.06), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 1.72, 0), Vector3(0.1, 0.07, 0.1), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0.015, 2.04, 0), Vector3(0.11, 0.58, 0.04), P.METAL, TEAL, TEAL_D)
	box(w, Vector3(0.0, 2.38, 0), Vector3(0.06, 0.1, 0.04), P.METAL, TEAL, TEAL_D)


static func _w_spear(w: Node3D) -> void:
	box(w, Vector3(0, 0.98, 0), Vector3(0.05, 1.96, 0.05), P.WOOD, WOOD, WOOD_D)
	box(w, Vector3(0, 1.98, 0), Vector3(0.07, 0.06, 0.07), P.METAL, IRON, IRON_D)
	var red := Color(0.8, 0.15, 0.15)
	box(w, Vector3(0.04, 1.93, 0.0), Vector3(0.07, 0.04, 0.07), P.CLOTH, red)
	box(w, Vector3(0.07, 1.85, 0.0), Vector3(0.03, 0.14, 0.03), P.CLOTH, red)
	box(w, Vector3(0, 2.22, 0), Vector3(0.05, 0.42, 0.03), P.METAL, Color(0.94, 0.96, 0.98), STEEL_D)


static func _bomb(w: Node3D, band: Color) -> void:
	box(w, Vector3(0, 0.11, 0), Vector3(0.22, 0.22, 0.22), P.METAL, IRON, IRON_D)
	box(w, Vector3(0, 0.1, 0), Vector3(0.23, 0.07, 0.23), P.GLOW, band, Color(-1, 0, 0), Vector3.ZERO, {"glow": 1.4})
	box(w, Vector3(0, 0.25, 0), Vector3(0.03, 0.07, 0.03), P.WOOD, Color(0.75, 0.45, 0.2))
	box(w, Vector3(0.03, 0.29, 0), Vector3(0.06, 0.03, 0.03), P.WOOD, Color(0.75, 0.45, 0.2))


# --- Cloaked wanderer (reference 5) ----------------------------------------------

static func wanderer() -> Node3D:
	var root := Node3D.new()
	var skin := Color(0.84, 0.6, 0.42)
	var hair := Color(0.12, 0.09, 0.08)
	var cloak := Color(0.17, 0.15, 0.2)
	var cloak_d := Color(0.09, 0.08, 0.11)
	var spirit := Color(0.45, 0.4, 0.95)
	var cl := {"accent": spirit, "glow": 2.2, "rag": 0.4}
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.14, 0.15, 0.02), Vector3(0.23, 0.3, 0.28), P.LEATHER, Color(0.25, 0.16, 0.11), Color(0.15, 0.09, 0.06))
		box(root, Vector3(s * 0.14, 0.52, 0), Vector3(0.22, 0.46, 0.24), P.CLOTH, Color(0.2, 0.17, 0.17))
	box(root, Vector3(0, 1.06, 0), Vector3(0.56, 0.62, 0.32), P.CLOTH, Color(0.2, 0.19, 0.22))
	box(root, Vector3(0, 0.79, 0), Vector3(0.58, 0.08, 0.34), P.LEATHER, LEATHER, LEATHER_D)
	# Head: eyes, brows, beard, curly hair.
	box(root, Vector3(0, 1.62, 0), Vector3(0.46, 0.46, 0.44), P.PLAIN, skin)
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.1, 1.63, 0.222), Vector3(0.11, 0.065, 0.01), P.PLAIN, Color(0.92, 0.92, 0.9))
		box(root, Vector3(s * 0.08, 1.63, 0.228), Vector3(0.045, 0.065, 0.01), P.PLAIN, Color(0.17, 0.17, 0.24))
		box(root, Vector3(s * 0.1, 1.7, 0.225), Vector3(0.13, 0.03, 0.01), P.PLAIN, hair)
		box(root, Vector3(s * 0.215, 1.55, 0.06), Vector3(0.05, 0.22, 0.3), P.HAIR, hair, hair * 0.5)
	box(root, Vector3(0, 1.46, 0.19), Vector3(0.4, 0.14, 0.08), P.HAIR, hair, hair * 0.5)
	box(root, Vector3(0, 1.535, 0.228), Vector3(0.2, 0.03, 0.02), P.HAIR, hair)
	box(root, Vector3(0, 1.58, 0.232), Vector3(0.06, 0.04, 0.01), P.PLAIN, skin * 0.85)
	box(root, Vector3(0, 1.88, -0.01), Vector3(0.52, 0.14, 0.5), P.HAIR, hair, hair * 0.5)
	box(root, Vector3(0, 1.66, -0.21), Vector3(0.5, 0.46, 0.1), P.HAIR, hair, hair * 0.5)
	for k in 16:
		var hs := HashUtils.hash3(k, 3, 77)
		var a := HashUtils.to_unit(hs, 0) * TAU
		var r := 0.2 + HashUtils.to_unit(hs, 1) * 0.08
		var cs := 0.09 + HashUtils.to_unit(hs, 2) * 0.06
		box(root, Vector3(cos(a) * r, 1.92 + HashUtils.to_unit(hs, 3) * 0.06, sin(a) * r - 0.03), Vector3.ONE * cs, P.HAIR, hair, hair * 0.5)
	# Bare right arm with dark tattoo lines.
	var ra := pivot(root, Vector3(0.36, 1.31, 0), Vector3(0, 0, 8))
	box(ra, Vector3(0, -0.15, 0), Vector3(0.18, 0.3, 0.2), P.TATTOO, skin, Color(0.25, 0.15, 0.12))
	box(ra, Vector3(0, -0.42, 0), Vector3(0.17, 0.26, 0.19), P.TATTOO, skin, Color(0.25, 0.15, 0.12))
	box(ra, Vector3(0, -0.6, 0), Vector3(0.16, 0.12, 0.16), P.PLAIN, skin)
	var la := pivot(root, Vector3(-0.36, 1.31, 0), Vector3(0, 0, -6))
	box(la, Vector3(0, -0.15, 0), Vector3(0.19, 0.3, 0.21), P.CLOTH, cloak)
	box(la, Vector3(0, -0.42, 0), Vector3(0.18, 0.26, 0.2), P.CLOTH, cloak)
	box(la, Vector3(0, -0.6, 0), Vector3(0.16, 0.12, 0.16), P.PLAIN, skin)
	# The cloak: mantle, hood roll, long ragged panels with spirit specks.
	box(root, Vector3(0, 1.34, -0.02), Vector3(0.68, 0.16, 0.46), P.CURSED, cloak, cloak_d, Vector3.ZERO, {"accent": spirit})
	box(root, Vector3(0, 1.28, 0), Vector3(0.88, 0.14, 0.48), P.CURSED, cloak, cloak_d, Vector3.ZERO, {"accent": spirit})
	box(root, Vector3(0, 0.84, -0.24), Vector3(0.86, 1.3, 0.06), P.CURSED, cloak, cloak_d, Vector3.ZERO, cl)
	box(root, Vector3(-0.42, 0.86, -0.02), Vector3(0.06, 1.28, 0.44), P.CURSED, cloak, cloak_d, Vector3.ZERO, cl)
	box(root, Vector3(-0.26, 0.9, 0.2), Vector3(0.3, 1.2, 0.06), P.CURSED, cloak, cloak_d, Vector3.ZERO, cl)
	box(root, Vector3(0.46, 0.92, -0.12), Vector3(0.06, 1.1, 0.24), P.CURSED, cloak, cloak_d, Vector3.ZERO, cl)
	box(root, Vector3(0.14, 1.12, 0.18), Vector3(0.1, 0.32, 0.04), P.CURSED, cloak, cloak_d, Vector3.ZERO, cl)
	# Faces trapped in the cloak (glowing eyes) and two shadow echoes behind.
	for f in [Vector3(-0.3, 0.75, 0.235), Vector3(-0.15, 1.02, 0.235), Vector3(-0.45, 1.0, 0.1)]:
		var fc: Vector3 = f
		var side := Vector3(0, 0, 0.04) if fc.z < 0.2 else Vector3(0.04, 0, 0)
		box(root, fc, Vector3(0.14, 0.12, 0.02) if fc.z > 0.2 else Vector3(0.02, 0.12, 0.14), P.PLAIN, Color(0.25, 0.22, 0.3))
		for s: float in [-1.0, 1.0]:
			box(root, fc + side * s + Vector3(0, 0.01, 0.012 if fc.z > 0.2 else 0) + (Vector3(-0.012, 0, 0) if fc.z <= 0.2 else Vector3.ZERO),
				Vector3(0.02, 0.02, 0.01) if fc.z > 0.2 else Vector3(0.01, 0.02, 0.02), P.GLOW, Color(0.65, 0.85, 1.0))
	for s: float in [-1.0, 1.0]:
		var e := Vector3(s * 0.46, 1.72, -0.42)
		box(root, e, Vector3(0.4, 0.42, 0.38), P.PLAIN, Color(0.36, 0.3, 0.3))
		box(root, e + Vector3(0, 0.22, -0.02), Vector3(0.44, 0.1, 0.42), P.HAIR, hair, hair * 0.5)
		for t: float in [-1.0, 1.0]:
			box(root, e + Vector3(t * 0.09, 0.0, 0.195), Vector3(0.06, 0.04, 0.01), P.GLOW, Color(0.7, 0.85, 1.0), Color(-1, 0, 0), Vector3.ZERO, {"glow": 1.5})
	return root


# --- Bandaged sword (reference 6) ------------------------------------------------

static func bandaged_sword() -> Node3D:
	var root := Node3D.new()
	var edge := Color(0.84, 0.92, 0.95)
	var core := Color(0.36, 0.43, 0.5)
	var wrap := Color(0.86, 0.79, 0.64)
	var wrap_d := Color(0.62, 0.53, 0.41)
	box(root, Vector3(0, 0.08, 0), Vector3(0.14, 0.14, 0.08), P.METAL, Color(0.6, 0.7, 0.75), IRON_D, Vector3(0, 0, 45))
	box(root, Vector3(0, 0.08, 0), Vector3(0.06, 0.06, 0.09), P.PLAIN, IRON_D, Color(-1, 0, 0), Vector3(0, 0, 45))
	box(root, Vector3(0, 0.3, 0), Vector3(0.08, 0.32, 0.08), P.WRAP, Color(0.62, 0.55, 0.45), Color(0.3, 0.32, 0.38))
	box(root, Vector3(0, 0.5, 0), Vector3(0.42, 0.1, 0.12), P.METAL, IRON, IRON_D)
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.22, 0.5, 0), Vector3(0.08, 0.15, 0.14), P.METAL, Color(0.55, 0.62, 0.68), IRON_D)
	box(root, Vector3(0, 1.2, 0), Vector3(0.3, 1.3, 0.06), P.METAL, edge, Color(0.6, 0.7, 0.76))
	box(root, Vector3(0, 1.18, 0.0), Vector3(0.18, 1.22, 0.072), P.METAL, core, Color(0.24, 0.28, 0.34))
	box(root, Vector3(-0.02, 1.9, 0), Vector3(0.26, 0.1, 0.06), P.METAL, edge, Color(0.6, 0.7, 0.76))
	box(root, Vector3(-0.05, 1.98, 0), Vector3(0.18, 0.08, 0.06), P.METAL, edge, Color(0.6, 0.7, 0.76))
	box(root, Vector3(-0.08, 2.05, 0), Vector3(0.1, 0.06, 0.06), P.METAL, edge, Color(0.6, 0.7, 0.76))
	box(root, Vector3(0, 0.62, 0), Vector3(0.33, 0.07, 0.09), P.CLOTH, wrap, wrap_d)
	box(root, Vector3(0, 0.74, 0), Vector3(0.38, 0.07, 0.095), P.CLOTH, wrap, wrap_d, Vector3(0, 0, 32))
	box(root, Vector3(0, 0.74, 0), Vector3(0.38, 0.07, 0.1), P.CLOTH, wrap * 0.95, wrap_d, Vector3(0, 0, -32))
	box(root, Vector3(0, 0.88, 0), Vector3(0.33, 0.06, 0.09), P.CLOTH, wrap, wrap_d)
	return root
