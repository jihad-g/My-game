class_name CameraRig
extends Node3D
## Top-down / isometric tactical camera.
##
## - Follows a target smoothly (or pans freely with the arrow keys; Home recenters)
## - Q/E or middle-mouse drag rotates (yaw); PageUp/PageDown or MMB drag pitches
## - Mouse wheel zooms
## - Provides the mouse aim point on the ground for the player
## - v0.49.0: an optional first-person view (End key or Settings → Gameplay)
##
## Hierarchy (created in _ready):  CameraRig (yaw, position) -> Pitch -> Camera3D

@export var target: Node3D
@export var min_distance: float = 7.0
@export var max_distance: float = 42.0
@export var distance: float = 18.0
@export var min_pitch_deg: float = 25.0
@export var max_pitch_deg: float = 80.0
@export var pitch_deg: float = 52.0
@export var yaw_deg: float = 45.0
@export var rotate_speed_deg: float = 110.0
@export var mouse_rotate_sensitivity: float = 0.3
@export var follow_sharpness: float = 10.0
@export var zoom_sharpness: float = 10.0
@export var pan_speed: float = 22.0
@export var max_pan_distance: float = 60.0

var camera: Camera3D
var _pitch_node: Node3D
var _target_distance: float
var _target_yaw: float
var _target_pitch: float
var _pan_offset := Vector3.ZERO
var _dragging := false
var _shake := 0.0
## Screen shake on/off (Settings).
var shake_enabled := true
## Rotation speed multiplier (Settings → Gameplay).
var rotate_speed_scale := 1.0

# Milestone 18a.
## The camera looks a little ahead of where you walk (seconds of movement, max metres).
@export var lead_time: float = 0.28
@export var max_lead: float = 2.2
## Fixed isometric view: yaw and pitch can't be changed (Settings → Gameplay).
const FIXED_YAW := 45.0
const FIXED_PITCH := 55.0
var fixed := false
var _lead := Vector3.ZERO
var _shake_t := 0.0

# Milestone 38: the dungeon camera and the measured hit kick (from the reference clip).
## Inside dungeons the camera turns to the clip's view: 50 degrees down, turned 45
## degrees, a narrow 30 degree lens from further away (flat, "diorama" look), and
## it follows the hero locked (no look-ahead). Settings → Gameplay can turn it off.
const DUNGEON_YAW := 45.0
const DUNGEON_PITCH := 50.0
const DUNGEON_FOV := 30.0
## The measured kick on a heavy hit: metres to the camera's right, one value per
## frame at 30 fps (+11, -6, +8, 0 px on the clip's 2 m hero), plus a small bob.
const KICK_X: Array[float] = [0.0, 0.11, -0.06, 0.08, 0.0]
const KICK_Y: Array[float] = [0.0, 0.04, -0.03, 0.02, 0.0]
const KICK_FPS := 30.0
## Shakes below this strength (light hits) don't move the camera: the hit's light
## pop carries them, like in the clip.
const KICK_MIN := 0.15
var dungeon_view := false
## The field of view outside dungeons (Settings → Field of view).
var base_fov := 45.0
var _saved_view := {}
var _kick_t := -1.0
var _kick_scale := 0.0

# v0.49.0: first-person view. An option: the top-down camera stays the default and
# the main way to fight. Stats, damage and ranges are the same in both views.
## True while the camera is in first-person view.
var first_person := false
## Mouse look speed multiplier and inverted up/down (Settings → Gameplay).
var fp_sensitivity := 1.0
var fp_invert_y := false
## Field of view in first person (degrees, its own setting).
var fp_fov := 70.0
## Degrees turned per pixel of mouse movement at sensitivity 1.
const FP_MOUSE_DEG := 0.15
## Gamepad / key look speed (degrees per second at full stick).
const FP_STICK_DEG := 150.0
const FP_PITCH_LIMIT := 85.0
## How far in front of the eyes the camera sits (metres), so the hands are in view.
const FP_FORWARD := 0.12
## Look up/down in first person (degrees, + = up).
var fp_pitch := 0.0
var _fp_model: Node = null
var _crosshair: CanvasLayer


