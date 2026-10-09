class_name BuildMeshes
## Blocky meshes for building pieces (local origin: cell/edge centre on the ground).
## Edge pieces are built along X (width 1 m) and rotated by the placer.

const WOOD := Color(0.62, 0.43, 0.26)
const WOOD_DARK := Color(0.48, 0.32, 0.19)
const STONE := Color(0.6, 0.6, 0.63)
const THATCH := Color(0.82, 0.7, 0.38)
const IRON := Color(0.5, 0.5, 0.55)

static var _cache: Dictionary = {}


static func get_mesh(name: StringName) -> ArrayMesh:
	if _cache.has(name):
		return _cache[name]
	var b := BlockMesh.new()
	build_into(b, name)
	var mesh := b.commit()
	_cache[name] = mesh
	return mesh


## Adds the named piece's boxes to `b` (using b.xform). Thread-safe: no engine
## resources are created. `color` is used by coloured pieces (banner cloth).
static func build_into(b: BlockMesh, name: StringName, color: Color = Color.WHITE) -> void:
	var fn := "build_%s" % name
	b.texture = &""
	var script: GDScript = load("res://src/building/build_meshes.gd")
	if name == &"banner_cloth":
		_banner_cloth(b, color)
	elif String(name).begins_with("crop_"):
		# crop_<kind>_<stage>
		var parts := String(name).split("_")
		build_crop(b, StringName(parts[1]), int(parts[2]))
	elif script.has_method(fn):
		script.call(fn, b)
	else:
		b.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	b.texture = &""


static func build_wood_floor(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, -0.2, 0), Vector3(1.0, 0.6, 1.0), WOOD_DARK)
	for k in 4:
		b.texture = &"planks_vertical"
		b.box(Vector3(-0.375 + k * 0.25, 0.11, 0), Vector3(0.24, 0.04, 0.98), WOOD * (0.95 + 0.05 * (k % 2)))


static func build_stone_floor(b: BlockMesh) -> void:
	b.texture = &"stone_tiles"
	b.box(Vector3(0, -0.2, 0), Vector3(1.0, 0.6, 1.0), STONE * 0.85)
	for i in 2:
		for j in 2:
			b.texture = &"stone_tiles"
			b.box(Vector3(-0.25 + i * 0.5, 0.11, -0.25 + j * 0.5), Vector3(0.47, 0.04, 0.47), STONE * (0.95 + 0.07 * ((i + j) % 2)))


static func _wall(b: BlockMesh, color: Color, h: float = 2.6) -> void:
	b.box(Vector3(0, h * 0.5 - 0.5, 0), Vector3(1.0, h + 1.0, 0.2), color)


static func build_wood_wall(b: BlockMesh) -> void:
	b.texture = &"planks_wall"
	_wall(b, WOOD)
	for k in 3:
		b.texture = &"wood_beam"
		b.box(Vector3(0, 0.45 + k * 0.85, 0), Vector3(1.0, 0.06, 0.22), WOOD_DARK)
	b.texture = &"wood_beam"
	b.box(Vector3(-0.47, 0.8, 0), Vector3(0.08, 2.6, 0.24), WOOD_DARK)


static func build_stone_wall(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	_wall(b, STONE)
	for k in 5:
		b.texture = &"stone_bricks"
		b.box(Vector3(0.25 * (k % 2) - 0.12, 0.25 + k * 0.5, 0), Vector3(0.5, 0.04, 0.22), STONE * 0.8)


static func build_wood_door(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(-0.45, 0.8, 0), Vector3(0.1, 2.6, 0.22), WOOD_DARK)
	b.box(Vector3(0.45, 0.8, 0), Vector3(0.1, 2.6, 0.22), WOOD_DARK)
	b.texture = &"planks_wall"
	b.box(Vector3(0, 2.3, 0), Vector3(1.0, 0.4, 0.22), WOOD)


## The moving door leaf (hinged at x = -0.4).
static func build_door_leaf(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0.4, 1.05, 0), Vector3(0.8, 2.1, 0.1), WOOD * 1.05)
	b.texture = &"wood_beam"
	b.box(Vector3(0.4, 0.6, 0), Vector3(0.8, 0.08, 0.12), WOOD_DARK)
	b.box(Vector3(0.4, 1.5, 0), Vector3(0.8, 0.08, 0.12), WOOD_DARK)
	b.texture = &"iron_plate"
	b.box(Vector3(0.7, 1.05, 0.07), Vector3(0.06, 0.12, 0.06), IRON)


static func build_wood_window(b: BlockMesh) -> void:
	b.texture = &"planks_wall"
	b.box(Vector3(0, 0.1, 0), Vector3(1.0, 1.2, 0.2), WOOD)
	b.box(Vector3(0, 2.3, 0), Vector3(1.0, 0.6, 0.2), WOOD)
	b.texture = &"wood_beam"
	b.box(Vector3(-0.42, 1.35, 0), Vector3(0.16, 1.3, 0.2), WOOD_DARK)
	b.box(Vector3(0.42, 1.35, 0), Vector3(0.16, 1.3, 0.2), WOOD_DARK)
	b.box(Vector3(0, 1.35, 0), Vector3(0.06, 1.3, 0.08), WOOD_DARK)


