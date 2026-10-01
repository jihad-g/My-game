extends Node
## Player settings (Milestone 10), saved to user://settings.cfg and applied
## immediately: volumes, display, graphics quality and comfort options.
## World systems read them through apply_to_world() when a world loads.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0, "ambience_volume": 1.0, "ui_volume": 1.0,
	"fullscreen": false, "vsync": true, "render_scale": 1.0, "shadows": 2,  # 0 off, 1 low, 2 high
	"weather_particles": true, "ambient_particles": true, "far_terrain": true, "screen_shake": true,
	"vfx_particles": true,
}

var values: Dictionary = DEFAULTS.duplicate()
## Settings file path (tests point this elsewhere).
var path := PATH


func _ready() -> void:
	load_settings()
	apply()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save_settings()
	changed.emit()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for k in DEFAULTS:
		values[k] = cf.get_value("settings", k, DEFAULTS[k])


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(path)


func reset_defaults() -> void:
	values = DEFAULTS.duplicate()
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	Audio.set_volume(&"Master", float(get_value("master_volume")))
	Audio.set_volume(&"Music", float(get_value("music_volume")))
	Audio.set_volume(&"SFX", float(get_value("sfx_volume")))
	Audio.set_volume(&"Ambience", float(get_value("ambience_volume")))
	Audio.set_volume(&"UI", float(get_value("ui_volume")))
	VFX.enabled = bool(get_value("vfx_particles"))
	if DisplayServer.get_name() != "headless":
		var fs := bool(get_value("fullscreen"))
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(float(get_value("render_scale")), 0.5, 1.0)
	if World.instance:
		apply_to_world(World.instance)


## Graphics/comfort settings that live on world nodes.
func apply_to_world(w: World) -> void:
	var shadows := int(get_value("shadows"))
	var sun := w.day_night.sun if w.day_night else null
	if sun:
		sun.shadow_enabled = shadows > 0
		sun.directional_shadow_max_distance = 45.0 if shadows == 1 else 70.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if shadows == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if w.weather:
		w.weather.particles_enabled = bool(get_value("weather_particles"))
	if w.ambient:
		w.ambient.particles_enabled = bool(get_value("ambient_particles"))
	if w.chunk_manager and w.chunk_manager.far:
		w.chunk_manager.far.visible = bool(get_value("far_terrain")) and w.layer == TerrainGenerator.Layer.SURFACE
		w.chunk_manager.far.set_meta(&"hidden_by_settings", not bool(get_value("far_terrain")))
	if w.camera_rig:
		w.camera_rig.shake_enabled = bool(get_value("screen_shake"))
