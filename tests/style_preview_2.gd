extends RefCounted
## Style preview, batch 2 (not used by the game): townsfolk, copper armour,
## samurai, a tribal warband and elemental armour sets, after the owner's
## second set of reference pictures. Uses the box helpers of style_preview.gd.

const SP := preload("res://tests/style_preview.gd")
const P := SP.P
const NONE := Color(-1, 0, 0)
const GOLD := Color(0.95, 0.72, 0.3)
const GOLD_D := Color(0.66, 0.42, 0.16)
const LENS := Color(0.55, 0.95, 0.9)
const BLACK := Color(0.12, 0.11, 0.13)


static func box(parent: Node3D, pos: Vector3, size: Vector3, pat: int, col: Color, dark := NONE, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
	return SP.box(parent, pos, size, pat, col, dark, rot, opts)


## Basic body: boots, legs, torso, head. Arms come from arm().
static func body(root: Node3D, skin: Color, top: Color, legs: Color, boots: Color, top_pat := P.CLOTH) -> void:
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.14, 0.14, 0.02), Vector3(0.23, 0.28, 0.28), P.LEATHER, boots)
		box(root, Vector3(s * 0.14, 0.5, 0), Vector3(0.22, 0.46, 0.24), P.CLOTH, legs)
	box(root, Vector3(0, 1.04, 0), Vector3(0.56, 0.64, 0.32), top_pat, top)
	box(root, Vector3(0, 1.62, 0), Vector3(0.46, 0.46, 0.44), P.PLAIN, skin)


## An arm from the shoulder to the hand spot, with a sleeve and a hand.
static func arm(root: Node3D, side: float, hand: Vector3, sleeve: Color, skin: Color, sleeve_pat := P.CLOTH) -> Node3D:
	var sh := Vector3(side * 0.37, 1.3, 0)
	var a := SP.aim(root, sh, hand)
	var l := (hand - sh).length()
	box(a, Vector3(0, -l * 0.42, 0), Vector3(0.19, l * 0.9, 0.2), sleeve_pat, sleeve)
	box(a, Vector3(0, -l * 0.92, 0), Vector3(0.16, 0.14, 0.16), P.PLAIN, skin)
	return a


static func eyes(root: Node3D, y: float, iris: Color, white := Color(0.94, 0.94, 0.92)) -> void:
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.1, y, 0.222), Vector3(0.11, 0.065, 0.01), P.PLAIN, white)
		box(root, Vector3(s * 0.075, y, 0.228), Vector3(0.05, 0.065, 0.01), P.PLAIN, iris)


static func glasses(root: Node3D, y: float, frame := GOLD) -> void:
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.11, y, 0.232), Vector3(0.15, 0.13, 0.02), P.PLAIN, frame)
		box(root, Vector3(s * 0.11, y, 0.24), Vector3(0.1, 0.08, 0.01), P.GLOW, LENS, NONE, Vector3.ZERO, {"glow": 1.2})


static func beard(root: Node3D, col: Color, long := 0.3) -> void:
	box(root, Vector3(0, 1.48 - long * 0.3, 0.2), Vector3(0.48, 0.2 + long * 0.6, 0.12), P.HAIR, col, col * 0.75)
	box(root, Vector3(0, 1.53, 0.235), Vector3(0.3, 0.05, 0.04), P.HAIR, col, col * 0.75)
	for s: float in [-1.0, 1.0]:
		box(root, Vector3(s * 0.22, 1.56, 0.06), Vector3(0.05, 0.24, 0.32), P.HAIR, col, col * 0.75)


static func trim(root: Node3D, pos: Vector3, size: Vector3) -> void:
	box(root, pos, size, P.METAL, GOLD, GOLD_D)


# --- Townsfolk (reference: six villagers) ----------------------------------------

static func witch() -> Node3D:
	var r := Node3D.new()
	var robe := Color(0.42, 0.25, 0.48)
	var robe_d := Color(0.27, 0.14, 0.33)
	var skin := Color(0.92, 0.72, 0.6)
	body(r, skin, robe, robe_d, Color(0.32, 0.2, 0.17))
	box(r, Vector3(0, 0.62, 0.0), Vector3(0.62, 0.6, 0.36), P.CLOTH, robe, robe_d, Vector3.ZERO, {"rag": 0.15})
	trim(r, Vector3(0, 0.34, 0.0), Vector3(0.64, 0.05, 0.38))
	trim(r, Vector3(0, 1.05, 0.165), Vector3(0.06, 0.62, 0.02))
	box(r, Vector3(0, 0.82, 0), Vector3(0.58, 0.07, 0.34), P.LEATHER, BLACK)
	trim(r, Vector3(0, 0.82, 0.175), Vector3(0.12, 0.1, 0.02))
	for s: float in [-1.0, 1.0]:
		trim(r, Vector3(s * 0.14, 0.22, 0.165), Vector3(0.1, 0.04, 0.02))
		arm(r, s, Vector3(s * 0.33, 0.78, 0.18), robe, skin)
	# Pink hair with a fringe, round glowing glasses.
	var pink := Color(0.88, 0.55, 0.62)
	box(r, Vector3(0, 1.7, 0.21), Vector3(0.48, 0.12, 0.06), P.HAIR, pink)
	box(r, Vector3(0, 1.58, -0.2), Vector3(0.5, 0.5, 0.1), P.HAIR, pink)
	glasses(r, 1.6)
	# Big hat: wide brim, tall crown that bends back, gem on the band.
	box(r, Vector3(0, 1.88, 0), Vector3(1.0, 0.07, 0.94), P.CLOTH, robe, robe_d)
	box(r, Vector3(0, 2.02, 0), Vector3(0.56, 0.22, 0.52), P.CLOTH, robe, robe_d)
	box(r, Vector3(0, 2.18, -0.02), Vector3(0.42, 0.16, 0.4), P.CLOTH, robe, robe_d)
	box(r, Vector3(0, 2.32, -0.08), Vector3(0.28, 0.16, 0.28), P.CLOTH, robe, robe_d)
	box(r, Vector3(0.06, 2.44, -0.18), Vector3(0.16, 0.12, 0.16), P.CLOTH, robe, robe_d)
	box(r, Vector3(0.16, 2.5, -0.26), Vector3(0.12, 0.08, 0.1), P.CLOTH, robe, robe_d)
	box(r, Vector3(0, 1.95, 0.265), Vector3(0.16, 0.16, 0.03), P.METAL, GOLD, GOLD_D)
	box(r, Vector3(0, 1.95, 0.28), Vector3(0.09, 0.09, 0.02), P.GLOW, LENS, NONE, Vector3.ZERO, {"glow": 1.8})
	return r