static func build_wood_fence(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(-0.45, 0.35, 0), Vector3(0.12, 1.2, 0.12), WOOD_DARK)
	b.box(Vector3(0.45, 0.35, 0), Vector3(0.12, 1.2, 0.12), WOOD_DARK)
	b.texture = &"planks_wall"
	b.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.1, 0.06), WOOD)
	b.box(Vector3(0, 0.8, 0), Vector3(1.0, 0.1, 0.06), WOOD)


static func build_spike_wall(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.25, 0), Vector3(1.0, 0.25, 0.25), WOOD_DARK)
	for k in 5:
		var x := -0.4 + k * 0.2
		b.texture = &"wood_beam"
		b.box(Vector3(x, 0.55, 0.12), Vector3(0.08, 0.9, 0.08), WOOD, Basis(Vector3.RIGHT, 0.6))
		b.box(Vector3(x + 0.1, 0.55, -0.12), Vector3(0.08, 0.9, 0.08), WOOD, Basis(Vector3.RIGHT, -0.6))
	for k in 5:
		b.texture = &"iron_plate"
		b.box(Vector3(-0.4 + k * 0.2, 0.95, 0.38), Vector3(0.05, 0.12, 0.05), IRON)


static func build_spike_trap(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.04, 0), Vector3(0.9, 0.08, 0.9), WOOD_DARK)
	for i in 3:
		for j in 3:
			b.texture = &"iron_plate"
			b.box(Vector3(-0.3 + i * 0.3, 0.2, -0.3 + j * 0.3), Vector3(0.06, 0.3, 0.06), IRON)


static func build_thatch_roof(b: BlockMesh) -> void:
	b.texture = &"thatch"
	b.box(Vector3(0, 0.08, 0), Vector3(1.1, 0.16, 1.1), THATCH)
	b.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.1, 0.9), THATCH * 1.05)


static func build_wood_roof(b: BlockMesh) -> void:
	b.texture = &"roof_shingles"
	b.box(Vector3(0, 0.08, 0), Vector3(1.1, 0.16, 1.1), Color(0.55, 0.28, 0.22))
	for k in 4:
		b.texture = &"roof_shingles"
		b.box(Vector3(0, 0.18, -0.4 + k * 0.27), Vector3(1.1, 0.06, 0.12), Color(0.45, 0.22, 0.18))


static func build_table(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.75, 0), Vector3(0.95, 0.1, 0.7), WOOD)
	for sx in [-0.4, 0.4]:
		for sz in [-0.28, 0.28]:
			b.texture = &"wood_beam"
			b.box(Vector3(sx, 0.35, sz), Vector3(0.08, 0.7, 0.08), WOOD_DARK)


static func build_chair(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.45, 0), Vector3(0.5, 0.08, 0.5), WOOD)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.8, -0.22), Vector3(0.5, 0.65, 0.06), WOOD_DARK)
	for sx in [-0.2, 0.2]:
		for sz in [-0.2, 0.2]:
			b.texture = &"wood_beam"
			b.box(Vector3(sx, 0.22, sz), Vector3(0.06, 0.44, 0.06), WOOD_DARK)


static func build_bed(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.3, 1.9), WOOD_DARK)
	b.texture = &"cloth"
	b.box(Vector3(0, 0.45, 0.1), Vector3(0.84, 0.14, 1.6), Color(0.85, 0.35, 0.3))
	b.box(Vector3(0, 0.5, -0.72), Vector3(0.6, 0.14, 0.32), Color(0.95, 0.93, 0.88))
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.6, -0.92), Vector3(0.9, 0.7, 0.08), WOOD)


static func build_chest(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.55), WOOD)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.65, 0), Vector3(0.84, 0.12, 0.6), WOOD_DARK)
	b.texture = &""
	b.box(Vector3(0, 0.45, 0.29), Vector3(0.12, 0.14, 0.04), Color(0.85, 0.7, 0.3))


static func build_torch(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.6, 0), Vector3(0.1, 1.2, 0.1), WOOD_DARK)
	b.texture = &""
	b.box(Vector3(0, 1.25, 0), Vector3(0.16, 0.14, 0.16), Color(0.25, 0.2, 0.15))


static func build_workbench(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.8, 0), Vector3(1.4, 0.14, 0.8), WOOD)
	for sx in [-0.6, 0.6]:
		for sz in [-0.32, 0.32]:
			b.texture = &"wood_beam"
			b.box(Vector3(sx, 0.4, sz), Vector3(0.12, 0.8, 0.12), WOOD_DARK)
	b.texture = &"stone_bricks"
	b.box(Vector3(-0.3, 0.92, 0.1), Vector3(0.4, 0.1, 0.2), STONE)  # whetstone
	b.texture = &"iron_plate"
	b.box(Vector3(0.35, 0.9, -0.15), Vector3(0.08, 0.06, 0.4), IRON)  # saw


