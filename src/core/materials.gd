class_name Materials
## Shared material cache. Sharing materials keeps draw-call batching effective.

static var _cache: Dictionary = {}


## Flat, vertex-coloured, matte material used by all blocky meshes.
static func vertex_color() -> StandardMaterial3D:
	if not _cache.has(&"vertex_color"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		# Palette colours are authored in sRGB (like every colour picker).
		m.vertex_color_is_srgb = true
		m.roughness = 0.95
		m.metallic_specular = 0.2
		_cache[&"vertex_color"] = m
	return _cache[&"vertex_color"]


## Vertex-colour material that dithers out near the camera, so tall props
## (trees) between the camera and the player don't hide the action.
## CameraRig updates the fade distances every frame via set_camera_fade().
static func vertex_color_occluder() -> StandardMaterial3D:
	if not _cache.has(&"vertex_color_occluder"):
		var m := vertex_color().duplicate() as StandardMaterial3D
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = 6.0
		m.distance_fade_max_distance = 11.0
		_cache[&"vertex_color_occluder"] = m
	return _cache[&"vertex_color_occluder"]


## Occluders closer to the camera than ~60% of the camera->player distance fade.
static func set_camera_fade(camera_distance: float) -> void:
	var m := vertex_color_occluder()
	m.distance_fade_min_distance = camera_distance * 0.45
	m.distance_fade_max_distance = camera_distance * 0.72


## Same as vertex_color() but glowing (flames, magic, eyes).
static func vertex_color_emissive() -> StandardMaterial3D:
	if not _cache.has(&"vertex_color_emissive"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache[&"vertex_color_emissive"] = m
	return _cache[&"vertex_color_emissive"]


static func water() -> StandardMaterial3D:
	if not _cache.has(&"water"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.62, 0.95, 0.62)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.15
		m.metallic_specular = 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
