extends Node
## Player settings, saved to user://settings.cfg and applied immediately.
## Milestone 10: volumes, display, graphics quality and comfort options.
## Milestone 13: gameplay (difficulty, tutorial, autosave), controls (rebinding,
## toggle sprint), display (window mode, frame cap, FPS counter) and
## accessibility (UI scale, colour-vision filters, high contrast, captions,
## reduced flashing and motion, damage numbers).
## World systems read them through apply_to_world() when a world loads.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	# Audio
	"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0, "ambience_volume": 1.0, "ui_volume": 1.0,
	# Display & graphics
	"fullscreen": false, "vsync": true, "render_scale": 1.0, "shadows": 2,  # 0 off, 1 low, 2 high
	"weather_particles": true, "ambient_particles": true, "far_terrain": true, "vfx_particles": true,
	"max_fps": 0, "show_fps": false,
	# Comfort
	"screen_shake": true,
	# Gameplay
	"difficulty": 1, "tutorial_hints": true, "autosave_minutes": 2, "damage_numbers": true,
	"camera_rotate_speed": 1.0,
	# Controls
	"toggle_sprint": false,
	# Accessibility
	"ui_scale": 1.0, "colorblind_mode": 0, "high_contrast": false, "captions": false,
	"reduce_flashing": false, "reduce_motion": false,
}
const DIFFICULTY_NAMES := ["Story", "Normal", "Hard"]
## Damage the player takes and hunger drain, by difficulty.
const DIFFICULTY_DAMAGE := [0.5, 1.0, 1.5]
const DIFFICULTY_HUNGER := [0.6, 1.0, 1.25]
const AUTOSAVE_CHOICES := [0, 1, 2, 5, 10]  # minutes, 0 = off
const FPS_CHOICES := [0, 30, 60, 120, 144]  # 0 = unlimited
const COLORBLIND_NAMES := ["Off", "Protanopia (red-weak)", "Deuteranopia (green-weak)", "Tritanopia (blue-weak)"]

var values: Dictionary = DEFAULTS.duplicate()
## Settings file path (tests point this elsewhere).
var path := PATH
var accessibility: AccessibilityLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.install_symbol_fallback()
	accessibility = AccessibilityLayer.new()
	accessibility.name = "Accessibility"
	add_child(accessibility)
	Audio.caption_hook = accessibility.caption_for_sound
	load_settings()
	apply()
	InputSetup.bindings_changed.connect(_on_bindings_changed)


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save_settings()
	changed.emit()


var _loading_bindings := false


func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for k in DEFAULTS:
		var v = cf.get_value("settings", k, DEFAULTS[k])
		# A hand-edited or old file can hold the wrong type: keep the default then.
		if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
			values[k] = v
	var binds = cf.get_value("input", "bindings", {})
	if binds is Dictionary and not binds.is_empty():
		_loading_bindings = true
		InputSetup.apply_custom_bindings(binds)
		_loading_bindings = false


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.set_value("input", "bindings", InputSetup.custom_bindings())
	cf.save(path)


func _on_bindings_changed() -> void:
	if not _loading_bindings:
		save_settings()


func reset_defaults() -> void:
	values = DEFAULTS.duplicate()
	apply()
	save_settings()
	changed.emit()


func reset_controls() -> void:
	InputSetup.reset_all()
	save_settings()


# --- Derived values -----------------------------------------------------------------------

func damage_taken_mult() -> float:
	return DIFFICULTY_DAMAGE[clampi(int(get_value("difficulty")), 0, 2)]


func hunger_mult() -> float:
	return DIFFICULTY_HUNGER[clampi(int(get_value("difficulty")), 0, 2)]


## Seconds between autosaves (0 = off).
func autosave_interval() -> float:
	return float(get_value("autosave_minutes")) * 60.0


func reduce_motion() -> bool:
	return bool(get_value("reduce_motion"))


func reduce_flashing() -> bool:
	return bool(get_value("reduce_flashing"))


# --- Applying ------------------------------------------------------------------------------

func apply() -> void:
	Audio.set_volume(&"Master", float(get_value("master_volume")))
	Audio.set_volume(&"Music", float(get_value("music_volume")))
	Audio.set_volume(&"SFX", float(get_value("sfx_volume")))
	Audio.set_volume(&"Ambience", float(get_value("ambience_volume")))
	Audio.set_volume(&"UI", float(get_value("ui_volume")))
	VFX.enabled = bool(get_value("vfx_particles"))
	Engine.max_fps = maxi(0, int(get_value("max_fps")))
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
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_factor = clampf(float(get_value("ui_scale")), 0.75, 1.5)
	UITheme.set_high_contrast(bool(get_value("high_contrast")))
	if accessibility:
		accessibility.set_colorblind(int(get_value("colorblind_mode")))
		accessibility.set_captions(bool(get_value("captions")))
		accessibility.fps_label.visible = bool(get_value("show_fps"))
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
		w.camera_rig.shake_enabled = bool(get_value("screen_shake")) and not reduce_motion()
		w.camera_rig.rotate_speed_scale = clampf(float(get_value("camera_rotate_speed")), 0.25, 2.5)