static func build_forge(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(-0.3, 0.55, 0), Vector3(1.0, 1.1, 1.0), STONE * 0.9)
	b.box(Vector3(-0.3, 1.3, 0), Vector3(0.6, 0.5, 0.6), STONE * 0.8)  # chimney
	b.texture = &""
	b.box(Vector3(-0.3, 0.55, 0.51), Vector3(0.5, 0.4, 0.04), Color(1.0, 0.45, 0.1))  # fire mouth
	b.texture = &"wood_beam"
	b.box(Vector3(0.6, 0.35, 0), Vector3(0.3, 0.7, 0.3), WOOD_DARK)
	b.texture = &"iron_plate"
	b.box(Vector3(0.6, 0.78, 0), Vector3(0.6, 0.16, 0.35), IRON)  # anvil


static func build_tailoring(b: BlockMesh) -> void:
	build_table(b)
	b.texture = &"cloth"
	b.box(Vector3(0.2, 0.83, 0), Vector3(0.5, 0.04, 0.5), Color(0.8, 0.75, 0.6))  # cloth
	b.texture = &""
	b.box(Vector3(-0.35, 0.95, -0.1), Vector3(0.14, 0.3, 0.14), Color(0.55, 0.35, 0.25))  # spool
	b.texture = &"wood_beam"
	b.box(Vector3(-0.8, 0.9, 0), Vector3(0.1, 1.8, 0.1), WOOD_DARK)  # drying rack
	b.texture = &"cloth"
	b.box(Vector3(-0.8, 1.5, 0.3), Vector3(0.04, 0.6, 0.5), Color(0.5, 0.34, 0.22))


static func build_arcane_altar(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.0), STONE * 0.75)
	b.box(Vector3(0, 0.75, 0), Vector3(0.7, 0.3, 0.7), STONE * 0.85)
	b.texture = &"crystal"
	b.box(Vector3(0, 1.2, 0), Vector3(0.2, 0.5, 0.2), Color(0.7, 0.45, 1.0))
	b.box(Vector3(0.28, 1.0, 0.28), Vector3(0.1, 0.25, 0.1), Color(0.45, 0.85, 1.0))
	b.box(Vector3(-0.28, 1.0, -0.28), Vector3(0.1, 0.25, 0.1), Color(0.45, 0.85, 1.0))


static func build_claim_flag(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 1.3, 0), Vector3(0.1, 2.6, 0.1), WOOD_DARK)
	b.texture = &"cloth"
	b.box(Vector3(0.35, 2.25, 0), Vector3(0.6, 0.45, 0.04), Color(0.2, 0.55, 0.95))
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), STONE)


static func build_claim_totem(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9), STONE)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 1.1, 0), Vector3(0.5, 1.2, 0.5), WOOD)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 1.9, 0), Vector3(0.6, 0.4, 0.6), WOOD_DARK)
	b.texture = &""
	b.box(Vector3(0, 1.95, 0.31), Vector3(0.3, 0.12, 0.04), Color(1.0, 0.8, 0.3))
	b.texture = &"wood_beam"
	b.box(Vector3(0.4, 1.9, 0), Vector3(0.3, 0.12, 0.12), WOOD_DARK)
	b.box(Vector3(-0.4, 1.9, 0), Vector3(0.3, 0.12, 0.12), WOOD_DARK)
	b.texture = &""
	b.box(Vector3(0, 2.3, 0), Vector3(0.18, 0.3, 0.18), Color(0.3, 0.8, 1.0))


# --- Milestone 5: settlements & farming --------------------------------------------

const SOIL := Color(0.36, 0.24, 0.15)


static func build_farmland(b: BlockMesh) -> void:
	b.texture = &"tilled_soil"
	b.box(Vector3(0, -0.2, 0), Vector3(1.0, 0.44, 1.0), SOIL * 0.85)
	for k in 3:
		b.texture = &"tilled_soil"
		b.box(Vector3(0, 0.05, -0.33 + k * 0.33), Vector3(0.96, 0.06, 0.16), SOIL * 1.12)


