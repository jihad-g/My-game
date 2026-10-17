class_name PropLibrary
extends RefCounted
## Loads PropData resources and builds (and caches) their blocky meshes.
##
## Meshes are generated in code from coloured boxes (BlockMesh), so the art
## style stays consistent and no external model files are required yet.
## To add a prop: create a PropData .tres in res://data/props/ and, if it needs a
## new shape, add a `_build_<name>` function below.

const PROP_DIR := "res://data/props/"

var _props: Dictionary = {}  # StringName -> PropData
var _meshes: Dictionary = {}  # StringName -> Mesh
var _shapes: Dictionary = {}  # StringName -> Shape3D


func _init() -> void:
	for file in ResourceLoader.list_directory(PROP_DIR):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(PROP_DIR + file)
			if res is PropData:
				_props[res.id] = res


## Wind sway per mesh (bend in metres per metre² of height; Milestone 10).
const SWAY := {
	&"tree_oak": 0.0035, &"tree_pine": 0.0025, &"tree_snowy_pine": 0.0025, &"tree_palm": 0.004,
	&"tree_jungle": 0.003, &"tree_swamp": 0.003, &"grass_tuft": 0.3, &"flowers": 0.25, &"reeds": 0.15,
	&"berry_bush": 0.03, &"frostberry_bush": 0.03, &"dead_bush": 0.02, &"sunbloom": 0.06, &"moonpetal": 0.06,
	&"starlight_orchid": 0.06, &"frost_lotus": 0.04, &"emberroot": 0.04,
	# Milestone 26 ("Rich World")
	&"flower_bush": 0.03, &"fern": 0.2, &"wildflowers_white": 0.25, &"wildflowers_orange": 0.25,
}


func get_prop(id: StringName) -> PropData:
	return _props.get(id)


func get_mesh(id: StringName) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var data := get_prop(id)
	var mesh: Mesh = null
	if data:
		var fn := "_build_%s" % data.mesh_builder
		if has_method(fn):
			var b := BlockMesh.new()
			call(fn, b)
			mesh = b.commit()
			var sway: float = SWAY.get(data.mesh_builder, 0.0)
			# v0.26.0: small plants are crossed cut-out cards (their own surface).
			var cards: int = mesh.get_meta(&"card_surface", -1)
			if cards >= 0:
				mesh.surface_set_material(cards, Materials.sprite(sway, 1.4 if data.glow else 0.0))
			if cards != 0 and mesh.get_surface_count() > 0:
				if data.glow:
					mesh.surface_set_material(0, Materials.vertex_color_emissive())
				elif sway > 0.0:
					mesh.surface_set_material(0, Materials.foliage(sway, data.fade_near_camera))
				elif data.fade_near_camera:
					mesh.surface_set_material(0, Materials.vertex_color_occluder())
		else:
			push_error("PropLibrary: missing mesh builder %s for %s" % [fn, id])
	if mesh == null:
		var b := BlockMesh.new()
		b.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)  # "missing" placeholder
		mesh = b.commit()
	_meshes[id] = mesh
	return mesh


## Collision shape (bottom-anchored cylinder). Shared between all instances.
func get_shape(id: StringName) -> Shape3D:
	if _shapes.has(id):
		return _shapes[id]
	var data := get_prop(id)
	var shape := CylinderShape3D.new()
	shape.radius = data.collision_radius if data else 0.4
	shape.height = data.collision_height if data else 1.0
	_shapes[id] = shape
	return shape


# --- Mesh builders -------------------------------------------------------------

func _build_tree_oak(b: BlockMesh) -> void:
	var trunk := Color(0.45, 0.3, 0.18)
	var leaf := Color(0.19, 0.46, 0.18)
	var leaf_light := Color(0.3, 0.57, 0.21)
	b.texture = &"bark"
	b.box(Vector3(0, 1.1, 0), Vector3(0.5, 2.2, 0.5), trunk)
	b.texture = &"leaves_oak"
	b.box(Vector3(0, 2.6, 0), Vector3(2.4, 1.2, 2.4), leaf)
	b.box(Vector3(0, 3.5, 0), Vector3(1.7, 0.9, 1.7), leaf_light)
	b.box(Vector3(0.9, 2.3, 0.5), Vector3(0.9, 0.8, 0.9), leaf_light)
	b.box(Vector3(-0.7, 2.2, -0.8), Vector3(0.8, 0.7, 0.8), leaf)
	b.box(Vector3(0, 4.1, 0), Vector3(0.8, 0.5, 0.8), leaf)
	b.texture = &""


