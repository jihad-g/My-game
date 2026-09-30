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
	var fn := "build_%s" % name
	var script: GDScript = load("res://src/building/build_meshes.gd")
	if script.has_method(fn):
		script.call(fn, b)
	else:
		b.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var mesh := b.commit()
	_cache[name] = mesh
	return mesh


static func build_wood_floor(b: BlockMesh) -> void:
	b.box(Vector3(0, -0.2, 0), Vector3(1.0, 0.6, 1.0), WOOD_DARK)
	for k in 4:
		b.box(Vector3(-0.375 + k * 0.25, 0.11, 0), Vector3(0.24, 0.04, 0.98), WOOD * (0.95 + 0.05 * (k % 2)))


static func build_stone_floor(b: BlockMesh) -> void:
	b.box(Vector3(0, -0.2, 0), Vector3(1.0, 0.6, 1.0), STONE * 0.85)
	for i in 2:
		for j in 2:
			b.box(Vector3(-0.25 + i * 0.5, 0.11, -0.25 + j * 0.5), Vector3(0.47, 0.04, 0.47), STONE * (0.95 + 0.07 * ((i + j) % 2)))


static func _wall(b: BlockMesh, color: Color, h: float = 2.6) -> void:
	b.box(Vector3(0, h * 0.5 - 0.5, 0), Vector3(1.0, h + 1.0, 0.2), color)


static func build_wood_wall(b: BlockMesh) -> void:
	_wall(b, WOOD)
	for k in 3:
		b.box(Vector3(0, 0.45 + k * 0.85, 0), Vector3(1.0, 0.06, 0.22), WOOD_DARK)
	b.box(Vector3(-0.47, 0.8, 0), Vector3(0.08, 2.6, 0.24), WOOD_DARK)


static func build_stone_wall(b: BlockMesh) -> void:
	_wall(b, STONE)
	for k in 5:
		b.box(Vector3(0.25 * (k % 2) - 0.12, 0.25 + k * 0.5, 0), Vector3(0.5, 0.04, 0.22), STONE * 0.8)


static func build_wood_door(b: BlockMesh) -> void:
	b.box(Vector3(-0.45, 0.8, 0), Vector3(0.1, 2.6, 0.22), WOOD_DARK)
	b.box(Vector3(0.45, 0.8, 0), Vector3(0.1, 2.6, 0.22), WOOD_DARK)
	b.box(Vector3(0, 2.3, 0), Vector3(1.0, 0.4, 0.22), WOOD)


## The moving door leaf (hinged at x = -0.4).
static func build_door_leaf(b: BlockMesh) -> void:
	b.box(Vector3(0.4, 1.05, 0), Vector3(0.8, 2.1, 0.1), WOOD * 1.05)
	b.box(Vector3(0.4, 0.6, 0), Vector3(0.8, 0.08, 0.12), WOOD_DARK)
	b.box(Vector3(0.4, 1.5, 0), Vector3(0.8, 0.08, 0.12), WOOD_DARK)
	b.box(Vector3(0.7, 1.05, 0.07), Vector3(0.06, 0.12, 0.06), IRON)


static func build_wood_window(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.1, 0), Vector3(1.0, 1.2, 0.2), WOOD)
	b.box(Vector3(0, 2.3, 0), Vector3(1.0, 0.6, 0.2), WOOD)
	b.box(Vector3(-0.42, 1.35, 0), Vector3(0.16, 1.3, 0.2), WOOD_DARK)
	b.box(Vector3(0.42, 1.35, 0), Vector3(0.16, 1.3, 0.2), WOOD_DARK)
	b.box(Vector3(0, 1.35, 0), Vector3(0.06, 1.3, 0.08), WOOD_DARK)


static func build_wood_fence(b: BlockMesh) -> void:
	b.box(Vector3(-0.45, 0.35, 0), Vector3(0.12, 1.2, 0.12), WOOD_DARK)
	b.box(Vector3(0.45, 0.35, 0), Vector3(0.12, 1.2, 0.12), WOOD_DARK)
	b.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.1, 0.06), WOOD)
	b.box(Vector3(0, 0.8, 0), Vector3(1.0, 0.1, 0.06), WOOD)


static func build_spike_wall(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.25, 0), Vector3(1.0, 0.25, 0.25), WOOD_DARK)
	for k in 5:
		var x := -0.4 + k * 0.2
		b.box(Vector3(x, 0.55, 0.12), Vector3(0.08, 0.9, 0.08), WOOD, Basis(Vector3.RIGHT, 0.6))
		b.box(Vector3(x + 0.1, 0.55, -0.12), Vector3(0.08, 0.9, 0.08), WOOD, Basis(Vector3.RIGHT, -0.6))
	for k in 5:
		b.box(Vector3(-0.4 + k * 0.2, 0.95, 0.38), Vector3(0.05, 0.12, 0.05), IRON)


static func build_spike_trap(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.04, 0), Vector3(0.9, 0.08, 0.9), WOOD_DARK)
	for i in 3:
		for j in 3:
			b.box(Vector3(-0.3 + i * 0.3, 0.2, -0.3 + j * 0.3), Vector3(0.06, 0.3, 0.06), IRON)


static func build_thatch_roof(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.08, 0), Vector3(1.1, 0.16, 1.1), THATCH)
	b.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.1, 0.9), THATCH * 1.05)


static func build_wood_roof(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.08, 0), Vector3(1.1, 0.16, 1.1), Color(0.55, 0.28, 0.22))
	for k in 4:
		b.box(Vector3(0, 0.18, -0.4 + k * 0.27), Vector3(1.1, 0.06, 0.12), Color(0.45, 0.22, 0.18))


