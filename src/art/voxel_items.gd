class_name VoxelItems
extends RefCounted
## Milestone 39 ("Voxel Arsenal"): every held item - weapons, shields, wands,
## tomes - is a voxel model in the style of the owner's reference sheets
## (docs/ART_BIBLE.md section 6). Dropped weapons use the same models.
##
## The voxel data is made by art/tools/voxel_items/build.py and lives in
## voxel_item_data.gd. Nothing is loaded from model or texture files: the
## meshes are built here, once per (item, size, tint), and cached.
##
##     var mi := VoxelItems.make(&"sword", Color(0.88, 0.52, 0.3))  # a copper sword
##     $Hand.add_child(mi)        # grip at the origin, blade along +Y, front +Z
##
## Tints: "steel" voxels are recoloured by `metal` (the weapon's metal, see
## ItemIcons.metal_of); "accent"/"glow" voxels by `accent` (the item's icon colour).
## Thread-safe: townsfolk are built on worker threads (SettlementSite).

const DATA = preload("res://src/art/voxel_item_data.gd")

## Held items: 32 voxels per metre (exactly 2 voxels per world pixel, ART_BIBLE rule 1).
const HAND_VOXEL := 1.0 / 32.0
## The default weapon colour: this metal tint changes nothing.
const METAL_REF := Color(0.78, 0.8, 0.86)
const DEFAULT_ACCENT := Color(0.55, 0.36, 0.2)
## Darkening for inside corners (ambient occlusion baked into vertex colours).
const AO_CURVE := [0.5, 0.68, 0.85, 1.0]
const GLOW_STRENGTH := 1.4

const SHADER_CODE := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;
uniform float glow_strength = 1.4;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	float glow = 1.0 - COLOR.a;            // vertex alpha 0 = glowing voxel
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 col = COLOR.rgb;
	float strength = 1.0;
#else
	vec3 col = srgb_to_linear(COLOR.rgb);
	float strength = glow_strength;