## Crops grow in 4 stages (0 sprout .. 3 ripe).
static func build_crop(b: BlockMesh, kind: StringName, stage: int) -> void:
	var leaf := Color(0.35, 0.65, 0.25)
	var grow := 0.25 + 0.25 * stage
	match kind:
		&"wheat":
			# v0.26.0: pixel-art wheat on crossed cards, one sprite per growth stage.
			for p: Vector3 in [Vector3(-0.22, 0, -0.2), Vector3(0.22, 0, 0.18)]:
				b.card(p, StringName("wheat_%d" % clampi(stage, 0, 3)), 0.7, 0.8, Color.WHITE, 0.4)
		&"carrot":
			for i in 3:
				var p := Vector3(-0.3 + i * 0.3, 0, 0)
				b.box(p + Vector3(0, 0.12 * grow + 0.04, 0), Vector3(0.18 * grow + 0.05, 0.24 * grow, 0.18 * grow + 0.05), leaf * 1.1)
				if stage == 3:
					b.box(p + Vector3(0, 0.03, 0), Vector3(0.12, 0.08, 0.12), Color(0.95, 0.5, 0.15))
		&"pumpkin":
			b.box(Vector3(0, 0.1 * grow + 0.03, 0), Vector3(0.7 * grow, 0.2 * grow, 0.7 * grow), leaf * 0.9)
			if stage >= 2:
				var sz := 0.3 if stage == 2 else 0.55
				b.box(Vector3(0.1, sz * 0.5, 0.1), Vector3(sz, sz * 0.8, sz), Color(0.95, 0.55, 0.12) if stage == 3 else Color(0.55, 0.7, 0.25))
				b.box(Vector3(0.1, sz * 0.9 + 0.04, 0.1), Vector3(0.06, 0.1, 0.06), Color(0.3, 0.45, 0.15))
		_:
			b.box(Vector3(0, 0.2 * grow, 0), Vector3(0.4, 0.4 * grow, 0.4), leaf)


static func build_farm_plot(b: BlockMesh) -> void:
	build_farmland(b)


static func build_anvil(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45), WOOD_DARK)
	b.texture = &"iron_plate"
	b.box(Vector3(0, 0.56, 0), Vector3(0.36, 0.12, 0.26), IRON * 0.8)
	b.box(Vector3(0, 0.68, 0), Vector3(0.7, 0.14, 0.28), IRON)
	b.box(Vector3(0.4, 0.7, 0), Vector3(0.14, 0.08, 0.14), IRON * 0.9)


static func build_market_stall(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.7), WOOD)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.92, 0), Vector3(1.9, 0.06, 0.8), WOOD_DARK)
	for sx in [-0.88, 0.88]:
		b.texture = &"wood_beam"
		b.box(Vector3(sx, 1.2, -0.3), Vector3(0.08, 2.4, 0.08), WOOD_DARK)
		b.box(Vector3(sx, 1.0, 0.35), Vector3(0.08, 2.0, 0.08), WOOD_DARK)
	# striped awning
	for k in 5:
		var c := Color(0.85, 0.2, 0.2) if k % 2 == 0 else Color(0.95, 0.92, 0.85)
		b.texture = &"cloth"
		b.box(Vector3(-0.76 + k * 0.38, 2.2, 0.05), Vector3(0.38, 0.06, 1.1), c, Basis(Vector3.RIGHT, -0.35))
	# goods
	b.texture = &""
	b.box(Vector3(-0.5, 1.05, 0.05), Vector3(0.3, 0.2, 0.3), Color(0.9, 0.3, 0.25))
	b.box(Vector3(0.0, 1.03, 0.1), Vector3(0.28, 0.16, 0.28), Color(0.95, 0.8, 0.35))
	b.box(Vector3(0.5, 1.05, 0.05), Vector3(0.3, 0.2, 0.3), Color(0.4, 0.7, 0.3))


static func build_well(b: BlockMesh) -> void:
	for k in 4:
		var a := k * PI * 0.5
		b.texture = &"stone_bricks"
		b.box(Vector3(cos(a) * 0.7, 0.4, sin(a) * 0.7), Vector3(0.5 if k % 2 == 0 else 1.9, 0.8, 1.9 if k % 2 == 0 else 0.5), STONE)
	b.texture = &""
	b.box(Vector3(0, 0.1, 0), Vector3(1.0, 0.1, 1.0), Color(0.2, 0.4, 0.7))
	b.texture = &"wood_beam"
	b.box(Vector3(-0.8, 1.3, 0), Vector3(0.12, 1.6, 0.12), WOOD_DARK)
	b.box(Vector3(0.8, 1.3, 0), Vector3(0.12, 1.6, 0.12), WOOD_DARK)
	b.box(Vector3(0, 2.1, 0), Vector3(1.9, 0.12, 0.12), WOOD_DARK)
	b.texture = &"roof_shingles"
	b.box(Vector3(0, 2.35, 0), Vector3(2.1, 0.12, 1.2), Color(0.55, 0.28, 0.22), Basis(Vector3.RIGHT, 0.0))
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 1.4, 0), Vector3(0.25, 0.3, 0.25), WOOD)


static func build_notice_board(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(-0.7, 0.9, 0), Vector3(0.12, 1.8, 0.12), WOOD_DARK)
	b.box(Vector3(0.7, 0.9, 0), Vector3(0.12, 1.8, 0.12), WOOD_DARK)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 1.3, 0), Vector3(1.5, 0.9, 0.08), WOOD)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 1.85, 0.02), Vector3(1.7, 0.14, 0.2), WOOD_DARK)
	var papers := [Color(0.95, 0.93, 0.85), Color(0.9, 0.88, 0.7), Color(0.95, 0.9, 0.8)]
	for k in 3:
		b.texture = &""
		b.box(Vector3(-0.45 + k * 0.45, 1.3 + (k % 2) * 0.1, 0.05), Vector3(0.3, 0.38, 0.02), papers[k])