static func adventurer() -> Node3D:
	var r := Node3D.new()
	var skin := Color(0.88, 0.66, 0.5)
	var green := Color(0.28, 0.5, 0.3)
	body(r, skin, green, Color(0.3, 0.2, 0.16), Color(0.4, 0.26, 0.18))
	eyes(r, 1.62, Color(0.2, 0.3, 0.55))
	box(r, Vector3(0, 0.66, 0.0), Vector3(0.6, 0.2, 0.34), P.CLOTH, green, green * 0.7)
	box(r, Vector3(0, 0.82, 0), Vector3(0.58, 0.08, 0.34), P.LEATHER, SP.LEATHER, SP.LEATHER_D)
	trim(r, Vector3(0, 0.82, 0.175), Vector3(0.13, 0.11, 0.02))
	box(r, Vector3(0.2, 0.72, 0.18), Vector3(0.14, 0.14, 0.06), P.LEATHER, SP.LEATHER)  # pouch
	box(r, Vector3(0, 1.38, 0.05), Vector3(0.5, 0.08, 0.36), P.CLOTH, Color(0.72, 0.2, 0.16))  # scarf
	box(r, Vector3(0.05, 1.12, 0.17), Vector3(0.08, 0.5, 0.02), P.LEATHER, SP.LEATHER, NONE, Vector3(0, 0, 30))
	# Backpack with a bedroll.
	box(r, Vector3(0, 1.05, -0.27), Vector3(0.46, 0.56, 0.22), P.CLOTH, Color(0.3, 0.45, 0.32))
	box(r, Vector3(0, 1.38, -0.3), Vector3(0.6, 0.14, 0.16), P.CLOTH, Color(0.62, 0.48, 0.32))
	# Hat with a red feather.
	var hat := Color(0.48, 0.3, 0.2)
	box(r, Vector3(0, 1.86, 0), Vector3(0.76, 0.06, 0.7), P.LEATHER, hat)
	box(r, Vector3(0, 1.97, 0), Vector3(0.48, 0.18, 0.46), P.LEATHER, hat)
	box(r, Vector3(0, 1.92, 0), Vector3(0.5, 0.06, 0.48), P.CLOTH, Color(0.25, 0.42, 0.28))
	box(r, Vector3(0.22, 2.06, -0.1), Vector3(0.05, 0.3, 0.06), P.HAIR, Color(0.75, 0.2, 0.16), NONE, Vector3(-35, 0, -25))
	arm(r, -1.0, Vector3(-0.36, 0.78, 0.12), green, skin)
	# Staff with a hanging lantern.
	var hand := Vector3(0.42, 1.02, 0.3)
	arm(r, 1.0, hand, green, skin)
	var staff := SP.pivot(r, hand, Vector3(0, 0, -6))
	box(staff, Vector3(0, 0.2, 0), Vector3(0.07, 1.9, 0.07), P.WOOD, Color(0.55, 0.3, 0.2), Color(0.38, 0.18, 0.12))
	box(staff, Vector3(-0.1, 1.12, 0), Vector3(0.24, 0.07, 0.07), P.WOOD, Color(0.55, 0.3, 0.2))
	box(staff, Vector3(-0.2, 1.0, 0), Vector3(0.03, 0.12, 0.03), P.METAL, SP.IRON)
	box(staff, Vector3(-0.2, 0.84, 0), Vector3(0.16, 0.06, 0.16), P.METAL, SP.IRON, SP.IRON_D)
	box(staff, Vector3(-0.2, 0.72, 0), Vector3(0.12, 0.18, 0.12), P.GLOW, Color(1.0, 0.82, 0.35), NONE, Vector3.ZERO, {"glow": 3.0})
	box(staff, Vector3(-0.2, 0.6, 0), Vector3(0.16, 0.06, 0.16), P.METAL, SP.IRON, SP.IRON_D)
	return r


