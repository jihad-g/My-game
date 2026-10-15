class_name PixelSkeleton
extends RefCounted
## Art pass pilot: the skeleton (look "skeleton": Skeleton Minion and Skeleton
## Warrior) painted pixel by pixel. The parts hang on the normal HumanoidModel
## pivots, so every animation still works.
##
## Sizes are in pixels (16 per metre); positions are metres from each pivot.

static var _cache: Dictionary = {}

const S := PixelArt.PX


static func build(rig: HumanoidModel) -> void:
	if _cache.is_empty():
		_cache = make()
	for p: Array in _cache["parts"]:
		rig._add_mesh(rig.get(p[0]) as Node3D, p[1], p[2])


static func make() -> Dictionary:
	var pa := PixelArt.new()
	var B := PixelArt.BONE
	var key := {
		"S": Color("2a1714"),  # socket
		"g": [PixelArt.GLOW[2], true],
		"G": [PixelArt.GLOW[4], true],
		"o": [PixelArt.GLOW[1], true],
		"a": PixelArt.IRON[0], "b": PixelArt.IRON[1], "c": PixelArt.IRON[2], "d": PixelArt.IRON[3], "e": PixelArt.IRON[4],
		"l": PixelArt.LEATHER[0], "m": PixelArt.LEATHER[1], "n": PixelArt.LEATHER[2], "p": PixelArt.LEATHER[3],
	}
	# --- Head: skull with glowing eyes and teeth, separate jaw. ---
	pa.add(&"_head", Vector3(0, 0.3, 0), Vector3i(8, 7, 8), PixelArt.paint(Vector3i(8, 7, 8), B, 11, {
		PixelArt.FRONT: PackedStringArray([
			"........",
			".1....1.",
			".oG..Go.",
			".Sg..gS.",
			"...00...",
			"........",
			"41414141",
		]),
		PixelArt.RIGHT: PackedStringArray(["........", "........", ".......1", "......1.", "........", "........", "........"]),
		PixelArt.LEFT: PackedStringArray(["........", "........", "1.......", ".1......", "........", "........", "........"]),
	}, key))
	pa.add(&"_head", Vector3(0, 0.05, 0.03), Vector3i(6, 2, 6), PixelArt.paint(Vector3i(6, 2, 6), B, 12, {
		PixelArt.FRONT: PackedStringArray(["414141", "......"]),
	}, key))
	# --- Torso: neck, collarbone, shoulder knobs, see-through ribcage, spine. ---
	var vert := PackedStringArray(["3", "1", "3", "1", "3", "1", "3", "1"])
	var vert2 := PackedStringArray(["31", "11", "31", "11", "31", "11", "31", "11"])
	pa.add(&"_torso", Vector3(0, 0.64, -0.02), Vector3i(2, 2, 2), PixelArt.paint(Vector3i(2, 2, 2), B, 13, {
		PixelArt.FRONT: vert2, PixelArt.BACK: vert2, PixelArt.LEFT: vert2, PixelArt.RIGHT: vert2}, key, 0.0))
	pa.add(&"_torso", Vector3(0, 0.33, -0.09), Vector3i(2, 8, 2), PixelArt.paint(Vector3i(2, 8, 2), B, 14, {
		PixelArt.FRONT: vert2, PixelArt.BACK: vert2, PixelArt.LEFT: vert2, PixelArt.RIGHT: vert2}, key, 0.0))
	pa.add(&"_torso", Vector3(0, 0.58, 0.02), Vector3i(10, 1, 2), PixelArt.paint(Vector3i(10, 1, 2), B, 15))
	pa.add(&"_torso", Vector3(0, 0.36, 0.0), Vector3i(8, 6, 5), PixelArt.paint(Vector3i(8, 6, 5), B, 16, {
		PixelArt.FRONT: PackedStringArray(["34444443", "___22___", "23333332", "___22___", "_233332_", "___11___"]),
		PixelArt.BACK: PackedStringArray(["22222222", "________", "22222222", "________", "_111111_", "________"]),
		PixelArt.RIGHT: PackedStringArray(["33333", "_____", "22222", "_____", "11111", "_____"]),
		PixelArt.LEFT: PackedStringArray(["33333", "_____", "22222", "_____", "11111", "_____"]),
		PixelArt.TOP: PackedStringArray(["44444444", "4______3", "4______3", "4______3", "33333333"]),
		PixelArt.BOTTOM: PackedStringArray(["________", "________", "________", "________", "________"]),
	}, key, 0.0))
	# --- Belt with a raised iron buckle, ragged crimson skirt. ---
	var belt_side := PackedStringArray(["pnpnpnp", "mmmmmmm"])
	pa.add(&"_torso", Vector3(0, 0.03, 0), Vector3i(10, 2, 7), PixelArt.paint(Vector3i(10, 2, 7), PixelArt.LEATHER, 17, {
		PixelArt.FRONT: PackedStringArray(["3d32323d23", "2c11111c12"]),
		PixelArt.BACK: PackedStringArray(["32323232d3", "1111111c11"]),
		PixelArt.RIGHT: belt_side, PixelArt.LEFT: belt_side,
	}, key))
	pa.add(&"_torso", Vector3(0, 0.03, 0.235), Vector3i(4, 3, 1), PixelArt.paint(Vector3i(4, 3, 1), PixelArt.IRON, 18, {
		PixelArt.FRONT: PackedStringArray(["edde", "dlld", "cbbb"]),
	}, key, 0.0))
	pa.add(&"_torso", Vector3(0, -0.095, 0), Vector3i(9, 4, 6), PixelArt.paint(Vector3i(9, 4, 6), PixelArt.CRIMSON, 19, {
		PixelArt.FRONT: PackedStringArray(["..1...1..", "..1...1..", "..1.._1..", "_.._.__._"]),
		PixelArt.BACK: PackedStringArray([".1....1..", ".1....1..", ".._...1..", "._.__.._."]),
		PixelArt.RIGHT: PackedStringArray(["...1..", "...1..", "..._..", "_._.._"]),
		PixelArt.LEFT: PackedStringArray(["..1...", "..1...", "_.1...", "._.._."]),
		PixelArt.TOP: PackedStringArray(["_________", "_________", "_________", "_________", "_________", "_________"]),
		PixelArt.BOTTOM: PackedStringArray(["_________", "_________", "_________", "_________", "_________", "_________"]),
	}, key))
	# --- Arms: shoulder knob, upper bone, elbow; two forearm bones, hand, fingers. ---
	var twin := PackedStringArray(["3_3", "2_2", "2_2", "1_1"])
	for side in [[&"_arm_l", &"_fore_l", -1.0], [&"_arm_r", &"_fore_r", 1.0]]:
		var s: float = side[2]
		pa.add(&"_torso", Vector3(s * 0.33, 0.55, 0), Vector3i(3, 3, 3), PixelArt.paint(Vector3i(3, 3, 3), B, 20))
		pa.add(side[0], Vector3(0, -0.15, 0), Vector3i(2, 5, 2), PixelArt.paint(Vector3i(2, 5, 2), B, 21))
		pa.add(side[0], Vector3(0, -0.29, 0), Vector3i(3, 2, 3), PixelArt.paint(Vector3i(3, 2, 3), B, 22))
		pa.add(side[1], Vector3(0, -0.1, 0), Vector3i(3, 4, 2), PixelArt.paint(Vector3i(3, 4, 2), B, 23, {
			PixelArt.FRONT: twin, PixelArt.BACK: twin,
			PixelArt.TOP: PackedStringArray(["3_3", "3_3"]), PixelArt.BOTTOM: PackedStringArray(["1_1", "1_1"]),
		}, key, 0.0))
		pa.add(side[1], Vector3(0, -0.24, 0), Vector3i(3, 2, 3), PixelArt.paint(Vector3i(3, 2, 3), B, 24))
		for k in 3:
			pa.add(side[1], Vector3((k - 1) * S, -0.34, S), Vector3i(1, 2, 1), PixelArt.paint(Vector3i(1, 2, 1), B, 25 + k, {
				PixelArt.FRONT: PackedStringArray(["3", "1"])}, key, 0.0))
		pa.add(side[1], Vector3(-s * 2 * S, -0.3, 2 * S), Vector3i(1, 2, 1), PixelArt.paint(Vector3i(1, 2, 1), B, 28))
	# --- Legs: hip knob, thigh, knee, shin, leather boot with an iron strap, toes. ---
	var boot_side := PackedStringArray(["3333.", "bbbbb", "00000"])
	for leg in [[&"_leg_l", &"_shin_l"], [&"_leg_r", &"_shin_r"]]:
		pa.add(leg[0], Vector3(0, -0.03, 0), Vector3i(3, 2, 3), PixelArt.paint(Vector3i(3, 2, 3), B, 30))
		pa.add(leg[0], Vector3(0, -0.2, 0), Vector3i(2, 5, 2), PixelArt.paint(Vector3i(2, 5, 2), B, 31))
		pa.add(leg[1], Vector3(0, 0.0, 0.01), Vector3i(3, 2, 3), PixelArt.paint(Vector3i(3, 2, 3), B, 32))
		pa.add(leg[1], Vector3(0, -0.11, 0), Vector3i(2, 4, 2), PixelArt.paint(Vector3i(2, 4, 2), B, 33))
		pa.add(leg[1], Vector3(0, -0.286, 0.03), Vector3i(4, 3, 5), PixelArt.paint(Vector3i(4, 3, 5), PixelArt.LEATHER, 34, {
			PixelArt.FRONT: PackedStringArray(["3333", "cbba", "0000"]),
			PixelArt.BACK: PackedStringArray(["3333", "bbbb", "0000"]),
			PixelArt.RIGHT: boot_side, PixelArt.LEFT: boot_side,
		}, key))
		pa.add(leg[1], Vector3(0, -0.19, 0.03), Vector3i(5, 1, 6), PixelArt.paint(Vector3i(5, 1, 6), PixelArt.LEATHER, 35, {
			PixelArt.FRONT: PackedStringArray(["pnpnp"]), PixelArt.BACK: PackedStringArray(["npnpn"]),
		}, key, 0.0))
		pa.add(leg[1], Vector3(0, -0.35, 0.22), Vector3i(3, 1, 2), PixelArt.paint(Vector3i(3, 1, 2), B, 36, {
			PixelArt.FRONT: PackedStringArray(["414"]), PixelArt.TOP: PackedStringArray(["414", "313"]),
		}, key, 0.0))
	return pa.build()
