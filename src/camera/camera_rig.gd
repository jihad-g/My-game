class_name CameraRig
extends Node3D
## Top-down / isometric tactical camera.
##
## - Follows a target smoothly (or pans freely with the arrow keys; Home recenters)
## - Q/E or middle-mouse drag rotates (yaw); PageUp/PageDown or MMB drag pitches
## - Mouse wheel zooms
## - Provides the mouse aim point on the ground for the player
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
	snap_to_target()


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
		global_position = target.global_position + _pan_offset
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


## World point under the mouse cursor: terrain hit, or the horizontal plane at
## `fallback_height` if the ray hits nothing.
func get_mouse_world_point(fallback_height: float) -> Vector3:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
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