static func cook() -> Node3D:
	var r := Node3D.new()
	var skin := Color(0.93, 0.74, 0.62)
	var shirt := Color(0.4, 0.26, 0.24)
	var white := Color(0.92, 0.9, 0.86)
	body(r, skin, shirt, Color(0.35, 0.24, 0.2), Color(0.32, 0.2, 0.17))
	eyes(r, 1.6, Color(0.25, 0.18, 0.15))
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.16, 1.54, 0.225), Vector3(0.07, 0.04, 0.01), P.PLAIN, Color(0.95, 0.55, 0.55))  # cheeks
	box(r, Vector3(0, 1.8, 0.0), Vector3(0.5, 0.12, 0.48), P.HAIR, Color(0.42, 0.24, 0.16))
	box(r, Vector3(0, 0.82, 0.17), Vector3(0.52, 0.86, 0.03), P.CLOTH, white, white * 0.8)
	box(r, Vector3(0, 1.32, 0.17), Vector3(0.3, 0.16, 0.03), P.CLOTH, white, white * 0.8)
	box(r, Vector3(0, 2.0, 0), Vector3(0.48, 0.3, 0.46), P.CLOTH, white, white * 0.8)
	box(r, Vector3(0, 2.2, 0), Vector3(0.66, 0.2, 0.62), P.CLOTH, white, white * 0.8)
	arm(r, -1.0, Vector3(-0.38, 0.8, 0.12), shirt, skin)
	var hand := Vector3(0.42, 0.86, 0.22)
	arm(r, 1.0, hand, shirt, skin)
	box(r, hand + Vector3(0.02, -0.14, 0.08), Vector3(0.04, 0.12, 0.04), P.WOOD, SP.WOOD)
	box(r, hand + Vector3(0.02, -0.3, 0.1), Vector3(0.03, 0.22, 0.2), P.METAL, SP.STEEL, SP.STEEL_D)
	return r


static func dwarf() -> Node3D:
	var r := Node3D.new()
	var b := SP.pivot(r, Vector3.ZERO)
	b.scale = Vector3(1.12, 0.84, 1.12)
	var skin := Color(0.9, 0.66, 0.54)
	var leather := Color(0.38, 0.27, 0.24)
	body(b, skin, leather, Color(0.24, 0.3, 0.3), Color(0.26, 0.18, 0.15), P.LEATHER)
	box(b, Vector3(0, 0.82, 0), Vector3(0.6, 0.1, 0.36), P.LEATHER, BLACK)
	box(b, Vector3(0, 0.82, 0.185), Vector3(0.14, 0.12, 0.02), P.METAL, SP.STEEL, SP.STEEL_D)
	beard(b, Color(0.94, 0.93, 0.9), 0.7)
	box(b, Vector3(0, 1.58, 0.235), Vector3(0.1, 0.1, 0.06), P.PLAIN, skin * 0.92)  # nose
	var cap := Color(0.26, 0.36, 0.36)
	box(b, Vector3(0, 1.86, 0), Vector3(0.52, 0.2, 0.5), P.CLOTH, cap)
	box(b, Vector3(0, 1.76, 0), Vector3(0.54, 0.06, 0.52), P.LEATHER, SP.LEATHER)
	glasses(b, 1.76, SP.IRON)
	for s: float in [-1.0, 1.0]:
		box(b, Vector3(s * 0.38, 1.32, 0), Vector3(0.26, 0.16, 0.36), P.LEATHER, leather * 0.85)
	arm(b, 1.0, Vector3(0.4, 0.84, 0.14), leather, skin, P.LEATHER)
	var hand := Vector3(-0.42, 0.9, 0.24)
	arm(b, -1.0, hand, leather, skin, P.LEATHER)
	box(b, hand + Vector3(0, -0.12, 0.12), Vector3(0.5, 0.56, 0.08), P.METAL, Color(0.7, 0.7, 0.7), Color(0.45, 0.45, 0.47))
	box(b, hand + Vector3(0, -0.12, 0.165), Vector3(0.3, 0.36, 0.02), P.METAL, Color(0.78, 0.78, 0.78), Color(0.5, 0.5, 0.52))
	return r


static func old_wizard() -> Node3D:
	var r := Node3D.new()
	var robe := Color(0.27, 0.36, 0.6)
	var robe_d := Color(0.17, 0.22, 0.42)
	var skin := Color(0.88, 0.68, 0.56)
	var orange := Color(0.95, 0.6, 0.28)
	body(r, skin, robe, robe_d, Color(0.35, 0.2, 0.18))
	box(r, Vector3(0, 0.56, 0.0), Vector3(0.64, 0.74, 0.38), P.CLOTH, robe, robe_d)
	box(r, Vector3(0, 0.2, 0.0), Vector3(0.66, 0.05, 0.4), P.METAL, orange, orange * 0.7)
	box(r, Vector3(-0.1, 0.8, 0.195), Vector3(0.05, 1.0, 0.02), P.METAL, orange, orange * 0.7)
	box(r, Vector3(0, 0.88, 0), Vector3(0.6, 0.08, 0.36), P.LEATHER, BLACK)
	box(r, Vector3(0.12, 0.88, 0.185), Vector3(0.12, 0.12, 0.02), P.METAL, GOLD, GOLD_D)
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.38, 1.33, 0), Vector3(0.24, 0.1, 0.36), P.CLOTH, robe, robe_d)
		box(r, Vector3(s * 0.5, 1.33, 0), Vector3(0.02, 0.12, 0.38), P.METAL, orange, orange * 0.7)
	var white := Color(0.94, 0.94, 0.92)
	beard(r, white, 1.2)
	glasses(r, 1.63)
	box(r, Vector3(0, 1.88, -0.02), Vector3(0.52, 0.16, 0.5), P.HAIR, white, white * 0.78)
	box(r, Vector3(0, 1.62, -0.21), Vector3(0.52, 0.48, 0.1), P.HAIR, white, white * 0.78)
	for k in 6:
		box(r, Vector3(-0.2 + k * 0.08, 1.98 + (k % 2) * 0.06, -0.02), Vector3(0.1, 0.1, 0.12), P.HAIR, white, white * 0.78)
	box(r, Vector3(0.24, 2.12, -0.04), Vector3(0.06, 0.14, 0.06), P.HAIR, white, NONE, Vector3(0, 0, -30))
	arm(r, 1.0, Vector3(0.4, 0.82, 0.12), robe, skin)
	var hand := Vector3(-0.4, 0.92, 0.26)
	arm(r, -1.0, hand, robe, skin)
	box(r, hand + Vector3(0, 0.0, 0.12), Vector3(0.1, 0.36, 0.26), P.LEATHER, Color(0.6, 0.35, 0.22))
	box(r, hand + Vector3(0.005, 0.0, 0.12), Vector3(0.11, 0.32, 0.2), P.PLAIN, Color(0.95, 0.9, 0.78))
	return r


