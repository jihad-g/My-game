class_name Materials
## Shared material cache. Sharing materials keeps draw-call batching effective.

static var _cache: Dictionary = {}


## Flat, vertex-coloured, matte material used by all blocky meshes.
## v0.26.0: a ShaderMaterial (assets/shaders/blocky.gdshader) that adds the
## pixel-art block textures to meshes that carry UV2 data (terrain, props,
## building pieces). Meshes without UV2 (characters, effects) look as before.
static func vertex_color() -> Material:
	if not _cache.has(&"vertex_color"):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/blocky.gdshader")
		m.set_shader_parameter(&"block_tex", block_texture_array())
		_cache[&"vertex_color"] = m
	return _cache[&"vertex_color"]


## Vertex-colour material that fades out near the camera, so tall props
## (walls, big rocks) between the camera and the player don't hide the action.
## CameraRig updates the fade distances every frame via set_camera_fade().
## Milestone 18 art pass: a soft see-through fade (no grainy pixel dither);
## the depth pre-pass keeps far objects drawn like normal solid blocks.
## v0.26.0: textured (assets/shaders/blocky_fade.gdshader).
static func vertex_color_occluder() -> Material:
	if not _cache.has(&"vertex_color_occluder"):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/blocky_fade.gdshader")
		m.set_shader_parameter(&"block_tex", block_texture_array())
		m.set_shader_parameter(&"fade_min", 6.0)
		m.set_shader_parameter(&"fade_max", 11.0)
		_cache[&"vertex_color_occluder"] = m
	return _cache[&"vertex_color_occluder"]


## v0.26.0: the block textures as one Texture2DArray (one 16 x 16 pixel-art
## texture per layer, layer numbers in BlockTextures). Built once from the
## strip assets/textures/block_textures.png, with mipmaps made per layer so
## textures never bleed into each other. Null if the image is missing.
static func block_texture_array() -> Texture2DArray:
	if _cache.has(&"block_texture_array"):
		return _cache[&"block_texture_array"]
	var arr: Texture2DArray = null
	var tex := load(BlockTextures.ARRAY_PATH) as Texture2D
	var strip: Image = tex.get_image() if tex else null
	if strip and not strip.is_empty():
		if strip.is_compressed():
			strip.decompress()
		strip.convert(Image.FORMAT_RGBA8)
		var size := BlockTextures.SIZE
		var layers: Array[Image] = []
		for k in mini(BlockTextures.COUNT, strip.get_height() / size):
			var img := strip.get_region(Rect2i(0, k * size, size, size))
			img.generate_mipmaps()
			layers.append(img)
		if not layers.is_empty():
			arr = Texture2DArray.new()
			if arr.create_from_images(layers) != OK:
				arr = null
	else:
		push_warning("Materials: block textures not found (%s)" % BlockTextures.ARRAY_PATH)
	_cache[&"block_texture_array"] = arr
	return arr


## v0.26.0 Settings "Block textures": on = pixel-art textures, off = plain colours (the old look).
static func set_block_textures(enabled: bool) -> void:
	RenderingServer.global_shader_parameter_set(&"block_textures", 1.0 if enabled else 0.0)


## v0.26.0: plants drawn on two crossed cut-out cards (flowers, tufts, herbs,
## crops), assets/shaders/sprite.gdshader. `glow` > 0 makes them shine.
static func sprite(sway: float, glow: float = 0.0) -> ShaderMaterial:
	var key := StringName("sprite_%d_%d" % [roundi(sway * 1000.0), roundi(glow * 100.0)])
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/sprite.gdshader")
		m.set_shader_parameter(&"block_tex", block_texture_array())
		m.set_shader_parameter(&"sway", sway)
		m.set_shader_parameter(&"emission", glow)
		_cache[key] = m
	return _cache[key]


## Occluders closer to the camera than ~60% of the camera->player distance fade.
## `focus` is the hero's chest: trees standing on the line from the camera to
## the hero fade as well, like in Minecraft Dungeons (foliage shader only).
static func set_camera_fade(camera_distance: float, focus := Vector3(0, -1.0e6, 0)) -> void:
	var m := vertex_color_occluder() as ShaderMaterial
	m.set_shader_parameter(&"fade_min", camera_distance * 0.45)
	m.set_shader_parameter(&"fade_max", camera_distance * 0.72)
	for key in _cache:
		var f = _cache[key]
		if f is ShaderMaterial and String(key).begins_with("foliage_fade"):
			f.set_shader_parameter(&"fade_min", camera_distance * 0.45)
			f.set_shader_parameter(&"fade_max", camera_distance * 0.72)
			f.set_shader_parameter(&"focus_pos", focus)


## Global shader parameters shared by foliage and water (WeatherSystem drives
## them) are declared in project.godot [shader_globals]; nothing to create here.
static func ensure_globals() -> void:
	pass


## Vertex-coloured foliage that sways in the wind (Milestone 10). `sway` is the
## bend per metre² of height; `fade_near` adds the soft near-camera fade
## (assets/shaders/foliage_fade.gdshader, Milestone 18 art pass).
static func foliage(sway: float, fade_near: bool) -> ShaderMaterial:
	var key := StringName("foliage%s_%d" % ["_fade" if fade_near else "", roundi(sway * 1000.0)])
	if not _cache.has(key):
		ensure_globals()
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/foliage_fade.gdshader" if fade_near else "res://assets/shaders/foliage.gdshader")
		m.set_shader_parameter(&"sway", sway)
		m.set_shader_parameter(&"fade_near", fade_near)
		m.set_shader_parameter(&"block_tex", block_texture_array())
		_cache[key] = m
	return _cache[key]


## Same as vertex_color() but glowing (flames, magic, eyes).
static func vertex_color_emissive() -> StandardMaterial3D:
	if not _cache.has(&"vertex_color_emissive"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache[&"vertex_color_emissive"] = m
	return _cache[&"vertex_color_emissive"]


## Animated stylized water (assets/shaders/water.gdshader, Milestone 10).
static func water() -> Material:
	if not _cache.has(&"water"):
		ensure_globals()
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/water.gdshader")
		_cache[&"water"] = m
	return _cache[&"water"]


## White overlay used for the "got hit" flash.
static func hit_flash() -> StandardMaterial3D:
	if not _cache.has(&"hit_flash"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 1, 1, 0.75)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache[&"hit_flash"] = m
	return _cache[&"hit_flash"]


## Milestone 18b: a coloured outline (an inverted hull drawn a little bigger
## behind the model) that marks elite enemies.
static func outline(color: Color) -> StandardMaterial3D:
	var key := "outline_%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = 0.045
		_cache[key] = m
	return _cache[key]


## Red glow overlay used to telegraph dangerous enemy attacks.
static func danger_glow() -> StandardMaterial3D:
	if not _cache.has(&"danger_glow"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.15, 0.1, 0.45)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache[&"danger_glow"] = m
	return _cache[&"danger_glow"]


## Unshaded flat colour, drawn on top of geometry (UI-in-world elements).
static func overlay_color(color: Color) -> StandardMaterial3D:
	var key := "overlay_%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.render_priority = 10
		_cache[key] = m
	return _cache[key]


## Dark overlay showing damage on building pieces (4 steps: 0 = none .. 3 = heavy).
static func damage_overlay(step: int) -> StandardMaterial3D:
	var key := "damage_%d" % step
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.06, 0.03, 0.18 * step)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache[key] = m
	return _cache[key]