func _build_tree_pine(b: BlockMesh) -> void:
	var trunk := Color(0.4, 0.26, 0.16)
	var needle := Color(0.18, 0.5, 0.33)
	var needle_light := Color(0.24, 0.6, 0.38)
	b.texture = &"bark"
	b.box(Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45), trunk)
	b.texture = &"leaves_pine"
	b.box(Vector3(0, 1.8, 0), Vector3(2.2, 0.8, 2.2), needle)
	b.box(Vector3(0, 2.6, 0), Vector3(1.7, 0.8, 1.7), needle_light)
	b.box(Vector3(0, 3.4, 0), Vector3(1.2, 0.8, 1.2), needle)
	b.box(Vector3(0, 4.1, 0), Vector3(0.7, 0.7, 0.7), needle_light)
	b.box(Vector3(0, 4.65, 0), Vector3(0.3, 0.4, 0.3), needle)
	b.texture = &""


func _build_rock(b: BlockMesh) -> void:
	# Milestone 26: lighter grey stone, like the rest of the Rich World ground cover.
	var stone := Color(0.62, 0.61, 0.6)
	var stone_dark := Color(0.52, 0.51, 0.5)
	b.texture = &"boulder"
	b.box(Vector3(0, 0.35, 0), Vector3(1.3, 0.7, 1.1), stone)
	b.box(Vector3(0.25, 0.8, 0.1), Vector3(0.8, 0.4, 0.7), stone_dark)
	b.box(Vector3(-0.55, 0.2, 0.45), Vector3(0.5, 0.4, 0.5), stone_dark)
	b.texture = &""


func _build_berry_bush(b: BlockMesh) -> void:
	var leaf := Color(0.25, 0.55, 0.25)
	var berry := Color(0.85, 0.15, 0.35)
	# v0.26.0: full-colour texture (leaves + painted berries) on a white vertex colour.
	b.texture = &"berry_bush"
	b.box(Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 1.0), Color.WHITE)
	b.box(Vector3(0.1, 0.75, -0.05), Vector3(0.7, 0.3, 0.7), Color.WHITE * 1.08)
	b.texture = &""
	for p: Vector3 in [Vector3(0.45, 0.5, 0.2), Vector3(-0.3, 0.6, 0.45), Vector3(0.2, 0.85, -0.3),
			Vector3(-0.45, 0.4, -0.25), Vector3(0.05, 0.3, 0.52)]:
		b.box(p, Vector3(0.16, 0.16, 0.16), berry)


func _build_flowers(b: BlockMesh) -> void:
	# v0.26.0: a clump of pixel-art flowers on crossed cards (was 4 tiny boxes).
	b.card(Vector3.ZERO, &"flowers_mixed", 0.9, 0.85)


func _build_grass_tuft(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"grass_tuft", 0.85, 0.75, Color(0.42, 0.7, 0.3))


func _build_stick_pile(b: BlockMesh) -> void:
	var wood := Color(0.55, 0.38, 0.22)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.08, 0.08), wood, Basis(Vector3.UP, 0.4))
	b.box(Vector3(0.05, 0.1, 0.05), Vector3(0.8, 0.08, 0.08), wood * 0.9, Basis(Vector3.UP, -0.6))
	b.texture = &""


func _build_stone_pile(b: BlockMesh) -> void:
	var s := Color(0.6, 0.6, 0.64)
	b.texture = &"boulder"
	b.box(Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.28), s)
	b.box(Vector3(0.22, 0.07, 0.15), Vector3(0.2, 0.14, 0.18), s * 0.9)
	b.box(Vector3(-0.18, 0.06, 0.12), Vector3(0.16, 0.12, 0.16), s * 1.05)
	b.texture = &""


# --- Milestone 2 vegetation -------------------------------------------------------