static func merchant() -> Node3D:
	var r := Node3D.new()
	var skin := Color(0.9, 0.7, 0.58)
	var coat := Color(0.62, 0.28, 0.2)
	var coat_d := Color(0.42, 0.16, 0.12)
	var vest := Color(0.22, 0.42, 0.38)
	body(r, skin, vest, Color(0.3, 0.22, 0.2), Color(0.26, 0.18, 0.15))
	# Long open coat with gold edges.
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.22, 0.86, 0.0), Vector3(0.16, 1.0, 0.36), P.CLOTH, coat, coat_d)
		box(r, Vector3(s * 0.15, 0.86, 0.185), Vector3(0.03, 1.0, 0.02), P.METAL, GOLD, GOLD_D)
		box(r, Vector3(s * 0.38, 1.3, 0), Vector3(0.26, 0.14, 0.38), P.CLOTH, coat, coat_d)
	box(r, Vector3(0, 0.86, -0.18), Vector3(0.6, 1.0, 0.04), P.CLOTH, coat, coat_d)
	trim(r, Vector3(0, 0.36, 0.0), Vector3(0.62, 0.04, 0.38))
	for k in 3:
		box(r, Vector3(0, 1.22 - k * 0.14, 0.165), Vector3(0.05, 0.05, 0.02), P.METAL, GOLD, GOLD_D)
	eyes(r, 1.64, Color(0.2, 0.18, 0.2))
	box(r, Vector3(-0.1, 1.64, 0.235), Vector3(0.14, 0.13, 0.02), P.METAL, GOLD, GOLD_D)
	box(r, Vector3(-0.1, 1.64, 0.243), Vector3(0.09, 0.08, 0.01), P.GLOW, LENS, NONE, Vector3.ZERO, {"glow": 1.2})
	box(r, Vector3(0, 1.55, 0.25), Vector3(0.1, 0.1, 0.06), P.PLAIN, skin * 0.92)
	# Big curled moustache and eyebrows.
	var brown := Color(0.42, 0.26, 0.16)
	box(r, Vector3(0, 1.49, 0.245), Vector3(0.36, 0.08, 0.06), P.HAIR, brown, brown * 0.7)
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.22, 1.53, 0.24), Vector3(0.1, 0.12, 0.06), P.HAIR, brown, brown * 0.7)
		box(r, Vector3(s * 0.25, 1.62, 0.24), Vector3(0.06, 0.08, 0.05), P.HAIR, brown, brown * 0.7)
		box(r, Vector3(s * 0.1, 1.72, 0.228), Vector3(0.14, 0.04, 0.02), P.HAIR, brown)
	box(r, Vector3(0, 1.86, 0.0), Vector3(0.44, 0.04, 0.42), P.PLAIN, skin * 1.04)  # bald top
	for s: float in [-1.0, 1.0]:
		var hand := Vector3(s * 0.12, 0.98, 0.26)
		arm(r, s, hand, coat, Color(0.22, 0.16, 0.15))
	return r


# --- Copper armour (reference: copper golem set) ---------------------------------

const COPPER := Color(0.88, 0.5, 0.38)
const COPPER_D := Color(0.62, 0.32, 0.24)
const VERDI := Color(0.45, 0.78, 0.62)


