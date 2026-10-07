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
	snap_to_target()


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + _pan_offset
	_apply_transform()


func add_shake(strength: float) -> void:
	if not shake_enabled:
		return
	_shake = clampf(maxf(_shake, strength), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance * 0.88, min_distance, max_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance * 1.12, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_target_yaw -= mm.relative.x * mouse_rotate_sensitivity
		_target_pitch = clampf(_target_pitch + mm.relative.y * mouse_rotate_sensitivity * 0.6, min_pitch_deg, max_pitch_deg)
	elif event.is_action_pressed(&"cam_recenter"):
		_pan_offset = Vector3.ZERO


func _process(delta: float) -> void:
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
		global_position = global_position.lerp(target.global_position + _pan_offset, t)
	var z := 1.0 - exp(-zoom_sharpness * delta)
	distance = lerpf(distance, _target_distance, z)
	yaw_deg = lerpf(yaw_deg, _target_yaw, z)
	pitch_deg = lerpf(pitch_deg, _target_pitch, z)
	_shake = maxf(_shake - delta * 2.5, 0.0)
	_apply_transform()
	Materials.set_camera_fade(distance)


func _apply_transform() -> void:
	rotation = Vector3(0, deg_to_rad(yaw_deg), 0)
	_pitch_node.rotation = Vector3(-deg_to_rad(pitch_deg), 0, 0)
	camera.position = Vector3(0, 0, distance)
	if _shake > 0.0:
		var s := _shake * _shake * 0.35
		camera.position += Vector3(randf_range(-s, s), randf_range(-s, s), 0)


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
