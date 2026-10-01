class_name AccessibilityLayer
extends CanvasLayer
## Screen-wide accessibility helpers (Milestone 13), owned by the Settings
## autoload so they work in menus and in the game:
## - colour-vision filter (daltonization for protanopia, deuteranopia, tritanopia)
## - sound captions ("[Monster growls, left]") for important audio cues
## - FPS counter

## Sounds that get a caption, and their text.
const CAPTIONS := {
	&"monster_growl": "Monster growls", &"boar_grunt": "Boar grunts", &"boss_roar": "Boss roars",
	&"bones": "Bones rattle", &"thunder": "Thunder", &"horn": "War horn", &"warning": "Alarm",
	&"explosion": "Explosion", &"bow": "Bowstring", &"arrow_hit": "Arrow hits", &"tree_fall": "Tree falls",
	&"door": "Door", &"fire_ignite": "Fire flares up", &"level_up": "Level up!", &"splash": "Splash",
	&"teleport": "Teleport", &"zap": "Magic crackles", &"rock_break": "Rock breaks", &"chest_open": "Chest opens",
	&"poison": "Poison hisses", &"discover": "Discovery", &"hurt": "You are hurt", &"parry": "Parry",
	&"frost": "Ice cracks", &"fire": "Flames", &"heal": "Healing", &"learn": "Learned something",
	&"enemy_die": "Enemy falls", &"notify": "Notice",
}
const MAX_CAPTIONS := 4
const CAPTION_TIME := 3.0

const _SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0;
uniform float strength = 1.0;
// Daltonization (Fidaner et al.): simulate the deficiency, then shift the
// lost contrast into channels the viewer can still tell apart.
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 lms = vec3(
		17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b,
		3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b,
		0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b);
	vec3 s = lms;
	if (mode == 1) {        // protanopia
		s.x = 2.02344 * lms.y - 2.52581 * lms.z;
	} else if (mode == 2) { // deuteranopia
		s.y = 0.494207 * lms.x + 1.24827 * lms.z;
	} else if (mode == 3) { // tritanopia
		s.z = -0.395913 * lms.x + 0.801109 * lms.y;
	}
	vec3 sim = vec3(
		0.0809444479 * s.x - 0.130504409 * s.y + 0.116721066 * s.z,
		-0.0102485335 * s.x + 0.0540193266 * s.y - 0.113614708 * s.z,
		-0.000365296938 * s.x - 0.00412161469 * s.y + 0.693511405 * s.z);
	vec3 err = c - sim;
	vec3 shift = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
	COLOR = vec4(clamp(c + shift * strength, 0.0, 1.0), 1.0);
}
"""

var filter := ColorRect.new()
var captions := VBoxContainer.new()
var fps_label := Label.new()
var colorblind_mode := 0
var captions_enabled := false
var _caption_times: Dictionary = {}  # Label -> time left


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = _SHADER
	mat.shader = sh
	filter.material = mat
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter.visible = false
	add_child(filter)
	captions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	captions.grow_horizontal = Control.GROW_DIRECTION_BOTH
	captions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	captions.offset_bottom = -150
	captions.alignment = BoxContainer.ALIGNMENT_END
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(captions)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -110
	fps_label.offset_top = 4
	fps_label.add_theme_constant_override(&"outline_size", 4)
	fps_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	fps_label.visible = false
	add_child(fps_label)


func set_colorblind(mode: int, strength: float = 1.0) -> void:
	colorblind_mode = clampi(mode, 0, 3)
	filter.visible = colorblind_mode != 0
	(filter.material as ShaderMaterial).set_shader_parameter(&"mode", colorblind_mode)
	(filter.material as ShaderMaterial).set_shader_parameter(&"strength", strength)


func set_captions(on: bool) -> void:
	captions_enabled = on
	if not on:
		for c in captions.get_children():
			c.queue_free()
		_caption_times.clear()


## Shows a caption for a sound, if it has one. `pos` = world position for
## positional sounds (adds "left"/"right"/"behind"), or null.
func caption_for_sound(sound: StringName, pos: Variant = null) -> void:
	if not captions_enabled:
		return
	var key := sound
	if not CAPTIONS.has(key):
		# Variant sounds: thunder_0, hit_flesh_1...
		var base := String(sound)
		var us := base.rfind("_")
		if us > 0 and base.substr(us + 1).is_valid_int():
			key = StringName(base.substr(0, us))
	if not CAPTIONS.has(key):
		return
	var text: String = CAPTIONS[key]
	if pos is Vector3:
		var d := direction_word(pos)
		if d != "":
			text += ", " + d
	show_caption("[%s]" % text)


func show_caption(text: String) -> void:
	# Refresh an identical caption instead of stacking duplicates.
	for c in captions.get_children():
		if c is Label and (c as Label).text == text:
			_caption_times[c] = CAPTION_TIME
			return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", 20)
	l.add_theme_constant_override(&"outline_size", 6)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.95))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_content_margin_all(4)
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.set_corner_radius_all(4)
	l.add_theme_stylebox_override(&"normal", bg)
	captions.add_child(l)
	_caption_times[l] = CAPTION_TIME
	while captions.get_child_count() > MAX_CAPTIONS:
		var old := captions.get_child(0)
		_caption_times.erase(old)
		captions.remove_child(old)
		old.queue_free()


## "left", "right", "behind" or "" (ahead / close), relative to the camera.
func direction_word(pos: Vector3) -> String:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return ""
	var focus := cam.global_position
	if World.instance and World.instance.player:
		focus = World.instance.player.global_position
	var rel := pos - focus
	rel.y = 0.0
	if rel.length() < 4.0:
		return ""
	var right := cam.global_transform.basis.x
	right.y = 0.0
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	var x := rel.normalized().dot(right.normalized())
	var z := rel.normalized().dot(fwd.normalized())
	if absf(x) >= absf(z):
		return "right" if x > 0 else "left"
	return "ahead" if z > 0 else "behind"


func _process(delta: float) -> void:
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	for l in _caption_times.keys():
		if not is_instance_valid(l):
			_caption_times.erase(l)
			continue
		_caption_times[l] = float(_caption_times[l]) - delta
		(l as Label).modulate.a = clampf(float(_caption_times[l]) / 0.6, 0.0, 1.0)
		if float(_caption_times[l]) <= 0.0:
			_caption_times.erase(l)
			l.queue_free()