#endif
	ALBEDO = col * (1.0 - glow);
	ROUGHNESS = 1.0;
	EMISSION = col * glow * strength;
}
"""

const _FACE_N := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const _AXIS := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
const _CORNERS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]

## Set false to fall back to the old box weapons (debugging).
static var enabled := true

static var _items: Dictionary = {}
static var _palette: Array = []
static var _emissive: Array = []
static var _tint: Array = []
static var _voxels: Dictionary = {}   # id -> PackedByteArray (decoded once)
static var _cache: Dictionary = {}
static var _material: ShaderMaterial = null
static var _mutex := Mutex.new()


static func has(id: StringName) -> bool:
	_load()
	return _items.has(String(id))


static func ids() -> Array:
	_load()
	return _items.keys()


## A MeshInstance3D: grip at the origin, the item pointing up (+Y), front +Z.
static func make(id: StringName, metal: Color = METAL_REF, accent: Color = DEFAULT_ACCENT, voxel_size: float = HAND_VOXEL) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = String(id)
	mi.mesh = get_mesh(id, metal, accent, voxel_size)
	return mi


static func get_mesh(id: StringName, metal: Color = METAL_REF, accent: Color = DEFAULT_ACCENT, voxel_size: float = HAND_VOXEL) -> ArrayMesh:
	_mutex.lock()
	var m := _get_mesh_locked(String(id), metal, accent, voxel_size)
	_mutex.unlock()
	return m


## The item's length along its long axis in metres (for the swing-trail tip).
static func reach(id: StringName, voxel_size: float = HAND_VOXEL) -> float:
	_load()
	var item: Dictionary = _items.get(String(id), {})
	if item.is_empty():
		return 0.0
	var s: Vector3i = item["size"]
	var a: Vector3 = item["anchor"]
	return (float(s.z) - a.z) * voxel_size


static func material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER_CODE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter(&"glow_strength", GLOW_STRENGTH)
		_material = m
	return _material


# ---------------------------------------------------------------- building

static func _load() -> void:
	if not _items.is_empty():
		return
	_mutex.lock()
	if _items.is_empty():
		_palette = DATA.palette()
		_emissive = DATA.emissive()
		_tint = DATA.tint_groups()
		_items = DATA.items()
	_mutex.unlock()


static func _get_mesh_locked(id: String, metal: Color, accent: Color, vs: float) -> ArrayMesh:
	if _items.is_empty():
		_palette = DATA.palette()
		_emissive = DATA.emissive()
		_tint = DATA.tint_groups()
		_items = DATA.items()
	if not _items.has(id):
		push_error("VoxelItems: unknown item '%s'" % id)
		return null
	var key := "%s|%.4f|%s|%s" % [id, vs, metal.to_html(false), accent.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	if not _voxels.has(id):
		_voxels[id] = _decode(_items[id])
	var mesh := _build(_items[id], _voxels[id], vs, _tinted_palette(metal, accent))
	_cache[key] = mesh
	return mesh


static func _tinted_palette(metal: Color, accent: Color) -> Array:
	var out: Array = []
	out.resize(_palette.size())
	var mf := Vector3(metal.r / METAL_REF.r, metal.g / METAL_REF.g, metal.b / METAL_REF.b)
	for i in _palette.size():
		var c: Color = _palette[i]
		match int(_tint[i]):
			1:
				c = Color(minf(c.r * mf.x, 1.0), minf(c.g * mf.y, 1.0), minf(c.b * mf.z, 1.0))
			2:
				c = Color(minf(c.r * accent.r * 1.3, 1.0), minf(c.g * accent.g * 1.3, 1.0), minf(c.b * accent.b * 1.3, 1.0))
		out[i] = c
	return out


static func _decode(item: Dictionary) -> PackedByteArray:
	var s: Vector3i = item["size"]
	var raw: PackedByteArray = Marshalls.base64_to_raw(item["rle"])
	var out := PackedByteArray()
	out.resize(s.x * s.y * s.z)
	var p := 0
	var i := 0
	while i + 1 < raw.size():
		var n: int = raw[i]
		var c: int = raw[i + 1]
		if c != 0:
			for k in n:
				out[p + k] = c
		p += n
		i += 2
	return out


static func _solid(g: PackedByteArray, s: Vector3i, x: int, y: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0 or x >= s.x or y >= s.y or z >= s.z:
		return false
	return g[x + s.x * (y + s.y * z)] != 0


static func _build(item: Dictionary, g: PackedByteArray, vs: float, pal: Array) -> ArrayMesh:
	var s: Vector3i = item["size"]
	var a: Vector3 = item["anchor"]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var tris := PackedInt32Array()
	for z in s.z:
		for y in s.y:
			for x in s.x:
				var c: int = g[x + s.x * (y + s.y * z)]
				if c == 0:
					continue
				var base: Color = pal[c]
				var glow: bool = int(_emissive[c]) == 1
				for f in 6:
					var n: Vector3i = _FACE_N[f]
					if _solid(g, s, x + n.x, y + n.y, z + n.z):
						continue
					_add_face(g, s, a, vs, Vector3i(x, y, z), f, base, glow, verts, norms, cols, tris)
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = tris
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


## Voxel space (x right, y back, z up) -> Godot (X right, Y up, Z front).
static func _to_godot(p: Vector3, a: Vector3, vs: float) -> Vector3:
	return Vector3(p.x - a.x, p.z - a.z, -(p.y - a.y)) * vs


static func _add_face(g: PackedByteArray, s: Vector3i, a: Vector3, vs: float, v: Vector3i, f: int,
		base: Color, glow: bool, verts: PackedVector3Array, norms: PackedVector3Array,
		cols: PackedColorArray, tris: PackedInt32Array) -> void:
	var ax: int = f / 2
	var n: Vector3i = _FACE_N[f]
	var eb: Vector3i = _AXIS[(ax + 1) % 3]
	var ec: Vector3i = _AXIS[(ax + 2) % 3]
	var front: Vector3i = v + n
	var ng := Vector3(n.x, n.z, -n.y)
	var start := verts.size()
	var ao: Array[int] = []
	var origin := Vector3(v)
	if f % 2 == 0:
		var ea: Vector3i = _AXIS[ax]
		origin += Vector3(ea)
	for corner: Vector2i in _CORNERS:
		var db: Vector3i = eb * (corner.x * 2 - 1)
		var dc: Vector3i = ec * (corner.y * 2 - 1)
		var s1 := _solid(g, s, front.x + db.x, front.y + db.y, front.z + db.z)
		var s2 := _solid(g, s, front.x + dc.x, front.y + dc.y, front.z + dc.z)
		var sc := _solid(g, s, front.x + db.x + dc.x, front.y + db.y + dc.y, front.z + db.z + dc.z)
		var level := 0
		if not (s1 and s2):
			level = 3 - int(s1) - int(s2) - int(sc)
		ao.append(level)
		verts.append(_to_godot(origin + Vector3(eb) * corner.x + Vector3(ec) * corner.y, a, vs))
		norms.append(ng)
		if glow:
			cols.append(Color(base.r, base.g, base.b, 0.0))
		else:
			var k: float = AO_CURVE[level]
			cols.append(Color(base.r * k, base.g * k, base.b * k, 1.0))
	var p0: Vector3 = verts[start]
	var flip := (verts[start + 1] - p0).cross(verts[start + 2] - p0).dot(ng) > 0.0
	var order: Array = [0, 1, 2, 0, 2, 3] if ao[0] + ao[2] > ao[1] + ao[3] else [1, 2, 3, 1, 3, 0]
	for t in 2:
		var i0: int = order[t * 3]
		var i1: int = order[t * 3 + 1]
		var i2: int = order[t * 3 + 2]
		tris.append(start + i0)
		if flip:
			tris.append(start + i2)
			tris.append(start + i1)
		else:
			tris.append(start + i1)
			tris.append(start + i2)


## The voxel model for an item (dropped loot, previews): {"id", "accent"}, or {} if none.
static func model_for_item(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	var id: StringName = &""
	var accent := item.icon_color
	var specials := [&"prismheart_blade", &"sporecrown_staff", &"gilded_greatsword", &"gilded_halberd", &"starlance"]
	if item.id in specials:
		id = item.id
	else:
		match item.weapon_type:
			&"sword", &"axe", &"dagger", &"greatsword", &"hoe", &"bow", &"wand":
				id = item.weapon_type
			&"staff":
				id = &"staff"
				accent = item.icon_color.lightened(0.2)
			&"hammer":
				id = &"warhammer"
			&"spear":
				id = &"halberd" if String(item.id).contains("halberd") else &"spear"
			&"tome":
				id = &"tome"
			&"shield":
				id = {&"buckler": &"buckler", &"kite": &"kite_shield", &"gilded_kite": &"gilded_kite", &"aegis": &"aegis"}.get(item.outfit_look, &"shield_round")
	if id == &"" or not has(id):
		return {}
	return {"id": id, "accent": accent}


## A mesh of the item about `longest` metres long (its pivot stays at the grip).
static func item_mesh(item: ItemData, longest: float = 0.6) -> ArrayMesh:
	var m := model_for_item(item)
	if m.is_empty():
		return null
	_load()
	var s: Vector3i = _items[String(m["id"])]["size"]
	# Books and shields lie flat and look big; keep them smaller than weapons.
	var k := 0.6 if m["id"] == &"tome" else (0.8 if String(item.weapon_type) == "shield" else 1.0)
	var vs := longest * k / float(maxi(s.x, maxi(s.y, s.z)))
	return get_mesh(m["id"], ItemIcons.metal_of(item), m["accent"], vs)
