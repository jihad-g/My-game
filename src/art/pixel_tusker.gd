class_name PixelTusker
extends RefCounted
## Art pass: the Tuskers, a boar-folk warband, drawn pixel by pixel. Three
## kinds share one body: the grunt (gold block mace), the brute (hook staff)
## and the chief (dark armour, gold crown, war banner with a skull).
## Parts hang on the HumanoidModel pivots, so the normal animations work.

static var _cache: Dictionary = {}

const S := PixelArt.PX


static func build(rig: HumanoidModel, kind: StringName) -> void:
	if not _cache.has(kind):
		_cache[kind] = make(kind)
	for p: Array in _cache[kind]["parts"]:
		rig._add_mesh(rig.get(p[0]) as Node3D, p[1], p[2])


static func _key() -> Dictionary:
	return {
		"W": Color("f2ece0"), "K": Color("1a1416"), "S": Color("2a1212"),
		"r": PixelArt.RUST[1], "R": PixelArt.RUST[2],
		"x": PixelArt.HAIR_BLACK[1], "y": PixelArt.HAIR_BLACK[2], "z": PixelArt.HAIR_BLACK[3],
		"a": PixelArt.GOLD[0], "b": PixelArt.GOLD[1], "c": PixelArt.GOLD[2], "d": PixelArt.GOLD[3], "e": PixelArt.GOLD[4],
		"B": PixelArt.BONE[3], "o": PixelArt.BONE[1],
	}


