class_name PixelAuto
extends RefCounted
## Milestone 21 ("Pixel World"): the pixel style is the standard for every model.
##
## Every box a character, monster, animal or weapon is built from (the `_part`
## helpers of HumanoidModel, BeastModel and BoarModel) gets painted faces,
## 16 pixels per metre like the hand-drawn models in src/art/:
##   - a 5-shade ramp made from the part's colour (shades lean cool, lights warm);
##   - light on the top and left edges, shade on the bottom and right (light from
##     the top-left, docs/ART_BIBLE.md rule 4);
##   - a pattern picked from the colour: metal gets a diagonal sheen, wood a
##     grain, cloth and skin a few soft patches.
## Faces are packed into shared 512 x 512 atlas pages (one material per page),
## and meshes are cached by size and colour, so 30 skeletons cost one mesh each.

const PAGE := 512
const PX_PER_M := 16.0
const MAX_FACE := 48

## Set false to fall back to the old flat-colour boxes (tests, debugging).
static var enabled := true

static var _pages: Array = []  # [{img, glow, tex, gtex, mat, x, y, shelf}]
static var _cache: Dictionary = {}
static var _dirty: Array = []


## A box mesh `size` (metres, centred) painted from `color`. `glow` parts shine.
static func mesh(size: Vector3, color: Color, glow := false) -> Mesh:
	var px := Vector3i(_px(size.x), _px(size.y), _px(size.z))
	color.a = 1.0
	var key := "%d,%d,%d,%s,%d|%.3f,%.3f,%.3f" % [px.x, px.y, px.z, color.to_html(false), int(glow), size.x, size.y, size.z]
	if _cache.has(key):
		return _cache[key]
	var ramp := ramp_for(color)
	var kind := kind_for(color, size)
	var seed := hash(key) & 0xffff
	var faces: Array = []
	for f in 6:
		faces.append(paint_face(PixelArt.face_size(px, f), f, ramp, kind, seed))
	var placed := _place(faces, glow)
	var page: Dictionary = placed[0]
	var rects: Array = placed[1]
	var half := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := 1.0 / float(PAGE)
	for f in 6:
		var r: Rect2i = rects[f]
		var uv0 := Vector2(r.position) * inv
		var uv1 := Vector2(r.end) * inv
		var uvs := [uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]
		var c: Array = PixelArt.CORNERS[f]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(PixelArt.NORMALS[f])
			st.set_uv(uvs[k])
			st.add_vertex(c[k] * half)
	st.set_material(page.mat)
	var m := st.commit()
	_cache[key] = m
	return m


static func _px(m: float) -> int:
	return clampi(roundi(absf(m) * PX_PER_M), 1, MAX_FACE)


## Five shades from dark to light around `c`: shades shift toward blue-violet,
## lights toward warm yellow.
static func ramp_for(c: Color) -> Array:
	return [_shift(c, -0.48), _shift(c, -0.24), c, _shift(c, 0.14), _shift(c, 0.3)]


static func _shift(c: Color, amt: float) -> Color:
	var target := 0.7 if amt < 0.0 else 0.13
	var dh := wrapf(target - c.h, -0.5, 0.5)
	var h := fposmod(c.h + dh * absf(amt) * 0.14, 1.0)
	var s := clampf(c.s * (1.0 + (0.18 if amt < 0.0 else -0.35) * absf(amt)), 0.0, 1.0)
	var v := clampf(c.v * (1.0 + amt), 0.0, 1.0)
	if amt > 0.0 and c.v > 0.85:
		s = clampf(s - amt * 0.3, 0.0, 1.0)  # very bright colours get lighter by losing colour
	return Color.from_hsv(h, s, v, 1.0)


## &"metal", &"wood" or &"cloth" from the colour and shape: only long thin
## brown parts (handles, shafts, bows) get wood grain, so brown shirts stay cloth.
static func kind_for(c: Color, size := Vector3.ONE) -> StringName:
	if c.s < 0.12 and c.v > 0.5:
		return &"metal"
	var dims := [absf(size.x), absf(size.y), absf(size.z)]
	dims.sort()
	var thin: bool = dims[2] >= dims[1] * 3.0
	if thin and c.h > 0.03 and c.h < 0.13 and c.s > 0.3 and c.v < 0.7:
		return &"wood"
	return &"cloth"