func _build_tree_jungle(b: BlockMesh) -> void:
	var trunk := Color(0.4, 0.28, 0.17)
	var leaf := Color(0.12, 0.44, 0.19)
	var leaf_light := Color(0.19, 0.54, 0.22)
	var vine := Color(0.22, 0.55, 0.22)
	b.texture = &"bark"
	b.box(Vector3(0, 2.0, 0), Vector3(0.6, 4.0, 0.6), trunk)
	b.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 1.0), trunk * 0.9)  # buttress roots
	b.texture = &"leaves_jungle"
	b.box(Vector3(0, 4.3, 0), Vector3(3.4, 1.0, 3.4), leaf)
	b.box(Vector3(0.3, 5.1, -0.2), Vector3(2.4, 0.8, 2.4), leaf_light)
	b.box(Vector3(1.4, 3.9, 1.2), Vector3(1.2, 0.7, 1.2), leaf_light)
	b.texture = &""
	for p: Vector3 in [Vector3(1.5, 3.2, 0.3), Vector3(-1.4, 3.3, -0.8), Vector3(0.4, 3.0, 1.5), Vector3(-0.6, 3.1, 1.4)]:
		b.box(p, Vector3(0.12, 1.4, 0.12), vine)


func _build_tree_palm(b: BlockMesh) -> void:
	var trunk := Color(0.62, 0.48, 0.3)
	var frond := Color(0.3, 0.66, 0.26)
	b.texture = &"bark"
	for k in 6:
		b.box(Vector3(k * 0.08, 0.3 + k * 0.6, 0), Vector3(0.36, 0.62, 0.36), trunk * (0.9 + 0.04 * (k % 2)))
	var top := Vector3(0.45, 3.7, 0)
	b.texture = &"palm_frond"
	for k in 6:
		var a := TAU * k / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		b.box(top + dir * 0.9 + Vector3(0, -0.15, 0), Vector3(1.8, 0.1, 0.45), frond,
			Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.25))
	b.texture = &""
	b.box(top + Vector3(0.15, -0.35, 0.1), Vector3(0.22, 0.22, 0.22), Color(0.45, 0.3, 0.15))
	b.box(top + Vector3(-0.15, -0.35, -0.1), Vector3(0.22, 0.22, 0.22), Color(0.4, 0.27, 0.13))


func _build_tree_snowy_pine(b: BlockMesh) -> void:
	_build_tree_pine(b)
	var snow := Color(0.95, 0.97, 1.0)
	b.texture = &"snow_top_0"
	b.box(Vector3(0, 2.25, 0), Vector3(2.0, 0.12, 2.0), snow)
	b.box(Vector3(0, 3.05, 0), Vector3(1.5, 0.12, 1.5), snow)
	b.box(Vector3(0, 3.85, 0), Vector3(1.0, 0.12, 1.0), snow)
	b.box(Vector3(0, 4.5, 0), Vector3(0.6, 0.12, 0.6), snow)
	b.texture = &""


func _build_tree_swamp(b: BlockMesh) -> void:
	var trunk := Color(0.28, 0.22, 0.16)
	var leaf := Color(0.3, 0.42, 0.2)
	var moss := Color(0.42, 0.5, 0.3)
	b.texture = &"bark"
	b.box(Vector3(0, 1.3, 0), Vector3(0.55, 2.6, 0.55), trunk)
	b.box(Vector3(0.45, 0.25, 0.1), Vector3(0.5, 0.5, 0.25), trunk * 0.9, Basis(Vector3.FORWARD, 0.6))
	b.box(Vector3(-0.4, 0.25, -0.2), Vector3(0.5, 0.5, 0.25), trunk * 0.9, Basis(Vector3.FORWARD, -0.6))
	b.texture = &"bush_leaves"
	b.box(Vector3(0, 2.9, 0), Vector3(2.8, 0.7, 2.8), leaf)
	b.texture = &"hanging_moss"
	for p: Vector3 in [Vector3(1.2, 2.2, 0), Vector3(-1.2, 2.2, 0.4), Vector3(0.3, 2.1, 1.2), Vector3(-0.3, 2.2, -1.2), Vector3(0.9, 2.1, -0.9)]:
		b.box(p, Vector3(0.35, 1.2, 0.35), moss)
	b.texture = &""