static func copper_knight() -> Node3D:
	var r := Node3D.new()
	var cop := {"accent": VERDI}
	body(r, BLACK, BLACK, BLACK, BLACK)
	# Helmet: a box with a dark face slot, a grill mouth and side lamps.
	box(r, Vector3(0, 1.66, 0), Vector3(0.6, 0.6, 0.58), P.PATINA, COPPER, COPPER_D, Vector3.ZERO, cop)
	box(r, Vector3(0, 1.7, 0.29), Vector3(0.34, 0.34, 0.02), P.PLAIN, Color(0.08, 0.07, 0.08))
	box(r, Vector3(0, 1.43, 0.25), Vector3(0.62, 0.12, 0.12), P.TEETH, COPPER, VERDI)
	box(r, Vector3(0, 2.0, 0), Vector3(0.42, 0.1, 0.42), P.PATINA, COPPER, COPPER_D, Vector3.ZERO, cop)
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.31, 1.7, 0.08), Vector3(0.04, 0.1, 0.1), P.GLOW, Color(1.0, 0.85, 0.45))
	box(r, Vector3(0, 2.18, 0), Vector3(0.06, 0.28, 0.06), P.WOOD, Color(0.55, 0.38, 0.3))
	box(r, Vector3(0, 2.36, 0), Vector3(0.14, 0.14, 0.14), P.PATINA, VERDI, VERDI * 0.7, Vector3.ZERO, {"accent": COPPER})
	# Chest plate and shoulder lamps.
	box(r, Vector3(0, 1.08, 0.02), Vector3(0.62, 0.52, 0.38), P.PATINA, COPPER, COPPER_D, Vector3.ZERO, cop)
	box(r, Vector3(0, 1.08, 0.215), Vector3(0.26, 0.26, 0.02), P.PATINA, VERDI, VERDI * 0.7, Vector3.ZERO, {"accent": COPPER})
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.42, 1.34, 0), Vector3(0.3, 0.3, 0.36), P.PATINA, COPPER, COPPER_D, Vector3.ZERO, cop)
		box(r, Vector3(s * 0.58, 1.34, 0), Vector3(0.04, 0.18, 0.2), P.GLOW, Color(1.0, 0.85, 0.45))
	arm(r, -1.0, Vector3(-0.42, 0.8, 0.1), BLACK, COPPER)
	var hand := Vector3(0.44, 0.98, 0.32)
	arm(r, 1.0, hand, BLACK, COPPER)
	# Lightning puff from the antenna (white smoke cubes).
	for k in 4:
		box(r, Vector3(0.08 + (k % 2) * 0.1, 2.5 + k * 0.14, -0.02), Vector3.ONE * (0.16 - k * 0.025), P.GLOW, Color(0.95, 0.97, 1.0), NONE, Vector3.ZERO, {"glow": 0.6})
	# Bent copper sword.
	var sw := SP.pivot(r, hand, Vector3(70, 0, 0))
	box(sw, Vector3(0, -0.08, 0), Vector3(0.07, 0.2, 0.07), P.WOOD, Color(0.55, 0.38, 0.3))
	box(sw, Vector3(0, 0.06, 0), Vector3(0.3, 0.1, 0.12), P.PATINA, COPPER, COPPER_D, Vector3.ZERO, cop)
	box(sw, Vector3(0, 0.06, 0.065), Vector3(0.08, 0.08, 0.02), P.GLOW, Color(1.0, 0.85, 0.45))
	for k in 6:
		box(sw, Vector3(0.012 * k * k * 0.3, 0.2 + k * 0.13, 0), Vector3(0.12, 0.15, 0.04), P.PATINA, VERDI, VERDI * 0.65, Vector3(0, 0, -k * 3.0), {"accent": COPPER * 0.8})
	return r


# --- Samurai (reference: oni samurai and straw-hat ronin) ------------------------

static func oni_samurai() -> Node3D:
	var r := Node3D.new()
	var lac := Color(0.42, 0.4, 0.26)
	var lac_d := Color(0.26, 0.24, 0.16)
	var plum := Color(0.3, 0.26, 0.34)
	var red := Color(0.7, 0.14, 0.14)
	var mane := Color(0.92, 0.9, 0.82)
	body(r, Color(0.6, 0.12, 0.1), plum, Color(0.24, 0.22, 0.26), Color(0.22, 0.2, 0.18))
	# Layered skirt plates and shoulder plates.
	for k in 3:
		box(r, Vector3(0, 0.82 - k * 0.12, 0), Vector3(0.66 - k * 0.02, 0.12, 0.4), P.METAL, plum if k % 2 == 0 else lac, lac_d)
	box(r, Vector3(0, 1.1, 0.02), Vector3(0.62, 0.48, 0.38), P.METAL, lac, lac_d)
	for k in 4:
		box(r, Vector3(0, 0.96 + k * 0.1, 0.205), Vector3(0.56, 0.03, 0.02), P.PLAIN, Color(0.85, 0.8, 0.7))
	for s: float in [-1.0, 1.0]:
		for k in 3:
			box(r, Vector3(s * (0.42 + k * 0.03), 1.36 - k * 0.12, 0), Vector3(0.28, 0.1, 0.42), P.METAL, lac if k % 2 == 0 else plum, lac_d)
	# Red rope belt with hanging tassels.
	box(r, Vector3(0, 0.88, 0.0), Vector3(0.66, 0.06, 0.42), P.WRAP, red, red * 0.6)
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.08, 0.62, 0.22), Vector3(0.04, 0.48, 0.04), P.WRAP, red, mane)
	# Oni mask: red face, gold eyes, white fangs; horned helmet; wild white mane.
	box(r, Vector3(0, 1.6, 0.235), Vector3(0.44, 0.36, 0.04), P.PLAIN, red)
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.1, 1.68, 0.258), Vector3(0.1, 0.05, 0.01), P.GLOW, Color(1.0, 0.75, 0.2), NONE, Vector3.ZERO, {"glow": 2.0})
		box(r, Vector3(s * 0.25, 2.12, 0.0), Vector3(0.08, 0.5, 0.08), P.METAL, lac, lac_d, Vector3(0, 0, -s * 10.0))
	box(r, Vector3(0, 1.5, 0.258), Vector3(0.28, 0.08, 0.01), P.TEETH, Color(0.96, 0.95, 0.9), Color(0.15, 0.05, 0.05))
	box(r, Vector3(0, 1.86, 0.0), Vector3(0.52, 0.14, 0.5), P.METAL, lac, lac_d)
	for k in 26:
		var h := HashUtils.hash3(k, 9, 31)
		var a := (HashUtils.to_unit(h, 0) - 0.5) * PI * 1.4 + PI
		var rr := 0.26 + HashUtils.to_unit(h, 1) * 0.12
		var y := 1.45 + HashUtils.to_unit(h, 2) * 0.55
		box(r, Vector3(sin(a) * rr, y, cos(a) * rr * 0.9 - 0.02), Vector3.ONE * (0.07 + HashUtils.to_unit(h, 3) * 0.07), P.HAIR, mane, mane * 0.75)
	arm(r, 1.0, Vector3(0.42, 0.82, 0.12), plum, Color(0.22, 0.2, 0.18), P.METAL)
	arm(r, -1.0, Vector3(-0.42, 0.82, 0.12), plum, Color(0.22, 0.2, 0.18), P.METAL)
	return r


