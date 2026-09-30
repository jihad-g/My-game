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
			if data.fade_near_camera:
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
	var leaf := Color(0.3, 0.68, 0.28)
	var leaf_light := Color(0.42, 0.78, 0.32)
	b.box(Vector3(0, 1.1, 0), Vector3(0.5, 2.2, 0.5), trunk)
	b.box(Vector3(0, 2.6, 0), Vector3(2.4, 1.2, 2.4), leaf)
	b.box(Vector3(0, 3.5, 0), Vector3(1.7, 0.9, 1.7), leaf_light)
	b.box(Vector3(0.9, 2.3, 0.5), Vector3(0.9, 0.8, 0.9), leaf_light)
	b.box(Vector3(-0.7, 2.2, -0.8), Vector3(0.8, 0.7, 0.8), leaf)
	b.box(Vector3(0, 4.1, 0), Vector3(0.8, 0.5, 0.8), leaf)


func _build_tree_pine(b: BlockMesh) -> void:
	var trunk := Color(0.4, 0.26, 0.16)
	var needle := Color(0.18, 0.5, 0.33)
	var needle_light := Color(0.24, 0.6, 0.38)
	b.box(Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45), trunk)
	b.box(Vector3(0, 1.8, 0), Vector3(2.2, 0.8, 2.2), needle)
	b.box(Vector3(0, 2.6, 0), Vector3(1.7, 0.8, 1.7), needle_light)
	b.box(Vector3(0, 3.4, 0), Vector3(1.2, 0.8, 1.2), needle)
	b.box(Vector3(0, 4.1, 0), Vector3(0.7, 0.7, 0.7), needle_light)
	b.box(Vector3(0, 4.65, 0), Vector3(0.3, 0.4, 0.3), needle)


func _build_rock(b: BlockMesh) -> void:
	var stone := Color(0.55, 0.56, 0.6)
	var stone_dark := Color(0.46, 0.47, 0.52)
	b.box(Vector3(0, 0.35, 0), Vector3(1.3, 0.7, 1.1), stone)
	b.box(Vector3(0.25, 0.8, 0.1), Vector3(0.8, 0.4, 0.7), stone_dark)
	b.box(Vector3(-0.55, 0.2, 0.45), Vector3(0.5, 0.4, 0.5), stone_dark)


func _build_berry_bush(b: BlockMesh) -> void:
	var leaf := Color(0.25, 0.55, 0.25)
	var berry := Color(0.85, 0.15, 0.35)
	b.box(Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 1.0), leaf)
	b.box(Vector3(0.1, 0.75, -0.05), Vector3(0.7, 0.3, 0.7), leaf * 1.1)
	for p: Vector3 in [Vector3(0.45, 0.5, 0.2), Vector3(-0.3, 0.6, 0.45), Vector3(0.2, 0.85, -0.3),
			Vector3(-0.45, 0.4, -0.25), Vector3(0.05, 0.3, 0.52)]:
		b.box(p, Vector3(0.16, 0.16, 0.16), berry)


func _build_flowers(b: BlockMesh) -> void:
	var stem := Color(0.3, 0.6, 0.25)
	var petals := [Color(1.0, 0.85, 0.3), Color(0.95, 0.5, 0.75), Color(0.65, 0.55, 1.0)]
	var spots := [Vector3(0.0, 0, 0.0), Vector3(0.3, 0, 0.2), Vector3(-0.25, 0, 0.3), Vector3(0.15, 0, -0.3)]
	for k in spots.size():
		var p: Vector3 = spots[k]
		b.box(p + Vector3(0, 0.15, 0), Vector3(0.05, 0.3, 0.05), stem)
		b.box(p + Vector3(0, 0.33, 0), Vector3(0.16, 0.1, 0.16), petals[k % petals.size()])


func _build_grass_tuft(b: BlockMesh) -> void:
	var g := Color(0.36, 0.72, 0.3)
	b.box(Vector3(0, 0.15, 0), Vector3(0.08, 0.3, 0.08), g)
	b.box(Vector3(0.12, 0.11, 0.05), Vector3(0.07, 0.22, 0.07), g * 1.1)
	b.box(Vector3(-0.1, 0.12, -0.06), Vector3(0.07, 0.24, 0.07), g * 0.95)


func _build_stick_pile(b: BlockMesh) -> void:
	var wood := Color(0.55, 0.38, 0.22)
	b.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.08, 0.08), wood, Basis(Vector3.UP, 0.4))
	b.box(Vector3(0.05, 0.1, 0.05), Vector3(0.8, 0.08, 0.08), wood * 0.9, Basis(Vector3.UP, -0.6))


func _build_stone_pile(b: BlockMesh) -> void:
	var s := Color(0.6, 0.6, 0.64)
	b.box(Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.28), s)
	b.box(Vector3(0.22, 0.07, 0.15), Vector3(0.2, 0.14, 0.18), s * 0.9)
	b.box(Vector3(-0.18, 0.06, 0.12), Vector3(0.16, 0.12, 0.16), s * 1.05)