## Turns the fixed isometric camera on or off (it glides to the angle).
func set_fixed(on: bool) -> void:
	fixed = on
	if on and not dungeon_view:
		_target_yaw = FIXED_YAW + roundf((_target_yaw - FIXED_YAW) / 360.0) * 360.0
		_target_pitch = FIXED_PITCH
		_dragging = false


func _ready() -> void:
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	add_child(_pitch_node)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 45.0
	camera.near = 0.3
	camera.far = 640.0  # far terrain reaches ~520 m (Milestone 9)
	_pitch_node.add_child(camera)
	camera.current = true
	_target_distance = distance
	_target_yaw = yaw_deg
	_target_pitch = pitch_deg
	Events.camera_shake.connect(add_shake)
	Events.dungeon_entered.connect(func(_id: String, _floor: int) -> void:
		set_dungeon_view(bool(Settings.get_value("dungeon_camera"))))
	Events.dungeon_left.connect(func(_id: String, _cleared: bool) -> void: set_dungeon_view(false))
	_build_crosshair()
	snap_to_target()


func _exit_tree() -> void:
	_set_fp_model(null)
	if first_person and _can_capture_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- First-person view (v0.49.0) ---------------------------------------------------------

## Turns first-person view on or off. The camera keeps looking the same way.
func set_first_person(on: bool) -> void:
	if on == first_person:
		return
	first_person = on
	_dragging = false
	_pan_offset = Vector3.ZERO
	if on:
		fp_pitch = 0.0
	else:
		_set_fp_model(null)
		if _can_capture_mouse():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if fixed:
			set_fixed(true)
	if camera:
		camera.near = 0.05 if on else 0.3
		camera.fov = target_fov()
		var mask := camera.cull_mask
		camera.cull_mask = (mask & ~HumanoidModel.FP_HIDDEN_LAYER) if on else (mask | HumanoidModel.FP_HIDDEN_LAYER)
	if _crosshair:
		_crosshair.visible = false
	snap_to_target()


## True when the local hero's camera is in first-person view (roofs stay on, etc.).
static func first_person_active() -> bool:
	return World.instance != null and is_instance_valid(World.instance.camera_rig) and World.instance.camera_rig.first_person


func _can_capture_mouse() -> bool:
	return DisplayServer.get_name() != "headless"


## Hides the hero's body from this camera (only the arms and weapon show).
func _set_fp_model(m: Node) -> void:
	if m == _fp_model:
		return
	if is_instance_valid(_fp_model) and _fp_model.has_method(&"set_first_person_hidden"):
		_fp_model.set_first_person_hidden(false)
	_fp_model = m
	if is_instance_valid(m) and m.has_method(&"set_first_person_hidden"):
		m.set_first_person_hidden(true)


func _target_model() -> Node:
	if target == null:
		return null
	var m = target.get("model")
	return m if m is Node else null


## Where the first-person camera sits: the hero's eyes.
func _eye_position() -> Vector3:
	var m := _target_model()
	if m and m.has_method(&"eye_position"):
		return m.eye_position()
	return target.global_position + Vector3(0, 1.6, 0) if target else global_position


## True while a window, menu or the pause screen needs the mouse cursor.
func _cursor_needed() -> bool:
	if get_tree().paused:
		return true
	var w := World.instance
	return w != null and is_instance_valid(w.hud) and w.hud.has_method(&"wants_cursor") and w.hud.wants_cursor()


func _build_crosshair() -> void:
	_crosshair = CanvasLayer.new()
	_crosshair.name = "Crosshair"
	_crosshair.layer = 0
	_crosshair.visible = false
	add_child(_crosshair)
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_child(center)
	for r in [Rect2(-9, -1, 6, 2), Rect2(3, -1, 6, 2), Rect2(-1, -9, 2, 6), Rect2(-1, 3, 2, 6), Rect2(-1, -1, 2, 2)]:
		var shadow := ColorRect.new()
		shadow.color = Color(0, 0, 0, 0.45)
		shadow.position = (r as Rect2).position - Vector2(1, 1)
		shadow.size = (r as Rect2).size + Vector2(2, 2)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(shadow)
		var c := ColorRect.new()
		c.color = Color(1, 1, 1, 0.9)
		c.position = (r as Rect2).position
		c.size = (r as Rect2).size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(c)