static func ronin() -> Node3D:
	var r := Node3D.new()
	var kimono := Color(0.2, 0.18, 0.2)
	var kimono_d := Color(0.12, 0.1, 0.12)
	var red := Color(0.55, 0.14, 0.16)
	body(r, Color(0.9, 0.72, 0.6), kimono, kimono, Color(0.9, 0.9, 0.88))
	box(r, Vector3(0, 0.5, 0.0), Vector3(0.62, 0.84, 0.36), P.CLOTH, kimono, kimono_d)  # hakama
	box(r, Vector3(0, 0.12, 0.0), Vector3(0.64, 0.05, 0.38), P.TEETH, Color(0.9, 0.9, 0.88), kimono_d)
	box(r, Vector3(0, 0.9, 0), Vector3(0.6, 0.14, 0.36), P.WRAP, red, red * 0.6)  # obi
	box(r, Vector3(0.1, 0.68, 0.19), Vector3(0.06, 0.32, 0.03), P.WRAP, red, red * 0.6)
	box(r, Vector3(0, 1.3, 0.165), Vector3(0.18, 0.2, 0.02), P.PLAIN, Color(0.92, 0.9, 0.86))  # collar
	for s: float in [-1.0, 1.0]:
		arm(r, s, Vector3(s * 0.44, 0.82, 0.1), kimono, Color(0.9, 0.72, 0.6))
		box(r, Vector3(s * 0.44, 0.86, 0.1), Vector3(0.24, 0.12, 0.24), P.PLAIN, Color(0.9, 0.9, 0.88))
	# Katana at the hip.
	box(r, Vector3(-0.32, 0.92, 0.0), Vector3(0.06, 0.06, 1.0), P.LEATHER, Color(0.3, 0.16, 0.12), NONE, Vector3(18, 0, 0))
	box(r, Vector3(-0.32, 1.08, 0.48), Vector3(0.06, 0.06, 0.28), P.WRAP, Color(0.45, 0.28, 0.2), BLACK, Vector3(18, 0, 0))
	# Big woven straw hat covering the eyes.
	var straw := Color(0.88, 0.68, 0.32)
	var straw_d := Color(0.62, 0.44, 0.18)
	box(r, Vector3(0, 1.8, 0.02), Vector3(1.2, 0.08, 1.2), P.STRAW, straw, straw_d)
	box(r, Vector3(0, 1.88, 0.02), Vector3(0.9, 0.1, 0.9), P.STRAW, straw, straw_d)
	box(r, Vector3(0, 1.97, 0.02), Vector3(0.56, 0.1, 0.56), P.STRAW, straw, straw_d)
	box(r, Vector3(0, 2.05, 0.02), Vector3(0.22, 0.07, 0.22), P.STRAW, straw, straw_d)
	return r


static func red_katana() -> Node3D:
	var r := Node3D.new()
	box(r, Vector3(-0.55, 0.05, 0), Vector3(0.32, 0.05, 0.05), P.WRAP, Color(0.45, 0.28, 0.2), BLACK)
	box(r, Vector3(-0.38, 0.05, 0), Vector3(0.04, 0.12, 0.12), P.METAL, SP.IRON, SP.IRON_D)
	for k in 8:
		box(r, Vector3(-0.28 + k * 0.13, 0.05, 0.004 * k * k), Vector3(0.14, 0.03, 0.05), P.METAL, Color(0.92, 0.42, 0.5), Color(0.6, 0.2, 0.28), Vector3(0, -k * 2.0, 0))
	return r


# --- Tribal warband (reference: tusked brutes with a banner) ---------------------