func _build_tree_dead(b: BlockMesh) -> void:
	var wood := Color(0.48, 0.4, 0.33)
	b.texture = &"bark"
	b.box(Vector3(0, 1.2, 0), Vector3(0.35, 2.4, 0.35), wood)
	b.box(Vector3(0.45, 1.9, 0), Vector3(0.9, 0.15, 0.15), wood * 0.9, Basis(Vector3.BACK, 0.5))
	b.box(Vector3(-0.35, 2.3, 0.1), Vector3(0.7, 0.14, 0.14), wood * 0.85, Basis(Vector3.BACK, -0.6))
	b.box(Vector3(0.1, 2.2, -0.35), Vector3(0.12, 0.12, 0.7), wood * 0.9, Basis(Vector3.RIGHT, 0.5))
	b.texture = &""


func _build_cactus(b: BlockMesh) -> void:
	var green := Color(0.3, 0.6, 0.3)
	b.texture = &"cactus"
	b.box(Vector3(0, 1.1, 0), Vector3(0.5, 2.2, 0.5), green)
	b.box(Vector3(0.45, 1.1, 0), Vector3(0.4, 0.3, 0.3), green * 0.95)
	b.box(Vector3(0.55, 1.5, 0), Vector3(0.28, 0.8, 0.28), green * 0.95)
	b.box(Vector3(-0.42, 0.8, 0), Vector3(0.35, 0.28, 0.28), green * 0.9)
	b.box(Vector3(-0.5, 1.15, 0), Vector3(0.26, 0.6, 0.26), green * 0.9)
	b.texture = &""
	b.box(Vector3(0, 2.28, 0), Vector3(0.22, 0.16, 0.22), Color(1.0, 0.45, 0.6))


func _build_dead_bush(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"dead_bush", 0.8, 0.8)


func _build_reeds(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"reeds", 1.0, 1.4)


func _build_lily_pad(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.02, 0), Vector3(0.7, 0.04, 0.6), Color(0.3, 0.6, 0.28))
	b.box(Vector3(0.15, 0.08, 0.1), Vector3(0.14, 0.1, 0.14), Color(1.0, 0.7, 0.85))


func _build_mushroom_giant(b: BlockMesh) -> void:
	b.box(Vector3(0, 0.9, 0), Vector3(0.45, 1.8, 0.45), Color(0.92, 0.88, 0.78))
	b.texture = &"mushroom_cap"
	b.box(Vector3(0, 1.95, 0), Vector3(2.0, 0.5, 2.0), Color.WHITE)
	b.box(Vector3(0, 2.3, 0), Vector3(1.2, 0.3, 1.2), Color.WHITE * 1.03)
	b.texture = &""
	for p: Vector3 in [Vector3(0.6, 2.21, 0.4), Vector3(-0.5, 2.21, -0.3), Vector3(0.1, 2.46, -0.4), Vector3(-0.7, 2.21, 0.6)]:
		b.box(p, Vector3(0.22, 0.04, 0.22), Color(1, 1, 0.95))


func _build_mushroom_patch(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"mushroom_patch", 0.55, 0.55)


func _build_glowcap(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"glowcap", 0.55, 0.55)


func _build_crystal_cluster(b: BlockMesh) -> void:
	var c1 := Color(0.72, 0.45, 1.0)
	var c2 := Color(0.45, 0.85, 1.0)
	b.texture = &"crystal"
	b.box(Vector3(0, 0.6, 0), Vector3(0.35, 1.3, 0.35), c1, Basis(Vector3.BACK, 0.1))
	b.box(Vector3(0.35, 0.4, 0.1), Vector3(0.25, 0.9, 0.25), c2, Basis(Vector3.BACK, -0.45))
	b.box(Vector3(-0.3, 0.35, 0.2), Vector3(0.22, 0.75, 0.22), c1 * 1.1, Basis(Vector3.BACK, 0.5))
	b.box(Vector3(0.05, 0.3, -0.3), Vector3(0.2, 0.6, 0.2), c2, Basis(Vector3.RIGHT, -0.5))
	b.texture = &""


