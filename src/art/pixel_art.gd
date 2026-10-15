class_name PixelArt
extends RefCounted
## Pixel-art models (art pass, v0.29 pilot): boxes whose six faces are exact
## pixel images, 16 pixels per metre (docs/ART_BIBLE.md rule 1), in one
## nearest-filtered atlas with alpha cut-outs (gaps between ribs, ragged hems)
## and a glow layer (eyes, lamps).
##
## Usage:
##   var pa := PixelArt.new()
##   var skin := PixelArt.paint(Vector3i(8, 7, 8), PixelArt.BONE, 1, {PixelArt.FRONT: [...]}, key)
##   pa.add(&"_head", Vector3(0, 0.3, 0), Vector3i(8, 7, 8), skin)
##   var built := pa.build()   # {"parts": [[pivot, pos, mesh], ...]}
##
## Face images are seen from outside the box. Side faces: image up = +Y.
## FRONT: left = -X. BACK: left = +X. RIGHT: left = +Z. LEFT: left = -Z.
## TOP: image top = -Z (the far edge), left = -X. BOTTOM: image top = +Z.

const PX := 1.0 / 16.0
enum { FRONT, BACK, RIGHT, LEFT, TOP, BOTTOM }
const CLEAR := Color(0, 0, 0, 0)
const NORMALS := [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]
## Corner signs (TL, TR, BR, BL) per face, times the half size.
const CORNERS := [
	[Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
	[Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1), Vector3(1, -1, -1)],
	[Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1)],
	[Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)],
	[Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
	[Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)],
]

# Colour ramps, darkest to brightest. Shades lean cool, lights lean warm.
const BONE := [Color("5e4c45"), Color("9c8466"), Color("cbb98d"), Color("e9ddb2"), Color("fbf4d9")]
const CRIMSON := [Color("33102a"), Color("5a1638"), Color("80204a"), Color("a42e5a"), Color("c64a72")]
const LEATHER := [Color("231215"), Color("44221c"), Color("663324"), Color("874832"), Color("a66242")]
const IRON := [Color("262a38"), Color("454d61"), Color("6c788d"), Color("9fabbd"), Color("d5dde8")]
const GLOW := [Color("8a2a10"), Color("e0601a"), Color("ff9a2a"), Color("ffc85a"), Color("fff0b0")]

var _parts: Array = []  # [pivot, pos, size, faces(6 Images), glows(6 Images or null)]


func add(pivot: StringName, pos: Vector3, size: Vector3i, skin: Array) -> void:
	_parts.append([pivot, pos, size, skin[0], skin[1]])


static func face_size(size: Vector3i, f: int) -> Vector2i:
	match f:
		FRONT, BACK:
			return Vector2i(size.x, size.y)
		RIGHT, LEFT:
			return Vector2i(size.z, size.y)
		_:
			return Vector2i(size.x, size.z)


## Paints the six faces of a box: a shaded fill (light from the top-left) plus
## `stamps` {face: PackedStringArray rows} drawn with `key` {char: Color or
## [Color, true] for glow}. "." keeps the fill, "_" cuts a hole.
## Returns [faces, glows].
static func paint(size: Vector3i, ramp: Array, seed: int, stamps := {}, key := {}, speckle := 0.07) -> Array:
	var faces: Array = []
	var glows: Array = []
	for f in 6:
		var fs := face_size(size, f)
		var img := Image.create(fs.x, fs.y, false, Image.FORMAT_RGBA8)
		for y in fs.y:
			for x in fs.x:
				img.set_pixel(x, y, ramp[_shade_index(f, x, y, fs, seed, speckle)])
		var glow: Image = null
		if stamps.has(f):
			glow = _stamp(img, stamps[f], key, ramp)
		faces.append(img)
		glows.append(glow)
	return [faces, glows]


static func _shade_index(f: int, x: int, y: int, fs: Vector2i, seed: int, speckle: float) -> int:
	var i := 2
	if f == TOP:
		i = 4 if (x == 0 or y == 0) and fs.x > 1 and fs.y > 1 else 3
	elif f == BOTTOM:
		return 1
	else:
		if y == 0:
			i = 3
		elif y == fs.y - 1 and fs.y > 2:
			i = 1
		if fs.x > 2 and x == 0 and y > 0:
			i += 1
		elif fs.x > 2 and x == fs.x - 1:
			i -= 1
	var u := HashUtils.to_unit(HashUtils.hash3(x + f * 37, y, seed), 0)
	if u < speckle:
		i -= 1
	elif u > 1.0 - speckle * 0.6:
		i += 1
	return clampi(i, 0, 4)