static func build_bench(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.42, 0), Vector3(1.6, 0.08, 0.4), WOOD)
	for sx in [-0.65, 0.65]:
		b.texture = &"wood_beam"
		b.box(Vector3(sx, 0.2, 0), Vector3(0.1, 0.4, 0.36), WOOD_DARK)


static func build_barrel(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.4, 0), Vector3(0.55, 0.8, 0.55), WOOD)
	b.texture = &"iron_plate"
	b.box(Vector3(0, 0.2, 0), Vector3(0.58, 0.06, 0.58), IRON * 0.8)
	b.box(Vector3(0, 0.6, 0), Vector3(0.58, 0.06, 0.58), IRON * 0.8)


static func build_crate(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), WOOD * 1.05)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.3, 0.305), Vector3(0.62, 0.08, 0.02), WOOD_DARK)
	b.box(Vector3(0, 0.3, -0.305), Vector3(0.62, 0.08, 0.02), WOOD_DARK)


static func build_hay_bale(b: BlockMesh) -> void:
	b.texture = &"thatch"
	b.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.6), THATCH)
	b.box(Vector3(0, 0.3, 0), Vector3(1.02, 0.08, 0.62), THATCH * 0.8)


static func build_throne(b: BlockMesh) -> void:
	var gold := Color(0.9, 0.72, 0.25)
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 1.0), STONE * 0.9)
	b.texture = &"cloth"
	b.box(Vector3(0, 0.62, 0), Vector3(0.8, 0.24, 0.7), Color(0.6, 0.12, 0.15))
	b.texture = &""
	b.box(Vector3(0, 1.4, -0.32), Vector3(0.9, 1.6, 0.14), gold)
	b.box(Vector3(-0.45, 0.85, 0), Vector3(0.1, 0.4, 0.7), gold)
	b.box(Vector3(0.45, 0.85, 0), Vector3(0.1, 0.4, 0.7), gold)
	b.box(Vector3(0, 2.3, -0.32), Vector3(0.3, 0.3, 0.1), Color(0.85, 0.2, 0.3))


static func build_stone_tower(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 2.5, 0), Vector3(2.4, 6.0, 2.4), STONE * 0.92)
	for k in 4:
		var a := k * PI * 0.5
		b.texture = &"stone_bricks"
		b.box(Vector3(cos(a) * 1.0, 5.8, sin(a) * 1.0), Vector3(0.6, 0.6, 0.6), STONE)
	b.texture = &""
	b.box(Vector3(0, 2.2, 1.21), Vector3(0.3, 0.6, 0.02), Color(0.15, 0.12, 0.1))


static func build_wagon(b: BlockMesh) -> void:
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.75, 0), Vector3(1.4, 0.5, 2.4), WOOD)
	for sx in [-0.75, 0.75]:
		for sz in [-0.8, 0.8]:
			b.texture = &"wood_beam"
			b.box(Vector3(sx, 0.4, sz), Vector3(0.12, 0.8, 0.8), WOOD_DARK)
	# canvas cover
	b.texture = &"cloth"
	b.box(Vector3(0, 1.5, 0), Vector3(1.5, 1.0, 2.2), Color(0.92, 0.88, 0.76))
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.9, 1.6), Vector3(0.1, 0.1, 1.0), WOOD_DARK)  # shaft


static func build_banner_pole(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 1.8, 0), Vector3(0.12, 3.6, 0.12), WOOD_DARK)
	b.box(Vector3(0, 3.6, 0), Vector3(0.9, 0.08, 0.08), WOOD_DARK)
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), STONE)


static func build_torch_flame(b: BlockMesh) -> void:
	b.box(Vector3(0, 1.42, 0), Vector3(0.14, 0.22, 0.14), Color(1.0, 0.75, 0.3))


static func build_carpet(b: BlockMesh) -> void:
	b.texture = &"cloth"
	b.box(Vector3(0, 0.15, 0), Vector3(1.0, 0.03, 1.0), Color(0.6, 0.12, 0.15))
	b.texture = &""
	b.box(Vector3(0.44, 0.16, 0), Vector3(0.08, 0.03, 1.0), Color(0.9, 0.72, 0.25))
	b.box(Vector3(-0.44, 0.16, 0), Vector3(0.08, 0.03, 1.0), Color(0.9, 0.72, 0.25))


## The banner cloth in a kingdom's colour (not cached: colours vary).
static func _banner_cloth(b: BlockMesh, color: Color) -> void:
	b.texture = &"cloth"
	b.box(Vector3(0, 2.95, 0.05), Vector3(0.8, 1.2, 0.04), color)
	b.texture = &""
	b.box(Vector3(0, 2.95, 0.08), Vector3(0.26, 0.26, 0.02), Color(0.95, 0.85, 0.4))


# --- Milestone 6 -----------------------------------------------------------------------