static func paint_face(fs: Vector2i, f: int, ramp: Array, kind: StringName, seed: int) -> Image:
	var img := Image.create(fs.x, fs.y, false, Image.FORMAT_RGBA8)
	var tiny := fs.x <= 2 and fs.y <= 2
	for y in fs.y:
		for x in fs.x:
			var i := 2
			if tiny:
				i = 3 if f == PixelArt.TOP else (1 if f == PixelArt.BOTTOM else 2)
			else:
				i = _index(f, x, y, fs, kind, seed)
			img.set_pixel(x, y, ramp[i])
	return img


static func _index(f: int, x: int, y: int, fs: Vector2i, kind: StringName, seed: int) -> int:
	var i := 2
	var side := f != PixelArt.TOP and f != PixelArt.BOTTOM
	if f == PixelArt.TOP:
		i = 4 if (x == 0 or y == 0) and fs.x > 2 and fs.y > 2 else 3
	elif f == PixelArt.BOTTOM:
		i = 1
	else:
		if y == 0:
			i = 3
		elif y == fs.y - 1 and fs.y > 2:
			i = 1
		if fs.x > 2 and x == 0 and y > 0:
			i += 1
		elif fs.x > 2 and x == fs.x - 1:
			i -= 1
	var u := HashUtils.to_unit(HashUtils.hash3(x + f * 31, y, seed), 0)
	match kind:
		&"metal":
			if side and fs.x > 2 and fs.y > 2 and (x + y) % 7 == 3:
				i += 1
			elif u < 0.04:
				i -= 1
		&"wood":
			var along_y := fs.y >= fs.x
			var line := HashUtils.to_unit(HashUtils.hash3((x if along_y else y) + f * 7, ((y if along_y else x)) / 4, seed + 5), 1)
			if line < 0.28 and fs.x > 1 and fs.y > 1:
				i -= 1
		_:
			var patch := HashUtils.to_unit(HashUtils.hash3(x / 2 + f * 13, y / 2, seed + 9), 2)
			if patch < 0.12 and fs.x > 2 and fs.y > 2:
				i -= 1
			elif u > 0.975:
				i += 1
	return clampi(i, 0, 4)


# --- Atlas pages -------------------------------------------------------------------

static func _place(faces: Array, glow: bool) -> Array:
	var page: Dictionary = _pages[-1] if not _pages.is_empty() else _new_page()
	var rects: Array = _pack(page, faces)
	if rects.is_empty():
		page = _new_page()
		rects = _pack(page, faces)
	for f in 6:
		var r: Rect2i = rects[f]
		PixelArt._blit_padded(page.img, faces[f], r)
		if glow:
			page.glow.blit_rect(faces[f], Rect2i(Vector2i.ZERO, r.size), r.position)
	if not _dirty.has(int(page.id)):
		_dirty.append(int(page.id))
		if _dirty.size() == 1:
			var loop := Engine.get_main_loop()
			if loop:
				(loop as SceneTree).process_frame.connect(flush, CONNECT_ONE_SHOT)
	return [page, rects]


## Shelf packing with a 1 px border; [] when the page is full.
static func _pack(page: Dictionary, faces: Array) -> Array:
	var x: int = page.x
	var y: int = page.y
	var shelf: int = page.shelf
	var out: Array = []
	for img: Image in faces:
		var w := img.get_width() + 2
		var h := img.get_height() + 2
		if x + w > PAGE:
			x = 0
			y += shelf
			shelf = 0
		if y + h > PAGE:
			return []
		out.append(Rect2i(x + 1, y + 1, img.get_width(), img.get_height()))
		x += w
		shelf = maxi(shelf, h)
	page.x = x
	page.y = y
	page.shelf = shelf
	return out


static func _new_page() -> Dictionary:
	var img := Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	var glow := Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
	glow.fill(Color.BLACK)
	var tex := ImageTexture.create_from_image(img)
	var gtex := ImageTexture.create_from_image(glow)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.roughness = 0.95
	mat.metallic_specular = 0.2
	mat.emission_enabled = true
	mat.emission_texture = gtex
	mat.emission = Color.WHITE
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_energy_multiplier = 2.0
	var page := {"id": _pages.size(), "img": img, "glow": glow, "tex": tex, "gtex": gtex, "mat": mat, "x": 0, "y": 0, "shelf": 0}
	_pages.append(page)
	return page


## Uploads the pages that changed (once per frame; also called by tests).
static func flush() -> void:
	for id: int in _dirty:
		var page: Dictionary = _pages[id]
		(page.tex as ImageTexture).update(page.img)
		(page.gtex as ImageTexture).update(page.glow)
	_dirty.clear()


static func page_count() -> int:
	return _pages.size()


static func cached_count() -> int:
	return _cache.size()
