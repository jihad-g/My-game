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
##
## v0.26.0 block textures: set `texture` to a BlockTextures name before adding
## boxes (`b.texture = &"bark"`); those faces get UVs in metres (16 texels per
## metre, docs/ART_BIBLE.md) and the texture layer in UV2. card() adds small
## plants as two crossed cut-out cards (a second surface, sprite material).

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
## Applied to every box added (lets one BlockMesh collect many placed pieces;
## used for merging settlement buildings on a worker thread).
var xform := Transform3D.IDENTITY
## Texture for the boxes added next (a BlockTextures.LAYER name; &"" = plain colour).
var texture: StringName = &""

var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _textured := false
# Plant cards (second surface).
var _c_verts := PackedVector3Array()
var _c_normals := PackedVector3Array()
var _c_colors := PackedColorArray()
var _c_uvs := PackedVector2Array()
var _c_uv2s := PackedVector2Array()
var _c_indices := PackedInt32Array()

## Top faces are brightened and bottom faces darkened slightly for a stylized,
## readable look even under flat lighting.
const TOP_TINT := 1.08
const SIDE_TINT := 0.92
const BOTTOM_TINT := 0.7


## Adds an axis-aligned box. `basis` optionally rotates/skews it around `center`.
func box(center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> BlockMesh:
	var local_center := center
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
	var meta := _meta()
	var lc := []  # unrotated corner positions, for texture coordinates (metres)
	if meta != Vector2.ZERO:
		for c in corners:
			lc.append(local_center + c)
	for i in corners.size():
		corners[i] = center + basis * corners[i]
	# face: 4 corner indices + normal
	_face(corners[4], corners[5], corners[6], corners[7], basis * Vector3.BACK, color * SIDE_TINT, _uv_side(lc, [4, 5, 6, 7], false), meta)
	_face(corners[1], corners[0], corners[3], corners[2], basis * Vector3.FORWARD, color * SIDE_TINT, _uv_side(lc, [1, 0, 3, 2], false), meta)
	_face(corners[5], corners[1], corners[2], corners[6], basis * Vector3.RIGHT, color, _uv_side(lc, [5, 1, 2, 6], true), meta)
	_face(corners[0], corners[4], corners[7], corners[3], basis * Vector3.LEFT, color * SIDE_TINT, _uv_side(lc, [0, 4, 7, 3], true), meta)
	_face(corners[7], corners[6], corners[2], corners[3], basis * Vector3.UP, color * TOP_TINT, _uv_top(lc, [7, 6, 2, 3]), meta)
	_face(corners[0], corners[1], corners[5], corners[4], basis * Vector3.DOWN, color * BOTTOM_TINT, _uv_top(lc, [0, 1, 5, 4]), meta)
	return self


## UV2 for the current `texture`: (layer + 1, -1 for full colour / 0 tinted); ZERO = untextured.
func _meta() -> Vector2:
	if texture == &"":
		return Vector2.ZERO
	var layer: int = BlockTextures.LAYER.get(texture, -1)
	if layer < 0:
		return Vector2.ZERO
	return Vector2(layer + 1, -1.0 if BlockTextures.FULL.has(texture) else 0.0)


static func _uv_side(lc: Array, idx: Array, along_z: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	if lc.is_empty():
		return out
	for i: int in idx:
		var p: Vector3 = lc[i]
		out.append(Vector2(p.z if along_z else p.x, -p.y))
	return out


static func _uv_top(lc: Array, idx: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if lc.is_empty():
		return out
	for i: int in idx:
		var p: Vector3 = lc[i]
		out.append(Vector2(p.x, p.z))
	return out


## v0.26.0: a small plant as two crossed vertical cards (`width` x `height`
## metres, bottom centre at `base`) showing the cut-out sprite `sprite`
## (a BlockTextures name). `tint` multiplies it (grass tufts take the grass colour).
func card(base: Vector3, sprite: StringName, width: float = 1.0, height: float = 1.0,
		tint: Color = Color.WHITE, angle: float = 0.0) -> BlockMesh:
	var layer: int = BlockTextures.LAYER.get(sprite, -1)
	if layer < 0:
		return self
	var meta := Vector2(layer + 1, -1.0 if BlockTextures.FULL.has(sprite) else 0.0)
	tint.a = 1.0
	for k in 2:
		var dir := Vector3(cos(angle + k * PI * 0.5), 0.0, sin(angle + k * PI * 0.5)) * (width * 0.5)
		var pts := [base - dir + Vector3(0, height, 0), base + dir + Vector3(0, height, 0), base + dir, base - dir]
		if xform != Transform3D.IDENTITY:
			for i in 4:
				pts[i] = xform * pts[i]
		var i0 := _c_verts.size()
		_c_verts.append_array(pts)
		var n := Vector3.UP
		_c_normals.append_array([n, n, n, n])
		_c_colors.append_array([tint, tint, tint, tint])
		_c_uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		_c_uv2s.append_array([meta, meta, meta, meta])
		_c_indices.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])
	return self


## Adds a quad (a, b, c, d in order around the perimeter). Winding is fixed up
## automatically so the face is visible from the `normal` side.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> BlockMesh:
	_face(a, b, c, d, normal, color)
	return self


func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color,
		uvs: PackedVector2Array = PackedVector2Array(), meta: Vector2 = Vector2.ZERO) -> void:
	color.a = 1.0
	var base := _verts.size()
	_verts.append_array([a, b, c, d])
	_normals.append_array([normal, normal, normal, normal])
	_colors.append_array([color, color, color, color])
	if uvs.size() == 4:
		_uvs.append_array(uvs)
	else:
		_uvs.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	_uv2s.append_array([meta, meta, meta, meta])
	if meta != Vector2.ZERO:
		_textured = true
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
	return _verts.is_empty() and _c_verts.is_empty()


## True if there are boxes (the first surface); cards alone don't count.
func has_boxes() -> bool:
	return not _verts.is_empty()


## Surface arrays of the plant cards ([] if none), for merged meshes that
## draw them with Materials.sprite().
func card_arrays() -> Array:
	if _c_verts.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _c_verts
	arrays[Mesh.ARRAY_NORMAL] = _c_normals
	arrays[Mesh.ARRAY_COLOR] = _c_colors
	arrays[Mesh.ARRAY_TEX_UV] = _c_uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _c_uv2s
	arrays[Mesh.ARRAY_INDEX] = _c_indices
	return arrays


## True if any box face has a block texture.
func is_textured() -> bool:
	return _textured


## Raw surface arrays (no engine resources: safe on worker threads).
## Plant cards are not included (use commit() for meshes with cards).
func to_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	if _textured:
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	arrays[Mesh.ARRAY_INDEX] = _indices
	return arrays


## Builds the mesh: surface 0 = boxes (vertex_color material), then the plant
## cards (sprite material) if any. The card surface index is stored in the
## mesh meta "card_surface" (-1 when there are none).
func commit(existing: ArrayMesh = null) -> ArrayMesh:
	var mesh := existing if existing else ArrayMesh.new()
	if not _verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, to_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, Materials.vertex_color())
	var card_surface := -1
	if not _c_verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, card_arrays())
		card_surface = mesh.get_surface_count() - 1
		mesh.surface_set_material(card_surface, Materials.sprite(0.0))
	mesh.set_meta(&"card_surface", card_surface)
	return mesh