func _build_moonpetal(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"moonpetal", 0.65, 0.65)


func _build_frostberry_bush(b: BlockMesh) -> void:
	var leaf := Color(0.25, 0.45, 0.4)
	b.texture = &"frostberry_bush"
	b.box(Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 1.0), Color.WHITE)
	b.texture = &"snow_top_0"
	b.box(Vector3(0, 0.74, 0), Vector3(0.9, 0.1, 0.9), Color(0.95, 0.97, 1.0))
	b.texture = &""
	for p: Vector3 in [Vector3(0.45, 0.5, 0.2), Vector3(-0.3, 0.55, 0.45), Vector3(-0.45, 0.4, -0.25), Vector3(0.1, 0.3, 0.52)]:
		b.box(p, Vector3(0.15, 0.15, 0.15), Color(0.5, 0.75, 1.0))


func _build_rock_snowy(b: BlockMesh) -> void:
	_build_rock(b)
	b.texture = &"snow_top_0"
	b.box(Vector3(0.25, 1.02, 0.1), Vector3(0.82, 0.08, 0.72), Color(0.96, 0.97, 1.0))
	b.box(Vector3(-0.2, 0.72, -0.1), Vector3(0.7, 0.06, 0.6), Color(0.96, 0.97, 1.0))
	b.texture = &""


func _build_sandstone_rock(b: BlockMesh) -> void:
	var s := Color(0.85, 0.68, 0.45)
	b.texture = &"sandstone_side"
	b.box(Vector3(0, 0.25, 0), Vector3(1.4, 0.5, 1.2), s)
	b.box(Vector3(0.1, 0.65, 0), Vector3(1.1, 0.3, 0.9), s * 1.08)
	b.box(Vector3(0.15, 0.9, 0.05), Vector3(0.7, 0.2, 0.6), s * 0.95)
	b.texture = &""


func _ore_rock(b: BlockMesh, ore: Color, tex: StringName = &"") -> void:
	var stone := Color(0.5, 0.5, 0.54)
	# v0.26.0: the stone carries a full-colour ore texture (white vertex colour).
	b.texture = tex
	var base := Color.WHITE if tex != &"" else stone
	b.box(Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.1), base)
	b.box(Vector3(0.2, 0.9, 0), Vector3(0.7, 0.3, 0.6), base * 0.9)
	b.texture = &""
	for p: Vector3 in [Vector3(0.61, 0.45, 0.1), Vector3(-0.3, 0.81, 0.2), Vector3(0.1, 0.3, 0.56), Vector3(-0.61, 0.3, -0.2), Vector3(0.3, 1.06, -0.1)]:
		b.box(p, Vector3(0.2, 0.18, 0.2), ore)


func _build_ore_copper(b: BlockMesh) -> void:
	_ore_rock(b, Color(0.9, 0.5, 0.25), &"ore_copper")


func _build_ore_iron(b: BlockMesh) -> void:
	_ore_rock(b, Color(0.8, 0.62, 0.55), &"ore_iron")


func _build_ore_coal(b: BlockMesh) -> void:
	_ore_rock(b, Color(0.12, 0.12, 0.14), &"ore_coal")


func _build_stalagmite(b: BlockMesh) -> void:
	var s := Color(0.45, 0.42, 0.46)
	b.texture = &"cave_stone_side"
	b.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), s)
	b.box(Vector3(0, 1.1, 0), Vector3(0.55, 0.7, 0.55), s * 1.05)
	b.box(Vector3(0, 1.7, 0), Vector3(0.32, 0.6, 0.32), s * 1.1)
	b.box(Vector3(0, 2.15, 0), Vector3(0.14, 0.35, 0.14), s * 1.15)
	b.texture = &""


func _build_clay_deposit(b: BlockMesh) -> void:
	var c := Color(0.72, 0.45, 0.35)
	b.texture = &"dirt_top"
	b.box(Vector3(0, 0.08, 0), Vector3(0.9, 0.16, 0.7), c)
	b.box(Vector3(0.2, 0.18, 0.1), Vector3(0.45, 0.12, 0.35), c * 1.08)
	b.texture = &""