static func make(kind: StringName) -> Dictionary:
	var pa := PixelArt.new()
	var key := _key()
	var SK := PixelArt.SKIN_BOAR
	var chief := kind == &"tusker_chief"
	# --- Head: big square face, small eyes, war paint, snout, tusks, ears, topknot. ---
	pa.add(&"_head", Vector3(0, 0.3, 0.02), Vector3i(10, 9, 9), PixelArt.paint(Vector3i(10, 9, 9), SK, 41, {
		PixelArt.FRONT: PackedStringArray([
			"..........",
			".2......2.",
			".44....44.",
			".WK....KW.",
			".r......r.",
			".rr....rr.",
			"..........",
			".2SSSSSS2.",
			"..........",
		]),
		PixelArt.RIGHT: PackedStringArray([".........", ".........", ".........", "......1..", ".....r...", "....r....", ".........", ".........", "........."]),
		PixelArt.LEFT: PackedStringArray([".........", ".........", ".........", "..1......", "...r.....", "....r....", ".........", ".........", "........."]),
	}, key))
	pa.add(&"_head", Vector3(0, 0.25, 0.32), Vector3i(5, 3, 2), PixelArt.paint(Vector3i(5, 3, 2), SK, 42, {
		PixelArt.FRONT: PackedStringArray(["43333", "3S3S2", "22221"]),
	}, key, 0.0))
	for s: float in [-1.0, 1.0]:
		pa.add(&"_head", Vector3(s * 0.19, 0.12, 0.3), Vector3i(1, 3, 1), PixelArt.paint(Vector3i(1, 3, 1), PixelArt.BONE, 43, {
			PixelArt.FRONT: PackedStringArray(["4", "3", "2"])}, key, 0.0))
		pa.add(&"_head", Vector3(s * 0.33, 0.52, 0.0), Vector3i(2, 3, 2), PixelArt.paint(Vector3i(2, 3, 2), SK, 44), Vector3(0, 0, -s * 35.0))
	if chief:
		# Gold crown helm with a square gem pattern.
		pa.add(&"_head", Vector3(0, 0.6, 0.02), Vector3i(11, 3, 10), PixelArt.paint(Vector3i(11, 3, 10), PixelArt.GOLD, 45, {
			PixelArt.FRONT: PackedStringArray(["4.4.4.4.4.4", "3111.1.1113", "22222222222"]),
		}, key))
		pa.add(&"_head", Vector3(0, 0.77, 0.0), Vector3i(9, 2, 8), PixelArt.paint(Vector3i(9, 2, 8), PixelArt.HAIR_BLACK, 46))
	else:
		pa.add(&"_head", Vector3(0, 0.6, -0.05), Vector3i(3, 1, 3), PixelArt.paint(Vector3i(3, 1, 3), PixelArt.GOLD, 46))
		for k in 3:
			pa.add(&"_head", Vector3((k - 1) * 0.06, 0.76, -0.05), Vector3i(1, 5, 1), PixelArt.paint(Vector3i(1, 5, 1), PixelArt.HAIR_BLACK, 47 + k), Vector3(0, 0, (k - 1) * 16.0))
	# --- Torso: bare chest with crossed straps (or dark armour for the chief). ---
	if chief:
		pa.add(&"_torso", Vector3(0, 0.3, 0), Vector3i(11, 9, 7), PixelArt.paint(Vector3i(11, 9, 7), PixelArt.SLATE, 50, {
			PixelArt.FRONT: PackedStringArray(["ddddddddddd", "3.........1", "3.cdddddc.1", "3.c.....c.1", "3.c.R.R.c.1", "3.c.....c.1", "3.cbbbbbc.1", "3.........1", "bbbbbbbbbbb"]),
		}, key))
	else:
		pa.add(&"_torso", Vector3(0, 0.3, 0), Vector3i(10, 9, 6), PixelArt.paint(Vector3i(10, 9, 6), SK, 51, {
			PixelArt.FRONT: PackedStringArray(["yy......yy", ".yy....yy.", "..yy..yy..", "...yyyy...", "...xyyx...", "..3....3..", "...2..2...", "..........", ".1......1."]),
			PixelArt.BACK: PackedStringArray(["yy......yy", ".yy....yy.", "..yy..yy..", "...yyyy...", "....yy....", "..........", "..........", "..........", ".........."]),
		}, key))
	pa.add(&"_torso", Vector3(0, 0.02, 0), Vector3i(11, 2, 7), PixelArt.paint(Vector3i(11, 2, 7), PixelArt.HAIR_BLACK, 52))
	pa.add(&"_torso", Vector3(0, 0.02, 0.24), Vector3i(4, 3, 1), PixelArt.paint(Vector3i(4, 3, 1), PixelArt.GOLD, 53, {
		PixelArt.FRONT: PackedStringArray(["edde", "d00d", "cbbc"])}, key, 0.0))
	pa.add(&"_torso", Vector3(0, -0.11, 0), Vector3i(10, 4, 7), PixelArt.paint(Vector3i(10, 4, 7), PixelArt.RUST, 54, {
		PixelArt.FRONT: PackedStringArray(["..1..1..1.", "..1..1..1.", "_.1._1.._.", "_._._.__._"]),
		PixelArt.BACK: PackedStringArray([".1..1..1..", ".1..1..1..", "._..1._.._", "_.__._._._"]),
		PixelArt.RIGHT: PackedStringArray(["...1...", "...1...", "_.._..1", "._._.__"]),
		PixelArt.LEFT: PackedStringArray(["..1....", "..1....", "1.._.._", "__._._."]),
		PixelArt.TOP: PackedStringArray(["__________", "__________", "__________", "__________", "__________", "__________", "__________"]),
		PixelArt.BOTTOM: PackedStringArray(["__________", "__________", "__________", "__________", "__________", "__________", "__________"]),
	}, key))
	# --- Arms: gold (or black) shoulder pads, bare upper arm, wrapped forearm. ---
	var wrap := PackedStringArray(["343", "121", "343", "121"])
	var pad_ramp: Array = PixelArt.HAIR_BLACK if chief else PixelArt.GOLD
	for side in [[&"_arm_l", &"_fore_l", -1.0], [&"_arm_r", &"_fore_r", 1.0]]:
		var s: float = side[2]
		pa.add(side[0], Vector3(s * 0.02, 0.02, 0), Vector3i(6 if chief else 5, 4 if chief else 3, 6 if chief else 5), PixelArt.paint(
			Vector3i(6 if chief else 5, 4 if chief else 3, 6 if chief else 5), pad_ramp, 55, {
			PixelArt.FRONT: PackedStringArray(["dddddd", "3....1", "3....1", "bbbbbb"]) if chief else PackedStringArray(["44443", "4ab.3", "33332"]),
		}, key))
		pa.add(side[0], Vector3(0, -0.16, 0), Vector3i(3, 5, 3), PixelArt.paint(Vector3i(3, 5, 3), SK, 56))
		pa.add(side[1], Vector3(0, -0.1, 0), Vector3i(3, 4, 3), PixelArt.paint(Vector3i(3, 4, 3), PixelArt.HAIR_BLACK, 57, {
			PixelArt.FRONT: wrap, PixelArt.BACK: wrap, PixelArt.LEFT: wrap, PixelArt.RIGHT: wrap}, key, 0.0))
		pa.add(side[1], Vector3(0, -0.24, 0), Vector3i(3, 3, 3), PixelArt.paint(Vector3i(3, 3, 3), SK, 58))
	# --- Legs: dark wrapped trousers and heavy boots. ---
	var leg_wrap := PackedStringArray(["...", "434", "...", "434"])
	for leg in [[&"_leg_l", &"_shin_l"], [&"_leg_r", &"_shin_r"]]:
		pa.add(leg[0], Vector3(0, -0.18, 0), Vector3i(3, 5, 3), PixelArt.paint(Vector3i(3, 5, 3), PixelArt.SLATE, 60))
		pa.add(leg[1], Vector3(0, -0.1, 0), Vector3i(3, 4, 3), PixelArt.paint(Vector3i(3, 4, 3), PixelArt.SLATE, 61, {
			PixelArt.FRONT: leg_wrap, PixelArt.LEFT: leg_wrap, PixelArt.RIGHT: leg_wrap}, key, 0.0))
		pa.add(leg[1], Vector3(0, -0.286, 0.03), Vector3i(4, 3, 5), PixelArt.paint(Vector3i(4, 3, 5), PixelArt.HAIR_BLACK, 62, {
			PixelArt.FRONT: PackedStringArray(["4444", "....", "0000"])}, key))
	# --- Weapons, held in the right hand (they point along +Z, like the rig's). ---
	var hand := Vector3(0, -0.26, 0.05)
	match kind:
		&"tusker":
			pa.add(&"_fore_r", hand + Vector3(0, 0, 0.3), Vector3i(1, 1, 11), PixelArt.paint(Vector3i(1, 1, 11), PixelArt.WOOD, 63))
			var cube := PackedStringArray(["44444", "41114", "41414", "41114", "33333"])
			pa.add(&"_fore_r", hand + Vector3(0, 0, 0.72), Vector3i(5, 5, 5), PixelArt.paint(Vector3i(5, 5, 5), PixelArt.GOLD, 64, {
				PixelArt.FRONT: cube, PixelArt.BACK: cube, PixelArt.LEFT: cube, PixelArt.RIGHT: cube, PixelArt.TOP: cube}, key, 0.0))
		&"tusker_brute":
			pa.add(&"_fore_r", hand + Vector3(0, 0, 0.42), Vector3i(1, 1, 18), PixelArt.paint(Vector3i(1, 1, 18), PixelArt.WOOD, 65))
			pa.add(&"_fore_r", hand + Vector3(0, 0, 1.0), Vector3i(1, 1, 2), PixelArt.paint(Vector3i(1, 1, 2), PixelArt.GOLD, 66))
			pa.add(&"_fore_r", hand + Vector3(0.09, 0, 1.08), Vector3i(4, 1, 1), PixelArt.paint(Vector3i(4, 1, 1), PixelArt.GOLD, 67))
			pa.add(&"_fore_r", hand + Vector3(0.19, 0, 1.0), Vector3i(1, 1, 3), PixelArt.paint(Vector3i(1, 1, 3), PixelArt.GOLD, 68))
			pa.add(&"_fore_r", hand + Vector3(0.12, 0, 0.92), Vector3i(2, 1, 1), PixelArt.paint(Vector3i(2, 1, 1), PixelArt.GOLD, 69))
		&"tusker_chief":
			pa.add(&"_fore_r", hand + Vector3(0, 0, 0.08), Vector3i(1, 1, 3), PixelArt.paint(Vector3i(1, 1, 3), PixelArt.WOOD, 70))
			pa.add(&"_fore_r", hand + Vector3(0, 0, 0.18), Vector3i(4, 1, 1), PixelArt.paint(Vector3i(4, 1, 1), PixelArt.GOLD, 71))
			pa.add(&"_fore_r", hand + Vector3(0, 0, 0.5), Vector3i(1, 2, 9), PixelArt.paint(Vector3i(1, 2, 9), PixelArt.BONE, 72))
			# War banner in the left hand: pole, gold-edged cloth, skull on top.
			var lh := Vector3(0, -0.26, 0.05)
			pa.add(&"_fore_l", lh + Vector3(0, 0.75, 0), Vector3i(1, 32, 1), PixelArt.paint(Vector3i(1, 32, 1), PixelArt.WOOD, 73))
			pa.add(&"_fore_l", lh + Vector3(0, 1.72, 0.06), Vector3i(12, 1, 1), PixelArt.paint(Vector3i(12, 1, 1), PixelArt.WOOD, 74))
			var cloth := PackedStringArray([
				"dddddddddd", "d22222222d", "d2cccccc2d", "d2c2222c2d", "d2c2dd2c2d", "d2c2dd2c2d", "d2c2222c2d",
				"d2cccccc2d", "d22222222d", "d22222222d", "dd222222dd", "_dd2222dd_", "__dd22dd__", "___dddd___",
			])
			pa.add(&"_fore_l", lh + Vector3(0, 1.26, 0.07), Vector3i(10, 14, 1), PixelArt.paint(Vector3i(10, 14, 1), PixelArt.RUST, 75, {
				PixelArt.FRONT: cloth, PixelArt.BACK: cloth}, key))
			pa.add(&"_fore_l", lh + Vector3(0, 1.9, 0.0), Vector3i(4, 4, 4), PixelArt.paint(Vector3i(4, 4, 4), PixelArt.BONE, 76, {
				PixelArt.FRONT: PackedStringArray(["4444", "SR3S", "3223", ".1.1"])}, key))
	return pa.build()