static func build_table(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.75, 0), Vector3(0.95, 0.1, 0.7), WOOD)
	for sx in [-0.4, 0.4]:
		for sz in [-0.28, 0.28]:
			b.box(Vector3(sx, 0.35, sz), Vector3(0.08, 0.7, 0.08), WOOD_DARK)


static func build_chair(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.45, 0), Vector3(0.5, 0.08, 0.5), WOOD)
	b.box(Vector3(0, 0.8, -0.22), Vector3(0.5, 0.65, 0.06), WOOD_DARK)
	for sx in [-0.2, 0.2]:
		for sz in [-0.2, 0.2]:
			b.box(Vector3(sx, 0.22, sz), Vector3(0.06, 0.44, 0.06), WOOD_DARK)


static func build_bed(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.3, 1.9), WOOD_DARK)
	b.box(Vector3(0, 0.45, 0.1), Vector3(0.84, 0.14, 1.6), Color(0.85, 0.35, 0.3))
	b.box(Vector3(0, 0.5, -0.72), Vector3(0.6, 0.14, 0.32), Color(0.95, 0.93, 0.88))
	b.box(Vector3(0, 0.6, -0.92), Vector3(0.9, 0.7, 0.08), WOOD)


static func build_chest(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.55), WOOD)
	b.box(Vector3(0, 0.65, 0), Vector3(0.84, 0.12, 0.6), WOOD_DARK)
	b.box(Vector3(0, 0.45, 0.29), Vector3(0.12, 0.14, 0.04), Color(0.85, 0.7, 0.3))


static func build_torch(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.6, 0), Vector3(0.1, 1.2, 0.1), WOOD_DARK)
	b.box(Vector3(0, 1.25, 0), Vector3(0.16, 0.14, 0.16), Color(0.25, 0.2, 0.15))


static func build_workbench(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.8, 0), Vector3(1.4, 0.14, 0.8), WOOD)
	for sx in [-0.6, 0.6]:
		for sz in [-0.32, 0.32]:
			b.box(Vector3(sx, 0.4, sz), Vector3(0.12, 0.8, 0.12), WOOD_DARK)
	b.box(Vector3(-0.3, 0.92, 0.1), Vector3(0.4, 0.1, 0.2), STONE)  # whetstone
	b.box(Vector3(0.35, 0.9, -0.15), Vector3(0.08, 0.06, 0.4), IRON)  # saw


static func build_forge(b: BlockMesh) -> void:
	b.box(Vector3(-0.3, 0.55, 0), Vector3(1.0, 1.1, 1.0), STONE * 0.9)
	b.box(Vector3(-0.3, 1.3, 0), Vector3(0.6, 0.5, 0.6), STONE * 0.8)  # chimney
	b.box(Vector3(-0.3, 0.55, 0.51), Vector3(0.5, 0.4, 0.04), Color(1.0, 0.45, 0.1))  # fire mouth
	b.box(Vector3(0.6, 0.35, 0), Vector3(0.3, 0.7, 0.3), WOOD_DARK)
	b.box(Vector3(0.6, 0.78, 0), Vector3(0.6, 0.16, 0.35), IRON)  # anvil


static func build_tailoring(b: BlockMesh) -> void:
	build_table(b)
	b.box(Vector3(0.2, 0.83, 0), Vector3(0.5, 0.04, 0.5), Color(0.8, 0.75, 0.6))  # cloth
	b.box(Vector3(-0.35, 0.95, -0.1), Vector3(0.14, 0.3, 0.14), Color(0.55, 0.35, 0.25))  # spool
	b.box(Vector3(-0.8, 0.9, 0), Vector3(0.1, 1.8, 0.1), WOOD_DARK)  # drying rack
	b.box(Vector3(-0.8, 1.5, 0.3), Vector3(0.04, 0.6, 0.5), Color(0.5, 0.34, 0.22))


static func build_arcane_altar(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.0), STONE * 0.75)
	b.box(Vector3(0, 0.75, 0), Vector3(0.7, 0.3, 0.7), STONE * 0.85)
	b.box(Vector3(0, 1.2, 0), Vector3(0.2, 0.5, 0.2), Color(0.7, 0.45, 1.0))
	b.box(Vector3(0.28, 1.0, 0.28), Vector3(0.1, 0.25, 0.1), Color(0.45, 0.85, 1.0))
	b.box(Vector3(-0.28, 1.0, -0.28), Vector3(0.1, 0.25, 0.1), Color(0.45, 0.85, 1.0))


static func build_claim_flag(b: BlockMesh) -> void:
	b.box(Vector3(0, 1.3, 0), Vector3(0.1, 2.6, 0.1), WOOD_DARK)
	b.box(Vector3(0.35, 2.25, 0), Vector3(0.6, 0.45, 0.04), Color(0.2, 0.55, 0.95))
	b.box(Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), STONE)


static func build_claim_totem(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9), STONE)
	b.box(Vector3(0, 1.1, 0), Vector3(0.5, 1.2, 0.5), WOOD)
	b.box(Vector3(0, 1.9, 0), Vector3(0.6, 0.4, 0.6), WOOD_DARK)
	b.box(Vector3(0, 1.95, 0.31), Vector3(0.3, 0.12, 0.04), Color(1.0, 0.8, 0.3))
	b.box(Vector3(0.4, 1.9, 0), Vector3(0.3, 0.12, 0.12), WOOD_DARK)
	b.box(Vector3(-0.4, 1.9, 0), Vector3(0.3, 0.12, 0.12), WOOD_DARK)
	b.box(Vector3(0, 2.3, 0), Vector3(0.18, 0.3, 0.18), Color(0.3, 0.8, 1.0))