# --- Milestone 4 ----------------------------------------------------------------

## Old supply crate left by lost miners (cave loot: recipe books, ores).
func _build_forgotten_cache(b: BlockMesh) -> void:
	var wood := Color(0.42, 0.3, 0.2)
	b.texture = &"planks_vertical"
	b.box(Vector3(0, 0.28, 0), Vector3(0.8, 0.56, 0.6), wood)
	b.box(Vector3(0, 0.6, 0), Vector3(0.84, 0.1, 0.64), wood * 0.8)
	b.texture = &""
	b.box(Vector3(-0.3, 0.28, 0.31), Vector3(0.06, 0.56, 0.02), Color(0.45, 0.45, 0.5))
	b.box(Vector3(0.3, 0.28, 0.31), Vector3(0.06, 0.56, 0.02), Color(0.45, 0.45, 0.5))
	b.box(Vector3(0.55, 0.1, 0.2), Vector3(0.3, 0.2, 0.3), Color(0.55, 0.55, 0.6))
	b.box(Vector3(-0.2, 0.7, 0.05), Vector3(0.3, 0.08, 0.22), Color(0.55, 0.2, 0.2))  # a book on top


# --- Milestone 6: magical plants & rare ore -----------------------------------------

func _build_sunbloom(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"sunbloom", 0.65, 0.65)


func _build_frost_lotus(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"frost_lotus", 0.6, 0.6)


func _build_emberroot(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"emberroot", 0.55, 0.55)


func _build_dreamcap(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"dreamcap", 0.55, 0.55)


func _build_starlight_orchid(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"starlight_orchid", 0.8, 0.8)


func _build_ore_mithril(b: BlockMesh) -> void:
	_ore_rock(b, Color(0.55, 0.75, 1.0), &"ore_silver")


# --- Milestone 26: Rich World ground cover ------------------------------------------------

## A round leafy shrub dotted with yellow and orange blossoms.
func _build_flower_bush(b: BlockMesh) -> void:
	var leaf := Color(0.27, 0.52, 0.22)
	b.texture = &"bush_leaves"
	b.box(Vector3(0, 0.3, 0), Vector3(0.95, 0.6, 0.9), leaf)
	b.box(Vector3(-0.1, 0.62, 0.05), Vector3(0.65, 0.3, 0.6), leaf * 1.12)
	b.box(Vector3(0.32, 0.45, -0.25), Vector3(0.4, 0.3, 0.4), leaf * 0.92)
	b.texture = &""
	var blossoms := [Color(1.0, 0.8, 0.22), Color(0.98, 0.56, 0.16), Color(1.0, 0.92, 0.45)]
	var pts := [Vector3(0.38, 0.55, 0.3), Vector3(-0.35, 0.5, 0.38), Vector3(0.1, 0.8, -0.12), Vector3(-0.4, 0.42, -0.3),
		Vector3(0.45, 0.35, -0.1), Vector3(-0.05, 0.62, 0.42), Vector3(0.22, 0.78, 0.2), Vector3(-0.25, 0.78, -0.05),
		Vector3(0.0, 0.3, -0.47)]
	for i in pts.size():
		b.box(pts[i], Vector3(0.13, 0.13, 0.13), blossoms[i % blossoms.size()])


func _build_fern(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"fern", 1.15, 1.0, Color(0.34, 0.62, 0.28))


func _build_wildflowers_white(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"flowers_white", 0.9, 0.8)


func _build_wildflowers_orange(b: BlockMesh) -> void:
	b.card(Vector3.ZERO, &"flowers_orange", 0.95, 0.85)


## A few small stones lying in the grass.
func _build_pebbles(b: BlockMesh) -> void:
	var s := Color(0.62, 0.6, 0.58)
	b.texture = &"boulder"
	b.box(Vector3(0.0, 0.04, 0.0), Vector3(0.16, 0.08, 0.13), s)
	b.box(Vector3(0.24, 0.03, 0.12), Vector3(0.1, 0.06, 0.1), s * 0.88)
	b.box(Vector3(-0.2, 0.035, 0.2), Vector3(0.12, 0.07, 0.09), s * 1.06)
	b.box(Vector3(0.1, 0.03, -0.25), Vector3(0.09, 0.06, 0.08), s * 0.95)
	b.texture = &""