static func build_alchemy_table(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.8, 0), Vector3(1.3, 0.12, 0.75), WOOD_DARK)
	for sx in [-0.55, 0.55]:
		for sz in [-0.28, 0.28]:
			b.texture = &"wood_beam"
			b.box(Vector3(sx, 0.4, sz), Vector3(0.1, 0.8, 0.1), WOOD_DARK)
	b.texture = &""
	b.box(Vector3(-0.35, 1.0, 0), Vector3(0.22, 0.3, 0.22), Color(0.45, 0.85, 0.5))  # flask
	b.box(Vector3(-0.35, 1.2, 0), Vector3(0.08, 0.14, 0.08), Color(0.8, 0.8, 0.85))
	b.box(Vector3(0.05, 0.96, 0.05), Vector3(0.16, 0.22, 0.16), Color(0.85, 0.35, 0.6))
	b.texture = &"iron_plate"
	b.box(Vector3(0.4, 0.92, -0.1), Vector3(0.3, 0.12, 0.3), IRON * 0.7)  # mortar
	b.texture = &"planks_vertical"
	b.box(Vector3(0.4, 1.05, -0.1), Vector3(0.05, 0.25, 0.05), WOOD)


# --- Milestone 6: ruins, towers, temples, dungeons, groves -------------------------------

const OLD_STONE := Color(0.55, 0.54, 0.5)
const MOSS := Color(0.35, 0.5, 0.25)


static func build_ruin_wall_low(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.1, 0), Vector3(1.0, 1.2, 0.35), OLD_STONE)
	b.box(Vector3(-0.25, 0.8, 0), Vector3(0.5, 0.2, 0.35), OLD_STONE * 0.92)
	b.texture = &""
	b.box(Vector3(0.1, 0.72, 0.1), Vector3(0.4, 0.06, 0.2), MOSS)


static func build_ruin_wall_mid(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.5, 0), Vector3(1.0, 2.0, 0.35), OLD_STONE)
	b.box(Vector3(0.25, 1.65, 0), Vector3(0.5, 0.3, 0.35), OLD_STONE * 0.9)
	b.texture = &""
	b.box(Vector3(-0.2, 1.52, 0.1), Vector3(0.5, 0.06, 0.22), MOSS)


static func build_pillar(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), OLD_STONE * 0.9)
	b.box(Vector3(0, 1.7, 0), Vector3(0.6, 2.8, 0.6), OLD_STONE)
	b.box(Vector3(0, 3.2, 0), Vector3(0.9, 0.3, 0.9), OLD_STONE * 0.95)


static func build_pillar_broken(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), OLD_STONE * 0.9)
	b.box(Vector3(0, 0.85, 0), Vector3(0.6, 1.1, 0.6), OLD_STONE)
	b.box(Vector3(0.7, 0.2, 0.3), Vector3(0.6, 0.4, 1.2), OLD_STONE * 0.95, Basis(Vector3.UP, 0.4))


static func build_rubble(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.4), OLD_STONE)
	b.box(Vector3(0.35, 0.08, 0.25), Vector3(0.3, 0.16, 0.3), OLD_STONE * 0.9)
	b.box(Vector3(-0.3, 0.1, 0.2), Vector3(0.35, 0.2, 0.3), OLD_STONE * 1.05)
	b.texture = &""
	b.box(Vector3(0.1, 0.03, -0.3), Vector3(0.5, 0.06, 0.3), MOSS)


static func build_statue(b: BlockMesh) -> void:
	var st := Color(0.72, 0.7, 0.66)
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4), OLD_STONE * 0.85)
	b.texture = &"boulder"
	b.box(Vector3(0, 1.6, 0), Vector3(0.7, 1.2, 0.45), st)
	b.box(Vector3(0, 2.5, 0), Vector3(0.5, 0.55, 0.5), st)
	b.box(Vector3(-0.5, 1.9, 0.15), Vector3(0.22, 0.9, 0.22), st, Basis(Vector3.BACK, 0.4))
	b.box(Vector3(0.55, 2.2, 0), Vector3(0.22, 1.1, 0.22), st, Basis(Vector3.BACK, -0.2))
	b.box(Vector3(0.75, 2.9, 0), Vector3(0.12, 0.9, 0.12), st * 0.9)


static func build_altar(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 1.0), OLD_STONE * 0.9)
	b.box(Vector3(0, 0.95, 0), Vector3(2.0, 0.12, 1.1), OLD_STONE)
	b.texture = &""
	b.box(Vector3(0, 0.46, 0.51), Vector3(1.0, 0.4, 0.02), Color(0.95, 0.75, 0.3))


static func build_altar_glow(b: BlockMesh) -> void:
	b.box(Vector3(0, 1.08, 0), Vector3(0.5, 0.12, 0.5), Color(1.0, 0.85, 0.4))


static func build_lectern(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.5, 0), Vector3(0.2, 1.0, 0.2), WOOD_DARK)
	b.box(Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.5), WOOD_DARK)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 1.05, 0), Vector3(0.7, 0.08, 0.5), WOOD, Basis(Vector3.RIGHT, -0.4))