## Mouse movement turns the view (degrees of yaw and pitch for `relative` pixels).
func fp_look(relative: Vector2) -> void:
	var k := FP_MOUSE_DEG * fp_sensitivity
	_target_yaw -= relative.x * k
	yaw_deg = _target_yaw
	fp_pitch = clampf(fp_pitch + relative.y * k * (1.0 if fp_invert_y else -1.0), -FP_PITCH_LIMIT, FP_PITCH_LIMIT)


func _process_first_person(delta: float) -> void:
	_set_fp_model(_target_model())
	if camera:
		camera.near = 0.05
		camera.cull_mask &= ~HumanoidModel.FP_HIDDEN_LAYER
	var free_cursor := _cursor_needed()
	if _can_capture_mouse():
		var mode := Input.MOUSE_MODE_VISIBLE if free_cursor else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != mode:
			Input.mouse_mode = mode
	if _crosshair:
		_crosshair.visible = not free_cursor
	if not free_cursor:
		# Gamepad right stick and the camera keys look around too.
		var turn := Input.get_axis(&"cam_rotate_right", &"cam_rotate_left")
		var tilt := Input.get_axis(&"cam_pitch_down", &"cam_pitch_up")
		_target_yaw += turn * FP_STICK_DEG * fp_sensitivity * rotate_speed_scale * delta
		fp_pitch = clampf(fp_pitch + tilt * FP_STICK_DEG * 0.6 * fp_sensitivity * (-1.0 if fp_invert_y else 1.0) * delta, -FP_PITCH_LIMIT, FP_PITCH_LIMIT)
	# Locked on: the view turns to the target.
	var lock = target.get("lock_target") if target else null
	if lock is Node3D and is_instance_valid(lock):
		var d := (lock as Node3D).global_position - _eye_position()
		if Vector2(d.x, d.z).length() > 0.5:
			var want := rad_to_deg(atan2(-d.x, -d.z))
			_target_yaw = rad_to_deg(lerp_angle(deg_to_rad(_target_yaw), deg_to_rad(want), 1.0 - exp(-8.0 * delta)))
	yaw_deg = _target_yaw
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_shake_t += delta
	if _kick_t >= 0.0:
		_kick_t += delta
		if _kick_t * KICK_FPS >= KICK_X.size() - 1:
			_kick_t = -1.0
	if camera and absf(camera.fov - target_fov()) > 0.01:
		camera.fov = lerpf(camera.fov, target_fov(), 1.0 - exp(-8.0 * delta))
	var eye := _eye_position()
	global_position = global_position.lerp(eye, 1.0 - exp(-30.0 * delta)) if global_position.distance_to(eye) < 2.0 else eye
	_apply_transform()
	# Nothing fades in first person (you see the world from inside it).
	Materials.set_camera_fade(0.0)


## How much further the camera sits with the narrow lens so the hero looks the
## same size (tan of the half angles).
func _lens_ratio() -> float:
	return tan(deg_to_rad(base_fov) * 0.5) / tan(deg_to_rad(DUNGEON_FOV) * 0.5)