## A big grey boulder with a cap of moss and a tuft of grass.
func _build_mossy_boulder(b: BlockMesh) -> void:
	var stone := Color(0.55, 0.54, 0.52)
	var moss := Color(0.33, 0.55, 0.24)
	b.texture = &"boulder"
	b.box(Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 1.3), stone)
	b.box(Vector3(-0.2, 1.0, 0.05), Vector3(1.0, 0.35, 0.9), stone * 1.06)
	b.box(Vector3(0.6, 0.25, 0.55), Vector3(0.55, 0.5, 0.5), stone * 0.88)
	b.texture = &"grass_forest_top_0"
	b.box(Vector3(-0.25, 1.2, 0.0), Vector3(0.85, 0.08, 0.75), moss)
	b.box(Vector3(-0.55, 0.92, -0.2), Vector3(0.45, 0.08, 0.6), moss * 0.92)
	b.texture = &""
	b.card(Vector3(0.75, 0.0, -0.55), &"grass_tuft", 0.5, 0.45, moss * 1.1)


## A mossy log lying on the ground, with a broken end and a small fungus.
func _build_fallen_log(b: BlockMesh) -> void:
	var bark := Color(0.54, 0.38, 0.24)
	var moss := Color(0.33, 0.55, 0.24)
	b.texture = &"bark"
	b.box(Vector3(0, 0.27, 0), Vector3(2.4, 0.5, 0.5), bark)
	b.box(Vector3(1.0, 0.22, 0.32), Vector3(0.18, 0.12, 0.22), bark * 0.9)
	b.texture = &"wood_beam"
	b.box(Vector3(-1.21, 0.27, 0), Vector3(0.04, 0.42, 0.42), Color(0.72, 0.56, 0.36))
	b.texture = &"grass_forest_top_0"
	b.box(Vector3(0.2, 0.54, 0.0), Vector3(1.3, 0.06, 0.4), moss)
	b.texture = &""
	b.box(Vector3(-0.6, 0.4, 0.27), Vector3(0.22, 0.05, 0.12), Color(0.86, 0.62, 0.3))
	b.card(Vector3(0.6, 0.0, -0.35), &"fern", 0.6, 0.5, moss)


func _build_tree_stump(b: BlockMesh) -> void:
	var bark := Color(0.56, 0.4, 0.26)
	b.texture = &"bark"
	b.box(Vector3(0, 0.22, 0), Vector3(0.6, 0.44, 0.6), bark)
	b.box(Vector3(0.3, 0.06, 0.15), Vector3(0.22, 0.12, 0.18), bark * 0.9)
	b.box(Vector3(-0.22, 0.06, -0.3), Vector3(0.18, 0.12, 0.2), bark * 0.9)
	b.texture = &"wood_beam"
	b.box(Vector3(0, 0.45, 0), Vector3(0.52, 0.03, 0.52), Color(0.78, 0.6, 0.38))
	b.texture = &""
	b.card(Vector3(-0.35, 0.0, 0.3), &"mushroom_patch", 0.4, 0.4)


## A weathered headstone, leaning a little, with moss at its feet.
func _build_old_gravestone(b: BlockMesh) -> void:
	var stone := Color(0.6, 0.6, 0.62)
	var lean := Basis(Vector3(0, 0, 1), 0.08)
	b.texture = &"boulder"
	b.box(Vector3(0, 0.42, 0), Vector3(0.55, 0.84, 0.16), stone, lean)
	b.box(Vector3(-0.035, 0.9, 0), Vector3(0.42, 0.14, 0.16), stone * 1.04, lean)
	b.texture = &""
	b.box(Vector3(-0.03, 0.55, 0.085), Vector3(0.06, 0.3, 0.02), stone * 0.7, lean)
	b.box(Vector3(-0.03, 0.62, 0.085), Vector3(0.22, 0.06, 0.02), stone * 0.7, lean)
	b.card(Vector3(0.0, 0.0, 0.2), &"grass_tuft", 0.6, 0.35, Color(0.33, 0.55, 0.24))