static func build_lectern_book(b: BlockMesh) -> void:
	b.texture = &""
	b.box(Vector3(-0.15, 1.13, 0.02), Vector3(0.28, 0.04, 0.36), Color(0.95, 0.9, 0.7), Basis(Vector3.RIGHT, -0.4))
	b.box(Vector3(0.15, 1.13, 0.02), Vector3(0.28, 0.04, 0.36), Color(0.95, 0.9, 0.7), Basis(Vector3.RIGHT, -0.4))


static func build_brazier(b: BlockMesh) -> void:
	b.texture = &"iron_plate"
	b.box(Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 0.3), IRON * 0.7)
	b.box(Vector3(0, 1.05, 0), Vector3(0.7, 0.2, 0.7), IRON * 0.8)
	b.box(Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.6), IRON * 0.6)


static func build_brazier_fire(b: BlockMesh) -> void:
	b.box(Vector3(0, 1.3, 0), Vector3(0.45, 0.35, 0.45), Color(1.0, 0.6, 0.2))
	b.box(Vector3(0, 1.5, 0), Vector3(0.25, 0.3, 0.25), Color(1.0, 0.85, 0.4))


static func build_dungeon_arch(b: BlockMesh) -> void:
	var st := Color(0.4, 0.38, 0.42)
	b.texture = &"stone_bricks"
	b.box(Vector3(-1.7, 1.8, 0), Vector3(0.9, 3.6, 1.2), st)
	b.box(Vector3(1.7, 1.8, 0), Vector3(0.9, 3.6, 1.2), st)
	b.box(Vector3(0, 3.9, 0), Vector3(4.4, 0.8, 1.3), st * 0.95)
	b.texture = &""
	b.box(Vector3(0, 4.5, 0), Vector3(1.0, 0.6, 0.4), Color(0.7, 0.2, 0.2))  # keystone
	# stairs down into darkness
	for k in 4:
		b.texture = &"stone_bricks"
		b.box(Vector3(0, -0.15 - k * 0.3, 0.3 - k * 0.5), Vector3(2.5, 0.3, 0.5), st * (0.8 - k * 0.12))
	b.texture = &""
	b.box(Vector3(0, -1.2, -1.6), Vector3(2.5, 2.4, 0.2), Color(0.03, 0.03, 0.05))
	b.texture = &"stone_bricks"
	b.box(Vector3(-1.3, -0.6, -0.6), Vector3(0.2, 1.5, 2.4), st * 0.6)
	b.box(Vector3(1.3, -0.6, -0.6), Vector3(0.2, 1.5, 2.4), st * 0.6)


static func build_standing_stone(b: BlockMesh) -> void:
	b.texture = &"boulder"
	b.box(Vector3(0, 1.2, 0), Vector3(0.8, 2.6, 0.5), Color(0.5, 0.5, 0.55))
	b.box(Vector3(0.05, 2.6, 0), Vector3(0.6, 0.3, 0.45), Color(0.45, 0.45, 0.5))


static func build_rune_glow(b: BlockMesh) -> void:
	b.box(Vector3(0, 1.4, 0.26), Vector3(0.2, 0.5, 0.02), Color(0.5, 0.9, 1.0))
	b.box(Vector3(0, 1.0, 0.26), Vector3(0.35, 0.08, 0.02), Color(0.5, 0.9, 1.0))


static func build_ancient_tree(b: BlockMesh) -> void:
	var bark := Color(0.35, 0.25, 0.3)
	b.texture = &"bark"
	b.box(Vector3(0, 3.0, 0), Vector3(1.6, 6.0, 1.6), bark)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		b.texture = &"bark"
		b.box(Vector3(cos(a) * 1.1, 0.4, sin(a) * 1.1), Vector3(1.2, 0.8, 0.5), bark * 0.9, Basis(Vector3.UP, a))
	var leaf := Color(0.35, 0.65, 0.6)
	b.texture = &"leaves_oak"
	b.box(Vector3(0, 7.0, 0), Vector3(7.0, 2.4, 7.0), leaf)
	b.box(Vector3(0, 8.6, 0), Vector3(4.6, 1.6, 4.6), leaf * 1.1)
	b.texture = &""
	b.box(Vector3(1.8, 6.2, 1.5), Vector3(2.4, 1.2, 2.4), Color(0.8, 0.55, 0.85))


static func build_mushroom_ring(b: BlockMesh) -> void:
	for k in 9:
		var a := TAU * k / 9.0
		var p := Vector3(cos(a) * 2.6, 0, sin(a) * 2.6)
		b.texture = &""
		b.box(p + Vector3(0, 0.12, 0), Vector3(0.08, 0.24, 0.08), Color(0.9, 0.9, 0.85))
		b.box(p + Vector3(0, 0.28, 0), Vector3(0.3, 0.1, 0.3), Color(0.6, 0.9, 1.0) if k % 2 == 0 else Color(0.95, 0.6, 1.0))