## Digits 0-4 pick from the part's own ramp; other chars come from `key`.
static func _stamp(img: Image, rows: PackedStringArray, key: Dictionary, ramp: Array) -> Image:
	var glow: Image = null
	for y in mini(rows.size(), img.get_height()):
		var row: String = rows[y]
		for x in mini(row.length(), img.get_width()):
			var ch := row[x]
			if ch == ".":
				continue
			if ch == "_":
				img.set_pixel(x, y, CLEAR)
			elif ch >= "0" and ch <= "4":
				img.set_pixel(x, y, ramp[int(ch)])
			elif key.has(ch):
				var v = key[ch]
				if v is Array:
					img.set_pixel(x, y, v[0])
					if glow == null:
						glow = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
						glow.fill(Color.BLACK)
					glow.set_pixel(x, y, v[0])
				else:
					img.set_pixel(x, y, v)
	return glow


## Packs every face into one atlas and makes one mesh per part.
func build() -> Dictionary:
	var rects: Array = []  # per part, per face: Rect2i in the atlas
	var items: Array = []
	for pi in _parts.size():
		for f in 6:
			var img: Image = _parts[pi][3][f]
			items.append([pi, f, img.get_width(), img.get_height()])
		rects.append([null, null, null, null, null, null])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3])
	# Shelf packing with a 1 px border around each face.
	var width := 128
	var x := 0
	var y := 0
	var shelf := 0
	for it in items:
		var w: int = it[2] + 2
		var h: int = it[3] + 2
		if x + w > width:
			x = 0
			y += shelf
			shelf = 0
		rects[it[0]][it[1]] = Rect2i(x + 1, y + 1, it[2], it[3])
		x += w
		shelf = maxi(shelf, h)
	var height := 1
	while height < y + shelf:
		height *= 2
	var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var glow := Image.create(width, height, false, Image.FORMAT_RGBA8)
	atlas.fill(CLEAR)
	glow.fill(Color.BLACK)
	var any_glow := false
	for pi in _parts.size():
		for f in 6:
			var r: Rect2i = rects[pi][f]
			_blit_padded(atlas, _parts[pi][3][f], r)
			var g: Image = _parts[pi][4][f]
			if g:
				any_glow = true
				glow.blit_rect(g, Rect2i(Vector2i.ZERO, r.size), r.position)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(atlas)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.92
	if any_glow:
		mat.emission_enabled = true
		mat.emission_texture = ImageTexture.create_from_image(glow)
		mat.emission = Color.WHITE
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier = 2.2
	var out: Array = []
	var tex_size := Vector2(width, height)
	for pi in _parts.size():
		var size: Vector3i = _parts[pi][2]
		var half := Vector3(size) * PX * 0.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in 6:
			var r: Rect2i = rects[pi][f]
			var uv0 := Vector2(r.position) / tex_size
			var uv1 := Vector2(r.end) / tex_size
			var uvs := [uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]
			var c: Array = CORNERS[f]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(NORMALS[f])
				st.set_uv(uvs[k])
				st.add_vertex(c[k] * half)
		st.set_material(mat)
		out.append([_parts[pi][0], _parts[pi][1], st.commit()])
	return {"parts": out, "material": mat, "atlas": atlas}


## Copies `img` into `r` and repeats its edge pixels into the 1 px border, so
## the nearest filter never picks a neighbour's colour at a face edge.
static func _blit_padded(atlas: Image, img: Image, r: Rect2i) -> void:
	atlas.blit_rect(img, Rect2i(Vector2i.ZERO, r.size), r.position)
	var w := r.size.x
	var h := r.size.y
	for x in w:
		atlas.set_pixel(r.position.x + x, r.position.y - 1, img.get_pixel(x, 0))
		atlas.set_pixel(r.position.x + x, r.end.y, img.get_pixel(x, h - 1))
	for y in range(-1, h + 1):
		var sy := clampi(y, 0, h - 1)
		atlas.set_pixel(r.position.x - 1, r.position.y + y, img.get_pixel(0, sy))
		atlas.set_pixel(r.end.x, r.position.y + y, img.get_pixel(w - 1, sy))