## Milestone 38: turns the dungeon camera on or off. It glides there; your zoom
## and angle from before come back when you leave.
func set_dungeon_view(on: bool) -> void:
	if on == dungeon_view:
		return
	dungeon_view = on
	_dragging = false
	if on:
		_saved_view = {"yaw": _target_yaw, "pitch": _target_pitch, "zoom": _target_distance,
			"min": min_distance, "max": max_distance}
		var k := _lens_ratio()
		min_distance = _saved_view.min * k
		max_distance = _saved_view.max * k
		_target_distance = clampf(_target_distance * k, min_distance, max_distance)
		_target_yaw = DUNGEON_YAW + roundf((_target_yaw - DUNGEON_YAW) / 360.0) * 360.0
		_target_pitch = DUNGEON_PITCH
		_pan_offset = Vector3.ZERO
	elif not _saved_view.is_empty():
		min_distance = _saved_view.min
		max_distance = _saved_view.max
		_target_distance = clampf(_saved_view.zoom, min_distance, max_distance)
		_target_yaw = _saved_view.yaw
		_target_pitch = _saved_view.pitch
		_saved_view = {}
		if fixed:
			set_fixed(true)


## The field of view the camera glides to.
func target_fov() -> float:
	if first_person:
		return fp_fov
	return DUNGEON_FOV if dungeon_view else base_fov


## Milestone 38: the measured heavy-hit kick (`scale` 1 = the clip's size).
func kick(scale: float = 1.0) -> void:
	if not shake_enabled:
		return
	_kick_scale = maxf(_kick_scale if _kick_t >= 0.0 else 0.0, clampf(scale, 0.0, 2.0))
	_kick_t = 0.0


## The kick offset (metres right, up) `t` seconds after it started.
static func kick_offset(t: float) -> Vector2:
	if t < 0.0:
		return Vector2.ZERO
	var f := t * KICK_FPS
	var i := int(f)
	if i >= KICK_X.size() - 1:
		return Vector2.ZERO
	var u := f - i
	return Vector2(lerpf(KICK_X[i], KICK_X[i + 1], u), lerpf(KICK_Y[i], KICK_Y[i + 1], u))


func snap_to_target() -> void:
	if target:
		global_position = _eye_position() if first_person else target.global_position + _pan_offset
	_apply_transform()