static func build_dungeon_floor(b: BlockMesh) -> void:
	b.texture = &"stone_tiles"
	b.box(Vector3(0, -0.25, 0), Vector3(1.0, 0.5, 1.0), Color(0.3, 0.29, 0.32))
	b.box(Vector3(0, 0.005, 0), Vector3(0.94, 0.01, 0.94), Color(0.34, 0.33, 0.36))


static func build_dungeon_wall(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(0, 1.75, 0), Vector3(1.0, 3.5, 0.5), Color(0.25, 0.24, 0.28))
	b.box(Vector3(0, 3.55, 0), Vector3(1.04, 0.14, 0.56), Color(0.32, 0.3, 0.34))
	b.box(Vector3(0, 0.1, 0), Vector3(1.04, 0.2, 0.56), Color(0.2, 0.19, 0.22))


# --- Milestone 7: defenses ---------------------------------------------------------------

## Log palisade: thick sharpened logs (edge piece, high hit points).
static func build_palisade_wall(b: BlockMesh) -> void:
	for k in 4:
		var x := -0.375 + k * 0.25
		var h := 2.7 + (k % 2) * 0.2
		b.texture = &"palisade"
		b.box(Vector3(x, h * 0.5 - 0.5, 0), Vector3(0.24, h + 1.0, 0.28), WOOD_DARK * (0.95 + 0.08 * (k % 2)))
		b.texture = &"wood_beam"
		b.box(Vector3(x, h + 0.05, 0), Vector3(0.14, 0.2, 0.16), WOOD * 0.9)
	b.texture = &"iron_plate"
	b.box(Vector3(0, 0.6, 0.15), Vector3(1.0, 0.12, 0.06), IRON * 0.8)
	b.box(Vector3(0, 1.9, 0.15), Vector3(1.0, 0.12, 0.06), IRON * 0.8)


## Iron-banded door frame (the leaf is the shared door_leaf).
static func build_reinforced_door(b: BlockMesh) -> void:
	b.texture = &"stone_bricks"
	b.box(Vector3(-0.45, 0.8, 0), Vector3(0.12, 2.6, 0.26), STONE * 0.8)
	b.box(Vector3(0.45, 0.8, 0), Vector3(0.12, 2.6, 0.26), STONE * 0.8)
	b.box(Vector3(0, 2.3, 0), Vector3(1.0, 0.4, 0.26), STONE * 0.75)
	b.texture = &"iron_plate"
	b.box(Vector3(0, 2.15, 0.14), Vector3(0.9, 0.06, 0.04), IRON)


## Arrow tower: wooden platform on stilts with a crossbow on top (shoots raiders).
static func build_arrow_tower(b: BlockMesh) -> void:
	for sx in [-0.35, 0.35]:
		for sz in [-0.35, 0.35]:
			b.texture = &"wood_beam"
			b.box(Vector3(sx, 1.0, sz), Vector3(0.14, 2.0, 0.14), WOOD_DARK)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.7, 0), Vector3(0.84, 0.06, 0.06), WOOD)
	b.box(Vector3(0, 0.7, 0), Vector3(0.06, 0.06, 0.84), WOOD)
	b.box(Vector3(0, 2.05, 0), Vector3(1.0, 0.12, 1.0), WOOD)
	for k in 4:
		var a := k * PI * 0.5
		b.texture = &"wood_beam"
		b.box(Vector3(cos(a) * 0.45, 2.3, sin(a) * 0.45), Vector3(0.12 if k % 2 == 0 else 0.9, 0.36, 0.9 if k % 2 == 0 else 0.12), WOOD_DARK)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 2.55, 0), Vector3(0.12, 0.3, 0.12), WOOD_DARK)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 2.72, 0.05), Vector3(0.12, 0.1, 0.7), WOOD)
	b.texture = &"iron_plate"
	b.box(Vector3(0, 2.75, 0.3), Vector3(0.7, 0.06, 0.06), IRON)
	b.texture = &""
	b.box(Vector3(0, 2.8, 0.42), Vector3(0.04, 0.04, 0.3), Color(0.9, 0.9, 0.85))


## Alarm bell: post with a hanging brass bell.
static func build_alarm_bell(b: BlockMesh) -> void:
	b.texture = &"wood_beam"
	b.box(Vector3(-0.35, 1.1, 0), Vector3(0.12, 2.2, 0.12), WOOD_DARK)
	b.box(Vector3(0.35, 1.1, 0), Vector3(0.12, 2.2, 0.12), WOOD_DARK)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 2.15, 0), Vector3(0.9, 0.12, 0.14), WOOD)
	var brass := Color(0.85, 0.65, 0.25)
	b.texture = &"iron_plate"
	b.box(Vector3(0, 1.95, 0), Vector3(0.04, 0.2, 0.04), IRON)
	b.box(Vector3(0, 1.72, 0), Vector3(0.3, 0.3, 0.3), brass)
	b.box(Vector3(0, 1.52, 0), Vector3(0.42, 0.14, 0.42), brass * 0.9)
	b.box(Vector3(0, 1.4, 0), Vector3(0.08, 0.1, 0.08), IRON * 0.7)