static func brute(big: float, weapon: int) -> Node3D:
	var r := Node3D.new()
	var b := SP.pivot(r, Vector3.ZERO)
	b.scale = Vector3.ONE * big
	var skin := Color(0.78, 0.48, 0.36)
	var skin_d := Color(0.55, 0.3, 0.22)
	var red := Color(0.55, 0.18, 0.14)
	body(b, skin, skin, Color(0.3, 0.28, 0.32), Color(0.25, 0.2, 0.2), P.PLAIN)
	box(b, Vector3(0, 0.66, 0), Vector3(0.62, 0.36, 0.36), P.CLOTH, red, red * 0.6, Vector3.ZERO, {"rag": 0.5})
	box(b, Vector3(0, 0.86, 0), Vector3(0.6, 0.08, 0.36), P.LEATHER, BLACK)
	box(b, Vector3(0, 0.86, 0.185), Vector3(0.14, 0.12, 0.02), P.METAL, GOLD, GOLD_D)
	box(b, Vector3(0.0, 1.1, 0.17), Vector3(0.08, 0.6, 0.02), P.LEATHER, BLACK, NONE, Vector3(0, 0, 35))
	# Square head with a snout, tusks, white eyes and a black topknot.
	box(b, Vector3(0, 1.7, 0), Vector3(0.6, 0.56, 0.52), P.PLAIN, skin)
	box(b, Vector3(0, 1.58, 0.29), Vector3(0.26, 0.18, 0.08), P.PLAIN, skin_d)
	for s: float in [-1.0, 1.0]:
		box(b, Vector3(s * 0.06, 1.58, 0.335), Vector3(0.05, 0.06, 0.01), P.PLAIN, Color(0.2, 0.1, 0.08))
		box(b, Vector3(s * 0.18, 1.5, 0.28), Vector3(0.05, 0.12, 0.05), P.BONE, Color(0.95, 0.92, 0.8))
		box(b, Vector3(s * 0.15, 1.75, 0.265), Vector3(0.1, 0.1, 0.01), P.PLAIN, Color(0.95, 0.94, 0.88))
		box(b, Vector3(s * 0.16, 1.75, 0.27), Vector3(0.04, 0.05, 0.01), P.PLAIN, Color(0.15, 0.12, 0.1))
		box(b, Vector3(s * 0.33, 1.84, 0), Vector3(0.08, 0.16, 0.12), P.PLAIN, skin_d, NONE, Vector3(0, 0, s * 30.0))
	for k in 3:
		box(b, Vector3(-0.05 + k * 0.05, 2.06 + k * 0.03, -0.04), Vector3(0.04, 0.24, 0.04), P.HAIR, BLACK, NONE, Vector3(0, 0, (k - 1) * 15.0))
	for s: float in [-1.0, 1.0]:
		box(b, Vector3(s * 0.4, 1.34, 0), Vector3(0.3, 0.2, 0.38), P.METAL, GOLD, GOLD_D)
	arm(b, -1.0, Vector3(-0.44, 0.84, 0.12), skin, skin_d, P.PLAIN)
	var hand := Vector3(0.48, 0.98, 0.3)
	arm(b, 1.0, hand, skin, skin_d, P.PLAIN)
	var w := SP.pivot(b, hand, Vector3(-20, 0, -15))
	box(w, Vector3(0, 0.25, 0), Vector3(0.07, 0.9, 0.07), P.WOOD, SP.WOOD, SP.WOOD_D)
	if weapon == 0:  # gold cube mace with a spiral face
		box(w, Vector3(0, 0.8, 0), Vector3(0.3, 0.3, 0.3), P.METAL, GOLD, GOLD_D)
		box(w, Vector3(0, 0.8, 0.152), Vector3(0.16, 0.16, 0.01), P.TEETH, GOLD_D, GOLD)
	else:  # hook staff
		box(w, Vector3(0.1, 0.72, 0), Vector3(0.24, 0.07, 0.08), P.METAL, GOLD, GOLD_D)
		box(w, Vector3(0.2, 0.62, 0), Vector3(0.07, 0.2, 0.08), P.METAL, GOLD, GOLD_D)
	return r


static func banner() -> Node3D:
	var r := Node3D.new()
	var red := Color(0.6, 0.2, 0.15)
	box(r, Vector3(0, 1.3, 0), Vector3(0.08, 2.6, 0.08), P.WOOD, SP.WOOD, SP.WOOD_D)
	box(r, Vector3(0, 2.42, 0.06), Vector3(0.9, 0.06, 0.06), P.WOOD, SP.WOOD, SP.WOOD_D)
	box(r, Vector3(0, 1.95, 0.08), Vector3(0.8, 0.9, 0.03), P.CLOTH, red, red * 0.6)
	box(r, Vector3(0, 1.95, 0.08), Vector3(0.86, 0.96, 0.02), P.METAL, GOLD, GOLD_D)
	for k in 4:
		box(r, Vector3(0, 1.45 - k * 0.06, 0.08), Vector3(0.7 - k * 0.18, 0.06, 0.03), P.METAL, GOLD if k % 2 == 0 else red, GOLD_D)
	box(r, Vector3(0, 2.0, 0.1), Vector3(0.2, 0.2, 0.02), P.METAL, GOLD, GOLD_D)
	box(r, Vector3(0, 2.0, 0.112), Vector3(0.1, 0.1, 0.01), P.PLAIN, red * 0.7)
	# Skull on top.
	box(r, Vector3(0, 2.62, 0.04), Vector3(0.3, 0.26, 0.28), P.BONE, SP.BONE, SP.BONE_D)
	for s: float in [-1.0, 1.0]:
		box(r, Vector3(s * 0.07, 2.62, 0.185), Vector3(0.08, 0.07, 0.01), P.PLAIN, Color(0.5, 0.08, 0.08))
	return r


# --- Elemental armour sets (reference: eight themed sets on dark bodies) ---------