## Milestone 38: hits kick the camera in the measured pattern (heavy hits only).
## Only big blasts (strength above 0.55) add the old wobble on top, weaker.
func add_shake(strength: float) -> void:
	if not shake_enabled:
		return
	if strength >= KICK_MIN:
		kick(clampf(strength / 0.3, 0.6, 1.8))
	if strength > 0.55:
		_shake = clampf(maxf(_shake, (strength - 0.55) * 1.6), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cam_first_person"):
		# Saved like any setting, so the Settings screen shows it too.
		Settings.set_value("first_person", not first_person)
		if Settings.get_value("first_person") != first_person:
			set_first_person(bool(Settings.get_value("first_person")))
		get_viewport().set_input_as_handled()
		return
	if first_person:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			fp_look((event as InputEventMouseMotion).relative)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance * 0.88, min_distance, max_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance * 1.12, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed and not fixed and not dungeon_view
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_target_yaw -= mm.relative.x * mouse_rotate_sensitivity
		_target_pitch = clampf(_target_pitch + mm.relative.y * mouse_rotate_sensitivity * 0.6, min_pitch_deg, max_pitch_deg)
	elif event.is_action_pressed(&"cam_recenter"):
		_pan_offset = Vector3.ZERO


func _process(delta: float) -> void:
	if first_person:
		_process_first_person(delta)
		return
	if not fixed and not dungeon_view:
		var rot_input := Input.get_axis(&"cam_rotate_right", &"cam_rotate_left")
		_target_yaw += rot_input * rotate_speed_deg * rotate_speed_scale * delta
		var pitch_input := Input.get_axis(&"cam_pitch_down", &"cam_pitch_up")
		_target_pitch = clampf(_target_pitch + pitch_input * 60.0 * delta, min_pitch_deg, max_pitch_deg)

	# Free pan relative to the camera orientation.
	var pan := Input.get_vector(&"cam_pan_left", &"cam_pan_right", &"cam_pan_forward", &"cam_pan_back")
	if pan != Vector2.ZERO:
		var basis_flat := Basis(Vector3.UP, deg_to_rad(yaw_deg))
		_pan_offset += basis_flat * Vector3(pan.x, 0, pan.y) * pan_speed * delta * (distance / 18.0)
		_pan_offset = _pan_offset.limit_length(max_pan_distance)

	var t := 1.0 - exp(-follow_sharpness * delta)
	if target:
		# Look ahead where the target walks (smoothed, so turning doesn't jerk the view).
		var v = target.get("velocity")
		var want := Vector3.ZERO
		if v is Vector3 and not dungeon_view:
			want = Vector3((v as Vector3).x, 0.0, (v as Vector3).z) * lead_time
			want = want.limit_length(max_lead)
		_lead = _lead.lerp(want, 1.0 - exp(-3.0 * delta))
		global_position = global_position.lerp(target.global_position + _pan_offset + _lead, t)
	var z := 1.0 - exp(-zoom_sharpness * delta)
	distance = lerpf(distance, _target_distance, z)
	yaw_deg = lerpf(yaw_deg, _target_yaw, z)
	pitch_deg = lerpf(pitch_deg, _target_pitch, z)
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_shake_t += delta
	if _kick_t >= 0.0:
		_kick_t += delta
		if _kick_t * KICK_FPS >= KICK_X.size() - 1:
			_kick_t = -1.0
	if camera and absf(camera.fov - target_fov()) > 0.01:
		camera.fov = lerpf(camera.fov, target_fov(), 1.0 - exp(-4.0 * delta))
	_apply_transform()
	# Trees between the camera and the hero fade too (Milestone 18 art pass).
	Materials.set_camera_fade(distance, target.global_position + Vector3(0, 1.0, 0) if target else Vector3(0, -1.0e6, 0))


func _apply_transform() -> void:
	rotation = Vector3(0, deg_to_rad(yaw_deg), 0)
	if first_person:
		_pitch_node.rotation = Vector3(deg_to_rad(fp_pitch), 0, 0)
		camera.position = Vector3(0, 0, -FP_FORWARD)
		# Hits shake the view a little (a third of the top-down shake).
		if _kick_t >= 0.0:
			var kf := kick_offset(_kick_t) * _kick_scale * 0.15
			camera.position += Vector3(kf.x, kf.y, 0.0)
		if _shake > 0.0:
			var sf := _shake * _shake * 0.03
			camera.position += Vector3(sin(_shake_t * 47.0), cos(_shake_t * 41.0), 0.0) * sf
		return
	_pitch_node.rotation = Vector3(-deg_to_rad(pitch_deg), 0, 0)
	camera.position = Vector3(0, 0, distance)
	if _kick_t >= 0.0:
		# Sized for the clip's camera; scaled with the zoom so it looks the same.
		var k := kick_offset(_kick_t) * _kick_scale * (distance * tan(deg_to_rad(camera.fov) * 0.5)) / (27.0 * tan(deg_to_rad(DUNGEON_FOV) * 0.5))
		camera.position += Vector3(k.x, k.y, 0.0)
	if _shake > 0.0:
		# Milestone 18a: a smooth wobble instead of random jumps every frame.
		var s := _shake * _shake * 0.28
		camera.position += Vector3(sin(_shake_t * 47.0) + sin(_shake_t * 23.0) * 0.5, cos(_shake_t * 41.0) + sin(_shake_t * 17.0) * 0.5, 0.0) * s * 0.67


## Horizontal forward direction of the camera (for camera-relative movement).
func get_forward_flat() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func get_right_flat() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	return r.normalized()


## Horizontal look direction in first person (the hero faces this way).
func get_look_flat() -> Vector3:
	return get_forward_flat()


## World point under the mouse cursor (first person: under the crosshair): terrain hit, or the horizontal plane at
## `fallback_height` if the ray hits nothing.
func get_mouse_world_point(fallback_height: float) -> Vector3:
	var viewport := get_viewport()
	# First person aims where the screen centre (the crosshair) points.
	var mouse := viewport.get_visible_rect().size * 0.5 if first_person else viewport.get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 500.0, Layers.TERRAIN)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	var plane := Plane(Vector3.UP, fallback_height)
	var p = plane.intersects_ray(origin, dir)
	return p if p != null else origin + dir * 20.0
