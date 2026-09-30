class_name BlockMesh
extends RefCounted
## Builds flat-shaded, vertex-coloured meshes out of boxes.
##
## This is the core of the blocky/voxel-inspired art style: characters, trees,
## rocks and props are all composed from coloured boxes merged into one mesh
## (one draw call per mesh).
##
## Usage:
##   var b := BlockMesh.new()
##   b.box(Vector3(0, 0.5, 0), Vector3(1, 1, 1), Color.RED)
##   mesh_instance.mesh = b.commit()

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
## Applied to every box added (lets one BlockMesh collect many placed pieces;
## used for merging settlement buildings on a worker thread).
var xform := Transform3D.IDENTITY

## Top faces are brightened and bottom faces darkened slightly for a stylized,
## readable look even under flat lighting.
const TOP_TINT := 1.08
const SIDE_TINT := 0.92
const BOTTOM_TINT := 0.7


## Adds an axis-aligned box. `basis` optionally rotates/skews it around `center`.
func box(center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> BlockMesh:
	if xform != Transform3D.IDENTITY:
		center = xform * center
		basis = xform.basis * basis
	var h := size * 0.5
	var corners := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in corners.size():
		corners[i] = center + basis * corners[i]
	# face: 4 corner indices + normal
	_face(corners[4], corners[5], corners[6], corners[7], basis * Vector3.BACK, color * SIDE_TINT)
	_face(corners[1], corners[0], corners[3], corners[2], basis * Vector3.FORWARD, color * SIDE_TINT)
	_face(corners[5], corners[1], corners[2], corners[6], basis * Vector3.RIGHT, color)
	_face(corners[0], corners[4], corners[7], corners[3], basis * Vector3.LEFT, color * SIDE_TINT)
	_face(corners[7], corners[6], corners[2], corners[3], basis * Vector3.UP, color * TOP_TINT)
	_face(corners[0], corners[1], corners[5], corners[4], basis * Vector3.DOWN, color * BOTTOM_TINT)
	return self


## Adds a quad (a, b, c, d in order around the perimeter). Winding is fixed up
## automatically so the face is visible from the `normal` side.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> BlockMesh:
	_face(a, b, c, d, normal, color)
	return self


func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	color.a = 1.0
	var base := _verts.size()
	_verts.append_array([a, b, c, d])
	_normals.append_array([normal, normal, normal, normal])
	_colors.append_array([color, color, color, color])
	append_quad_indices(_indices, base, a, b, c, normal)


## Godot treats clockwise triangles (as seen by the viewer) as front faces.
## Picks the index order that makes the quad face `normal`.
static func append_quad_indices(indices: PackedInt32Array, base: int, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var ccw := (b - a).cross(c - a).dot(normal) > 0.0
	if ccw:
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	else:
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func is_empty() -> bool:
	return _verts.is_empty()


## Raw surface arrays (no engine resources: safe on worker threads).
func to_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	return arrays


func commit(existing: ArrayMesh = null) -> ArrayMesh:
	var mesh := existing if existing else ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, Materials.vertex_color())
	return mesh