## 0 amethyst, 1 spectral bone, 2 stone spiral, 3 sun (teal and orange).
static func armour_set(kind: int) -> Node3D:
	var r := Node3D.new()
	var dark := Color(0.13, 0.12, 0.15)
	body(r, dark, dark, dark, dark, P.CLOTH)
	for s: float in [-1.0, 1.0]:
		arm(r, s, Vector3(s * 0.42, 0.82, 0.1), dark, dark)
	match kind:
		0:
			var am := Color(0.7, 0.45, 0.95)
			var am_d := Color(0.42, 0.24, 0.66)
			box(r, Vector3(0, 0.95, -0.22), Vector3(0.8, 1.2, 0.05), P.CLOTH, Color(0.5, 0.3, 0.72), am_d, Vector3.ZERO, {"rag": 0.15})
			box(r, Vector3(0, 0.36, -0.22), Vector3(0.82, 0.05, 0.06), P.METAL, GOLD, GOLD_D)
			box(r, Vector3(0, 1.66, 0.24), Vector3(0.24, 0.24, 0.03), P.METAL, GOLD, GOLD_D)
			box(r, Vector3(0, 1.66, 0.26), Vector3(0.12, 0.12, 0.02), P.GLOW, am)
			for k in 7:
				var h := HashUtils.hash3(k, 1, 5)
				var x := (k - 3) * 0.13
				var hh := 0.3 + HashUtils.to_unit(h, 0) * 0.35
				box(r, Vector3(x, 1.95 + hh * 0.5, -0.05), Vector3(0.1, hh, 0.1), P.GLOW, am, NONE, Vector3(0, 0, -x * 40.0), {"glow": 0.9})
			for s: float in [-1.0, 1.0]:
				for k in 3:
					box(r, Vector3(s * (0.42 + k * 0.05), 1.42 + k * 0.14, -0.02), Vector3(0.12, 0.3, 0.12), P.GLOW, am, NONE, Vector3(0, 0, -s * 25.0), {"glow": 0.9})
			var ring := SP.pivot(r, Vector3(-0.62, 1.2, 0.2))
			for e: Vector3 in [Vector3(0, 0.12, 0), Vector3(0, -0.12, 0), Vector3(0.12, 0, 0), Vector3(-0.12, 0, 0)]:
				box(ring, e, Vector3(0.06, 0.06, 0.04) + Vector3(absf(e.y), absf(e.x), 0) * 2.0, P.METAL, GOLD, GOLD_D)
		1:
			var cyan := Color(0.3, 0.9, 0.9)
			var bone := SP.BONE
			box(r, Vector3(0, 1.66, 0.24), Vector3(0.3, 0.34, 0.04), P.BONE, bone, SP.BONE_D)
			box(r, Vector3(0, 1.68, 0.265), Vector3(0.1, 0.12, 0.01), P.GLOW, cyan)
			for s: float in [-1.0, 1.0]:
				for k in 3:
					box(r, Vector3(s * (0.24 + k * 0.1), 1.95 + k * 0.08, 0), Vector3(0.1, 0.16, 0.1), P.BONE, bone, SP.BONE_D)
				for k in 8:
					var a := k * 0.7
					box(r, Vector3(s * (0.55 + sin(a) * 0.12), 1.9 - k * 0.14, -0.1 + cos(a) * 0.1), Vector3(0.06, 0.16, 0.06), P.GLOW, cyan, NONE, Vector3(0, 0, sin(a) * 30.0), {"glow": 1.4})
			var staff := SP.pivot(r, Vector3(-0.46, 0.86, 0.22))
			box(staff, Vector3(0, 0.3, 0), Vector3(0.06, 1.7, 0.06), P.METAL, Color(0.5, 0.62, 0.66), SP.IRON_D)
			box(staff, Vector3(0, 1.22, 0), Vector3(0.18, 0.18, 0.08), P.GLOW, cyan)
		2:
			var stone := Color(0.55, 0.52, 0.5)
			var stone_d := Color(0.35, 0.33, 0.33)
			box(r, Vector3(0, 1.66, 0.0), Vector3(0.56, 0.56, 0.52), P.PLAIN, stone)
			for s: float in [-1.0, 1.0]:
				box(r, Vector3(s * 0.12, 1.68, 0.265), Vector3(0.08, 0.05, 0.01), P.GLOW, Color(1.0, 0.6, 0.15), NONE, Vector3.ZERO, {"glow": 3.0})
				# Spiral curls: a hook of small blocks on each side.
				for k in 7:
					var a := k * 0.9
					var rad := 0.24 - k * 0.025
					box(r, Vector3(s * (0.62 + cos(a) * rad), 1.5 + sin(a) * rad, -0.05), Vector3(0.08, 0.08, 0.08), P.PLAIN, stone, stone_d)
				box(r, Vector3(s * 0.42, 1.34, 0), Vector3(0.3, 0.28, 0.4), P.PLAIN, stone_d)
			box(r, Vector3(0, 1.08, 0.18), Vector3(0.44, 0.4, 0.04), P.PLAIN, stone)
			for k in 5:
				box(r, Vector3(0, 2.0 + k * 0.08, -0.05 - k * 0.02), Vector3(0.5 - k * 0.07, 0.08, 0.2), P.PLAIN, stone, stone_d)
		3:
			var teal := Color(0.32, 0.62, 0.6)
			var orange := Color(1.0, 0.62, 0.2)
			box(r, Vector3(0, 1.66, 0.24), Vector3(0.36, 0.3, 0.04), P.METAL, teal, teal * 0.6)
			box(r, Vector3(0, 1.66, 0.265), Vector3(0.12, 0.08, 0.01), P.GLOW, LENS)
			box(r, Vector3(0, 1.08, 0.18), Vector3(0.46, 0.44, 0.04), P.METAL, teal, teal * 0.6)
			for k in 8:
				var a := (k / 7.0 - 0.5) * PI * 1.2
				box(r, Vector3(sin(a) * 0.36, 1.66 + cos(a) * 0.36, -0.02), Vector3(0.1, 0.24, 0.1), P.GLOW, orange, NONE, Vector3(0, 0, -rad_to_deg(a)), {"glow": 0.9})
			for s: float in [-1.0, 1.0]:
				for k in 4:
					box(r, Vector3(s * (0.36 + k * 0.12), 1.4 - k * 0.1, -0.24), Vector3(0.1, 0.6 - k * 0.08, 0.03), P.CLOTH, Color(0.95, 0.72, 0.3), GOLD_D, Vector3(0, 0, s * (15.0 + k * 8.0)))
			var staff := SP.pivot(r, Vector3(-0.46, 0.86, 0.22))
			box(staff, Vector3(0, 0.3, 0), Vector3(0.06, 1.7, 0.06), P.METAL, teal, teal * 0.6)
			box(staff, Vector3(0, 1.24, 0), Vector3(0.2, 0.2, 0.2), P.GLOW, LENS, NONE, Vector3(45, 0, 45))
	return r
